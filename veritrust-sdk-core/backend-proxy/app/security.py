import hmac
import hashlib
import json
import base64
import os
from datetime import datetime, timedelta
from typing import Any

# Layer 2: Dual-Channel Cryptographic Handshake Secret
SECRET_KEY = os.getenv("VERITRUST_SECRET_KEY", "super_secret_hackathon_key_2026")

def sign_action_token(action_type: str, parameters: dict[str, Any], risk_tier: str) -> str:
    """Generate a signed ephemeral action token for native execution."""
    payload = {
        "action": action_type,
        "params": parameters,
        "risk": risk_tier,
        "exp": (datetime.utcnow() + timedelta(minutes=5)).timestamp()
    }
    
    payload_bytes = json.dumps(payload, sort_keys=True).encode('utf-8')
    payload_b64 = base64.urlsafe_b64encode(payload_bytes).decode('utf-8').rstrip("=")
    
    signature = hmac.new(SECRET_KEY.encode(), payload_b64.encode(), hashlib.sha256).digest()
    signature_b64 = base64.urlsafe_b64encode(signature).decode('utf-8').rstrip("=")
    
    return f"{payload_b64}.{signature_b64}"

def verify_action_token(token: str) -> dict[str, Any]:
    """Verify an action token and return its payload."""
    try:
        payload_b64, signature_b64 = token.split(".")
        
        # Re-compute signature
        expected_sig = hmac.new(SECRET_KEY.encode(), payload_b64.encode(), hashlib.sha256).digest()
        expected_sig_b64 = base64.urlsafe_b64encode(expected_sig).decode('utf-8').rstrip("=")
        
        if not hmac.compare_digest(signature_b64, expected_sig_b64):
            raise ValueError("Invalid signature")
            
        payload_bytes = base64.urlsafe_b64decode(payload_b64 + "=" * (4 - len(payload_b64) % 4))
        payload = json.loads(payload_bytes)
        
        if payload.get("exp", 0) < datetime.utcnow().timestamp():
            raise ValueError("Token expired")
            
        return payload
    except Exception as e:
        raise ValueError(f"Token verification failed: {e}")
