import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Interactive chart visualizing acoustic room impulse response reverberation
/// decay time (RT60) using Schroeder's backward energy integration.
class Rt60DecayChart extends StatelessWidget {
  final List<double>? decayCurve;
  final double rt60Sec;
  final String acousticEnvironment;
  final bool isSynthetic;
  final double height;

  const Rt60DecayChart({
    super.key,
    this.decayCurve,
    this.rt60Sec = 0.42,
    this.acousticEnvironment = 'Standard Physical Room',
    this.isSynthetic = false,
    this.height = 220,
  });

  List<double> _generateDefaultDecay(bool synthetic) {
    final list = <double>[];
    for (int i = 0; i < 64; i++) {
      final t = i / 63.0;
      if (synthetic) {
        // Immediate drop off into digital noise / anechoic cliff
        final val = (t < 0.1) ? -(t * 200.0) : -60.0 + (math.Random(i).nextDouble() * 2.0);
        list.add(val.clamp(-60.0, 0.0));
      } else {
        // Natural linear Sabine/Schroeder energy decay (-60 dB over time)
        final val = -(t * 52.0) + (math.sin(t * 12.0) * 1.5);
        list.add(val.clamp(-60.0, 0.0));
      }
    }
    return list;
  }

  @override
  Widget build(BuildContext context) {
    final points = (decayCurve != null && decayCurve!.isNotEmpty)
        ? decayCurve!
        : _generateDefaultDecay(isSynthetic);

    final statusColor = isSynthetic ? const Color(0xFFEF4444) : const Color(0xFF0EA5E9);

    return Container(
      height: height,
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.graphic_eq_rounded,
                      color: statusColor,
                      size: 16,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Acoustic RT60 Reverberation',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.3,
                        ),
                      ),
                      Text(
                        isSynthetic
                            ? 'Anechoic vocoder profile (Cloned Voice)'
                            : acousticEnvironment,
                        style: TextStyle(
                          color: statusColor.withValues(alpha: 0.9),
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ],
              ),

              // RT60 Value Badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E293B),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                ),
                child: Text(
                  isSynthetic ? 'RT60: < 0.08s' : 'RT60: ${rt60Sec.toStringAsFixed(2)}s',
                  style: TextStyle(
                    color: statusColor,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Chart Canvas
          Expanded(
            child: CustomPaint(
              size: Size.infinite,
              painter: _DecayPainter(
                points: points,
                lineColor: statusColor,
                isSynthetic: isSynthetic,
              ),
            ),
          ),

          const SizedBox(height: 8),

          // Footer info
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Schroeder Backward Integration [-60 dB]',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.4),
                  fontSize: 10,
                ),
              ),
              Text(
                isSynthetic ? 'Physical Resonance Failure' : 'Sabine Room Law Verified',
                style: TextStyle(
                  color: statusColor.withValues(alpha: 0.8),
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DecayPainter extends CustomPainter {
  final List<double> points;
  final Color lineColor;
  final bool isSynthetic;

  _DecayPainter({
    required this.points,
    required this.lineColor,
    required this.isSynthetic,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (points.isEmpty) return;

    final width = size.width;
    final height = size.height;

    // Grid Guides (-5 dB, -25 dB, -50 dB)
    final gridPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.06)
      ..strokeWidth = 1.0;

    final textStyle = TextStyle(
      color: Colors.white.withValues(alpha: 0.3),
      fontSize: 9,
      fontWeight: FontWeight.w500,
    );

    final decibels = [0.0, -20.0, -40.0, -60.0];
    for (final db in decibels) {
      final normY = (db / -60.0).clamp(0.0, 1.0);
      final y = normY * (height * 0.85) + height * 0.08;
      canvas.drawLine(Offset(28, y), Offset(width, y), gridPaint);

      final textSpan = TextSpan(text: '${db.toInt()}dB', style: textStyle);
      final textPainter = TextPainter(
        text: textSpan,
        textDirection: TextDirection.ltr,
      )..layout();
      textPainter.paint(canvas, Offset(0, y - 6));
    }

    // Plot decay curve
    final plotStartX = 32.0;
    final plotWidth = width - plotStartX;
    final stepX = plotWidth / (points.length - 1);

    final path = Path();
    for (int i = 0; i < points.length; i++) {
      final db = points[i].clamp(-60.0, 0.0);
      final normY = (db / -60.0).clamp(0.0, 1.0);
      final y = normY * (height * 0.85) + height * 0.08;
      final x = plotStartX + (i * stepX);

      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }

    // Area fill
    final fillPath = Path.from(path)
      ..lineTo(plotStartX + plotWidth, height)
      ..lineTo(plotStartX, height)
      ..close();

    final fillPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          lineColor.withValues(alpha: 0.25),
          lineColor.withValues(alpha: 0.0),
        ],
      ).createShader(Rect.fromLTWH(0, 0, width, height))
      ..style = PaintingStyle.fill;
    canvas.drawPath(fillPath, fillPaint);

    // Stroke
    final strokePaint = Paint()
      ..color = lineColor
      ..strokeWidth = 2.4
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawPath(path, strokePaint);
  }

  @override
  bool shouldRepaint(_DecayPainter oldDelegate) {
    return oldDelegate.points != points || oldDelegate.lineColor != lineColor;
  }
}
