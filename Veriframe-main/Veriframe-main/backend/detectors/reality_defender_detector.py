import os
import logging
import asyncio
from typing import Dict, Any, Optional
from config import config as app_config

logger = logging.getLogger("veriframe.detectors.reality_defender")

class RealityDefenderDetector:
    """
    Detector service that integrates Reality Defender API / SDK for media forensics and deepfake detection.
    """

    def __init__(self, api_key: Optional[str] = None):
        self.api_key = api_key or app_config.REALITY_DEFENDER_API_KEY or os.getenv("REALITY_DEFENDER_API_KEY", "")
        self._sdk_client = None

    def is_configured(self) -> bool:
        """Check if an API key is provided and not masked with ellipsis."""
        if not self.api_key:
            return False
        if "..." in self.api_key:
            logger.warning("[RealityDefenderDetector] API key appears masked (contains '...'). Please configure the full unmasked key.")
            return False
        return True

    def _get_sdk_client(self):
        if not self.is_configured():
            return None
        if self._sdk_client is None:
            try:
                from realitydefender import RealityDefender
                self._sdk_client = RealityDefender(api_key=self.api_key)
            except ImportError:
                logger.warning("[RealityDefenderDetector] 'realitydefender' package not installed. Run `pip install realitydefender`.")
                return None
            except Exception as e:
                logger.error(f"[RealityDefenderDetector] Failed to initialize Reality Defender SDK: {e}")
                return None
        return self._sdk_client

    def detect_file(self, file_path: str) -> Dict[str, Any]:
        """
        Synchronously sends a media file (image/video/audio) to Reality Defender for deepfake detection.
        """
        if not os.path.exists(file_path):
            return {
                "status": "error",
                "error": f"File not found: {file_path}",
                "is_fake": False,
                "score": 0.0,
                "confidence": 0.0,
            }

        if not self.is_configured():
            return {
                "status": "skipped",
                "reason": "Reality Defender API key is not configured or is masked.",
                "is_fake": False,
                "score": 0.0,
                "confidence": 0.0,
            }

        client = self._get_sdk_client()
        if client:
            try:
                logger.info(f"[RealityDefenderDetector] Detecting file via Reality Defender: {file_path}")
                # Use synchronous detect_file from SDK
                result = client.detect_file(file_path=file_path)
                
                raw_score = result.get("score")
                if raw_score is None:
                    raw_score = 0.0
                else:
                    raw_score = float(raw_score)

                # Normalize score to 0.0 - 1.0 range
                norm_score = raw_score / 100.0 if raw_score > 1.0 else raw_score
                norm_score = max(0.0, min(1.0, norm_score))

                raw_status = str(result.get("status", "")).upper()
                is_fake = "MANIPULATED" in raw_status or "SYNTHETIC" in raw_status or norm_score >= 0.50

                return {
                    "status": "success",
                    "request_id": result.get("request_id", ""),
                    "score": norm_score,
                    "percentage_score": round(norm_score * 100.0, 2),
                    "is_fake": is_fake,
                    "confidence": round(abs(norm_score - 0.5) * 200, 2),
                    "rd_status": raw_status,
                    "models": result.get("models", []),
                    "heatmaps": result.get("heatmaps") or {},
                    "details": dict(result),
                }
            except Exception as e:
                logger.error(f"[RealityDefenderDetector] SDK detection error: {e}")
                return {
                    "status": "error",
                    "error": str(e),
                    "is_fake": False,
                    "score": 0.0,
                    "confidence": 0.0,
                }

        return {
            "status": "skipped",
            "reason": "Reality Defender SDK unavailable.",
            "is_fake": False,
            "score": 0.0,
            "confidence": 0.0,
        }

    async def detect_file_async(self, file_path: str) -> Dict[str, Any]:
        """Asynchronous wrapper that runs synchronous detection in a background executor."""
        loop = asyncio.get_event_loop()
        return await loop.run_in_executor(None, self.detect_file, file_path)
