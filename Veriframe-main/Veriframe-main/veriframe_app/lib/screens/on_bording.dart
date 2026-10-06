import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:veriframe_app/l10n/app_localizations.dart';
import 'package:veriframe_app/widgets/language_selector_button.dart';

class OnBoardingScreen extends StatefulWidget {
  const OnBoardingScreen({super.key});

  @override
  State<OnBoardingScreen> createState() => _OnBoardingScreenState();
}

class _OnBoardingScreenState extends State<OnBoardingScreen>
    with TickerProviderStateMixin {
  final PageController controller = PageController();
  int selectPage = 0;

  late AnimationController _scanController;
  late Animation<double> _scanAnimation;

  static const _bg = Color(0xFF0D1B2A);
  static const _accent = Color(0xFF1565C0);
  static const _scan = Color(0xFF00E5FF);

  @override
  void initState() {
    super.initState();

    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
      ),
    );

    _scanController = AnimationController(
      duration: const Duration(milliseconds: 2200),
      vsync: this,
    )..repeat();

    _scanAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _scanController, curve: Curves.linear));
  }

  @override
  void dispose() {
    _scanController.dispose();
    controller.dispose();
    super.dispose();
  }

  List<Map<String, dynamic>> _getPages(AppLocalizations? loc) {
    return [
      {
        "headline": loc?.onboardingSlide1Headline.replaceAll('\\n', '\n') ??
            "Detect Deepfakes.\nTrust What's Real.",
        "subtitle": loc?.onboardingSlide1Subtitle.replaceAll('\\n', '\n') ??
            "An AI system built to detect\ndeepfake videos automatically.",
        "badgeLabel": loc?.onboardingSlide1Badge ?? "Deepfake Detection",
        "illustration": 0,
      },
      {
        "headline": loc?.onboardingSlide2Headline.replaceAll('\\n', '\n') ??
            "Real-Time Video &\nVoice Forensics",
        "subtitle": loc?.onboardingSlide2Subtitle.replaceAll('\\n', '\n') ??
            "AI models analyze facial landmarks,\noptical noise, and temporal consistency.",
        "badgeLabel": loc?.onboardingSlide2Badge ?? "VeriFrame AI",
        "illustration": 1,
      },
      {
        "headline": loc?.onboardingSlide3Headline.replaceAll('\\n', '\n') ??
            "Explainable Results &\nForensic Reports",
        "subtitle": loc?.onboardingSlide3Subtitle.replaceAll('\\n', '\n') ??
            "Step-by-step forensic reasoning with\nclear confidence scores and evidence.",
        "badgeLabel": loc?.onboardingSlide3Badge ?? "Forensic Audit",
        "illustration": 2,
      },
    ];
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final loc = AppLocalizations.of(context);
    final pageArr = _getPages(loc);

    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: Column(
          children: [
            // Top Bar with Brand and Language selector
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'VERIFRAME',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 2.0,
                    ),
                  ),
                  const LanguageSelectorButton(iconColor: Colors.white),
                ],
              ),
            ),

            // PageView
            Expanded(
              child: PageView.builder(
                controller: controller,
                itemCount: pageArr.length,
                onPageChanged: (p) => setState(() => selectPage = p),
                itemBuilder: (context, index) =>
                    _buildPage(pageArr[index], size, loc, pageArr.length),
              ),
            ),

            // Bottom controls
            _buildBottomControls(context, pageArr.length, loc),
          ],
        ),
      ),
    );
  }

  Widget _buildPage(Map<String, dynamic> obj, Size size, AppLocalizations? loc, int totalPages) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 12),

          // Illustration card
          _buildIllustrationCard(obj, size, loc),

          const SizedBox(height: 24),

          // Badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: _accent.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 5,
                  height: 5,
                  decoration: const BoxDecoration(
                    color: _scan,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  obj["badgeLabel"] as String,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.65),
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 0.2,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // Headline
          Text(
            obj["headline"] as String,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.w700,
              height: 1.25,
              letterSpacing: -0.3,
            ),
          ),

          const SizedBox(height: 10),

          // Subtitle
          Text(
            obj["subtitle"] as String,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.55),
              fontSize: 13,
              height: 1.5,
            ),
          ),

          const SizedBox(height: 20),

          // Dots
          Row(
            children: List.generate(totalPages, (i) {
              final active = selectPage == i;
              return AnimatedContainer(
                duration: const Duration(milliseconds: 280),
                margin: const EdgeInsets.only(right: 6),
                width: active ? 20 : 6,
                height: 6,
                decoration: BoxDecoration(
                  color: active ? Colors.white : Colors.white.withValues(alpha: 0.25),
                  borderRadius: BorderRadius.circular(3),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildIllustrationCard(Map<String, dynamic> obj, Size size, AppLocalizations? loc) {
    final cardHeight = (size.height * 0.33).clamp(180.0, 260.0);
    return Container(
      height: cardHeight,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: Colors.white.withValues(alpha: 0.04),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      clipBehavior: Clip.hardEdge,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Subtle grid
          CustomPaint(painter: _GridPainter()),

          // Content
          Center(child: _buildIllustration(obj["illustration"] as int, loc)),

          // Scan line
          AnimatedBuilder(
            animation: _scanAnimation,
            builder: (_, __) => Positioned(
              top: _scanAnimation.value * cardHeight,
              left: 0,
              right: 0,
              child: Container(
                height: 1.5,
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.transparent, _scan, Colors.transparent],
                  ),
                ),
              ),
            ),
          ),

          // Top-right badge
          Positioned(
            top: 10,
            right: 10,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 5,
                    height: 5,
                    decoration: const BoxDecoration(
                      color: _scan,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 5),
                  Text(
                    obj["badgeLabel"] as String,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 9,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIllustration(int index, AppLocalizations? loc) {
    switch (index) {
      case 0:
        return _faceGrid(loc);
      case 1:
        return _analysisPanel(loc);
      default:
        return _explainPanel(loc);
    }
  }

  Widget _faceGrid(AppLocalizations? loc) {
    final statuses = [true, false, true, false, true, null, false, null, true];
    return Padding(
      padding: const EdgeInsets.all(20),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: SizedBox(
          width: 260,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                loc?.onboardingFrameAnalysis ?? "Frame Analysis",
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.4),
                  fontSize: 10,
                  letterSpacing: 0.8,
                ),
              ),
              const SizedBox(height: 10),
              GridView.count(
                crossAxisCount: 3,
                shrinkWrap: true,
                mainAxisSpacing: 6,
                crossAxisSpacing: 6,
                childAspectRatio: 1.3,
                physics: const NeverScrollableScrollPhysics(),
                children: statuses.map((s) {
                  final bg = s == null
                      ? Colors.white.withValues(alpha: 0.04)
                      : s
                      ? Colors.green.withValues(alpha: 0.12)
                      : Colors.red.withValues(alpha: 0.10);
                  final border = s == null
                      ? Colors.white.withValues(alpha: 0.08)
                      : s
                      ? Colors.green.withValues(alpha: 0.3)
                      : Colors.red.withValues(alpha: 0.25);
                  return Container(
                    decoration: BoxDecoration(
                      color: bg,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: border),
                    ),
                    child: s == null
                        ? null
                        : Align(
                            alignment: Alignment.bottomRight,
                            child: Padding(
                              padding: const EdgeInsets.all(3),
                              child: Text(
                                s ? "✓" : "✗",
                                style: TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold,
                                  color: s
                                      ? Colors.greenAccent
                                      : Colors.redAccent,
                                ),
                              ),
                            ),
                          ),
                  );
                }).toList(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _analysisPanel(AppLocalizations? loc) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.bar_chart_rounded,
            color: Colors.white.withValues(alpha: 0.6),
            size: 30,
          ),
          const SizedBox(height: 14),
          _bar(loc?.realVerdict ?? "Real", 0.94, Colors.greenAccent),
          const SizedBox(height: 8),
          _bar(loc?.manipulatedVerdict ?? "Fake", 0.06, Colors.redAccent),
          const SizedBox(height: 14),
          Text(
            loc?.onboardingConfidence("97.4") ?? "97.4% confidence",
            style: TextStyle(
              color: _scan.withValues(alpha: 0.8),
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _bar(String label, double value, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.55),
                fontSize: 11,
              ),
            ),
            Text(
              "${(value * 100).toInt()}%",
              style: TextStyle(
                color: color,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Stack(
          children: [
            Container(
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            FractionallySizedBox(
              widthFactor: value,
              child: Container(
                height: 4,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.7),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _explainPanel(AppLocalizations? loc) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          Icons.verified_user_outlined,
          color: Colors.white.withValues(alpha: 0.5),
          size: 44,
        ),
        const SizedBox(height: 12),
        Text(
          loc?.onboardingExplainableResults ?? "Explainable Results",
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.7),
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          loc?.onboardingExplainableDesc.replaceAll('\\n', '\n') ??
              "Step-by-step reasoning\nwith confidence scores",
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.35),
            fontSize: 11,
            height: 1.6,
          ),
        ),
      ],
    );
  }

  Widget _buildBottomControls(BuildContext context, int totalPages, AppLocalizations? loc) {
    final isLast = selectPage == totalPages - 1;
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 28),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Skip
          GestureDetector(
            onTap: () => Navigator.pushReplacementNamed(context, '/login'),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 14),
              child: Text(
                loc?.onboardingSkip ?? "Skip",
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.4),
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),

          // Next / Get Started
          GestureDetector(
            onTap: () {
              if (isLast) {
                Navigator.pushReplacementNamed(context, '/login');
              } else {
                controller.nextPage(
                  duration: const Duration(milliseconds: 380),
                  curve: Curves.easeInOutCubic,
                );
              }
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
              decoration: BoxDecoration(
                color: _accent,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    isLast
                        ? (loc?.onboardingGetStarted ?? "Get Started")
                        : (loc?.onboardingNext ?? "Next"),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: 6),
                  const Icon(
                    Icons.arrow_forward_rounded,
                    color: Colors.white,
                    size: 15,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.04)
      ..strokeWidth = 0.5;
    const spacing = 32.0;
    for (double x = 0; x < size.width; x += spacing) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y < size.height; y += spacing) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}
