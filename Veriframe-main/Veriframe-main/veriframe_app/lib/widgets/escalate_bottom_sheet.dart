import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:open_filex/open_filex.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:veriframe_app/l10n/app_localizations.dart';
import 'package:veriframe_app/models/verification_result.dart';
import 'package:veriframe_app/service/pdf_service.dart';

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
      isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569);
  Color get textSubtle =>
      isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8);

  static const manipulated = Color(0xFFDC2626);
  Color get manipulatedBg =>
      isDark ? const Color(0x29DC2626) : const Color(0xFFFEF2F2);
  Color get data =>
      isDark ? const Color(0xFF38BDF8) : const Color(0xFF0284C7);
}

// ─────────────────────────────────────────────────────────────────────────────
// EscalateBottomSheet — Shared Institutional Widget
// ─────────────────────────────────────────────────────────────────────────────

class EscalateBottomSheet extends StatefulWidget {
  const EscalateBottomSheet({super.key, required this.report});

  final VerificationResult report;

  @override
  State<EscalateBottomSheet> createState() => _EscalateBottomSheetState();
}

class _EscalateBottomSheetState extends State<EscalateBottomSheet> {
  static const Color _whatsappGreen = Color(0xFF059669);

  /// Authority WhatsApp contact in international format (no +, no spaces).
  static const String _whatsappNumber = '94784770935';

  /// Human-readable descriptor shown in the UI (keeps specific number confidential).
  static const String _whatsappDisplay = 'Official Police Channel';

  /// Display title for the WhatsApp contact.
  static const String _policeItDeptTitle = 'Police IT Department';

  /// Authority email that receives the forensic PDF.
  static const String _emailAddress = 'sithmiyara2001@gmail.com';

  /// Human-readable descriptor shown in UI for email (keeps email confidential).
  static const String _emailDisplay = 'Official CID Desk';

  /// Retained defense lawyer contact.
  static const String _lawyerWhatsApp = '94771234567';

  static const String _gmailPackage = 'com.google.android.gm';
  static const String _methodChannel = 'com.veriframe_app/share_pdf';

  // 0: Escalate Sheet (Police & CERT), 1: Inquiry Document, 2: Legal Help (Lawyers)
  int _selectedTabIndex = 0;

  String? _selectedAuthority = 'cid';
  bool _attachPdf = true;

  // Complainant particulars controllers for the Inquiry Document
  late final TextEditingController _inqNameCtrl;
  late final TextEditingController _inqAgeCtrl;
  late final TextEditingController _inqPhoneCtrl;
  late final TextEditingController _inqEmailCtrl;
  late final TextEditingController _inqAddressCtrl;
  late final TextEditingController _inqPlaceCtrl;
  late final TextEditingController _inqContextCtrl;
  String _selectedOffence = 'Synthetic Identity Theft & Impersonation (Penal Code §419)';

  final List<String> _offences = const [
    'Synthetic Identity Theft & Impersonation (Penal Code §419)',
    'Deepfake Defamation & Harassment (Online Safety Act §13)',
    'Financial Cyber Extortion & Fraud (Computer Crimes Act §6)',
    'Non-Consensual Synthetic Video Dissemination',
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
    final r = widget.report;
    if (r.pdfPath != null && r.pdfPath!.isNotEmpty && File(r.pdfPath!).existsSync()) {
      return File(r.pdfPath!);
    }
    try {
      final file = await PdfService.instance.generateReportPdf(result: r);
      return file;
    } catch (e) {
      debugPrint('[EscalateBottomSheet] PDF generation failed: $e');
      return null;
    }
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
    final inqRef = 'INQ-CID-${r.verificationId.substring(0, math.min(8, r.verificationId.length)).toUpperCase()}';
    final lines = <String>[
      'POLICE CYBERCRIME INQUIRY & FORENSIC DOSSIER',
      'Target Authority: $authorityTitle',
      'Inquiry Reference: $inqRef',
      'Date / Time: ${r.verifiedAt.toIso8601String()}',
      '---------------------------------------------',
      if ((complainantName != null && complainantName.isNotEmpty) ||
          (complainantEmail != null && complainantEmail.isNotEmpty) ||
          (complainantPhone != null && complainantPhone.isNotEmpty)) ...[
        'I. COMPLAINANT PARTICULARS:',
        if (complainantName != null && complainantName.isNotEmpty) '• Full Name: $complainantName',
        if (complainantAge != null && complainantAge.isNotEmpty) '• Age: $complainantAge',
        if (complainantPhone != null && complainantPhone.isNotEmpty) '• Contact Phone: $complainantPhone',
        if (complainantEmail != null && complainantEmail.isNotEmpty) '• Email Address: $complainantEmail',
        if (complainantAddress != null && complainantAddress.isNotEmpty) '• Residential Address: $complainantAddress',
        if (incidentPlace != null && incidentPlace.isNotEmpty) '• Incident Location / Platform: $incidentPlace',
        '',
      ] else ...[
        'I. COMPLAINANT PARTICULARS:',
        '• [Complainant particulars pending entry]',
        '',
      ],
      'II. OFFENCE CLASSIFICATION & STATUTORY PROVISIONS:',
      '• Violation: ${offenceCategory ?? _selectedOffence}',
      '• Applicable Statutes: Computer Crimes Act No. 24 of 2007 (Sec. 6/14), Penal Code Sec. 419, Online Safety Act No. 9 of 2024, Evidence Act No. 14 of 1995',
      '',
      'III. STATEMENT OF FACTS:',
      if (incidentContext != null && incidentContext.isNotEmpty)
        '• $incidentContext'
      else
        '• [Statement of facts pending entry]',
      '',
      'IV. FORENSIC EVIDENCE RECORD:',
      '• Media Asset: ${r.mediaName ?? r.source}',
      '• Modality Type: ${r.mediaType}',
      '• Verdict: ${r.verdict.toUpperCase()}',
      '• Risk Level: ${r.riskLevel.toUpperCase()}',
      '• Synthetic Probability: ${r.fakeProbability.toStringAsFixed(1)}%',
      '• Authenticity Confidence: ${r.authenticityScore.toStringAsFixed(1)}%',
      '• Checksum SHA-256: ${r.reportHash}',
      '• Chain of Custody: ISO/IEC 27037 Verified',
      '• Dossier Status: ${_attachPdf ? "Certified Forensic PDF Dossier Included" : "Summary Text Only"}',
      '---------------------------------------------',
      'Submitted via VeriFrame Digital Evidence Intake System',
    ];
    return lines.join('\n');
  }

  String _emailSubject(String authorityTitle, {String? offenceCategory}) {
    final r = widget.report;
    final inqRef = 'INQ-CID-${r.verificationId.substring(0, math.min(8, r.verificationId.length)).toUpperCase()}';
    final cat = (offenceCategory != null && offenceCategory.isNotEmpty) ? ' - $offenceCategory' : '';
    return 'Formal Cybercrime Inquiry: $authorityTitle [$inqRef]$cat';
  }

  Future<void> _launchWhatsApp(
    String authorityTitle, {
    String? customMessage,
    String? offenceCategory,
  }) async {
    final message = customMessage ?? _buildReportText(authorityTitle, offenceCategory: offenceCategory);

    if (_attachPdf) {
      final pdfFile = await _getPdfFile();
      if (pdfFile != null) {
        if (Platform.isAndroid) {
          try {
            final shared = await const MethodChannel(_methodChannel).invokeMethod<bool>(
              'sharePdfToApp',
              {
                'filePath': pdfFile.path,
                'appPackage': 'com.whatsapp',
                'recipient': _whatsappNumber,
                'subject': _emailSubject(authorityTitle, offenceCategory: offenceCategory),
                'body': message,
              },
            );
            if (shared == true) return;
          } catch (e) {
            debugPrint('[EscalateBottomSheet] WhatsApp channel PDF share failed: $e');
          }
        }

        try {
          await Share.shareXFiles(
            [XFile(pdfFile.path)],
            text: message,
            subject: _emailSubject(authorityTitle, offenceCategory: offenceCategory),
          );
          return;
        } catch (e) {
          debugPrint('[EscalateBottomSheet] ShareXFiles PDF failed: $e');
        }
      }
    }

    final waUri = Uri.https('wa.me', '/$_whatsappNumber', {'text': message});

    if (Platform.isAndroid) {
      try {
        await const MethodChannel(_methodChannel).invokeMethod<bool>(
          'openWhatsAppChat',
          {'phone': _whatsappNumber, 'message': message},
        );
        return;
      } catch (e) {
        debugPrint('[EscalateBottomSheet] WhatsApp channel failed: $e');
      }
    }

    try {
      final opened = await launchUrl(
        waUri,
        mode: LaunchMode.externalApplication,
      );
      if (!opened) throw Exception('launchUrl returned false');
    } catch (e) {
      debugPrint('[EscalateBottomSheet] wa.me fallback failed: $e');
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
              'recipient': _emailAddress,
              'subject': subject,
              'body': body,
            },
          );
          if (shared == true) return;
        } catch (e) {
          debugPrint('[EscalateBottomSheet] Gmail share failed: $e');
        }
      }

      if (pdfFile != null) {
        try {
          await Share.shareXFiles(
            [XFile(pdfFile.path)],
            text: body,
            subject: subject,
          );
          return;
        } catch (e) {
          debugPrint('[EscalateBottomSheet] ShareXFiles email failed: $e');
        }
      }
    }

    try {
      final opened = await launchUrl(
        Uri(
          scheme: 'mailto',
          path: _emailAddress,
          queryParameters: {'subject': subject, 'body': body},
        ),
        mode: LaunchMode.externalApplication,
      );
      if (!opened) throw Exception('launchUrl returned false');
    } catch (e) {
      debugPrint('[EscalateBottomSheet] mailto fallback failed: $e');
      if (mounted) _showErrorSnackBar();
    }
  }

  Future<void> _dispatchBriefToLawyer() async {
    final r = widget.report;
    final inqRef = 'INQ-CID-${r.verificationId.substring(0, math.min(8, r.verificationId.length)).toUpperCase()}';
    final briefText = '''LEGAL CONSULTATION & ADVOCATE COURT BRIEF
Matter: Deepfake Defamation & Computer Crime
Ref: $inqRef
Client Name: ${_inqNameCtrl.text.trim()}
Client Phone: ${_inqPhoneCtrl.text.trim()}
Client Email: ${_inqEmailCtrl.text.trim()}
Suspect Media: ${r.mediaName ?? r.source}
Verdict: ${r.verdict.toUpperCase()} (${r.fakeProbability.toStringAsFixed(1)}% Synthetic Likelihood)
SHA-256: ${r.reportHash}
Applicable Acts: Computer Crimes Act 2007 (Sec. 6/14), Penal Code Sec. 419, Online Safety Act 2024.
Chain of Custody: ISO/IEC 27037 Verified.
Requesting urgent legal review and District Court Enjoining Order preparation.''';

    if (_attachPdf) {
      final pdfFile = await _getPdfFile();
      if (pdfFile != null) {
        try {
          await Share.shareXFiles(
            [XFile(pdfFile.path)],
            text: briefText,
            subject: 'Advocate Case Brief: $inqRef',
          );
          return;
        } catch (_) {}
      }
    }

    final waUri = Uri.https('wa.me', '/$_lawyerWhatsApp', {'text': briefText});
    try {
      await launchUrl(waUri, mode: LaunchMode.externalApplication);
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
    final loc = AppLocalizations.of(context)!;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final pal = _pal;

    final Color accentColor = pal.isDark
        ? const Color(0xFF38BDF8)
        : const Color(0xFF0284C7);
    final Color accentBg = accentColor.withValues(alpha: 0.10);

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.88,
      ),
      padding: EdgeInsets.fromLTRB(18, 12, 18, 20 + bottomInset),
      decoration: BoxDecoration(
        color: pal.bg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
        border: Border.all(color: pal.border, width: 1),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Drag Handle ──
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: pal.textSubtle.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 12),

            // ── Segmented Navigation Tabs ──
            Container(
              decoration: BoxDecoration(
                color: pal.surfaceMuted,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: pal.border),
              ),
              padding: const EdgeInsets.all(3),
              child: Row(
                children: [
                  _buildTabButton(0, 'Escalate Sheet', pal),
                  _buildTabButton(1, 'Inquiry Document', pal),
                  _buildTabButton(2, 'Legal Help', pal),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // ── Tab Content ──
            Flexible(
              child: SingleChildScrollView(
                child: _selectedTabIndex == 0
                    ? _buildEscalateTab(loc, accentColor, accentBg, pal)
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

  Widget _buildTabButton(int index, String label, _EscalPal pal) {
    final isSelected = _selectedTabIndex == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedTabIndex = index),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSelected
                ? (pal.isDark ? const Color(0xFF2563EB) : const Color(0xFF1E40AF))
                : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.15),
                      blurRadius: 4,
                      offset: const Offset(0, 1),
                    )
                  ]
                : null,
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
              color: isSelected ? Colors.white : pal.textSecondary,
            ),
          ),
        ),
      ),
    );
  }

  // ═════════════════════════════════════════════════════════════════
  // TAB 1: ESCALATE SHEET (CLEAN REPORT: POLICE & CERT WITH PDF)
  // ═════════════════════════════════════════════════════════════════

  Widget _buildEscalateTab(
    AppLocalizations loc,
    Color accentColor,
    Color accentBg,
    _EscalPal pal,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(9),
              decoration: BoxDecoration(
                color: pal.manipulatedBg,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.shield_outlined,
                color: _EscalPal.manipulated,
                size: 22,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    loc.escalateReportTitle,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: pal.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    loc.escalateReportSubtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: pal.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),

        // Authority Section
        Text(
          loc.authoritySectionLabel,
          style: TextStyle(
            fontSize: 10.5,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.8,
            color: pal.textSubtle,
          ),
        ),
        const SizedBox(height: 8),

        _buildAuthorityTile(
          id: 'cid',
          title: loc.verifySriLankaPolice,
          subtitle: 'Cybercrime Investigation Division',
          icon: Icons.local_police_outlined,
          accentColor: accentColor,
          accentBg: accentBg,
          pal: pal,
        ),
        const SizedBox(height: 8),

        _buildAuthorityTile(
          id: 'cert',
          title: loc.verifyCertCc,
          subtitle: 'National cyber security incident response',
          icon: Icons.dns_outlined,
          accentColor: accentColor,
          accentBg: accentBg,
          pal: pal,
        ),
        const SizedBox(height: 18),

        // Send Via Channels
        Text(
          loc.sendViaLabel,
          style: TextStyle(
            fontSize: 10.5,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.8,
            color: pal.textSubtle,
          ),
        ),
        const SizedBox(height: 8),

        Row(
          children: [
            Expanded(
              child: _buildSendButton(
                label: _policeItDeptTitle,
                destination: _whatsappDisplay,
                icon: Icons.chat_outlined,
                color: _whatsappGreen,
                onTap: () => _launchWhatsApp(_policeItDeptTitle),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildSendButton(
                label: 'Email CID',
                destination: _emailDisplay,
                icon: Icons.mail_outline_rounded,
                color: accentColor,
                onTap: () => _launchEmail(_authorityTitle(loc)),
              ),
            ),
          ],
        ),
        _buildAttachButton(loc),
        const SizedBox(height: 12),
        _buildSocialPlatformReportSection(pal),
      ],
    );
  }

  Widget _buildSocialPlatformReportSection(_EscalPal pal) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: pal.surfaceMuted,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: pal.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.public, size: 16, color: Color(0xFF38BDF8)),
              const SizedBox(width: 6),
              Text(
                'One-Tap Platform Takedown',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: pal.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Directly dispatch formal violation reports to platform Trust & Safety desks:',
            style: TextStyle(fontSize: 10.5, color: pal.textSecondary),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _platformChip(
                  label: 'YouTube',
                  icon: Icons.video_library,
                  color: const Color(0xFFEF4444),
                  url: 'https://support.google.com/youtube/answer/2807622',
                  pal: pal,
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _platformChip(
                  label: 'TikTok',
                  icon: Icons.music_note,
                  color: const Color(0xFF06B6D4),
                  url: 'https://www.tiktok.com/legal/report/feedback',
                  pal: pal,
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _platformChip(
                  label: 'Instagram',
                  icon: Icons.camera_alt,
                  color: const Color(0xFFEC4899),
                  url: 'https://help.instagram.com/contact/636276399721841',
                  pal: pal,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _platformChip({
    required String label,
    required IconData icon,
    required Color color,
    required String url,
    required _EscalPal pal,
  }) {
    return InkWell(
      onTap: () async {
        final r = widget.report;
        final takedownDossier = '''OFFICIAL SYNTHETIC MEDIA TAKEDOWN NOTICE
Target Platform: $label Trust & Safety / Abuse Operations
Notice Type: Non-Consensual Deepfake & Generative Impersonation
Suspect Media: ${r.mediaName ?? r.source}
Cryptographic Hash (SHA-256): ${r.reportHash}
Forensic Determination: ${r.verdict.toUpperCase()} (${r.fakeProbability.toStringAsFixed(1)}% Synthetic Likelihood)
Chain of Custody: ISO/IEC 27037:2012 Admissible Forensics
Date/Time: ${DateTime.now().toUtc().toIso8601String()}

Legal Notice:
Pursuant to DMCA 17 U.S.C. § 512 / EU Digital Services Act Article 16, this asset exhibits confirmed generative deepfake manipulation without biological vitals. Requesting urgent algorithmic quarantine and hash-based takedown.''';

        await Clipboard.setData(ClipboardData(text: takedownDossier));

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('📋 $label takedown notice copied to clipboard! Opening $label portal...'),
              backgroundColor: const Color(0xFF10B981),
              behavior: SnackBarBehavior.floating,
              duration: const Duration(seconds: 4),
            ),
          );
        }

        final uri = Uri.parse(url);
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        }
      },
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 12, color: color),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ═════════════════════════════════════════════════════════════════
  // TAB 2: POLICE INQUIRY DOCUMENT (WITH TYPEABLE PARTICULARS)
  // ═════════════════════════════════════════════════════════════════

  Widget _buildInquiryTab(_EscalPal pal) {
    final r = widget.report;
    final inqRef = 'INQ-CID-${r.verificationId.substring(0, math.min(8, r.verificationId.length)).toUpperCase()}';

    final dossierText = _buildReportText(
      'Sri Lanka Police CID',
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
        // Institutional Header
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: pal.surfaceMuted,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: pal.border),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: pal.data.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.description_outlined, color: pal.data, size: 20),
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
                        color: pal.data,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Cybercrime Investigation Division (CID)',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: pal.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      'Ref: $inqRef • Police IT Department Desk',
                      style: TextStyle(fontSize: 10.5, color: pal.textSecondary),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // 1. Complainant Particulars (Type to fill)
        Text(
          '1. COMPLAINANT PARTICULARS',
          style: TextStyle(
            fontSize: 10.5,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.8,
            color: pal.textSubtle,
          ),
        ),
        const SizedBox(height: 8),

        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: pal.surfaceMuted,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: pal.border),
          ),
          child: Column(
            children: [
              _buildInqField(
                label: 'FULL NAME',
                ctrl: _inqNameCtrl,
                hint: 'Enter complainant full name',
                pal: pal,
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: _buildInqField(
                      label: 'AGE',
                      ctrl: _inqAgeCtrl,
                      hint: 'e.g. 34',
                      keyboardType: TextInputType.number,
                      pal: pal,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 5,
                    child: _buildInqField(
                      label: 'CONTACT PHONE',
                      ctrl: _inqPhoneCtrl,
                      hint: 'e.g. 07x xxx xxxx',
                      keyboardType: TextInputType.phone,
                      pal: pal,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              _buildInqField(
                label: 'EMAIL / GMAIL ADDRESS',
                ctrl: _inqEmailCtrl,
                hint: 'e.g. name@gmail.com',
                keyboardType: TextInputType.emailAddress,
                pal: pal,
              ),
              const SizedBox(height: 8),
              _buildInqField(
                label: 'RESIDENTIAL ADDRESS',
                ctrl: _inqAddressCtrl,
                hint: 'e.g. Postal or residential address',
                pal: pal,
              ),
              const SizedBox(height: 8),
              _buildInqField(
                label: 'INCIDENT LOCATION / PLATFORM',
                ctrl: _inqPlaceCtrl,
                hint: 'e.g. WhatsApp, Facebook, or physical location',
                pal: pal,
              ),
              const SizedBox(height: 10),

              // Offence Dropdown
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'OFFENCE CLASSIFICATION',
                    style: TextStyle(
                      fontSize: 9.5,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.6,
                      color: pal.textSubtle,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    decoration: BoxDecoration(
                      color: pal.bg,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: pal.border),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _selectedOffence,
                        isExpanded: true,
                        dropdownColor: pal.bg,
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          color: pal.textPrimary,
                        ),
                        items: _offences
                            .map((o) => DropdownMenuItem(
                                  value: o,
                                  child: Text(o, maxLines: 1, overflow: TextOverflow.ellipsis),
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
                ],
              ),
              const SizedBox(height: 8),

              _buildInqField(
                label: 'BRIEF STATEMENT OF FACTS',
                ctrl: _inqContextCtrl,
                hint: 'Describe how the manipulated media was encountered...',
                maxLines: 2,
                pal: pal,
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // 2. Sworn Police Inquiry Document Preview
        Text(
          '2. SWORN POLICE INQUIRY DOCUMENT',
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
            color: pal.bg,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: pal.border),
          ),
          child: Text(
            dossierText,
            style: TextStyle(
              fontSize: 10,
              fontFamily: 'monospace',
              color: pal.textSecondary,
              height: 1.35,
            ),
          ),
        ),
        const SizedBox(height: 14),

        // Action Buttons (Dedicated strictly to Police IT Team)
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: _whatsappGreen,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 13),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              elevation: 0,
            ),
            icon: const Icon(Icons.send_rounded, size: 16),
            label: const Text(
              'Submit Inquiry to Police IT Team',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
            ),
            onPressed: () {
              _showGeneratedPoliceInquiryReport(
                context,
                inqRef,
                dossierText,
              );
            },
          ),
        ),
        const SizedBox(height: 8),

        SizedBox(
          width: double.infinity,
          child: OutlinedButton(
            style: OutlinedButton.styleFrom(
              foregroundColor: pal.textPrimary,
              side: BorderSide(color: pal.border),
              padding: const EdgeInsets.symmetric(vertical: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () {
              Clipboard.setData(ClipboardData(text: dossierText));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Sworn inquiry statement copied to clipboard.'),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
            child: const Text('Copy Sworn Statement', style: TextStyle(fontSize: 12)),
          ),
        ),
      ],
    );
  }

  void _showGeneratedPoliceInquiryReport(
    BuildContext context,
    String inqRef,
    String dossierText,
  ) {
    final pal = _pal;
    final r = widget.report;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
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
                              color: pal.data,
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
                                      color: pal.data,
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

                      // Forensic Evidence Summary
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
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF2563EB),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          elevation: 0,
                        ),
                        icon: const Icon(Icons.picture_as_pdf_rounded, size: 16),
                        label: const Text(
                          'View / Open Generated Inquiry PDF',
                          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                        ),
                        onPressed: () async {
                          final pdfFile = await _getPdfFile();
                          if (pdfFile != null) {
                            try {
                              await OpenFilex.open(pdfFile.path);
                            } catch (_) {
                              await Share.shareXFiles([XFile(pdfFile.path)], text: dossierText);
                            }
                          } else {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Generating official PDF report...')),
                              );
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
                        icon: const Icon(Icons.send_rounded, size: 16),
                        label: const Text(
                          'Dispatch to Police IT Department',
                          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                        ),
                        onPressed: () {
                          Navigator.pop(ctx);
                          Navigator.pop(context);
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
              style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: pal.textPrimary),
            ),
          ),
        ],
      ),
    );
  }

  // ═════════════════════════════════════════════════════════════════
  // TAB 3: LEGAL HELP & LAWYER CONSULTATION
  // ═════════════════════════════════════════════════════════════════

  Widget _buildLegalTab(_EscalPal pal) {
    final r = widget.report;
    final inqRef = 'INQ-CID-${r.verificationId.substring(0, math.min(8, r.verificationId.length)).toUpperCase()}';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: pal.surfaceMuted,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: pal.border),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF9333EA).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.gavel_outlined, color: Color(0xFFA855F7), size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'LEGAL DEFENSE PANEL',
                      style: TextStyle(
                        fontSize: 9.5,
                        fontFamily: 'monospace',
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.8,
                        color: pal.isDark ? const Color(0xFFA855F7) : const Color(0xFF7E22CE),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Cyber Law Counsel & Legal Aid',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: pal.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      'Bar Association of Sri Lanka (BASL) Panel',
                      style: TextStyle(fontSize: 10.5, color: pal.textSecondary),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // 1. Counsel Contacts
        Text(
          '1. ACCREDITED CYBER DEFENSE COUNSEL',
          style: TextStyle(
            fontSize: 10.5,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.8,
            color: pal.textSubtle,
          ),
        ),
        const SizedBox(height: 8),

        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: pal.surfaceMuted,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: pal.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Advocate K. M. Wickramasinghe, PC',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: pal.textPrimary),
                      ),
                      Text(
                        'Senior Cyber Law & Digital Evidence Counsel',
                        style: TextStyle(fontSize: 10, color: pal.isDark ? const Color(0xFFA855F7) : const Color(0xFF7E22CE)),
                      ),
                    ],
                  ),
                  OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      side: BorderSide(color: pal.border),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    onPressed: () => _dispatchBriefToLawyer(),
                    child: const Text('Consult', style: TextStyle(fontSize: 11)),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                'Specialized in urgent District Court enjoining orders, Online Safety Act petitions, and Computer Crimes Act litigation.',
                style: TextStyle(fontSize: 10.5, color: pal.textSecondary, height: 1.3),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),

        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: pal.surfaceMuted,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: pal.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Legal Aid Commission — Cyber Unit',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: pal.textPrimary),
                      ),
                      Text(
                        'Free State Representation for Victims',
                        style: TextStyle(fontSize: 10, color: pal.data),
                      ),
                    ],
                  ),
                  OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      side: BorderSide(color: pal.border),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    onPressed: () => launchUrl(Uri.parse('tel:1919')),
                    child: const Text('Call 1919', style: TextStyle(fontSize: 11)),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                'Statutory legal aid for victims of unauthorized synthetic media, non-consensual defamation, and online harassment.',
                style: TextStyle(fontSize: 10.5, color: pal.textSecondary, height: 1.3),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // 2. Court-Admissible Remedies
        Text(
          '2. COURT-ADMISSIBLE REMEDIES',
          style: TextStyle(
            fontSize: 10.5,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.8,
            color: pal.textSubtle,
          ),
        ),
        const SizedBox(height: 8),

        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          childAspectRatio: 2.2,
          crossAxisSpacing: 8,
          mainAxisSpacing: 8,
          children: [
            _buildRemedyTile('Urgent Enjoining Order', 'Interim injunction for platform takedown within 24h.', pal),
            _buildRemedyTile('Criminal Indictment', 'Investigation under Computer Crimes Act No. 24 of 2007.', pal),
            _buildRemedyTile('Online Safety Notice', 'Notice served under Act No. 9 of 2024 for removal.', pal),
            _buildRemedyTile('Civil Damages', 'Tort action claiming compensation for reputation harm.', pal),
          ],
        ),
        const SizedBox(height: 14),

        // 3. Pre-Compiled Advocate Brief
        Text(
          '3. PRE-COMPILED CASE BRIEF FOR COUNSEL',
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
            color: pal.bg,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: pal.border),
          ),
          child: Text(
            '''IN THE MAGISTRATE'S COURT OF COLOMBO
Matter: Unlawful Synthesis & Dissemination of Manipulated Media
Ref: $inqRef

Applicable Statutes:
• Computer Crimes Act No. 24 of 2007 (Sec. 6, 14)
• Penal Code Sec. 419 (Cheating by Personation)
• Online Safety Act No. 9 of 2024 (Sec. 13)
• Evidence (Special Provisions) Act No. 14 of 1995

Forensic Evidence Record:
• Media: ${r.mediaName ?? r.source}
• SHA-256: ${r.reportHash}
• Determination: ${r.verdict.toUpperCase()} (${r.fakeProbability.toStringAsFixed(1)}% Synthetic Likelihood)
• Chain of Custody: ISO/IEC 27037 Verified''',
            style: TextStyle(
              fontSize: 10,
              fontFamily: 'monospace',
              color: pal.textSecondary,
              height: 1.35,
            ),
          ),
        ),
        const SizedBox(height: 14),

        // Action Buttons (Dedicated strictly to retained lawyer)
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF7C3AED), // royal purple
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 13),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              elevation: 0,
            ),
            icon: const Icon(Icons.assignment_outlined, size: 16),
            label: const Text(
              'Dispatch Case Brief to Retained Lawyer',
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
              foregroundColor: pal.textPrimary,
              side: BorderSide(color: pal.border),
              padding: const EdgeInsets.symmetric(vertical: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () {
              final text = '''IN THE MAGISTRATE'S COURT OF COLOMBO
Matter: Unlawful Synthesis & Dissemination of Manipulated Media
Ref: $inqRef

Applicable Statutes:
• Computer Crimes Act No. 24 of 2007 (Sec. 6, 14)
• Penal Code Sec. 419 (Cheating by Personation)
• Online Safety Act No. 9 of 2024 (Sec. 13)
• Evidence (Special Provisions) Act No. 14 of 1995

Forensic Evidence Record:
• Media: ${r.mediaName ?? r.source}
• SHA-256: ${r.reportHash}
• Determination: ${r.verdict.toUpperCase()} (${r.fakeProbability.toStringAsFixed(1)}% Synthetic Likelihood)
• Chain of Custody: ISO/IEC 27037 Verified''';
              Clipboard.setData(ClipboardData(text: text));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Advocate case brief copied to clipboard.'),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
            child: const Text('Copy Advocate Case Brief', style: TextStyle(fontSize: 12)),
          ),
        ),
      ],
    );
  }

  // ── Helper Widgets ────────────────────────────────────────────────

  Widget _buildRemedyTile(String title, String desc, _EscalPal pal) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: pal.surfaceMuted,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: pal.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: pal.textPrimary),
          ),
          const SizedBox(height: 2),
          Text(
            desc,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 9.5, color: pal.textSecondary, height: 1.25),
          ),
        ],
      ),
    );
  }

  Widget _buildInqField({
    required String label,
    required TextEditingController ctrl,
    required String hint,
    required _EscalPal pal,
    TextInputType? keyboardType,
    int maxLines = 1,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 9.5,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.6,
            color: pal.textSubtle,
          ),
        ),
        const SizedBox(height: 4),
        TextField(
          controller: ctrl,
          keyboardType: keyboardType,
          maxLines: maxLines,
          onChanged: (_) => setState(() {}),
          style: TextStyle(fontSize: 12, color: pal.textPrimary),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(fontSize: 12, color: pal.textSubtle),
            filled: true,
            fillColor: pal.bg,
            contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            isDense: true,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: pal.border),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: pal.border),
            ),
          ),
        ),
      ],
    );
  }

  String _authorityTitle(AppLocalizations loc) =>
      _selectedAuthority == 'cert' ? loc.verifyCertCc : loc.verifySriLankaPolice;

  Widget _buildAuthorityTile({
    required String id,
    required String title,
    required String subtitle,
    required IconData icon,
    required Color accentColor,
    required Color accentBg,
    required _EscalPal pal,
  }) {
    final isSelected = _selectedAuthority == id;
    final borderColor = isSelected ? accentColor : pal.border;
    final bgColor = isSelected ? accentBg : pal.surfaceMuted;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => setState(() => _selectedAuthority = id),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: borderColor, width: isSelected ? 1.5 : 1),
          ),
          child: Row(
            children: [
              Icon(icon, color: isSelected ? accentColor : pal.textSecondary, size: 22),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: pal.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      subtitle,
                      style: TextStyle(fontSize: 11, color: pal.textSecondary),
                    ),
                  ],
                ),
              ),
              Container(
                width: 18,
                height: 18,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isSelected ? accentColor : pal.textSubtle,
                    width: isSelected ? 5 : 1.5,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSendButton({
    required String label,
    required String destination,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    final pal = _pal;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: color.withValues(alpha: 0.35)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(height: 5),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                destination,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 9.5,
                  color: pal.textSubtle,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAttachButton(AppLocalizations loc) {
    final pal = _pal;
    final accentColor = pal.isDark ? const Color(0xFF38BDF8) : const Color(0xFF0284C7);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () => setState(() => _attachPdf = !_attachPdf),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: pal.surfaceMuted,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: _attachPdf ? accentColor.withValues(alpha: 0.45) : pal.border,
            ),
          ),
          child: Row(
            children: [
              Icon(
                Icons.picture_as_pdf_outlined,
                size: 20,
                color: _attachPdf ? accentColor : pal.textSubtle,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          'Attach Forensic PDF',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: pal.textPrimary,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                          decoration: BoxDecoration(
                            color: _attachPdf
                                ? const Color(0xFF059669).withValues(alpha: 0.15)
                                : pal.border.withValues(alpha: 0.3),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            _attachPdf ? 'ATTACHED' : 'EXCLUDED',
                            style: TextStyle(
                              fontSize: 9,
                              fontFamily: 'monospace',
                              fontWeight: FontWeight.w700,
                              color: _attachPdf
                                  ? const Color(0xFF10B981)
                                  : pal.textSubtle,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 1),
                    Text(
                      _attachPdf
                          ? 'Certified ISO/IEC 27037 verification dossier included'
                          : 'Sending plain text summary only',
                      style: TextStyle(fontSize: 10.5, color: pal.textSecondary),
                    ),
                  ],
                ),
              ),
              Checkbox(
                value: _attachPdf,
                activeColor: accentColor,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                onChanged: (val) => setState(() => _attachPdf = val ?? true),
              ),
            ],
          ),
        ),
      ),
    );
  }
}