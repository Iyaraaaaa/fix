import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:veriframe_app/models/notification_model.dart';
import 'package:veriframe_app/models/verification_result.dart';
import 'package:veriframe_app/provider/verification_notifier.dart';
import 'package:veriframe_app/service/notification_service.dart';
import 'package:veriframe_app/service/verify_backend_service.dart';
import 'package:veriframe_app/widgets/forensic_result_card.dart';
import 'package:veriframe_app/widgets/main_scaffold.dart';

class ImagePage extends ConsumerStatefulWidget {
  const ImagePage({super.key});

  @override
  ConsumerState<ImagePage> createState() => _ImagePageState();
}

class _ImagePageState extends ConsumerState<ImagePage> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final ImagePicker _picker = ImagePicker();

  // Local Image State
  File? _selectedImage;

  // Link Image State
  final TextEditingController _urlController = TextEditingController();

  // Status & Analysis State
  bool _isAnalyzing = false;
  String _statusMessage = '';
  Map<String, dynamic>? _result;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _urlController.dispose();
    super.dispose();
  }

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

  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? file = await _picker.pickImage(
        source: source,
        maxWidth: 2048,
        maxHeight: 2048,
        imageQuality: 95,
      );
      if (file != null) {
        setState(() {
          _selectedImage = File(file.path);
          _result = null;
          _errorMessage = null;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to pick image: $e')),
        );
      }
    }
  }

  Future<void> _analyzeLocalImage() async {
    if (_selectedImage == null) return;

    setState(() {
      _isAnalyzing = true;
      _errorMessage = null;
      _statusMessage = 'Uploading image to forensic engine...';
    });

    try {
      final baseUrl = await VerifyBackendService.instance.getBaseUrl();
      setState(() => _statusMessage = 'Running Biometrics, 2D FFT & Reality Defender AI...');
      final res = await VerifyBackendService.instance.verifyImage(baseUrl, _selectedImage!);

      setState(() {
        _result = res;
        _isAnalyzing = false;
      });

      final fileName = _selectedImage!.path.split('/').last.split('\\').last;
      await _saveResultAndNotify(res, fileName);
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isAnalyzing = false;
      });
    }
  }

  Future<void> _analyzeLinkImage() async {
    final url = _urlController.text.trim();
    if (url.isEmpty || !url.startsWith('http')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid HTTP/HTTPS image URL')),
      );
      return;
    }

    setState(() {
      _isAnalyzing = true;
      _errorMessage = null;
      _statusMessage = 'Downloading image from URL...';
    });

    try {
      final baseUrl = await VerifyBackendService.instance.getBaseUrl();
      setState(() => _statusMessage = 'Running Biometrics, 2D FFT & Reality Defender AI...');
      final res = await VerifyBackendService.instance.verifyImageLink(baseUrl, url);

      setState(() {
        _result = res;
        _isAnalyzing = false;
      });

      final mediaName = url.length > 60 ? '${url.substring(0, 57)}...' : url;
      await _saveResultAndNotify(res, mediaName);
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isAnalyzing = false;
      });
    }
  }

  /// Builds a [VerificationResult] from an image pipeline response map, saves
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
            'VRF-IMG-${DateTime.now().millisecondsSinceEpoch}',
        verifiedAt:
            DateTime.tryParse(r['verifiedAt'] as String? ?? '') ?? DateTime.now(),
        mediaType: r['mediaType'] as String? ?? 'image/jpeg',
        source: r['source'] as String? ?? 'Image Forensics',
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
        title: 'VeriFrame — Image Analysis Complete',
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
        title: 'VeriFrame — Image Analysis Complete',
        body:
            '$verdict: ${notifScore.toStringAsFixed(1)}% '
            '${isAuthentic ? 'authentic' : 'manipulated'}. Tap to view report.',
        payload: result.verificationId,
      );
    } catch (e) {
      debugPrint('[ImagePage] Failed to save result or send notification: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF090D16) : const Color(0xFFF8FAFC);
    final onAppBar = Theme.of(context).colorScheme.onPrimary;

    return MainScaffold(
      backgroundColor: bg,
      showBack: true,
      title: const Text(
        'Image Forensics',
        style: TextStyle(fontWeight: FontWeight.w800, letterSpacing: -0.5),
      ),
      extraActions: [
        IconButton(
          icon: const Icon(Icons.dns_outlined),
          tooltip: 'Backend Server',
          onPressed: _showServerDialog,
        ),
      ],
      appBarBottom: TabBar(
        controller: _tabController,
        labelColor: onAppBar,
        unselectedLabelColor: onAppBar.withValues(alpha: 0.7),
        indicatorColor: onAppBar,
        indicatorWeight: 3,
        tabs: const [
          Tab(icon: Icon(Icons.photo_library_rounded), text: 'Local Image'),
          Tab(icon: Icon(Icons.link_rounded), text: 'Image Link'),
        ],
      ),
      body: _result != null
          ? _buildResultView(isDark)
          : TabBarView(
              controller: _tabController,
              children: [
                _buildLocalTab(isDark),
                _buildLinkTab(isDark),
              ],
            ),
    );
  }

  Widget _buildLocalTab(bool isDark) {
    final cardBg = isDark ? const Color(0xFF162032) : Colors.white;
    final borderColor = isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Banner
          _buildInfoBanner(
            icon: Icons.auto_awesome,
            title: 'Dual-Engine Image Verification',
            subtitle: 'Combines VeriFrame 2D FFT frequency spectrum check with Reality Defender Cloud deepfake detector.',
            color: const Color(0xFF10B981),
          ),
          const SizedBox(height: 20),

          // Upload Preview Container
          Container(
            height: 280,
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: borderColor, width: 1.5),
            ),
            child: _selectedImage != null
                ? Stack(
                    fit: StackFit.expand,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(24),
                        child: Image.file(_selectedImage!, fit: BoxFit.cover),
                      ),
                      Positioned(
                        top: 12,
                        right: 12,
                        child: CircleAvatar(
                          backgroundColor: Colors.black.withValues(alpha: 0.6),
                          child: IconButton(
                            icon: const Icon(Icons.close, color: Colors.white, size: 20),
                            onPressed: () => setState(() => _selectedImage = null),
                          ),
                        ),
                      ),
                    ],
                  )
                : Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(18),
                          decoration: BoxDecoration(
                            color: const Color(0xFF10B981).withValues(alpha: 0.12),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.add_photo_alternate_rounded,
                            size: 40,
                            color: Color(0xFF10B981),
                          ),
                        ),
                        const SizedBox(height: 14),
                        const Text(
                          'Select Image for Forensic Analysis',
                          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Supports JPG, PNG, WEBP up to 50MB',
                          style: TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
          ),
          const SizedBox(height: 16),

          // Action Buttons: Gallery or Camera
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _isAnalyzing ? null : () => _pickImage(ImageSource.gallery),
                  icon: const Icon(Icons.photo_library_outlined),
                  label: const Text('From Gallery'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _isAnalyzing ? null : () => _pickImage(ImageSource.camera),
                  icon: const Icon(Icons.camera_alt_outlined),
                  label: const Text('Take Photo'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Error Message
          if (_errorMessage != null) _buildErrorCard(_errorMessage!),

          // Status & Progress
          if (_isAnalyzing) ...[
            _buildScanningProgress(),
            const SizedBox(height: 20),
          ],

          // Verify Button
          ElevatedButton(
            onPressed: (_selectedImage != null && !_isAnalyzing) ? _analyzeLocalImage : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF10B981),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              elevation: 4,
            ),
            child: Text(
              _isAnalyzing ? 'Analyzing Image...' : 'Verify Image Authenticity',
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLinkTab(bool isDark) {
    final cardBg = isDark ? const Color(0xFF162032) : Colors.white;
    final borderColor = isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildInfoBanner(
            icon: Icons.link_rounded,
            title: 'Verify Image from Web Link',
            subtitle: 'Provide direct link to any online image (news sites, social media, CDNs) to check for deepfake tampering.',
            color: const Color(0xFF0D9488),
          ),
          const SizedBox(height: 24),

          // URL Input
          Container(
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: borderColor, width: 1.2),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: TextField(
              controller: _urlController,
              decoration: const InputDecoration(
                hintText: 'https://example.com/image.jpg',
                border: InputBorder.none,
                icon: Icon(Icons.link, color: Color(0xFF0D9488)),
              ),
              keyboardType: TextInputType.url,
            ),
          ),
          const SizedBox(height: 24),

          if (_errorMessage != null) _buildErrorCard(_errorMessage!),

          if (_isAnalyzing) ...[
            _buildScanningProgress(),
            const SizedBox(height: 20),
          ],

          ElevatedButton(
            onPressed: !_isAnalyzing ? _analyzeLinkImage : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0D9488),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              elevation: 4,
            ),
            child: Text(
              _isAnalyzing ? 'Fetching & Analyzing...' : 'Verify Image URL',
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoBanner({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: color,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style: const TextStyle(fontSize: 12, height: 1.35, color: Colors.grey),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScanningProgress() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF10B981).withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          const LinearProgressIndicator(color: Color(0xFF10B981)),
          const SizedBox(height: 12),
          Text(
            _statusMessage,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorCard(String error) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
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
          Expanded(child: Text(error, style: const TextStyle(color: Colors.red, fontSize: 13))),
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
      verificationId: r['verificationId'] as String? ?? 'VRF-IMG-${DateTime.now().millisecondsSinceEpoch}',
      verifiedAt: DateTime.tryParse(r['verifiedAt'] as String? ?? '') ?? DateTime.now(),
      mediaType: r['mediaType'] as String? ?? 'image/jpeg',
      source: r['source'] as String? ?? 'Image Forensics',
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
      mediaName: _selectedImage?.path.split(Platform.pathSeparator).last ?? _urlController.text,
      thumbnailBase64: r['thumbnailBase64'] as String?,
      aiExplanation: r['aiExplanation'] as Map<String, dynamic>?,
    );

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: ForensicResultCard(
        result: verificationResult,
        scanAnotherText: 'Verify Another Image',
        onScanAnother: () => setState(() {
          _result = null;
          _selectedImage = null;
          _urlController.clear();
        }),
      ),
    );
  }
}
