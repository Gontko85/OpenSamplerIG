//==============================================================================
//    settings_screen.dart
//    Released under EUPL 1.2
//    Copyright Cherry Tree Studio 2021
//    Modifications Copyright IG Littoral Labs 2026
//==============================================================================

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

import 'dialogs.dart';
import 'storage_cleaner.dart';

import 'settings.dart';
import 'l10n.dart';

//==============================================================================

class SettingsScreen extends StatefulWidget {
  final Settings settings;

  const SettingsScreen(this.settings, {super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

//==============================================================================

class _SettingsScreenState extends State<SettingsScreen> {
  static const List<int> _gridSizes = [1, 2, 3, 4, 5, 6, 7, 8];
  static const List<String> _fontSizes = ['Default', '12', '18', '24', '32', '40', '48', '56', '64'];
  static Map<int, String> get _fades => {
    0: S.fadeOff,
    300: '0.3 s',
    500: '0.5 s',
    1000: '1 s',
    2000: '2 s',
    3000: '3 s',
    5000: '5 s',
  };

  Settings get _s => widget.settings;

  Widget _dropdownRow<T>(String label, T value, Map<T, String> items, ValueChanged<T> onChanged) {
    return Row(
      children: <Widget>[
        Expanded(child: Text(label)),
        DropdownButton<T>(
          value: items.containsKey(value) ? value : items.keys.first,
          onChanged: (v) {
            if (v != null) setState(() => onChanged(v));
          },
          items: items.entries.map((e) => DropdownMenuItem<T>(value: e.key, child: Text(e.value))).toList(),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    const header = TextStyle(fontSize: 20, fontWeight: FontWeight.w600);
    final gridItems = {for (final n in _gridSizes) n: '$n'};

    return Scaffold(
      appBar: AppBar(title: Text(S.settings)),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: <Widget>[
          Text(S.projectSettings, style: header),
          const SizedBox(height: 8),
          _dropdownRow<int>(S.horizontalPads, _s.x, gridItems, (v) {
            _s.x = v;
            _s.validate();
          }),
          _dropdownRow<int>(S.verticalPads, _s.y, gridItems, (v) {
            _s.y = v;
            _s.validate();
          }),
          if (_s.pageCount > 1)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(S.gridAllPages, style: Theme.of(context).textTheme.bodySmall),
            ),
          const SizedBox(height: 28),
          Text(S.globalSettings, style: header),
          const SizedBox(height: 8),
          _dropdownRow<String>(S.language, S.code, const {
            'fr': 'Français',
            'en': 'English',
          }, (v) => setLanguage(v)),
          _dropdownRow<String>(S.fontSize, GlobalPrefs.fontSize, {
            for (final f in _fontSizes) f: f == 'Default' ? S.fontDefault : f,
          }, (v) => GlobalPrefs.fontSize = v),
          _dropdownRow<int>(S.fadeOut, GlobalPrefs.fadeMs, _fades, (v) => GlobalPrefs.fadeMs = v),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(S.showRemaining),
            value: GlobalPrefs.showRemaining,
            onChanged: (v) => setState(() => GlobalPrefs.showRemaining = v),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(S.keepScreenOn),
            value: GlobalPrefs.keepScreenOn,
            onChanged: (v) => setState(() => GlobalPrefs.keepScreenOn = v),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(S.showNowPlaying),
            value: GlobalPrefs.showNowPlaying,
            onChanged: (v) => setState(() => GlobalPrefs.showNowPlaying = v),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(S.showRecent),
            value: GlobalPrefs.showRecent,
            onChanged: (v) => setState(() => GlobalPrefs.showRecent = v),
          ),
          const SizedBox(height: 28),
          Text(S.storage, style: header),
          const SizedBox(height: 8),
          _StoragePanel(current: _s),
        ],
      ),
    );
  }
}

//==============================================================================

/// Space used by the sounds, and a button to delete those no project uses.
class _StoragePanel extends StatefulWidget {
  final Settings current;
  const _StoragePanel({required this.current});

  @override
  State<_StoragePanel> createState() => _StoragePanelState();
}

class _StoragePanelState extends State<_StoragePanel> {
  late Future<StorageReport> _report = _analyze();
  bool _cleaning = false;

  Future<StorageReport> _analyze() async {
    await widget.current.save(); // the project on screen counts as "used"
    return StorageCleaner.analyze(current: widget.current, cacheDir: await getTemporaryDirectory());
  }

  String _b(int bytes) => StorageCleaner.formatBytes(bytes, fr: S.fr);

  Future<void> _clean(StorageReport r) async {
    final ok = await confirm(
      context,
      title: Text(S.storageCleanTitle),
      content: Text(S.storageCleanConfirm(r.unused.length, _b(r.freeableBytes))),
    );
    if (!ok || !mounted) return;
    setState(() => _cleaning = true);
    final freed = await StorageCleaner.clean(r);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(S.storageFreed(_b(freed)))));
    setState(() {
      _cleaning = false;
      _report = _analyze();
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<StorageReport>(
      future: _report,
      builder: (context, snap) {
        if (!snap.hasData || _cleaning) {
          return const Padding(padding: EdgeInsets.all(8), child: LinearProgressIndicator());
        }
        final r = snap.data!;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(S.storageSounds(r.soundCount, _b(r.soundBytes))),
            const SizedBox(height: 4),
            Text(
              r.freeableBytes > 0 ? S.storageUnused(r.unused.length, _b(r.freeableBytes)) : S.storageNothing,
              style: TextStyle(color: Theme.of(context).hintColor),
            ),
            if (!r.safe) ...[
              const SizedBox(height: 4),
              Text(
                S.storageUnsafe(r.unreadableProjects.join(', ')),
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
            const SizedBox(height: 10),
            FilledButton.tonalIcon(
              onPressed: r.safe && r.freeableBytes > 0 ? () => _clean(r) : null,
              icon: const Icon(Icons.cleaning_services_outlined),
              label: Text(S.storageCleanButton(_b(r.freeableBytes))),
            ),
          ],
        );
      },
    );
  }
}
