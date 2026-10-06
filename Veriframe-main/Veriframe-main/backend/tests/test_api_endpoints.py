import unittest
import numpy as np
import cv2
import wave
import io
import tempfile
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from unittest.mock import patch, MagicMock
from starlette.testclient import TestClient
from main import app
from database.connection import init_db, insert_report, get_report_by_hash, list_reports

client = TestClient(app)

class TestApiEndpoints(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        init_db()
        cls.rd_patcher = patch(
            "services.reality_defender_service.RealityDefenderService.analyze_media",
            return_value={
                "status": "success",
                "fake_probability": 10.0,
                "confidence": 90.0,
                "verdict": "AUTHENTIC",
                "evidence": [],
                "observations": ["Mock Reality Defender: AUTHENTIC (10%)"],
                "partial": False,
            }
        )
        cls.gemini_patcher = patch(
            "services.gemini_service.GeminiService.generate_forensic_explanation",
            return_value={
                "status": "success",
                "ai_summary": "Test automated forensic summary.",
                "threat_level": "LOW",
                "threat_context": "None",
                "recommended_action": "Standard review.",
            }
        )
        cls.rd_patcher.start()
        cls.gemini_patcher.start()

    @classmethod
    def tearDownClass(cls):
        cls.rd_patcher.stop()
        cls.gemini_patcher.stop()

    def test_health_endpoint(self):
        resp = client.get("/health")
        self.assertEqual(resp.status_code, 200)
        data = resp.json()
        self.assertEqual(data.get("status"), "healthy")

    def test_version_endpoint(self):
        resp = client.get("/version")
        self.assertEqual(resp.status_code, 200)
        data = resp.json()
        self.assertEqual(data.get("api_version"), "2.0.0")

    def test_verify_image_endpoint(self):
        # Create a small valid test JPEG
        img = np.zeros((100, 100, 3), dtype=np.uint8)
        cv2.circle(img, (50, 50), 30, (200, 200, 200), -1)
        _, buf = cv2.imencode(".jpg", img)
        file_bytes = io.BytesIO(buf.tobytes())

        resp = client.post("/verify/image", files={"file": ("test.jpg", file_bytes, "image/jpeg")})
        self.assertEqual(resp.status_code, 200)
        data = resp.json()

        # Check all required VerificationResult schema fields are present
        required_fields = [
            "verificationId", "verifiedAt", "mediaType", "source",
            "authenticityScore", "fakeProbability", "confidence",
            "metadataScore", "frameConsistency", "ocrConfidence",
            "trackingConfidence", "manipulationScore", "verdict", "riskLevel",
            "detectedEvidence", "forensicObservations", "reportHash"
        ]
        for field in required_fields:
            self.assertIn(field, data, f"Missing required schema field: {field}")
            self.assertIsNotNone(data[field], f"Field {field} should not be None")

        # Verify it was persisted to SQLite
        persisted = get_report_by_hash(data["reportHash"])
        self.assertIsNotNone(persisted)
        self.assertEqual(persisted["verificationId"], data["verificationId"])

    def test_verify_audio_endpoint(self):
        # Create a small valid test WAV
        buf = io.BytesIO()
        sample_rate = 16000
        samples = (np.sin(2 * np.pi * 440 * np.linspace(0, 0.5, int(sample_rate * 0.5))) * 32767).astype(np.int16)
        with wave.open(buf, "wb") as wf:
            wf.setnchannels(1)
            wf.setsampwidth(2)
            wf.setframerate(sample_rate)
            wf.writeframes(samples.tobytes())
        buf.seek(0)

        resp = client.post("/verify/audio", files={"file": ("test.wav", buf, "audio/wav")})
        self.assertEqual(resp.status_code, 200)
        data = resp.json()

        # Check all required VerificationResult schema fields are present
        required_fields = [
            "verificationId", "verifiedAt", "mediaType", "source",
            "authenticityScore", "fakeProbability", "confidence",
            "metadataScore", "frameConsistency", "ocrConfidence",
            "trackingConfidence", "manipulationScore", "verdict", "riskLevel",
            "detectedEvidence", "forensicObservations", "reportHash"
        ]
        for field in required_fields:
            self.assertIn(field, data, f"Missing required schema field: {field}")
            self.assertIsNotNone(data[field], f"Field {field} should not be None")

        # Verify it was persisted to SQLite
        persisted = get_report_by_hash(data["reportHash"])
        self.assertIsNotNone(persisted)

    def test_reports_endpoints(self):
        dummy_report = {
            "verificationId": "VRF-TEST-ENDPOINT-1",
            "verifiedAt": "2026-10-04T00:00:00Z",
            "mediaType": "image/jpeg",
            "source": "Endpoint Test",
            "authenticityScore": 92.5,
            "fakeProbability": 7.5,
            "confidence": 88.0,
            "verdict": "AUTHENTIC",
            "riskLevel": "LOW",
            "detectedEvidence": ["Test evidence indicator"],
            "forensicObservations": ["Observation note 1"],
            "reportHash": "endpoint_test_hash_unique_123",
            "framesAnalyzed": 1,
            "processingTimeSec": 0.12,
        }
        insert_report(dummy_report)

        # GET /reports
        resp = client.get("/reports")
        self.assertEqual(resp.status_code, 200)
        reports = resp.json().get("reports", [])
        self.assertGreaterEqual(len(reports), 1)

        # GET /reports/{report_hash}
        resp = client.get(f"/reports/{dummy_report['reportHash']}")
        self.assertEqual(resp.status_code, 200)
        data = resp.json()
        self.assertEqual(data["verificationId"], dummy_report["verificationId"])
        self.assertEqual(data["detectedEvidence"], dummy_report["detectedEvidence"])
        self.assertEqual(data["forensicObservations"], dummy_report["forensicObservations"])

    def test_shield_protect_endpoint(self):
        # Create a small valid test JPEG
        img = np.zeros((80, 80, 3), dtype=np.uint8)
        cv2.circle(img, (40, 40), 20, (150, 150, 150), -1)
        _, buf = cv2.imencode(".jpg", img)
        file_bytes = io.BytesIO(buf.tobytes())

        resp = client.post("/shield/protect", files={"file": ("face.jpg", file_bytes, "image/jpeg")}, data={"epsilon": "8.0"})
        self.assertEqual(resp.status_code, 200)
        data = resp.json()
        self.assertEqual(data["status"], "success")
        self.assertIn("c2pa_manifest", data)
        self.assertIn("psnr_db", data)
        self.assertGreater(data["psnr_db"], 30.0)
        self.assertIn("protected_image_base64", data)

    def test_stream_analysis_endpoint(self):
        from main import jobs_db
        test_job_id = "test_stream_job_123"
        jobs_db[test_job_id] = {
            "status": "completed",
            "progress": 1.0,
            "cached": False,
            "result": {"test": "ok"}
        }
        resp = client.get(f"/analysis/{test_job_id}/stream")
        self.assertEqual(resp.status_code, 200)
        self.assertIn("text/event-stream", resp.headers["content-type"])
        self.assertIn("completed", resp.text)

if __name__ == "__main__":
    unittest.main()
