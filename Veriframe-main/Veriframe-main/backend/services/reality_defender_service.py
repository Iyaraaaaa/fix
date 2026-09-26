import os
import logging
import asyncio
from typing import Dict, Any, Optional

from config import config as app_config
from detectors.reality_defender_detector import RealityDefenderDetector

logger = logging.getLogger("veriframe.services.reality_defender_service")

class RealityDefenderService:
    """High‑level wrapper around :class:`RealityDefenderDetector`.

    Provides two convenience methods used by the verification pipelines:

    * ``analyze_media(file_path)`` – for whole video/image files.
    * ``analyze_bytes(data)`` – for a single frame (bytes) coming from a live stream.

    Both methods return a **normalized dict** that matches the ``VerificationResult``
    schema (except for UI‑only fields). Errors are captured and translated to a
    ``status`` field (``SUCCESS``, ``ERROR``, ``UNSUPPORTED``) together with a
    ``error_code`` identifier.
    """

    def __init__(self):
        self.detector = RealityDefenderDetector()
        if not self.detector.is_configured():
            logger.warning("RealityDefenderService initialized without a valid API key.")

    async def _detect_async(self, path: Optional[str] = None, data: Optional[bytes] = None) -> Dict[str, Any]:
        """Internal helper that delegates to the detector.

        Exactly one of ``path`` or ``data`` must be provided.
        """
        if path:
            return await self.detector.detect_file_async(path)
        if data:
            # The SDK currently only supports file paths, so we write a temporary file.
            import tempfile
            with tempfile.NamedTemporaryFile(delete=False, suffix=".tmp") as tmp:
                tmp.write(data)
                tmp_path = tmp.name
            try:
                result = await self.detector.detect_file_async(tmp_path)
            finally:
                try:
                    os.remove(tmp_path)
                except Exception:
                    pass
            return result
        return {"status": "error", "error": "No input provided to RealityDefenderService"}

    def analyze_media(self, file_path: str) -> Dict[str, Any]:
        """Synchronous method for analysing a complete media file (video, image, audio).
        Returns the normalized dict.
        """
        try:
            raw = self.detector.detect_file(file_path)
        except Exception as e:
            logger.error(f"[RealityDefenderService] analyze_media error: {e}")
            raw = {"status": "error", "error": str(e)}
        return self._normalize(raw)

    async def analyze_media_async(self, file_path: str) -> Dict[str, Any]:
        """Asynchronous method for analysing a media file."""
        try:
            raw = await self.detector.detect_file_async(file_path)
        except Exception as e:
            logger.error(f"[RealityDefenderService] analyze_media_async error: {e}")
            raw = {"status": "error", "error": str(e)}
        return self._normalize(raw)

    def analyze_bytes(self, frame_bytes: bytes) -> Dict[str, Any]:
        """Analyse a single frame (bytes). Used by the live‑stream pipeline.
        """
        import tempfile
        tmp_path = None
        try:
            with tempfile.NamedTemporaryFile(delete=False, suffix=".jpg") as tmp:
                tmp.write(frame_bytes)
                tmp_path = tmp.name
            raw = self.detector.detect_file(tmp_path)
        except Exception as e:
            logger.error(f"[RealityDefenderService] analyze_bytes error: {e}")
            raw = {"status": "error", "error": str(e)}
        finally:
            if tmp_path and os.path.exists(tmp_path):
                try:
                    os.remove(tmp_path)
                except Exception:
                    pass
        return self._normalize(raw)

    def _normalize(self, raw: Dict[str, Any]) -> Dict[str, Any]:
        """Convert the raw detector response into the canonical dict used by the pipelines.
        """
        status = raw.get("status")
        if status != "success":
            return {
                "status": status,
                "error_code": raw.get("error") or raw.get("reason") or "UNKNOWN",
                "error_message": raw.get("error") or raw.get("reason"),
                "fake_probability": 0.0,
                "authenticity_score": 100.0,
                "verdict": "UNKNOWN",
                "fine_verdict": "UNKNOWN",
                "models": [],
                "heatmaps": {},
                "evidence": [],
                "observations": [],
            }

        score = float(raw.get("score", 0.0))  # 0.0 - 1.0 range
        fake_prob = round(score * 100.0, 2)
        auth_score = round(max(0.0, (1.0 - score) * 100.0), 2)
        
        rd_status = raw.get("rd_status", "")
        if "MANIPULATED" in rd_status or fake_prob > 65.0:
            verdict = "MANIPULATED"
            fine_verdict = "FAKE" if fake_prob >= 85.0 else "LIKELY_FAKE"
        elif "AUTHENTIC" in rd_status or fake_prob < 35.0:
            verdict = "AUTHENTIC"
            fine_verdict = "REAL" if fake_prob <= 15.0 else "LIKELY_REAL"
        else:
            verdict = "INCONCLUSIVE"
            fine_verdict = "UNCERTAIN"

        models = raw.get("models", [])
        evidence = []
        observations = []

        if raw.get("request_id"):
            observations.append(f"Reality Defender Request ID: {raw['request_id']}")

        for m in models:
            m_name = m.get("name", "Model")
            m_status = m.get("status", "")
            m_score = m.get("score")
            score_str = f" ({m_score}%)" if m_score is not None else ""
            if "MANIPULATED" in str(m_status).upper() or (m_score is not None and m_score > 60):
                evidence.append(f"Reality Defender {m_name}: Flagged as {m_status}{score_str}")
            else:
                observations.append(f"Reality Defender {m_name}: {m_status}{score_str}")

        return {
            "status": "success",
            "request_id": raw.get("request_id"),
            "fake_probability": fake_prob,
            "authenticity_score": auth_score,
            "confidence": raw.get("confidence", 85.0),
            "verdict": verdict,
            "fine_verdict": fine_verdict,
            "models": models,
            "heatmaps": raw.get("heatmaps", {}),
            "evidence": evidence,
            "observations": observations,
        }
