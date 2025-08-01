"""Protection modules for FastAPI Guard"""

from fastapi_guard.protection.waf import WAFProtection
from fastapi_guard.protection.bot_detection import BotDetector  
from fastapi_guard.protection.ip_blocklist import IPBlocklistManager
from fastapi_guard.utils.security_utils import SecurityDecision

__all__ = [
    "WAFProtection",
    "BotDetector", 
    "IPBlocklistManager",
    "SecurityDecision"
]