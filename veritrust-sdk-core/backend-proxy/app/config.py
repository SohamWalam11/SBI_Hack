"""
VeriTrust AI — Immutable Configuration
=======================================
All system parameters loaded from environment variables with strict defaults.
No runtime mutation of these values is permitted.
"""

from __future__ import annotations

import os
from pathlib import Path
from functools import lru_cache

from pydantic_settings import BaseSettings
from pydantic import Field


class Settings(BaseSettings):
    """Immutable application configuration sourced from environment."""

    # ── LLM Provider ──────────────────────────────────────────────
    GEMINI_API_KEY: str = Field(
        default="",
        description="Google Gemini API key for LLM inference",
    )
    LLM_MODEL: str = Field(
        default="gemini-2.0-flash",
        description="Gemini model identifier",
    )
    LLM_TEMPERATURE: float = Field(
        default=0.1,
        description="Low temperature for deterministic outputs",
    )
    LLM_MAX_TOKENS: int = Field(
        default=2048,
        description="Maximum output tokens per generation",
    )

    # ── Vector Store ──────────────────────────────────────────────
    CHROMA_PERSIST_DIR: str = Field(
        default="./chroma_db",
        description="ChromaDB persistent storage directory",
    )
    CHROMA_COLLECTION_NAME: str = Field(
        default="veritrust_compliance",
        description="Collection name for compliance documents",
    )
    EMBEDDING_MODEL: str = Field(
        default="all-MiniLM-L6-v2",
        description="Sentence-transformer model for embeddings",
    )

    # ── Document Processing ───────────────────────────────────────
    CHUNK_SIZE: int = Field(default=500, description="Characters per chunk")
    CHUNK_OVERLAP: int = Field(default=50, description="Overlap between chunks")
    MAX_RETRIEVAL_RESULTS: int = Field(
        default=5, description="Top-K results from vector search"
    )

    # ── Paths ─────────────────────────────────────────────────────
    STRUCTURED_DATA_DIR: str = Field(
        default="./data/structured",
        description="Directory containing structured JSON data files",
    )
    COMPLIANCE_SOURCE_DIR: str = Field(
        default="../../data",
        description="Directory containing source compliance PDFs",
    )
    AUDIT_LOG_DIR: str = Field(
        default="./audit_logs",
        description="Append-only audit log directory",
    )

    # ── Server ────────────────────────────────────────────────────
    APP_HOST: str = Field(default="0.0.0.0")
    APP_PORT: int = Field(default=8000)
    CORS_ORIGINS: list[str] = Field(
        default=["*"],
        description="Allowed CORS origins (restrict in production)",
    )

    # ── Verification Thresholds ───────────────────────────────────
    RATE_TOLERANCE_BPS: float = Field(
        default=0.0,
        description="Tolerance in basis points for rate verification (0 = exact match)",
    )
    CONFIDENCE_THRESHOLD: float = Field(
        default=0.75,
        description="Minimum similarity score to consider a retrieval relevant",
    )

    class Config:
        env_file = ".env"
        env_file_encoding = "utf-8"
        case_sensitive = True


@lru_cache()
def get_settings() -> Settings:
    """Singleton accessor for immutable settings."""
    return Settings()
