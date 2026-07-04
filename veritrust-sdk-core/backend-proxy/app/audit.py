"""
VeriTrust AI — Append-Only Audit Trail
========================================
Every transaction through the proxy gateway produces an immutable audit record.
Records are stored as JSON Lines (.jsonl) files partitioned by date.
This provides out-of-the-box compliance for RBI regulatory audits.
"""

from __future__ import annotations

import json
import os
from datetime import datetime, date
from pathlib import Path
from typing import Optional

from app.config import get_settings
from app.schemas import AuditEntry


class AuditLogger:
    """Append-only audit trail manager."""

    def __init__(self, log_dir: Optional[str] = None):
        settings = get_settings()
        self._log_dir = Path(log_dir or settings.AUDIT_LOG_DIR)
        self._log_dir.mkdir(parents=True, exist_ok=True)

    def _get_log_path(self, for_date: Optional[date] = None) -> Path:
        """Get the log file path for a given date (defaults to today)."""
        target_date = for_date or date.today()
        filename = f"audit_{target_date.isoformat()}.jsonl"
        return self._log_dir / filename

    def log_transaction(self, entry: AuditEntry) -> str:
        """
        Append audit entry to the daily log file.
        Returns the audit_id for reference.
        """
        log_path = self._get_log_path()
        record = entry.model_dump(mode="json")
        # Ensure datetime serialization
        for key, value in record.items():
            if isinstance(value, datetime):
                record[key] = value.isoformat()

        with open(log_path, "a", encoding="utf-8") as f:
            f.write(json.dumps(record, ensure_ascii=False, default=str) + "\n")

        return entry.audit_id

    def get_audit_trail(self, session_id: str) -> list[dict]:
        """
        Retrieve all audit entries for a given session ID.
        Scans all log files in the directory.
        """
        entries = []
        for log_file in sorted(self._log_dir.glob("audit_*.jsonl")):
            with open(log_file, "r", encoding="utf-8") as f:
                for line in f:
                    line = line.strip()
                    if not line:
                        continue
                    try:
                        record = json.loads(line)
                        if record.get("session_id") == session_id:
                            entries.append(record)
                    except json.JSONDecodeError:
                        continue
        return entries

    def get_entry_by_id(self, audit_id: str) -> Optional[dict]:
        """Retrieve a specific audit entry by its audit_id."""
        for log_file in sorted(self._log_dir.glob("audit_*.jsonl"), reverse=True):
            with open(log_file, "r", encoding="utf-8") as f:
                for line in f:
                    line = line.strip()
                    if not line:
                        continue
                    try:
                        record = json.loads(line)
                        if record.get("audit_id") == audit_id:
                            return record
                    except json.JSONDecodeError:
                        continue
        return None

    def get_stats(self) -> dict:
        """Return summary statistics of audit logs."""
        total_entries = 0
        total_verified = 0
        total_failed = 0
        log_files = list(self._log_dir.glob("audit_*.jsonl"))

        for log_file in log_files:
            with open(log_file, "r", encoding="utf-8") as f:
                for line in f:
                    line = line.strip()
                    if not line:
                        continue
                    try:
                        record = json.loads(line)
                        total_entries += 1
                        if record.get("verification_passed"):
                            total_verified += 1
                        else:
                            total_failed += 1
                    except json.JSONDecodeError:
                        continue

        return {
            "total_entries": total_entries,
            "total_verified": total_verified,
            "total_failed": total_failed,
            "log_files_count": len(log_files),
            "log_directory": str(self._log_dir),
        }


# ── Module-level singleton ────────────────────────────────────────
_audit_logger: Optional[AuditLogger] = None


def get_audit_logger() -> AuditLogger:
    """Get or create the singleton audit logger instance."""
    global _audit_logger
    if _audit_logger is None:
        _audit_logger = AuditLogger()
    return _audit_logger
