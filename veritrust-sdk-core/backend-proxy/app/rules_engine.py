"""
VeriTrust AI — Deterministic Rules Engine
==========================================
Structured data lookup and computation engine for interest rates,
fees, and RBI-mandated Key Fact Statement (KFS) generation.

All values are sourced from immutable JSON files — zero neural inference.
"""

from __future__ import annotations

import json
import logging
import math
from pathlib import Path
from typing import Any, Optional

from app.config import get_settings
from app.schemas import VerificationResult

logger = logging.getLogger("veritrust.rules")


class RulesEngine:
    """Deterministic lookup and computation engine for structured banking data."""

    def __init__(self):
        self._settings = get_settings()
        self._rates_data: Optional[dict] = None
        self._fees_data: Optional[dict] = None
        self._kfs_template: Optional[dict] = None

    def _load_json(self, filename: str) -> dict:
        """Load a JSON file from the structured data directory."""
        path = Path(self._settings.STRUCTURED_DATA_DIR) / filename
        if not path.exists():
            raise FileNotFoundError(f"Structured data file not found: {path}")
        with open(path, "r", encoding="utf-8") as f:
            return json.load(f)

    @property
    def rates(self) -> dict:
        if self._rates_data is None:
            self._rates_data = self._load_json("sbi_rates_v7.json")
        return self._rates_data

    @property
    def fees(self) -> dict:
        if self._fees_data is None:
            self._fees_data = self._load_json("sbi_fees_schedule.json")
        return self._fees_data

    @property
    def kfs_template(self) -> dict:
        if self._kfs_template is None:
            self._kfs_template = self._load_json("kfs_template.json")
        return self._kfs_template

    # ── Interest Rate Lookup ──────────────────────────────────────

    def lookup_interest_rate(
        self,
        account_type: str,
        tenure_days: Optional[int] = None,
        depositor_category: str = "general",
    ) -> dict:
        """
        Exact-match lookup against the SBI rate matrix.

        Args:
            account_type: 'savings', 'term_deposit', 'recurring_deposit'
            tenure_days: Required for term/recurring deposits
            depositor_category: 'general' or 'senior_citizen'

        Returns:
            Dict with rate, effective_date, found status
        """
        data = self.rates

        # Savings account — flat rate
        if account_type in ("savings", "savings_account"):
            savings = data.get("savings_account", {})
            standard = savings.get("standard", {})
            return {
                "account_type": "savings_account",
                "depositor_category": depositor_category,
                "rate_percent_pa": standard.get("rate_percent_pa"),
                "effective_date": standard.get("effective_date"),
                "found": True,
                "details": standard,
            }

        # Term deposit
        if account_type in ("term_deposit", "td", "fixed_deposit", "fd"):
            if tenure_days is None:
                return {"found": False, "error": "tenure_days is required for term deposits"}

            td_data = data.get("term_deposit", {})

            # Check special schemes first
            special = td_data.get("special_schemes", {})
            for scheme_name, scheme in special.items():
                if scheme.get("tenure_days") == tenure_days:
                    rate_key = f"rate_{depositor_category}" if depositor_category != "general" else "rate_general"
                    return {
                        "account_type": "term_deposit",
                        "scheme": scheme_name,
                        "depositor_category": depositor_category,
                        "tenure_days": tenure_days,
                        "rate_percent_pa": scheme.get(rate_key, scheme.get("rate_general")),
                        "effective_date": scheme.get("effective_date"),
                        "found": True,
                        "details": scheme,
                    }

            # Standard TD slabs
            category_key = depositor_category if depositor_category in td_data else "general"
            slabs = td_data.get(category_key, [])

            for slab in slabs:
                if slab["min_days"] <= tenure_days <= slab["max_days"]:
                    return {
                        "account_type": "term_deposit",
                        "depositor_category": category_key,
                        "tenure_days": tenure_days,
                        "rate_percent_pa": slab["rate_percent_pa"],
                        "found": True,
                        "details": slab,
                    }

            return {"found": False, "error": f"No rate slab found for tenure {tenure_days} days"}

        # Recurring deposit
        if account_type in ("recurring_deposit", "rd"):
            if tenure_days is None:
                return {"found": False, "error": "tenure_days is required for recurring deposits"}

            tenure_months = tenure_days // 30  # Approximate
            rd_data = data.get("recurring_deposit", {}).get("general", [])

            for slab in rd_data:
                if slab["min_months"] <= tenure_months <= slab["max_months"]:
                    return {
                        "account_type": "recurring_deposit",
                        "depositor_category": depositor_category,
                        "tenure_months": tenure_months,
                        "rate_percent_pa": slab["rate_percent_pa"],
                        "found": True,
                        "details": slab,
                    }

            return {"found": False, "error": f"No RD slab found for tenure ~{tenure_months} months"}

        return {"found": False, "error": f"Unknown account type: {account_type}"}

    # ── Fee Lookup ────────────────────────────────────────────────

    def lookup_fee(self, category: str, item: str) -> dict:
        """
        Lookup a specific fee from the schedule.

        Args:
            category: Top-level category (e.g., 'digital_transactions', 'card_charges')
            item: Specific fee item within the category

        Returns:
            Dict with fee amount and found status
        """
        data = self.fees
        category_data = data.get(category, {})

        if isinstance(category_data, dict):
            if item in category_data:
                value = category_data[item]
                if isinstance(value, dict):
                    return {"found": True, "category": category, "item": item, "details": value}
                return {"found": True, "category": category, "item": item, "amount": value}

            # Search nested
            for sub_key, sub_val in category_data.items():
                if isinstance(sub_val, dict) and item in sub_val:
                    return {
                        "found": True,
                        "category": f"{category}.{sub_key}",
                        "item": item,
                        "amount": sub_val[item],
                    }

        return {"found": False, "error": f"Fee not found: {category}/{item}"}

    # ── APR Calculation ───────────────────────────────────────────

    def compute_apr(
        self,
        principal: float,
        tenure_months: int,
        interest_rate: float,
        processing_fee: float = 0.0,
        other_charges: float = 0.0,
        insurance_premium: float = 0.0,
    ) -> dict:
        """
        Compute Annual Percentage Rate (APR) per RBI Digital Lending Directions.
        Uses the IRR method to compute the all-inclusive cost of credit.

        Args:
            principal: Loan amount in INR
            tenure_months: Loan tenure in months
            interest_rate: Nominal annual interest rate (%)
            processing_fee: Processing fee in INR
            other_charges: Other upfront charges in INR
            insurance_premium: Insurance premium if linked to loan

        Returns:
            Dict with APR, EMI, total interest, total cost
        """
        monthly_rate = interest_rate / 100 / 12

        # EMI calculation (standard annuity formula)
        if monthly_rate > 0:
            emi = principal * monthly_rate * (1 + monthly_rate) ** tenure_months / (
                (1 + monthly_rate) ** tenure_months - 1
            )
        else:
            emi = principal / tenure_months

        total_payment = emi * tenure_months
        total_interest = total_payment - principal

        # Total upfront deductions (included in APR per RBI)
        total_upfront = processing_fee + other_charges + insurance_premium
        net_disbursed = principal - total_upfront

        # APR via IRR: find rate r where
        # net_disbursed = sum(emi / (1 + r)^t for t in 1..tenure_months)
        # Using Newton-Raphson approximation
        apr = self._compute_irr(net_disbursed, emi, tenure_months)

        return {
            "principal": principal,
            "tenure_months": tenure_months,
            "nominal_rate": interest_rate,
            "apr": round(apr, 2),
            "emi": round(emi, 2),
            "total_interest": round(total_interest, 2),
            "total_payment": round(total_payment, 2),
            "total_upfront_charges": round(total_upfront, 2),
            "net_disbursed": round(net_disbursed, 2),
            "total_cost_of_credit": round(total_interest + total_upfront, 2),
        }

    def _compute_irr(
        self, net_disbursed: float, emi: float, months: int, max_iter: int = 100
    ) -> float:
        """
        Compute annualized IRR using Newton-Raphson method.
        """
        if net_disbursed <= 0 or emi <= 0 or months <= 0:
            return 0.0

        # Initial guess: nominal rate
        r = emi / net_disbursed  # Monthly rate guess

        for _ in range(max_iter):
            # PV of annuity
            pv = 0.0
            dpv = 0.0  # Derivative
            for t in range(1, months + 1):
                discount = (1 + r) ** t
                pv += emi / discount
                dpv -= t * emi / ((1 + r) ** (t + 1))

            f = pv - net_disbursed
            if abs(f) < 1e-6:
                break
            if abs(dpv) < 1e-12:
                break
            r = r - f / dpv

            # Clamp to reasonable range
            r = max(r, 1e-10)
            r = min(r, 1.0)  # 100% monthly = unreasonable

        # Annualize
        apr_annual = ((1 + r) ** 12 - 1) * 100
        return apr_annual

    # ── KFS Generation ────────────────────────────────────────────

    def generate_kfs(
        self,
        principal: float,
        tenure_months: int,
        interest_rate: float,
        processing_fee: float = 0.0,
        other_charges: float = 0.0,
        insurance_premium: float = 0.0,
    ) -> dict:
        """
        Generate a complete Key Fact Statement per RBI mandate.
        """
        # Compute financial details
        financials = self.compute_apr(
            principal, tenure_months, interest_rate,
            processing_fee, other_charges, insurance_premium,
        )

        template = self.kfs_template
        compliance = template.get("template_fields", {}).get("compliance_fields", {})

        return {
            "lender": template.get("template_fields", {}).get("lender_details", {}),
            "loan_details": {
                "loan_amount": principal,
                "tenure_months": tenure_months,
                "repayment_frequency": "Monthly",
                "number_of_installments": tenure_months,
            },
            "cost_details": {
                "nominal_interest_rate_pa": interest_rate,
                "annual_percentage_rate": financials["apr"],
                "processing_fee": processing_fee,
                "insurance_premium": insurance_premium,
                "other_charges": other_charges,
                "total_upfront_deductions": financials["total_upfront_charges"],
            },
            "repayment_details": {
                "emi_amount": financials["emi"],
                "total_interest_payable": financials["total_interest"],
                "total_amount_payable": financials["total_payment"],
                "net_disbursed_amount": financials["net_disbursed"],
                "total_cost_of_credit": financials["total_cost_of_credit"],
            },
            "compliance": compliance,
            "apr_calculation_rules": template.get("apr_calculation_rules", {}),
        }

    # ── Rate Verification ─────────────────────────────────────────

    def validate_rate_claim(
        self,
        claimed_rate: float,
        account_type: str,
        tenure_days: Optional[int] = None,
        depositor_category: str = "general",
    ) -> VerificationResult:
        """
        Boolean check: does the claimed rate match the structured store?
        """
        lookup = self.lookup_interest_rate(account_type, tenure_days, depositor_category)

        if not lookup.get("found"):
            return VerificationResult(
                passed=False,
                flags=[f"Cannot verify rate — {lookup.get('error', 'rate not found')}"],
                rules_applied=["RATE_LOOKUP"],
            )

        actual_rate = lookup["rate_percent_pa"]
        tolerance = self._settings.RATE_TOLERANCE_BPS / 100  # Convert BPS to percentage

        if abs(claimed_rate - actual_rate) <= tolerance:
            return VerificationResult(
                passed=True,
                flags=[],
                rules_applied=["RATE_EXACT_MATCH"],
            )
        else:
            return VerificationResult(
                passed=False,
                flags=[
                    f"RATE_MISMATCH: Claimed {claimed_rate}% but actual is {actual_rate}% "
                    f"for {account_type} ({depositor_category}, "
                    f"tenure={tenure_days} days)"
                ],
                corrected_value=f"The correct interest rate is {actual_rate}% p.a.",
                rules_applied=["RATE_EXACT_MATCH"],
            )


# ── Module-level singleton ────────────────────────────────────────
_rules_engine: Optional[RulesEngine] = None


def get_rules_engine() -> RulesEngine:
    """Get or create the singleton rules engine instance."""
    global _rules_engine
    if _rules_engine is None:
        _rules_engine = RulesEngine()
    return _rules_engine
