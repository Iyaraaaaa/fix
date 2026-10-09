import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:veriframe_app/models/verification_result.dart';
import 'package:veriframe_app/service/pdf_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final tempDir = Directory.systemTemp.createTempSync('veriframe_pdf_test_');

  tearDownAll(() {
    try {
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    } catch (_) {}
  });

  group('PdfService Standardized Report Generation Tests', () {
    test('Generates complete PDF for Video Verification Result', () async {
      final outPath = '${tempDir.path}/test_video_report.pdf';
      final sampleVideo = VerificationResult(
        verificationId: 'VRF-TEST-VID-101',
        verifiedAt: DateTime.now(),
        mediaType: 'video/mp4',
        source: 'Local File',
        authenticityScore: 84.5,
        fakeProbability: 15.5,
        confidence: 88.0,
        metadataScore: 85.0,
        frameConsistency: 92.0,
        ocrConfidence: 0.0,
        trackingConfidence: 94.0,
        manipulationScore: 15.5,
        verdict: 'AUTHENTIC',
        riskLevel: 'LOW',
        detectedEvidence: [
          'Optical textures display genuine camera sensor noise and natural motion gradients.',
          'Facial landmarks and eye-mouth contours remain structurally stable.',
        ],
        forensicObservations: [
          'TFLite deep-learning classifier output: REAL (15.5% confidence).',
          'Frame consistency score: 92.0%.',
          'Biometric tracking stability: 94.0%.',
          'Inter-frame temporal analysis verified without GAN drift.',
        ],
        reportHash: 'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855',
        mediaName: 'interview_clip.mp4',
        framesAnalysedCount: 12,
        processingTimeSec: 1.8,
        pdfPath: outPath,
      );

      final file = await PdfService.instance.generateReportPdf(result: sampleVideo);
      expect(file, isNotNull);
      expect(await file!.exists(), isTrue);
      expect(await file.length(), greaterThan(1000));
    });

    test('Generates complete PDF for Image Verification Result', () async {
      final outPath = '${tempDir.path}/test_image_report.pdf';
      final sampleImage = VerificationResult(
        verificationId: 'VRF-TEST-IMG-202',
        verifiedAt: DateTime.now(),
        mediaType: 'image/jpeg',
        source: 'Image Forensics',
        authenticityScore: 22.0,
        fakeProbability: 78.0,
        confidence: 78.0,
        metadataScore: 60.0,
        frameConsistency: 0.0,
        ocrConfidence: 0.0,
        trackingConfidence: 0.0,
        manipulationScore: 78.0,
        verdict: 'MANIPULATED',
        riskLevel: 'HIGH',
        detectedEvidence: [
          'High-frequency spectral anomalies and diffusion grid warping detected.',
          'Irregular boundary blending around eye and ear perimeters.',
        ],
        forensicObservations: [
          'Verified locally via on-device Image.tflite model.',
          'Inference time: 42 ms.',
          'Generative synthesis artifacts confirmed.',
        ],
        reportHash: '1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef',
        mediaName: 'profile_shot.jpg',
        framesAnalysedCount: 1,
        processingTimeSec: 0.042,
        pdfPath: outPath,
      );

      final file = await PdfService.instance.generateReportPdf(result: sampleImage);
      expect(file, isNotNull);
      expect(await file!.exists(), isTrue);
      expect(await file.length(), greaterThan(1000));
    });

    test('Generates complete PDF for Audio Verification Result', () async {
      final outPath = '${tempDir.path}/test_audio_report.pdf';
      final sampleAudio = VerificationResult(
        verificationId: 'VRF-TEST-AUD-303',
        verifiedAt: DateTime.now(),
        mediaType: 'audio/mpeg',
        source: 'Audio Forensics',
        authenticityScore: 89.0,
        fakeProbability: 11.0,
        confidence: 89.0,
        metadataScore: 75.0,
        frameConsistency: 0.0,
        ocrConfidence: 0.0,
        trackingConfidence: 91.0,
        manipulationScore: 11.0,
        verdict: 'AUTHENTIC',
        riskLevel: 'LOW',
        detectedEvidence: [
          'Organic vocal tract resonance and authentic harmonics verified.',
        ],
        forensicObservations: [
          'Verified locally via on-device Audio.tflite model.',
          'Natural harmonic structure across speech frequency spectrum.',
        ],
        reportHash: 'abcdef1234567890abcdef1234567890abcdef1234567890abcdef1234567890',
        mediaName: 'voice_note.mp3',
        framesAnalysedCount: 4,
        processingTimeSec: 0.6,
        pdfPath: outPath,
      );

      final file = await PdfService.instance.generateReportPdf(result: sampleAudio);
      expect(file, isNotNull);
      expect(await file!.exists(), isTrue);
      expect(await file.length(), greaterThan(1000));
    });

    test('Generates PDF with Sinhala text', () async {
      final outPath = '${tempDir.path}/test_sinhala_report.pdf';
      final sampleSinhala = VerificationResult(
        verificationId: 'VRF-TEST-SINHALA-404',
        verifiedAt: DateTime.now(),
        mediaType: 'video/mp4',
        source: 'Local File',
        authenticityScore: 78.5,
        fakeProbability: 21.5,
        confidence: 78.5,
        metadataScore: 85.0,
        frameConsistency: 92.0,
        ocrConfidence: 0.0,
        trackingConfidence: 94.0,
        manipulationScore: 21.5,
        verdict: 'AUTHENTIC',
        riskLevel: 'LOW',
        detectedEvidence: [
          'දෘශ්‍ය සංවේදක ගැළපීම: කැමරා සංවේදක ශබ්දරටාව (PRNU) සියලු රාමුවල ස්වාභාවිකව පවතී.',
          'ස්වාභාවික චලන රටාව: මුහුණේ සීමා සහ ආලෝක රටා ස්වාභාවිකව පවතී.',
        ],
        forensicObservations: [
          'විශ්ලේෂණ එන්ජිම: උපාංගයේ TFLite video.tflite',
          '3 විශ්ලේෂිත රාමු',
          '180ms රාමුවකට සාමාන්‍ය කාලය',
          '21.5% ව්‍යාජතා විශ්වාසනීයත්වය',
        ],
        reportHash: 'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855',
        mediaName: 'sinhala_test.mp4',
        framesAnalysedCount: 3,
        processingTimeSec: 0.54,
        pdfPath: outPath,
      );

      final file = await PdfService.instance.generateReportPdf(result: sampleSinhala);
      expect(file, isNotNull);
      expect(await file!.exists(), isTrue);
    });

    test('Generates complete PDF for Web Link Verification Result (with QR Code)', () async {
      final outPath = '${tempDir.path}/test_link_report.pdf';
      final sampleLink = VerificationResult(
        verificationId: 'VRF-TEST-LNK-505',
        verifiedAt: DateTime.now(),
        mediaType: 'video/mp4',
        source: 'Web Link Analysis',
        authenticityScore: 18.5,
        fakeProbability: 81.5,
        confidence: 85.0,
        metadataScore: 40.0,
        frameConsistency: 35.0,
        ocrConfidence: 90.0,
        trackingConfidence: 45.0,
        manipulationScore: 81.5,
        verdict: 'MANIPULATED',
        riskLevel: 'HIGH',
        videoUrl: 'https://www.youtube.com/watch?v=dQw4w9WgXcQ',
        platform: 'YouTube',
        detectedEvidence: [
          'Temporal inconsistency detected across extracted keyframes.',
          'Audio-visual sync mismatch between lip landmarks and vocal envelope.',
        ],
        forensicObservations: [
          'Downloaded and analyzed stream from YouTube platform.',
          'High probability of synthetic face reenactment.',
        ],
        reportHash: '9876543210fedcba9876543210fedcba9876543210fedcba9876543210fedcba',
        mediaName: 'youtube_broadcast.mp4',
        framesAnalysedCount: 24,
        processingTimeSec: 2.4,
        pdfPath: outPath,
      );

      final file = await PdfService.instance.generateReportPdf(result: sampleLink);
      expect(file, isNotNull);
      expect(await file!.exists(), isTrue);
      expect(await file.length(), greaterThan(1000));
    });
  });
}
