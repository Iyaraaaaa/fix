import 'package:flutter/material.dart';
import 'package:veriframe_app/controllers/settings_controller.dart';
import 'package:veriframe_app/l10n/app_localizations.dart';

class LanguageSelectorButton extends StatelessWidget {
  final Color? iconColor;
  final Color? backgroundColor;

  const LanguageSelectorButton({
    super.key,
    this.iconColor,
    this.backgroundColor,
  });

  static const languages = [
    (name: 'English', code: 'en', flag: '🇬🇧'),
    (name: 'සිංහල', code: 'si', flag: '🇱🇰'),
    (name: 'தமிழ்', code: 'ta', flag: '🇱🇰'),
  ];

  @override
  Widget build(BuildContext context) {
    final controller = SettingsScope.of(context);
    final loc = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;

    Widget button = PopupMenuButton<Locale>(
      icon: Icon(
        Icons.language,
        color: iconColor ?? (Theme.of(context).brightness == Brightness.dark ? Colors.amber : Colors.white),
        size: 22,
      ),
      tooltip: loc?.changeLanguage ?? 'Change Language',
      initialValue: controller.locale,
      onSelected: (locale) => controller.setLocale(locale),
      itemBuilder: (_) => languages
          .map(
            (l) {
              final isSelected = controller.locale.languageCode == l.code;
              return PopupMenuItem<Locale>(
                value: Locale(l.code),
                child: Row(
                  children: [
                    Text(l.flag, style: const TextStyle(fontSize: 16)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        l.name,
                        style: TextStyle(
                          fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                          color: isSelected ? scheme.primary : null,
                        ),
                      ),
                    ),
                    if (isSelected)
                      Icon(Icons.check, size: 18, color: scheme.primary),
                  ],
                ),
              );
            },
          )
          .toList(),
    );

    if (backgroundColor != null) {
      return Container(
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(25),
        ),
        child: button,
      );
    }

    return button;
  }
}
