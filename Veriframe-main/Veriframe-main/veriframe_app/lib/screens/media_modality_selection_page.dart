import 'package:flutter/material.dart';
import 'package:veriframe_app/screens/image_page.dart';
import 'package:veriframe_app/screens/verify.dart';
import 'package:veriframe_app/widgets/home_top_bar.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  MediaModalitySelectionPage
//  Matches the user's original HTML design:
//    • Clean white page with gradient background
//    • Accordion cards: icon-box top-left, ▼ toggle top-right
//    • Expandable option buttons below each card (animated)
//    • Active card gets cyan border (#00A3CC), light-cyan tint, top accent line
//    • Real HomeTopBar app bar – no fake status bar
// ─────────────────────────────────────────────────────────────────────────────

class MediaModalitySelectionPage extends StatefulWidget {
  const MediaModalitySelectionPage({super.key, this.asModal = false});

  final bool asModal;

  /// Opens the page as a bottom-sheet modal.
  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.55),
      builder: (context) => const MediaModalitySelectionPage(asModal: true),
    );
  }

  @override
  State<MediaModalitySelectionPage> createState() =>
      _MediaModalitySelectionPageState();
}

class _MediaModalitySelectionPageState
    extends State<MediaModalitySelectionPage> {
  // Which card index is expanded: 0=Video, 1=Image, 2=Audio, null=none
  int? _expandedIndex;

  void _toggle(int index) {
    setState(() {
      _expandedIndex = (_expandedIndex == index) ? null : index;
    });
  }

  void _navigate(VoidCallback action) {
    if (widget.asModal) Navigator.pop(context);
    action();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (widget.asModal) {
      return _buildModalSheet(isDark);
    }

    // Full-page mode: use real HomeTopBar
    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0B1120) : const Color(0xFFF8F9FA),
      appBar: const HomeTopBar(showBack: true),
      body: _buildBody(isDark),
    );
  }

  // ── Modal Sheet wrapper ────────────────────────────────────────────────────
  Widget _buildModalSheet(bool isDark) {
    return DraggableScrollableSheet(
      initialChildSize: 0.88,
      minChildSize: 0.5,
      maxChildSize: 0.96,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF0F172A) : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.3),
                blurRadius: 24,
                offset: const Offset(0, -6),
              ),
            ],
          ),
          child: Column(
            children: [
              // Drag handle
              Padding(
                padding: const EdgeInsets.only(top: 10, bottom: 4),
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white24 : const Color(0xFFDDE3EC),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Expanded(child: _buildBody(isDark, scrollController: scrollController)),
            ],
          ),
        );
      },
    );
  }

  // ── Main scrollable body ───────────────────────────────────────────────────
  Widget _buildBody(bool isDark, {ScrollController? scrollController}) {
    final bg = isDark ? const Color(0xFF0B1120) : const Color(0xFFF8F9FA);

    return Container(
      color: bg,
      child: SingleChildScrollView(
        controller: scrollController,
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Page heading ─────────────────────────────────────────────
            Text(
              'Select Verification Type',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.5,
                color: isDark ? Colors.white : const Color(0xFF1A1A1A),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Choose what type of media you want to inspect for deepfakes and AI generation.',
              style: TextStyle(
                fontSize: 13.5,
                color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF666666),
                height: 1.5,
              ),
            ),
            const SizedBox(height: 24),

            // ── Card 0: Video ─────────────────────────────────────────────
            _AccordionCard(
              index: 0,
              expandedIndex: _expandedIndex,
              onToggle: _toggle,
              isDark: isDark,
              iconEmoji: '🎥',
              iconBgColor: const Color(0xFF00A3CC).withValues(alpha: 0.12),
              title: 'Video Verification',
              description:
                  'Analyze videos, YouTube links & live streams for authenticity',
              badgeText: 'VIDEO & STREAM',
              badgeColor: const Color(0xFF0077AA),
              badgeBg: const Color(0xFF00A3CC).withValues(alpha: 0.15),
              options: const ['Local Video', 'Video Link', 'Live Stream'],
              onOptionTap: (option) {
                if (option == 'Video Link') {
                  _navigate(() => Navigator.pushNamed(context, '/video_link'));
                } else if (option == 'Live Stream') {
                  _navigate(() => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const VerifyPage(initialStreamUrl: ''),
                        ),
                      ));
                } else {
                  _navigate(() => Navigator.pushNamed(context, '/analyze'));
                }
              },
            ),
            const SizedBox(height: 16),

            // ── Card 1: Image ─────────────────────────────────────────────
            _AccordionCard(
              index: 1,
              expandedIndex: _expandedIndex,
              onToggle: _toggle,
              isDark: isDark,
              iconEmoji: '🖼️',
              iconBgColor: const Color(0xFF22C55E).withValues(alpha: 0.12),
              title: 'Image Verification',
              description:
                  'Detect AI artifacts, face swaps, GAN images & deep fakes',
              badgeText: 'IMAGE & URL',
              badgeColor: const Color(0xFF166534),
              badgeBg: const Color(0xFF22C55E).withValues(alpha: 0.15),
              options: const ['Local Photo', 'Image Link'],
              onOptionTap: (option) {
                if (option == 'Image Link') {
                  _navigate(() => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const ImagePage(initialTab: 1),
                        ),
                      ));
                } else {
                  _navigate(() => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const ImagePage(initialTab: 0),
                        ),
                      ));
                }
              },
            ),
            const SizedBox(height: 16),

            // ── Card 2: Audio ─────────────────────────────────────────────
            _AccordionCard(
              index: 2,
              expandedIndex: _expandedIndex,
              onToggle: _toggle,
              isDark: isDark,
              iconEmoji: '🎙️',
              iconBgColor: const Color(0xFFF97316).withValues(alpha: 0.12),
              title: 'Audio Voice Verification',
              description:
                  'Detect voice cloning, synthetic speech & audio artifacts',
              badgeText: 'VOICE CLONE AI',
              badgeColor: const Color(0xFF92400E),
              badgeBg: const Color(0xFFF97316).withValues(alpha: 0.15),
              options: const ['Local Audio'],
              onOptionTap: (option) {
                _navigate(() => Navigator.pushNamed(context, '/audio'));
              },
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  _AccordionCard  –  matches the HTML .feature-card design exactly
// ─────────────────────────────────────────────────────────────────────────────
class _AccordionCard extends StatefulWidget {
  const _AccordionCard({
    required this.index,
    required this.expandedIndex,
    required this.onToggle,
    required this.isDark,
    required this.iconEmoji,
    required this.iconBgColor,
    required this.title,
    required this.description,
    required this.badgeText,
    required this.badgeColor,
    required this.badgeBg,
    required this.options,
    required this.onOptionTap,
  });

  final int index;
  final int? expandedIndex;
  final void Function(int) onToggle;
  final bool isDark;
  final String iconEmoji;
  final Color iconBgColor;
  final String title;
  final String description;
  final String badgeText;
  final Color badgeColor;
  final Color badgeBg;
  final List<String> options;
  final void Function(String) onOptionTap;

  @override
  State<_AccordionCard> createState() => _AccordionCardState();
}

class _AccordionCardState extends State<_AccordionCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _expandAnim;

  bool get _isExpanded => widget.expandedIndex == widget.index;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _expandAnim = CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut);
  }

  @override
  void didUpdateWidget(_AccordionCard old) {
    super.didUpdateWidget(old);
    if (_isExpanded) {
      _ctrl.forward();
    } else {
      _ctrl.reverse();
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cardBg = _isExpanded
        ? (widget.isDark
            ? const Color(0xFF0A1A2E)
            : const Color(0xFFF0F9FC))
        : (widget.isDark ? const Color(0xFF111827) : Colors.white);

    final cardBorder = _isExpanded
        ? const Color(0xFF00A3CC)
        : (widget.isDark ? const Color(0xFF1E293B) : const Color(0xFFE0E0E0));

    final titleColor =
        widget.isDark ? const Color(0xFFF1F5F9) : const Color(0xFF1A1A1A);
    final descColor =
        widget.isDark ? const Color(0xFF94A3B8) : const Color(0xFF666666);
    final dividerColor =
        widget.isDark ? const Color(0xFF1E293B) : const Color(0xFFE0E0E0);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cardBorder, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: widget.isDark ? 0.22 : 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Top accent line (cyan gradient, visible when active) ──────
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            height: _isExpanded ? 3.0 : 0.0,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF00A3CC), Colors.transparent],
              ),
            ),
          ),

          // ── Card header (always visible) ─────────────────────────────
          InkWell(
            onTap: () => widget.onToggle(widget.index),
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ── Icon box ────────────────────────────────────
                      Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          color: widget.iconBgColor,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Center(
                          child: Text(
                            widget.iconEmoji,
                            style: const TextStyle(fontSize: 28),
                          ),
                        ),
                      ),

                      const Spacer(),

                      // ── Toggle arrow ────────────────────────────────
                      AnimatedRotation(
                        turns: _isExpanded ? 0.5 : 0.0,
                        duration: const Duration(milliseconds: 300),
                        child: Icon(
                          Icons.arrow_drop_down_rounded,
                          size: 28,
                          color: _isExpanded
                              ? const Color(0xFF00A3CC)
                              : (widget.isDark
                                  ? const Color(0xFF94A3B8)
                                  : const Color(0xFF999999)),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // ── Title ────────────────────────────────────────────
                  Text(
                    widget.title,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.3,
                      color: titleColor,
                    ),
                  ),
                  const SizedBox(height: 6),

                  // ── Description ──────────────────────────────────────
                  Text(
                    widget.description,
                    style: TextStyle(
                      fontSize: 13,
                      color: descColor,
                      height: 1.6,
                    ),
                  ),
                  const SizedBox(height: 12),

                  // ── Category badge ───────────────────────────────────
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: widget.badgeBg,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      widget.badgeText,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.4,
                        color: widget.badgeColor,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── Expandable options section ────────────────────────────────
          SizeTransition(
            sizeFactor: _expandAnim,
            child: Column(
              children: [
                Divider(height: 1, color: dividerColor),
                Padding(
                  padding:
                      const EdgeInsets.fromLTRB(24, 16, 24, 20),
                  child: Row(
                    children: widget.options.map((opt) {
                      return Expanded(
                        child: Padding(
                          padding: EdgeInsets.only(
                            right: opt != widget.options.last ? 8 : 0,
                          ),
                          child: _OptionButton(
                            label: opt,
                            isDark: widget.isDark,
                            onTap: () => widget.onOptionTap(opt),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  _OptionButton  –  the pill buttons inside each expanded card
// ─────────────────────────────────────────────────────────────────────────────
class _OptionButton extends StatelessWidget {
  const _OptionButton({
    required this.label,
    required this.isDark,
    required this.onTap,
  });

  final String label;
  final bool isDark;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: isDark ? const Color(0xFF0F172A) : Colors.white,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        splashColor: const Color(0xFF00A3CC).withValues(alpha: 0.15),
        highlightColor: const Color(0xFFF0F9FC),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE0E0E0),
              width: 1.5,
            ),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.2,
              color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF666666),
            ),
          ),
        ),
      ),
    );
  }
}
