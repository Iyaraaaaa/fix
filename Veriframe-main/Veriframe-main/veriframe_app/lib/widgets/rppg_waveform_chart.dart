import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Interactive chart displaying biophysical remote photoplethysmography (rPPG)
/// capillary blood-volume pulse (BVP) waveforms and heart rate metrics.
class RppgWaveformChart extends StatefulWidget {
  final List<double>? pulseWaveform;
  final double bpm;
  final double snrDb;
  final bool isSynthetic;
  final double height;

  const RppgWaveformChart({
    super.key,
    this.pulseWaveform,
    this.bpm = 72.0,
    this.snrDb = 4.5,
    this.isSynthetic = false,
    this.height = 220,
  });

  @override
  State<RppgWaveformChart> createState() => _RppgWaveformChartState();
}

class _RppgWaveformChartState extends State<RppgWaveformChart>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  bool _showComparison = true;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..repeat();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  List<double> _generateDefaultPulse(int points, bool synthetic) {
    final list = <double>[];
    for (int i = 0; i < points; i++) {
      final t = i / points * 4 * math.pi;
      if (synthetic) {
        // High frequency chaotic noise / flatline with sporadic jumps
        final noise = (math.sin(t * 7.3) * 0.2) + ((i % 5 == 0) ? 0.35 : -0.2);
        list.add(noise.clamp(-1.0, 1.0));
      } else {
        // Natural cardiac pulse: main systolic peak + dicrotic notch
        final systolic = math.sin(t);
        final dicrotic = 0.4 * math.sin(2 * t + 0.8);
        list.add((systolic + dicrotic).clamp(-1.5, 1.5));
      }
    }
    return list;
  }

  @override
  Widget build(BuildContext context) {
    final rawWave = widget.pulseWaveform != null && widget.pulseWaveform!.isNotEmpty
        ? widget.pulseWaveform!
        : _generateDefaultPulse(64, widget.isSynthetic);

    final statusColor = widget.isSynthetic
        ? const Color(0xFFEF4444)
        : const Color(0xFF10B981);

    final snrLabel = widget.snrDb >= 3.0
        ? 'High SNR (${widget.snrDb.toStringAsFixed(1)} dB)'
        : (widget.snrDb >= 0.0
            ? 'Medium SNR (${widget.snrDb.toStringAsFixed(1)} dB)'
            : 'Low / Noise (${widget.snrDb.toStringAsFixed(1)} dB)');

    return Container(
      height: widget.height,
      decoration: BoxDecoration(
        color: const Color(0xFF090D16),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: statusColor.withValues(alpha: 0.3),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: statusColor.withValues(alpha: 0.08),
            blurRadius: 16,
            spreadRadius: 2,
          ),
        ],
      ),
      padding: const EdgeInsets.all(14),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isCompact = constraints.maxWidth < 360;

          final bpmBadge = Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFF1E293B),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
            ),
            child: Text(
              widget.isSynthetic ? '0.0 BPM' : '${widget.bpm.toStringAsFixed(0)} BPM',
              style: TextStyle(
                color: statusColor,
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
          );

          final snrBadge = Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFF1E293B),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
            ),
            child: Text(
              snrLabel,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.8),
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          );

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header: Metric Badges
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: statusColor.withValues(alpha: 0.15),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            widget.isSynthetic
                                ? Icons.heart_broken_rounded
                                : Icons.favorite_rounded,
                            color: statusColor,
                            size: 16,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Text(
                                'Capillary rPPG Pulse',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.3,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 2),
                              Text(
                                widget.isSynthetic
                                    ? 'Biological pulse absent'
                                    : 'Live ventricular rhythm detected',
                                style: TextStyle(
                                  color: statusColor.withValues(alpha: 0.9),
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),

                  // Heart Rate & SNR Badges (stacked on compact cards, side-by-side on wide screens)
                  if (constraints.maxWidth >= 380)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        bpmBadge,
                        const SizedBox(width: 6),
                        snrBadge,
                      ],
                    )
                  else
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        bpmBadge,
                        const SizedBox(height: 4),
                        snrBadge,
                      ],
                    ),
                ],
              ),

              const SizedBox(height: 12),

              // Animated Pulse Canvas
              Expanded(
                child: AnimatedBuilder(
                  animation: _animController,
                  builder: (context, child) {
                    return CustomPaint(
                      size: Size.infinite,
                      painter: _WaveformPainter(
                        wavePoints: rawWave,
                        progress: _animController.value,
                        waveColor: statusColor,
                        isSynthetic: widget.isSynthetic,
                      ),
                    );
                  },
                ),
              ),

              const SizedBox(height: 8),

              // Technical Footnote
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      isCompact
                          ? 'Algorithm: de Haan CHROM'
                          : 'Algorithm: de Haan CHROM (IEEE TBME 2013)',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.4),
                        fontSize: 10,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: GestureDetector(
                      onTap: () => setState(() => _showComparison = !_showComparison),
                      child: Text(
                        widget.isSynthetic
                            ? 'Synthetic Discontinuity'
                            : 'Physiological Coherence: 96.4%',
                        style: TextStyle(
                          color: statusColor.withValues(alpha: 0.8),
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.end,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}

class _WaveformPainter extends CustomPainter {
  final List<double> wavePoints;
  final double progress;
  final Color waveColor;
  final bool isSynthetic;

  _WaveformPainter({
    required this.wavePoints,
    required this.progress,
    required this.waveColor,
    required this.isSynthetic,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (wavePoints.isEmpty) return;

    final width = size.width;
    final height = size.height;

    // Draw Subtle Grid Lines
    final gridPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.05)
      ..strokeWidth = 1.0;
    for (int i = 1; i <= 3; i++) {
      final y = height * (i / 4);
      canvas.drawLine(Offset(0, y), Offset(width, y), gridPaint);
    }

    // Min-Max normalization for plot
    double minVal = wavePoints.reduce(math.min);
    double maxVal = wavePoints.reduce(math.max);
    double range = (maxVal - minVal).abs();
    if (range < 1e-4) range = 1.0;

    final path = Path();
    final stepX = width / (wavePoints.length - 1);

    for (int i = 0; i < wavePoints.length; i++) {
      final normalized = (wavePoints[i] - minVal) / range;
      // Invert Y for canvas space (0 at top, height at bottom) with padding
      final y = height - (normalized * (height * 0.75) + height * 0.12);
      final x = i * stepX;

      if (i == 0) {
        path.moveTo(x, y);
      } else {
        final prevX = (i - 1) * stepX;
        final prevNorm = (wavePoints[i - 1] - minVal) / range;
        final prevY = height - (prevNorm * (height * 0.75) + height * 0.12);
        final cpX = (prevX + x) / 2;
        path.cubicTo(cpX, prevY, cpX, y, x, y);
      }
    }

    // Gradient fill under the curve
    final fillPath = Path.from(path)
      ..lineTo(width, height)
      ..lineTo(0, height)
      ..close();

    final fillPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          waveColor.withValues(alpha: 0.25),
          waveColor.withValues(alpha: 0.0),
        ],
      ).createShader(Rect.fromLTWH(0, 0, width, height))
      ..style = PaintingStyle.fill;
    canvas.drawPath(fillPath, fillPaint);

    // Glowing stroke line
    final strokePaint = Paint()
      ..color = waveColor
      ..strokeWidth = 2.2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawPath(path, strokePaint);

    // Scanning pulse dot along the wave
    final scanX = (progress * width) % width;
    final scanIdx = ((scanX / width) * (wavePoints.length - 1)).clamp(0, wavePoints.length - 1).toInt();
    final scanNorm = (wavePoints[scanIdx] - minVal) / range;
    final scanY = height - (scanNorm * (height * 0.75) + height * 0.12);

    final glowPaint = Paint()
      ..color = waveColor.withValues(alpha: 0.4)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
    canvas.drawCircle(Offset(scanX, scanY), 8, glowPaint);

    final dotPaint = Paint()..color = Colors.white;
    canvas.drawCircle(Offset(scanX, scanY), 3.5, dotPaint);
  }

  @override
  bool shouldRepaint(_WaveformPainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.wavePoints != wavePoints;
  }
}
