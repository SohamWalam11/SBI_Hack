"""
VeriTrust AI — RAG Engine
===========================
Metadata-rich vector retrieval pipeline for compliance document Q&A.

Pipeline:  PDF Ingestion → Chunking → Embedding → ChromaDB → Retrieval → LLM Generation

The engine enforces strict grounding: the LLM may ONLY answer from retrieved context
and must return INSUFFICIENT_CONTEXT if the source material doesn't cover the query.
"""

from __future__ import annotations

import hashlib
import logging
import os
import re
from pathlib import Path
from typing import Optional

import chromadb
from chromadb.utils import embedding_functions
from google.generativeai.types import HarmCategory, HarmBlockThreshold
from pypdf import PdfReader

from app.config import get_settings
from app.security import sign_action_token

logger = logging.getLogger("veritrust.rag")


# ═══════════════════════════════════════════════════════════════════
#  System Prompt — Strict Grounding
# ═══════════════════════════════════════════════════════════════════

SYSTEM_PROMPT = """You are VeriTrust AI, a deterministic compliance assistant for State Bank of India (SBI) deployed within the YONO 2.0 mobile banking platform.

STRICT RULES — VIOLATION IS UNACCEPTABLE:
1. For ANY banking, financial, policy, or regulatory query, answer ONLY from the provided context documents. Never use external knowledge.
2. For every factual claim, cite the exact source document name and section/clause number.
3. If the context does not contain enough information to answer a banking query, respond ONLY with: "INSUFFICIENT_CONTEXT: The provided compliance documents do not contain information to answer this query. Please contact SBI customer support at 1800-11-2211."
4. NEVER fabricate interest rates, fees, dates, percentages, or any numerical values.
5. If the user asks a general non-banking question or a greeting (e.g. "hi", "who are you", "how are you"), you may respond politely and naturally without requiring context documents. Just act as a helpful AI assistant.
6. For regulatory queries, always reference the specific RBI Master Direction or Circular.
7. Respond in the language requested by the user. Default is English.
8. Keep responses concise, factual, and professional.

AGENTIC ACTIONS:
If the user asks to perform an action, you must extract their intent and output it exactly at the end of your response in this format:
[INTENT: ACTION_TYPE]
[PARAMS: {"key": "value"}]

Supported Actions:
- BLOCK_CARD (e.g., "I lost my debit card, please block it.", outputs PARAMS: {})
- TRANSFER_FUNDS (e.g., "Transfer 500 rupees to Mom", outputs PARAMS: {"amount": 500, "payee": "Mom"})

FORMAT:
- Use bullet points for multiple items
- Bold key terms and values
- Include [Source: document_name, Section X.X] citations inline
"""


class RAGEngine:
    """Semantic retrieval and grounded generation engine."""

    def __init__(self):
        self._settings = get_settings()
        self._client: Optional[chromadb.PersistentClient] = None
        self._collection = None
        self._embedding_fn = None
        self._llm = None

    def _ensure_initialized(self):
        """Lazy initialization of ChromaDB client and embedding function."""
        if self._client is not None and self._collection is not None:
            return

        self._client = chromadb.PersistentClient(
            path=self._settings.CHROMA_PERSIST_DIR
        )

        self._embedding_fn = embedding_functions.SentenceTransformerEmbeddingFunction(
            model_name=self._settings.EMBEDDING_MODEL
        )

        self._collection = self._client.get_or_create_collection(
            name=self._settings.CHROMA_COLLECTION_NAME,
            embedding_function=self._embedding_fn,
            metadata={"hnsw:space": "cosine"},
        )

        logger.info(
            "ChromaDB initialized — collection '%s' has %d documents",
            self._settings.CHROMA_COLLECTION_NAME,
            self._collection.count(),
        )

    def _init_llm(self):
        """Initialize the Google Gemini LLM client."""
        if self._llm is not None:
            return

        import google.generativeai as genai

        api_key = self._settings.GEMINI_API_KEY
        if not api_key:
            raise ValueError(
                "GEMINI_API_KEY is not set. Please configure it in .env or environment."
            )

        genai.configure(api_key=api_key)
        self._llm = genai.GenerativeModel(
            model_name=self._settings.LLM_MODEL,
            system_instruction=SYSTEM_PROMPT,
            generation_config=genai.GenerationConfig(
                temperature=self._settings.LLM_TEMPERATURE,
                max_output_tokens=self._settings.LLM_MAX_TOKENS,
            ),
        )
        logger.info("Gemini LLM initialized — model: %s", self._settings.LLM_MODEL)

    # ── Document Ingestion ────────────────────────────────────────

    def _extract_text_from_pdf(self, pdf_path: Path) -> list[dict]:
        """
        Extract text from a PDF, returning a list of
        {text, page, source} dicts per page.
        """
        reader = PdfReader(str(pdf_path))
        pages = []
        for i, page in enumerate(reader.pages):
            text = page.extract_text()
            if text and text.strip():
                pages.append({
                    "text": text.strip(),
                    "page": i + 1,
                    "source": pdf_path.name,
                })
        return pages

    def _chunk_text(
        self, text: str, chunk_size: int, overlap: int
    ) -> list[str]:
        """Split text into overlapping chunks."""
        chunks = []
        start = 0
        while start < len(text):
            end = start + chunk_size
            chunk = text[start:end]
            if chunk.strip():
                chunks.append(chunk.strip())
            start = end - overlap
        return chunks

    def _generate_chunk_id(self, source: str, page: int, chunk_idx: int) -> str:
        """Deterministic chunk ID from source metadata."""
        raw = f"{source}::page{page}::chunk{chunk_idx}"
        return hashlib.md5(raw.encode()).hexdigest()

    def ingest_documents(self, force: bool = False) -> dict:
        """
        Ingest all PDFs from the compliance source directory into ChromaDB.

        Args:
            force: If True, re-ingest even if documents already exist.

        Returns:
            Summary dict with document and chunk counts.
        """
        self._ensure_initialized()

        source_dir = Path(self._settings.COMPLIANCE_SOURCE_DIR)
        if not source_dir.exists():
            raise FileNotFoundError(f"Compliance source directory not found: {source_dir}")

        pdf_files = list(source_dir.glob("*.pdf"))
        if not pdf_files:
            return {
                "status": "no_documents",
                "documents_processed": 0,
                "total_chunks": 0,
            }

        # Skip if already ingested (unless forced)
        if not force and self._collection.count() > 0:
            logger.info("Documents already ingested (%d chunks). Skipping.", self._collection.count())
            return {
                "status": "already_ingested",
                "documents_processed": 0,
                "total_chunks": self._collection.count(),
            }

        all_ids = []
        all_documents = []
        all_metadatas = []
        errors = []
        docs_processed = 0

        for pdf_path in pdf_files:
            try:
                logger.info("Ingesting: %s", pdf_path.name)
                pages = self._extract_text_from_pdf(pdf_path)

                for page_data in pages:
                    chunks = self._chunk_text(
                        page_data["text"],
                        self._settings.CHUNK_SIZE,
                        self._settings.CHUNK_OVERLAP,
                    )
                    for idx, chunk in enumerate(chunks):
                        chunk_id = self._generate_chunk_id(
                            page_data["source"], page_data["page"], idx
                        )
                        all_ids.append(chunk_id)
                        all_documents.append(chunk)
                        all_metadatas.append({
                            "source": page_data["source"],
                            "page": page_data["page"],
                            "chunk_index": idx,
                            "char_count": len(chunk),
                        })

                docs_processed += 1
            except Exception as e:
                error_msg = f"Error processing {pdf_path.name}: {str(e)}"
                logger.error(error_msg)
                errors.append(error_msg)

        # Batch upsert into ChromaDB
        if all_ids:
            # ChromaDB has a batch limit, process in chunks of 500
            batch_size = 500
            for i in range(0, len(all_ids), batch_size):
                batch_end = i + batch_size
                self._collection.upsert(
                    ids=all_ids[i:batch_end],
                    documents=all_documents[i:batch_end],
                    metadatas=all_metadatas[i:batch_end],
                )

        logger.info(
            "Ingestion complete — %d documents, %d chunks",
            docs_processed,
            len(all_ids),
        )

        return {
            "status": "completed",
            "documents_processed": docs_processed,
            "total_chunks": len(all_ids),
            "collection_name": self._settings.CHROMA_COLLECTION_NAME,
            "errors": errors,
        }

    # ── Retrieval ─────────────────────────────────────────────────

    def retrieve(
        self, query: str, n_results: Optional[int] = None
    ) -> list[dict]:
        """
        Retrieve the most relevant document chunks for a query.

        Returns:
            List of dicts with keys: text, source, page, score
        """
        self._ensure_initialized()

        n = n_results or self._settings.MAX_RETRIEVAL_RESULTS

        if self._collection.count() == 0:
            logger.warning("Vector store is empty — no documents to retrieve from.")
            return []

        results = self._collection.query(
            query_texts=[query],
            n_results=min(n, self._collection.count()),
            include=["documents", "metadatas", "distances"],
        )

        retrieved = []
        if results and results["documents"]:
            for doc, meta, dist in zip(
                results["documents"][0],
                results["metadatas"][0],
                results["distances"][0],
            ):
                # ChromaDB cosine distance: 0 = identical, 2 = opposite
                # Convert to similarity score: 1 - (distance / 2)
                similarity = 1.0 - (dist / 2.0)
                retrieved.append({
                    "text": doc,
                    "source": meta.get("source", "unknown"),
                    "page": meta.get("page", 0),
                    "chunk_index": meta.get("chunk_index", 0),
                    "score": round(similarity, 4),
                })

        return retrieved

    # ── Generation ────────────────────────────────────────────────

    def generate_answer(
        self, query: str, context_chunks: list[dict], language: str = "en"
    ) -> dict:
        """
        Generate a grounded answer from retrieved context using the LLM.

        Returns:
            Dict with keys: answer, citations, confidence
        """
        self._init_llm()

        # Build context block
        context_block = ""
        if context_chunks:
            context_block = "\n\n---\n\n".join(
                f"[Source: {c['source']}, Page {c['page']}]\n{c['text']}"
                for c in context_chunks
            )

        # Build language instruction
        lang_instruction = ""
        if language != "en":
            lang_instruction = f"\n\nIMPORTANT: Respond in language code '{language}'. Translate your response naturally while keeping technical terms, rates, and citations in English."

        intent_instruction = """
If the user's query is a clear request to perform a banking action (e.g. blocking a card, transferring funds), append the following intent block to the very END of your response exactly as shown:
[INTENT: <ACTION_TYPE>]
[PARAMS: {"key": "value"}]
Where ACTION_TYPE is BLOCK_CARD or TRANSFER_FUNDS etc. Do not include this block if it's just a general question.
"""

        # Construct prompt
        user_prompt = f"""CONTEXT DOCUMENTS:
{context_block}

USER QUERY: {query}
{lang_instruction}
{intent_instruction}

Provide a comprehensive, accurately cited answer based ONLY on the above context documents."""

        # Call LLM
        response = self._llm.generate_content(user_prompt)
        answer_text = response.text if response.text else "INSUFFICIENT_CONTEXT: Unable to generate response."

        # Build citations from chunks used
        citations = [
            {
                "source_document": c["source"],
                "section": "",
                "page": c["page"],
                "relevance_score": c["score"],
            }
            for c in context_chunks
        ]

        # Compute average confidence
        avg_confidence = (
            sum(c["score"] for c in context_chunks) / len(context_chunks)
            if context_chunks
            else 0.0
        )

        import re, json
        action_intent = None
        intent_match = re.search(r'\[INTENT:\s*([^\]]+)\]\n\[PARAMS:\s*(.+?)\]', answer_text, re.IGNORECASE)
        if intent_match:
            action_type = intent_match.group(1).strip()
            try:
                params = json.loads(intent_match.group(2).strip())
                risk_tier = "HIGH" if action_type in ["BLOCK_CARD", "TRANSFER_FUNDS"] else "LOW"
                action_token = sign_action_token(action_type, params, risk_tier)
                action_intent = {
                    "action_type": action_type,
                    "parameters": params,
                    "risk_tier": risk_tier,
                    "action_token": action_token
                }
                # Remove the intent block from the final answer text shown to user
                answer_text = answer_text[:intent_match.start()].strip()
            except Exception as e:
                pass

        return {
            "answer": answer_text,
            "citations": citations,
            "confidence": round(avg_confidence, 4),
            "action_intent": action_intent
        }

    # ── Full Pipeline ─────────────────────────────────────────────

    def query(self, query: str, language: str = "en") -> dict:
        """
        Full RAG pipeline: Retrieve → Generate.
        Returns the raw (unverified) response for the verifier.
        """
        chunks = self.retrieve(query)

        # Filter by confidence threshold
        settings = get_settings()
        relevant_chunks = [
            c for c in chunks
            if c["score"] >= settings.CONFIDENCE_THRESHOLD
        ]

        # Fall back to all chunks if none pass threshold
        if not relevant_chunks and chunks:
            relevant_chunks = chunks[:3]  # Use top 3 anyway

        result = self.generate_answer(query, relevant_chunks, language)
        result["retrieved_chunks"] = relevant_chunks
        return result

    # ── Status ────────────────────────────────────────────────────

    def get_status(self) -> dict:
        """Return current status of the vector store."""
        self._ensure_initialized()
        return {
            "collection_name": self._settings.CHROMA_COLLECTION_NAME,
            "document_count": self._collection.count(),
            "embedding_model": self._settings.EMBEDDING_MODEL,
            "persist_dir": self._settings.CHROMA_PERSIST_DIR,
        }


# ── Module-level singleton ────────────────────────────────────────
_rag_engine: Optional[RAGEngine] = None


def get_rag_engine() -> RAGEngine:
    """Get or create the singleton RAG engine instance."""
    global _rag_engine
    if _rag_engine is None:
        _rag_engine = RAGEngine()
    return _rag_engine
