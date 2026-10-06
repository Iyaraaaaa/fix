import 'dart:typed_data';
import 'package:flutter/material.dart';

/// Interactive draggable comparison slider between an original media frame
/// and its forensic heatmap / reconstructed structural geometry.
class ForensicSplitSlider extends StatefulWidget {
  final ImageProvider originalImage;
  final ImageProvider comparisonImage;
  final String originalLabel;
  final String comparisonLabel;
  final double initialPosition;
  final double height;
  final BorderRadius? borderRadius;

  const ForensicSplitSlider({
    super.key,
    required this.originalImage,
    required this.comparisonImage,
    this.originalLabel = 'ORIGINAL',
    this.comparisonLabel = 'FORENSIC HEATMAP',
    this.initialPosition = 0.5,
    this.height = 320,
    this.borderRadius,
  });

  /// Factory helper to build from raw byte buffers (e.g. from backend response)
  factory ForensicSplitSlider.fromBytes({
    Key? key,
    required Uint8List originalBytes,
    required Uint8List comparisonBytes,
    String originalLabel = 'ORIGINAL',
    String comparisonLabel = 'RESIDUAL MAP',
    double initialPosition = 0.5,
    double height = 320,
    BorderRadius? borderRadius,
  }) {
    return ForensicSplitSlider(
      key: key,
      originalImage: MemoryImage(originalBytes),
      comparisonImage: MemoryImage(comparisonBytes),
      originalLabel: originalLabel,
      comparisonLabel: comparisonLabel,
      initialPosition: initialPosition,
      height: height,
      borderRadius: borderRadius,
    );
  }

  @override
  State<ForensicSplitSlider> createState() => _ForensicSplitSliderState();
}

class _ForensicSplitSliderState extends State<ForensicSplitSlider> {
  late double _position;

  @override
  void initState() {
    super.initState();
    _position = widget.initialPosition.clamp(0.05, 0.95);
  }

  void _updatePosition(double localDx, double width) {
    if (width <= 0) return;
    setState(() {
      _position = (localDx / width).clamp(0.02, 0.98);
    });
  }

  @override
  Widget build(BuildContext context) {
    final br = widget.borderRadius ?? BorderRadius.circular(16);

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final dividerX = width * _position;

        return ClipRRect(
          borderRadius: br,
          child: Container(
            height: widget.height,
            width: width,
            color: const Color(0xFF0F172A),
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onHorizontalDragUpdate: (details) =>
                  _updatePosition(details.localPosition.dx, width),
              onTapDown: (details) =>
                  _updatePosition(details.localPosition.dx, width),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // 1. Bottom Layer (Comparison / Forensic Heatmap)
                  Image(
                    image: widget.comparisonImage,
                    fit: BoxFit.cover,
                  ),

                  // 2. Top Layer (Original Frame, clipped to left of divider)
                  ClipRect(
                    clipper: _HorizontalSplitClipper(dividerX),
                    child: Image(
                      image: widget.originalImage,
                      fit: BoxFit.cover,
                    ),
                  ),

                  // 3. Subtle Badges at top corners
                  Positioned(
                    top: 12,
                    left: 12,
                    child: _buildBadge(widget.originalLabel, const Color(0xFF10B981)),
                  ),
                  Positioned(
                    top: 12,
                    right: 12,
                    child: _buildBadge(widget.comparisonLabel, const Color(0xFFEF4444)),
                  ),

                  // 4. Vertical Divider Line
                  Positioned(
                    left: dividerX - 1.5,
                    top: 0,
                    bottom: 0,
                    child: Container(
                      width: 3,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.5),
                            blurRadius: 6,
                            spreadRadius: 1,
                          ),
                        ],
                      ),
                    ),
                  ),

                  // 5. Draggable Grip Handle in Center of Divider
                  Positioned(
                    left: dividerX - 18,
                    top: (widget.height / 2) - 18,
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.6),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                        border: Border.all(color: const Color(0xFF0284C7), width: 2),
                      ),
                      child: const Center(
                        child: Icon(
                          Icons.drag_indicator,
                          size: 20,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                    ),
                  ),

                  // 6. Instructional bottom banner
                  Positioned(
                    bottom: 8,
                    left: 0,
                    right: 0,
                    child: Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.6),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Text(
                          '< Drag to inspect forensic boundary >',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.4,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildBadge(String label, Color dotColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.75),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(
              color: dotColor,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _HorizontalSplitClipper extends CustomClipper<Rect> {
  final double splitX;
  _HorizontalSplitClipper(this.splitX);

  @override
  Rect getClip(Size size) {
    return Rect.fromLTWH(0, 0, splitX, size.height);
  }

  @override
  bool shouldReclip(_HorizontalSplitClipper oldClipper) {
    return oldClipper.splitX != splitX;
  }
}
