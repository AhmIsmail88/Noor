import 'package:flutter/material.dart';

import '../../app/l10n/gen/app_localizations.dart';
import '../../app/settings.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key, required this.settings});
  final AppSettings settings;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return ListenableBuilder(
      listenable: settings,
      builder: (context, _) => ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(l.language, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          SegmentedButton<String>(
            segments: [
              ButtonSegment(value: 'ar', label: Text(l.arabic)),
              ButtonSegment(value: 'en', label: Text(l.english)),
            ],
            selected: {settings.locale.languageCode},
            onSelectionChanged: (s) => settings.setLocale(Locale(s.first)),
          ),
          const SizedBox(height: 24),
          Text(l.theme, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          SegmentedButton<ThemeMode>(
            segments: [
              ButtonSegment(value: ThemeMode.dark, label: Text(l.themeDark)),
              ButtonSegment(value: ThemeMode.light, label: Text(l.themeLight)),
              ButtonSegment(
                value: ThemeMode.system,
                label: Text(l.themeSystem),
              ),
            ],
            selected: {settings.themeMode},
            onSelectionChanged: (s) => settings.setThemeMode(s.first),
          ),
        ],
      ),
    );
  }
}
