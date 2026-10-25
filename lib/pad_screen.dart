//==============================================================================
//    pad_screen.dart
//    Released under EUPL 1.2
//    Copyright Cherry Tree Studio 2021
//    Modifications Copyright IG Littoral Labs 2026
//==============================================================================

import 'dart:async';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import 'about_screen.dart';
import 'dialogs.dart';
import 'help_screen.dart';
import 'l10n.dart';
import 'load_screen.dart';
import 'main.dart';
import 'native_files.dart';
import 'pad_settings_screen.dart';
import 'pad_tile.dart';
import 'project_archive.dart';
import 'sample_engine.dart';
import 'sample_store.dart';
import 'settings.dart';
import 'settings_screen.dart';

//==============================================================================

enum MenuAction {
  newProject,
  saveProject,
  openProject,
  bulkImport,
  exportProject,
  importProject,
  settings,
  help,
  about,
}

//==============================================================================

class PadScreen extends StatefulWidget {
  final Settings initialSettings;

  /// Audio engine (tests can pass their own).
  final SampleEngine? engine;

  const PadScreen(this.initialSettings, {super.key, this.engine});

  @override
  State<PadScreen> createState() => _PadScreenState();
}

//==============================================================================

class _PadScreenState extends State<PadScreen> with SingleTickerProviderStateMixin {
  late Settings _settings;

  /// The project as edited on screen (tests).
  @visibleForTesting
  Settings get debugSettings => _settings;
  late final SampleEngine _engine = widget.engine ?? SampleEngine();
  late final Ticker _ticker;
  bool _stageLock = GlobalPrefs.stageLock;

  // Search
  bool _searching = false;
  final TextEditingController _searchCtl = TextEditingController();
  final FocusNode _searchFocus = FocusNode();
  List<int> _matches = const [];
  int _matchPos = 0;
  bool _justTyped = false; // first "Enter" after typing keeps the first result

  // A pad briefly framed after a tap in the "Now playing" strip.
  Object? _flashPad;
  Timer? _flashTimer;

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
    _flashTimer?.cancel();
    _searchCtl.dispose();
    _searchFocus.dispose();
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

  void _press(int idx) {
    final v = _engine.voice(idx);
    if (v != null && v.missing) {
      _showPadProblem(idx);
      return;
    }
    _engine.press(idx);
  }

  /// Plain-language reason for a pad with a red badge.
  String? _problemOf(int idx) {
    final v = _engine.voice(idx);
    if (v == null || !v.missing) return null;
    return v.fileMissing ? S.padProblemMissing : S.padProblemRefused(v.error ?? '?');
  }

  void _showPadProblem(int idx) {
    final msg = _problemOf(idx);
    if (msg == null) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          duration: const Duration(seconds: 8),
          content: Text('${_settings.padSettings[idx].caption} : $msg'),
          action: _stageLock ? null : SnackBarAction(label: S.padProblemFix, onPressed: () => _editPad(idx)),
        ),
      );
  }

  int get _page => _settings.currentPage.clamp(0, _settings.pageCount - 1);

  Future<void> _editPad(int padIdx) async {
    final int inPage = _settings.indexInPage(padIdx);
    final int row = inPage ~/ _settings.x;
    final int col = inPage % _settings.x;
    final before = PadSettings.copy(_settings.padSettings[padIdx]);

    final int? otherPad = await Navigator.push<int>(
      context,
      MaterialPageRoute(
        builder: (context) => PadSettingsScreen(col, row, padIdx, _settings, problem: _problemOf(padIdx)),
      ),
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

  //----------------------------------------------------------------------------
  // Search

  void _openSearch() {
    setState(() => _searching = true);
    _searchFocus.requestFocus();
  }

  void _closeSearch() {
    setState(() {
      _searching = false;
      _matches = const [];
      _matchPos = 0;
      _searchCtl.clear();
    });
    _searchFocus.unfocus();
  }

  /// New text: find all matches and jump to the first one.
  void _onSearchChanged(String text) {
    setState(() {
      _matches = _settings.searchPads(text);
      _matchPos = 0;
      _justTyped = true;
    });
    _showMatch();
  }

  /// Enter / arrows: go to the next (or previous) match.
  void _stepMatch(int delta) {
    if (_matches.isEmpty) return;
    setState(() => _matchPos = (_matchPos + delta) % _matches.length);
    _showMatch();
  }

  void _showMatch() {
    if (_matches.isEmpty) return;
    final page = _settings.pageOf(_matches[_matchPos]);
    if (page != _page) setState(() => _settings.currentPage = page);
  }

  /// Keeps the results right after a pad was renamed / moved during a search.
  void _refreshMatches() {
    if (!_searching || _searchCtl.text.trim().isEmpty) return;
    final fresh = _settings.searchPads(_searchCtl.text);
    if (fresh.length != _matches.length || !fresh.every(_matches.contains)) {
      _matches = fresh;
      if (_matchPos >= _matches.length) _matchPos = 0;
    }
  }

  int _highlightOf(int i) {
    if (_flashPad != null && identical(_flashPad, _settings.padSettings[i])) return 2;
    if (!_searching || _matches.isEmpty) return 0;
    if (_matches[_matchPos] == i) return 2;
    return _matches.contains(i) ? 1 : 0;
  }

  Widget _buildSearchBar() {
    final bool hasText = _searchCtl.text.trim().isNotEmpty;
    final bool none = hasText && _matches.isEmpty;
    return Container(
      color: const Color(0xFF1F2A3A),
      padding: const EdgeInsets.fromLTRB(10, 4, 4, 4),
      child: Row(
        children: [
          const Icon(Icons.search, color: PadTile.searchColor),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: _searchCtl,
              focusNode: _searchFocus,
              style: const TextStyle(color: Colors.white, fontSize: 17),
              cursorColor: Colors.white,
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                isDense: true,
                border: InputBorder.none,
                hintText: S.searchHint,
                hintStyle: const TextStyle(color: Colors.white54),
              ),
              onChanged: _onSearchChanged,
              onSubmitted: (_) {
                if (_justTyped) {
                  _justTyped = false;
                } else {
                  _stepMatch(1);
                }
              },
            ),
          ),
          if (hasText)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: Text(
                none ? S.searchNone : '${_matchPos + 1}/${_matches.length}',
                style: TextStyle(
                  color: none ? Colors.redAccent : Colors.white,
                  fontWeight: FontWeight.w600,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ),
          if (_matches.length > 1) ...[
            IconButton(
              tooltip: S.searchPrev,
              visualDensity: VisualDensity.compact,
              color: Colors.white,
              icon: const Icon(Icons.keyboard_arrow_up),
              onPressed: () => _stepMatch(-1),
            ),
            IconButton(
              tooltip: S.searchNext,
              visualDensity: VisualDensity.compact,
              color: Colors.white,
              icon: const Icon(Icons.keyboard_arrow_down),
              onPressed: () => _stepMatch(1),
            ),
          ],
          IconButton(
            tooltip: S.searchClose,
            visualDensity: VisualDensity.compact,
            color: Colors.white70,
            icon: const Icon(Icons.close),
            onPressed: _closeSearch,
          ),
        ],
      ),
    );
  }

  //----------------------------------------------------------------------------
  // "Now playing" strip and recent sounds

  /// Shows the page of pad [i] and frames the pad for a moment.
  void _revealPad(int i) {
    _flashTimer?.cancel();
    setState(() {
      _settings.currentPage = _settings.pageOf(i);
      _flashPad = _settings.padSettings[i];
    });
    _flashTimer = Timer(const Duration(milliseconds: 1500), () {
      if (mounted) setState(() => _flashPad = null);
    });
  }

  Widget _buildNowPlaying() {
    final active = _engine.activeIndices();
    return Container(
      height: 50,
      color: const Color(0xFF1B1B1B),
      child: Row(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Tooltip(
              message: S.nowPlaying,
              child: const Icon(Icons.graphic_eq, color: Color(0xFF69F0AE), size: 22),
            ),
          ),
          Expanded(
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(vertical: 6),
              itemCount: active.length,
              separatorBuilder: (_, _) => const SizedBox(width: 6),
              itemBuilder: (_, k) {
                final i = active[k];
                final v = _engine.voice(i)!;
                final pad = _settings.padSettings[i];
                final String time = v.state == VoiceState.paused
                    ? S.paused
                    : pad.looped
                    ? PadTile.formatDuration(v.position)
                    : (v.remaining != null ? '-${PadTile.formatDuration(v.remaining!)}' : '');
                return Material(
                  color: pad.color,
                  borderRadius: BorderRadius.circular(8),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(8),
                    onTap: () => _revealPad(i),
                    child: Padding(
                      padding: const EdgeInsets.only(left: 10),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 150),
                            child: Text(
                              pad.caption,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(color: pad.textColor, fontWeight: FontWeight.w600),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            time,
                            style: TextStyle(
                              color: pad.textColor,
                              fontFeatures: const [FontFeature.tabularFigures()],
                              fontSize: 13,
                            ),
                          ),
                          IconButton(
                            tooltip: S.stopThis,
                            visualDensity: VisualDensity.compact,
                            iconSize: 22,
                            color: pad.textColor,
                            icon: Icon(v.state == VoiceState.fading ? Icons.flash_on : Icons.stop_circle),
                            onPressed: () => _engine.stopPad(i),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecent(List<int> recent) {
    return Container(
      height: 44,
      color: const Color(0xFF262626),
      child: Row(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Tooltip(
              message: S.recentSounds,
              child: const Icon(Icons.history, color: Colors.white60, size: 22),
            ),
          ),
          Expanded(
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(vertical: 6),
              itemCount: recent.length,
              separatorBuilder: (_, _) => const SizedBox(width: 6),
              itemBuilder: (_, k) {
                final i = recent[k];
                final pad = _settings.padSettings[i];
                final chip = Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(color: pad.color, borderRadius: BorderRadius.circular(8)),
                  constraints: const BoxConstraints(maxWidth: 170),
                  child: Text(
                    pad.caption,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: pad.textColor, fontWeight: FontWeight.w600),
                  ),
                );
                // Same trigger as the pad itself (finger down in stage mode).
                return _stageLock
                    ? Listener(behavior: HitTestBehavior.opaque, onPointerDown: (_) => _press(i), child: chip)
                    : GestureDetector(onTap: () => _press(i), child: chip);
              },
            ),
          ),
        ],
      ),
    );
  }

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

  /// Runs [job] behind a modal progress dialog. The job reports its progress
  /// through the given notifier ("label", done, total).
  Future<T?> _withProgress<T>(String label, Future<T> Function(ValueNotifier<(String, int, int)>) job) async {
    final progress = ValueNotifier<(String, int, int)>((label, 0, 0));
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => PopScope(
        canPop: false,
        child: AlertDialog(
          content: ValueListenableBuilder<(String, int, int)>(
            valueListenable: progress,
            builder: (_, v, _) {
              final (text, done, total) = v;
              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(text),
                  const SizedBox(height: 16),
                  LinearProgressIndicator(value: total > 0 ? done / total : null),
                  if (total > 0) ...[
                    const SizedBox(height: 8),
                    Text(S.progressCount(done, total), style: Theme.of(context).textTheme.bodySmall),
                  ],
                ],
              );
            },
          ),
        ),
      ),
    );
    try {
      return await job(progress);
    } finally {
      if (mounted) Navigator.of(context, rootNavigator: true).pop();
    }
  }

  Future<void> _goToExport() async {
    final fileName = ProjectArchive.fileNameFor(_settings);
    final String zipPath;
    try {
      // Old exports are removed first: they live in the app cache only.
      final exportDir = Directory(p.join((await getTemporaryDirectory()).path, 'exports'));
      if (await exportDir.exists()) await exportDir.delete(recursive: true);
      zipPath = p.join(exportDir.path, fileName);
      final ok = await _withProgress(S.exporting, (progress) async {
        await ProjectArchive.exportToFile(
          _settings,
          zipPath,
          onProgress: (d, t) => progress.value = (S.exporting, d, t),
        );
        return true;
      });
      if (ok != true || !mounted) return;
    } catch (e) {
      _snack(S.exportFailed(e));
      return;
    }

    // Where should the file go?
    final choice = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Text(
                S.exportReady(fileName, _fileSize(zipPath)),
                style: Theme.of(ctx).textTheme.titleSmall,
              ),
            ),
            ListTile(
              leading: const Icon(Icons.save_alt),
              title: Text(S.exportSave),
              subtitle: Text(S.exportSaveHint),
              onTap: () => Navigator.pop(ctx, 'save'),
            ),
            ListTile(
              leading: const Icon(Icons.share),
              title: Text(S.exportShare),
              subtitle: Text(S.exportShareHint),
              onTap: () => Navigator.pop(ctx, 'share'),
            ),
          ],
        ),
      ),
    );
    try {
      if (choice == 'save') {
        final saved = await NativeFiles.saveFile(zipPath, fileName);
        _snack(saved ? S.exportDone(fileName) : S.exportCancelled);
      } else if (choice == 'share') {
        await NativeFiles.shareFile(zipPath, title: fileName);
      }
    } catch (e) {
      _snack(S.exportFailed(e));
    }
  }

  /// Several sounds at once: they fill the empty pads of the current page,
  /// then of the following pages (new pages are added if the user agrees).
  Future<void> _bulkImport() async {
    final List<PlatformFile> picked = List.of(await FilePicker.pickFiles(type: FileType.audio));
    if (picked.isEmpty || !mounted) return;
    // Alphabetical order (natural: "2" before "10"), so the result is predictable.
    picked.sort((a, b) => _naturalCompare(a.name.toLowerCase(), b.name.toLowerCase()));

    List<int> slots = _settings.emptySlotsFrom(_page);
    int count = picked.length;
    if (slots.length < count) {
      final int missing = count - slots.length;
      final int pagesNeeded = (missing / _settings.padsPerPage).ceil();
      final choice = await showDialog<String>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(S.bulkTooMany(count, slots.length)),
          content: Text(S.bulkAddPages(pagesNeeded)),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: Text(S.cancel)),
            if (slots.isNotEmpty)
              TextButton(
                onPressed: () => Navigator.pop(ctx, 'fit'),
                child: Text(S.bulkOnlyFirst(slots.length)),
              ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, 'add'),
              child: Text(S.bulkAddPagesButton(pagesNeeded)),
            ),
          ],
        ),
      );
      if (choice == null || !mounted) return;
      if (choice == 'add') {
        await _changePages(() {
          for (int i = 0; i < pagesNeeded; i++) {
            _settings.addPage();
          }
        });
        slots = _settings.emptySlotsFrom(_page);
      } else {
        count = slots.length;
      }
    }

    final List<int> filled = [];
    int failed = 0;
    await _withProgress(S.bulkImporting, (progress) async {
      for (int k = 0; k < count; k++) {
        progress.value = (S.bulkImporting, k, count);
        final f = picked[k];
        final int index = slots[k];
        try {
          final stored = await SampleStore.import(f.name, f.readAsByteStream(), length: f.lengthSync());
          final pad = _settings.padSettings[index];
          pad.sample = stored;
          pad.caption = p.basenameWithoutExtension(f.name);
          // "Long sound" chosen from the real length (music vs short jingle).
          final d = await SampleEngine.probeDuration(stored);
          pad.durationMs = d?.inMilliseconds ?? 0;
          pad.long = d == null ? (f.lengthSync() ?? 0) > 1024 * 1024 : d.inMilliseconds > 5000;
          filled.add(index);
        } catch (_) {
          failed++;
        }
      }
      progress.value = (S.bulkImporting, count, count);
      await _settings.save();
      for (final i in filled) {
        await _engine.reloadPad(i, _settings.padSettings[i]);
      }
      _saveIfDirty();
      return true;
    });
    if (!mounted) return;
    setState(() {});
    final pages = filled
        .map(_settings.pageOf)
        .toSet()
        .map((pg) => _settings.pageLabel(pg, S.pageN))
        .join(', ');
    _snack(S.bulkDone(filled.length, pages, failed));
  }

  static int _naturalCompare(String a, String b) {
    final re = RegExp(r'(\d+)|(\D+)');
    final ma = re.allMatches(a).toList(), mb = re.allMatches(b).toList();
    for (int i = 0; i < ma.length && i < mb.length; i++) {
      final x = ma[i].group(0)!, y = mb[i].group(0)!;
      final nx = int.tryParse(x), ny = int.tryParse(y);
      final c = (nx != null && ny != null) ? nx.compareTo(ny) : x.compareTo(y);
      if (c != 0) return c;
    }
    return ma.length.compareTo(mb.length);
  }

  String _fileSize(String path) {
    final int bytes = File(path).lengthSync();
    if (bytes >= 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} Go';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(0)} Mo';
  }

  Future<void> _goToImport() async {
    final PlatformFile? picked = await FilePicker.pickFile(type: FileType.any);
    if (picked == null) return;
    File? tmpCopy;
    try {
      final result = await _withProgress(S.importing, (progress) async {
        // Get the zip as a real file, copied in a stream if needed (never in memory).
        String? zipPath = picked.path;
        if (zipPath == null || !await File(zipPath).exists()) {
          progress.value = (S.importCopying, 0, 0);
          tmpCopy = File(p.join((await getTemporaryDirectory()).path, 'import.zip'));
          final sink = tmpCopy!.openWrite();
          try {
            await sink.addStream(picked.readAsByteStream());
          } finally {
            await sink.close();
          }
          zipPath = tmpCopy!.path;
        }
        return ProjectArchive.importFromFile(
          zipPath,
          onProgress: (d, t) => progress.value = (S.importing, d, t),
        );
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
    } finally {
      if (tmpCopy != null && await tmpCopy!.exists()) await tmpCopy!.delete();
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
      case MenuAction.bulkImport:
        _bulkImport();
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
    _refreshMatches();
    // Recent sounds that still exist in this project, as pad indexes.
    final List<int> recent = [
      for (final pad in _engine.recent)
        if (_settings.padSettings.indexWhere((p) => identical(p, pad)) case final int i when i >= 0) i,
    ];

    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 60, 60, 60),
      appBar: AppBar(
        titleSpacing: 12,
        title: Text(_settings.name, overflow: TextOverflow.ellipsis, maxLines: 1),
        actions: [
          IconButton(
            tooltip: S.search,
            icon: Icon(_searching ? Icons.search_off : Icons.search),
            onPressed: _searching ? _closeSearch : _openSearch,
          ),
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
                PopupMenuItem(value: MenuAction.bulkImport, child: Text(S.bulkImport)),
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
            if (_searching) _buildSearchBar(),
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
                                // One identity per pad: switching page shows the new pads at once
                                // (no colour fade from the pads of the previous page).
                                key: ValueKey(_settings.padSettings[i]),
                                settings: _settings.padSettings[i],
                                voice: _engine.voice(i),
                                fontSize: fontSize,
                                showRemaining: showRemaining,
                                stageLock: _stageLock,
                                onTrigger: () => _press(i),
                                onEdit: () => _editPad(i),
                                highlight: _highlightOf(i),
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
            if (GlobalPrefs.showNowPlaying && _engine.anyActive) _buildNowPlaying(),
            if (GlobalPrefs.showRecent && recent.isNotEmpty) _buildRecent(recent),
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
