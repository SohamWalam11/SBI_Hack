"""
VeriTrust AI — Pydantic Schemas
================================
Strict request/response contracts for the proxy gateway API.
"""

from __future__ import annotations

from datetime import datetime
from typing import Any, Optional
from uuid import uuid4

from pydantic import BaseModel, Field


# ═══════════════════════════════════════════════════════════════════
#  Request Models
# ═══════════════════════════════════════════════════════════════════

class QueryRequest(BaseModel):
    """Inbound query from the mobile client."""

    session_id: str = Field(
        ..., description="Tokenized session identifier (no PII)"
    )
    query: str = Field(
        ..., min_length=1, max_length=2000, description="User query text"
    )
    language: str = Field(
        default="en",
        description="ISO 639-1 language code for response",
    )
    context: dict[str, Any] = Field(
        default_factory=dict,
        description="Optional contextual metadata (form type, screen ID, etc.)",
    )


class KFSRequest(BaseModel):
    """Parameters for Key Fact Statement generation."""

    principal: float = Field(..., gt=0, description="Loan principal amount in INR")
    tenure_months: int = Field(..., gt=0, description="Loan tenure in months")
    interest_rate: float = Field(
        ..., ge=0, description="Nominal annual interest rate (%)"
    )
    processing_fee: float = Field(
        default=0.0, ge=0, description="Processing fee in INR"
    )
    other_charges: float = Field(
        default=0.0, ge=0, description="Other upfront charges in INR"
    )
    insurance_premium: float = Field(
        default=0.0, ge=0, description="Insurance premium if linked to loan"
    )


class RateLookupRequest(BaseModel):
    """Parameters for structured rate lookup."""

    account_type: str = Field(
        ..., description="Account type: 'savings', 'term_deposit'"
    )
    tenure_days: Optional[int] = Field(
        default=None, ge=1, description="Tenure in days (for term deposits)"
    )
    depositor_category: str = Field(
        default="general",
        description="Depositor category: 'general', 'senior_citizen'",
    )


# ═══════════════════════════════════════════════════════════════════
#  Response Models
# ═══════════════════════════════════════════════════════════════════

class Citation(BaseModel):
    """Source citation from the compliance knowledge base."""

    source_document: str = Field(..., description="Document filename or title")
    section: str = Field(default="", description="Section/clause reference")
    page: Optional[int] = Field(default=None, description="Page number if available")
    relevance_score: float = Field(
        default=0.0, description="Similarity score from vector search"
    )

class ActionIntent(BaseModel):
    """Layer 2: Dual-Channel Cryptographic Handshake for Native Actions."""
    
    action_type: str = Field(..., description="E.g., BLOCK_CARD, TRANSFER_FUNDS")
    parameters: dict[str, Any] = Field(default_factory=dict)
    risk_tier: str = Field(..., description="LOW, MEDIUM, or HIGH")
    action_token: str = Field(..., description="Cryptographically signed state token")


class VerificationResult(BaseModel):
    """Outcome of the deterministic verification pass."""

    passed: bool = Field(
        ..., description="True if all claims passed verification"
    )
    flags: list[str] = Field(
        default_factory=list,
        description="List of verification flag messages",
    )
    corrected_value: Optional[str] = Field(
        default=None,
        description="Corrected response text if verification failed",
    )
    rules_applied: list[str] = Field(
        default_factory=list,
        description="List of rule IDs that were evaluated",
    )


class QueryResponse(BaseModel):
    """Full verified response to a user query."""

    session_id: str
    answer: str = Field(..., description="Final verified response text")
    verified: bool = Field(
        ..., description="Whether the response passed all verification checks"
    )
    confidence: float = Field(
        ..., ge=0.0, le=1.0, description="Retrieval confidence score"
    )
    citations: list[Citation] = Field(default_factory=list)
    verification: VerificationResult
    action_intent: Optional[ActionIntent] = Field(
        default=None, description="Detected action for native execution"
    )
    audit_id: str = Field(
        default_factory=lambda: str(uuid4()),
        description="Unique audit trail identifier",
    )


class RateLookupResponse(BaseModel):
    """Structured rate lookup result."""

    account_type: str
    depositor_category: str
    tenure_days: Optional[int] = None
    rate: Optional[float] = Field(
        default=None, description="Interest rate in % p.a."
    )
    effective_date: Optional[str] = None
    found: bool = Field(
        ..., description="Whether a matching rate was found"
    )
    details: dict[str, Any] = Field(default_factory=dict)


class KFSResponse(BaseModel):
    """Generated Key Fact Statement."""

    loan_amount: float
    tenure_months: int
    nominal_rate: float
    apr: float = Field(..., description="Annual Percentage Rate (%)")
    emi: float = Field(..., description="Equated Monthly Installment in INR")
    total_interest: float
    total_cost_of_credit: float
    processing_fee: float
    other_charges: float
    insurance_premium: float
    cooling_off_days: int = Field(
        default=3, description="RBI-mandated cooling-off period in working days"
    )
    penal_charges_disclosure: str = Field(
        default="Penal charges, if applicable, will be levied as per RBI guidelines and are excluded from APR computation."
    )
    generated_at: datetime = Field(default_factory=datetime.utcnow)
    disclaimer: str = Field(
        default="This KFS is generated as per RBI Digital Lending Directions, 2025. Any fee not disclosed herein cannot be legally enforced."
    )


# ═══════════════════════════════════════════════════════════════════
#  Audit Models
# ═══════════════════════════════════════════════════════════════════

class AuditEntry(BaseModel):
    """Immutable audit trail record for a single transaction."""

    audit_id: str = Field(default_factory=lambda: str(uuid4()))
    timestamp: datetime = Field(default_factory=datetime.utcnow)
    session_id: str
    query: str
    raw_response: str = Field(
        ..., description="Original unverified LLM output"
    )
    verified_response: str = Field(
        ..., description="Post-verification response (may be modified)"
    )
    verification_passed: bool
    verification_flags: list[str] = Field(default_factory=list)
    citations: list[Citation] = Field(default_factory=list)
    rules_applied: list[str] = Field(default_factory=list)
    confidence: float = 0.0
    request_metadata: dict[str, Any] = Field(default_factory=dict)


class HealthResponse(BaseModel):
    """Health check response."""

    status: str = "ok"
    version: str = "0.1.0"
    vector_store_ready: bool = False
    documents_indexed: int = 0
    timestamp: datetime = Field(default_factory=datetime.utcnow)


class IngestResponse(BaseModel):
    """Response from document ingestion."""

    status: str
    documents_processed: int
    total_chunks: int
    collection_name: str
    errors: list[str] = Field(default_factory=list)
