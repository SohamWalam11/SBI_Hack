"""
VeriTrust AI — FastAPI Gateway (Core B)
=========================================
Main application entry point. Orchestrates the full pipeline:
  Query → PII Redaction → RAG Retrieval → LLM Generation →
  Deterministic Verification → Audit Logging → Response

All responses are verified before reaching the client.
"""

from __future__ import annotations

import logging
import time
import uuid
from contextlib import asynccontextmanager
from datetime import datetime
from typing import AsyncGenerator

from fastapi import FastAPI, HTTPException, Request, File, UploadFile
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse, StreamingResponse

from app import __version__, __app_name__
from app.config import get_settings
from app.schemas import (
    AuditEntry,
    Citation,
    HealthResponse,
    IngestResponse,
    KFSRequest,
    KFSResponse,
    QueryRequest,
    QueryResponse,
    RateLookupResponse,
    VerificationResult,
)
from app.redactor import redact_all, contains_pii
from app.audit import get_audit_logger
from app.rag_engine import get_rag_engine
from app.rules_engine import get_rules_engine
from app.verifier import run_full_verification
from app.stt_engine import transcribe_audio

# ── Logging ───────────────────────────────────────────────────────
logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s | %(name)-25s | %(levelname)-7s | %(message)s",
    datefmt="%Y-%m-%d %H:%M:%S",
)
logger = logging.getLogger("veritrust.api")


# ── Lifespan ──────────────────────────────────────────────────────

@asynccontextmanager
async def lifespan(app: FastAPI):
    """Startup and shutdown events."""
    logger.info("🚀 VeriTrust AI Backend Proxy v%s starting...", __version__)

    # Auto-ingest documents if vector store is empty
    try:
        rag = get_rag_engine()
        status = rag.get_status()
        if status["document_count"] == 0:
            logger.info("Vector store is empty — auto-ingesting compliance documents...")
            result = rag.ingest_documents()
            logger.info("Auto-ingestion result: %s", result)
        else:
            logger.info(
                "Vector store ready — %d chunks indexed", status["document_count"]
            )
    except Exception as e:
        logger.warning("Auto-ingestion skipped: %s", str(e))

    yield

    logger.info("🛑 VeriTrust AI Backend Proxy shutting down...")


# ── App Initialization ────────────────────────────────────────────

settings = get_settings()

app = FastAPI(
    title=__app_name__,
    version=__version__,
    description=(
        "Deterministic Verifier Gateway for SBI YONO 2.0. "
        "All LLM responses are verified against structured data and "
        "compliance documents before reaching the client."
    ),
    lifespan=lifespan,
)

# CORS Middleware
app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.CORS_ORIGINS,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


# ── Middleware: Request ID & PII Redaction ────────────────────────

@app.middleware("http")
async def add_request_id(request: Request, call_next):
    """Inject a unique request ID and measure latency."""
    request_id = str(uuid.uuid4())
    start_time = time.time()

    response = await call_next(request)

    latency_ms = (time.time() - start_time) * 1000
    response.headers["X-Request-ID"] = request_id
    response.headers["X-Latency-Ms"] = f"{latency_ms:.2f}"

    logger.info(
        "request_id=%s method=%s path=%s status=%d latency=%.2fms",
        request_id,
        request.method,
        request.url.path,
        response.status_code,
        latency_ms,
    )
    return response


# ═══════════════════════════════════════════════════════════════════
#  API Endpoints
# ═══════════════════════════════════════════════════════════════════


@app.get("/api/v1/health", response_model=HealthResponse, tags=["System"])
async def health_check():
    """Health check endpoint with system status."""
    try:
        rag = get_rag_engine()
        status = rag.get_status()
        return HealthResponse(
            status="ok",
            version=__version__,
            vector_store_ready=status["document_count"] > 0,
            documents_indexed=status["document_count"],
        )
    except Exception as e:
        return HealthResponse(
            status="degraded",
            version=__version__,
            vector_store_ready=False,
            documents_indexed=0,
        )


# ── Document Ingestion ────────────────────────────────────────────

@app.post("/api/v1/ingest", response_model=IngestResponse, tags=["Ingestion"])
async def ingest_documents(force: bool = False):
    """
    Trigger ingestion of compliance PDFs into the vector store.

    Args:
        force: If True, re-ingest even if documents already exist.
    """
    try:
        rag = get_rag_engine()
        result = rag.ingest_documents(force=force)
        return IngestResponse(
            status=result.get("status", "completed"),
            documents_processed=result.get("documents_processed", 0),
            total_chunks=result.get("total_chunks", 0),
            collection_name=result.get("collection_name", settings.CHROMA_COLLECTION_NAME),
            errors=result.get("errors", []),
        )
    except FileNotFoundError as e:
        raise HTTPException(status_code=404, detail=str(e))
    except Exception as e:
        logger.error("Ingestion failed: %s", str(e))
        raise HTTPException(status_code=500, detail=f"Ingestion failed: {str(e)}")


# ── Main Query Endpoint ──────────────────────────────────────────

@app.post("/api/v1/query", response_model=QueryResponse, tags=["Query"])
async def query(request: QueryRequest):
    """
    Main query endpoint — runs the full RAG → Verify → Respond pipeline.

    1. Redacts PII from inbound query
    2. Retrieves relevant compliance context via RAG
    3. Generates grounded LLM response
    4. Runs deterministic verification on all claims
    5. Logs audit trail
    6. Returns verified response (or safe-fail)
    """
    audit_id = str(uuid.uuid4())
    audit_logger = get_audit_logger()

    try:
        # Step 1: PII Redaction on inbound query
        redacted_query = redact_all(request.query)
        if contains_pii(request.query):
            logger.warning(
                "session=%s — PII detected and redacted from inbound query",
                request.session_id,
            )

        # Step 2: RAG Pipeline (Retrieve + Generate)
        rag = get_rag_engine()
        rag_result = rag.query(redacted_query, request.language)

        raw_response = rag_result["answer"]
        citations_raw = rag_result.get("citations", [])
        confidence = rag_result.get("confidence", 0.0)
        action_intent_raw = rag_result.get("action_intent")

        # Build Citation objects
        citations = [
            Citation(
                source_document=c.get("source_document", ""),
                section=c.get("section", ""),
                page=c.get("page"),
                relevance_score=c.get("relevance_score", 0.0),
            )
            for c in citations_raw
        ]

        # Step 3: Deterministic Verification
        verification_output = run_full_verification(
            raw_response,
            [c.model_dump() for c in citations],
        )

        verified_response = verification_output["verified_response"]
        verification_result: VerificationResult = verification_output["verification_result"]

        # Step 4: Audit Logging
        audit_entry = AuditEntry(
            audit_id=audit_id,
            session_id=request.session_id,
            query=redacted_query,
            raw_response=raw_response,
            verified_response=verified_response,
            verification_passed=verification_result.passed,
            verification_flags=verification_result.flags,
            citations=citations,
            rules_applied=verification_result.rules_applied,
            confidence=confidence,
            request_metadata=request.context,
        )
        audit_logger.log_transaction(audit_entry)

        # Step 5: Return verified response
        return QueryResponse(
            session_id=request.session_id,
            answer=verified_response,
            verified=verification_result.passed,
            confidence=confidence,
            citations=citations,
            verification=verification_result,
            action_intent=action_intent_raw,
            audit_id=audit_id,
        )

    except Exception as e:
        logger.error("Query pipeline error: %s", str(e), exc_info=True)

        # Log the failure
        try:
            audit_entry = AuditEntry(
                audit_id=audit_id,
                session_id=request.session_id,
                query=redact_all(request.query),
                raw_response=f"ERROR: {str(e)}",
                verified_response="An error occurred processing your request.",
                verification_passed=False,
                verification_flags=[f"PIPELINE_ERROR: {str(e)}"],
            )
            audit_logger.log_transaction(audit_entry)
        except Exception:
            pass

        raise HTTPException(
            status_code=500,
            detail="An error occurred processing your request. This has been logged.",
        )


# ── Streaming Query Endpoint ─────────────────────────────────────

@app.post("/api/v1/query/stream", tags=["Query"])
async def query_stream(request: QueryRequest):
    """
    SSE streaming variant of the query endpoint.
    Streams tokens in real-time, then sends verification status.
    """
    import json

    async def event_generator() -> AsyncGenerator[str, None]:
        try:
            # Redact PII
            redacted_query = redact_all(request.query)

            # RAG pipeline
            rag = get_rag_engine()
            rag_result = rag.query(redacted_query, request.language)

            raw_response = rag_result["answer"]
            citations_raw = rag_result.get("citations", [])
            confidence = rag_result.get("confidence", 0.0)

            # Stream the response in chunks
            words = raw_response.split(" ")
            buffer = ""
            for i, word in enumerate(words):
                buffer += word + " "
                if i % 3 == 0 or i == len(words) - 1:
                    event_data = json.dumps({
                        "type": "token",
                        "content": buffer.strip(),
                        "done": i == len(words) - 1,
                    })
                    yield f"data: {event_data}\n\n"
                    buffer = ""

            # Run verification
            verification_output = run_full_verification(
                raw_response,
                citations_raw,
            )

            # Send verification result
            verification_data = json.dumps({
                "type": "verification",
                "passed": verification_output["verification_result"].passed,
                "flags": verification_output["verification_result"].flags,
                "confidence": confidence,
                "citations": [
                    {"source": c.get("source_document", ""), "page": c.get("page")}
                    for c in citations_raw
                ],
            })
            yield f"data: {verification_data}\n\n"

            # Send done signal
            yield f"data: {json.dumps({'type': 'done'})}\n\n"

        except Exception as e:
            error_data = json.dumps({
                "type": "error",
                "message": str(e),
            })
            yield f"data: {error_data}\n\n"

    return StreamingResponse(
        event_generator(),
        media_type="text/event-stream",
        headers={
            "Cache-Control": "no-cache",
            "Connection": "keep-alive",
            "X-Accel-Buffering": "no",
        },
    )


# ── STT Endpoint ─────────────────────────────────────────────────

@app.post("/api/v1/transcribe", tags=["Voice"])
async def transcribe_endpoint(audio: UploadFile = File(...)):
    """
    Convert spoken audio to text using OpenAI Whisper.
    Supports multilingual input including Indian languages (Hindi, Tamil, Telugu, etc.)
    """
    try:
        text = await transcribe_audio(audio)
        return {"text": text}
    except Exception as e:
        logger.error(f"STT Error: {e}")
        raise HTTPException(status_code=500, detail=f"Transcription failed: {str(e)}")


# ── Rate Lookup ───────────────────────────────────────────────────

@app.get(
    "/api/v1/rates/{account_type}",
    response_model=RateLookupResponse,
    tags=["Structured Data"],
)
async def lookup_rate(
    account_type: str,
    tenure_days: int | None = None,
    depositor_category: str = "general",
):
    """
    Direct structured rate lookup from the SBI rate matrix.
    No LLM involved — pure deterministic lookup.
    """
    try:
        rules = get_rules_engine()
        result = rules.lookup_interest_rate(
            account_type=account_type,
            tenure_days=tenure_days,
            depositor_category=depositor_category,
        )

        return RateLookupResponse(
            account_type=account_type,
            depositor_category=depositor_category,
            tenure_days=tenure_days,
            rate=result.get("rate_percent_pa"),
            effective_date=result.get("effective_date"),
            found=result.get("found", False),
            details=result.get("details", {}),
        )
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


# ── KFS Generation ───────────────────────────────────────────────

@app.post(
    "/api/v1/kfs/generate",
    response_model=KFSResponse,
    tags=["Structured Data"],
)
async def generate_kfs(request: KFSRequest):
    """
    Generate a Key Fact Statement per RBI Digital Lending Directions.
    Computes APR using IRR method and populates all mandatory fields.
    """
    try:
        rules = get_rules_engine()
        kfs = rules.generate_kfs(
            principal=request.principal,
            tenure_months=request.tenure_months,
            interest_rate=request.interest_rate,
            processing_fee=request.processing_fee,
            other_charges=request.other_charges,
            insurance_premium=request.insurance_premium,
        )

        return KFSResponse(
            loan_amount=request.principal,
            tenure_months=request.tenure_months,
            nominal_rate=request.interest_rate,
            apr=kfs["cost_details"]["annual_percentage_rate"],
            emi=kfs["repayment_details"]["emi_amount"],
            total_interest=kfs["repayment_details"]["total_interest_payable"],
            total_cost_of_credit=kfs["repayment_details"]["total_cost_of_credit"],
            processing_fee=request.processing_fee,
            other_charges=request.other_charges,
            insurance_premium=request.insurance_premium,
        )
    except Exception as e:
        logger.error("KFS generation failed: %s", str(e))
        raise HTTPException(status_code=500, detail=str(e))


# ── Audit Trail ───────────────────────────────────────────────────

@app.get("/api/v1/audit/{session_id}", tags=["Audit"])
async def get_audit_trail(session_id: str):
    """Retrieve the complete audit trail for a session."""
    audit_logger = get_audit_logger()
    entries = audit_logger.get_audit_trail(session_id)
    return {
        "session_id": session_id,
        "entries": entries,
        "total": len(entries),
    }


@app.get("/api/v1/audit/stats/summary", tags=["Audit"])
async def get_audit_stats():
    """Get audit log statistics summary."""
    audit_logger = get_audit_logger()
    return audit_logger.get_stats()


# ═══════════════════════════════════════════════════════════════════
#  Entry Point
# ═══════════════════════════════════════════════════════════════════

if __name__ == "__main__":
    import uvicorn

    uvicorn.run(
        "app.main:app",
        host=settings.APP_HOST,
        port=settings.APP_PORT,
        reload=True,
        log_level="info",
    )
