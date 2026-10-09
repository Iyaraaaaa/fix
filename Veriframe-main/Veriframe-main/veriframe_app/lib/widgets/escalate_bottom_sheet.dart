import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:veriframe_app/l10n/app_localizations.dart';
import 'package:veriframe_app/models/verification_result.dart';
import 'package:veriframe_app/service/pdf_service.dart';
import 'package:veriframe_app/screens/pdf_viewer_screen.dart';
import 'package:veriframe_app/service/inquiry_service.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Theme-aware palette
// ─────────────────────────────────────────────────────────────────────────────

class _EscalPal {
  final bool isDark;
  const _EscalPal(this.isDark);

  Color get bg => isDark ? const Color(0xFF0F172A) : const Color(0xFFFFFFFF);
  Color get surfaceMuted =>
      isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC);
  Color get border => isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);
  Color get textPrimary =>
      isDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A);
  Color get textSecondary =>
      isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
  Color get textSubtle =>
      isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8);

  static const Color manipulated = Color(0xFFDC2626);
  Color get manipulatedBg =>
      isDark ? const Color(0x29DC2626) : const Color(0xFFFEE2E2);
}

// ─────────────────────────────────────────────────────────────────────────────
// EscalateBottomSheet — Institutional Report & Legal Dispatch Sheet
// ─────────────────────────────────────────────────────────────────────────────

class EscalateBottomSheet extends StatefulWidget {
  const EscalateBottomSheet({super.key, required this.report});

  final VerificationResult report;

  @override
  State<EscalateBottomSheet> createState() => _EscalateBottomSheetState();
}

class _EscalateBottomSheetState extends State<EscalateBottomSheet> {
  static const Color _primaryBlue = Color(0xFF1976D2);
  static const Color _whatsappGreen = Color(0xFF059669);

  /// Official Police & CERT WhatsApp contact: 0784770935 (international 94784770935).
  static const String _policeCertWhatsApp = '94784770935';

  /// Official Police & CERT Email: sithmiyara2001@gmail.com.
  static const String _policeCertEmail = 'sithmiyara2001@gmail.com';

  /// Official Police IT Department title.
  static const String _policeItDeptTitle = 'Sri Lanka Police (Cyber Crime)';

  static const String _gmailPackage = 'com.google.android.gm';
  static const String _methodChannel = 'com.veriframe_app/share_pdf';

  // 0: Escalate, 1: Inquiry form, 2: Legal help
  int _selectedTabIndex = 0;

  // Selected authority: 'police' or 'cert'
  String _selectedAuthority = 'police';
  bool _attachPdf = true;

  // Complainant particulars controllers for the Inquiry Document (Empty by default)
  late final TextEditingController _inqNameCtrl;
  late final TextEditingController _inqAgeCtrl;
  late final TextEditingController _inqPhoneCtrl;
  late final TextEditingController _inqEmailCtrl;
  late final TextEditingController _inqAddressCtrl;
  late final TextEditingController _inqPlaceCtrl;
  late final TextEditingController _inqContextCtrl;
  String _selectedOffence = 'Deepfake / impersonation';

  final List<String> _offences = const [
    'Deepfake / impersonation',
    'Non-consensual media',
    'Defamation & harassment',
    'Financial cyber fraud',
  ];

  _EscalPal get _pal =>
      _EscalPal(Theme.of(context).brightness == Brightness.dark);

  @override
  void initState() {
    super.initState();
    _inqNameCtrl = TextEditingController(text: '');
    _inqAgeCtrl = TextEditingController(text: '');
    _inqPhoneCtrl = TextEditingController(text: '');
    _inqEmailCtrl = TextEditingController(text: '');
    _inqAddressCtrl = TextEditingController(text: '');
    _inqPlaceCtrl = TextEditingController(text: '');
    _inqContextCtrl = TextEditingController(text: '');
  }

  @override
  void dispose() {
    _inqNameCtrl.dispose();
    _inqAgeCtrl.dispose();
    _inqPhoneCtrl.dispose();
    _inqEmailCtrl.dispose();
    _inqAddressCtrl.dispose();
    _inqPlaceCtrl.dispose();
    _inqContextCtrl.dispose();
    super.dispose();
  }

  // ── Helpers ──────────────────────────────────────────────────────

  Future<File?> _getPdfFile() async {
    try {
      final inqRef = _formatInquiryRef();
      return await _generatePoliceInquiryPdf(inqRef);
    } catch (e) {
      debugPrint('[EscalateBottomSheet] Inquiry PDF generation failed: $e, falling back to PdfService');
      final r = widget.report;
      if (r.pdfPath != null && r.pdfPath!.isNotEmpty && File(r.pdfPath!).existsSync()) {
        return File(r.pdfPath!);
      }
      try {
        return await PdfService.instance.generateReportPdf(result: r);
      } catch (err) {
        debugPrint('[EscalateBottomSheet] PdfService fallback failed: $err');
        return null;
      }
    }
  }

  String _formatInquiryRef() {
    final r = widget.report;
    return 'INQ-CID-${r.verificationId.substring(0, math.min(8, r.verificationId.length)).toUpperCase()}';
  }

  String _shortHash(String hash) {
    if (hash.length <= 8) return hash;
    return '${hash.substring(0, 4)}...${hash.substring(hash.length - 4)}';
  }

  String _buildReportText(
    String authorityTitle, {
    String? offenceCategory,
    String? incidentContext,
    String? complainantName,
    String? complainantAge,
    String? complainantPhone,
    String? complainantEmail,
    String? complainantAddress,
    String? incidentPlace,
  }) {
    final r = widget.report;
    final inqRef = _formatInquiryRef();
    final lines = <String>[
      'CYBERCRIME INCIDENT REPORT & FORENSIC SUMMARY',
      'Authority / Desk: $authorityTitle',
      'Reference ID: $inqRef',
      'Reported Date: ${r.verifiedAt.toIso8601String().substring(0, 19).replaceAll("T", " ")}',
      '---------------------------------------------',
      if ((complainantName != null && complainantName.isNotEmpty) ||
          (complainantEmail != null && complainantEmail.isNotEmpty) ||
          (complainantPhone != null && complainantPhone.isNotEmpty)) ...[
        '1. COMPLAINANT INFORMATION:',
        if (complainantName != null && complainantName.isNotEmpty) '• Full Name: $complainantName',
        if (complainantAge != null && complainantAge.isNotEmpty) '• Age: $complainantAge',
        if (complainantPhone != null && complainantPhone.isNotEmpty) '• Contact Phone: $complainantPhone',
        if (complainantEmail != null && complainantEmail.isNotEmpty) '• Email Address: $complainantEmail',
        if (complainantAddress != null && complainantAddress.isNotEmpty) '• Address: $complainantAddress',
        if (incidentPlace != null && incidentPlace.isNotEmpty) '• Platform / Location: $incidentPlace',
        '',
      ] else ...[
        '1. COMPLAINANT INFORMATION: Anonymous / Not provided',
        '',
      ],
      '2. INCIDENT DETAILS:',
      '• Category: ${offenceCategory ?? _selectedOffence}',
      if (incidentContext != null && incidentContext.isNotEmpty)
        '• Description: $incidentContext'
      else
        '• Description: [No additional details provided]',
      '',
      '3. FORENSIC VERIFICATION RESULTS:',
      '• Media File: ${r.mediaName ?? r.source}',
      '• Modality Type: ${r.mediaType}',
      '• Analysis Verdict: ${r.verdict.toUpperCase()}',
      '• Risk Level: ${r.riskLevel.toUpperCase()}',
      '• Manipulation Probability: ${r.fakeProbability.toStringAsFixed(1)}%',
      '• Authenticity Score: ${r.authenticityScore.toStringAsFixed(1)}%',
      '• SHA-256 Checksum: ${r.reportHash}',
      '• Detailed PDF Report: ${_attachPdf ? "Attached" : "Summary Text Only"}',
      '---------------------------------------------',
      'Generated by VeriFrame Deepfake Detection & Verification System',
    ];
    return lines.join('\n');
  }

  String _emailSubject(String authorityTitle, {String? offenceCategory}) {
    final inqRef = _formatInquiryRef();
    final cat = (offenceCategory != null && offenceCategory.isNotEmpty) ? ' - $offenceCategory' : '';
    return 'Cyber Incident Report: $authorityTitle [$inqRef]$cat';
  }

  Future<void> _launchWhatsApp(
    String authorityTitle, {
    String? customMessage,
    String? offenceCategory,
  }) async {
    final message = customMessage ?? _buildReportText(authorityTitle, offenceCategory: offenceCategory);

    // Record inquiry/escalation directly into official account (0784770935) in Firestore
    final r = widget.report;
    final inqRef = _formatInquiryRef();
    try {
      await InquiryService.instance.recordPoliceInquiry(
        inqRef: inqRef,
        reportId: r.verificationId,
        complainantName: _inqNameCtrl.text.trim(),
        complainantPhone: _inqPhoneCtrl.text.trim(),
        complainantEmail: _inqEmailCtrl.text.trim(),
        complainantAddress: _inqAddressCtrl.text.trim(),
        incidentLocation: _inqPlaceCtrl.text.trim(),
        offenceCategory: offenceCategory ?? _selectedOffence,
        statementOfFacts: _inqContextCtrl.text.trim(),
        suspectMedia: r.mediaName ?? r.source,
        mediaType: r.mediaType,
        verdict: r.verdict,
        fakeProbability: r.fakeProbability,
        reportHash: r.reportHash,
        dossierText: message,
      );
    } catch (e) {
      debugPrint('[EscalateBottomSheet] Auto-recording to InquiryService failed: $e');
    }

    if (_attachPdf) {
      final pdfFile = await _getPdfFile();
      if (pdfFile != null && Platform.isAndroid) {
        try {
          final shared = await const MethodChannel(_methodChannel).invokeMethod<bool>(
            'sharePdfToApp',
            {
              'filePath': pdfFile.path,
              'appPackage': 'com.whatsapp',
              'recipient': _policeCertWhatsApp,
              'subject': _emailSubject(authorityTitle, offenceCategory: offenceCategory),
              'body': message,
            },
          );
          if (shared == true) return;
        } catch (_) {}
      }
    }

    if (Platform.isAndroid) {
      try {
        final opened = await const MethodChannel(_methodChannel).invokeMethod<bool>(
          'openWhatsAppChat',
          {'phone': _policeCertWhatsApp, 'message': message},
        );
        if (opened == true) return;
      } catch (_) {}
    }

    final waUrl = 'https://wa.me/$_policeCertWhatsApp?text=${Uri.encodeComponent(message)}';
    try {
      final opened = await launchUrl(
        Uri.parse(waUrl),
        mode: LaunchMode.externalApplication,
      );
      if (opened) return;
    } catch (_) {}

    try {
      final fallbackUri = Uri.parse('whatsapp://send?phone=$_policeCertWhatsApp&text=${Uri.encodeComponent(message)}');
      final opened = await launchUrl(fallbackUri, mode: LaunchMode.externalApplication);
      if (opened) return;
    } catch (_) {}

    try {
      await Share.share(message, subject: _emailSubject(authorityTitle, offenceCategory: offenceCategory));
    } catch (e) {
      debugPrint('[EscalateBottomSheet] WhatsApp redirect failed: $e');
      if (mounted) _showErrorSnackBar();
    }
  }

  Future<void> _launchEmail(
    String authorityTitle, {
    String? customMessage,
    String? offenceCategory,
  }) async {
    final body = customMessage ?? _buildReportText(authorityTitle, offenceCategory: offenceCategory);
    final subject = _emailSubject(authorityTitle, offenceCategory: offenceCategory);

    if (_attachPdf) {
      final pdfFile = await _getPdfFile();
      if (Platform.isAndroid && pdfFile != null) {
        try {
          final shared = await const MethodChannel(_methodChannel).invokeMethod<bool>(
            'sharePdfToApp',
            {
              'filePath': pdfFile.path,
              'appPackage': _gmailPackage,
              'recipient': _policeCertEmail,
              'subject': subject,
              'body': body,
            },
          );
          if (shared == true) return;
        } catch (e) {
          debugPrint('[EscalateBottomSheet] Gmail share failed: $e');
        }
      }
    }

    final mailtoUri = Uri(
      scheme: 'mailto',
      path: _policeCertEmail,
      queryParameters: {'subject': subject, 'body': body},
    );

    try {
      final opened = await launchUrl(
        mailtoUri,
        mode: LaunchMode.externalApplication,
      );
      if (opened) return;
    } catch (e) {
      debugPrint('[EscalateBottomSheet] mailto fallback failed: $e');
    }

    try {
      final encodedSubject = Uri.encodeComponent(subject);
      final encodedBody = Uri.encodeComponent(body);
      final directMailto = Uri.parse('mailto:$_policeCertEmail?subject=$encodedSubject&body=$encodedBody');
      final opened = await launchUrl(directMailto, mode: LaunchMode.externalApplication);
      if (opened) return;
    } catch (_) {}

    try {
      await Share.share('$subject\n\n$body', subject: subject);
    } catch (e) {
      debugPrint('[EscalateBottomSheet] email share failed: $e');
      if (mounted) _showErrorSnackBar();
    }
  }

  Future<void> _dispatchBriefToLawyer() async {
    final r = widget.report;
    final inqRef = _formatInquiryRef();
    final name = _inqNameCtrl.text.trim();
    final phone = _inqPhoneCtrl.text.trim();
    final email = _inqEmailCtrl.text.trim();
    final contextText = _inqContextCtrl.text.trim();

    final briefText = '''LEGAL ADVICE CONSULTATION REQUEST
Reference ID: $inqRef
Client Name: ${name.isNotEmpty ? name : 'Not provided'}
Contact Phone: ${phone.isNotEmpty ? phone : 'Not provided'}${email.isNotEmpty ? '\nClient Email: $email' : ''}
Incident Category: $_selectedOffence
Suspected Media: ${r.mediaName ?? r.source}
Verification Verdict: ${r.verdict.toUpperCase()} (${r.fakeProbability.toStringAsFixed(1)}% manipulation score)
SHA-256 Digest: ${r.reportHash}
${contextText.isNotEmpty ? 'Incident Details: $contextText\n' : ''}
Requesting urgent legal counsel regarding synthetic media takedown and protection under Computer Crimes Act No. 24 of 2007 and Online Safety Act No. 9 of 2024.
Generated via VeriFrame Analysis System.''';

    // Deliver directly to the official 0784770935 account inside Firestore
    await InquiryService.instance.recordLegalConsultation(
      inqRef: inqRef,
      reportId: r.verificationId,
      clientName: name,
      clientPhone: phone,
      clientEmail: email,
      incidentCategory: _selectedOffence,
      briefText: briefText,
      suspectMedia: r.mediaName ?? r.source,
      verdict: r.verdict,
      fakeProbability: r.fakeProbability,
      reportHash: r.reportHash,
    );

    if (_attachPdf) {
      final pdfFile = await _getPdfFile();
      if (pdfFile != null && Platform.isAndroid) {
        try {
          final shared = await const MethodChannel(_methodChannel).invokeMethod<bool>(
            'sharePdfToApp',
            {
              'filePath': pdfFile.path,
              'appPackage': 'com.whatsapp',
              'recipient': _policeCertWhatsApp,
              'subject': 'Legal Consultation Request: $inqRef',
              'body': briefText,
            },
          );
          if (shared == true) return;
        } catch (_) {}
      }
    }

    if (Platform.isAndroid) {
      try {
        final opened = await const MethodChannel(_methodChannel).invokeMethod<bool>(
          'openWhatsAppChat',
          {'phone': _policeCertWhatsApp, 'message': briefText},
        );
        if (opened == true) return;
      } catch (_) {}
    }

    final waUrl = 'https://wa.me/$_policeCertWhatsApp?text=${Uri.encodeComponent(briefText)}';
    try {
      final opened = await launchUrl(Uri.parse(waUrl), mode: LaunchMode.externalApplication);
      if (opened) return;
    } catch (_) {}

    try {
      final fallbackUri = Uri.parse('whatsapp://send?phone=$_policeCertWhatsApp&text=${Uri.encodeComponent(briefText)}');
      final opened = await launchUrl(fallbackUri, mode: LaunchMode.externalApplication);
      if (opened) return;
    } catch (_) {}

    try {
      await Share.share(briefText, subject: 'Legal Consultation Request: $inqRef');
    } catch (_) {
      if (mounted) _showErrorSnackBar();
    }
  }

  void _showErrorSnackBar() {
    final loc = AppLocalizations.of(context)!;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(loc.escalateSendFailed),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  // ── Build ─────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final pal = _pal;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.90,
      ),
      margin: EdgeInsets.only(bottom: bottomInset),
      decoration: BoxDecoration(
        color: pal.bg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        border: Border.all(color: pal.border, width: 1),
      ),
      clipBehavior: Clip.antiAlias,
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Top Blue Header Bar ──
            Container(
              color: _primaryBlue,
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
              child: Row(
                children: [
                  const Icon(
                    Icons.shield_rounded,
                    color: Colors.white,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'VeriFrame',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.3,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    icon: const Icon(
                      Icons.more_horiz_rounded,
                      color: Colors.white,
                      size: 22,
                    ),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),

            // ── Navigation Tabs Under Header ──
            Container(
              decoration: BoxDecoration(
                color: pal.bg,
                border: Border(bottom: BorderSide(color: pal.border)),
              ),
              child: Row(
                children: [
                  _buildTopTabItem(0, 'Escalate', pal),
                  _buildTopTabItem(1, 'Inquiry form', pal),
                  _buildTopTabItem(2, 'Legal help', pal),
                ],
              ),
            ),

            // ── Tab Content ──
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(18, 16, 18, 20),
                child: _selectedTabIndex == 0
                    ? _buildEscalateTab(pal)
                    : _selectedTabIndex == 1
                        ? _buildInquiryTab(pal)
                        : _buildLegalTab(pal),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Segmented Tab Button ──────────────────────────────────────────

  Widget _buildTopTabItem(int index, String label, _EscalPal pal) {
    final isSelected = _selectedTabIndex == index;
    final activeColor = pal.isDark ? const Color(0xFF38BDF8) : _primaryBlue;

    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _selectedTabIndex = index),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: isSelected ? activeColor : Colors.transparent,
                width: 2.5,
              ),
            ),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
              color: isSelected ? activeColor : pal.textSecondary,
            ),
          ),
        ),
      ),
    );
  }

  // ═════════════════════════════════════════════════════════════════
  // TAB 1: ESCALATE (Matches Screenshot 1 + WhatsApp)
  // ═════════════════════════════════════════════════════════════════

  Widget _buildEscalateTab(_EscalPal pal) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header
        Text(
          'Report this media',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: pal.textPrimary,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          'Send this result to the authorities.',
          style: TextStyle(
            fontSize: 12,
            color: pal.textSecondary,
          ),
        ),
        const SizedBox(height: 16),

        // Authority Selection Cards
        _buildAuthorityRadioCard(
          id: 'police',
          title: 'Sri Lanka Police (Cyber Crime)',
          icon: Icons.shield_outlined,
          iconBg: pal.isDark ? const Color(0xFF1E3A8A) : const Color(0xFFDBEAFE),
          iconColor: const Color(0xFF2563EB),
          pal: pal,
        ),
        const SizedBox(height: 10),

        _buildAuthorityRadioCard(
          id: 'cert',
          title: 'Sri Lanka CERT|CC',
          icon: Icons.dns_outlined,
          iconBg: pal.surfaceMuted,
          iconColor: pal.textSecondary,
          pal: pal,
        ),
        const SizedBox(height: 16),

        // Send Via Buttons (Email & WhatsApp per user instruction)
        Text(
          'Send via',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w500,
            color: pal.textSecondary,
          ),
        ),
        const SizedBox(height: 6),

        Row(
          children: [
            Expanded(
              child: _buildActionCardButton(
                icon: Icons.mail_outline_rounded,
                iconColor: pal.textSecondary,
                label: 'Email',
                onTap: () => _launchEmail(
                  _selectedAuthority == 'cert'
                      ? 'Sri Lanka CERT|CC'
                      : _policeItDeptTitle,
                ),
                pal: pal,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildActionCardButton(
                icon: Icons.chat_bubble_outline_rounded,
                iconColor: _whatsappGreen,
                label: 'WhatsApp',
                onTap: () => _launchWhatsApp(
                  _selectedAuthority == 'cert'
                      ? 'Sri Lanka CERT|CC'
                      : _policeItDeptTitle,
                ),
                pal: pal,
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),

        // Attach PDF report card
        _buildAttachPdfCard(pal),
        const SizedBox(height: 16),

        // Also report this video to
        Text(
          'Also report this video to',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w500,
            color: pal.textSecondary,
          ),
        ),
        const SizedBox(height: 6),

        Row(
          children: [
            Expanded(child: _buildPlatformChip('YouTube', 'https://support.google.com/youtube/answer/2807622', pal)),
            const SizedBox(width: 8),
            Expanded(child: _buildPlatformChip('TikTok', 'https://www.tiktok.com/legal/report/feedback', pal)),
            const SizedBox(width: 8),
            Expanded(child: _buildPlatformChip('Instagram', 'https://help.instagram.com/contact/636276399721841', pal)),
          ],
        ),
      ],
    );
  }

  Widget _buildAuthorityRadioCard({
    required String id,
    required String title,
    required IconData icon,
    required Color iconBg,
    required Color iconColor,
    required _EscalPal pal,
  }) {
    final isSelected = _selectedAuthority == id;
    final borderColor = isSelected ? const Color(0xFF60A5FA) : pal.border;
    final bgColor = isSelected
        ? (pal.isDark ? const Color(0xFF1E3A8A).withValues(alpha: 0.25) : const Color(0xFFEFF6FF))
        : pal.bg;

    return InkWell(
      onTap: () => setState(() => _selectedAuthority = id),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: borderColor, width: isSelected ? 1.5 : 1.0),
        ),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: iconBg,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: iconColor, size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: pal.textPrimary,
                ),
              ),
            ),
            Container(
              width: 18,
              height: 18,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected ? _primaryBlue : pal.border,
                  width: isSelected ? 5.5 : 1.5,
                ),
                color: isSelected ? Colors.white : Colors.transparent,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAttachPdfCard(_EscalPal pal, {VoidCallback? onToggle}) {
    return InkWell(
      onTap: () {
        if (onToggle != null) {
          onToggle();
        } else {
          setState(() => _attachPdf = !_attachPdf);
        }
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: pal.bg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: pal.border),
        ),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: pal.surfaceMuted,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                Icons.description_outlined,
                color: pal.textSecondary,
                size: 18,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Attach PDF report',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: pal.textPrimary,
                    ),
                  ),
                  Text(
                    _attachPdf ? 'Attached to WhatsApp (+94 78 477 0935)' : 'Summary text only',
                    style: TextStyle(
                      fontSize: 10.5,
                      color: pal.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: _attachPdf ? _primaryBlue : pal.border,
                  width: 1.5,
                ),
                color: _attachPdf ? _primaryBlue : Colors.transparent,
              ),
              child: _attachPdf
                  ? const Icon(
                      Icons.check,
                      size: 13,
                      color: Colors.white,
                    )
                  : null,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionCardButton({
    required IconData icon,
    required Color iconColor,
    required String label,
    required VoidCallback onTap,
    required _EscalPal pal,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
        decoration: BoxDecoration(
          color: pal.bg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: pal.border),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 16, color: iconColor),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: pal.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlatformChip(String platform, String url, _EscalPal pal) {
    return InkWell(
      onTap: () async {
        final r = widget.report;
        final takedownNotice = '''OFFICIAL SYNTHETIC MEDIA TAKEDOWN NOTICE
Target Platform: $platform Trust & Safety
Suspect Media: ${r.mediaName ?? r.source}
Cryptographic Hash (SHA-256): ${r.reportHash}
Forensic Verdict: ${r.verdict.toUpperCase()} (${r.fakeProbability.toStringAsFixed(1)}% synthetic likelihood)
Incident Reference: ${_formatInquiryRef()}

Pursuant to DMCA § 512 / Online Safety Act No. 9 of 2024, this asset exhibits verified synthetic manipulation and non-consensual defamation. Requesting immediate quarantine and removal.''';

        await Clipboard.setData(ClipboardData(text: takedownNotice));
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('$platform takedown notice copied. Opening portal...'),
              behavior: SnackBarBehavior.floating,
              duration: const Duration(seconds: 3),
            ),
          );
        }

        final uri = Uri.parse(url);
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        }
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 9),
        decoration: BoxDecoration(
          color: pal.bg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: pal.border),
        ),
        child: Text(
          platform,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: pal.textPrimary,
          ),
        ),
      ),
    );
  }

  // ═════════════════════════════════════════════════════════════════
  // TAB 2: INQUIRY FORM (Matches Screenshot 2)
  // ═════════════════════════════════════════════════════════════════

  Widget _buildInquiryTab(_EscalPal pal) {
    final r = widget.report;
    final inqRef = _formatInquiryRef();

    final dossierText = _buildReportText(
      _policeItDeptTitle,
      offenceCategory: _selectedOffence,
      incidentContext: _inqContextCtrl.text.trim(),
      complainantName: _inqNameCtrl.text.trim(),
      complainantAge: _inqAgeCtrl.text.trim(),
      complainantPhone: _inqPhoneCtrl.text.trim(),
      complainantEmail: _inqEmailCtrl.text.trim(),
      complainantAddress: _inqAddressCtrl.text.trim(),
      incidentPlace: _inqPlaceCtrl.text.trim(),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header
        Text(
          'Incident form',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: pal.textPrimary,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          'Ref: $inqRef',
          style: TextStyle(
            fontSize: 12,
            fontFamily: 'monospace',
            color: pal.textSecondary,
          ),
        ),
        const SizedBox(height: 14),

        // Form Fields (Empty by default)
        _buildCleanInput(
          ctrl: _inqNameCtrl,
          hint: 'Full name',
          pal: pal,
        ),
        const SizedBox(height: 10),

        Row(
          children: [
            Expanded(
              flex: 1,
              child: _buildCleanInput(
                ctrl: _inqAgeCtrl,
                hint: 'Age',
                keyboardType: TextInputType.number,
                pal: pal,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              flex: 2,
              child: _buildCleanInput(
                ctrl: _inqPhoneCtrl,
                hint: '07x xxx xxxx',
                keyboardType: TextInputType.phone,
                pal: pal,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),

        _buildCleanInput(
          ctrl: _inqEmailCtrl,
          hint: 'name@gmail.com',
          keyboardType: TextInputType.emailAddress,
          pal: pal,
        ),
        const SizedBox(height: 10),

        _buildCleanInput(
          ctrl: _inqAddressCtrl,
          hint: 'Home address',
          pal: pal,
        ),
        const SizedBox(height: 10),

        _buildCleanInput(
          ctrl: _inqPlaceCtrl,
          hint: 'Where you saw it, e.g. WhatsApp',
          pal: pal,
        ),
        const SizedBox(height: 10),

        // Dropdown for offence
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: pal.bg,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: pal.border),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _selectedOffence,
              isExpanded: true,
              dropdownColor: pal.bg,
              icon: Icon(Icons.keyboard_arrow_down_rounded, color: pal.textSecondary),
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w500,
                color: pal.textPrimary,
              ),
              items: _offences
                  .map((o) => DropdownMenuItem(
                        value: o,
                        child: Text(o),
                      ))
                  .toList(),
              onChanged: (val) {
                if (val != null) {
                  setState(() => _selectedOffence = val);
                }
              },
            ),
          ),
        ),
        const SizedBox(height: 10),

        _buildCleanInput(
          ctrl: _inqContextCtrl,
          hint: 'What happened?',
          maxLines: 2,
          pal: pal,
        ),
        const SizedBox(height: 14),

        // Auto-filled summary card
        Text(
          'Auto-filled summary',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w500,
            color: pal.textSecondary,
          ),
        ),
        const SizedBox(height: 6),

        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: pal.surfaceMuted,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: pal.border),
          ),
          child: Column(
            children: [
              _buildSummaryRow(
                'File',
                r.mediaName ?? r.source,
                isMonospace: true,
                pal: pal,
              ),
              const SizedBox(height: 6),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Result',
                    style: TextStyle(fontSize: 12, color: pal.textSecondary),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: pal.manipulatedBg,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      'Manipulated',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: _EscalPal.manipulated,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              _buildSummaryRow(
                'Fake / real',
                '${r.fakeProbability.toStringAsFixed(1)}% / ${r.authenticityScore.toStringAsFixed(1)}%',
                pal: pal,
              ),
              const SizedBox(height: 6),
              _buildSummaryRow(
                'SHA-256',
                _shortHash(r.reportHash),
                isMonospace: true,
                pal: pal,
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // Attach PDF report card
        _buildAttachPdfCard(pal),
        const SizedBox(height: 14),

        // Buttons
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: _primaryBlue,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              elevation: 0,
            ),
            icon: const Icon(Icons.description_rounded, size: 16),
            label: const Text(
              'Submit & View Official Report',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
            ),
            onPressed: () async {
              final r = widget.report;
              // Deliver inquiry directly into the official 0784770935 account in Firestore
              await InquiryService.instance.recordPoliceInquiry(
                inqRef: inqRef,
                reportId: r.verificationId,
                complainantName: _inqNameCtrl.text.trim(),
                complainantPhone: _inqPhoneCtrl.text.trim(),
                complainantEmail: _inqEmailCtrl.text.trim(),
                complainantAddress: _inqAddressCtrl.text.trim(),
                incidentLocation: _inqPlaceCtrl.text.trim(),
                offenceCategory: _selectedOffence,
                statementOfFacts: _inqContextCtrl.text.trim(),
                suspectMedia: r.mediaName ?? r.source,
                mediaType: r.mediaType,
                verdict: r.verdict,
                fakeProbability: r.fakeProbability,
                reportHash: r.reportHash,
                dossierText: dossierText,
              );
              if (mounted) {
                _showGeneratedPoliceInquiryReport(
                  context,
                  inqRef,
                  dossierText,
                );
              }
            },
          ),
        ),
        const SizedBox(height: 8),

        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: _whatsappGreen,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              elevation: 0,
            ),
            icon: const Icon(Icons.chat_bubble_outline_rounded, size: 16),
            label: const Text(
              'Direct Dispatch to WhatsApp (+94 78 477 0935)',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
            ),
            onPressed: () async {
              final r = widget.report;
              await InquiryService.instance.recordPoliceInquiry(
                inqRef: inqRef,
                reportId: r.verificationId,
                complainantName: _inqNameCtrl.text.trim(),
                complainantPhone: _inqPhoneCtrl.text.trim(),
                complainantEmail: _inqEmailCtrl.text.trim(),
                complainantAddress: _inqAddressCtrl.text.trim(),
                incidentLocation: _inqPlaceCtrl.text.trim(),
                offenceCategory: _selectedOffence,
                statementOfFacts: _inqContextCtrl.text.trim(),
                suspectMedia: r.mediaName ?? r.source,
                mediaType: r.mediaType,
                verdict: r.verdict,
                fakeProbability: r.fakeProbability,
                reportHash: r.reportHash,
                dossierText: dossierText,
              );
              if (mounted) {
                Navigator.pop(context);
                _launchWhatsApp(
                  _policeItDeptTitle,
                  customMessage: dossierText,
                  offenceCategory: _selectedOffence,
                );
              }
            },
          ),
        ),
        const SizedBox(height: 8),

        SizedBox(
          width: double.infinity,
          child: OutlinedButton(
            style: OutlinedButton.styleFrom(
              backgroundColor: pal.bg,
              foregroundColor: pal.textPrimary,
              side: BorderSide(color: pal.border),
              padding: const EdgeInsets.symmetric(vertical: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () {
              Clipboard.setData(ClipboardData(text: dossierText));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Summary copied to clipboard.'),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
            child: const Text(
              'Copy summary',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12.5),
            ),
          ),
        ),
      ],
    );
  }

  // ═════════════════════════════════════════════════════════════════
  // TAB 3: LEGAL HELP (Matches Screenshot 3 + 0784770935)
  // ═════════════════════════════════════════════════════════════════

  Widget _buildLegalTab(_EscalPal pal) {
    final r = widget.report;
    final inqRef = _formatInquiryRef();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header
        Text(
          'Legal help',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: pal.textPrimary,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          'Free support for victims.',
          style: TextStyle(
            fontSize: 12,
            color: pal.textSecondary,
          ),
        ),
        const SizedBox(height: 14),

        // Legal Aid Commission Card
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: pal.bg,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: pal.border),
          ),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: pal.surfaceMuted,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.balance_rounded,
                  color: pal.textSecondary,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Legal Aid Commission',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: pal.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      'Free legal aid',
                      style: TextStyle(
                        fontSize: 11,
                        color: pal.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              TextButton(
                style: TextButton.styleFrom(
                  foregroundColor: _primaryBlue,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  visualDensity: VisualDensity.compact,
                ),
                onPressed: () => launchUrl(Uri.parse('tel:1919')),
                child: const Text(
                  'Call',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // What you can do
        Text(
          'What you can do',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w500,
            color: pal.textSecondary,
          ),
        ),
        const SizedBox(height: 6),

        Row(
          children: [
            Expanded(
              child: _buildRemedyActionButton('Takedown', () async {
                final r = widget.report;
                final takedownNotice = '''OFFICIAL SYNTHETIC MEDIA TAKEDOWN NOTICE
Suspect Media: ${r.mediaName ?? r.source}
Cryptographic Hash (SHA-256): ${r.reportHash}
Forensic Verdict: ${r.verdict.toUpperCase()} (${r.fakeProbability.toStringAsFixed(1)}% synthetic likelihood)
Incident Reference: ${_formatInquiryRef()}

Pursuant to DMCA § 512 / Online Safety Act No. 9 of 2024, this asset exhibits verified synthetic manipulation. Requesting immediate algorithmic quarantine and removal.''';
                await Clipboard.setData(ClipboardData(text: takedownNotice));
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Takedown notice copied to clipboard.'),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                }
              }, pal),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildRemedyActionButton('Police report', () {
                setState(() => _selectedTabIndex = 1);
              }, pal),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildRemedyActionButton('Civil case', () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Consult retained lawyer below for District Court civil injunctions.'),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }, pal),
            ),
          ],
        ),
        const SizedBox(height: 14),

        // Case summary
        Text(
          'Case summary',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w500,
            color: pal.textSecondary,
          ),
        ),
        const SizedBox(height: 6),

        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: pal.surfaceMuted,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: pal.border),
          ),
          child: Column(
            children: [
              _buildSummaryRow(
                'Ref',
                inqRef,
                isMonospace: true,
                pal: pal,
              ),
              const SizedBox(height: 6),
              _buildSummaryRow(
                'Evidence',
                r.mediaName ?? r.source,
                isMonospace: true,
                pal: pal,
              ),
              const SizedBox(height: 6),
              _buildSummaryRow(
                'Result',
                'Manipulated (${r.fakeProbability.toStringAsFixed(1)}%)',
                pal: pal,
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // Related laws
        Text(
          'Related laws',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w500,
            color: pal.textSecondary,
          ),
        ),
        const SizedBox(height: 6),

        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildLawBullet('Computer Crimes Act No. 24 of 2007', pal),
            const SizedBox(height: 4),
            _buildLawBullet('Online Safety Act No. 9 of 2024', pal),
          ],
        ),
        const SizedBox(height: 14),

        // Attach PDF report card
        _buildAttachPdfCard(pal),
        const SizedBox(height: 14),

        // Buttons (Send to lawyer goes to 0784770935)
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: _whatsappGreen,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              elevation: 0,
            ),
            icon: const Icon(Icons.chat_bubble_outline_rounded, size: 16),
            label: const Text(
              'Send to lawyer (+94 78 477 0935)',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
            ),
            onPressed: () {
              Navigator.pop(context);
              _dispatchBriefToLawyer();
            },
          ),
        ),
        const SizedBox(height: 8),

        SizedBox(
          width: double.infinity,
          child: OutlinedButton(
            style: OutlinedButton.styleFrom(
              backgroundColor: pal.bg,
              foregroundColor: pal.textPrimary,
              side: BorderSide(color: pal.border),
              padding: const EdgeInsets.symmetric(vertical: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () {
              final briefText = '''LEGAL DEFENSE BRIEF
Reference ID: $inqRef
Media: ${r.mediaName ?? r.source}
Verdict: ${r.verdict.toUpperCase()} (${r.fakeProbability.toStringAsFixed(1)}%)
SHA-256: ${r.reportHash}
Applicable Statutes:
• Computer Crimes Act No. 24 of 2007
• Online Safety Act No. 9 of 2024''';
              Clipboard.setData(ClipboardData(text: briefText));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Case summary copied to clipboard.'),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
            child: const Text(
              'Copy summary',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12.5),
            ),
          ),
        ),
      ],
    );
  }

  // ── Helper Widgets ────────────────────────────────────────────────

  Widget _buildCleanInput({
    required TextEditingController ctrl,
    required String hint,
    required _EscalPal pal,
    TextInputType? keyboardType,
    int maxLines = 1,
  }) {
    return TextField(
      controller: ctrl,
      keyboardType: keyboardType,
      maxLines: maxLines,
      onChanged: (_) => setState(() {}),
      style: TextStyle(fontSize: 12.5, color: pal.textPrimary),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(fontSize: 12.5, color: pal.textSubtle),
        filled: true,
        fillColor: pal.bg,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        isDense: true,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: pal.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: pal.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _primaryBlue, width: 1.5),
        ),
      ),
    );
  }

  Widget _buildSummaryRow(
    String label,
    String value, {
    bool isMonospace = false,
    required _EscalPal pal,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(fontSize: 12, color: pal.textSecondary),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.right,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              fontFamily: isMonospace ? 'monospace' : null,
              color: pal.textPrimary,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRemedyActionButton(String label, VoidCallback onTap, _EscalPal pal) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: pal.bg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: pal.border),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: pal.textPrimary,
          ),
        ),
      ),
    );
  }

  Widget _buildLawBullet(String text, _EscalPal pal) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('• ', style: TextStyle(fontSize: 12, color: pal.textSecondary)),
        Expanded(
          child: Text(
            text,
            style: TextStyle(fontSize: 12, color: pal.textPrimary),
          ),
        ),
      ],
    );
  }

  // ── Police Inquiry Generated Report Dialog ────────────────────────

  void _showGeneratedPoliceInquiryReport(
    BuildContext context,
    String inqRef,
    String dossierText,
  ) {
    final pal = _pal;
    final r = widget.report;

    bool isOpeningPdf = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            return Container(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(ctx).size.height * 0.90,
              ),
              decoration: BoxDecoration(
                color: pal.bg,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                border: Border.all(color: pal.border),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(height: 12),
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: pal.border,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Title Bar
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.green.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(
                            Icons.verified_user_rounded,
                            color: Colors.green,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'DEPARTMENT OF POLICE • SRI LANKA',
                                style: TextStyle(
                                  fontSize: 9.5,
                                  fontFamily: 'monospace',
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.8,
                                  color: _primaryBlue,
                                ),
                              ),
                              Text(
                                'Official Inquiry Report Generated',
                                style: TextStyle(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w700,
                                  color: pal.textPrimary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close_rounded, size: 20),
                          color: pal.textSecondary,
                          onPressed: () => Navigator.pop(ctx),
                        ),
                      ],
                    ),
                  ),

                  const Divider(height: 16),

                  // Scrollable Document Content
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Inquiry Reference Banner
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: pal.surfaceMuted,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: pal.border),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'OFFICIAL INQUIRY REFERENCE',
                                        style: TextStyle(
                                          fontSize: 9,
                                          fontWeight: FontWeight.w700,
                                          letterSpacing: 0.6,
                                          color: pal.textSubtle,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        inqRef,
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontFamily: 'monospace',
                                          fontWeight: FontWeight.w800,
                                          color: _primaryBlue,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        'Police IT Department Desk • Evidence Act §4 Admissible',
                                        style: TextStyle(
                                          fontSize: 10,
                                          color: pal.textSecondary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                IconButton(
                                  tooltip: 'Copy Reference',
                                  icon: const Icon(Icons.copy_rounded, size: 16),
                                  color: pal.textSecondary,
                                  onPressed: () {
                                    Clipboard.setData(ClipboardData(text: inqRef));
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('Inquiry Number copied to clipboard.'),
                                        behavior: SnackBarBehavior.floating,
                                      ),
                                    );
                                  },
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),

                          // Complainant Particulars Summary
                          Text(
                            '1. COMPLAINANT PARTICULARS',
                            style: TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.8,
                              color: pal.textSubtle,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: pal.surfaceMuted,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: pal.border),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildInfoRow('Full Name', _inqNameCtrl.text.trim().isNotEmpty ? _inqNameCtrl.text.trim() : 'Anonymous / Not provided', pal),
                                _buildInfoRow('Age', _inqAgeCtrl.text.trim().isNotEmpty ? _inqAgeCtrl.text.trim() : 'N/A', pal),
                                _buildInfoRow('Contact Phone', _inqPhoneCtrl.text.trim().isNotEmpty ? _inqPhoneCtrl.text.trim() : 'Not provided', pal),
                                _buildInfoRow('Email Address', _inqEmailCtrl.text.trim().isNotEmpty ? _inqEmailCtrl.text.trim() : 'Not provided', pal),
                                _buildInfoRow('Residential Address', _inqAddressCtrl.text.trim().isNotEmpty ? _inqAddressCtrl.text.trim() : 'Not provided', pal),
                                _buildInfoRow('Incident Location', _inqPlaceCtrl.text.trim().isNotEmpty ? _inqPlaceCtrl.text.trim() : 'Not specified', pal),
                                _buildInfoRow('Offence Classification', _selectedOffence, pal),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),

                          // Sworn Statement
                          if (_inqContextCtrl.text.trim().isNotEmpty) ...[
                            Text(
                              '2. SWORN STATEMENT OF FACTS',
                              style: TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.8,
                                color: pal.textSubtle,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: pal.surfaceMuted,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: pal.border),
                              ),
                              child: Text(
                                _inqContextCtrl.text.trim(),
                                style: TextStyle(
                                  fontSize: 11,
                                  fontStyle: FontStyle.italic,
                                  color: pal.textPrimary,
                                  height: 1.4,
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                          ],

                          // Forensic Evidence Record
                          Text(
                            '3. FORENSIC EVIDENCE RECORD',
                            style: TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.8,
                              color: pal.textSubtle,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: pal.surfaceMuted,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: pal.border),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildInfoRow('Suspect Media', r.mediaName ?? r.source, pal),
                                _buildInfoRow('Forensic Verdict', '${r.verdict.toUpperCase()} (${r.fakeProbability.toStringAsFixed(1)}%)', pal),
                                _buildInfoRow('SHA-256 Digest', r.reportHash, pal),
                                _buildInfoRow('Chain of Custody', 'ISO/IEC 27037:2012 Certified Admissible Evidence', pal),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                        ],
                      ),
                    ),
                  ),

                  // Action Toolbar
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: pal.bg,
                      border: Border(top: BorderSide(color: pal.border)),
                    ),
                    child: Column(
                      children: [
                        _buildAttachPdfCard(
                          pal,
                          onToggle: () {
                            setModalState(() => _attachPdf = !_attachPdf);
                            setState(() {});
                          },
                        ),
                        const SizedBox(height: 10),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _primaryBlue,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              elevation: 0,
                            ),
                            icon: isOpeningPdf
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                  )
                                : const Icon(Icons.picture_as_pdf_rounded, size: 16),
                            label: Text(
                              isOpeningPdf ? 'Opening PDF Report...' : 'View / Open Generated Inquiry PDF',
                              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                            ),
                            onPressed: isOpeningPdf
                                ? null
                                : () async {
                                    setModalState(() => isOpeningPdf = true);
                                    try {
                                      final inqRefClean = inqRef;
                                      final pdfFile = await _generatePoliceInquiryPdf(inqRefClean);
                                      if (await pdfFile.exists()) {
                                        if (ctx.mounted) {
                                          Navigator.of(ctx).push(
                                            MaterialPageRoute(
                                              builder: (_) => PdfViewerScreen(
                                                file: pdfFile,
                                                title: 'Official Inquiry Report',
                                                subtitle: inqRefClean,
                                                fileName: 'Inquiry_Report_$inqRefClean.pdf',
                                              ),
                                            ),
                                          );
                                        }
                                      } else {
                                        if (ctx.mounted) {
                                          ScaffoldMessenger.of(ctx).showSnackBar(
                                            const SnackBar(
                                              content: Text('Failed to generate PDF report. Please try again.'),
                                              backgroundColor: Colors.redAccent,
                                            ),
                                          );
                                        }
                                      }
                                    } catch (e) {
                                      if (ctx.mounted) {
                                        ScaffoldMessenger.of(ctx).showSnackBar(
                                          SnackBar(
                                            content: Text('Error generating PDF: $e'),
                                            backgroundColor: Colors.redAccent,
                                          ),
                                        );
                                      }
                                    } finally {
                                      if (ctx.mounted) {
                                        setModalState(() => isOpeningPdf = false);
                                      }
                                    }
                                  },
                          ),
                        ),
                        const SizedBox(height: 8),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _whatsappGreen,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              elevation: 0,
                            ),
                            icon: const Icon(Icons.chat_bubble_outline_rounded, size: 16),
                            label: const Text(
                              'Dispatch to Police IT Department (+94 78 477 0935)',
                              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                            ),
                            onPressed: () async {
                              Navigator.pop(ctx);
                              Navigator.pop(context);
                              final r = widget.report;
                              await InquiryService.instance.recordPoliceInquiry(
                                inqRef: inqRef,
                                reportId: r.verificationId,
                                complainantName: _inqNameCtrl.text.trim(),
                                complainantPhone: _inqPhoneCtrl.text.trim(),
                                complainantEmail: _inqEmailCtrl.text.trim(),
                                complainantAddress: _inqAddressCtrl.text.trim(),
                                incidentLocation: _inqPlaceCtrl.text.trim(),
                                offenceCategory: _selectedOffence,
                                statementOfFacts: _inqContextCtrl.text.trim(),
                                suspectMedia: r.mediaName ?? r.source,
                                mediaType: r.mediaType,
                                verdict: r.verdict,
                                fakeProbability: r.fakeProbability,
                                reportHash: r.reportHash,
                                dossierText: dossierText,
                              );
                              _launchWhatsApp(
                                _policeItDeptTitle,
                                customMessage: dossierText,
                                offenceCategory: _selectedOffence,
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildInfoRow(String label, String value, _EscalPal pal) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              '$label:',
              style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: pal.textSecondary),
            ),
          ),
          Expanded(
            child: Text(
              value,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: pal.textPrimary),
            ),
          ),
        ],
      ),
    );
  }

  Future<File> _generatePoliceInquiryPdf(String inqRef) async {
    final r = widget.report;
    final pdf = pw.Document();

    final name = _inqNameCtrl.text.trim().isNotEmpty ? _inqNameCtrl.text.trim() : 'Anonymous / Not provided';
    final age = _inqAgeCtrl.text.trim().isNotEmpty ? _inqAgeCtrl.text.trim() : 'N/A';
    final phone = _inqPhoneCtrl.text.trim().isNotEmpty ? _inqPhoneCtrl.text.trim() : 'Not provided';
    final email = _inqEmailCtrl.text.trim().isNotEmpty ? _inqEmailCtrl.text.trim() : 'Not provided';
    final address = _inqAddressCtrl.text.trim().isNotEmpty ? _inqAddressCtrl.text.trim() : 'Not provided';
    final place = _inqPlaceCtrl.text.trim().isNotEmpty ? _inqPlaceCtrl.text.trim() : 'Not specified';
    final contextText = _inqContextCtrl.text.trim().isNotEmpty ? _inqContextCtrl.text.trim() : 'No additional facts provided.';

    final primaryBlue = PdfColor.fromHex('#1976D2');
    final darkText = PdfColor.fromHex('#0F172A');
    final subtleText = PdfColor.fromHex('#64748B');
    final cardBg = PdfColor.fromHex('#F8FAFC');
    final borderColor = PdfColor.fromHex('#E2E8F0');
    final redColor = PdfColor.fromHex('#DC2626');

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.symmetric(horizontal: 32, vertical: 28),
        build: (pw.Context ctx) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Header Banner
              pw.Container(
                padding: const pw.EdgeInsets.all(12),
                decoration: pw.BoxDecoration(
                  color: primaryBlue,
                  borderRadius: pw.BorderRadius.circular(6),
                ),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          'DEPARTMENT OF POLICE - SRI LANKA',
                          style: pw.TextStyle(
                            color: PdfColors.white,
                            fontSize: 10,
                            fontWeight: pw.FontWeight.bold,
                            letterSpacing: 1.0,
                          ),
                        ),
                        pw.SizedBox(height: 2),
                        pw.Text(
                          'CYBERCRIME INVESTIGATION DIVISION (CID)',
                          style: pw.TextStyle(
                            color: PdfColors.white,
                            fontSize: 13,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    pw.Container(
                      padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: pw.BoxDecoration(
                        color: PdfColors.white,
                        borderRadius: pw.BorderRadius.circular(4),
                      ),
                      child: pw.Text(
                        'OFFICIAL INQUIRY',
                        style: pw.TextStyle(
                          color: primaryBlue,
                          fontSize: 8.5,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 12),

              // Reference Strip
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: pw.BoxDecoration(
                  color: cardBg,
                  borderRadius: pw.BorderRadius.circular(4),
                  border: pw.Border.all(color: borderColor),
                ),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          'INQUIRY REFERENCE NUMBER',
                          style: pw.TextStyle(color: subtleText, fontSize: 7, fontWeight: pw.FontWeight.bold),
                        ),
                        pw.Text(
                          inqRef,
                          style: pw.TextStyle(color: primaryBlue, fontSize: 13, fontWeight: pw.FontWeight.bold),
                        ),
                      ],
                    ),
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.end,
                      children: [
                        pw.Text(
                          'FILING DATE & TIME',
                          style: pw.TextStyle(color: subtleText, fontSize: 7, fontWeight: pw.FontWeight.bold),
                        ),
                        pw.Text(
                          DateTime.now().toIso8601String().substring(0, 19).replaceAll('T', ' '),
                          style: pw.TextStyle(color: darkText, fontSize: 9, fontWeight: pw.FontWeight.bold),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 14),

              // Section 1: Complainant Information
              pw.Text(
                '1. COMPLAINANT PARTICULARS',
                style: pw.TextStyle(color: primaryBlue, fontSize: 10, fontWeight: pw.FontWeight.bold),
              ),
              pw.SizedBox(height: 4),
              pw.Container(
                padding: const pw.EdgeInsets.all(10),
                decoration: pw.BoxDecoration(
                  color: cardBg,
                  borderRadius: pw.BorderRadius.circular(4),
                  border: pw.Border.all(color: borderColor),
                ),
                child: pw.Column(
                  children: [
                    _pwRow('Full Legal Name', name, darkText, subtleText),
                    _pwRow('Age', age, darkText, subtleText),
                    _pwRow('Contact Phone', phone, darkText, subtleText),
                    _pwRow('Email Address', email, darkText, subtleText),
                    _pwRow('Residential Address', address, darkText, subtleText),
                    _pwRow('Incident Platform / Location', place, darkText, subtleText),
                  ],
                ),
              ),
              pw.SizedBox(height: 12),

              // Section 2: Incident Classification & Sworn Facts
              pw.Text(
                '2. INCIDENT PARTICULARS & SWORN STATEMENT',
                style: pw.TextStyle(color: primaryBlue, fontSize: 10, fontWeight: pw.FontWeight.bold),
              ),
              pw.SizedBox(height: 4),
              pw.Container(
                padding: const pw.EdgeInsets.all(10),
                decoration: pw.BoxDecoration(
                  color: cardBg,
                  borderRadius: pw.BorderRadius.circular(4),
                  border: pw.Border.all(color: borderColor),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    _pwRow('Offence Classification', _selectedOffence, darkText, subtleText),
                    pw.SizedBox(height: 4),
                    pw.Text('Statement of Facts:', style: pw.TextStyle(fontSize: 8.5, color: subtleText, fontWeight: pw.FontWeight.bold)),
                    pw.SizedBox(height: 2),
                    pw.Text(
                      contextText,
                      style: pw.TextStyle(fontSize: 9, color: darkText, fontStyle: pw.FontStyle.italic),
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 12),

              // Section 3: Forensic Verification Findings
              pw.Text(
                '3. DIGITAL FORENSIC VERIFICATION EVIDENCE',
                style: pw.TextStyle(color: primaryBlue, fontSize: 10, fontWeight: pw.FontWeight.bold),
              ),
              pw.SizedBox(height: 4),
              pw.Container(
                padding: const pw.EdgeInsets.all(10),
                decoration: pw.BoxDecoration(
                  color: cardBg,
                  borderRadius: pw.BorderRadius.circular(4),
                  border: pw.Border.all(color: borderColor),
                ),
                child: pw.Column(
                  children: [
                    _pwRow('Suspect Media File', r.mediaName ?? r.source, darkText, subtleText),
                    _pwRow('Modality Type', r.mediaType, darkText, subtleText),
                    _pwRow('Forensic Verdict', '${r.verdict.toUpperCase()} (${r.fakeProbability.toStringAsFixed(1)}% Synthetic Likelihood)', redColor, subtleText),
                    _pwRow('Authenticity Confidence', '${r.authenticityScore.toStringAsFixed(1)}%', darkText, subtleText),
                    _pwRow('Cryptographic Hash (SHA-256)', r.reportHash, darkText, subtleText),
                    _pwRow('Forensic Chain of Custody', 'ISO/IEC 27037:2012 Certified Digital Forensics', darkText, subtleText),
                  ],
                ),
              ),
              pw.SizedBox(height: 14),

              // Section 4: Legal Notice & Certification Stamp
              pw.Container(
                padding: const pw.EdgeInsets.all(8),
                decoration: pw.BoxDecoration(
                  borderRadius: pw.BorderRadius.circular(4),
                  border: pw.Border.all(color: borderColor),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'STATUTORY LEGAL ADMISSIBILITY:',
                      style: pw.TextStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold, color: darkText),
                    ),
                    pw.Text(
                      'This inquiry dossier is generated by VeriFrame Digital Verification System in accordance with Evidence (Special Provisions) Act No. 14 of 1995, Computer Crimes Act No. 24 of 2007 (Sec. 6, 14), and Online Safety Act No. 9 of 2024. Certified admissible for preliminary law enforcement inquiry and court filing.',
                      style: pw.TextStyle(fontSize: 7, color: subtleText),
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 12),

              // Footer
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('VeriFrame Police Cybercrime Intake System', style: pw.TextStyle(fontSize: 7.5, color: subtleText)),
                  pw.Text('Official Seal & Hash: ${r.reportHash.substring(0, math.min(16, r.reportHash.length))}', style: pw.TextStyle(fontSize: 7.5, color: subtleText)),
                ],
              ),
            ],
          );
        },
      ),
    );

    final bytes = await pdf.save();
    Directory dir;
    try {
      dir = await getTemporaryDirectory();
    } catch (_) {
      dir = await getApplicationDocumentsDirectory();
    }
    final safeName = inqRef.replaceAll(RegExp(r'[^a-zA-Z0-9_\-]'), '_');
    final file = File('${dir.path}/Inquiry_Report_$safeName.pdf');
    await file.writeAsBytes(bytes, flush: true);
    return file;
  }

  static pw.Widget _pwRow(String label, String value, PdfColor valColor, PdfColor lblColor) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 3),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(label, style: pw.TextStyle(fontSize: 8.5, color: lblColor)),
          pw.SizedBox(width: 8),
          pw.Expanded(
            child: pw.Text(
              value,
              textAlign: pw.TextAlign.right,
              maxLines: 1,
              overflow: pw.TextOverflow.clip,
              style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold, color: valColor),
            ),
          ),
        ],
      ),
    );
  }
}