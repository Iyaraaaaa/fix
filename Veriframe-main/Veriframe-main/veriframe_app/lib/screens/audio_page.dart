import 'dart:io';
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

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Backend Server Settings'),
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
                hintText: 'https://veriframe-backend-x3fn.onrender.com',
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
            child: const Text('Reset to Default'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
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
            child: const Text('Save'),
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
      setState(() => _statusMessage = 'Scanning acoustic spectrum & querying Reality Defender Voice AI...');
      final res = await VerifyBackendService.instance.verifyAudio(baseUrl, _selectedAudio!);

      setState(() {
        _result = res;
        _isAnalyzing = false;
      });

      final mediaName = _audioFileName ?? _selectedAudio!.path.split('/').last.split('\\').last;
      await _saveResultAndNotify(res, mediaName);
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
    String mediaName,
  ) async {
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
    final bg = isDark ? const Color(0xFF090D16) : const Color(0xFFF8FAFC);

    return MainScaffold(
      backgroundColor: bg,
      showBack: true,
      title: const Text(
        'Audio Voice Forensics',
        style: TextStyle(fontWeight: FontWeight.w800, letterSpacing: -0.5),
      ),
      extraActions: [
        IconButton(
          icon: const Icon(Icons.dns_outlined),
          tooltip: 'Backend Server',
          onPressed: _showServerDialog,
        ),
      ],
      body: _result != null ? _buildResultView(isDark) : _buildUploadView(isDark),
    );
  }

  Widget _buildUploadView(bool isDark) {
    final cardBg = isDark ? const Color(0xFF162032) : Colors.white;
    final borderColor = isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Banner
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFF59E0B).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFFF59E0B).withValues(alpha: 0.3)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.record_voice_over_rounded, color: Color(0xFFF59E0B), size: 26),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text(
                        'Voice Cloning & Synthetic Speech Detection',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: Color(0xFFF59E0B),
                          fontSize: 14,
                        ),
                      ),
                      SizedBox(height: 3),
                      Text(
                        'Detects ElevenLabs, TTS vocoders, and AI speech synthesis using spectral band decomposition and Reality Defender Voice AI.',
                        style: TextStyle(fontSize: 12, height: 1.35, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Audio Selection Box
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: borderColor, width: 1.5),
            ),
            child: Column(
              children: [
                if (_selectedAudio != null) ...[
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF59E0B).withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.audiotrack_rounded,
                      size: 34,
                      color: Color(0xFFF59E0B),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    _audioFileName ?? 'audio_file',
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${(_audioFileSize / 1024).toStringAsFixed(1)} KB • ${(_audioFileName ?? '').split('.').last.toUpperCase()}',
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                  const SizedBox(height: 16),
                  TextButton.icon(
                    onPressed: _isAnalyzing ? null : _pickAudioFile,
                    icon: const Icon(Icons.refresh, size: 18),
                    label: const Text('Choose Different Audio'),
                  ),
                ] else ...[
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF59E0B).withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.mic_none_rounded,
                      size: 40,
                      color: Color(0xFFF59E0B),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Select Audio File to Verify',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Supports MP3, WAV, M4A, AAC, FLAC up to 20MB',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                  const SizedBox(height: 18),
                  ElevatedButton.icon(
                    onPressed: _pickAudioFile,
                    icon: const Icon(Icons.file_upload_outlined),
                    label: const Text('Browse Files'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFF59E0B),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 24),

          if (_errorMessage != null) ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.error_outline, color: Colors.red),
                  const SizedBox(width: 12),
                  Expanded(child: Text(_errorMessage!, style: const TextStyle(color: Colors.red, fontSize: 13))),
                ],
              ),
            ),
            const SizedBox(height: 20),
          ],

          if (_isAnalyzing) ...[
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: const Color(0xFFF59E0B).withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  const LinearProgressIndicator(color: Color(0xFFF59E0B)),
                  const SizedBox(height: 12),
                  Text(_statusMessage, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                ],
              ),
            ),
            const SizedBox(height: 20),
          ],

          ElevatedButton(
            onPressed: (_selectedAudio != null && !_isAnalyzing) ? _analyzeAudio : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFF59E0B),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              elevation: 4,
            ),
            child: Text(
              _isAnalyzing ? 'Analyzing Speech Patterns...' : 'Verify Audio Authenticity',
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResultView(bool isDark) {
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
        scanAnotherText: 'Verify Another Audio File',
        onScanAnother: () => setState(() {
          _result = null;
          _selectedAudio = null;
          _audioFileName = null;
        }),
      ),
    );
  }
}
