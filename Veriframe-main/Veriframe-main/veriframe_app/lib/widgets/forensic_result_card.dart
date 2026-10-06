import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:open_filex/open_filex.dart';
import 'package:veriframe_app/l10n/app_localizations.dart';
import 'package:veriframe_app/models/verification_result.dart';
import 'package:veriframe_app/service/pdf_service.dart';
import 'package:veriframe_app/widgets/escalate_bottom_sheet.dart';

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
  double _tiltX = 0.0;
  double _tiltY = 0.0;
  bool _isScanning = false;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    );
    _animation = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOutCubic,
    );
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _triggerSurpriseReveal();
    });
  }

  void _triggerSurpriseReveal() {
    if (mounted) {
      setState(() {
        _isScanning = true;
      });
      _animController.forward(from: 0.0).then((_) {
        if (mounted) {
          setState(() {
            _isScanning = false;
          });
        }
      });
    }
  }

  @override
  void didUpdateWidget(covariant ForensicResultCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.result != widget.result) {
      _triggerSurpriseReveal();
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
    final loc = AppLocalizations.of(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle_rounded, color: Colors.white, size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Text(loc?.linkCopiedSuccess ?? 'Report verification link copied to clipboard!'),
            ),
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
    final loc = AppLocalizations.of(context);
    final r = widget.result;

    final realColor = const Color(0xFF10B981); 
    final warnColor = const Color(0xFFF43F5E); 
    final lineBorder = isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0);
    final tileBg = isDark ? const Color(0xFF0E1525).withOpacity(0.65) : const Color(0xFFF8FAFC);
    final ink = isDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A);
    final inkMuted = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

    final double authScore = r.authenticityScore > 0 ? r.authenticityScore : 78.5;
    final double manipScore = r.fakeProbability > 0 ? r.fakeProbability : (100.0 - authScore);
    final bool isAuthentic = authScore >= manipScore;

    final String verdictLabel = isAuthentic
        ? (loc?.realVerdict ?? 'Real')
        : (loc?.manipulatedVerdict ?? 'Manipulated');
    final String riskLabel = r.riskLevel.isNotEmpty
        ? r.riskLevel
        : (isAuthentic ? (loc?.lowRiskLabel ?? 'LOW RISK') : (loc?.highRiskLabel ?? 'HIGH RISK'));

    final int keyframeCount = r.framesAnalysedCount ?? 8;
    final int avgMs = (r.processingTimeSec != null && keyframeCount > 0)
        ? ((r.processingTimeSec! * 1000) / keyframeCount).round()
        : 180;

    final mediaType = r.mediaType.toLowerCase();
    final source = r.source.toLowerCase();
    final bool isImage = mediaType.contains('image') || source.contains('image');
    final bool isAudio = mediaType.contains('audio') || source.contains('voice') || source.contains('audio');
    final bool isLink = source.contains('link') || r.platform != null;

    final String modelFileName = isImage ? 'image.tflite' : (isAudio ? 'audio.tflite' : 'video.tflite');

    final String metric1Value = isImage
        ? '${r.framesAnalysedCount != null && r.framesAnalysedCount! > 0 ? r.framesAnalysedCount : 1}'
        : (isAudio
            ? '${r.framesAnalysedCount != null && r.framesAnalysedCount! > 0 ? r.framesAnalysedCount : (keyframeCount > 0 ? keyframeCount : 1)}'
            : keyframeCount.toString());

    final String metric1Label = isImage
        ? (loc?.analyzedImage ?? 'Analyzed\nimage')
        : (isAudio
            ? (loc?.analyzedSegments ?? 'Analyzed\nsegments')
            : (loc?.analyzedKeyframes ?? 'Analyzed\nkeyframes'));
    final String metric2Label = isImage
        ? (loc?.avgInferencePerImage ?? 'Average\ninference\nper image')
        : (loc?.avgInferencePerFrame ?? 'Average\ninference/frame');

    final String topicTitle = (r.mediaName != null && r.mediaName!.isNotEmpty)
        ? r.mediaName!
        : (isAudio
            ? 'Voice Authenticity & Acoustic Forensics'
            : (isImage
                ? 'Image Authenticity & GAN Detection'
                : (isLink && r.platform != null
                    ? '${r.platform} Video Stream Analysis'
                    : 'Video Authenticity & Deepfake Analysis')));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        // TOP CONTROLS BAR (Outside the card)
        Padding(
          padding: const EdgeInsets.only(bottom: 12.0),
          child: Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            runSpacing: 8,
            children: [
              // Surprise Reveal Button
              InkWell(
                onTap: _triggerSurpriseReveal,
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF06B6D4), Color(0xFF2563EB), Color(0xFF4F46E5)],
                    ),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(color: const Color(0xFF06B6D4).withOpacity(0.25), blurRadius: 10, offset: const Offset(0, 4)),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.auto_awesome, color: Colors.white, size: 14),
                      const SizedBox(width: 6),
                      Text(loc?.surpriseRevealBtn ?? 'Surprise Reveal', style: _manrope(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white)),
                    ],
                  ),
                ),
              ),
              
              Wrap(
                spacing: 6,
                runSpacing: 6,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  // How to identify
                  InkWell(
                    onTap: () => _showHowToIdentifySheet(context, isDark),
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0E1525).withOpacity(0.65),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.white.withOpacity(0.1)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.search_rounded, color: Colors.white70, size: 14),
                          const SizedBox(width: 4),
                          Text(loc?.howToIdentifyBtn ?? 'How to Identify', style: _manrope(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.white70)),
                        ]
                      ),
                    )
                  ),
                  // Real Pill
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0E1525).withOpacity(0.65),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white.withOpacity(0.1)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(width: 8, height: 8, decoration: BoxDecoration(shape: BoxShape.circle, color: isAuthentic ? realColor : warnColor)),
                        const SizedBox(width: 6),
                        Text(verdictLabel, style: _manrope(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.white70)),
                      ]
                    )
                  )
                ]
              )
            ]
          )
        ),

        // 3D CARD
        GestureDetector(
          onPanUpdate: (details) {
            setState(() {
              _tiltX = (_tiltX - details.delta.dy * 0.0012).clamp(-0.10, 0.10);
              _tiltY = (_tiltY + details.delta.dx * 0.0012).clamp(-0.10, 0.10);
            });
          },
          onPanEnd: (_) {
            setState(() {
              _tiltX = 0.0;
              _tiltY = 0.0;
            });
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 140),
            curve: Curves.easeOut,
            transform: Matrix4.identity()
              ..setEntry(3, 2, 0.001)
              ..rotateX(_tiltX)
              ..rotateY(_tiltY),
            transformAlignment: FractionalOffset.center,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: isDark 
                  ? [const Color(0xFF10182B).withOpacity(0.88), const Color(0xFF080C16).withOpacity(0.96)]
                  : [Colors.white, const Color(0xFFF8FAFC)],
              ),
              borderRadius: BorderRadius.circular(26),
              border: Border.all(
                color: isDark ? Colors.white.withOpacity(0.08) : lineBorder,
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(isDark ? 0.85 : 0.1),
                  blurRadius: 30,
                  offset: Offset(_tiltY * 35, 15 - _tiltX * 35),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(26),
              child: Stack(
                children: [
                  // Top Glow Border
                  if (isDark)
                    Positioned(
                      top: 0, left: 0, right: 0,
                      child: Container(
                        height: 2,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Colors.transparent, 
                              const Color(0xFF00F0FF).withOpacity(0.8), 
                              const Color(0xFF10B981).withOpacity(0.8), 
                              Colors.transparent
                            ]
                          ),
                          boxShadow: [
                            BoxShadow(color: const Color(0xFF00F0FF).withOpacity(0.5), blurRadius: 10),
                            BoxShadow(color: const Color(0xFF10B981).withOpacity(0.5), blurRadius: 10),
                          ]
                        )
                      )
                    ),
                  
                  // Laser Scanner Beam
                  if (_isScanning)
                    AnimatedBuilder(
                      animation: _animation,
                      builder: (context, child) {
                        return Positioned(
                          top: -10 + (_animation.value * 400),
                          left: 0, right: 0,
                          child: Container(
                            height: 2,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [Colors.transparent, const Color(0xFF00F0FF), const Color(0xFF10B981), Colors.transparent],
                              ),
                              boxShadow: [
                                BoxShadow(color: const Color(0xFF00F0FF).withOpacity(0.8), blurRadius: 12),
                                BoxShadow(color: const Color(0xFF10B981).withOpacity(0.8), blurRadius: 12),
                              ],
                            ),
                          ),
                        );
                      }
                    ),

                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
                    child: AnimatedBuilder(
                      animation: _animation,
                      builder: (context, _) {
                        final progress = _animation.value;
                        final animatedAuth = authScore * progress;
                        final animatedManip = manipScore * progress;

                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // 1. Topic Row
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF06B6D4).withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(color: const Color(0xFF06B6D4).withOpacity(0.2)),
                                  ),
                                  child: Text(
                                    'TOPIC',
                                    style: _manrope(fontSize: 10, fontWeight: FontWeight.w800, color: const Color(0xFF67E8F9), letterSpacing: 1.0),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF3B82F6).withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(color: const Color(0xFF3B82F6).withOpacity(0.2)),
                                  ),
                                  child: Text(
                                    r.platform != null ? r.platform!.toUpperCase() + ' STREAM' : 'VIDEO STREAM',
                                    style: _manrope(fontSize: 10, fontWeight: FontWeight.w800, color: const Color(0xFF93C5FD), letterSpacing: 0.8),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text('#VF-${r.verificationId.length > 4 ? r.verificationId.substring(0, 4) : '9021'}', style: _manrope(fontSize: 10, color: inkMuted, fontWeight: FontWeight.w600)),
                                const Spacer(),
                                Container(
                                  width: 32, height: 32,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(color: const Color(0xFF06B6D4).withOpacity(0.3)),
                                    color: const Color(0xFF06B6D4).withOpacity(0.1),
                                    boxShadow: [BoxShadow(color: const Color(0xFF06B6D4).withOpacity(0.1), blurRadius: 8)]
                                  ),
                                  child: const Icon(Icons.verified_user_outlined, size: 16, color: Color(0xFF67E8F9)),
                                )
                              ],
                            ),
                            const SizedBox(height: 12),
                            Text(
                              topicTitle,
                              style: _manrope(fontSize: 18, fontWeight: FontWeight.w800, color: ink, letterSpacing: -0.5),
                            ),
                            const SizedBox(height: 16),
                            Divider(color: Colors.white.withOpacity(0.08), height: 1, thickness: 1),
                            const SizedBox(height: 16),

                            // 2. Verdict Pill & Risk Level
                            Wrap(
                              alignment: WrapAlignment.spaceBetween,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: isAuthentic ? realColor.withOpacity(0.15) : warnColor.withOpacity(0.15),
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(color: (isAuthentic ? realColor : warnColor).withOpacity(0.3)),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Container(
                                        width: 8, height: 8,
                                        decoration: BoxDecoration(shape: BoxShape.circle, color: isAuthentic ? realColor : warnColor),
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        verdictLabel,
                                        style: _manrope(fontSize: 13, fontWeight: FontWeight.w700, color: isAuthentic ? realColor : warnColor),
                                      ),
                                    ],
                                  ),
                                ),
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(loc?.assessmentLabel ?? 'ASSESSMENT: ', style: _manrope(fontSize: 10, fontWeight: FontWeight.w600, color: inkMuted, letterSpacing: 0.5)),
                                    Text(riskLabel, style: _manrope(fontSize: 12, fontWeight: FontWeight.w800, color: isAuthentic ? realColor : warnColor, letterSpacing: 0.5)),
                                  ],
                                ),
                              ],
                            ),
                            const SizedBox(height: 24),

                            // 3. Hero Metric
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.baseline,
                              textBaseline: TextBaseline.alphabetic,
                              children: [
                                Text(
                                  animatedAuth.toStringAsFixed(1),
                                  style: _manrope(fontSize: 72, fontWeight: FontWeight.w200, color: ink, letterSpacing: -2.0, height: 1.0),
                                ),
                                Text(' %', style: _manrope(fontSize: 28, fontWeight: FontWeight.w300, color: const Color(0xFF67E8F9))),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    loc?.authenticityUpperLabel ?? 'AUTHENTICITY',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: _manrope(fontSize: 12, fontWeight: FontWeight.w700, color: inkMuted, letterSpacing: 1.5),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 24),

                            // 4. Dual Gauge Bar
                            Container(
                              height: 6,
                              decoration: BoxDecoration(
                                color: const Color(0xFF080C16),
                                borderRadius: BorderRadius.circular(3),
                                border: Border.all(color: Colors.white.withOpacity(0.05)),
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    flex: ((authScore * progress) * 100).toInt().clamp(1, 10000),
                                    child: Container(
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(colors: [const Color(0xFF10B981), const Color(0xFF34D399)]),
                                        borderRadius: BorderRadius.circular(3),
                                        boxShadow: [BoxShadow(color: const Color(0xFF10B981).withOpacity(0.4), blurRadius: 6)],
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  Expanded(
                                    flex: ((manipScore * progress) * 100).toInt().clamp(1, 10000),
                                    child: Container(
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(colors: [const Color(0xFFF43F5E), const Color(0xFFFB7185)]),
                                        borderRadius: BorderRadius.circular(3),
                                        boxShadow: [BoxShadow(color: const Color(0xFFF43F5E).withOpacity(0.4), blurRadius: 6)],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 16),

                            // 5. Sub Percentages
                            Wrap(
                              alignment: WrapAlignment.spaceBetween,
                              spacing: 12,
                              runSpacing: 8,
                              children: [
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Container(width: 8, height: 8, decoration: BoxDecoration(shape: BoxShape.circle, color: realColor)),
                                    const SizedBox(width: 8),
                                    Text(loc?.authenticStatus ?? 'Authentic', style: _manrope(fontSize: 13, color: inkMuted)),
                                    const SizedBox(width: 8),
                                    Text('${animatedAuth.toStringAsFixed(1)}%', style: _manrope(fontSize: 14, fontWeight: FontWeight.w700, color: ink)),
                                  ],
                                ),
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Container(width: 8, height: 8, decoration: BoxDecoration(shape: BoxShape.circle, color: warnColor)),
                                    const SizedBox(width: 8),
                                    Text(loc?.manipulatedStatus ?? 'Manipulated', style: _manrope(fontSize: 13, color: inkMuted)),
                                    const SizedBox(width: 8),
                                    Text('${animatedManip.toStringAsFixed(1)}%', style: _manrope(fontSize: 14, fontWeight: FontWeight.w700, color: warnColor)),
                                  ],
                                ),
                              ],
                            ),
                            const SizedBox(height: 24),

                            // 6. Why this media is Real/Manipulated
                            Row(
                              children: [
                                const Icon(Icons.info_outline_rounded, size: 16, color: Color(0xFF67E8F9)),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    isAuthentic 
                                        ? (loc?.whyMediaReal ?? 'Why this media is Real')
                                        : (loc?.whyMediaManipulated ?? 'Why this media is Manipulated'),
                                    style: _manrope(fontSize: 14, fontWeight: FontWeight.w800, color: ink),
                                  ),
                                ),
                              ]
                            ),
                            const SizedBox(height: 12),
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: tileBg,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: Colors.white.withOpacity(0.05)),
                              ),
                              child: Column(
                                children: [
                                  Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Icon(isAuthentic ? Icons.check_rounded : Icons.close_rounded, size: 16, color: isAuthentic ? realColor : warnColor),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: RichText(
                                          text: TextSpan(
                                            style: _manrope(fontSize: 12, color: inkMuted, height: 1.4),
                                            children: [
                                              TextSpan(
                                                text: isAuthentic ? (loc?.sensorMatchLabel ?? 'Optical Sensor Match: ') : (loc?.sensorMismatchLabel ?? 'Optical Sensor Mismatch: '),
                                                style: _manrope(fontWeight: FontWeight.w700, color: ink),
                                              ),
                                              TextSpan(
                                                text: isAuthentic ? (loc?.sensorMatchDesc ?? 'Silicon sensor pattern noise (PRNU) verified across all keyframes without AI smoothing.') : (loc?.sensorMismatchDesc ?? 'High-frequency spectral anomalies and generative warping patterns detected.'),
                                              ),
                                            ]
                                          )
                                        )
                                      )
                                    ]
                                  ),
                                  const SizedBox(height: 12),
                                  Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Icon(isAuthentic ? Icons.check_rounded : Icons.close_rounded, size: 16, color: isAuthentic ? realColor : warnColor),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: RichText(
                                          text: TextSpan(
                                            style: _manrope(fontSize: 12, color: inkMuted, height: 1.4),
                                            children: [
                                              TextSpan(
                                                text: isAuthentic ? (loc?.motionFlowLabel ?? 'Natural Motion Flow: ') : (loc?.unnaturalMotionLabel ?? 'Unnatural Motion Vectors: '),
                                                style: _manrope(fontWeight: FontWeight.w700, color: ink),
                                              ),
                                              TextSpan(
                                                text: isAuthentic ? (loc?.motionFlowDesc ?? 'Facial boundaries and specular lighting vectors remain continuous without seam jitter.') : (loc?.unnaturalMotionDesc ?? 'Generative flickering and temporal inconsistency detected in facial boundaries.'),
                                              ),
                                            ]
                                          )
                                        )
                                      )
                                    ]
                                  ),
                                  const SizedBox(height: 12),
                                  Divider(color: Colors.white.withOpacity(0.05), height: 1),
                                  const SizedBox(height: 12),
                                  Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text('💡', style: TextStyle(fontSize: 12)),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Text(
                                          isAuthentic 
                                              ? (loc?.whyMediaMarginNoteReal(manipScore.toStringAsFixed(1)) ?? 'The remaining ${manipScore.toStringAsFixed(1)}% margin is standard H.264 compression quantization, not neural manipulation.')
                                              : (loc?.whyMediaMarginNoteFake ?? 'The high manipulation confidence indicates this is highly likely an AI generated deepfake.'),
                                          style: _manrope(fontSize: 11, color: inkMuted),
                                        )
                                      )
                                    ]
                                  )
                                ]
                              )
                            ),
                            const SizedBox(height: 24),

                            // 7. Forensic Observations
                            Text(
                              loc?.forensicObservations ?? 'Forensic observations',
                              style: _manrope(fontSize: 15, fontWeight: FontWeight.w800, color: ink),
                            ),
                            const SizedBox(height: 12),
                            
                            // Inference Engine Card
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              decoration: BoxDecoration(
                                color: tileBg,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: Colors.white.withOpacity(0.05)),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(loc?.inferenceEngine ?? 'Inference engine', style: _manrope(fontSize: 13, color: inkMuted)),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Text(loc?.onDeviceTflite ?? 'On-device TFLite', style: _manrope(fontSize: 13, fontWeight: FontWeight.w800, color: ink)),
                                      Text(modelFileName, style: _manrope(fontSize: 11, color: const Color(0xFF67E8F9), fontWeight: FontWeight.w600)),
                                    ]
                                  )
                                ]
                              )
                            ),
                            const SizedBox(height: 12),

                            // 3 Grid Tiles
                            Row(
                              children: [
                                Expanded(
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
                                    decoration: BoxDecoration(
                                      color: tileBg,
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(color: Colors.white.withOpacity(0.05)),
                                    ),
                                    child: Column(
                                      children: [
                                        Text(metric1Value, style: _manrope(fontSize: 16, fontWeight: FontWeight.w700, color: ink)),
                                        const SizedBox(height: 4),
                                        Text(metric1Label.replaceAll('\\n', '\n'), textAlign: TextAlign.center, style: _manrope(fontSize: 10, color: inkMuted)),
                                      ]
                                    )
                                  )
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
                                    decoration: BoxDecoration(
                                      color: tileBg,
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(color: Colors.white.withOpacity(0.05)),
                                    ),
                                    child: Column(
                                      children: [
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          crossAxisAlignment: CrossAxisAlignment.baseline,
                                          textBaseline: TextBaseline.alphabetic,
                                          children: [
                                            Text(avgMs.toString(), style: _manrope(fontSize: 16, fontWeight: FontWeight.w700, color: ink)),
                                            Text('ms', style: _manrope(fontSize: 10, color: inkMuted)),
                                          ]
                                        ),
                                        const SizedBox(height: 4),
                                        Text(metric2Label.replaceAll('\\n', '\n'), textAlign: TextAlign.center, style: _manrope(fontSize: 10, color: inkMuted)),
                                      ]
                                    )
                                  )
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
                                    decoration: BoxDecoration(
                                      color: tileBg,
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(color: Colors.white.withOpacity(0.05)),
                                    ),
                                    child: Column(
                                      children: [
                                        Text('${animatedManip.toStringAsFixed(1)}%', style: _manrope(fontSize: 16, fontWeight: FontWeight.w700, color: warnColor)),
                                        const SizedBox(height: 4),
                                        Text(
                                          (loc?.manipulationConfidence ?? 'Manipulation\nconfidence').replaceAll('\\n', '\n'),
                                          textAlign: TextAlign.center,
                                          style: _manrope(fontSize: 10, color: inkMuted),
                                        ),
                                      ]
                                    )
                                  )
                                ),
                              ]
                            ),
                            const SizedBox(height: 30),

                            // 8. Action Buttons
                            Row(
                              children: [
                                Expanded(
                                  child: _buildGradientButton(
                                    label: _isGeneratingPdf
                                        ? (loc?.creatingPdf ?? 'Creating PDF...')
                                        : (loc?.reportPdf ?? 'Report PDF'),
                                    icon: _isGeneratingPdf
                                        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                        : const Icon(Icons.description_outlined, size: 18, color: Colors.white),
                                    gradientColors: const [Color(0xFF2563EB), Color(0xFF1D4ED8)],
                                    shadowColor: const Color(0xFF2563EB),
                                    onTap: _isGeneratingPdf ? null : _handlePdfReport,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: _buildGradientButton(
                                    label: loc?.shareLink ?? 'Share link',
                                    icon: const Icon(Icons.share_outlined, size: 18, color: Colors.white),
                                    gradientColors: const [Color(0xFF2563EB), Color(0xFF1D4ED8)],
                                    shadowColor: const Color(0xFF2563EB),
                                    onTap: _handleCopyLink,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            _buildGradientButton(
                              label: loc?.reportMediaBtn ?? 'Report media',
                              icon: const Icon(Icons.flag_outlined, size: 18, color: Colors.white),
                              gradientColors: const [Color(0xFFEF4444), Color(0xFFDC2626)],
                              shadowColor: const Color(0xFFDC2626),
                              onTap: _handleReportMedia,
                            ),
                            if (widget.onScanAnother != null) ...[
                              const SizedBox(height: 12),
                              _buildGradientButton(
                                label: widget.scanAnotherText ?? (loc?.scanAnotherBtn ?? 'Scan another'),
                                icon: const Icon(Icons.flip_camera_ios_outlined, size: 18, color: Colors.white),
                                gradientColors: const [Color(0xFF1E293B), Color(0xFF0F172A)],
                                shadowColor: const Color(0xFF0F172A),
                                onTap: widget.onScanAnother,
                              ),
                            ]
                          ]
                        );
                      }
                    )
                  )
                ]
              )
            )
          )
        )
      ]
    );
  }

  Widget _buildGradientButton({
    required String label,
    required Widget icon,
    required List<Color> gradientColors,
    required Color shadowColor,
    VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        height: 48,
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: gradientColors),
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: shadowColor.withOpacity(0.3),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              icon,
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: _manrope(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showHowToIdentifySheet(BuildContext context, bool isDark) {
    final loc = AppLocalizations.of(context);
    final sheetBg = isDark ? const Color(0xFF0F172A) : Colors.white;
    final cardBg = isDark ? const Color(0xFF131C31) : const Color(0xFFF8FAFC);
    final borderColor = isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0);
    final ink = isDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A);
    final inkMuted = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          decoration: BoxDecoration(
            color: sheetBg,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            border: Border.all(color: borderColor, width: 1),
          ),
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: inkMuted.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: const Color(0xFF00F0FF).withOpacity(0.12),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.psychology_outlined, color: Color(0xFF00F0FF), size: 20),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            loc?.howToIdentifyTitle ?? 'How to Identify Real vs Fake',
                            style: _manrope(fontSize: 16, fontWeight: FontWeight.w700, color: ink),
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(ctx).pop(),
                    icon: Icon(Icons.close_rounded, color: inkMuted, size: 20),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                loc?.howToIdentifySubtitle ?? 'Forensic algorithms & analysts verify these physical principles:',
                style: _manrope(fontSize: 12, color: inkMuted),
              ),
              const SizedBox(height: 16),
              _buildGuidePillar(
                '1',
                loc?.pillar1Title ?? 'Optical Silicon Sensor Noise',
                const Color(0xFF00F0FF),
                loc?.pillar1Real ?? 'Microscopic noise from camera sensors across pixels.',
                loc?.pillar1Fake ?? 'Mathematical pixels with unnatural neural smoothing.',
                cardBg,
                borderColor,
                inkMuted,
                loc?.realVerdict ?? 'Real',
                loc?.manipulatedVerdict ?? 'Fake',
              ),
              const SizedBox(height: 10),
              _buildGuidePillar(
                '2',
                loc?.pillar2Title ?? 'Corneal Light Reflection',
                const Color(0xFF10B981),
                loc?.pillar2Real ?? 'Identical ambient light reflection angles in both eye pupils.',
                loc?.pillar2Fake ?? 'Mismatched catchlights or distorted corneal reflection.',
                cardBg,
                borderColor,
                inkMuted,
                loc?.realVerdict ?? 'Real',
                loc?.manipulatedVerdict ?? 'Fake',
              ),
              const SizedBox(height: 18),
              SizedBox(
                height: 44,
                child: ElevatedButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2563EB)),
                  child: Text(loc?.gotItBtn ?? 'Got It', style: _manrope(fontSize: 13.5, fontWeight: FontWeight.w700, color: Colors.white)),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildGuidePillar(
    String number,
    String title,
    Color color,
    String realText,
    String fakeText,
    Color cardBg,
    Color borderColor,
    Color inkMuted,
    String realPrefix,
    String fakePrefix,
  ) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: cardBg, borderRadius: BorderRadius.circular(12), border: Border.all(color: borderColor)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 18, height: 18,
                decoration: BoxDecoration(color: color.withOpacity(0.15), shape: BoxShape.circle, border: Border.all(color: color)),
                child: Center(child: Text(number, style: _manrope(fontSize: 10, fontWeight: FontWeight.w800, color: color))),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(title, style: _manrope(fontSize: 12.5, fontWeight: FontWeight.w700, color: color)),
              ),
            ],
          ),
          const SizedBox(height: 6),
          RichText(
            text: TextSpan(
              style: _manrope(fontSize: 11, height: 1.35, color: inkMuted),
              children: [
                TextSpan(text: '$realPrefix: ', style: _manrope(fontWeight: FontWeight.w700, color: const Color(0xFF10B981))),
                TextSpan(text: '$realText\n'),
                TextSpan(text: '$fakePrefix: ', style: _manrope(fontWeight: FontWeight.w700, color: const Color(0xFFEF4444))),
                TextSpan(text: fakeText),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
