import 'package:flutter/material.dart';

import '../../app/l10n/gen/app_localizations.dart';
import '../../app/settings.dart';
import '../../data/online_media_service.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key, required this.settings, this.online});
  final AppSettings settings;
  final OnlineMediaService? online;

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
          const SizedBox(height: 16),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(l.autoplayNext),
            subtitle: Text(l.autoplayNextHint),
            value: settings.autoplayNext,
            onChanged: settings.setAutoplayNext,
          ),
          if (online != null) ...[
            const Divider(height: 32),
            _EngineSection(online: online!),
          ],
        ],
      ),
    );
  }
}

class _EngineSection extends StatefulWidget {
  const _EngineSection({required this.online});
  final OnlineMediaService online;

  @override
  State<_EngineSection> createState() => _EngineSectionState();
}

class _EngineSectionState extends State<_EngineSection> {
  String? _version;

  @override
  void initState() {
    super.initState();
    widget.online.engineVersion().then((v) {
      if (mounted) setState(() => _version = v);
    });
  }

  Future<void> _update() async {
    final l = AppLocalizations.of(context)!;
    final messenger = ScaffoldMessenger.of(context);
    String message;
    try {
      final result = await widget.online.updateEngine();
      if (mounted) setState(() => _version = result.after);
      final after = result.after ?? '?';
      message = result.before == result.after
          ? l.engineUpToDate(after)
          : l.engineUpdated(after);
    } on StateError catch (e) {
      message = e.message.startsWith('Finish or cancel')
          ? l.engineBusy
          : l.engineUpdateFailed;
    } catch (_) {
      message = l.engineUpdateFailed;
    }
    messenger.showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final online = widget.online;
    return ListenableBuilder(
      listenable: online,
      builder: (context, _) {
        final blocked = online.busy || online.hasTransfer;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l.engineTitle, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(
              _version == null
                  ? l.engineVersionUnknown
                  : l.engineVersion(_version!),
            ),
            const SizedBox(height: 4),
            Text(l.engineHint, style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 12),
            FilledButton.tonalIcon(
              onPressed: online.engineUpdating || blocked ? null : _update,
              icon: online.engineUpdating
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.system_update_alt),
              label: Text(
                online.engineUpdating ? l.engineUpdating : l.engineUpdate,
              ),
            ),
            if (blocked && !online.engineUpdating) ...[
              const SizedBox(height: 4),
              Text(l.engineBusy, style: Theme.of(context).textTheme.bodySmall),
            ],
          ],
        );
      },
    );
  }
}
