import os
import math
from PIL import Image, ImageDraw, ImageFont

def create_phone_mockup():
    # High resolution canvas for phone mockup
    W, H = 820, 1600
    img = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)

    # Fonts
    font_dir = r"C:\Windows\Fonts"
    f_bold_large = ImageFont.truetype(os.path.join(font_dir, "arialbd.ttf"), 38)
    f_bold_med = ImageFont.truetype(os.path.join(font_dir, "arialbd.ttf"), 28)
    f_bold_sm = ImageFont.truetype(os.path.join(font_dir, "segoeuib.ttf"), 22)
    f_reg_med = ImageFont.truetype(os.path.join(font_dir, "segoeui.ttf"), 22)
    f_reg_sm = ImageFont.truetype(os.path.join(font_dir, "segoeui.ttf"), 18)
    f_mono = ImageFont.truetype(os.path.join(font_dir, "consola.ttf"), 18)
    f_tiny = ImageFont.truetype(os.path.join(font_dir, "segoeui.ttf"), 15)

    # 1. Outer Glow around phone
    for r in range(12, 0, -2):
        alpha = int(18 * (12 - r) / 12)
        draw.rounded_rectangle(
            [20 - r, 20 - r, W - 20 + r, H - 20 + r],
            radius=88 + r,
            outline=(0, 240, 255, alpha),
            width=2
        )

    # 2. Titanium Frame
    draw.rounded_rectangle([20, 20, W - 20, H - 20], radius=85, fill=(16, 23, 40, 255), outline=(0, 240, 255, 230), width=5)

    # 3. Inner Screen Bezel
    draw.rounded_rectangle([34, 34, W - 34, H - 34], radius=72, fill=(8, 12, 22, 255))

    # 4. Status Bar (Time, Battery, Wifi)
    draw.text((80, 56), "09:41", font=f_bold_sm, fill=(240, 246, 255, 255))
    # Battery icon on right
    draw.rounded_rectangle([W - 130, 60, W - 80, 80], radius=5, outline=(160, 180, 210, 255), width=2)
    draw.rounded_rectangle([W - 126, 64, W - 90, 76], radius=3, fill=(0, 255, 136, 255))
    draw.rectangle([W - 79, 66, W - 76, 74], fill=(160, 180, 210, 255))
    # 5G tag
    draw.text((W - 175, 58), "5G", font=f_bold_sm, fill=(160, 180, 210, 255))

    # 5. Dynamic Island Pill
    draw.rounded_rectangle([W // 2 - 110, 48, W // 2 + 110, 94], radius=23, fill=(3, 7, 18, 255), outline=(30, 41, 59, 255), width=2)
    # Camera sensor dot
    draw.ellipse([W // 2 + 55, 62, W // 2 + 81, 88], fill=(15, 23, 42, 255), outline=(30, 41, 59, 255), width=1)
    draw.ellipse([W // 2 - 60, 65, W // 2 - 46, 79], fill=(16, 185, 129, 200)) # Green privacy LED

    # 6. App Header Bar
    # Shield icon box
    draw.rounded_rectangle([60, 115, 105, 160], radius=12, fill=(37, 99, 235, 255))
    draw.text((73, 122), "V", font=f_bold_med, fill=(255, 255, 255, 255))
    draw.text((120, 116), "VeriFrame Forensics", font=f_bold_med, fill=(255, 255, 255, 255))
    draw.text((122, 146), "REAL-TIME MEDIA SCANNER • v2.4", font=f_tiny, fill=(0, 240, 255, 255))

    # Live Mode Badge (Top Right)
    draw.rounded_rectangle([W - 180, 118, W - 60, 154], radius=18, fill=(239, 68, 68, 40), outline=(239, 68, 68, 220), width=1)
    draw.ellipse([W - 165, 131, W - 155, 141], fill=(239, 68, 68, 255))
    draw.text((W - 146, 124), "LIVE", font=f_bold_sm, fill=(239, 68, 68, 255))

    # 7. Live Viewfinder / Video Stream Panel
    vf_top, vf_bottom = 180, 780
    vf_left, vf_right = 55, W - 55
    draw.rounded_rectangle([vf_left, vf_top, vf_right, vf_bottom], radius=24, fill=(12, 18, 32, 255), outline=(30, 48, 80, 255), width=2)

    # Grid lines inside viewfinder
    for gx in range(vf_left + 70, vf_right, 70):
        draw.line([(gx, vf_top + 10), (gx, vf_bottom - 10)], fill=(20, 32, 54, 120), width=1)
    for gy in range(vf_top + 60, vf_bottom, 60):
        draw.line([(vf_left + 10, gy), (vf_right - 10, gy)], fill=(20, 32, 54, 120), width=1)

    # Simulated Face & 68-Point Landmark Mesh
    cx, cy = W // 2, 450
    # Head contour
    draw.ellipse([cx - 160, cy - 200, cx + 160, cy + 190], outline=(0, 240, 255, 90), width=2)
    # Eyes & Eyebrows
    draw.arc([cx - 110, cy - 80, cx - 30, cy - 40], 0, 180, fill=(0, 240, 255, 200), width=2)
    draw.arc([cx + 30, cy - 80, cx + 110, cy - 40], 0, 180, fill=(0, 240, 255, 200), width=2)
    draw.line([(cx - 100, cy - 100), (cx - 40, cy - 105)], fill=(0, 240, 255, 220), width=2)
    draw.line([(cx + 40, cy - 105), (cx + 100, cy - 100)], fill=(0, 240, 255, 220), width=2)
    # Nose & Mouth
    draw.line([(cx, cy - 50), (cx - 15, cy + 30), (cx + 15, cy + 30)], fill=(0, 240, 255, 220), width=2)
    draw.ellipse([cx - 50, cy + 70, cx + 50, cy + 110], outline=(239, 68, 68, 200), width=2)

    # Landmark points (MediaPipe 68 nodes)
    pts = [
        (cx - 140, cy - 50), (cx - 130, cy + 20), (cx - 100, cy + 90), (cx - 60, cy + 140), (cx, cy + 170),
        (cx + 60, cy + 140), (cx + 100, cy + 90), (cx + 130, cy + 20), (cx + 140, cy - 50),
        (cx - 70, cy - 60), (cx - 50, cy - 60), (cx + 50, cy - 60), (cx + 70, cy - 60),
        (cx, cy - 20), (cx, cy + 10), (cx - 20, cy + 30), (cx + 20, cy + 30),
        (cx - 30, cy + 85), (cx + 30, cy + 85), (cx, cy + 100)
    ]
    for px, py in pts:
        draw.ellipse([px - 4, py - 4, px + 4, py + 4], fill=(0, 255, 136, 255))
        # Connection spider threads
        draw.line([(px, py), (cx, cy)], fill=(0, 240, 255, 45), width=1)

    # Red Tampering Alert Bounding Box
    box_l, box_t, box_r, box_b = cx - 180, cy - 220, cx + 180, cy + 210
    draw.rectangle([box_l, box_t, box_r, box_b], outline=(239, 68, 68, 240), width=3)
    # Corner brackets (HUD style)
    c_len = 25
    draw.line([(box_l, box_t), (box_l + c_len, box_t)], fill=(239, 68, 68, 255), width=6)
    draw.line([(box_l, box_t), (box_l, box_t + c_len)], fill=(239, 68, 68, 255), width=6)
    draw.line([(box_r, box_t), (box_r - c_len, box_t)], fill=(239, 68, 68, 255), width=6)
    draw.line([(box_r, box_t), (box_r, box_t + c_len)], fill=(239, 68, 68, 255), width=6)
    draw.line([(box_l, box_b), (box_l + c_len, box_b)], fill=(239, 68, 68, 255), width=6)
    draw.line([(box_l, box_b), (box_l, box_b - c_len)], fill=(239, 68, 68, 255), width=6)
    draw.line([(box_r, box_b), (box_r - c_len, box_b)], fill=(239, 68, 68, 255), width=6)
    draw.line([(box_r, box_b), (box_r, box_b - c_len)], fill=(239, 68, 68, 255), width=6)

    # Tamper Alert Label Pill on top of box
    draw.rounded_rectangle([box_l + 10, box_t - 26, box_l + 320, box_t + 8], radius=8, fill=(239, 68, 68, 255))
    draw.text((box_l + 20, box_t - 24), "⚠️ SYNTHETIC MANIPULATION: 97.8%", font=f_tiny, fill=(255, 255, 255, 255))

    # Bottom Overlay on Viewfinder: Live Scanning Telemetry
    draw.rounded_rectangle([vf_left + 15, vf_bottom - 75, vf_right - 15, vf_bottom - 15], radius=14, fill=(5, 9, 18, 220), outline=(0, 240, 255, 120), width=1)
    draw.text((vf_left + 30, vf_bottom - 68), "FPS: 30.2  |  LATENCY: 248ms  |  ENGINE: Cross-Efficient-ViT", font=f_tiny, fill=(0, 240, 255, 255))
    draw.text((vf_left + 30, vf_bottom - 42), "HASH: SHA256:7f9a2b8...  |  STATUS: ACTIVE DETECTION", font=f_tiny, fill=(165, 185, 210, 255))

    # 8. Forensic Confidence Metric Card
    cd1_top = 805
    draw.rounded_rectangle([55, cd1_top, W - 55, cd1_top + 160], radius=20, fill=(15, 23, 42, 255), outline=(239, 68, 68, 200), width=2)
    draw.text((80, cd1_top + 18), "AUTHENTICITY VERDICT", font=f_tiny, fill=(165, 185, 210, 255))
    draw.text((80, cd1_top + 40), "DEEPFAKE DETECTED", font=f_bold_med, fill=(239, 68, 68, 255))
    draw.text((W - 200, cd1_top + 34), "97.8%", font=f_bold_large, fill=(239, 68, 68, 255))
    draw.text((W - 200, cd1_top + 76), "CONFIDENCE", font=f_tiny, fill=(239, 68, 68, 200))

    # Dual Progress Bar (Manipulated vs Real)
    bar_y = cd1_top + 115
    draw.rounded_rectangle([80, bar_y, W - 80, bar_y + 16], radius=8, fill=(30, 41, 59, 255))
    draw.rounded_rectangle([80, bar_y, 80 + int((W - 160) * 0.978), bar_y + 16], radius=8, fill=(239, 68, 68, 255))
    draw.text((80, bar_y + 22), "0.0% Authentic", font=f_tiny, fill=(100, 125, 155, 255))
    draw.text((W - 210, bar_y + 22), "97.8% Manipulated", font=f_tiny, fill=(239, 68, 68, 255))

    # 9. Biometrics Telemetry Grid (2 Columns: rPPG Pulse & RT60 Reverb)
    cd2_top = 985
    # Card Left: rPPG Heartbeat
    draw.rounded_rectangle([55, cd2_top, W // 2 - 10, cd2_top + 120], radius=16, fill=(15, 23, 42, 255), outline=(0, 240, 255, 150), width=1)
    draw.text((75, cd2_top + 14), "rPPG Pulse Flow", font=f_tiny, fill=(0, 240, 255, 255))
    draw.text((75, cd2_top + 38), "DESYNC", font=f_bold_med, fill=(255, 170, 0, 255))
    # Simulated mini ECG waveform
    wf_pts = [(75, cd2_top + 95), (105, cd2_top + 95), (120, cd2_top + 70), (135, cd2_top + 110), (150, cd2_top + 80), (180, cd2_top + 95), (W // 2 - 30, cd2_top + 95)]
    draw.line(wf_pts, fill=(0, 240, 255, 255), width=2)

    # Card Right: RT60 Acoustic Reverb
    draw.rounded_rectangle([W // 2 + 10, cd2_top, W - 55, cd2_top + 120], radius=16, fill=(15, 23, 42, 255), outline=(139, 92, 246, 150), width=1)
    draw.text((W // 2 + 30, cd2_top + 14), "RT60 Audio Decay", font=f_tiny, fill=(196, 181, 253, 255))
    draw.text((W // 2 + 30, cd2_top + 38), "CLONED VOICE", font=f_bold_med, fill=(239, 68, 68, 255))
    draw.text((W // 2 + 30, cd2_top + 80), "Spectral Phase Null", font=f_tiny, fill=(165, 185, 210, 255))

    # 10. Gemini Multimodal Reasoning Card
    gem_top = 1125
    draw.rounded_rectangle([55, gem_top, W - 55, gem_top + 165], radius=18, fill=(19, 14, 38, 255), outline=(139, 92, 246, 180), width=2)
    # Sparkle / AI icon
    draw.text((75, gem_top + 16), "✨ GEMINI 1.5 PRO FORENSIC SUMMARY", font=f_bold_sm, fill=(196, 181, 253, 255))
    desc_gemini_1 = "\"High-frequency spatial boundary blurring identified along the jawline"
    desc_gemini_2 = "and eye orbit. Natural micro-blood flow pulse is absent. Synthetic facial"
    desc_gemini_3 = "reenactment probability exceeds 97.8% threshold.\""
    draw.text((75, gem_top + 52), desc_gemini_1, font=f_reg_sm, fill=(225, 231, 245, 255))
    draw.text((75, gem_top + 82), desc_gemini_2, font=f_reg_sm, fill=(225, 231, 245, 255))
    draw.text((75, gem_top + 112), desc_gemini_3, font=f_reg_sm, fill=(225, 231, 245, 255))

    # 11. Dual Action Buttons (Escalate & Export PDF)
    btn_top = 1310
    # Left Button: Escalate (Crimson)
    draw.rounded_rectangle([55, btn_top, W // 2 - 10, btn_top + 70], radius=16, fill=(239, 68, 68, 255))
    draw.text((85, btn_top + 20), "🚨 Police Escalate", font=f_bold_sm, fill=(255, 255, 255, 255))

    # Right Button: Export PDF (Blue / Cyan)
    draw.rounded_rectangle([W // 2 + 10, btn_top, W - 55, btn_top + 70], radius=16, fill=(37, 99, 235, 255))
    draw.text((W // 2 + 35, btn_top + 20), "📄 Export SHA PDF", font=f_bold_sm, fill=(255, 255, 255, 255))

    # 12. Bottom Navigation Dock
    dock_top = 1405
    draw.rounded_rectangle([55, dock_top, W - 55, dock_top + 100], radius=24, fill=(11, 16, 28, 255), outline=(30, 41, 59, 255), width=1)
    nav_items = ["Home", "Verify", "Scanner", "Reports", "Settings"]
    for i, name in enumerate(nav_items):
        nx = 85 + i * 140
        col = (0, 240, 255, 255) if name == "Scanner" else (140, 160, 190, 255)
        # Dot icon
        draw.ellipse([nx + 20, dock_top + 22, nx + 36, dock_top + 38], fill=col)
        draw.text((nx + 10, dock_top + 52), name, font=f_tiny, fill=col)

    # 13. Home Indicator Bar
    draw.rounded_rectangle([W // 2 - 80, H - 48, W // 2 + 80, H - 40], radius=4, fill=(160, 180, 210, 200))

    out_path = r"d:\Final Project\fix\mobile_mockup_slide3.png"
    img.save(out_path, format="PNG")
    print(f"Mobile mockup image generated successfully at: {out_path}")
    print(f"Dimensions: {img.size}")

if __name__ == "__main__":
    create_phone_mockup()
