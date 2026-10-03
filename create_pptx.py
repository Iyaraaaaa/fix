import os
import pptx
from pptx import Presentation
from pptx.util import Inches, Pt
from pptx.dml.color import RGBColor
from pptx.enum.text import PP_ALIGN, MSO_ANCHOR
from pptx.enum.shapes import MSO_SHAPE
from pptx.oxml import parse_xml

def create_deck():
    prs = Presentation()
    # 16:9 Widescreen dimensions
    prs.slide_width = Inches(13.333)
    prs.slide_height = Inches(7.5)

    blank_layout = prs.slide_layouts[6]
    slide = prs.slides.add_slide(blank_layout)

    # 1. Background image
    bg_path = r"d:\Final Project\fix\slide1_bg.png"
    slide.shapes.add_picture(bg_path, Inches(0), Inches(0), prs.slide_width, prs.slide_height)

    # Color definitions
    C_CYAN = RGBColor(0, 240, 255)
    C_SKY = RGBColor(120, 225, 255)
    C_WHITE = RGBColor(255, 255, 255)
    C_MUTED = RGBColor(165, 185, 210)
    C_DIM = RGBColor(100, 125, 155)
    C_DARK_CARD = RGBColor(8, 15, 30)
    C_BORDER = RGBColor(0, 240, 255)
    C_EMERALD = RGBColor(0, 255, 140)
    C_AMBER = RGBColor(255, 185, 40)

    # 2. Top Capsule Pill Badge
    pill = slide.shapes.add_shape(
        MSO_SHAPE.ROUNDED_RECTANGLE,
        Inches(0.8), Inches(0.7), Inches(4.5), Inches(0.38)
    )
    pill.fill.solid()
    pill.fill.fore_color.rgb = RGBColor(6, 16, 32)
    pill.line.color.rgb = C_CYAN
    pill.line.width = Pt(1.2)
    tf = pill.text_frame
    tf.word_wrap = True
    tf.vertical_anchor = MSO_ANCHOR.MIDDLE
    tf.margin_left = Inches(0.15)
    tf.margin_right = Inches(0.15)
    tf.margin_top = Inches(0.02)
    tf.margin_bottom = Inches(0.02)
    p = tf.paragraphs[0]
    p.text = "⚡ NEXT-GEN AI FORENSICS & VERIFICATION ENGINE"
    p.font.name = "Segoe UI"
    p.font.size = Pt(9.5)
    p.font.bold = True
    p.font.color.rgb = C_CYAN

    # 3. Main Title: VERIFRAME
    title_box = slide.shapes.add_textbox(
        Inches(0.75), Inches(1.22), Inches(6.8), Inches(1.2)
    )
    tf = title_box.text_frame
    tf.word_wrap = True
    tf.margin_left = tf.margin_top = tf.margin_right = tf.margin_bottom = 0
    p = tf.paragraphs[0]
    p.text = "VERIFRAME"
    p.font.name = "Arial Black"
    p.font.size = Pt(56)
    p.font.bold = True
    p.font.color.rgb = C_WHITE

    # 4. Tagline
    tagline_box = slide.shapes.add_textbox(
        Inches(0.8), Inches(2.45), Inches(6.4), Inches(0.75)
    )
    tf = tagline_box.text_frame
    tf.word_wrap = True
    tf.margin_left = tf.margin_top = tf.margin_right = tf.margin_bottom = 0
    p = tf.paragraphs[0]
    p.text = "Real-Time Deepfake Detection & Video Authenticity Verification"
    p.font.name = "Segoe UI"
    p.font.size = Pt(19)
    p.font.bold = True
    p.font.color.rgb = C_SKY

    # 5. Lead Description
    desc_box = slide.shapes.add_textbox(
        Inches(0.8), Inches(3.32), Inches(5.8), Inches(1.1)
    )
    tf = desc_box.text_frame
    tf.word_wrap = True
    tf.margin_left = tf.margin_top = tf.margin_right = tf.margin_bottom = 0
    p = tf.paragraphs[0]
    p.text = (
        "Engineered with a high-precision Cross-Efficient-ViT neural architecture, "
        "adaptive multi-scale frame sampling, triple-engine face detection fallback "
        "(MTCNN + MediaPipe), and Platt temperature-calibrated forensic reporting."
    )
    p.font.name = "Calibri"
    p.font.size = Pt(12.5)
    p.font.color.rgb = C_MUTED

    # 6. Three Spec Metric Cards
    metrics = [
        {
            "x": Inches(0.8),
            "val": "97.68%",
            "label": "ROC-AUC BENCHMARK",
            "sub": "DFDC & FaceForensics++",
            "accent": C_CYAN
        },
        {
            "x": Inches(2.8),
            "val": "91.0%",
            "label": "DETECTION ACCURACY",
            "sub": "Balanced Test Corpus",
            "accent": C_EMERALD
        },
        {
            "x": Inches(4.8),
            "val": "< 300ms",
            "label": "EDGE LATENCY",
            "sub": "TFLite FP16 Optimization",
            "accent": C_AMBER
        }
    ]

    card_y = Inches(4.75)
    card_w = Inches(1.85)
    card_h = Inches(1.4)

    for m in metrics:
        # Card Background Box
        card = slide.shapes.add_shape(
            MSO_SHAPE.ROUNDED_RECTANGLE,
            m["x"], card_y, card_w, card_h
        )
        card.fill.solid()
        card.fill.fore_color.rgb = C_DARK_CARD
        card.line.color.rgb = m["accent"]
        card.line.width = Pt(1.2)

        tf = card.text_frame
        tf.word_wrap = True
        tf.margin_left = Inches(0.12)
        tf.margin_right = Inches(0.12)
        tf.margin_top = Inches(0.14)
        tf.margin_bottom = Inches(0.1)

        # Big Value
        p1 = tf.paragraphs[0]
        p1.text = m["val"]
        p1.font.name = "Arial"
        p1.font.size = Pt(24)
        p1.font.bold = True
        p1.font.color.rgb = C_WHITE

        # Label
        p2 = tf.add_paragraph()
        p2.text = m["label"]
        p2.font.name = "Segoe UI"
        p2.font.size = Pt(8.5)
        p2.font.bold = True
        p2.font.color.rgb = m["accent"]
        p2.space_before = Pt(4)

        # Subtitle
        p3 = tf.add_paragraph()
        p3.text = m["sub"]
        p3.font.name = "Calibri"
        p3.font.size = Pt(7.5)
        p3.font.color.rgb = C_MUTED
        p3.space_before = Pt(2)

    # 7. Right-Side Holographic HUD Callout Badges
    hud_callouts = [
        {
            "x": Inches(8.3),
            "y": Inches(1.15),
            "w": Inches(3.8),
            "h": Inches(0.55),
            "title": "◉ Cross-Efficient-ViT Attention Core",
            "sub": "Spatial-frequency anomaly feature maps",
            "accent": C_CYAN
        },
        {
            "x": Inches(9.2),
            "y": Inches(3.6),
            "w": Inches(3.7),
            "h": Inches(0.55),
            "title": "◉ 68-Point Facial Landmark Mesh",
            "sub": "MTCNN + MediaPipe real-time tracking",
            "accent": C_EMERALD
        },
        {
            "x": Inches(8.2),
            "y": Inches(5.8),
            "w": Inches(3.8),
            "h": Inches(0.55),
            "title": "◉ Platt Temperature Calibration",
            "sub": "Confidence smoothing & SHA-256 report verification",
            "accent": C_CYAN
        }
    ]

    for h in hud_callouts:
        tag = slide.shapes.add_shape(
            MSO_SHAPE.ROUNDED_RECTANGLE,
            h["x"], h["y"], h["w"], h["h"]
        )
        tag.fill.solid()
        tag.fill.fore_color.rgb = RGBColor(6, 12, 24)
        tag.line.color.rgb = h["accent"]
        tag.line.width = Pt(1.0)

        tf = tag.text_frame
        tf.word_wrap = True
        tf.margin_left = Inches(0.12)
        tf.margin_right = Inches(0.12)
        tf.margin_top = Inches(0.06)
        tf.margin_bottom = Inches(0.06)

        p1 = tf.paragraphs[0]
        p1.text = h["title"]
        p1.font.name = "Segoe UI"
        p1.font.size = Pt(9.5)
        p1.font.bold = True
        p1.font.color.rgb = h["accent"]

        p2 = tf.add_paragraph()
        p2.text = h["sub"]
        p2.font.name = "Calibri"
        p2.font.size = Pt(8.0)
        p2.font.color.rgb = C_MUTED

    # 8. Slide Footer / Project Metadata
    footer_box = slide.shapes.add_textbox(
        Inches(0.8), Inches(6.75), Inches(11.7), Inches(0.3)
    )
    tf = footer_box.text_frame
    tf.word_wrap = True
    tf.margin_left = tf.margin_top = tf.margin_right = tf.margin_bottom = 0
    p = tf.paragraphs[0]
    p.text = "VeriFrame Forensic Core v2.4   |   Final Year Capstone Project   |   Deep Learning & Media Forensics   |   2026"
    p.font.name = "Segoe UI"
    p.font.size = Pt(9.0)
    p.font.color.rgb = C_DIM

    # Save presentation
    output_pptx = r"d:\Final Project\fix\VeriFrame_3D_Presentation.pptx"
    prs.save(output_pptx)
    print(f"Presentation saved successfully to: {output_pptx}")
    print(f"File size: {os.path.getsize(output_pptx)} bytes")

if __name__ == "__main__":
    create_deck()
