"""
VeriFrame Remote Photoplethysmography (rPPG) Forensics Pipeline
==============================================================
Extracts biophysical blood-volume pulse (BVP) from facial capillary blood
flow across video frames using the Chrominance-based (CHROM) method
(de Haan & Jeanne, IEEE TBME 2013).

Biological Reality:
- Human skin capillaries expand and contract with cardiac ventricular contractions.
  Oxygenated hemoglobin absorbs green/blue optical wavelengths differently than red.
- Deepfake neural synthesis (GAN / Diffusion / FaceSwap) regenerates facial pixels
  independently per frame or latent vector, destroying biological micro-vascular
  photoplethysmographic pulse coherence.
"""

import numpy as np
import cv2
from scipy import signal
from typing import Dict, Any, List, Tuple, Optional
import logging

logger = logging.getLogger("veriframe.pipelines.rppg")

class RppgForensicsDetector:
    """
    Biophysical rPPG capillary pulse detector.
    Extracts arterial pulse waveform, estimates heart rate (BPM),
    and computes spectral Signal-to-Noise Ratio (SNR) to distinguish
    living humans from synthetic deepfakes.
    """

    def __init__(self, fps: float = 30.0, min_bpm: float = 45.0, max_bpm: float = 180.0):
        self.fps = fps
        self.min_freq = min_bpm / 60.0   # 0.75 Hz
        self.max_freq = max_bpm / 60.0   # 3.00 Hz

    def extract_skin_roi(self, frame: np.ndarray, box: Optional[List[float]] = None) -> np.ndarray:
        """
        Isolates forehead and cheek regions from a face image.
        These regions have dense capillary vasculature and minimum motion distortion.
        """
        h, w = frame.shape[:2]
        if box is not None and len(box) >= 4:
            x1 = max(0, int(box[0]))
            y1 = max(0, int(box[1]))
            bw = int(box[2])
            bh = int(box[3])
            face = frame[y1:min(h, y1 + bh), x1:min(w, x1 + bw)]
            if face.size == 0:
                face = frame
        else:
            face = frame

        fh, fw = face.shape[:2]
        # Forehead ROI: top 20% - 40%, central 60%
        forehead = face[int(fh * 0.15):int(fh * 0.40), int(fw * 0.20):int(fw * 0.80)]
        # Cheeks ROI: 50% - 70%, left and right
        left_cheek = face[int(fh * 0.50):int(fh * 0.70), int(fw * 0.15):int(fw * 0.40)]
        right_cheek = face[int(fh * 0.50):int(fh * 0.70), int(fw * 0.60):int(fw * 0.85)]

        rois = []
        for r in [forehead, left_cheek, right_cheek]:
            if r.size > 0:
                rois.append(r.reshape(-1, 3))

        if rois:
            return np.vstack(rois)
        return face.reshape(-1, 3)

    def compute_chrom_pulse(self, rgb_series: np.ndarray, fps: float) -> np.ndarray:
        """
        De Haan's CHROM algorithm for rPPG pulse extraction.
        rgb_series: Shape (N, 3) representing [R, G, B] means over time.
        """
        N = len(rgb_series)
        if N < 15:
            return np.zeros(N, dtype=np.float32)

        # 1. Temporal normalization: divide each channel by its running or global mean
        means = np.mean(rgb_series, axis=0)
        means[means == 0] = 1.0
        norm_rgb = rgb_series / means

        R = norm_rgb[:, 0]
        G = norm_rgb[:, 1]
        B = norm_rgb[:, 2]

        # 2. Chrominance projection
        # Xs = 3R - 2G
        # Ys = 1.5R + G - 1.5B
        Xs = 3.0 * R - 2.0 * G
        Ys = 1.5 * R + G - 1.5 * B

        # 3. Standard deviation ratio
        std_x = np.std(Xs)
        std_y = np.std(Ys)
        alpha = (std_x / std_y) if std_y > 1e-6 else 1.0

        # 4. Raw BVP signal
        bvp = Xs - alpha * Ys

        # 5. Zero-phase bandpass filter [0.75 Hz, 3.0 Hz]
        nyquist = 0.5 * fps
        low = max(0.01, self.min_freq / nyquist)
        high = min(0.99, self.max_freq / nyquist)

        if low < high and N > 12:
            try:
                b, a = signal.butter(3, [low, high], btype='bandpass')
                bvp_filtered = signal.filtfilt(b, a, bvp)
                return bvp_filtered
            except Exception as e:
                logger.debug(f"[RPPG] Filter fallback: {e}")

        # Detrend fallback
        return signal.detrend(bvp)

    def analyze_spectrum(self, bvp_signal: np.ndarray, fps: float) -> Tuple[float, float, float]:
        """
        Computes power spectral density to determine:
        - peak_bpm: Dominant heart rate frequency (BPM)
        - snr_db: Cardiac peak power vs. non-cardiac noise power (dB)
        - peak_energy: Relative spectral energy of cardiac pulse
        """
        N = len(bvp_signal)
        if N < 16:
            return 0.0, -10.0, 0.0

        # Zero-pad for higher frequency resolution
        n_fft = max(256, 1 << (N - 1).bit_length() + 1)
        freqs, psd = signal.welch(bvp_signal, fs=fps, nperseg=min(N, 128), nfft=n_fft)

        # Physiological band mask
        cardiac_mask = (freqs >= self.min_freq) & (freqs <= self.max_freq)
        if not np.any(cardiac_mask):
            return 0.0, -10.0, 0.0

        band_freqs = freqs[cardiac_mask]
        band_psd = psd[cardiac_mask]

        peak_idx = np.argmax(band_psd)
        peak_freq = band_freqs[peak_idx]
        peak_power = band_psd[peak_idx]
        peak_bpm = round(float(peak_freq * 60.0), 1)

        # Peak power within +/- 0.2 Hz vs. background noise
        half_window = 0.20
        peak_window_mask = (band_freqs >= peak_freq - half_window) & (band_freqs <= peak_freq + half_window)
        signal_power = np.sum(band_psd[peak_window_mask])
        noise_power = np.sum(band_psd[~peak_window_mask]) + 1e-9

        snr = float(10.0 * np.log10(max(1e-6, signal_power / noise_power)))
        snr_db = round(snr, 2)
        peak_energy = float(signal_power / (np.sum(band_psd) + 1e-9))

        return peak_bpm, snr_db, peak_energy

    def process_frames(self, frames: List[np.ndarray], boxes: Optional[List[List[float]]] = None, fps: float = 30.0) -> Dict[str, Any]:
        """
        Processes a sequence of extracted video frames to compute rPPG vitals.
        Returns waveform array, heart rate (BPM), SNR, and deepfake pulse authenticity verdict.
        """
        if not frames or len(frames) < 10:
            return {
                "detected": False,
                "bpm": 0.0,
                "snr_db": -10.0,
                "is_biologically_consistent": False,
                "confidence": 0.0,
                "waveform": [0.0] * 50,
                "observation": "Insufficient video frames for physiological rPPG extraction."
            }

        rgb_series = []
        for i, frame in enumerate(frames):
            box = boxes[i] if (boxes and i < len(boxes)) else None
            skin_pixels = self.extract_skin_roi(frame, box)
            if skin_pixels.size > 0:
                mean_rgb = np.mean(skin_pixels, axis=0) # [B, G, R]
                # Convert BGR to RGB
                rgb_series.append([mean_rgb[2], mean_rgb[1], mean_rgb[0]])
            else:
                rgb_series.append([128.0, 128.0, 128.0])

        rgb_arr = np.array(rgb_series, dtype=np.float32)
        bvp_raw = self.compute_chrom_pulse(rgb_arr, fps)

        # Normalize waveform to range [-1.0, 1.0] for plotting
        max_val = np.max(np.abs(bvp_raw)) if len(bvp_raw) > 0 else 1.0
        if max_val < 1e-6:
            max_val = 1.0
        norm_waveform = (bvp_raw / max_val).tolist()

        # Resample waveform to clean 64 data points for smooth client rendering
        if len(norm_waveform) > 64:
            x_old = np.linspace(0, 1, len(norm_waveform))
            x_new = np.linspace(0, 1, 64)
            norm_waveform = np.interp(x_new, x_old, norm_waveform).tolist()
        elif len(norm_waveform) < 64 and len(norm_waveform) > 1:
            x_old = np.linspace(0, 1, len(norm_waveform))
            x_new = np.linspace(0, 1, 64)
            norm_waveform = np.interp(x_new, x_old, norm_waveform).tolist()

        peak_bpm, snr_db, peak_energy = self.analyze_spectrum(bvp_raw, fps)

        # Real humans: periodic pulse in [50, 150] BPM, SNR > 2.5 dB
        # Synthetic / Deepfake: random latent noise, SNR < 1.0 dB or BPM outside physiological bounds
        is_bio_authentic = (snr_db >= 2.5) and (50.0 <= peak_bpm <= 150.0)

        if is_bio_authentic:
            obs = f"Biophysical capillary blood flow verified ({peak_bpm} BPM, pulse SNR {snr_db} dB). Natural ventricular photoplethysmography detected."
            confidence = min(98.5, max(75.0, 50.0 + snr_db * 5.0))
        elif snr_db < 0.5:
            obs = f"Synthetic flatline: Zero physiological capillary pulse rhythm (SNR {snr_db} dB). Video facial regions lack biological hemoglobin absorption."
            confidence = min(98.0, max(80.0, 95.0 - snr_db * 4.0))
        else:
            obs = f"Weak or irregular capillary pulse signal ({peak_bpm} BPM, SNR {snr_db} dB). Biometrics inconclusive due to video motion or re-encoding."
            confidence = 55.0

        return {
            "detected": True,
            "bpm": peak_bpm if is_bio_authentic else 0.0,
            "snr_db": snr_db,
            "is_biologically_consistent": is_bio_authentic,
            "confidence": round(confidence, 1),
            "waveform": [round(float(v), 3) for v in norm_waveform],
            "observation": obs,
        }
