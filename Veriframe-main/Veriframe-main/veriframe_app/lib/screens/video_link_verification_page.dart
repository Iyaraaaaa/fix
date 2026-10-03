import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:veriframe_app/screens/download_analysis_page.dart';
import 'package:veriframe_app/widgets/main_scaffold.dart';

class VideoLinkVerificationPage extends StatefulWidget {
  const VideoLinkVerificationPage({super.key});

  @override
  State<VideoLinkVerificationPage> createState() =>
      _VideoLinkVerificationPageState();
}

class _VideoLinkVerificationPageState extends State<VideoLinkVerificationPage> {
  String selectedPlatform = 'YouTube';
  final TextEditingController linkController = TextEditingController();

  @override
  void initState() {
    super.initState();
    linkController.addListener(() {
      setState(() {});
    });
  }

  @override
  void dispose() {
    linkController.dispose();
    super.dispose();
  }

  void _selectPlatform(String platform) {
    setState(() {
      selectedPlatform = platform;
    });
  }

  Future<void> _pasteFromClipboard() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    if (data?.text != null && data!.text!.trim().isNotEmpty) {
      linkController.text = data.text!.trim();
    }
  }

  void _submitLink() {
    final url = linkController.text.trim();
    if (url.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Please paste a $selectedPlatform link first.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => DownloadAnalysisPage(videoUrl: url),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? const Color(0xFF131D2E) : Colors.white;
    final borderColor = isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0);
    final titleColor = isDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A);
    final subtitleColor = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

    return MainScaffold(
      backgroundColor: isDark ? const Color(0xFF0B1424) : const Color(0xFFF8FAFC),
      showBack: true,
      title: const Text(
        'Link Verification',
        style: TextStyle(fontWeight: FontWeight.w800, letterSpacing: -0.5),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: Container(
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: borderColor, width: 1.1),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.04),
                    blurRadius: 14,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Title & Subtitle Header - Compact & Sleek
                  Center(
                    child: Column(
                      children: [
                        Text(
                          'Select Platform',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                            color: titleColor,
                            letterSpacing: -0.3,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Choose where your video is hosted',
                          style: TextStyle(
                            fontSize: 12,
                            color: subtitleColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Horizontal 3-Platform Selector Row (Instagram removed)
                  Row(
                    children: [
                      Expanded(
                        child: _buildPlatformCard(
                          name: 'YouTube',
                          brandColor: const Color(0xFFFF0000),
                          isDark: isDark,
                          customIconWidget: Container(
                            width: 30,
                            height: 30,
                            decoration: BoxDecoration(
                              color: const Color(0xFFFF0000),
                              borderRadius: BorderRadius.circular(9),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFFFF0000).withValues(alpha: 0.28),
                                  blurRadius: 6,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.play_arrow_rounded,
                              color: Colors.white,
                              size: 20,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildPlatformCard(
                          name: 'Facebook',
                          brandColor: const Color(0xFF1877F2),
                          isDark: isDark,
                          customIconWidget: Container(
                            width: 30,
                            height: 30,
                            decoration: BoxDecoration(
                              color: const Color(0xFF1877F2),
                              borderRadius: BorderRadius.circular(9),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFF1877F2).withValues(alpha: 0.28),
                                  blurRadius: 6,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: const Center(
                              child: Text(
                                'f',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w900,
                                  fontFamily: 'sans-serif',
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildPlatformCard(
                          name: 'TikTok',
                          brandColor: isDark ? const Color(0xFFE2E8F0) : const Color(0xFF0F172A),
                          isDark: isDark,
                          customIconWidget: Container(
                            width: 30,
                            height: 30,
                            decoration: BoxDecoration(
                              color: Colors.black,
                              borderRadius: BorderRadius.circular(9),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.28),
                                  blurRadius: 6,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Stack(
                              alignment: Alignment.center,
                              children: const [
                                Positioned(
                                  left: 7.5,
                                  top: 6.5,
                                  child: Icon(
                                    Icons.music_note_rounded,
                                    color: Color(0xFF00F2FE),
                                    size: 16,
                                  ),
                                ),
                                Positioned(
                                  right: 7.5,
                                  bottom: 6.5,
                                  child: Icon(
                                    Icons.music_note_rounded,
                                    color: Color(0xFFFE2C55),
                                    size: 16,
                                  ),
                                ),
                                Icon(
                                  Icons.music_note_rounded,
                                  color: Colors.white,
                                  size: 16,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // VIDEO LINK Label with Quick Action
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'VIDEO LINK',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: subtitleColor,
                          letterSpacing: 0.5,
                        ),
                      ),
                      if (linkController.text.isNotEmpty)
                        GestureDetector(
                          onTap: () => linkController.clear(),
                          child: Text(
                            'Clear',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: subtitleColor,
                            ),
                          ),
                        )
                      else
                        GestureDetector(
                          onTap: _pasteFromClipboard,
                          child: const Text(
                            'Paste',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF8B5CF6),
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 6),

                  // Compact Link TextField
                  Container(
                    height: 44,
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF0F172A) : Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: borderColor,
                        width: 1.1,
                      ),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    child: Row(
                      children: [
                        Container(
                          width: 26,
                          height: 26,
                          decoration: BoxDecoration(
                            color: const Color(0xFF8B5CF6).withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(7),
                          ),
                          child: const Icon(
                            Icons.link_rounded,
                            color: Color(0xFF8B5CF6),
                            size: 16,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextField(
                            controller: linkController,
                            style: TextStyle(
                              fontSize: 13,
                              color: titleColor,
                              fontWeight: FontWeight.w500,
                            ),
                            decoration: InputDecoration(
                              border: InputBorder.none,
                              isDense: true,
                              contentPadding: EdgeInsets.zero,
                              hintText: 'Paste your $selectedPlatform link here...',
                              hintStyle: const TextStyle(
                                color: Color(0xFF94A3B8),
                                fontSize: 13,
                                fontWeight: FontWeight.w400,
                              ),
                            ),
                            onSubmitted: (_) => _submitLink(),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),

                  // VERIFY NOW Button (Compact, Emerald Green with Shield)
                  SizedBox(
                    height: 44,
                    child: ElevatedButton(
                      onPressed: _submitLink,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF10B981),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: EdgeInsets.zero,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(3.5),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.white.withValues(alpha: 0.2),
                            ),
                            child: const Icon(
                              Icons.shield_rounded,
                              color: Color(0xFF38BDF8),
                              size: 14,
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Text(
                            'VERIFY NOW',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.5,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPlatformCard({
    required String name,
    required Color brandColor,
    required bool isDark,
    required Widget customIconWidget,
  }) {
    final isSelected = selectedPlatform == name;
    final cardBg = isDark
        ? (isSelected ? const Color(0xFF1E293B) : const Color(0xFF111C2E))
        : (isSelected ? const Color(0xFFF1F5F9) : const Color(0xFFFAFAFA));

    final activeBorderColor = name == 'YouTube'
        ? const Color(0xFFFF0000)
        : (name == 'Facebook'
            ? const Color(0xFF1877F2)
            : (isDark ? Colors.white : const Color(0xFF0F172A)));

    final cardBorder = isSelected
        ? activeBorderColor
        : (isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0));

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _selectPlatform(name),
        borderRadius: BorderRadius.circular(14),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: cardBorder,
              width: isSelected ? 1.6 : 1.0,
            ),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: activeBorderColor.withValues(alpha: 0.12),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              customIconWidget,
              const SizedBox(height: 6),
              Text(
                name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                  color: isSelected
                      ? (isDark ? Colors.white : const Color(0xFF0F172A))
                      : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569)),
                  letterSpacing: -0.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
