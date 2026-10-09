//==============================================================================
//    pad_screen.dart
//    Released under EUPL 1.2
//    Copyright Cherry Tree Studio 2021
//    Modifications Copyright IG Littoral Labs 2026
//==============================================================================

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:path/path.dart' as p;
import 'package:wakelock_plus/wakelock_plus.dart';

import 'about_screen.dart';
import 'dialogs.dart';
import 'help_screen.dart';
import 'load_screen.dart';
import 'main.dart';
import 'pad_settings_screen.dart';
import 'pad_tile.dart';
import 'sample_engine.dart';
import 'settings.dart';
import 'settings_screen.dart';

//==============================================================================

enum MenuAction { newProject, saveProject, openProject, settings, help, about }

//==============================================================================

class PadScreen extends StatefulWidget {
  final Settings initialSettings;

  const PadScreen(this.initialSettings, {super.key});

  @override
  State<PadScreen> createState() => _PadScreenState();
}

//==============================================================================

class _PadScreenState extends State<PadScreen> with SingleTickerProviderStateMixin {
  late Settings _settings;
  final SampleEngine _engine = SampleEngine();
  late final Ticker _ticker;
  bool _stageLock = GlobalPrefs.stageLock;

  //----------------------------------------------------------------------------

  @override
  void initState() {
    super.initState();
    _settings = Settings.copy(widget.initialSettings);
    _engine.fadeMs = GlobalPrefs.fadeMs;
    _engine.addListener(_onEngineChanged);
    _ticker = createTicker(_onTick);
    _applyWakelock();
    _reloadAll();
  }

  @override
  void dispose() {
    _ticker.dispose();
    _engine.removeListener(_onEngineChanged);
    _engine.dispose();
    WakelockPlus.disable();
    super.dispose();
  }

  //----------------------------------------------------------------------------

  Future<void> _reloadAll() async {
    await _engine.init(_settings);
    _saveIfDirty();
  }

  void _saveIfDirty() {
    if (_engine.settingsDirty) {
      _engine.settingsDirty = false;
      _settings.save();
    }
  }

  void _applyWakelock() {
    if (GlobalPrefs.keepScreenOn) {
      WakelockPlus.enable();
    } else {
      WakelockPlus.disable();
    }
  }

  void _onEngineChanged() {
    if (!mounted) return;
    // Animate only while something is playing, so the app stays idle otherwise.
    if (_engine.anyActive && !_ticker.isActive) {
      _ticker.start();
    } else if (!_engine.anyActive && _ticker.isActive) {
      _ticker.stop();
    }
    setState(() {});
  }

  void _onTick(Duration _) {
    _engine.tick();
    if (mounted) setState(() {});
  }

  //----------------------------------------------------------------------------

  void _press(int idx) => _engine.press(idx);

  Future<void> _editPad(int padIdx) async {
    final int row = padIdx ~/ _settings.x;
    final int col = padIdx % _settings.x;
    final before = PadSettings.copy(_settings.padSettings[padIdx]);

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PadSettingsScreen(col, row, _settings.padSettings[padIdx], _settings),
      ),
    );

    final after = _settings.padSettings[padIdx];
    if (after.sample != before.sample) after.durationMs = 0;

    await _settings.save();

    // Reload only this pad if its sound changed: the others keep playing.
    final bool audioChanged = after.sample != before.sample ||
        after.looped != before.looped ||
        after.long != before.long ||
        after.volume != before.volume;
    if (audioChanged) {
      await _engine.reloadPad(padIdx, after);
      _saveIfDirty();
    }
    if (mounted) setState(() {});
  }

  //----------------------------------------------------------------------------

  void _toggleStageLock() {
    setState(() {
      _stageLock = !_stageLock;
      GlobalPrefs.stageLock = _stageLock;
    });
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        duration: const Duration(seconds: 2),
        content: Text(_stageLock
            ? 'Stage mode ON: pads fire on touch, editing is locked.'
            : 'Stage mode OFF: long press a pad to edit it.'),
      ));
  }

  //----------------------------------------------------------------------------

  Future<void> _goToNew() async {
    final ok = await confirm(context,
        content: const Text('This will close current project and create a blank one. Continue?'));
    if (!ok) return;

    _settings = defaultSettings();
    await _settings.save();
    preferences.setString(GlobalPrefs.lastFileKey, _settings.file.absolute.path);
    await _reloadAll();
    if (mounted) setState(() {});
  }

  Future<void> _goToSettings() async {
    final int oldX = _settings.x, oldY = _settings.y;
    await Navigator.push(context, MaterialPageRoute(builder: (context) => SettingsScreen(_settings)));

    _settings.validate();
    await _settings.save();
    _engine.fadeMs = GlobalPrefs.fadeMs;
    _applyWakelock();

    if (oldX != _settings.x || oldY != _settings.y) {
      await _reloadAll();
    }
    if (mounted) setState(() {});
  }

  Future<void> _goToSave() async {
    final name = await askText(context, 'Input project name', initial: _settings.name);
    if (name == null || name.trim().isEmpty) return;

    final safe = name.trim().replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
    _settings.name = name.trim();
    _settings.file = File('${documentDirectory.path}/$safe.json');
    await _settings.save();
    preferences.setString(GlobalPrefs.lastFileKey, _settings.file.absolute.path);
    if (mounted) setState(() {});
  }

  Future<void> _goToOpen() async {
    final List<File> files = [];
    await for (final f in documentDirectory.list(recursive: false, followLinks: false)) {
      if (f is File && f.path.endsWith(".json") && p.basename(f.path) != "temp.json") {
        files.add(f);
      }
    }
    files.sort((a, b) => p.basename(a.path).toLowerCase().compareTo(p.basename(b.path).toLowerCase()));

    if (!mounted) return;
    final File? settingsFile =
        await Navigator.push(context, MaterialPageRoute(builder: (context) => LoadScreen(files)));

    if (settingsFile != null) {
      try {
        final json = await settingsFile.readAsString();
        _settings = Settings.fromJson(settingsFile, json);
        await _reloadAll();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text('Cannot open project: $e')));
        }
      }
    }
    if (mounted) setState(() {});
  }

  void _onMenu(MenuAction a) {
    switch (a) {
      case MenuAction.newProject:
        _goToNew();
        break;
      case MenuAction.saveProject:
        _goToSave();
        break;
      case MenuAction.openProject:
        _goToOpen();
        break;
      case MenuAction.settings:
        _goToSettings();
        break;
      case MenuAction.help:
        Navigator.push(context, MaterialPageRoute(builder: (context) => const HelpScreen()));
        break;
      case MenuAction.about:
        Navigator.push(context, MaterialPageRoute(builder: (context) => const AboutScreen()));
        break;
    }
  }

  //----------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final String prefFont = GlobalPrefs.fontSize;
    final double? fontSize = prefFont != "Default" ? double.tryParse(prefFont) : null;
    final bool showRemaining = GlobalPrefs.showRemaining;
    const double spacing = 4;

    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 60, 60, 60),
      appBar: AppBar(
        title: Text(_settings.name),
        actions: [
          IconButton(
            tooltip: _stageLock ? 'Unlock editing' : 'Stage mode (lock editing)',
            icon: Icon(_stageLock ? Icons.lock : Icons.lock_open),
            color: _stageLock ? Colors.amber : null,
            onPressed: _toggleStageLock,
          ),
          IconButton(
            tooltip: 'Stop all (tap twice to cut at once)',
            icon: const Icon(Icons.volume_off_rounded),
            onPressed: () => _engine.stopAll(),
          ),
          if (!_stageLock)
            PopupMenuButton<MenuAction>(
              onSelected: _onMenu,
              itemBuilder: (context) => const [
                PopupMenuItem(value: MenuAction.newProject, child: Text('New Project')),
                PopupMenuItem(value: MenuAction.saveProject, child: Text('Save Project')),
                PopupMenuItem(value: MenuAction.openProject, child: Text('Open Project')),
                PopupMenuItem(value: MenuAction.settings, child: Text('Settings')),
                PopupMenuDivider(),
                PopupMenuItem(value: MenuAction.help, child: Text('Help')),
                PopupMenuItem(value: MenuAction.about, child: Text('About')),
              ],
            ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(spacing),
          child: Column(
            children: List.generate(_settings.y, (row) {
              return Expanded(
                child: Row(
                  children: List.generate(_settings.x, (col) {
                    final int i = row * _settings.x + col;
                    return Expanded(
                      child: Padding(
                        padding: const EdgeInsets.all(spacing / 2),
                        child: PadTile(
                          settings: _settings.padSettings[i],
                          voice: _engine.voice(i),
                          fontSize: fontSize,
                          showRemaining: showRemaining,
                          stageLock: _stageLock,
                          onTrigger: () => _press(i),
                          onEdit: () => _editPad(i),
                        ),
                      ),
                    );
                  }),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}

//==============================================================================
