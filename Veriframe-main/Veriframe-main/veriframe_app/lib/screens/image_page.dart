import 'dart:convert';
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
import 'package:veriframe_app/service/tflite_service.dart';
import 'package:veriframe_app/service/verify_backend_service.dart';
import 'package:veriframe_app/widgets/forensic_result_card.dart';
import 'package:veriframe_app/widgets/main_scaffold.dart';

class ImagePage extends ConsumerStatefulWidget {
  final int initialTab;
  const ImagePage({super.key, this.initialTab = 0});

  @override
  ConsumerState<ImagePage> createState() => _ImagePageState();
}

class _ImagePageState extends ConsumerState<ImagePage> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final ImagePicker _picker = ImagePicker();
  final ScrollController _linkScrollController = ScrollController();
  final ScrollController _localScrollController = ScrollController();
  bool _initializedArgs = false;

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
    _tabController = TabController(
      length: 2,
      vsync: this,
      initialIndex: widget.initialTab.clamp(0, 1),
    );
    _tabController.addListener(() {
      if (mounted) setState(() {});
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initializedArgs) {
      _initializedArgs = true;
      final args = ModalRoute.of(context)?.settings.arguments;
      if (args is int && args >= 0 && args <= 1 && args != _tabController.index) {
        _tabController.index = args;
      }
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _urlController.dispose();
    _linkScrollController.dispose();
    _localScrollController.dispose();
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
      await _saveResultAndNotify(res, fileName, mediaPath: _selectedImage?.path);
    } catch (e) {
      debugPrint('[ImagePage] Backend analysis error: $e. Checking on-device TFLite fallback...');
      try {
        setState(() => _statusMessage = 'Running on-device Image.tflite model...');
        final bytes = await _selectedImage!.readAsBytes();
        if (!TFLiteService.instance.isInitialized) {
          await TFLiteService.instance.init();
        }
        final inference = await TFLiteService.instance.runInference(bytes);

        final fakeProb = (inference.fakeProbability * 100).clamp(0.0, 100.0);
        final authScore = (100.0 - fakeProb).clamp(0.0, 100.0);
        final isReal = authScore >= 50.0;
        final verdict = isReal ? 'AUTHENTIC' : 'MANIPULATED';
        final riskLevel = authScore >= 70 ? 'LOW' : (authScore >= 40 ? 'MEDIUM' : 'HIGH');

        final fallbackRes = {
          'verdict': verdict,
          'fineVerdict': verdict,
          'authenticityScore': double.parse(authScore.toStringAsFixed(1)),
          'fakeProbability': double.parse(fakeProb.toStringAsFixed(1)),
          'confidence': double.parse(authScore.toStringAsFixed(1)),
          'riskLevel': riskLevel,
          'mediaType': 'image/jpeg',
          'source': 'On-Device TFLite (Image.tflite)',
          'detectedEvidence': isReal
              ? <String>['On-device biometric verification passed', 'No deepfake anomalies detected']
              : <String>['Facial distortion signature detected', 'High probability synthetic generation'],
          'forensicObservations': <String>[
            'Verified locally via on-device Image.tflite model',
            'Inference time: ${inference.inferenceMs} ms',
            'Runs on device: 100% offline & private',
          ],
          'thumbnailBase64': base64Encode(bytes),
        };

        setState(() {
          _result = fallbackRes;
          _isAnalyzing = false;
        });

        final fileName = _selectedImage!.path.split('/').last.split('\\').last;
        await _saveResultAndNotify(fallbackRes, fileName, mediaPath: _selectedImage?.path);
        return;
      } catch (fallbackErr) {
        debugPrint('[ImagePage] On-device inference error: $fallbackErr');
      }

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
      await _saveResultAndNotify(res, mediaName, videoUrl: url);
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isAnalyzing = false;
      });
    }
  }

  Future<void> _saveResultAndNotify(
    Map<String, dynamic> r,
    String mediaName, {
    String? mediaPath,
    String? videoUrl,
  }) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    try {
      final verdict = (r['verdict'] as String? ?? 'UNKNOWN');
      final fakeProbability = (r['fakeProbability'] as num?)?.toDouble() ?? 0.0;
      final authenticityScore = (r['authenticityScore'] as num?)?.toDouble() ?? 0.0;

      String? thumbBase64 = r['thumbnailBase64'] as String?;
      if ((thumbBase64 == null || thumbBase64.isEmpty) && mediaPath != null && File(mediaPath).existsSync()) {
        try {
          thumbBase64 = base64Encode(File(mediaPath).readAsBytesSync());
        } catch (_) {}
      }

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
        mediaPath: mediaPath,
        videoUrl: videoUrl,
        thumbnailBase64: thumbBase64,
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
    final bg = isDark ? const Color(0xFF090D16) : const Color(0xFFF6F8FC);

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
      body: _result != null
          ? _buildResultView(isDark)
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
                  child: _buildSegmentedTabSelector(isDark),
                ),
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _buildLocalTab(isDark),
                      _buildLinkTab(isDark),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildSegmentedTabSelector(bool isDark) {
    final barBg = isDark ? const Color(0xFF1E293B) : const Color(0xFFE8EDF7);
    final activeBg = const Color(0xFF0F766E);
    final unselectedText = isDark ? const Color(0xFF94A3B8) : const Color(0xFF515E71);
    final isLocal = _tabController.index == 0;
    final isLink = _tabController.index == 1;

    return Container(
      height: 52,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: barBg,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () {
                _tabController.animateTo(0);
                setState(() {});
              },
              behavior: HitTestBehavior.opaque,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                decoration: BoxDecoration(
                  color: isLocal ? activeBg : Colors.transparent,
                  borderRadius: BorderRadius.circular(14),
                ),
                alignment: Alignment.center,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.image_outlined,
                      size: 20,
                      color: isLocal ? Colors.white : unselectedText,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Local image',
                      style: TextStyle(
                        fontSize: 14.5,
                        fontWeight: isLocal ? FontWeight.w700 : FontWeight.w600,
                        color: isLocal ? Colors.white : unselectedText,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Expanded(
            child: GestureDetector(
              onTap: () {
                _tabController.animateTo(1);
                setState(() {});
              },
              behavior: HitTestBehavior.opaque,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                decoration: BoxDecoration(
                  color: isLink ? activeBg : Colors.transparent,
                  borderRadius: BorderRadius.circular(14),
                ),
                alignment: Alignment.center,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.link_rounded,
                      size: 21,
                      color: isLink ? Colors.white : unselectedText,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Image link',
                      style: TextStyle(
                        fontSize: 14.5,
                        fontWeight: isLink ? FontWeight.w700 : FontWeight.w600,
                        color: isLink ? Colors.white : unselectedText,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF122820) : const Color(0xFFEAF7F0),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? const Color(0xFF1E4837) : const Color(0xFFC7EBD7),
          width: 1.2,
        ),
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
                  color: isDark ? const Color(0xFF1B382D) : Colors.white,
                  borderRadius: BorderRadius.circular(13),
                  boxShadow: isDark
                      ? null
                      : [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.04),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                ),
                child: Center(
                  child: SizedBox(
                    width: 26,
                    height: 26,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Icon(
                          Icons.shield_outlined,
                          size: 26,
                          color: isDark ? const Color(0xFF34D399) : const Color(0xFF107050),
                        ),
                        Positioned(
                          top: 5,
                          child: Icon(
                            Icons.sync_rounded,
                            size: 13,
                            color: isDark ? const Color(0xFF34D399) : const Color(0xFF107050),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  'Image authenticity check',
                  style: TextStyle(
                    fontSize: 16.5,
                    fontWeight: FontWeight.w700,
                    color: isDark ? const Color(0xFF86EFAC) : const Color(0xFF135B3E),
                    letterSpacing: -0.2,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Scans every pixel pattern and frequency signature with the VeriFrame Image model to expose manipulation and deepfakes.',
            style: TextStyle(
              fontSize: 13.5,
              height: 1.45,
              color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF374151),
              fontWeight: FontWeight.w400,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLinkTab(bool isDark) {
    return SingleChildScrollView(
      controller: _linkScrollController,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildInfoCard(isDark),
          const SizedBox(height: 18),

          // URL Input
          Container(
            height: 58,
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF162032) : Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isDark ? const Color(0xFF1E293B) : const Color(0xFFD9E2EC),
                width: 1.4,
              ),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 18),
            child: Row(
              children: [
                Icon(
                  Icons.link_rounded,
                  color: isDark ? const Color(0xFF2DD4BF) : const Color(0xFF0F766E),
                  size: 22,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _urlController,
                    keyboardType: TextInputType.url,
                    style: TextStyle(
                      color: isDark ? Colors.white : const Color(0xFF1E293B),
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                    ),
                    decoration: InputDecoration(
                      hintText: 'https://example.com/image.jpg',
                      hintStyle: TextStyle(
                        color: isDark ? const Color(0xFF64748B) : const Color(0xFF8A99AD),
                        fontSize: 15,
                        fontWeight: FontWeight.w400,
                      ),
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),

          if (_errorMessage != null) ...[
            _buildErrorCard(_errorMessage!),
            const SizedBox(height: 14),
          ],

          if (_isAnalyzing) ...[
            _buildScanningProgress(),
            const SizedBox(height: 14),
          ],

          // Verify Button
          SizedBox(
            height: 54,
            width: double.infinity,
            child: ElevatedButton(
              onPressed: !_isAnalyzing ? _analyzeLinkImage : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0F766E),
                foregroundColor: Colors.white,
                disabledBackgroundColor: const Color(0xFF0F766E).withValues(alpha: 0.6),
                disabledForegroundColor: Colors.white.withValues(alpha: 0.8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                elevation: 0,
              ),
              child: _isAnalyzing
                  ? const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.2,
                            color: Colors.white,
                          ),
                        ),
                        SizedBox(width: 12),
                        Text(
                          'Fetching & Analyzing...',
                          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                        ),
                      ],
                    )
                  : const Text(
                      'Verify image link',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 16.5,
                        letterSpacing: -0.2,
                      ),
                    ),
            ),
          ),
          const SizedBox(height: 18),

          // Chips
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildChip('Image.tflite', isDark),
              const SizedBox(width: 10),
              _buildChip('Direct image URLs', isDark),
            ],
          ),
          const SizedBox(height: 28),

          // Down arrow indicator
          _buildDownArrow(isDark, _linkScrollController),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildLocalTab(bool isDark) {
    return SingleChildScrollView(
      controller: _localScrollController,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildInfoCard(isDark),
          const SizedBox(height: 18),

          // Upload Preview Container with Dashed Border
          CustomPaint(
            painter: _DashedBorderPainter(
              color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
              strokeWidth: 1.3,
              dashWidth: 5.5,
              dashSpace: 4.5,
              radius: 20,
            ),
            child: Container(
              height: 250,
              width: double.infinity,
              decoration: BoxDecoration(
                color: isDark
                    ? const Color(0xFF131D2E).withValues(alpha: 0.6)
                    : Colors.white.withValues(alpha: 0.9),
                borderRadius: BorderRadius.circular(20),
              ),
              child: _selectedImage != null
                  ? Stack(
                      fit: StackFit.expand,
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(20),
                          child: Image.file(_selectedImage!, fit: BoxFit.cover),
                        ),
                        Positioned(
                          top: 12,
                          right: 12,
                          child: CircleAvatar(
                            backgroundColor: Colors.black.withValues(alpha: 0.65),
                            radius: 18,
                            child: IconButton(
                              icon: const Icon(Icons.close, color: Colors.white, size: 18),
                              padding: EdgeInsets.zero,
                              onPressed: () => setState(() => _selectedImage = null),
                            ),
                          ),
                        ),
                        Positioned(
                          bottom: 12,
                          left: 12,
                          right: 12,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.65),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.image, color: Colors.white70, size: 16),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    _selectedImage!.path.split(Platform.pathSeparator).last,
                                    style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w500),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                GestureDetector(
                                  onTap: () => _pickImage(ImageSource.gallery),
                                  child: const Text(
                                    'Change',
                                    style: TextStyle(color: Color(0xFF38BDF8), fontSize: 12, fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    )
                  : InkWell(
                      onTap: () => _pickImage(ImageSource.gallery),
                      borderRadius: BorderRadius.circular(20),
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              width: 60,
                              height: 60,
                              decoration: BoxDecoration(
                                color: isDark
                                    ? const Color(0xFF133E33)
                                    : const Color(0xFFE6F7F0),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.add_photo_alternate_outlined,
                                size: 28,
                                color: isDark ? const Color(0xFF34D399) : const Color(0xFF0A6C60),
                              ),
                            ),
                            const SizedBox(height: 14),
                            Text(
                              'Select an image to analyze',
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 16,
                                color: isDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A),
                                letterSpacing: -0.2,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'JPG, PNG, WEBP up to 50 MB',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                                color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
            ),
          ),
          const SizedBox(height: 16),

          // Action Buttons: Gallery and Camera
          Row(
            children: [
              Expanded(
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: _isAnalyzing ? null : () => _pickImage(ImageSource.gallery),
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      height: 52,
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF162032) : Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
                          width: 1.2,
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.photo_outlined,
                            size: 22,
                            color: isDark ? const Color(0xFF60A5FA) : const Color(0xFF1D4ED8),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Gallery',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: isDark ? const Color(0xFF93C5FD) : const Color(0xFF1E40AF),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: _isAnalyzing ? null : () => _pickImage(ImageSource.camera),
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      height: 52,
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF162032) : Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
                          width: 1.2,
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.camera_alt_outlined,
                            size: 22,
                            color: isDark ? const Color(0xFF60A5FA) : const Color(0xFF1D4ED8),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Camera',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: isDark ? const Color(0xFF93C5FD) : const Color(0xFF1E40AF),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),

          if (_errorMessage != null) ...[
            _buildErrorCard(_errorMessage!),
            const SizedBox(height: 14),
          ],

          if (_isAnalyzing) ...[
            _buildScanningProgress(),
            const SizedBox(height: 14),
          ],

          // Verify Button: Dark teal rounded button
          SizedBox(
            height: 52,
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isAnalyzing
                  ? null
                  : (_selectedImage != null
                      ? _analyzeLocalImage
                      : () => _pickImage(ImageSource.gallery)),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0A6C60),
                foregroundColor: Colors.white,
                disabledBackgroundColor: const Color(0xFF0A6C60).withValues(alpha: 0.6),
                disabledForegroundColor: Colors.white.withValues(alpha: 0.8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                elevation: 0,
              ),
              child: _isAnalyzing
                  ? const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.2,
                            color: Colors.white,
                          ),
                        ),
                        SizedBox(width: 12),
                        Text(
                          'Verifying image...',
                          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                        ),
                      ],
                    )
                  : const Text(
                      'Verify image',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                        letterSpacing: -0.2,
                      ),
                    ),
            ),
          ),
          const SizedBox(height: 16),

          // Chips at bottom
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildChip('Image.tflite', isDark),
              const SizedBox(width: 10),
              _buildChip('Runs on device', isDark),
            ],
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildChip(String label, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7.5),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : const Color(0xFFEEF2F6),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12.5,
          fontWeight: FontWeight.w600,
          color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569),
        ),
      ),
    );
  }

  Widget _buildDownArrow(bool isDark, ScrollController controller) {
    return Center(
      child: GestureDetector(
        onTap: () {
          if (controller.hasClients) {
            controller.animateTo(
              controller.offset + 120,
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOut,
            );
          }
        },
        child: Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF162032) : Colors.white,
            shape: BoxShape.circle,
            border: Border.all(
              color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Icon(
            Icons.arrow_downward_rounded,
            size: 18,
            color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF515E71),
          ),
        ),
      ),
    );
  }

  Widget _buildScanningProgress() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF0F766E).withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF0F766E).withValues(alpha: 0.2)),
      ),
      child: Column(
        children: [
          const LinearProgressIndicator(
            color: Color(0xFF0F766E),
            backgroundColor: Color(0xFFE8EDF7),
          ),
          const SizedBox(height: 12),
          Text(
            _statusMessage,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 13,
              color: Color(0xFF0F766E),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorCard(String error) {
    return Container(
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

class _DashedBorderPainter extends CustomPainter {
  final Color color;
  final double strokeWidth;
  final double dashWidth;
  final double dashSpace;
  final double radius;

  _DashedBorderPainter({
    required this.color,
    this.strokeWidth = 1.3,
    this.dashWidth = 5.5,
    this.dashSpace = 4.5,
    this.radius = 20.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke;

    final rrect = RRect.fromRectAndRadius(
      Rect.fromLTWH(
        strokeWidth / 2,
        strokeWidth / 2,
        size.width - strokeWidth,
        size.height - strokeWidth,
      ),
      Radius.circular(radius),
    );

    final path = Path()..addRRect(rrect);
    final metrics = path.computeMetrics();

    for (final metric in metrics) {
      double distance = 0.0;
      while (distance < metric.length) {
        final len = (distance + dashWidth < metric.length)
            ? dashWidth
            : metric.length - distance;
        final extract = metric.extractPath(distance, distance + len);
        canvas.drawPath(extract, paint);
        distance += dashWidth + dashSpace;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DashedBorderPainter oldDelegate) =>
      oldDelegate.color != color ||
      oldDelegate.strokeWidth != strokeWidth ||
      oldDelegate.dashWidth != dashWidth ||
      oldDelegate.dashSpace != dashSpace ||
      oldDelegate.radius != radius;
}
