import 'dart:io';
import 'dart:math' as math;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:veriframe_app/models/notification_model.dart';
import 'package:veriframe_app/models/verification_result.dart';
import 'package:veriframe_app/provider/verification_notifier.dart';
import 'package:veriframe_app/service/notification_service.dart';
import 'package:veriframe_app/service/verify_backend_service.dart';
import 'package:veriframe_app/widgets/forensic_result_card.dart';
import 'package:veriframe_app/widgets/main_scaffold.dart';
import 'package:veriframe_app/l10n/app_localizations.dart';

class AudioPage extends ConsumerStatefulWidget {
  const AudioPage({super.key});

  @override
  ConsumerState<AudioPage> createState() => _AudioPageState();
}

class _AudioPageState extends ConsumerState<AudioPage> {
  File? _selectedAudio;
  String? _audioFileName;
  int _audioFileSize = 0;

  bool _isAnalyzing = false;
  String _statusMessage = '';
  Map<String, dynamic>? _result;
  String? _errorMessage;

  Future<void> _showServerDialog() async {
    final currentUrl = await VerifyBackendService.instance.getBaseUrl();
    if (!mounted) return;
    final controller = TextEditingController(text: currentUrl);

    final loc = AppLocalizations.of(context)!;
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(loc.backendServerSettingsTitle),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Backend API server URL (Default: Render cloud backend):',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              decoration: const InputDecoration(
                labelText: 'Backend URL',
                hintText: 'https://veriframe-backend-3itd.onrender.com',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () async {
              controller.text = VerifyBackendService.defaultRemoteUrl;
              await VerifyBackendService.instance.saveBaseUrl(VerifyBackendService.defaultRemoteUrl);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Reset to Render Cloud Backend')),
                );
              }
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: Text(loc.resetToDefaultBtn),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(loc.verifyCancel),
          ),
          ElevatedButton(
            onPressed: () async {
              final newUrl = controller.text.trim();
              if (newUrl.isNotEmpty) {
                await VerifyBackendService.instance.saveBaseUrl(newUrl);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Backend URL set to $newUrl')),
                  );
                }
              }
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: Text(loc.verifyBackendSave),
          ),
        ],
      ),
    );
  }

  Future<void> _pickAudioFile() async {
    try {
      final res = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['mp3', 'wav', 'm4a', 'aac', 'flac', 'ogg'],
      );

      if (res != null && res.files.single.path != null) {
        setState(() {
          _selectedAudio = File(res.files.single.path!);
          _audioFileName = res.files.single.name;
          _audioFileSize = res.files.single.size;
          _result = null;
          _errorMessage = null;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to pick audio file: $e')),
        );
      }
    }
  }

  Future<void> _analyzeAudio() async {
    if (_selectedAudio == null) return;

    setState(() {
      _isAnalyzing = true;
      _errorMessage = null;
      _statusMessage = 'Uploading audio payload to forensic pipeline...';
    });

    try {
      final baseUrl = await VerifyBackendService.instance.getBaseUrl();
      setState(() => _statusMessage = 'Scanning acoustic spectrum & querying Cloud Voice AI...');
      final res = await VerifyBackendService.instance.verifyAudio(baseUrl, _selectedAudio!);

      setState(() {
        _result = res;
        _isAnalyzing = false;
      });

      final mediaName = _audioFileName ?? _selectedAudio!.path.split('/').last.split('\\').last;
      await _saveResultAndNotify(res, mediaName, mediaPath: _selectedAudio?.path);
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isAnalyzing = false;
      });
    }
  }

  /// Builds a [VerificationResult] from an audio pipeline response map, saves
  /// it to Firestore history, creates an in-app notification, and shows a
  /// local system notification.
  Future<void> _saveResultAndNotify(
    Map<String, dynamic> r,
    String mediaName, {
    String? mediaPath,
  }) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    try {
      final verdict = (r['verdict'] as String? ?? 'UNKNOWN');
      final fakeProbability = (r['fakeProbability'] as num?)?.toDouble() ?? 0.0;
      final authenticityScore = (r['authenticityScore'] as num?)?.toDouble() ?? 0.0;

      final result = VerificationResult(
        verificationId: r['verificationId'] as String? ??
            'VRF-AUD-${DateTime.now().millisecondsSinceEpoch}',
        verifiedAt:
            DateTime.tryParse(r['verifiedAt'] as String? ?? '') ?? DateTime.now(),
        mediaType: r['mediaType'] as String? ?? 'audio/mp3',
        source: r['source'] as String? ?? 'Audio Forensics',
        authenticityScore: authenticityScore,
        fakeProbability: fakeProbability,
        confidence: (r['confidence'] as num?)?.toDouble() ?? 0.0,
        metadataScore: 0.0,
        frameConsistency: 0.0,
        ocrConfidence: 0.0,
        trackingConfidence: 0.0,
        manipulationScore: fakeProbability,
        verdict: verdict,
        riskLevel: r['riskLevel'] as String? ?? 'MEDIUM',
        detectedEvidence: List<String>.from(r['detectedEvidence'] ?? []),
        forensicObservations: List<String>.from(r['forensicObservations'] ?? []),
        reportHash: r['reportHash'] as String? ?? '',
        mediaName: mediaName,
        mediaPath: mediaPath,
        thumbnailBase64: r['thumbnailBase64'] as String?,
        aiExplanation: r['aiExplanation'] as Map<String, dynamic>?,
      );

      await ref.read(verificationRepositoryProvider).saveResult(result);

      // Build notification
      final notifId = FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('notifications')
          .doc()
          .id;

      final isAuthentic = verdict.toUpperCase() == 'AUTHENTIC' ||
          verdict.toUpperCase() == 'REAL' ||
          verdict.toUpperCase() == 'LIKELY_REAL';
      final prediction = isAuthentic ? 'REAL' : 'FAKE';
      final notifScore = isAuthentic ? authenticityScore : fakeProbability;

      final notification = NotificationModel(
        id: notifId,
        title: 'VeriFrame — Audio Analysis Complete',
        message:
            'Analysis complete. Verdict: $verdict. '
            '${isAuthentic ? 'Authenticity' : 'Manipulation'}: '
            '${notifScore.toStringAsFixed(1)}%. Tap to view report.',
        type: 'verification_completed',
        reportId: result.verificationId,
        createdAt: DateTime.now(),
        isRead: false,
        score: notifScore,
        prediction: prediction,
        videoName: mediaName,
      );

      await NotificationService.instance.createNotification(uid, notification);
      await NotificationService.instance.showLocalNotification(
        id: notifId.hashCode,
        title: 'VeriFrame — Audio Analysis Complete',
        body:
            '$verdict: ${notifScore.toStringAsFixed(1)}% '
            '${isAuthentic ? 'authentic' : 'manipulated'}. Tap to view report.',
        payload: result.verificationId,
      );
    } catch (e) {
      debugPrint('[AudioPage] Failed to save result or send notification: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF090D16) : const Color(0xFFF6F8FC);
    final loc = AppLocalizations.of(context)!;

    return MainScaffold(
      backgroundColor: bg,
      showBack: true,
      title: Text(
        loc.audioVerificationTitle,
        style: const TextStyle(fontWeight: FontWeight.w800, letterSpacing: -0.5),
      ),
      extraActions: [
        IconButton(
          icon: const Icon(Icons.dns_outlined),
          tooltip: 'Backend Server',
          onPressed: _showServerDialog,
        ),
      ],
      body: _result != null ? _buildResultView(isDark, loc) : _buildUploadView(isDark, loc),
    );
  }

  Widget _buildUploadView(bool isDark, AppLocalizations loc) {
    const primaryColor = Color(0xFFEA580C);
    final bannerBg = isDark ? const Color(0xFF7C2D12).withValues(alpha: 0.2) : const Color(0xFFFFF7ED);
    final bannerBorder = isDark ? const Color(0xFF9A3412).withValues(alpha: 0.4) : const Color(0xFFFED7AA);
    final bannerTitleColor = isDark ? const Color(0xFFFED7AA) : const Color(0xFF9A3412);
    final bannerDescColor = isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569);
    final iconBoxBg = isDark ? const Color(0xFF431407) : Colors.white;
    final iconBoxBorder = isDark ? const Color(0xFF9A3412) : const Color(0xFFFDBA74);

    final cardBg = isDark ? const Color(0xFF1E293B).withValues(alpha: 0.5) : Colors.white;
    final circleBg = isDark ? const Color(0xFF431407).withValues(alpha: 0.4) : const Color(0xFFFFF7ED);
    final circleBorder = isDark ? const Color(0xFF9A3412).withValues(alpha: 0.4) : const Color(0xFFFED7AA);
    final borderColor = isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1);
    final titleColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final subtitleColor = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Top Card: Voice authenticity check ───────────────────────
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: bannerBg,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: bannerBorder, width: 1.0),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: iconBoxBg,
                        borderRadius: BorderRadius.circular(13),
                        border: Border.all(color: iconBoxBorder, width: 1.0),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.04),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: const Center(
                        child: Icon(
                          Icons.mic_none_rounded,
                          color: primaryColor,
                          size: 24,
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Text(
                        loc.audioVoiceDeepfakeTitle,
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: bannerTitleColor,
                          fontSize: 16.5,
                          letterSpacing: -0.2,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  loc.audioVoiceDeepfakeDesc,
                  style: TextStyle(
                    fontSize: 13.5,
                    height: 1.45,
                    color: bannerDescColor,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // ── Middle Card: Upload Box with Dashed Border ───────────────
          CustomPaint(
            painter: _DashedRRectPainter(
              color: borderColor,
              strokeWidth: 1.5,
              dashWidth: 5.5,
              dashSpace: 4.0,
              radius: 20.0,
            ),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 34),
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Warm Circle
                  Container(
                    width: 68,
                    height: 68,
                    decoration: BoxDecoration(
                      color: circleBg,
                      shape: BoxShape.circle,
                      border: Border.all(color: circleBorder, width: 1.0),
                    ),
                    child: Center(
                      child: Icon(
                        _selectedAudio != null
                            ? Icons.audiotrack_rounded
                            : Icons.graphic_eq_rounded,
                        color: primaryColor,
                        size: 32,
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    _selectedAudio != null
                        ? (_audioFileName ?? 'Audio file selected')
                        : loc.uploadAudioClipTitle,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 16.5,
                      color: titleColor,
                      letterSpacing: -0.2,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _selectedAudio != null
                        ? '${(_audioFileSize / 1024).toStringAsFixed(1)} KB • ${(_audioFileName ?? '').split('.').last.toUpperCase()}'
                        : loc.supportedAudioFormatsHint,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: subtitleColor,
                    ),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: _isAnalyzing ? null : _pickAudioFile,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryColor,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _selectedAudio != null
                              ? Icons.refresh_rounded
                              : Icons.file_upload_outlined,
                          color: Colors.white,
                          size: 19,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _selectedAudio != null ? 'Change file' : loc.browseAudioFileBtn,
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 14.5,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),

          // ── Error Message Banner (if any) ───────────────────────────
          if (_errorMessage != null) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.red.withValues(alpha: 0.3), width: 1.0),
              ),
              child: Row(
                children: [
                  const Icon(Icons.error_outline_rounded, color: Colors.red, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _errorMessage!,
                      style: const TextStyle(color: Colors.red, fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],

          // ── Analyzing Status Indicator ──────────────────────────────
          if (_isAnalyzing) ...[
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: primaryColor.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: primaryColor.withValues(alpha: 0.25),
                  width: 1.0,
                ),
              ),
              child: Column(
                children: [
                  ClipRRect(
                    borderRadius: const BorderRadius.all(Radius.circular(6)),
                    child: LinearProgressIndicator(
                      color: primaryColor,
                      backgroundColor: primaryColor.withValues(alpha: 0.15),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    _statusMessage,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 12.5,
                      color: primaryColor,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],

          // ── Verify Audio Button ─────────────────────────────────────
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: _isAnalyzing
                  ? null
                  : () {
                      if (_selectedAudio == null) {
                        _pickAudioFile();
                      } else {
                        _analyzeAudio();
                      }
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryColor,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: _isAnalyzing
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : Text(
                      loc.verifyAudioBtn,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 16.5,
                        color: Colors.white,
                      ),
                    ),
            ),
          ),
          const SizedBox(height: 18),

          // ── Bottom Chips: Audio.tflite & Runs on device ──────────────
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 12,
            runSpacing: 8,
            children: [
              _buildPill('Audio.tflite', isDark),
              _buildPill(loc.verifyRunsOnDevice, isDark),
            ],
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildPill(String label, bool isDark) {
    final pillBorder = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: pillBorder, width: 1.0),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12.5,
          fontWeight: FontWeight.w500,
          color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
        ),
      ),
    );
  }

  Widget _buildResultView(bool isDark, AppLocalizations loc) {
    final r = _result!;
    final authScore = (r['authenticityScore'] as num?)?.toDouble() ?? 0.0;
    final fakeProb = (r['fakeProbability'] as num?)?.toDouble() ?? 0.0;
    final verdict = (r['fineVerdict'] ?? r['verdict'] ?? 'UNKNOWN').toString();
    final riskLevel = (r['riskLevel'] ?? 'LOW').toString();

    final verificationResult = VerificationResult(
      verificationId: r['verificationId'] as String? ?? 'VRF-AUD-${DateTime.now().millisecondsSinceEpoch}',
      verifiedAt: DateTime.tryParse(r['verifiedAt'] as String? ?? '') ?? DateTime.now(),
      mediaType: r['mediaType'] as String? ?? 'audio/mpeg',
      source: r['source'] as String? ?? 'Voice Forensics',
      authenticityScore: authScore,
      fakeProbability: fakeProb,
      confidence: (r['confidence'] as num?)?.toDouble() ?? 0.0,
      metadataScore: 0.0,
      frameConsistency: 0.0,
      ocrConfidence: 0.0,
      trackingConfidence: 0.0,
      manipulationScore: fakeProb,
      verdict: verdict,
      riskLevel: riskLevel,
      detectedEvidence: List<String>.from(r['detectedEvidence'] ?? []),
      forensicObservations: List<String>.from(r['forensicObservations'] ?? []),
      reportHash: r['reportHash'] as String? ?? '',
      mediaName: _selectedAudio?.path.split(Platform.pathSeparator).last ?? _audioFileName ?? 'audio_file',
      thumbnailBase64: r['thumbnailBase64'] as String?,
      aiExplanation: r['aiExplanation'] as Map<String, dynamic>?,
    );

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: ForensicResultCard(
        result: verificationResult,
        scanAnotherText: loc.scanAnotherAudioBtn,
        onScanAnother: () => setState(() {
          _result = null;
          _selectedAudio = null;
          _audioFileName = null;
        }),
      ),
    );
  }
}

/// Custom painter for dashed rounded rectangle border.
class _DashedRRectPainter extends CustomPainter {
  final Color color;
  final double strokeWidth;
  final double dashWidth;
  final double dashSpace;
  final double radius;

  const _DashedRRectPainter({
    required this.color,
    this.strokeWidth = 1.2,
    this.dashWidth = 4.5,
    this.dashSpace = 3.5,
    this.radius = 20.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) return;
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke;

    final halfStroke = strokeWidth / 2;
    final rrect = RRect.fromRectAndRadius(
      Rect.fromLTWH(
        halfStroke,
        halfStroke,
        size.width - strokeWidth,
        size.height - strokeWidth,
      ),
      Radius.circular(radius),
    );

    final path = Path()..addRRect(rrect);
    for (final metric in path.computeMetrics()) {
      double distance = 0.0;
      while (distance < metric.length) {
        final length = math.min(dashWidth, metric.length - distance);
        final extract = metric.extractPath(distance, distance + length);
        canvas.drawPath(extract, paint);
        distance += dashWidth + dashSpace;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DashedRRectPainter oldDelegate) =>
      oldDelegate.color != color ||
      oldDelegate.strokeWidth != strokeWidth ||
      oldDelegate.dashWidth != dashWidth ||
      oldDelegate.dashSpace != dashSpace ||
      oldDelegate.radius != radius;
}
