//==============================================================================
//    pad_screen.dart
//    Released under EUPL 1.2
//    Copyright Cherry Tree Studio 2021
//    Modifications Copyright IG Littoral Labs 2026
//==============================================================================

import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:path/path.dart' as p;
import 'package:wakelock_plus/wakelock_plus.dart';

import 'about_screen.dart';
import 'dialogs.dart';
import 'help_screen.dart';
import 'l10n.dart';
import 'load_screen.dart';
import 'main.dart';
import 'pad_settings_screen.dart';
import 'pad_tile.dart';
import 'project_archive.dart';
import 'sample_engine.dart';
import 'settings.dart';
import 'settings_screen.dart';

//==============================================================================

enum MenuAction { newProject, saveProject, openProject, exportProject, importProject, settings, help, about }

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
    WakelockPlus.disable().catchError((_) {});
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
    final f = GlobalPrefs.keepScreenOn ? WakelockPlus.enable() : WakelockPlus.disable();
    f.catchError((_) {});
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

  int get _page => _settings.currentPage.clamp(0, _settings.pageCount - 1);

  Future<void> _editPad(int padIdx) async {
    final int inPage = _settings.indexInPage(padIdx);
    final int row = inPage ~/ _settings.x;
    final int col = inPage % _settings.x;
    final before = PadSettings.copy(_settings.padSettings[padIdx]);

    final int? otherPad = await Navigator.push<int>(
      context,
      MaterialPageRoute(builder: (context) => PadSettingsScreen(col, row, padIdx, _settings)),
    );

    // The pad was swapped with / copied to another pad: reload both.
    if (otherPad != null) {
      await _settings.save();
      await _engine.reloadPad(padIdx, _settings.padSettings[padIdx]);
      await _engine.reloadPad(otherPad, _settings.padSettings[otherPad]);
      _saveIfDirty();
      if (mounted) setState(() {});
      return;
    }

    final after = _settings.padSettings[padIdx];
    if (after.sample != before.sample) after.durationMs = 0;

    await _settings.save();

    // Reload only this pad if its sound changed: the others keep playing.
    final bool audioChanged =
        after.sample != before.sample ||
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
  // Pages

  void _selectPage(int p) {
    if (p == _page) return;
    setState(() => _settings.currentPage = p);
    _settings.save();
  }

  /// Runs a page operation on the model, then moves the audio players along
  /// with their pads so that whatever is playing keeps playing.
  Future<void> _changePages(void Function() op) async {
    final before = List<PadSettings>.of(_settings.padSettings);
    op();
    final List<int> oldIndexForNew = _settings.padSettings
        .map((pad) => before.indexWhere((b) => identical(b, pad)))
        .toList();
    await _engine.applyLayout(oldIndexForNew, _settings);
    await _settings.save();
    _saveIfDirty();
    if (mounted) setState(() {});
  }

  Future<void> _addPage() async {
    await _changePages(() => _settings.currentPage = _settings.addPage());
  }

  Future<void> _pageMenu(int p) async {
    if (_stageLock) return;
    final String label = _settings.pageLabel(p, S.pageN);
    final action = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(label, style: Theme.of(ctx).textTheme.titleMedium),
            ),
            ListTile(
              leading: const Icon(Icons.edit),
              title: Text(S.renamePage),
              onTap: () => Navigator.pop(ctx, 'rename'),
            ),
            ListTile(
              leading: const Icon(Icons.copy),
              title: Text(S.duplicatePage),
              onTap: () => Navigator.pop(ctx, 'dup'),
            ),
            if (p > 0)
              ListTile(
                leading: const Icon(Icons.arrow_back),
                title: Text(S.movePageLeft),
                onTap: () => Navigator.pop(ctx, 'left'),
              ),
            if (p < _settings.pageCount - 1)
              ListTile(
                leading: const Icon(Icons.arrow_forward),
                title: Text(S.movePageRight),
                onTap: () => Navigator.pop(ctx, 'right'),
              ),
            if (_settings.pageCount > 1)
              ListTile(
                leading: const Icon(Icons.delete_outline, color: Colors.redAccent),
                title: Text(S.deletePage, style: const TextStyle(color: Colors.redAccent)),
                onTap: () => Navigator.pop(ctx, 'delete'),
              ),
          ],
        ),
      ),
    );
    if (!mounted || action == null) return;

    switch (action) {
      case 'rename':
        final name = await askText(context, S.pageNamePrompt, initial: _settings.pageNames[p]);
        if (name == null) return;
        setState(() => _settings.pageNames[p] = name.trim());
        await _settings.save();
        break;
      case 'dup':
        await _changePages(() => _settings.currentPage = _settings.duplicatePage(p, S.copyOf(label)));
        break;
      case 'left':
      case 'right':
        final int d = action == 'left' ? -1 : 1;
        await _changePages(() {
          _settings.movePage(p, d);
          if (_settings.currentPage == p) {
            _settings.currentPage = p + d;
          } else if (_settings.currentPage == p + d) {
            _settings.currentPage = p;
          }
        });
        break;
      case 'delete':
        final ok = await confirm(context, content: Text(S.deletePageConfirm(label)));
        if (!ok) return;
        await _changePages(() {
          _settings.removePage(p);
          if (_settings.currentPage > p) _settings.currentPage--;
          _settings.currentPage = _settings.currentPage.clamp(0, _settings.pageCount - 1);
        });
        break;
    }
  }

  Widget _buildPageTabs() {
    final n = _settings.padsPerPage;
    return Container(
      height: 46,
      color: const Color(0xFF2B2B2B),
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
        children: [
          for (int p = 0; p < _settings.pageCount; p++)
            Padding(
              padding: const EdgeInsets.only(right: 6),
              child: _PageTab(
                label: _settings.pageLabel(p, S.pageN),
                selected: p == _page,
                playing: _engine.anyActiveIn(p * n, (p + 1) * n),
                onTap: () => _selectPage(p),
                onLongPress: _stageLock ? null : () => _pageMenu(p),
              ),
            ),
          if (!_stageLock)
            IconButton(
              tooltip: S.addPage,
              onPressed: _addPage,
              icon: const Icon(Icons.add, color: Colors.white70),
              visualDensity: VisualDensity.compact,
            ),
        ],
      ),
    );
  }

  //----------------------------------------------------------------------------

  void _toggleStageLock() {
    setState(() {
      _stageLock = !_stageLock;
      GlobalPrefs.stageLock = _stageLock;
    });
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(duration: const Duration(seconds: 2), content: Text(_stageLock ? S.stageOn : S.stageOff)),
      );
  }

  //----------------------------------------------------------------------------

  Future<void> _goToNew() async {
    final ok = await confirm(context, content: Text(S.newProjectConfirm));
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
    final name = await askText(context, S.projectNamePrompt, initial: _settings.name);
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
    final File? settingsFile = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => LoadScreen(files)),
    );

    if (settingsFile != null) {
      try {
        final json = await settingsFile.readAsString();
        _settings = Settings.fromJson(settingsFile, json);
        await _reloadAll();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(S.cannotOpen(e))));
        }
      }
    }
    if (mounted) setState(() {});
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<T?> _withProgress<T>(String label, Future<T> Function() job) async {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => PopScope(
        canPop: false,
        child: AlertDialog(
          content: Row(
            children: [
              const CircularProgressIndicator(),
              const SizedBox(width: 20),
              Expanded(child: Text(label)),
            ],
          ),
        ),
      ),
    );
    try {
      return await job();
    } finally {
      if (mounted) Navigator.of(context, rootNavigator: true).pop();
    }
  }

  Future<void> _goToExport() async {
    try {
      final bytes = await _withProgress(S.exporting, () => ProjectArchive.export(_settings));
      if (bytes == null) return;
      final fileName = ProjectArchive.fileNameFor(_settings);
      final Uri? saved = await FilePicker.saveFile(
        fileName: fileName,
        bytes: bytes,
        mimeType: 'application/zip',
      );
      _snack(saved == null ? S.exportCancelled : S.exportDone(fileName));
    } catch (e) {
      _snack(S.exportFailed(e));
    }
  }

  Future<void> _goToImport() async {
    final PlatformFile? picked = await FilePicker.pickFile(type: FileType.any);
    if (picked == null) return;
    try {
      final result = await _withProgress(S.importing, () async {
        final bytes = await picked.readAsBytes();
        return ProjectArchive.import(bytes);
      });
      if (result == null) return;
      final (imported, count) = result;
      _settings = imported;
      preferences.setString(GlobalPrefs.lastFileKey, imported.file.absolute.path);
      await _reloadAll();
      if (mounted) setState(() {});
      _snack(S.importDone(imported.name, count));
    } on FormatException {
      _snack(S.notAProject);
    } catch (e) {
      _snack(S.importFailed(e));
    }
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
      case MenuAction.exportProject:
        _goToExport();
        break;
      case MenuAction.importProject:
        _goToImport();
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
        titleSpacing: 12,
        title: Text(_settings.name, overflow: TextOverflow.ellipsis, maxLines: 1),
        actions: [
          _StopButton(
            width: MediaQuery.sizeOf(context).width * 0.25,
            active: _engine.anyActive,
            fading: _engine.anyFading,
            onPressed: () => _engine.stopAll(),
          ),
          const SizedBox(width: 4),
          IconButton(
            tooltip: _stageLock ? S.stageOnTooltip : S.stageOffTooltip,
            icon: Icon(_stageLock ? Icons.lock : Icons.lock_open),
            color: _stageLock ? Colors.amber : null,
            onPressed: _toggleStageLock,
          ),
          if (!_stageLock)
            PopupMenuButton<MenuAction>(
              onSelected: _onMenu,
              itemBuilder: (context) => [
                PopupMenuItem(value: MenuAction.newProject, child: Text(S.newProject)),
                PopupMenuItem(value: MenuAction.saveProject, child: Text(S.saveProject)),
                PopupMenuItem(value: MenuAction.openProject, child: Text(S.openProject)),
                const PopupMenuDivider(),
                PopupMenuItem(value: MenuAction.exportProject, child: Text(S.exportProject)),
                PopupMenuItem(value: MenuAction.importProject, child: Text(S.importProject)),
                const PopupMenuDivider(),
                PopupMenuItem(value: MenuAction.settings, child: Text(S.settings)),
                PopupMenuItem(value: MenuAction.help, child: Text(S.help)),
                PopupMenuItem(value: MenuAction.about, child: Text(S.about)),
              ],
            ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Page tabs (hidden in stage mode when the project has a single page).
            if (_settings.pageCount > 1 || !_stageLock) _buildPageTabs(),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(spacing),
                child: Column(
                  children: List.generate(_settings.y, (row) {
                    return Expanded(
                      child: Row(
                        children: List.generate(_settings.x, (col) {
                          final int i = _settings.globalIndex(_page, row * _settings.x + col);
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
          ],
        ),
      ),
    );
  }
}

//==============================================================================

/// One page tab. A dot shows that a sound of this page is playing.
class _PageTab extends StatelessWidget {
  final String label;
  final bool selected;
  final bool playing;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  const _PageTab({
    required this.label,
    required this.selected,
    required this.playing,
    required this.onTap,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final Color fg = selected ? Colors.black : Colors.white;
    return Material(
      color: selected ? const Color(0xFFFB8C00) : const Color(0xFF4A4A4A),
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        onLongPress: onLongPress,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (playing) ...[
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: selected ? Colors.black : const Color(0xFF69F0AE),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
              ],
              Text(
                label,
                style: TextStyle(
                  color: fg,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  fontSize: 15,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

//==============================================================================

//==============================================================================

/// Big red STOP button, easy to hit in a hurry.
class _StopButton extends StatelessWidget {
  final double width;
  final bool active;
  final bool fading;
  final VoidCallback onPressed;

  const _StopButton({
    required this.width,
    required this.active,
    required this.fading,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    // Always a strong red; brighter while something plays, dark while fading.
    final Color bg = fading
        ? const Color(0xFF7F0000)
        : (active ? const Color(0xFFFF1744) : const Color(0xFFC62828));
    return Tooltip(
      message: S.stopTooltip,
      child: SizedBox(
        width: width,
        height: 46,
        child: FilledButton.icon(
          style: FilledButton.styleFrom(
            backgroundColor: bg,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            textStyle: Theme.of(context).textTheme.labelLarge
                ?.copyWith(fontSize: 20, fontWeight: FontWeight.w800, letterSpacing: 1.5),
          ),
          onPressed: onPressed,
          icon: Icon(fading ? Icons.flash_on : Icons.stop_rounded, size: 28),
          label: FittedBox(child: Text(fading ? S.cutNow : S.stop)),
        ),
      ),
    );
  }
}
