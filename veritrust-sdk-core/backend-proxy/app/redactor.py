"""
VeriTrust AI — PII Redactor
=============================
DPDP Act-compliant redaction utilities for Aadhaar, PAN, card numbers,
phone numbers, and other personally identifiable information.

All redaction happens BEFORE any data is logged, transmitted, or processed
by downstream services.
"""

from __future__ import annotations

import re
from typing import Callable


# ═══════════════════════════════════════════════════════════════════
#  Regex Patterns
# ═══════════════════════════════════════════════════════════════════

# Aadhaar: 12 digits, optionally separated by spaces or hyphens
_AADHAAR_PATTERN = re.compile(
    r"\b([2-9]\d{3})[\s\-]?(\d{4})[\s\-]?(\d{4})\b"
)

# PAN: 5 uppercase letters + 4 digits + 1 uppercase letter
_PAN_PATTERN = re.compile(
    r"\b([A-Z]{5})(\d{4})([A-Z])\b"
)

# Card numbers: 13-19 digits optionally separated by spaces/hyphens
_CARD_PATTERN = re.compile(
    r"\b(\d{4})[\s\-]?(\d{4})[\s\-]?(\d{4})[\s\-]?(\d{4})(?:[\s\-]?\d{1,3})?\b"
)

# Indian mobile: +91 or 0 prefix + 10 digits
_PHONE_PATTERN = re.compile(
    r"(?:\+91[\s\-]?|0)?([6-9]\d{4})[\s\-]?(\d{5})\b"
)

# Email addresses
_EMAIL_PATTERN = re.compile(
    r"\b([a-zA-Z0-9._%+-]+)@([a-zA-Z0-9.-]+\.[a-zA-Z]{2,})\b"
)

# IFSC Code: 4 letters + 0 + 6 alphanumeric
_IFSC_PATTERN = re.compile(
    r"\b([A-Z]{4})(0)([A-Z0-9]{6})\b"
)

# Bank account numbers: 9-18 digit sequences (heuristic)
_ACCOUNT_PATTERN = re.compile(
    r"\b(\d{2})(\d+)(\d{4})\b"
)


# ═══════════════════════════════════════════════════════════════════
#  Individual Redactors
# ═══════════════════════════════════════════════════════════════════

def redact_aadhaar(text: str) -> str:
    """Mask Aadhaar numbers → XXXX-XXXX-1234 (last 4 visible)."""
    def _replace(match: re.Match) -> str:
        last_four = match.group(3)
        return f"XXXX-XXXX-{last_four}"
    return _AADHAAR_PATTERN.sub(_replace, text)


def redact_pan(text: str) -> str:
    """Mask PAN → XXXXX1234X (digits visible, letters masked)."""
    def _replace(match: re.Match) -> str:
        digits = match.group(2)
        last = match.group(3)
        return f"XXXXX{digits}{last}"
    return _PAN_PATTERN.sub(_replace, text)


def redact_card_number(text: str) -> str:
    """Mask card numbers → XXXX-XXXX-XXXX-1234 (last 4 visible)."""
    def _replace(match: re.Match) -> str:
        last_four = match.group(4)
        return f"XXXX-XXXX-XXXX-{last_four}"
    return _CARD_PATTERN.sub(_replace, text)


def redact_phone(text: str) -> str:
    """Mask Indian mobile numbers → XXXXX-12345 (last 5 visible)."""
    def _replace(match: re.Match) -> str:
        last_five = match.group(2)
        return f"XXXXX-{last_five}"
    return _PHONE_PATTERN.sub(_replace, text)


def redact_email(text: str) -> str:
    """Mask email → u***@domain.com."""
    def _replace(match: re.Match) -> str:
        local = match.group(1)
        domain = match.group(2)
        masked_local = local[0] + "***" if len(local) > 0 else "***"
        return f"{masked_local}@{domain}"
    return _EMAIL_PATTERN.sub(_replace, text)


# ═══════════════════════════════════════════════════════════════════
#  Composite Redactor
# ═══════════════════════════════════════════════════════════════════

_REDACTION_PIPELINE: list[Callable[[str], str]] = [
    redact_aadhaar,
    redact_pan,
    redact_card_number,
    redact_phone,
    redact_email,
]


def redact_all(text: str) -> str:
    """
    Run the full PII redaction pipeline.
    Order matters — Aadhaar before generic digit patterns.
    """
    result = text
    for redactor in _REDACTION_PIPELINE:
        result = redactor(result)
    return result


def contains_pii(text: str) -> bool:
    """Quick check: does the text contain any detectable PII patterns?"""
    return text != redact_all(text)
