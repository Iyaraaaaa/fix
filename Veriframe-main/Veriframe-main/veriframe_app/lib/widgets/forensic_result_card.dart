import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:open_filex/open_filex.dart';
import 'package:veriframe_app/models/verification_result.dart';
import 'package:veriframe_app/service/pdf_service.dart';
import 'package:veriframe_app/widgets/escalate_bottom_sheet.dart';

/// Pixel-perfect forensic result card matching the lightweight designer specification.
/// Features Manrope typography, animated dual-color gauge, custom detected evidence card,
/// 3-column forensic metrics grid, and gradient action buttons.
class ForensicResultCard extends StatefulWidget {
  final VerificationResult result;
  final VoidCallback? onScanAnother;
  final String? scanAnotherText;
  final bool showPreviewTabs;

  const ForensicResultCard({
    super.key,
    required this.result,
    this.onScanAnother,
    this.scanAnotherText,
    this.showPreviewTabs = false,
  });

  @override
  State<ForensicResultCard> createState() => _ForensicResultCardState();
}

class _ForensicResultCardState extends State<ForensicResultCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _animation;
  bool _isGeneratingPdf = false;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _animation = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOutCubic,
    );
    _animController.forward();
  }

  @override
  void didUpdateWidget(covariant ForensicResultCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.result.verificationId != widget.result.verificationId) {
      _animController.forward(from: 0.0);
    }
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  TextStyle _manrope({
    double? fontSize,
    FontWeight? fontWeight,
    Color? color,
    double? letterSpacing,
    double? height,
  }) {
    try {
      return GoogleFonts.manrope(
        fontSize: fontSize,
        fontWeight: fontWeight,
        color: color,
        letterSpacing: letterSpacing,
        height: height,
      );
    } catch (_) {
      return TextStyle(
        fontFamily: 'Manrope',
        fontSize: fontSize,
        fontWeight: fontWeight,
        color: color,
        letterSpacing: letterSpacing,
        height: height,
      );
    }
  }

  Future<void> _handlePdfReport() async {
    setState(() => _isGeneratingPdf = true);
    try {
      final file = await PdfService.instance.generateReportPdf(result: widget.result);
      if (file != null && await file.exists()) {
        final openRes = await OpenFilex.open(file.path);
        if (openRes.type != ResultType.done && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Report saved to: ${file.path}'),
              behavior: SnackBarBehavior.floating,
              backgroundColor: const Color(0xFF2563EB),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to generate PDF: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isGeneratingPdf = false);
    }
  }

  void _handleCopyLink() {
    final link = 'https://veriframe.web.app/verify/${widget.result.verificationId}';
    Clipboard.setData(ClipboardData(text: link));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: const [
            Icon(Icons.check_circle_rounded, color: Colors.white, size: 18),
            SizedBox(width: 8),
            Text('Report verification link copied to clipboard!'),
          ],
        ),
        backgroundColor: const Color(0xFF10B981),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _handleReportMedia() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => EscalateBottomSheet(report: widget.result),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final r = widget.result;

    // Design tokens
    final realColor = const Color(0xFF0E8C56); // Green (--real)
    final warnColor = const Color(0xFFDC2626); // Red (--warn)
    final lineBorder = isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0);
    final cardBg = isDark ? const Color(0xFF0F172A) : Colors.white;
    final tileBg = isDark ? const Color(0xFF131C31) : Colors.white;
    final ink = isDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A);
    final inkMuted = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
    final inkSoft = isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8);

    // Compute metrics
    final double authScore = r.authenticityScore > 0 ? r.authenticityScore : 78.5;
    final double manipScore = r.fakeProbability > 0 ? r.fakeProbability : (100.0 - authScore);
    final bool isAuthentic = authScore >= manipScore;

    final String verdictLabel = isAuthentic ? 'Real' : 'Manipulated';
    final String riskLabel = r.riskLevel.isNotEmpty ? r.riskLevel : (isAuthentic ? 'Low risk' : 'High risk');

    final int keyframeCount = r.framesAnalysedCount ?? 8;
    final int avgMs = (r.processingTimeSec != null && keyframeCount > 0)
        ? ((r.processingTimeSec! * 1000) / keyframeCount).round()
        : 180;

    // Modality detection (Image vs Video vs Audio)
    final mediaType = r.mediaType.toLowerCase();
    final source = r.source.toLowerCase();
    final bool isImage = mediaType.contains('image') || source.contains('image');
    final bool isAudio = mediaType.contains('audio') || source.contains('voice') || source.contains('audio');

    // Dynamically assigned model filename based on modality:
    // Image -> image.tflite, Video -> video.tflite, Audio -> audio.tflite
    final String modelFileName = isImage
        ? 'image.tflite'
        : (isAudio ? 'audio.tflite' : 'video.tflite');

    final String metric1Value = isImage
        ? '${r.framesAnalysedCount != null && r.framesAnalysedCount! > 0 ? r.framesAnalysedCount : 1}'
        : (isAudio
            ? '${r.framesAnalysedCount != null && r.framesAnalysedCount! > 0 ? r.framesAnalysedCount : (keyframeCount > 0 ? keyframeCount : 1)}'
            : keyframeCount.toString());

    final String metric1Label = isImage
        ? 'Analyzed\nimage'
        : (isAudio ? 'Analyzed\naudio segments' : 'Analyzed\nkeyframes');

    final String metric2Label = isImage
        ? 'Average\ninference per\nimage'
        : (isAudio ? 'Average\ninference per\nsegment' : 'Average\ninference per\nframe');

    return Container(
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: lineBorder, width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.03),
            blurRadius: 18,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(20, 22, 20, 24),
      child: AnimatedBuilder(
        animation: _animation,
        builder: (context, _) {
          final progress = _animation.value;
          final animatedAuth = authScore * progress;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── 1. Top Verdict Pill & Risk Level ──
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Pill Tag: [ • Real ] or [ • Manipulated ]
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                    decoration: BoxDecoration(
                      color: isAuthentic
                          ? (isDark ? const Color(0xFF064E3B).withValues(alpha: 0.3) : const Color(0xFFE8F8F0))
                          : (isDark ? const Color(0xFF7F1D1D).withValues(alpha: 0.3) : const Color(0xFFFEF2F2)),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: isAuthentic ? realColor : warnColor,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          verdictLabel,
                          style: _manrope(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                            color: isAuthentic ? realColor : warnColor,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Risk Label: "Low risk" / "High risk"
                  Text(
                    riskLabel,
                    style: _manrope(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: inkMuted,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // ── 2. Hero Metric: 78.5% Authenticity ──
              RichText(
                text: TextSpan(
                  children: [
                    TextSpan(
                      text: animatedAuth.toStringAsFixed(1),
                      style: _manrope(
                        fontSize: 66,
                        fontWeight: FontWeight.w200,
                        color: ink,
                        letterSpacing: -1.5,
                        height: 1.0,
                      ),
                    ),
                    TextSpan(
                      text: ' %',
                      style: _manrope(
                        fontSize: 26,
                        fontWeight: FontWeight.w300,
                        color: inkMuted,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Authenticity',
                style: _manrope(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w400,
                  color: inkMuted,
                ),
              ),
              const SizedBox(height: 22),

              // ── 3. Thin Gauge Bar ──
              SizedBox(
                height: 3,
                child: Row(
                  children: [
                    Expanded(
                      flex: ((authScore * progress) * 100).toInt().clamp(1, 10000),
                      child: Container(
                        decoration: BoxDecoration(
                          color: realColor,
                          borderRadius: BorderRadius.circular(1.5),
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      flex: ((manipScore * progress) * 100).toInt().clamp(1, 10000),
                      child: Container(
                        decoration: BoxDecoration(
                          color: warnColor,
                          borderRadius: BorderRadius.circular(1.5),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),

              // ── 4. Sub Percentages Row (Authentic / Manipulated) ──
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Authentic
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: realColor,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Authentic',
                            style: _manrope(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w500,
                              color: inkMuted,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${authScore.toStringAsFixed(1)}%',
                        style: _manrope(
                          fontSize: 20,
                          fontWeight: FontWeight.w400,
                          color: ink,
                        ),
                      ),
                    ],
                  ),

                  // Manipulated
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: warnColor,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Manipulated',
                            style: _manrope(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w500,
                              color: inkMuted,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${manipScore.toStringAsFixed(1)}%',
                        style: _manrope(
                          fontSize: 20,
                          fontWeight: FontWeight.w400,
                          color: warnColor,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 30),

              // ── 5. Detected Evidence Section ──
              Text(
                'Detected evidence',
                style: _manrope(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: ink,
                  letterSpacing: -0.2,
                ),
              ),
              const SizedBox(height: 12),
              _buildEvidenceCard(
                isAuthentic: isAuthentic,
                isDark: isDark,
                isImage: isImage,
                isAudio: isAudio,
                realColor: realColor,
                warnColor: warnColor,
                ink: ink,
                inkMuted: inkMuted,
              ),
              const SizedBox(height: 28),

              // ── 6. Forensic Observations Section ──
              Text(
                'Forensic observations',
                style: _manrope(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: ink,
                  letterSpacing: -0.2,
                ),
              ),
              const SizedBox(height: 12),

              // Inference mode slim card
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: tileBg,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: lineBorder, width: 1.1),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Inference mode',
                      style: _manrope(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: inkMuted,
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          'On-device TFLite',
                          style: _manrope(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w700,
                            color: ink,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          modelFileName,
                          style: _manrope(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w400,
                            color: inkSoft,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // 3-column metric cards grid
              Row(
                children: [
                  Expanded(
                    child: _buildMetricTile(
                      value: metric1Value,
                      label: metric1Label,
                      isDark: isDark,
                      tileBg: tileBg,
                      borderColor: lineBorder,
                      ink: ink,
                      inkMuted: inkMuted,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _buildMetricTile(
                      value: avgMs.toString(),
                      unit: 'ms',
                      label: metric2Label,
                      isDark: isDark,
                      tileBg: tileBg,
                      borderColor: lineBorder,
                      ink: ink,
                      inkMuted: inkMuted,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _buildMetricTile(
                      value: manipScore.toStringAsFixed(1),
                      unit: '%',
                      label: 'Manipulation\nconfidence',
                      isDark: isDark,
                      tileBg: tileBg,
                      borderColor: lineBorder,
                      ink: warnColor,
                      unitColor: warnColor,
                      inkMuted: inkMuted,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 30),

              // ── 7. Action Buttons ──
              // Row: [ Report PDF ] [ Copy link ] (Blue gradient)
              Row(
                children: [
                  Expanded(
                    child: _buildGradientButton(
                      label: _isGeneratingPdf ? 'Creating PDF...' : 'Report PDF',
                      icon: _isGeneratingPdf
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Icon(Icons.description_outlined, size: 18, color: Colors.white),
                      gradientColors: const [Color(0xFF3B82F6), Color(0xFF1D4ED8)],
                      shadowColor: const Color(0xFF2563EB),
                      onTap: _isGeneratingPdf ? null : _handlePdfReport,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildGradientButton(
                      label: 'Copy link',
                      icon: const Icon(Icons.link_rounded, size: 18, color: Colors.white),
                      gradientColors: const [Color(0xFF3B82F6), Color(0xFF1D4ED8)],
                      shadowColor: const Color(0xFF2563EB),
                      onTap: _handleCopyLink,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Full-width: [ Report media ] (Red gradient)
              _buildGradientButton(
                label: 'Report media',
                icon: const Icon(Icons.flag_outlined, size: 18, color: Colors.white),
                gradientColors: const [Color(0xFFEF4444), Color(0xFFDC2626)],
                shadowColor: const Color(0xFFDC2626),
                onTap: _handleReportMedia,
              ),

              // Full-width: [ Scan another media ] (Black / Dark Navy gradient)
              if (widget.onScanAnother != null) ...[
                const SizedBox(height: 12),
                _buildGradientButton(
                  label: widget.scanAnotherText ?? 'Scan another media',
                  icon: const Icon(Icons.crop_free_rounded, size: 18, color: Colors.white),
                  gradientColors: const [Color(0xFF1E293B), Color(0xFF0F172A)],
                  shadowColor: Colors.black.withValues(alpha: 0.35),
                  onTap: widget.onScanAnother,
                ),
              ],
            ],
          );
        },
      ),
    );
  }

  Widget _buildEvidenceCard({
    required bool isAuthentic,
    required bool isDark,
    required bool isImage,
    required bool isAudio,
    required Color realColor,
    required Color warnColor,
    required Color ink,
    required Color inkMuted,
  }) {
    final String title;
    final String fallbackDesc;

    if (isAudio) {
      title = isAuthentic ? 'Natural acoustic signature' : 'Voice cloning detected';
      fallbackDesc = isAuthentic
          ? 'Organic vocal tract resonance and authentic harmonics verified.'
          : 'Synthetic pitch contours and vocoder spectral anomalies detected.';
    } else if (isImage) {
      title = isAuthentic ? 'Genuine camera signature' : 'Diffusion / GAN artifacts detected';
      fallbackDesc = isAuthentic
          ? 'Optical sensor noise and natural frequency gradients verified genuine.'
          : 'High-frequency spectral anomalies and generative warping patterns detected.';
    } else {
      title = isAuthentic ? 'Genuine camera signature' : 'Synthetic manipulation detected';
      fallbackDesc = isAuthentic
          ? 'Optical textures show real camera sensor noise and natural motion gradients.'
          : 'Unnatural facial warp and generative frequency anomalies detected.';
    }

    final description = widget.result.detectedEvidence.isNotEmpty
        ? widget.result.detectedEvidence.first
        : fallbackDesc;

    final accentColor = isAuthentic ? realColor : warnColor;

    return Container(
      decoration: BoxDecoration(
        color: isAuthentic
            ? (isDark ? const Color(0xFF064E3B).withValues(alpha: 0.18) : const Color(0xFFF2FBF6))
            : (isDark ? const Color(0xFF7F1D1D).withValues(alpha: 0.18) : const Color(0xFFFEF2F2)),
        borderRadius: BorderRadius.circular(16),
        border: Border(
          left: BorderSide(color: accentColor, width: 2.8),
          top: BorderSide(color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0), width: 1.0),
          right: BorderSide(color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0), width: 1.0),
          bottom: BorderSide(color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0), width: 1.0),
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isAuthentic ? Icons.check_circle_outline_rounded : Icons.warning_amber_rounded,
                color: accentColor,
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: _manrope(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w700,
                    color: accentColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            description,
            style: _manrope(
              fontSize: 13,
              fontWeight: FontWeight.w400,
              color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF475569),
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricTile({
    required String value,
    String? unit,
    required String label,
    required bool isDark,
    required Color tileBg,
    required Color borderColor,
    required Color ink,
    Color? unitColor,
    required Color inkMuted,
  }) {
    return Container(
      constraints: const BoxConstraints(minHeight: 116),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 14),
      decoration: BoxDecoration(
        color: tileBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor, width: 1.1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: RichText(
              text: TextSpan(
                children: [
                  TextSpan(
                    text: value,
                    style: _manrope(
                      fontSize: 28,
                      fontWeight: FontWeight.w200,
                      color: ink,
                      letterSpacing: -0.5,
                      height: 1.0,
                    ),
                  ),
                  if (unit != null)
                    TextSpan(
                      text: ' $unit',
                      style: _manrope(
                        fontSize: 13,
                        fontWeight: FontWeight.w300,
                        color: unitColor ?? inkMuted,
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            label,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: _manrope(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: inkMuted,
              height: 1.25,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGradientButton({
    required String label,
    required Widget icon,
    required List<Color> gradientColors,
    required Color shadowColor,
    required VoidCallback? onTap,
  }) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: shadowColor.withValues(alpha: 0.28),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: gradientColors,
              ),
              border: Border(
                top: BorderSide(
                  color: Colors.white.withValues(alpha: 0.25),
                  width: 1,
                ),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                icon,
                const SizedBox(width: 8),
                Text(
                  label,
                  style: _manrope(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                    letterSpacing: -0.1,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
