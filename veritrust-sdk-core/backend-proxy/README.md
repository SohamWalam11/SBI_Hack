# VeriTrust AI — Backend Proxy (Core B)

> Deterministic Verifier Gateway for SBI YONO 2.0

## Overview

Core B is a FastAPI-based proxy gateway that sits between the conversational AI layer and the client. Every LLM response passes through deterministic boolean verification before reaching the user.

## Quick Start

```bash
# 1. Install dependencies
pip install -r requirements.txt

# 2. Set environment variables
export GEMINI_API_KEY="your-api-key-here"

# 3. Run the server
uvicorn app.main:app --reload --port 8000

# 4. Trigger document ingestion
curl -X POST http://localhost:8000/api/v1/ingest
```

## API Endpoints

| Method | Path | Description |
|--------|------|-------------|
| `POST` | `/api/v1/query` | Main query — RAG → Verify → Respond |
| `POST` | `/api/v1/query/stream` | SSE streaming variant |
| `POST` | `/api/v1/ingest` | Ingest PDFs into vector store |
| `GET`  | `/api/v1/rates/{type}` | Deterministic rate lookup |
| `POST` | `/api/v1/kfs/generate` | Generate Key Fact Statement |
| `GET`  | `/api/v1/audit/{session}` | Retrieve audit trail |
| `GET`  | `/api/v1/health` | Health check |

## Architecture

```
Query → PII Redaction → RAG Retrieval → LLM Generation →
  Deterministic Verification → Audit Logging → Response
```

## Docker

```bash
docker build -t veritrust-backend .
docker run -p 8000:8000 -e GEMINI_API_KEY=your-key veritrust-backend
```
