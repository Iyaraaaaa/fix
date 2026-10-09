import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:open_filex/open_filex.dart';
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';

class PdfViewerScreen extends StatelessWidget {
  final File? file;
  final Uint8List? bytes;
  final Future<Uint8List> Function()? onBuild;
  final String title;
  final String? subtitle;
  final String fileName;

  const PdfViewerScreen({
    super.key,
    this.file,
    this.bytes,
    this.onBuild,
    this.title = 'Forensic Inquiry Report',
    this.subtitle,
    this.fileName = 'Inquiry_Report.pdf',
  }) : assert(file != null || bytes != null || onBuild != null,
            'Must provide either file, bytes, or onBuild callback');

  Future<Uint8List> _loadBytes() async {
    if (bytes != null) return bytes!;
    if (file != null) return await file!.readAsBytes();
    if (onBuild != null) return await onBuild!();
    throw Exception('No PDF data provided');
  }

  Future<void> _openExternal(BuildContext context) async {
    try {
      String? path = file?.path;
      if (path == null) {
        final b = await _loadBytes();
        final tempDir = Directory.systemTemp;
        final tempFile = File('${tempDir.path}/$fileName');
        await tempFile.writeAsBytes(b, flush: true);
        path = tempFile.path;
      }
      final res = await OpenFilex.open(path, type: 'application/pdf');
      if (res.type != ResultType.done && context.mounted) {
        // Fallback to sharing if external viewer cannot open
        await Share.shareXFiles(
          [XFile(path, mimeType: 'application/pdf', name: fileName)],
          subject: title,
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not open external app: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  Future<void> _sharePdf(BuildContext context) async {
    try {
      String? path = file?.path;
      if (path == null) {
        final b = await _loadBytes();
        final tempDir = Directory.systemTemp;
        final tempFile = File('${tempDir.path}/$fileName');
        await tempFile.writeAsBytes(b, flush: true);
        path = tempFile.path;
      }
      await Share.shareXFiles(
        [XFile(path, mimeType: 'application/pdf', name: fileName)],
        subject: title,
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to share PDF: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryBlue = const Color(0xFF1976D2);
    final bgColor = isDark ? const Color(0xFF0D1117) : const Color(0xFFF8FAFC);
    final barBg = isDark ? const Color(0xFF161B22) : Colors.white;
    final textColor = isDark ? Colors.white : const Color(0xFF0F172A);

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: barBg,
        elevation: 0.5,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded, color: textColor),
          onPressed: () => Navigator.of(context).pop(),
        ),
        titleSpacing: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: TextStyle(
                color: textColor,
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
            if (subtitle != null)
              Text(
                subtitle!,
                style: const TextStyle(
                  color: Color(0xFF1976D2),
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Open in External PDF Reader',
            icon: Icon(Icons.open_in_new_rounded, color: textColor, size: 20),
            onPressed: () => _openExternal(context),
          ),
          IconButton(
            tooltip: 'Share PDF Report',
            icon: Icon(Icons.share_rounded, color: textColor, size: 20),
            onPressed: () => _sharePdf(context),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: SafeArea(
        child: PdfPreview(
          build: (format) => _loadBytes(),
          pdfFileName: fileName,
          allowPrinting: true,
          allowSharing: true,
          canChangeOrientation: false,
          canChangePageFormat: false,
          canDebug: false,
          dynamicLayout: false,
          loadingWidget: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(strokeWidth: 2.5, color: primaryBlue),
                const SizedBox(height: 12),
                Text(
                  'Rendering Inquiry PDF...',
                  style: TextStyle(
                    color: textColor.withValues(alpha: 0.7),
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          onError: (context, error) => Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.error_outline_rounded, color: Colors.redAccent, size: 48),
                  const SizedBox(height: 12),
                  Text(
                    'Failed to display PDF: $error',
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 13, color: Colors.redAccent),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(backgroundColor: primaryBlue),
                    icon: const Icon(Icons.share_rounded, size: 16, color: Colors.white),
                    label: const Text('Share File Directly', style: TextStyle(color: Colors.white)),
                    onPressed: () => _sharePdf(context),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
