import os
from pptx import Presentation
from pptx.util import Inches, Pt
from pptx.dml.color import RGBColor
from pptx.enum.shapes import MSO_SHAPE
from pptx.enum.text import MSO_ANCHOR
from pptx.oxml import parse_xml

def build_amsonppt_presentation():
    prs = Presentation()
    prs.slide_width = Inches(13.333)
    prs.slide_height = Inches(7.5)

    # Color definitions
    C_CYAN = RGBColor(0, 240, 255)
    C_SKY = RGBColor(120, 225, 255)
    C_WHITE = RGBColor(255, 255, 255)
    C_MUTED = RGBColor(165, 185, 210)
    C_DIM = RGBColor(100, 125, 155)
    C_CARD_BG = RGBColor(9, 16, 34)
    C_EMERALD = RGBColor(0, 255, 136)
    C_AMBER = RGBColor(255, 170, 0)
    C_PILL_BG = RGBColor(7, 14, 28)

    blank_layout = prs.slide_layouts[6]

    # =========================================================================
    # SLIDE 1: CREATIVE 3D FIRST PAGE (AMSONPPT POP-OUT & FRAGMENTED STYLE)
    # =========================================================================
    slide1 = prs.slides.add_slide(blank_layout)

    # Background: Organic curved glass panel with glowing cyan neon border & 01 watermark
    bg1_path = r"d:\Final Project\fix\amson_bg_slide1.png"
    bg1 = slide1.shapes.add_picture(bg1_path, Inches(0), Inches(0), prs.slide_width, prs.slide_height)
    bg1.name = "!!BACKGROUND"

    # 3D Pop-Out Hero Hologram breaking the frame
    hero_path = r"d:\Final Project\fix\hero_3d_popout.png"
    hero1 = slide1.shapes.add_picture(hero_path, Inches(6.5), Inches(0.5), Inches(6.8), Inches(6.5))
    hero1.name = "!!HERO_3D"

    # Top Capsule Badge
    pill1 = slide1.shapes.add_shape(
        MSO_SHAPE.ROUNDED_RECTANGLE,
        Inches(0.8), Inches(0.75), Inches(4.5), Inches(0.38)
    )
    pill1.name = "!!PILL_BADGE"
    pill1.fill.solid()
    pill1.fill.fore_color.rgb = C_PILL_BG
    pill1.line.color.rgb = C_CYAN
    pill1.line.width = Pt(1.2)
    tf1 = pill1.text_frame
    tf1.word_wrap = True
    tf1.vertical_anchor = MSO_ANCHOR.MIDDLE
    tf1.margin_left = tf1.margin_right = Inches(0.15)
    tf1.margin_top = tf1.margin_bottom = Inches(0.02)
    p = tf1.paragraphs[0]
    p.text = "⚡ NEXT-GEN AI FORENSICS & VERIFICATION"
    p.font.name = "Segoe UI"
    p.font.size = Pt(9.5)
    p.font.bold = True
    p.font.color.rgb = C_CYAN

    # Main Title
    title1 = slide1.shapes.add_textbox(
        Inches(0.75), Inches(1.3), Inches(5.8), Inches(1.15)
    )
    title1.name = "!!MAIN_TITLE"
    tf = title1.text_frame
    tf.word_wrap = True
    tf.margin_left = tf.margin_top = tf.margin_right = tf.margin_bottom = 0
    p = tf.paragraphs[0]
    p.text = "VERIFRAME"
    p.font.name = "Arial Black"
    p.font.size = Pt(56)
    p.font.bold = True
    p.font.color.rgb = C_WHITE

    # Tagline
    tag1 = slide1.shapes.add_textbox(
        Inches(0.8), Inches(2.45), Inches(5.8), Inches(0.75)
    )
    tag1.name = "!!TAGLINE"
    tf = tag1.text_frame
    tf.word_wrap = True
    tf.margin_left = tf.margin_top = tf.margin_right = tf.margin_bottom = 0
    p = tf.paragraphs[0]
    p.text = "Real-Time Deepfake Detection & Video Authenticity Verification"
    p.font.name = "Segoe UI"
    p.font.size = Pt(18)
    p.font.bold = True
    p.font.color.rgb = C_SKY

    # Lead Description
    desc1 = slide1.shapes.add_textbox(
        Inches(0.8), Inches(3.3), Inches(5.4), Inches(1.1)
    )
    desc1.name = "!!DESC"
    tf = desc1.text_frame
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

    # 3 Floating Glassmorphic Spec Metric Cards
    metrics_data = [
        {
            "name": "!!CARD_1",
            "x": Inches(0.8),
            "val": "97.68%",
            "label": "ROC-AUC SCORE",
            "sub": "DFDC & FaceForensics++",
            "accent": C_CYAN
        },
        {
            "name": "!!CARD_2",
            "x": Inches(2.65),
            "val": "91.0%",
            "label": "MODEL ACCURACY",
            "sub": "Balanced Test Corpus",
            "accent": C_EMERALD
        },
        {
            "name": "!!CARD_3",
            "x": Inches(4.5),
            "val": "< 300ms",
            "label": "EDGE LATENCY",
            "sub": "Rolling Window FP16",
            "accent": C_AMBER
        }
    ]

    card_y = Inches(4.8)
    card_w = Inches(1.7)
    card_h = Inches(1.35)

    for m in metrics_data:
        c = slide1.shapes.add_shape(
            MSO_SHAPE.ROUNDED_RECTANGLE,
            m["x"], card_y, card_w, card_h
        )
        c.name = m["name"]
        c.fill.solid()
        c.fill.fore_color.rgb = C_CARD_BG
        c.line.color.rgb = m["accent"]
        c.line.width = Pt(1.2)

        tf = c.text_frame
        tf.word_wrap = True
        tf.margin_left = Inches(0.12)
        tf.margin_right = Inches(0.12)
        tf.margin_top = Inches(0.14)
        tf.margin_bottom = Inches(0.1)

        p1 = tf.paragraphs[0]
        p1.text = m["val"]
        p1.font.name = "Arial"
        p1.font.size = Pt(23)
        p1.font.bold = True
        p1.font.color.rgb = C_WHITE

        p2 = tf.add_paragraph()
        p2.text = m["label"]
        p2.font.name = "Segoe UI"
        p2.font.size = Pt(8.5)
        p2.font.bold = True
        p2.font.color.rgb = m["accent"]
        p2.space_before = Pt(4)

        p3 = tf.add_paragraph()
        p3.text = m["sub"]
        p3.font.name = "Calibri"
        p3.font.size = Pt(7.5)
        p3.font.color.rgb = C_MUTED
        p3.space_before = Pt(2)

    # Right-Side 3D HUD Callout Badges
    callouts = [
        {
            "x": Inches(8.3), "y": Inches(1.1), "w": Inches(3.6), "h": Inches(0.5),
            "title": "◉ Cross-Efficient-ViT Core", "sub": "Vision Transformer spatial attention", "accent": C_CYAN
        },
        {
            "x": Inches(9.2), "y": Inches(3.5), "w": Inches(3.5), "h": Inches(0.5),
            "title": "◉ 68-Point Facial Landmark Mesh", "sub": "MTCNN + MediaPipe tracking", "accent": C_EMERALD
        },
        {
            "x": Inches(8.2), "y": Inches(5.8), "w": Inches(3.6), "h": Inches(0.5),
            "title": "◉ Platt Temperature Calibration", "sub": "Confidence smoothing & SHA-256 hash", "accent": C_CYAN
        }
    ]
    for idx, h in enumerate(callouts):
        tag = slide1.shapes.add_shape(
            MSO_SHAPE.ROUNDED_RECTANGLE,
            h["x"], h["y"], h["w"], h["h"]
        )
        tag.name = f"!!HUD_{idx+1}"
        tag.fill.solid()
        tag.fill.fore_color.rgb = RGBColor(6, 12, 26)
        tag.line.color.rgb = h["accent"]
        tag.line.width = Pt(1.0)

        tf = tag.text_frame
        tf.word_wrap = True
        tf.margin_left = Inches(0.1)
        tf.margin_right = Inches(0.1)
        tf.margin_top = Inches(0.05)
        tf.margin_bottom = Inches(0.05)

        p1 = tf.paragraphs[0]
        p1.text = h["title"]
        p1.font.name = "Segoe UI"
        p1.font.size = Pt(9.0)
        p1.font.bold = True
        p1.font.color.rgb = h["accent"]

        p2 = tf.add_paragraph()
        p2.text = h["sub"]
        p2.font.name = "Calibri"
        p2.font.size = Pt(7.5)
        p2.font.color.rgb = C_MUTED

    # Footer
    footer1 = slide1.shapes.add_textbox(
        Inches(0.8), Inches(6.8), Inches(11.7), Inches(0.3)
    )
    footer1.name = "!!FOOTER"
    tf = footer1.text_frame
    tf.word_wrap = True
    tf.margin_left = tf.margin_top = tf.margin_right = tf.margin_bottom = 0
    p = tf.paragraphs[0]
    p.text = "VeriFrame Forensic Core v2.4   •   Final Year Capstone Project   •   Deep Learning & Media Forensics   •   2026"
    p.font.name = "Segoe UI"
    p.font.size = Pt(9.0)
    p.font.color.rgb = C_DIM


    # =========================================================================
    # SLIDE 2: MORPHED STATE (THE MORPH ANIMATION TRANSITION)
    # =========================================================================
    slide2 = prs.slides.add_slide(blank_layout)

    # Background 2: 02 Watermark & Expanded panel
    bg2_path = r"d:\Final Project\fix\amson_bg_slide2.png"
    bg2 = slide2.shapes.add_picture(bg2_path, Inches(0), Inches(0), prs.slide_width, prs.slide_height)
    bg2.name = "!!BACKGROUND"

    # In Slide 2, the 3D Pop-Out Hero smoothly glides over to the left!
    hero2 = slide2.shapes.add_picture(hero_path, Inches(0.3), Inches(1.3), Inches(5.2), Inches(5.0))
    hero2.name = "!!HERO_3D"

    # Top Badge Morphed
    pill2 = slide2.shapes.add_shape(
        MSO_SHAPE.ROUNDED_RECTANGLE,
        Inches(5.7), Inches(0.75), Inches(5.2), Inches(0.38)
    )
    pill2.name = "!!PILL_BADGE"
    pill2.fill.solid()
    pill2.fill.fore_color.rgb = C_PILL_BG
    pill2.line.color.rgb = C_CYAN
    pill2.line.width = Pt(1.2)
    tf2 = pill2.text_frame
    tf2.word_wrap = True
    tf2.vertical_anchor = MSO_ANCHOR.MIDDLE
    tf2.margin_left = tf2.margin_right = Inches(0.15)
    tf2.margin_top = tf2.margin_bottom = Inches(0.02)
    p = tf2.paragraphs[0]
    p.text = "⚡ DEEP DIVE: END-TO-END FORENSIC PIPELINE"
    p.font.name = "Segoe UI"
    p.font.size = Pt(9.5)
    p.font.bold = True
    p.font.color.rgb = C_CYAN

    # Main Title Morphed
    title2 = slide2.shapes.add_textbox(
        Inches(5.7), Inches(1.25), Inches(7.0), Inches(0.65)
    )
    title2.name = "!!MAIN_TITLE"
    tf = title2.text_frame
    tf.word_wrap = True
    tf.margin_left = tf.margin_top = tf.margin_right = tf.margin_bottom = 0
    p = tf.paragraphs[0]
    p.text = "CORE ARCHITECTURE"
    p.font.name = "Arial Black"
    p.font.size = Pt(36)
    p.font.bold = True
    p.font.color.rgb = C_WHITE

    # Tagline Morphed
    tag2 = slide2.shapes.add_textbox(
        Inches(5.7), Inches(1.9), Inches(7.0), Inches(0.45)
    )
    tag2.name = "!!TAGLINE"
    tf = tag2.text_frame
    tf.word_wrap = True
    tf.margin_left = tf.margin_top = tf.margin_right = tf.margin_bottom = 0
    p = tf.paragraphs[0]
    p.text = "Multi-Stage Spatial Attention, Temporal Calibration & Forensic Output"
    p.font.name = "Segoe UI"
    p.font.size = Pt(15)
    p.font.bold = True
    p.font.color.rgb = C_SKY

    # 3 Expanded Architectural Feature Cards (Morphed from !!CARD_1, !!CARD_2, !!CARD_3)
    pillars = [
        {
            "name": "!!CARD_1",
            "y": Inches(2.45),
            "title": "01. Cross-Efficient-ViT Vision Transformer",
            "body": "Fuses EfficientNet spatial convolution with multi-head self-attention. Detects subtle high-frequency artifacts, compression incongruities, and synthetic facial warping with 97.68% ROC-AUC.",
            "tag": "97.68% ROC-AUC",
            "accent": C_CYAN
        },
        {
            "name": "!!CARD_2",
            "y": Inches(3.85),
            "title": "02. Adaptive Frame Sampling & 3-Tier Face Tracking",
            "body": "Intelligently samples 20-40 informative frames (scene shifts, motion peaks). Triple fallback (MTCNN -> MediaPipe -> Haar) guarantees continuous tracking across extreme yaw, pitch, and partial occlusions.",
            "tag": "Triple Fallback",
            "accent": C_EMERALD
        },
        {
            "name": "!!CARD_3",
            "y": Inches(5.25),
            "title": "03. Temporal Smoothing & Cryptographic Verification",
            "body": "A 30-frame rolling window with Platt temperature scaling stabilizes predictions and eliminates isolated false triggers. Automatically issues SHA-256 tamper-evident forensic verification certificates.",
            "tag": "< 300ms Real-Time",
            "accent": C_AMBER
        }
    ]

    for pil in pillars:
        box = slide2.shapes.add_shape(
            MSO_SHAPE.ROUNDED_RECTANGLE,
            Inches(5.7), pil["y"], Inches(6.9), Inches(1.25)
        )
        box.name = pil["name"]
        box.fill.solid()
        box.fill.fore_color.rgb = C_CARD_BG
        box.line.color.rgb = pil["accent"]
        box.line.width = Pt(1.2)

        tf = box.text_frame
        tf.word_wrap = True
        tf.margin_left = Inches(0.18)
        tf.margin_right = Inches(0.18)
        tf.margin_top = Inches(0.12)
        tf.margin_bottom = Inches(0.1)

        # Title
        p1 = tf.paragraphs[0]
        p1.text = pil["title"]
        p1.font.name = "Segoe UI"
        p1.font.size = Pt(12)
        p1.font.bold = True
        p1.font.color.rgb = pil["accent"]

        # Body
        p2 = tf.add_paragraph()
        p2.text = pil["body"]
        p2.font.name = "Calibri"
        p2.font.size = Pt(10.5)
        p2.font.color.rgb = C_MUTED
        p2.space_before = Pt(3)

    # Footer 2
    footer2 = slide2.shapes.add_textbox(
        Inches(5.7), Inches(6.8), Inches(6.9), Inches(0.3)
    )
    footer2.name = "!!FOOTER"
    tf = footer2.text_frame
    tf.word_wrap = True
    tf.margin_left = tf.margin_top = tf.margin_right = tf.margin_bottom = 0
    p = tf.paragraphs[0]
    p.text = "VeriFrame Architecture Overview   •   Slide 02   •   Morph Transition Active"
    p.font.name = "Segoe UI"
    p.font.size = Pt(9.0)
    p.font.color.rgb = C_DIM

    # Inject PowerPoint Morph Transition XML into Slide 2
    morph_xml = """<p:transition xmlns:p="http://schemas.openxmlformats.org/presentationml/2006/main" xmlns:p14="http://schemas.microsoft.com/office/powerpoint/2010/main" spd="med"><p14:morph option="byObject"/></p:transition>"""
    transition_elem = parse_xml(morph_xml)
    slide2.element.insert(-1, transition_elem)

    # =========================================================================
    # SLIDE 3: DEMONSTRATION OF MOBILE APP (LIVE SYSTEM WALKTHROUGH & MOBILE FORENSICS)
    # =========================================================================
    slide3 = prs.slides.add_slide(blank_layout)

    # Background 3: Clean cyber panel
    bg3_path = r"d:\Final Project\fix\amson_bg_slide3.png"
    bg3 = slide3.shapes.add_picture(bg3_path, Inches(0), Inches(0), prs.slide_width, prs.slide_height)
    bg3.name = "!!BACKGROUND"

    # Smartphone Mockup on the Left (Morphed from !!HERO_3D!)
    mockup_path = r"d:\Final Project\fix\mobile_mockup_slide3.png"
    phone_w = Inches(3.45)
    phone_h = Inches(6.25)
    mockup_x = Inches(0.9)
    mockup_y = Inches(0.62)
    phone_mockup = slide3.shapes.add_picture(mockup_path, mockup_x, mockup_y, phone_w, phone_h)
    phone_mockup.name = "!!HERO_3D"

    # Top Capsule Pill Badge (Morphed from !!PILL_BADGE)
    pill3 = slide3.shapes.add_shape(
        MSO_SHAPE.ROUNDED_RECTANGLE,
        Inches(4.95), Inches(0.68), Inches(5.2), Inches(0.36)
    )
    pill3.name = "!!PILL_BADGE"
    pill3.fill.solid()
    pill3.fill.fore_color.rgb = C_PILL_BG
    pill3.line.color.rgb = C_CYAN
    pill3.line.width = Pt(1.2)
    tf3 = pill3.text_frame
    tf3.word_wrap = True
    tf3.vertical_anchor = MSO_ANCHOR.MIDDLE
    tf3.margin_left = tf3.margin_right = Inches(0.15)
    tf3.margin_top = tf3.margin_bottom = Inches(0.02)
    p = tf3.paragraphs[0]
    p.text = "⚡ SYSTEM DEMONSTRATION & LIVE EXECUTION"
    p.font.name = "Segoe UI"
    p.font.size = Pt(9.5)
    p.font.bold = True
    p.font.color.rgb = C_CYAN

    # Main Title (Morphed from !!MAIN_TITLE)
    title3 = slide3.shapes.add_textbox(
        Inches(4.95), Inches(1.16), Inches(7.8), Inches(0.55)
    )
    title3.name = "!!MAIN_TITLE"
    tf = title3.text_frame
    tf.word_wrap = False
    tf.margin_left = tf.margin_top = tf.margin_right = tf.margin_bottom = 0
    p = tf.paragraphs[0]
    p.text = "Demonstration of Mobile APP"
    p.font.name = "Arial Black"
    p.font.size = Pt(30)
    p.font.bold = True
    p.font.color.rgb = C_WHITE

    # Tagline (Morphed from !!TAGLINE)
    tag3 = slide3.shapes.add_textbox(
        Inches(4.95), Inches(1.80), Inches(7.8), Inches(0.40)
    )
    tag3.name = "!!TAGLINE"
    tf = tag3.text_frame
    tf.word_wrap = True
    tf.margin_left = tf.margin_top = tf.margin_right = tf.margin_bottom = 0
    p = tf.paragraphs[0]
    p.text = "Interactive Real-Time Forensics, Multi-Modal Ingestion & Legal Reporting"
    p.font.name = "Segoe UI"
    p.font.size = Pt(13)
    p.font.bold = True
    p.font.color.rgb = C_SKY

    # 4 Demonstration Stage Breakdown Cards (Morphed from !!CARD_1, !!CARD_2, !!CARD_3, !!CARD_4)
    demo_cards = [
        {
            "name": "!!CARD_1",
            "y": Inches(2.32),
            "title": "01. Multi-Modal Media Ingestion & Live Stream",
            "body": "Supports real-time 30 FPS camera feeds, local gallery video uploads, and URL scrapers for social platforms (YouTube, TikTok, Reels).",
            "accent": C_CYAN
        },
        {
            "name": "!!CARD_2",
            "y": Inches(3.30),
            "title": "02. Real-Time Neural Forensics & Visual Heatmaps",
            "body": "Cross-Efficient-ViT extracts spatial manipulation heatmaps, 68-point facial meshes, and evaluates biological rPPG pulse desynchronization.",
            "accent": C_EMERALD
        },
        {
            "name": "!!CARD_3",
            "y": Inches(4.28),
            "title": "03. Calibrated Scoring & Gemini Multimodal Reasoning",
            "body": "Calculates Platt temperature-calibrated authenticity confidence (97.8%) and uses Gemini 1.5 Pro to explain facial/audio anomalies.",
            "accent": RGBColor(167, 139, 250)
        },
        {
            "name": "!!CARD_4",
            "y": Inches(5.26),
            "title": "04. Law Enforcement Escalation & SHA-256 PDF",
            "body": "Exports court-admissible forensic audit dossiers sealed with SHA-256 hashes, tamper timestamps, and 1-tap police incident dispatch.",
            "accent": C_AMBER
        }
    ]

    for dcard in demo_cards:
        box = slide3.shapes.add_shape(
            MSO_SHAPE.ROUNDED_RECTANGLE,
            Inches(4.95), dcard["y"], Inches(7.7), Inches(0.88)
        )
        box.name = dcard["name"]
        box.fill.solid()
        box.fill.fore_color.rgb = C_CARD_BG
        box.line.color.rgb = dcard["accent"]
        box.line.width = Pt(1.2)

        tf = box.text_frame
        tf.word_wrap = True
        tf.margin_left = tf.margin_right = Inches(0.18)
        tf.margin_top = Inches(0.08)
        tf.margin_bottom = Inches(0.06)

        # Title
        p1 = tf.paragraphs[0]
        p1.text = dcard["title"]
        p1.font.name = "Segoe UI"
        p1.font.size = Pt(11.0)
        p1.font.bold = True
        p1.font.color.rgb = dcard["accent"]

        # Body
        p2 = tf.add_paragraph()
        p2.text = dcard["body"]
        p2.font.name = "Calibri"
        p2.font.size = Pt(9.5)
        p2.font.color.rgb = C_MUTED
        p2.space_before = Pt(2)

    # Live Demo Quick-Launch Banner Shape
    launch_bar = slide3.shapes.add_shape(
        MSO_SHAPE.ROUNDED_RECTANGLE,
        Inches(4.95), Inches(6.25), Inches(7.7), Inches(0.34)
    )
    launch_bar.fill.solid()
    launch_bar.fill.fore_color.rgb = RGBColor(10, 20, 38)
    launch_bar.line.color.rgb = C_CYAN
    launch_bar.line.width = Pt(1.0)
    tf = launch_bar.text_frame
    tf.word_wrap = True
    tf.vertical_anchor = MSO_ANCHOR.MIDDLE
    tf.margin_left = tf.margin_right = Inches(0.15)
    tf.margin_top = tf.margin_bottom = 0
    p = tf.paragraphs[0]
    p.text = "▶ LIVE DEMO SHORTCUT: Run launch_live_preview.bat or execute Flutter app for interactive inspection"
    p.font.name = "Segoe UI"
    p.font.size = Pt(8.8)
    p.font.bold = True
    p.font.color.rgb = C_CYAN

    # Footer 3
    footer3 = slide3.shapes.add_textbox(
        Inches(4.95), Inches(6.75), Inches(7.7), Inches(0.28)
    )
    footer3.name = "!!FOOTER"
    tf = footer3.text_frame
    tf.word_wrap = True
    tf.margin_left = tf.margin_top = tf.margin_right = tf.margin_bottom = 0
    p = tf.paragraphs[0]
    p.text = "VeriFrame Mobile App Demonstration   •   Slide 03   •   Morph Transition Active"
    p.font.name = "Segoe UI"
    p.font.size = Pt(9.0)
    p.font.color.rgb = C_DIM

    # Inject PowerPoint Morph Transition XML into Slide 3
    slide3.element.insert(-1, parse_xml(morph_xml))

    # Save final presentation
    output_path = r"d:\Final Project\fix\VeriFrame_Creative_3D_Morph.pptx"
    prs.save(output_path)
    print(f"Creative 3D Presentation created successfully: {output_path}")
    print(f"File size: {os.path.getsize(output_path)} bytes")

if __name__ == "__main__":
    build_amsonppt_presentation()
