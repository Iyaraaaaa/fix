import csv
import os
import sys
import tempfile
import unittest
from pathlib import Path

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from metrics import run_eval


class TestClassifyPathUsed(unittest.TestCase):
    def test_face_observation_means_face_path(self):
        result = {"forensicObservations": [
            "Image dimensions: 640x480 (3 color channels).",
            "Face Model (Image) Confidence: 37.9% fake probability.",
        ]}
        self.assertEqual(run_eval.classify_path_used(result), run_eval.FACE)

    def test_full_scene_observation_means_fallback(self):
        result = {"forensicObservations": [
            "Full-Scene Inference (Image): 39.9% fake probability.",
        ]}
        self.assertEqual(run_eval.classify_path_used(result), run_eval.FALLBACK)

    def test_face_wins_over_full_scene_when_both_present(self):
        result = {"forensicObservations": [
            "Full-Scene Inference (Image): 10.0% fake probability.",
            "Face Model (Image) Confidence: 90.0% fake probability.",
        ]}
        self.assertEqual(run_eval.classify_path_used(result), run_eval.FACE)

    def test_missing_observations_is_unknown_not_a_guess(self):
        self.assertEqual(run_eval.classify_path_used({}), "unknown")
        self.assertEqual(run_eval.classify_path_used({"forensicObservations": None}), "unknown")


class TestManifest(unittest.TestCase):
    def setUp(self):
        self.tmp = Path(tempfile.mkdtemp())

    def tearDown(self):
        import shutil
        shutil.rmtree(self.tmp, ignore_errors=True)

    def _write_manifest(self, where: Path, rows):
        where.mkdir(parents=True, exist_ok=True)
        with open(where / "manifest.csv", "w", newline="", encoding="utf-8") as fh:
            w = csv.DictWriter(fh, fieldnames=["path", "label", "split", "video_id", "method"])
            w.writeheader()
            w.writerows(rows)

    def test_manifest_in_root_is_found(self):
        self._write_manifest(self.tmp, [
            {"path": str(self.tmp / "real" / "a.png"), "label": 0, "split": "val",
             "video_id": "v1", "method": "original"},
        ])
        m = run_eval.load_manifest(self.tmp)
        row = run_eval.lookup_manifest(m, self.tmp / "real" / "a.png")
        self.assertEqual(row["video_id"], "v1")

    def test_manifest_in_parent_is_found(self):
        (self.tmp / "val").mkdir()
        self._write_manifest(self.tmp, [
            {"path": str(self.tmp / "val" / "real" / "a.png"), "label": 0, "split": "val",
             "video_id": "v1", "method": "original"},
        ])
        m = run_eval.load_manifest(self.tmp / "val")
        self.assertEqual(run_eval.lookup_manifest(m, self.tmp / "val" / "real" / "a.png")["video_id"], "v1")

    def test_lookup_falls_back_to_filename(self):
        self._write_manifest(self.tmp, [
            {"path": "/somewhere/else/a.png", "label": 0, "split": "val",
             "video_id": "v9", "method": "Deepfakes"},
        ])
        m = run_eval.load_manifest(self.tmp)
        self.assertEqual(run_eval.lookup_manifest(m, Path("C:/other/a.png"))["video_id"], "v9")

    def test_missing_manifest_returns_empty(self):
        self.assertEqual(run_eval.load_manifest(self.tmp), {})
        self.assertEqual(run_eval.lookup_manifest({}, Path("x.png")), {})

    def test_unknown_file_yields_empty_row(self):
        self._write_manifest(self.tmp, [
            {"path": str(self.tmp / "a.png"), "label": 0, "split": "val",
             "video_id": "v1", "method": "original"},
        ])
        m = run_eval.load_manifest(self.tmp)
        self.assertEqual(run_eval.lookup_manifest(m, self.tmp / "zzz.png"), {})


class TestMetricBlocks(unittest.TestCase):
    def test_threshold_is_honoured(self):
        # Every sample scores 0.40: below 0.5 -> all real, above 0.3 -> all fake.
        low = run_eval._metric_block([0, 1], [0.4, 0.4], 0.5)
        self.assertEqual(low["cm"]["tp"], 0)
        self.assertEqual(low["cm"]["fn"], 1)
        high = run_eval._metric_block([0, 1], [0.4, 0.4], 0.3)
        self.assertEqual(high["cm"]["tp"], 1)
        self.assertEqual(high["cm"]["fp"], 1)

    def test_n_is_reported(self):
        block = run_eval._metric_block([0, 1, 0], [0.1, 0.9, 0.2], 0.5)
        self.assertEqual(block["n"], 3)

    def test_small_group_detection(self):
        self.assertTrue(run_eval._too_small(run_eval.MIN_GROUP_ROWS - 1))
        self.assertFalse(run_eval._too_small(run_eval.MIN_GROUP_ROWS))


def _read_source() -> str:
    return Path(run_eval.__file__).read_text(encoding="utf-8")


class TestEngineFlags(unittest.TestCase):
    """The harness must never reach the network unless explicitly asked to."""

    def test_default_engine_is_local(self):
        self.assertIn('default="local"', _read_source())
        self.assertIn('choices=["local", "rd", "fused"]', _read_source())

    def test_local_only_flag_exists(self):
        self.assertIn('"--local-only"', _read_source())

    def test_max_frames_cap_exists(self):
        self.assertIn("--max-frames-per-video", _read_source())

    def test_rd_columns_are_written(self):
        for column in ("local_score", "rd_score", "rd_status"):
            self.assertIn(column, _read_source())


if __name__ == "__main__":
    unittest.main()
