import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:veriframe_app/controllers/settings_controller.dart';
import 'package:veriframe_app/l10n/app_localizations.dart';
import 'package:veriframe_app/screens/home_page.dart';
import 'package:veriframe_app/screens/on_bording.dart';
import 'package:veriframe_app/screens/login_page.dart';
import 'package:veriframe_app/screens/signup_page.dart';
import 'package:veriframe_app/screens/forgot_password.dart';
import 'package:veriframe_app/screens/verify.dart';
import 'package:veriframe_app/screens/image_page.dart';
import 'package:veriframe_app/screens/audio_page.dart';
import 'package:veriframe_app/screens/contact_us.dart';
import 'package:veriframe_app/screens/privacy.dart';
import 'package:veriframe_app/screens/settings_page.dart';
import 'package:veriframe_app/screens/reports_page.dart';
import 'package:veriframe_app/screens/technology_stack_page.dart';
import 'package:veriframe_app/screens/splash_screen.dart';
import 'package:veriframe_app/service/user_profile_cache.dart';
import 'package:veriframe_app/theme/app_theme.dart';
import 'package:veriframe_app/utils/navigator_key.dart';
import 'package:veriframe_app/screens/download_analysis_page.dart';
import 'package:veriframe_app/screens/media_modality_selection_page.dart';
import 'package:veriframe_app/widgets/error_screen.dart';

Future<void> _initializeApp() async {
  await UserProfileCache.instance.preload();
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  late final SettingsController _controller;

  @override
  void initState() {
    super.initState();
    _controller = SettingsController();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {

    ErrorWidget.builder = (FlutterErrorDetails errorDetails) {
      return ErrorScreen(
        errorDetails: errorDetails,
        onRetry: () {
          if (navigatorKey.currentState != null) {
            navigatorKey.currentState!.pushReplacement(
              MaterialPageRoute(builder: (_) => const OnBoardingScreen()),
            );
          }
        },
      );
    };

    return SettingsScope(
      controller: _controller,
      child: ListenableBuilder(
        listenable: _controller,
        builder: (context, _) => ProviderScope(
          child: MaterialApp(
            title: 'VeriFrame SL',
          debugShowCheckedModeBanner: false,
          navigatorKey: navigatorKey,
          locale: _controller.locale,
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          themeMode: _controller.themeMode,
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          home: const SplashScreen(onInitialized: _initializeApp),
          routes: {
            '/on_boarding': (_) => const OnBoardingScreen(),
            '/login': (_) => LoginPage(
              isDarkMode: _controller.isDarkMode,
              onThemeChanged: (isDark) => _controller.setThemeMode(
                isDark ? ThemeMode.dark : ThemeMode.light,
              ),
              onGoogleSignIn: () async {},
            ),
            '/signup': (_) => SignUpPage(
              isDarkMode: _controller.isDarkMode,
              onThemeChanged: (isDark) => _controller.setThemeMode(
                isDark ? ThemeMode.dark : ThemeMode.light,
              ),
            ),
            '/forgot_password': (_) => const ForgetPasswordPage(),
            '/home': (_) => const HomePage(),
            '/analyze': (context) {
              final args = ModalRoute.of(context)?.settings.arguments;
              final tab = args is int ? args : 0;
              return VerifyPage(initialTab: tab);
            },
            '/image': (_) => const ImagePage(),
            '/audio': (_) => const AudioPage(),
            '/privacy': (_) => const PrivacyPage(),
            '/contact': (_) => const ContactUsPage(),
            '/settings': (_) => const SettingsPage(),
            '/reports': (_) => const ReportsPage(),
            '/tech_stack': (_) => const TechnologyStackPage(),
            '/video_link': (_) => const VerifyPage(initialTab: 1),
            '/download_analysis': (context) => DownloadAnalysisPage(
              videoUrl: ModalRoute.of(context)?.settings.arguments as String? ?? '',
            ),
            '/media_selection': (_) => const MediaModalitySelectionPage(),
            '/modality_selection': (_) => const MediaModalitySelectionPage(),
            '/model_selection': (_) => const MediaModalitySelectionPage(),
          },
        ),
      ),
    ),
  );
  }
}
