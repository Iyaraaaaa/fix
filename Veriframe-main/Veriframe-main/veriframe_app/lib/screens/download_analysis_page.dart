import 'dart:async';
import 'package:flutter/material.dart';

enum TimelineStatus { completed, active, pending }

class TimelineStep {
  final String label;
  final String time;
  final TimelineStatus status;

  const TimelineStep({
    required this.label,
    required this.time,
    required this.status,
  });
}

class DownloadAnalysisPage extends StatefulWidget {
  const DownloadAnalysisPage({super.key});

  @override
  State<DownloadAnalysisPage> createState() => _DownloadAnalysisPageState();
}

class _DownloadAnalysisPageState extends State<DownloadAnalysisPage>
    with SingleTickerProviderStateMixin {
  int currentProgress = 40;
  int currentStage = 2; // 0-indexed (Stage 3 of 9)
  late AnimationController _pulseController;
  Timer? _simulationTimer;

  final List<TimelineStep> steps = const [
    TimelineStep(
      label: 'Validating URL',
      time: '2.3s',
      status: TimelineStatus.completed,
    ),
    TimelineStep(
      label: 'Detecting Platform',
      time: '1.8s',
      status: TimelineStatus.completed,
    ),
    TimelineStep(
      label: 'Downloading Video',
      time: '4.2s...',
      status: TimelineStatus.active,
    ),
    TimelineStep(
      label: 'Extracting Frames',
      time: '--',
      status: TimelineStatus.pending,
    ),
    TimelineStep(
      label: 'Detecting Faces',
      time: '--',
      status: TimelineStatus.pending,
    ),
    TimelineStep(
      label: 'Running AI Analysis',
      time: '--',
      status: TimelineStatus.pending,
    ),
    TimelineStep(
      label: 'Generating Report',
      time: '--',
      status: TimelineStatus.pending,
    ),
    TimelineStep(
      label: 'Verification Complete',
      time: '--',
      status: TimelineStatus.pending,
    ),
  ];

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    )..repeat(reverse: true);

    _startProgressSimulation();
  }

  void _startProgressSimulation() {
    _simulationTimer = Timer.periodic(const Duration(seconds: 2), (timer) {
      if (mounted) {
        setState(() {
          if (currentProgress < 100) {
            currentProgress += 5;
          } else {
            timer.cancel();
          }
        });
      }
    });
  }

  @override
  void dispose() {
    _simulationTimer?.cancel();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? const Color(0xFF131D2E) : Colors.white;
    final borderColor = isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0);
    final titleColor = isDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A);
    final subtitleColor = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0B1424) : const Color(0xFFF8FAFC),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: const Color(0xFF00458E),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white, size: 22),
          onPressed: () => Navigator.maybePop(context),
        ),
        title: const Text(
          'VERIFRAME',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.0,
            color: Colors.white,
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.more_horiz_rounded, color: Colors.white, size: 24),
            onPressed: () {},
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
        child: Column(
          children: [
            // Top Progress Card
            Container(
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: borderColor, width: 1.2),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.03),
                    blurRadius: 12,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              padding: const EdgeInsets.all(22),
              child: Column(
                children: [
                  // Status & Percentage Row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Downloading Video',
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                              color: titleColor,
                              letterSpacing: -0.2,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Stage 3 of 9',
                            style: TextStyle(
                              fontSize: 12.5,
                              color: subtitleColor,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            '$currentProgress%',
                            style: const TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF00A3CC),
                              letterSpacing: -0.5,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '~6s remaining',
                            style: TextStyle(
                              fontSize: 11,
                              color: subtitleColor,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),

                  // Rounded Cyan Linear Progress Bar
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: currentProgress / 100,
                      minHeight: 6,
                      backgroundColor: isDark
                          ? const Color(0xFF1E293B)
                          : const Color(0xFFE2E8F0),
                      valueColor: const AlwaysStoppedAnimation<Color>(
                        Color(0xFF00A3CC),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Vertical Timeline Card
            Container(
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: borderColor, width: 1.2),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.03),
                    blurRadius: 12,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              clipBehavior: Clip.antiAlias,
              child: Column(
                children: List.generate(
                  steps.length,
                  (index) => _buildTimelineRow(
                    step: steps[index],
                    index: index,
                    isLast: index == steps.length - 1,
                    isDark: isDark,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 22),

            // Action Buttons
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Opening forensic report...')),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF10B981),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: const [
                        Text('📊', style: TextStyle(fontSize: 16)),
                        SizedBox(width: 8),
                        Text(
                          'VIEW REPORT',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.4,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Analysis paused')),
                      );
                    },
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: borderColor, width: 1.3),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      'PAUSE',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: subtitleColor,
                        letterSpacing: 0.4,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimelineRow({
    required TimelineStep step,
    required int index,
    required bool isLast,
    required bool isDark,
  }) {
    // Dynamic styling based on Timeline status
    Color rowBgColor;
    Color verticalLineColor;
    Color stepTextColor;
    Color timeTextColor;

    switch (step.status) {
      case TimelineStatus.completed:
        rowBgColor = isDark
            ? const Color(0xFF0A2218).withValues(alpha: 0.6)
            : const Color(0xFFF0FDF4);
        verticalLineColor = const Color(0xFF22C55E);
        stepTextColor = const Color(0xFF16A34A);
        timeTextColor = const Color(0xFF94A3B8);
        break;
      case TimelineStatus.active:
        rowBgColor = isDark
            ? const Color(0xFF082638).withValues(alpha: 0.7)
            : const Color(0xFFF0F9FF);
        verticalLineColor = const Color(0xFF00A3CC);
        stepTextColor = const Color(0xFF0077AA);
        timeTextColor = const Color(0xFF00A3CC);
        break;
      case TimelineStatus.pending:
        rowBgColor = isDark ? const Color(0xFF131D2E) : Colors.white;
        verticalLineColor = isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0);
        stepTextColor = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
        timeTextColor = isDark ? const Color(0xFF475569) : const Color(0xFFCBD5E1);
        break;
    }

    return Container(
      decoration: BoxDecoration(
        color: rowBgColor,
        border: Border(
          bottom: isLast
              ? BorderSide.none
              : BorderSide(
                  color: isDark ? const Color(0xFF1A263B) : const Color(0xFFF1F5F9),
                  width: 1.0,
                ),
        ),
      ),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Left continuous timeline spine
            SizedBox(
              width: 32,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Continuous vertical line
                  Positioned(
                    top: 0,
                    bottom: 0,
                    left: 14.5,
                    child: Container(
                      width: 2.5,
                      color: verticalLineColor,
                    ),
                  ),
                  // Timeline Node (Dot or Pulsing circle)
                  _buildTimelineNode(step.status),
                ],
              ),
            ),

            // Status Indicator Icon (Checkmark / Down Arrow / Hollow Circle)
            Container(
              alignment: Alignment.center,
              padding: const EdgeInsets.only(right: 12),
              child: _buildStatusActionIcon(step.status),
            ),

            // Step Label
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Text(
                  step.label,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: step.status == TimelineStatus.active
                        ? FontWeight.w700
                        : (step.status == TimelineStatus.completed
                            ? FontWeight.w600
                            : FontWeight.w500),
                    color: stepTextColor,
                  ),
                ),
              ),
            ),

            // Time / Duration Text on Right
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 16, 20, 16),
              child: Text(
                step.time,
                style: TextStyle(
                  fontSize: 12,
                  color: timeTextColor,
                  fontWeight: step.status == TimelineStatus.active
                      ? FontWeight.w700
                      : FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Node dot on the continuous line
  Widget _buildTimelineNode(TimelineStatus status) {
    switch (status) {
      case TimelineStatus.completed:
        return Container(
          width: 7.5,
          height: 7.5,
          decoration: const BoxDecoration(
            color: Color(0xFF22C55E),
            shape: BoxShape.circle,
          ),
        );
      case TimelineStatus.active:
        return AnimatedBuilder(
          animation: _pulseController,
          builder: (context, child) {
            return Container(
              width: 14 + (_pulseController.value * 3),
              height: 14 + (_pulseController.value * 3),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF00A3CC).withValues(alpha: 0.25),
              ),
              child: Center(
                child: Container(
                  width: 7.5,
                  height: 7.5,
                  decoration: const BoxDecoration(
                    color: Color(0xFF00A3CC),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            );
          },
        );
      case TimelineStatus.pending:
        return Container(
          width: 6,
          height: 6,
          decoration: const BoxDecoration(
            color: Color(0xFFE2E8F0),
            shape: BoxShape.circle,
          ),
        );
    }
  }

  // Icon in front of the text: ✓ / ↓ / ○
  Widget _buildStatusActionIcon(TimelineStatus status) {
    switch (status) {
      case TimelineStatus.completed:
        return const Icon(
          Icons.check_rounded,
          color: Color(0xFF16A34A),
          size: 17,
        );
      case TimelineStatus.active:
        return const Icon(
          Icons.arrow_downward_rounded,
          color: Color(0xFF0077AA),
          size: 16,
        );
      case TimelineStatus.pending:
        return Container(
          width: 14,
          height: 14,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: const Color(0xFF64748B),
              width: 1.5,
            ),
          ),
        );
    }
  }
}
