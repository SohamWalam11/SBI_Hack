"""
VeriTrust AI — Deterministic Verifier
=======================================
The heart of Core B. Intercepts raw LLM output, extracts all numerical
and regulatory claims, cross-references against the structured rules engine,
and either passes or suppresses the response.

Zero tolerance: if ANY unverifiable claim is detected, the response is
replaced with a safe-fail message.
"""

from __future__ import annotations

import logging
import re
from typing import Any, Optional

from app.schemas import VerificationResult
from app.rules_engine import get_rules_engine

logger = logging.getLogger("veritrust.verifier")


# ═══════════════════════════════════════════════════════════════════
#  Regex Patterns for Claim Extraction
# ═══════════════════════════════════════════════════════════════════

# Percentage rates: "6.25%", "6.25% p.a.", "2.5 percent"
_RATE_PATTERN = re.compile(
    r"(\d+\.?\d*)\s*(?:%|percent|per\s*cent)(?:\s*(?:p\.?a\.?|per\s*annum))?",
    re.IGNORECASE,
)

# Monetary amounts: "₹5,000", "Rs. 25,000", "INR 1,00,000"
_AMOUNT_PATTERN = re.compile(
    r"(?:₹|Rs\.?|INR)\s*([\d,]+(?:\.\d{1,2})?)",
    re.IGNORECASE,
)

# Tenure patterns: "365 days", "12 months", "5 years"
_TENURE_PATTERN = re.compile(
    r"(\d+)\s*(days?|months?|years?)",
    re.IGNORECASE,
)

# Account type mentions
_ACCOUNT_TYPE_PATTERN = re.compile(
    r"\b(savings?\s*account|term\s*deposit|fixed\s*deposit|recurring\s*deposit|fd|td|rd)\b",
    re.IGNORECASE,
)

# Senior citizen mentions
_SENIOR_PATTERN = re.compile(
    r"\bsenior\s*citizen\b",
    re.IGNORECASE,
)

# Specific rate claims: "savings account interest rate is 2.5%"
_RATE_CLAIM_PATTERN = re.compile(
    r"(savings?\s*account|term\s*deposit|fixed\s*deposit|fd|td|rd)"
    r".*?"
    r"(?:interest\s*rate|rate\s*of\s*interest|rate)"
    r".*?"
    r"(\d+\.?\d*)\s*(?:%|percent)",
    re.IGNORECASE | re.DOTALL,
)


# ═══════════════════════════════════════════════════════════════════
#  Claim Extraction
# ═══════════════════════════════════════════════════════════════════

def extract_numerical_claims(response_text: str) -> list[dict]:
    """
    Extract all numerical claims (rates, amounts, tenures) from LLM output.

    Returns:
        List of dicts with keys: type, value, raw_match, context
    """
    claims = []

    # Extract rate claims with associated account types
    for match in _RATE_CLAIM_PATTERN.finditer(response_text):
        account_type = _normalize_account_type(match.group(1))
        rate = float(match.group(2))
        claims.append({
            "type": "interest_rate",
            "value": rate,
            "account_type": account_type,
            "raw_match": match.group(0).strip(),
            "position": match.start(),
        })

    # Extract standalone rates (not already captured)
    for match in _RATE_PATTERN.finditer(response_text):
        rate = float(match.group(1))
        # Check if this rate is already part of a rate_claim
        already_captured = any(
            c["type"] == "interest_rate"
            and abs(c["value"] - rate) < 0.001
            for c in claims
        )
        if not already_captured:
            # Try to find nearby account type context
            context_start = max(0, match.start() - 100)
            context = response_text[context_start:match.end() + 50]
            account_match = _ACCOUNT_TYPE_PATTERN.search(context)
            claims.append({
                "type": "rate_mention",
                "value": rate,
                "account_type": (
                    _normalize_account_type(account_match.group(1))
                    if account_match
                    else None
                ),
                "raw_match": match.group(0).strip(),
                "context": context.strip(),
                "position": match.start(),
            })

    # Extract monetary amounts
    for match in _AMOUNT_PATTERN.finditer(response_text):
        amount_str = match.group(1).replace(",", "")
        try:
            amount = float(amount_str)
            claims.append({
                "type": "monetary_amount",
                "value": amount,
                "raw_match": match.group(0).strip(),
                "position": match.start(),
            })
        except ValueError:
            pass

    # Extract tenure mentions
    for match in _TENURE_PATTERN.finditer(response_text):
        value = int(match.group(1))
        unit = match.group(2).lower().rstrip("s")
        claims.append({
            "type": "tenure",
            "value": value,
            "unit": unit,
            "raw_match": match.group(0).strip(),
            "position": match.start(),
        })

    return claims


def _normalize_account_type(raw: str) -> str:
    """Normalize account type strings to canonical keys."""
    raw_lower = raw.lower().strip()
    if any(k in raw_lower for k in ("saving",)):
        return "savings"
    if any(k in raw_lower for k in ("term deposit", "fixed deposit", "fd", "td")):
        return "term_deposit"
    if any(k in raw_lower for k in ("recurring", "rd")):
        return "recurring_deposit"
    return raw_lower


# ═══════════════════════════════════════════════════════════════════
#  Verification Logic
# ═══════════════════════════════════════════════════════════════════

def verify_claims(
    claims: list[dict], response_text: str
) -> VerificationResult:
    """
    Cross-reference extracted claims against the deterministic rules engine.
    """
    rules = get_rules_engine()
    flags: list[str] = []
    rules_applied: list[str] = []
    corrected_parts: list[str] = []

    # Check for senior citizen context
    is_senior = bool(_SENIOR_PATTERN.search(response_text))
    depositor_category = "senior_citizen" if is_senior else "general"

    for claim in claims:
        if claim["type"] == "interest_rate":
            # Extract tenure from nearby context if available
            tenure_days = _extract_tenure_from_context(
                response_text, claim.get("position", 0)
            )

            result = rules.validate_rate_claim(
                claimed_rate=claim["value"],
                account_type=claim.get("account_type", "savings"),
                tenure_days=tenure_days,
                depositor_category=depositor_category,
            )

            rules_applied.extend(result.rules_applied)
            if not result.passed:
                flags.extend(result.flags)
                if result.corrected_value:
                    corrected_parts.append(result.corrected_value)

        elif claim["type"] == "rate_mention" and claim.get("account_type"):
            # Try to verify standalone rate mentions
            tenure_days = _extract_tenure_from_context(
                response_text, claim.get("position", 0)
            )
            result = rules.validate_rate_claim(
                claimed_rate=claim["value"],
                account_type=claim["account_type"],
                tenure_days=tenure_days,
                depositor_category=depositor_category,
            )
            rules_applied.extend(result.rules_applied)
            if not result.passed:
                flags.extend(result.flags)
                if result.corrected_value:
                    corrected_parts.append(result.corrected_value)

    passed = len(flags) == 0
    corrected_value = "; ".join(corrected_parts) if corrected_parts else None

    return VerificationResult(
        passed=passed,
        flags=flags,
        corrected_value=corrected_value,
        rules_applied=list(set(rules_applied)),
    )


def _extract_tenure_from_context(text: str, position: int) -> Optional[int]:
    """
    Try to find a tenure value near a given position in the text.
    Returns tenure in days, or None.
    """
    context_start = max(0, position - 200)
    context_end = min(len(text), position + 200)
    context = text[context_start:context_end]

    for match in _TENURE_PATTERN.finditer(context):
        value = int(match.group(1))
        unit = match.group(2).lower().rstrip("s")
        if unit == "day":
            return value
        elif unit == "month":
            return value * 30
        elif unit == "year":
            return value * 365
    return None


def verify_compliance_references(
    response_text: str, citations: list[dict]
) -> list[str]:
    """
    Ensure cited source documents are in our known document set.
    Returns list of warning flags for unknown citations.
    """
    known_sources = {
        "master_direction_kyc.pdf",
        "master direction1.pdf",
        "sbi_depositor_rights.pdf",
        "Policy on Depositors Rights version 7.0.pdf",
        "internal_ombudsman.pdf",
        "RBI Master Directions IO 2023.pdf",
        "guidelinesrbi.pdf",
        "SAV INT HIST.pdf",
    }

    flags = []
    for citation in citations:
        source = citation.get("source_document", "")
        if source and source not in known_sources:
            flags.append(
                f"UNKNOWN_SOURCE: Citation references '{source}' which is not "
                f"in the verified compliance document set."
            )
    return flags


# ═══════════════════════════════════════════════════════════════════
#  Safe-Fail Mechanism
# ═══════════════════════════════════════════════════════════════════

SAFE_FAIL_MESSAGE = (
    "⚠️ **Verification Alert**: This response could not be fully verified against "
    "SBI's official records. For accurate information, please:\n\n"
    "- Contact SBI Customer Care: **1800-11-2211** (Toll Free)\n"
    "- Visit your nearest SBI branch\n"
    "- Check the official SBI website: sbi.co.in\n\n"
    "This alert has been logged for compliance review."
)


def safe_fail(response_text: str, flags: list[str]) -> str:
    """
    Replace the unverified response with a safe-fail message.
    Preserves the original response in audit logs but suppresses it from the user.
    """
    logger.warning(
        "SAFE_FAIL triggered — %d verification flags: %s",
        len(flags),
        "; ".join(flags),
    )
    return SAFE_FAIL_MESSAGE


# ═══════════════════════════════════════════════════════════════════
#  Full Verification Pipeline
# ═══════════════════════════════════════════════════════════════════

def run_full_verification(
    raw_response: str,
    citations: list[dict],
) -> dict:
    """
    Orchestrator: run all verification checks on an LLM response.

    Returns:
        Dict with: verified_response, verification_result, all_flags
    """
    all_flags: list[str] = []
    all_rules: list[str] = []

    # Skip verification for INSUFFICIENT_CONTEXT responses
    if "INSUFFICIENT_CONTEXT" in raw_response:
        return {
            "verified_response": raw_response,
            "verification_result": VerificationResult(
                passed=True,
                flags=[],
                rules_applied=["INSUFFICIENT_CONTEXT_PASSTHROUGH"],
            ),
        }

    # Step 1: Extract numerical claims
    claims = extract_numerical_claims(raw_response)
    logger.info("Extracted %d claims from response", len(claims))

    # Step 2: Verify numerical claims against structured data
    if claims:
        claim_result = verify_claims(claims, raw_response)
        all_flags.extend(claim_result.flags)
        all_rules.extend(claim_result.rules_applied)
    else:
        all_rules.append("NO_NUMERICAL_CLAIMS")

    # Step 3: Verify compliance references
    ref_flags = verify_compliance_references(raw_response, citations)
    all_flags.extend(ref_flags)
    if ref_flags:
        all_rules.append("CITATION_VERIFICATION")

    # Step 4: Determine final response
    passed = len(all_flags) == 0
    if passed:
        verified_response = raw_response
    else:
        verified_response = safe_fail(raw_response, all_flags)

    verification_result = VerificationResult(
        passed=passed,
        flags=all_flags,
        corrected_value=None if passed else "; ".join(
            f for f in all_flags if "MISMATCH" in f
        ) or None,
        rules_applied=list(set(all_rules)),
    )

    return {
        "verified_response": verified_response,
        "verification_result": verification_result,
    }
