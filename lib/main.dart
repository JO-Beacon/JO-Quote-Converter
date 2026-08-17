import 'dart:async';
import 'dart:io';
import 'dart:ui' show AppExitResponse;

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import 'archive_service.dart';
import 'draft_store.dart';
import 'history_store.dart';
import 'quote_converter.dart';
import 'windows_data_migrator.dart';

const appVersion = '0.0.3+3';
const appAuthor = 'JO-Beacon';
final appAuthorUrl = Uri.parse('https://github.com/JO-Beacon/');

enum AppPalette { red, yellow, green, blue, purple, gray }

extension AppPaletteStyle on AppPalette {
  String get label => switch (this) {
    AppPalette.red => '红',
    AppPalette.yellow => '黄',
    AppPalette.green => '绿',
    AppPalette.blue => '蓝',
    AppPalette.purple => '紫',
    AppPalette.gray => '灰',
  };

  Color get color => switch (this) {
    AppPalette.red => const Color(0xFFCC4C45),
    AppPalette.yellow => const Color(0xFFD6A626),
    AppPalette.green => const Color(0xFF4A8F5B),
    AppPalette.blue => const Color(0xFF4B73B5),
    AppPalette.purple => const Color(0xFF835DA0),
    AppPalette.gray => const Color(0xFF777777),
  };
}

Future<void> main(List<String> arguments) async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await migratePreviousWindowsPreferences();
  } catch (_) {
    // Migration failure must not prevent the editor from opening.
  }
  runApp(QuoteConverterApp(startupArchivePath: _startupArchivePath(arguments)));
}

String? _startupArchivePath(Iterable<String> arguments) {
  if (!Platform.isWindows) return null;
  for (final argument in arguments) {
    if (argument.toLowerCase().endsWith('.$archiveExtension')) {
      return argument;
    }
  }
  return null;
}

class QuoteConverterApp extends StatefulWidget {
  const QuoteConverterApp({
    super.key,
    this.historyStore,
    this.archiveService,
    this.draftStore,
    this.startupArchivePath,
  });

  final HistoryStore? historyStore;
  final ArchiveService? archiveService;
  final DraftStore? draftStore;
  final String? startupArchivePath;

  @override
  State<QuoteConverterApp> createState() => _QuoteConverterAppState();
}

class _QuoteConverterAppState extends State<QuoteConverterApp> {
  late final DraftStore _draftStore = widget.draftStore ?? DraftStore();
  ThemeMode _themeMode = ThemeMode.system;
  AppPalette _palette = AppPalette.gray;

  @override
  void initState() {
    super.initState();
    unawaited(_restoreThemeMode());
    unawaited(_restorePalette());
  }

  Future<void> _restoreThemeMode() async {
    try {
      final savedMode = await _draftStore.loadThemeMode();
      if (!mounted || savedMode == null) return;
      for (final mode in ThemeMode.values) {
        if (mode.name == savedMode) {
          setState(() => _themeMode = mode);
          return;
        }
      }
    } catch (_) {
      // An unavailable preference store should not block the application.
    }
  }

  void _changeThemeMode(ThemeMode mode) {
    setState(() => _themeMode = mode);
    unawaited(_draftStore.saveThemeMode(mode.name));
  }

  Future<void> _restorePalette() async {
    try {
      final savedPalette = await _draftStore.loadPalette();
      if (!mounted || savedPalette == null) return;
      for (final palette in AppPalette.values) {
        if (palette.name == savedPalette) {
          setState(() => _palette = palette);
          return;
        }
      }
    } catch (_) {
      // An unavailable preference store should not block the application.
    }
  }

  void _changePalette(AppPalette palette) {
    setState(() => _palette = palette);
    unawaited(_draftStore.savePalette(palette.name));
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'JO-引号转换',
      debugShowCheckedModeBanner: false,
      locale: const Locale('zh', 'CN'),
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      supportedLocales: const [Locale('zh', 'CN')],
      theme: _buildAppTheme(Brightness.light, _palette),
      darkTheme: _buildAppTheme(Brightness.dark, _palette),
      themeMode: _themeMode,
      home: ConverterPage(
        historyStore: widget.historyStore,
        archiveService: widget.archiveService,
        draftStore: _draftStore,
        themeMode: _themeMode,
        palette: _palette,
        onThemeModeChanged: _changeThemeMode,
        onPaletteChanged: _changePalette,
        startupArchivePath: widget.startupArchivePath,
      ),
    );
  }
}

ThemeData _buildAppTheme(Brightness brightness, AppPalette palette) {
  final isDark = brightness == Brightness.dark;
  final isGray = palette == AppPalette.gray;
  final colorScheme = ColorScheme.fromSeed(
    seedColor: palette.color,
    brightness: brightness,
    dynamicSchemeVariant: isGray
        ? DynamicSchemeVariant.monochrome
        : DynamicSchemeVariant.tonalSpot,
    surface: isGray
        ? (isDark ? const Color(0xFF1A1A1A) : const Color(0xFFFAFAFA))
        : (isDark ? const Color(0xFF171A19) : const Color(0xFFF8FAF8)),
  );
  final scaffoldColor = isGray
      ? (isDark ? const Color(0xFF121212) : const Color(0xFFF5F5F5))
      : (isDark ? const Color(0xFF101312) : const Color(0xFFF3F5F3));
  final inputFillColor = isGray && isDark
      ? const Color(0xFF1A1A1A)
      : (isDark ? const Color(0xFF1A1E1C) : Colors.white);
  final inputBorderColor = isGray
      ? (isDark ? const Color(0xFF424242) : const Color(0xFFD8D8D8))
      : (isDark ? const Color(0xFF3A423F) : const Color(0xFFD5DAD7));

  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: colorScheme,
    scaffoldBackgroundColor: scaffoldColor,
    fontFamily: 'SourceHanSansSC',
    appBarTheme: AppBarTheme(
      centerTitle: false,
      elevation: 0,
      scrolledUnderElevation: 0,
      backgroundColor: scaffoldColor,
      foregroundColor: colorScheme.onSurface,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: inputFillColor,
      contentPadding: const EdgeInsets.all(16),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(6),
        borderSide: BorderSide(color: inputBorderColor),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(6),
        borderSide: BorderSide(color: colorScheme.primary, width: 1.5),
      ),
    ),
    tooltipTheme: const TooltipThemeData(
      waitDuration: Duration(milliseconds: 450),
    ),
  );
}

class ConverterPage extends StatefulWidget {
  const ConverterPage({
    super.key,
    this.historyStore,
    this.archiveService,
    this.draftStore,
    required this.themeMode,
    required this.palette,
    required this.onThemeModeChanged,
    required this.onPaletteChanged,
    this.startupArchivePath,
  });

  final HistoryStore? historyStore;
  final ArchiveService? archiveService;
  final DraftStore? draftStore;
  final ThemeMode themeMode;
  final AppPalette palette;
  final ValueChanged<ThemeMode> onThemeModeChanged;
  final ValueChanged<AppPalette> onPaletteChanged;
  final String? startupArchivePath;

  @override
  State<ConverterPage> createState() => _ConverterPageState();
}

class _ConverterPageState extends State<ConverterPage> {
  final _inputController = TextEditingController();
  final _outputController = TextEditingController();
  final _inputFocusNode = FocusNode();
  late final DraftStore _draftStore;
  late final HistoryStore _historyStore;
  late final ArchiveService _archiveService;
  late final AppLifecycleListener _lifecycleListener;
  Future<void> _saveQueue = Future.value();
  Future<void> _historySaveQueue = Future.value();
  Timer? _saveTimer;
  bool _listenersAttached = false;
  bool _isRestoringDraft = true;
  bool _isLoadingHistory = true;
  bool _historyLoadFailed = false;
  bool _excludeMarkdownCode = true;
  bool _useHeuristics = true;
  bool _keyboardShortcutsEnabled = true;
  List<ConversionHistoryEntry> _history = [];

  @override
  void initState() {
    super.initState();
    _historyStore = widget.historyStore ?? HistoryStore();
    _archiveService = widget.archiveService ?? ArchiveService();
    _draftStore = widget.draftStore ?? DraftStore();
    _lifecycleListener = AppLifecycleListener(
      onHide: _saveForLifecycleChange,
      onPause: _saveForLifecycleChange,
      onDetach: _saveForLifecycleChange,
      onExitRequested: _handleExitRequested,
    );
    unawaited(_restoreDraft());
  }

  @override
  void dispose() {
    _saveTimer?.cancel();
    if (_listenersAttached) {
      _inputController.removeListener(_handleTextChanged);
      _outputController.removeListener(_handleTextChanged);
    }
    _lifecycleListener.dispose();
    _inputController.dispose();
    _outputController.dispose();
    _inputFocusNode.dispose();
    super.dispose();
  }

  Future<void> _restoreDraft() async {
    SavedDraft? draft;
    bool? keyboardShortcutsEnabled;
    List<ConversionHistoryEntry>? history;
    final historyFuture = _historyStore.load();
    final keyboardShortcutsFuture = _draftStore.loadKeyboardShortcutsEnabled();
    try {
      draft = await _draftStore.load();
    } catch (_) {
      // A corrupt or unavailable preference store should not block the editor.
    }
    try {
      keyboardShortcutsEnabled = await keyboardShortcutsFuture;
    } catch (_) {
      // Keep shortcuts enabled when the preference store is unavailable.
    }
    try {
      history = await historyFuture;
    } catch (_) {
      _historyLoadFailed = true;
    }
    if (!mounted) return;
    if (draft != null) {
      _inputController.text = draft.input;
      _outputController.text = draft.output;
      _excludeMarkdownCode = draft.excludeMarkdownCode;
      _useHeuristics = draft.useHeuristics;
    }
    if (keyboardShortcutsEnabled != null) {
      _keyboardShortcutsEnabled = keyboardShortcutsEnabled;
    }
    if (history != null) _history = history;
    _isLoadingHistory = false;
    _inputController.addListener(_handleTextChanged);
    _outputController.addListener(_handleTextChanged);
    _listenersAttached = true;
    setState(() => _isRestoringDraft = false);
    final startupArchivePath = widget.startupArchivePath;
    if (startupArchivePath != null) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => unawaited(_importStartupArchive(startupArchivePath)),
      );
    }
  }

  Future<void> _importStartupArchive(String path) async {
    try {
      final document = await _archiveService.decodeFilePath(path);
      if (!mounted) return;
      final selection = await showDialog<ArchiveImportSelection>(
        context: context,
        builder: (context) => _ArchiveImportDialog(document: document),
      );
      if (selection == null || !mounted) return;
      await _importArchive(document, selection);
    } on ArchiveFormatException catch (error) {
      if (mounted) _showMessage(error.message);
    } catch (_) {
      if (mounted) _showMessage('存档读取失败');
    }
  }

  void _handleTextChanged() {
    setState(() {});
    _scheduleSave();
  }

  void _scheduleSave() {
    _saveTimer?.cancel();
    _saveTimer = Timer(
      const Duration(milliseconds: 300),
      () => unawaited(_enqueueSave()),
    );
  }

  Future<void> _enqueueSave() {
    _saveTimer?.cancel();
    final snapshot = SavedDraft(
      input: _inputController.text,
      output: _outputController.text,
      excludeMarkdownCode: _excludeMarkdownCode,
      useHeuristics: _useHeuristics,
    );
    _saveQueue = _saveQueue
        .then((_) => _draftStore.save(snapshot))
        .catchError((Object _) {});
    return _saveQueue;
  }

  void _saveForLifecycleChange() => unawaited(_enqueueSave());

  Future<AppExitResponse> _handleExitRequested() async {
    await _enqueueSave();
    await _historySaveQueue;
    await _historyStore.close();
    return AppExitResponse.exit;
  }

  Future<void> _convert() async {
    final result = QuoteConverter.convert(
      _inputController.text,
      excludeMarkdownCode: _excludeMarkdownCode,
      useHeuristics: _useHeuristics,
    );
    _outputController.value = TextEditingValue(
      text: result,
      selection: TextSelection.collapsed(offset: result.length),
    );
    final entry = ConversionHistoryEntry(
      input: _inputController.text,
      output: result,
      createdAt: DateTime.now(),
    );
    setState(() {
      _history = [entry, ..._history];
      _historyLoadFailed = false;
    });

    final save = _historySaveQueue.then((_) => _historyStore.add(entry));
    _historySaveQueue = save.catchError((Object _) {});
    try {
      await save;
      final storedHistory = await _historyStore.load();
      if (!mounted) return;
      setState(() {
        _history = storedHistory;
        _historyLoadFailed = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _historyLoadFailed = true);
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(content: Text('历史记录保存失败，本次记录尚未写入磁盘')));
    }
  }

  Future<void> _copyResult() async {
    if (_outputController.text.isEmpty) return;
    await Clipboard.setData(ClipboardData(text: _outputController.text));
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(const SnackBar(content: Text('结果已复制')));
  }

  void _clear() {
    _inputController.clear();
    _outputController.clear();
    _inputFocusNode.requestFocus();
  }

  Future<void> _confirmClear() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        final colorScheme = Theme.of(context).colorScheme;
        return AlertDialog(
          icon: Icon(Icons.warning_amber_rounded, color: colorScheme.error),
          title: const Text('确认清空？'),
          content: const Text('原文和转换结果都会被清空。'),
          actions: [
            TextButton(
              key: const Key('cancelClearButton'),
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('取消'),
            ),
            FilledButton(
              key: const Key('confirmClearButton'),
              onPressed: () => Navigator.of(context).pop(true),
              style: FilledButton.styleFrom(
                backgroundColor: colorScheme.error,
                foregroundColor: colorScheme.onError,
              ),
              child: const Text('清空'),
            ),
          ],
        );
      },
    );
    if (confirmed == true && mounted) _clear();
  }

  Future<bool> _restoreHistoryEntry(ConversionHistoryEntry entry) async {
    final workspaceIsNotEmpty =
        _inputController.text.isNotEmpty || _outputController.text.isNotEmpty;
    if (workspaceIsNotEmpty) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          icon: const Icon(Icons.restore_rounded),
          title: const Text('恢复历史记录？'),
          content: const Text('当前工作区内容将被覆盖。'),
          actions: [
            TextButton(
              key: const Key('cancelRestoreButton'),
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('取消'),
            ),
            FilledButton.icon(
              key: const Key('confirmRestoreButton'),
              onPressed: () => Navigator.of(context).pop(true),
              icon: const Icon(Icons.restore_rounded),
              label: const Text('恢复'),
            ),
          ],
        ),
      );
      if (confirmed != true || !mounted) return false;
    }

    _inputController.value = TextEditingValue(
      text: entry.input,
      selection: TextSelection.collapsed(offset: entry.input.length),
    );
    _outputController.value = TextEditingValue(
      text: entry.output,
      selection: TextSelection.collapsed(offset: entry.output.length),
    );
    await _enqueueSave();
    if (!mounted) return false;
    _inputFocusNode.requestFocus();
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(const SnackBar(content: Text('已恢复到工作区')));
    return true;
  }

  Future<bool> _deleteHistoryEntry(ConversionHistoryEntry entry) async {
    try {
      await _historySaveQueue;
      await _historyStore.delete(entry);
      final storedHistory = await _historyStore.load();
      if (!mounted) return false;
      setState(() => _history = storedHistory);
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> _clearHistory() async {
    try {
      await _historySaveQueue;
      await _historyStore.clear();
      if (!mounted) return false;
      setState(() {
        _history = [];
        _historyLoadFailed = false;
      });
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> _openHistory() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => HistoryPage(
          initialEntries: _history,
          isLoading: _isLoadingHistory,
          hasStorageError: _historyLoadFailed,
          onRestore: _restoreHistoryEntry,
          onDelete: _deleteHistoryEntry,
          onClear: _clearHistory,
          onStorageSize: _historyStore.storageSizeBytes,
        ),
      ),
    );
  }

  Future<void> _openSettings() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => SettingsPage(
          initialExcludeMarkdownCode: _excludeMarkdownCode,
          initialUseHeuristics: _useHeuristics,
          initialThemeMode: widget.themeMode,
          initialPalette: widget.palette,
          initialKeyboardShortcutsEnabled: _keyboardShortcutsEnabled,
          onExcludeMarkdownCodeChanged: (value) {
            setState(() => _excludeMarkdownCode = value);
            _scheduleSave();
          },
          onUseHeuristicsChanged: (value) {
            setState(() => _useHeuristics = value);
            _scheduleSave();
          },
          onThemeModeChanged: widget.onThemeModeChanged,
          onPaletteChanged: widget.onPaletteChanged,
          onKeyboardShortcutsEnabledChanged: (enabled) {
            setState(() => _keyboardShortcutsEnabled = enabled);
            unawaited(_draftStore.saveKeyboardShortcutsEnabled(enabled));
          },
          onExportArchive: _exportArchive,
          onPickArchive: _pickArchive,
          onImportArchive: _importArchive,
          onListAutomaticBackups: _archiveService.listAutomaticBackups,
          onDeleteAutomaticBackup: _archiveService.deleteAutomaticBackup,
          onClearAutomaticBackups: _archiveService.clearAutomaticBackups,
          onRestoreAutomaticBackup: (backup) => _importArchive(
            backup.document!,
            const ArchiveImportSelection(ArchiveImportMode.overwrite),
            successMessage: '自动备份已恢复',
          ),
        ),
      ),
    );
  }

  Future<ArchiveSnapshot> _currentArchiveSnapshot() async {
    await _historySaveQueue;
    return ArchiveSnapshot(
      draft: SavedDraft(
        input: _inputController.text,
        output: _outputController.text,
        excludeMarkdownCode: _excludeMarkdownCode,
        useHeuristics: _useHeuristics,
      ),
      themeMode: widget.themeMode.name,
      palette: widget.palette.name,
      keyboardShortcutsEnabled: _keyboardShortcutsEnabled,
      history: List.of(_history),
    );
  }

  Future<bool> _exportArchive() async {
    try {
      await _enqueueSave();
      final exported = await _archiveService.exportWithPicker(
        snapshot: await _currentArchiveSnapshot(),
        appVersion: appVersion,
      );
      if (exported && mounted) _showMessage('存档导出成功');
      return exported;
    } catch (_) {
      if (mounted) _showMessage('存档导出失败');
      return false;
    }
  }

  Future<ArchiveDocument?> _pickArchive() async {
    try {
      return await _archiveService.pickAndDecode();
    } on ArchiveFormatException catch (error) {
      if (mounted) _showMessage(error.message);
      return null;
    } catch (_) {
      if (mounted) _showMessage('存档读取失败');
      return null;
    }
  }

  Future<bool> _importArchive(
    ArchiveDocument document,
    ArchiveImportSelection selection, {
    String successMessage = '存档导入成功',
  }) async {
    final previousSnapshot = await _currentArchiveSnapshot();
    try {
      await _archiveService.createAutomaticBackup(
        snapshot: previousSnapshot,
        appVersion: appVersion,
      );

      if (selection.isOverwrite) {
        await _historyStore.replaceAll(document.snapshot.history);
      } else {
        await _historyStore.merge(document.snapshot.history);
      }

      final workspaceIsEmpty =
          previousSnapshot.draft.input.trim().isEmpty &&
          previousSnapshot.draft.output.trim().isEmpty;
      final shouldRestoreWorkspace = selection.isOverwrite || workspaceIsEmpty;
      final nextDraft = shouldRestoreWorkspace
          ? document.snapshot.draft
          : previousSnapshot.draft;
      final nextThemeMode = selection.isOverwrite
          ? document.snapshot.themeMode
          : previousSnapshot.themeMode;
      final nextPalette = selection.isOverwrite
          ? document.snapshot.palette
          : previousSnapshot.palette;
      final nextKeyboardShortcutsEnabled = selection.isOverwrite
          ? document.snapshot.keyboardShortcutsEnabled
          : previousSnapshot.keyboardShortcutsEnabled;
      final nextBehaviorDraft = SavedDraft(
        input: nextDraft.input,
        output: nextDraft.output,
        excludeMarkdownCode: selection.isOverwrite
            ? document.snapshot.draft.excludeMarkdownCode
            : previousSnapshot.draft.excludeMarkdownCode,
        useHeuristics: selection.isOverwrite
            ? document.snapshot.draft.useHeuristics
            : previousSnapshot.draft.useHeuristics,
      );
      await _draftStore.saveArchiveState(
        draft: nextBehaviorDraft,
        themeMode: nextThemeMode,
        palette: nextPalette,
        keyboardShortcutsEnabled: nextKeyboardShortcutsEnabled,
      );

      final storedHistory = await _historyStore.load();
      if (!mounted) return false;
      final importedThemeMode = ThemeMode.values.firstWhere(
        (mode) => mode.name == nextThemeMode,
      );
      final importedPalette = AppPalette.values.firstWhere(
        (palette) => palette.name == nextPalette,
      );
      setState(() {
        _inputController.text = nextBehaviorDraft.input;
        _outputController.text = nextBehaviorDraft.output;
        _excludeMarkdownCode = nextBehaviorDraft.excludeMarkdownCode;
        _useHeuristics = nextBehaviorDraft.useHeuristics;
        _keyboardShortcutsEnabled = nextKeyboardShortcutsEnabled;
        _history = storedHistory;
        _historyLoadFailed = false;
      });
      if (selection.isOverwrite) {
        widget.onThemeModeChanged(importedThemeMode);
        widget.onPaletteChanged(importedPalette);
      }
      _showMessage(successMessage);
      return true;
    } catch (_) {
      try {
        await _historyStore.replaceAll(previousSnapshot.history);
        await _draftStore.saveArchiveState(
          draft: previousSnapshot.draft,
          themeMode: previousSnapshot.themeMode,
          palette: previousSnapshot.palette,
          keyboardShortcutsEnabled: previousSnapshot.keyboardShortcutsEnabled,
        );
      } catch (_) {
        // The automatic backup remains available if in-process rollback fails.
      }
      if (mounted) _showMessage('存档导入失败，已恢复导入前的数据');
      return false;
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final isCompact = screenWidth < 760;
    final showTitleIcon = screenWidth >= 360;

    return Shortcuts(
      shortcuts: _keyboardShortcutsEnabled
          ? const {
              SingleActivator(LogicalKeyboardKey.enter, control: true):
                  _ConvertIntent(),
            }
          : const <ShortcutActivator, Intent>{},
      child: Actions(
        actions: {
          _ConvertIntent: CallbackAction<_ConvertIntent>(
            onInvoke: (_) {
              unawaited(_convert());
              return null;
            },
          ),
        },
        child: Scaffold(
          appBar: AppBar(
            title: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (showTitleIcon) ...[
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: Image.asset(
                      'assets/images/jo_quote_converter_icon.png',
                      width: 27,
                      height: 27,
                    ),
                  ),
                  const SizedBox(width: 9),
                ],
                const Text(
                  'JO-引号转换',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
              ],
            ),
            actions: [
              IconButton(
                onPressed: _openHistory,
                tooltip: '历史记录',
                icon: const Icon(Icons.history_rounded),
              ),
              IconButton(
                onPressed: _openSettings,
                tooltip: '设置',
                icon: const Icon(Icons.settings_rounded),
              ),
              const SizedBox(width: 8),
            ],
          ),
          body: SafeArea(
            child: _isRestoringDraft
                ? const Center(
                    child: SizedBox.square(
                      dimension: 28,
                      child: CircularProgressIndicator(strokeWidth: 2.5),
                    ),
                  )
                : Padding(
                    padding: EdgeInsets.fromLTRB(
                      isCompact ? 12 : 24,
                      6,
                      isCompact ? 12 : 24,
                      isCompact ? 12 : 20,
                    ),
                    child: isCompact
                        ? Column(
                            children: [
                              Expanded(child: _buildInputEditor()),
                              const SizedBox(height: 12),
                              Expanded(child: _buildOutputEditor()),
                            ],
                          )
                        : Row(
                            children: [
                              Expanded(child: _buildInputEditor()),
                              const SizedBox(width: 16),
                              Expanded(child: _buildOutputEditor()),
                            ],
                          ),
                  ),
          ),
        ),
      ),
    );
  }

  Widget _buildInputEditor() {
    return _EditorPane(
      title: '原文',
      characterCount: _inputController.text.length,
      controller: _inputController,
      focusNode: _inputFocusNode,
      hintText: '在此输入或粘贴文本',
      titleActions: _EditorActions(
        onClear: _inputController.text.isEmpty && _outputController.text.isEmpty
            ? null
            : _confirmClear,
        onConvert: _convert,
      ),
    );
  }

  Widget _buildOutputEditor() {
    return _EditorPane(
      title: '转换结果',
      characterCount: _outputController.text.length,
      controller: _outputController,
      hintText: '转换结果将在此显示',
      readOnly: true,
      titleActions: _CopyAction(
        onCopy: _outputController.text.isEmpty ? null : _copyResult,
      ),
    );
  }
}

class _ConvertIntent extends Intent {
  const _ConvertIntent();
}

class HistoryPage extends StatefulWidget {
  const HistoryPage({
    super.key,
    required this.initialEntries,
    required this.isLoading,
    required this.hasStorageError,
    required this.onRestore,
    required this.onDelete,
    required this.onClear,
    required this.onStorageSize,
  });

  final List<ConversionHistoryEntry> initialEntries;
  final bool isLoading;
  final bool hasStorageError;
  final Future<bool> Function(ConversionHistoryEntry) onRestore;
  final Future<bool> Function(ConversionHistoryEntry) onDelete;
  final Future<bool> Function() onClear;
  final Future<int> Function() onStorageSize;

  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  final _searchController = TextEditingController();
  late List<ConversionHistoryEntry> _entries;
  bool _operationInProgress = false;
  int? _storageSizeBytes;

  @override
  void initState() {
    super.initState();
    _entries = List.of(widget.initialEntries);
    unawaited(_loadStorageSize());
  }

  Future<void> _loadStorageSize() async {
    try {
      final size = await widget.onStorageSize();
      if (mounted) setState(() => _storageSizeBytes = size);
    } catch (_) {
      if (mounted) setState(() => _storageSizeBytes = null);
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<ConversionHistoryEntry> get _filteredEntries {
    final query = _searchController.text.trim().toLowerCase();
    if (query.isEmpty) return _entries;
    return _entries
        .where(
          (entry) =>
              entry.input.toLowerCase().contains(query) ||
              entry.output.toLowerCase().contains(query),
        )
        .toList(growable: false);
  }

  Future<void> _restore(ConversionHistoryEntry entry) async {
    final restored = await widget.onRestore(entry);
    if (restored && mounted) Navigator.of(context).pop();
  }

  Future<void> _confirmDelete(ConversionHistoryEntry entry) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        final colorScheme = Theme.of(context).colorScheme;
        return AlertDialog(
          icon: Icon(Icons.delete_outline_rounded, color: colorScheme.error),
          title: const Text('删除这条历史记录？'),
          content: const Text('删除后无法恢复。'),
          actions: [
            TextButton(
              key: const Key('cancelDeleteHistoryButton'),
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('取消'),
            ),
            FilledButton.icon(
              key: const Key('confirmDeleteHistoryButton'),
              onPressed: () => Navigator.of(context).pop(true),
              style: FilledButton.styleFrom(
                backgroundColor: colorScheme.error,
                foregroundColor: colorScheme.onError,
              ),
              icon: const Icon(Icons.delete_outline_rounded),
              label: const Text('删除'),
            ),
          ],
        );
      },
    );
    if (confirmed != true || !mounted) return;

    setState(() => _operationInProgress = true);
    final deleted = await widget.onDelete(entry);
    if (!mounted) return;
    setState(() {
      _operationInProgress = false;
      if (deleted) {
        _entries.removeWhere(
          (candidate) => candidate.id != null && candidate.id == entry.id,
        );
        if (entry.id == null) _entries.remove(entry);
      }
    });
    if (deleted) unawaited(_loadStorageSize());
    _showResult(deleted ? '历史记录已删除' : '历史记录删除失败');
  }

  Future<void> _confirmClear() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        final colorScheme = Theme.of(context).colorScheme;
        return AlertDialog(
          icon: Icon(Icons.delete_sweep_outlined, color: colorScheme.error),
          title: const Text('清空全部历史记录？'),
          content: Text('将永久删除全部 ${_entries.length} 条历史记录，此操作无法撤销。'),
          actions: [
            TextButton(
              key: const Key('cancelClearHistoryButton'),
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('取消'),
            ),
            FilledButton.icon(
              key: const Key('confirmClearHistoryButton'),
              onPressed: () => Navigator.of(context).pop(true),
              style: FilledButton.styleFrom(
                backgroundColor: colorScheme.error,
                foregroundColor: colorScheme.onError,
              ),
              icon: const Icon(Icons.delete_sweep_outlined),
              label: const Text('全部清空'),
            ),
          ],
        );
      },
    );
    if (confirmed != true || !mounted) return;

    setState(() => _operationInProgress = true);
    final cleared = await widget.onClear();
    if (!mounted) return;
    setState(() {
      _operationInProgress = false;
      if (cleared) _entries = [];
    });
    if (cleared) unawaited(_loadStorageSize());
    _showResult(cleared ? '历史记录已全部清空' : '历史记录清空失败');
  }

  void _showResult(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final filteredEntries = _filteredEntries;
    final queryIsEmpty = _searchController.text.trim().isEmpty;

    return Scaffold(
      appBar: AppBar(
        title: const Text('历史记录'),
        actions: [
          TextButton.icon(
            key: const Key('clearAllHistoryButton'),
            onPressed: _entries.isEmpty || _operationInProgress
                ? null
                : _confirmClear,
            style: TextButton.styleFrom(
              foregroundColor: theme.colorScheme.error,
            ),
            icon: const Icon(Icons.delete_sweep_outlined, size: 19),
            label: const Text('清空'),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 920),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
                  child: TextField(
                    key: const Key('historySearchField'),
                    controller: _searchController,
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(
                      hintText: '搜索原文或转换结果',
                      prefixIcon: const Icon(Icons.search_rounded),
                      suffixIcon: queryIsEmpty
                          ? null
                          : IconButton(
                              key: const Key('clearHistorySearchButton'),
                              onPressed: () {
                                _searchController.clear();
                                setState(() {});
                              },
                              tooltip: '清除搜索',
                              icon: const Icon(Icons.close_rounded),
                            ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 0, 18, 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          queryIsEmpty
                              ? '${_entries.length} 条记录'
                              : '${filteredEntries.length} 条结果，共 ${_entries.length} 条记录',
                          key: const Key('historyCount'),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                      if (_storageSizeBytes != null)
                        Text(
                          '占用 ${_formatFileSize(_storageSizeBytes!)}',
                          key: const Key('historyStorageSize'),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                    ],
                  ),
                ),
                if (widget.hasStorageError)
                  MaterialBanner(
                    content: Text(
                      _entries.isEmpty
                          ? '历史记录读取失败，请重新启动应用后重试。'
                          : '部分历史记录尚未写入磁盘。',
                    ),
                    leading: const Icon(Icons.error_outline_rounded),
                    actions: const [SizedBox.shrink()],
                  ),
                Expanded(child: _buildBody(context, filteredEntries)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBody(
    BuildContext context,
    List<ConversionHistoryEntry> filteredEntries,
  ) {
    final theme = Theme.of(context);
    if (widget.isLoading) {
      return const Center(
        child: SizedBox.square(
          dimension: 26,
          child: CircularProgressIndicator(strokeWidth: 2.5),
        ),
      );
    }
    if (_entries.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.history_toggle_off_rounded,
              size: 40,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 12),
            Text(
              '暂无历史记录',
              style: theme.textTheme.bodyLarge?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      );
    }

    if (filteredEntries.isEmpty) {
      return Center(
        child: Text(
          '没有匹配的历史记录',
          style: theme.textTheme.bodyLarge?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      );
    }

    return ListView.separated(
      key: const Key('historyList'),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: filteredEntries.length,
      separatorBuilder: (context, index) => const Divider(height: 1),
      itemBuilder: (context, index) => _HistoryEntryView(
        entry: filteredEntries[index],
        index: index,
        onDetails: _operationInProgress
            ? null
            : () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (context) =>
                      _HistoryDetailPage(entry: filteredEntries[index]),
                ),
              ),
        onRestore: _operationInProgress
            ? null
            : () => _restore(filteredEntries[index]),
        onDelete: _operationInProgress
            ? null
            : () => _confirmDelete(filteredEntries[index]),
      ),
    );
  }
}

class _HistoryEntryView extends StatelessWidget {
  const _HistoryEntryView({
    required this.entry,
    required this.index,
    required this.onDetails,
    required this.onRestore,
    required this.onDelete,
  });

  final ConversionHistoryEntry entry;
  final int index;
  final VoidCallback? onDetails;
  final VoidCallback? onRestore;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final mutedStyle = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    return Padding(
      key: Key('historyEntry_$index'),
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  _formatHistoryTime(entry.createdAt),
                  style: mutedStyle,
                ),
              ),
              IconButton(
                key: Key('historyDetails_$index'),
                onPressed: onDetails,
                tooltip: '查看详情',
                style: IconButton.styleFrom(
                  minimumSize: const Size.square(30),
                  maximumSize: const Size.square(30),
                  padding: EdgeInsets.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
                icon: const Icon(Icons.open_in_new_rounded, size: 17),
              ),
              const SizedBox(width: 2),
              TextButton.icon(
                key: Key('historyRestore_$index'),
                onPressed: onRestore,
                style: TextButton.styleFrom(
                  minimumSize: const Size(0, 30),
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  visualDensity: VisualDensity.compact,
                  textStyle: const TextStyle(fontSize: 13),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
                icon: const Icon(Icons.restore_rounded, size: 16),
                label: const Text('恢复'),
              ),
              const SizedBox(width: 2),
              IconButton(
                key: Key('historyDelete_$index'),
                onPressed: onDelete,
                tooltip: '删除',
                style: IconButton.styleFrom(
                  minimumSize: const Size.square(30),
                  maximumSize: const Size.square(30),
                  padding: EdgeInsets.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  foregroundColor: theme.colorScheme.error,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
                icon: const Icon(Icons.delete_outline_rounded, size: 17),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text('原文', style: mutedStyle),
          const SizedBox(height: 3),
          Text(
            entry.input.isEmpty ? '（空文本）' : entry.input,
            key: Key('historyInput_$index'),
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: 10),
          Text('转换结果', style: mutedStyle),
          const SizedBox(height: 3),
          Text(
            entry.output.isEmpty ? '（空文本）' : entry.output,
            key: Key('historyOutput_$index'),
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }
}

class _HistoryDetailPage extends StatelessWidget {
  const _HistoryDetailPage({required this.entry});

  final ConversionHistoryEntry entry;

  Future<void> _copy(
    BuildContext context,
    String text,
    String successMessage,
  ) async {
    await Clipboard.setData(ClipboardData(text: text));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(successMessage)));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('历史记录详情')),
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 920),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
              children: [
                Text(
                  _formatHistoryTime(entry.createdAt),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 16),
                _HistoryDetailSection(
                  key: const Key('historyDetailInput'),
                  title: '原文',
                  text: entry.input,
                  onCopy: () => _copy(context, entry.input, '原文已复制'),
                ),
                const Divider(height: 32),
                _HistoryDetailSection(
                  key: const Key('historyDetailOutput'),
                  title: '转换结果',
                  text: entry.output,
                  onCopy: () => _copy(context, entry.output, '转换结果已复制'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _HistoryDetailSection extends StatelessWidget {
  const _HistoryDetailSection({
    super.key,
    required this.title,
    required this.text,
    required this.onCopy,
  });

  final String title;
  final String text;
  final VoidCallback onCopy;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(child: Text(title, style: theme.textTheme.titleMedium)),
            IconButton(
              onPressed: onCopy,
              tooltip: '复制$title',
              icon: const Icon(Icons.copy_rounded),
            ),
          ],
        ),
        const SizedBox(height: 8),
        SelectableText(text.isEmpty ? '（空文本）' : text),
      ],
    );
  }
}

String _formatHistoryTime(DateTime value) {
  String twoDigits(int number) => number.toString().padLeft(2, '0');
  final local = value.toLocal();
  return '${local.year}-${twoDigits(local.month)}-${twoDigits(local.day)} '
      '${twoDigits(local.hour)}:${twoDigits(local.minute)}:${twoDigits(local.second)}';
}

String _formatFileSize(int bytes) {
  if (bytes < 1024) return '$bytes B';
  final kilobytes = bytes / 1024;
  if (kilobytes < 1024) return '${kilobytes.toStringAsFixed(1)} KB';
  final megabytes = kilobytes / 1024;
  if (megabytes < 1024) return '${megabytes.toStringAsFixed(1)} MB';
  return '${(megabytes / 1024).toStringAsFixed(1)} GB';
}

class SettingsPage extends StatefulWidget {
  const SettingsPage({
    super.key,
    required this.initialExcludeMarkdownCode,
    required this.initialUseHeuristics,
    required this.initialThemeMode,
    required this.initialPalette,
    required this.initialKeyboardShortcutsEnabled,
    required this.onExcludeMarkdownCodeChanged,
    required this.onUseHeuristicsChanged,
    required this.onThemeModeChanged,
    required this.onPaletteChanged,
    required this.onKeyboardShortcutsEnabledChanged,
    required this.onExportArchive,
    required this.onPickArchive,
    required this.onImportArchive,
    required this.onListAutomaticBackups,
    required this.onDeleteAutomaticBackup,
    required this.onClearAutomaticBackups,
    required this.onRestoreAutomaticBackup,
  });

  final bool initialExcludeMarkdownCode;
  final bool initialUseHeuristics;
  final ThemeMode initialThemeMode;
  final AppPalette initialPalette;
  final bool initialKeyboardShortcutsEnabled;
  final ValueChanged<bool> onExcludeMarkdownCodeChanged;
  final ValueChanged<bool> onUseHeuristicsChanged;
  final ValueChanged<ThemeMode> onThemeModeChanged;
  final ValueChanged<AppPalette> onPaletteChanged;
  final ValueChanged<bool> onKeyboardShortcutsEnabledChanged;
  final Future<bool> Function() onExportArchive;
  final Future<ArchiveDocument?> Function() onPickArchive;
  final Future<bool> Function(
    ArchiveDocument document,
    ArchiveImportSelection selection,
  )
  onImportArchive;
  final Future<List<AutomaticBackup>> Function() onListAutomaticBackups;
  final Future<void> Function(AutomaticBackup) onDeleteAutomaticBackup;
  final Future<int> Function() onClearAutomaticBackups;
  final Future<bool> Function(AutomaticBackup) onRestoreAutomaticBackup;

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  late bool _excludeMarkdownCode;
  late bool _useHeuristics;
  late ThemeMode _themeMode;
  late AppPalette _palette;
  late bool _keyboardShortcutsEnabled;

  @override
  void initState() {
    super.initState();
    _excludeMarkdownCode = widget.initialExcludeMarkdownCode;
    _useHeuristics = widget.initialUseHeuristics;
    _themeMode = widget.initialThemeMode;
    _palette = widget.initialPalette;
    _keyboardShortcutsEnabled = widget.initialKeyboardShortcutsEnabled;
  }

  Future<void> _openPage(Widget page) => Navigator.of(
    context,
  ).push(MaterialPageRoute<void>(builder: (context) => page));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('设置')),
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 680),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 32),
              children: [
                _SettingsDestination(
                  key: const Key('settingsLanguage'),
                  icon: Icons.language_rounded,
                  title: '语言',
                  subtitle: '简体中文',
                  onTap: () => _openPage(const _LanguageSettingsPage()),
                ),
                _SettingsDestination(
                  key: const Key('settingsAppearance'),
                  icon: Icons.palette_outlined,
                  title: '外观',
                  subtitle:
                      '${_themeModeLabel(_themeMode)} · ${_palette.label}色',
                  onTap: () => _openPage(
                    _AppearanceSettingsPage(
                      initialThemeMode: _themeMode,
                      initialPalette: _palette,
                      onThemeModeChanged: (mode) {
                        setState(() => _themeMode = mode);
                        widget.onThemeModeChanged(mode);
                      },
                      onPaletteChanged: (palette) {
                        setState(() => _palette = palette);
                        widget.onPaletteChanged(palette);
                      },
                    ),
                  ),
                ),
                _SettingsDestination(
                  key: const Key('settingsBehavior'),
                  icon: Icons.tune_rounded,
                  title: '行为',
                  subtitle: '转换规则与 Markdown 代码排除',
                  onTap: () => _openPage(
                    _BehaviorSettingsPage(
                      initialExcludeMarkdownCode: _excludeMarkdownCode,
                      initialUseHeuristics: _useHeuristics,
                      onExcludeMarkdownCodeChanged: (value) {
                        setState(() => _excludeMarkdownCode = value);
                        widget.onExcludeMarkdownCodeChanged(value);
                      },
                      onUseHeuristicsChanged: (value) {
                        setState(() => _useHeuristics = value);
                        widget.onUseHeuristicsChanged(value);
                      },
                    ),
                  ),
                ),
                _SettingsDestination(
                  key: const Key('settingsShortcuts'),
                  icon: Icons.keyboard_outlined,
                  title: '快捷键',
                  subtitle: _keyboardShortcutsEnabled ? '已启用' : '已关闭',
                  onTap: () => _openPage(
                    _ShortcutSettingsPage(
                      initialEnabled: _keyboardShortcutsEnabled,
                      onEnabledChanged: (enabled) {
                        setState(() => _keyboardShortcutsEnabled = enabled);
                        widget.onKeyboardShortcutsEnabledChanged(enabled);
                      },
                    ),
                  ),
                ),
                _SettingsDestination(
                  key: const Key('settingsDataArchive'),
                  icon: Icons.archive_outlined,
                  title: '数据与存档',
                  subtitle: '导出、导入与自动回退备份',
                  onTap: () => _openPage(
                    _DataArchiveSettingsPage(
                      onExport: widget.onExportArchive,
                      onPickArchive: widget.onPickArchive,
                      onListAutomaticBackups: widget.onListAutomaticBackups,
                      onDeleteAutomaticBackup: widget.onDeleteAutomaticBackup,
                      onClearAutomaticBackups: widget.onClearAutomaticBackups,
                      onImport: (document, selection) async {
                        final imported = await widget.onImportArchive(
                          document,
                          selection,
                        );
                        if (imported && selection.isOverwrite && mounted) {
                          setState(() {
                            _excludeMarkdownCode =
                                document.snapshot.draft.excludeMarkdownCode;
                            _useHeuristics =
                                document.snapshot.draft.useHeuristics;
                            _themeMode = ThemeMode.values.firstWhere(
                              (mode) =>
                                  mode.name == document.snapshot.themeMode,
                            );
                            _palette = AppPalette.values.firstWhere(
                              (palette) =>
                                  palette.name == document.snapshot.palette,
                            );
                            _keyboardShortcutsEnabled =
                                document.snapshot.keyboardShortcutsEnabled;
                          });
                        }
                        return imported;
                      },
                      onRestoreAutomaticBackup: (backup) async {
                        final restored = await widget.onRestoreAutomaticBackup(
                          backup,
                        );
                        final document = backup.document;
                        if (restored && document != null && mounted) {
                          setState(() {
                            _excludeMarkdownCode =
                                document.snapshot.draft.excludeMarkdownCode;
                            _useHeuristics =
                                document.snapshot.draft.useHeuristics;
                            _themeMode = ThemeMode.values.firstWhere(
                              (mode) =>
                                  mode.name == document.snapshot.themeMode,
                            );
                            _palette = AppPalette.values.firstWhere(
                              (palette) =>
                                  palette.name == document.snapshot.palette,
                            );
                            _keyboardShortcutsEnabled =
                                document.snapshot.keyboardShortcutsEnabled;
                          });
                        }
                        return restored;
                      },
                    ),
                  ),
                ),
                _SettingsDestination(
                  key: const Key('settingsAbout'),
                  icon: Icons.info_outline_rounded,
                  title: '关于',
                  subtitle: 'JO-引号转换 $appVersion',
                  onTap: () => _openPage(const _AboutSettingsPage()),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

String _themeModeLabel(ThemeMode mode) => switch (mode) {
  ThemeMode.system => '跟随系统',
  ThemeMode.light => '浅色',
  ThemeMode.dark => '深色',
};

class _SettingsDestination extends StatelessWidget {
  const _SettingsDestination({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      minTileHeight: 68,
      leading: Icon(icon),
      title: Text(title),
      subtitle: Text(subtitle, maxLines: 2, overflow: TextOverflow.ellipsis),
      trailing: const Icon(Icons.chevron_right_rounded),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
      onTap: onTap,
    );
  }
}

class _LanguageSettingsPage extends StatelessWidget {
  const _LanguageSettingsPage();

  @override
  Widget build(BuildContext context) {
    return _SettingsSubpage(
      title: '语言',
      children: const [
        ListTile(
          key: Key('languageSimplifiedChinese'),
          contentPadding: EdgeInsets.zero,
          leading: Icon(Icons.translate_rounded),
          title: Text('简体中文'),
          subtitle: Text('当前唯一支持的界面语言'),
          trailing: Icon(Icons.check_rounded),
        ),
      ],
    );
  }
}

class _BehaviorSettingsPage extends StatefulWidget {
  const _BehaviorSettingsPage({
    required this.initialExcludeMarkdownCode,
    required this.initialUseHeuristics,
    required this.onExcludeMarkdownCodeChanged,
    required this.onUseHeuristicsChanged,
  });

  final bool initialExcludeMarkdownCode;
  final bool initialUseHeuristics;
  final ValueChanged<bool> onExcludeMarkdownCodeChanged;
  final ValueChanged<bool> onUseHeuristicsChanged;

  @override
  State<_BehaviorSettingsPage> createState() => _BehaviorSettingsPageState();
}

class _BehaviorSettingsPageState extends State<_BehaviorSettingsPage> {
  late bool _excludeMarkdownCode = widget.initialExcludeMarkdownCode;
  late bool _useHeuristics = widget.initialUseHeuristics;

  @override
  Widget build(BuildContext context) {
    return _SettingsSubpage(
      title: '行为',
      children: [
        SwitchListTile(
          key: const Key('excludeMarkdownCodeSetting'),
          contentPadding: EdgeInsets.zero,
          secondary: const Icon(Icons.code_rounded),
          title: const Text('排除 Markdown 代码'),
          subtitle: const Text('保留围栏代码块和行内代码中的原始引号'),
          value: _excludeMarkdownCode,
          onChanged: (value) {
            setState(() => _excludeMarkdownCode = value);
            widget.onExcludeMarkdownCodeChanged(value);
          },
        ),
        SwitchListTile(
          key: const Key('useHeuristicsSetting'),
          contentPadding: EdgeInsets.zero,
          secondary: const Icon(Icons.auto_awesome_rounded),
          title: const Text('启发式判断'),
          subtitle: const Text('尽量保留缩写、所有格、单位和年代中的撇号'),
          value: _useHeuristics,
          onChanged: (value) {
            setState(() => _useHeuristics = value);
            widget.onUseHeuristicsChanged(value);
          },
        ),
      ],
    );
  }
}

class _AppearanceSettingsPage extends StatefulWidget {
  const _AppearanceSettingsPage({
    required this.initialThemeMode,
    required this.initialPalette,
    required this.onThemeModeChanged,
    required this.onPaletteChanged,
  });

  final ThemeMode initialThemeMode;
  final AppPalette initialPalette;
  final ValueChanged<ThemeMode> onThemeModeChanged;
  final ValueChanged<AppPalette> onPaletteChanged;

  @override
  State<_AppearanceSettingsPage> createState() =>
      _AppearanceSettingsPageState();
}

class _AppearanceSettingsPageState extends State<_AppearanceSettingsPage> {
  late ThemeMode _themeMode = widget.initialThemeMode;
  late AppPalette _palette = widget.initialPalette;

  @override
  Widget build(BuildContext context) {
    return _SettingsSubpage(
      title: '外观',
      children: [
        const _SettingsSectionTitle('模式'),
        const SizedBox(height: 12),
        SegmentedButton<ThemeMode>(
          segments: const [
            ButtonSegment(value: ThemeMode.system, label: Text('跟随系统')),
            ButtonSegment(value: ThemeMode.light, label: Text('浅色')),
            ButtonSegment(value: ThemeMode.dark, label: Text('深色')),
          ],
          selected: {_themeMode},
          showSelectedIcon: false,
          expandedInsets: EdgeInsets.zero,
          onSelectionChanged: (selection) {
            final mode = selection.first;
            setState(() => _themeMode = mode);
            widget.onThemeModeChanged(mode);
          },
        ),
        const SizedBox(height: 28),
        const _SettingsSectionTitle('配色'),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 12,
          children: [
            for (final palette in AppPalette.values)
              _PaletteChoice(
                palette: palette,
                selected: palette == _palette,
                onSelected: () {
                  setState(() => _palette = palette);
                  widget.onPaletteChanged(palette);
                },
              ),
          ],
        ),
      ],
    );
  }
}

class _ShortcutSettingsPage extends StatefulWidget {
  const _ShortcutSettingsPage({
    required this.initialEnabled,
    required this.onEnabledChanged,
  });

  final bool initialEnabled;
  final ValueChanged<bool> onEnabledChanged;

  @override
  State<_ShortcutSettingsPage> createState() => _ShortcutSettingsPageState();
}

class _ShortcutSettingsPageState extends State<_ShortcutSettingsPage> {
  late bool _enabled = widget.initialEnabled;

  @override
  Widget build(BuildContext context) {
    return _SettingsSubpage(
      title: '快捷键',
      children: [
        SwitchListTile(
          key: const Key('keyboardShortcutsEnabledSetting'),
          contentPadding: EdgeInsets.zero,
          secondary: const Icon(Icons.keyboard_outlined),
          title: const Text('启用键盘快捷键'),
          subtitle: const Text('关闭后，所有键盘快捷键将停止响应'),
          value: _enabled,
          onChanged: (enabled) {
            setState(() => _enabled = enabled);
            widget.onEnabledChanged(enabled);
          },
        ),
        const Divider(height: 28),
        ListTile(
          key: const Key('shortcutConvert'),
          contentPadding: EdgeInsets.zero,
          enabled: _enabled,
          leading: const Icon(Icons.play_arrow_rounded),
          title: const Text('转换'),
          trailing: const _ShortcutKeys(keys: ['Ctrl', 'Enter']),
        ),
      ],
    );
  }
}

class _ShortcutKeys extends StatelessWidget {
  const _ShortcutKeys({required this.keys});

  final List<String> keys;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var index = 0; index < keys.length; index++) ...[
          if (index > 0)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 5),
              child: Text('+'),
            ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              border: Border.all(color: theme.colorScheme.outlineVariant),
              borderRadius: BorderRadius.circular(4),
              color: theme.colorScheme.surfaceContainer,
            ),
            child: Text(keys[index], style: theme.textTheme.labelMedium),
          ),
        ],
      ],
    );
  }
}

enum ArchiveImportMode { smartMerge, overwrite }

class ArchiveImportSelection {
  const ArchiveImportSelection(this.mode);

  final ArchiveImportMode mode;

  bool get isOverwrite => mode == ArchiveImportMode.overwrite;
}

class _DataArchiveSettingsPage extends StatefulWidget {
  const _DataArchiveSettingsPage({
    required this.onExport,
    required this.onPickArchive,
    required this.onImport,
    required this.onListAutomaticBackups,
    required this.onDeleteAutomaticBackup,
    required this.onClearAutomaticBackups,
    required this.onRestoreAutomaticBackup,
  });

  final Future<bool> Function() onExport;
  final Future<ArchiveDocument?> Function() onPickArchive;
  final Future<bool> Function(
    ArchiveDocument document,
    ArchiveImportSelection selection,
  )
  onImport;
  final Future<List<AutomaticBackup>> Function() onListAutomaticBackups;
  final Future<void> Function(AutomaticBackup) onDeleteAutomaticBackup;
  final Future<int> Function() onClearAutomaticBackups;
  final Future<bool> Function(AutomaticBackup) onRestoreAutomaticBackup;

  @override
  State<_DataArchiveSettingsPage> createState() =>
      _DataArchiveSettingsPageState();
}

class _DataArchiveSettingsPageState extends State<_DataArchiveSettingsPage> {
  bool _busy = false;

  Future<void> _export() async {
    setState(() => _busy = true);
    await widget.onExport();
    if (mounted) setState(() => _busy = false);
  }

  Future<void> _import() async {
    setState(() => _busy = true);
    final document = await widget.onPickArchive();
    if (!mounted) return;
    setState(() => _busy = false);
    if (document == null) return;

    final selection = await showDialog<ArchiveImportSelection>(
      context: context,
      builder: (context) => _ArchiveImportDialog(document: document),
    );
    if (selection == null || !mounted) return;
    setState(() => _busy = true);
    await widget.onImport(document, selection);
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    return _SettingsSubpage(
      title: '数据与存档',
      children: [
        ListTile(
          key: const Key('exportArchive'),
          enabled: !_busy,
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.file_upload_outlined),
          title: const Text('导出存档'),
          subtitle: const Text('保存工作区、设置和全部历史记录'),
          trailing: const Icon(Icons.chevron_right_rounded),
          onTap: _busy ? null : _export,
        ),
        ListTile(
          key: const Key('importArchive'),
          enabled: !_busy,
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.file_download_outlined),
          title: const Text('导入存档'),
          subtitle: const Text('校验后选择完全覆盖或智能合并'),
          trailing: const Icon(Icons.chevron_right_rounded),
          onTap: _busy ? null : _import,
        ),
        ListTile(
          key: const Key('manageAutomaticBackups'),
          enabled: !_busy,
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.settings_backup_restore_rounded),
          title: const Text('自动备份'),
          subtitle: const Text('查看、恢复或清理导入前备份'),
          trailing: const Icon(Icons.chevron_right_rounded),
          onTap: _busy
              ? null
              : () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (context) => _AutomaticBackupsPage(
                      onLoad: widget.onListAutomaticBackups,
                      onDelete: widget.onDeleteAutomaticBackup,
                      onClear: widget.onClearAutomaticBackups,
                      onRestore: widget.onRestoreAutomaticBackup,
                    ),
                  ),
                ),
        ),
        if (_busy)
          const Padding(
            padding: EdgeInsets.only(top: 16),
            child: LinearProgressIndicator(),
          ),
        const SizedBox(height: 20),
        const _SettingsSectionTitle('存档说明'),
        const SizedBox(height: 10),
        Text(
          '存档使用 .joquoteconverter 后缀并采用 ZIP Deflate 压缩。'
          '存档包含原文、转换结果、设置和历史记录，不加密，请妥善保管。'
          '确认导入后，应用会先在本机自动保存一份导入前备份。',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(height: 1.55),
        ),
      ],
    );
  }
}

class _AutomaticBackupsPage extends StatefulWidget {
  const _AutomaticBackupsPage({
    required this.onLoad,
    required this.onDelete,
    required this.onClear,
    required this.onRestore,
  });

  final Future<List<AutomaticBackup>> Function() onLoad;
  final Future<void> Function(AutomaticBackup) onDelete;
  final Future<int> Function() onClear;
  final Future<bool> Function(AutomaticBackup) onRestore;

  @override
  State<_AutomaticBackupsPage> createState() => _AutomaticBackupsPageState();
}

class _AutomaticBackupsPageState extends State<_AutomaticBackupsPage> {
  List<AutomaticBackup> _backups = const [];
  bool _loading = true;
  bool _operationInProgress = false;
  String? _loadError;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _loadError = null;
    });
    try {
      final backups = await widget.onLoad();
      if (!mounted) return;
      setState(() {
        _backups = backups;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _loadError = '自动备份读取失败';
      });
    }
  }

  Future<void> _confirmRestore(AutomaticBackup backup) async {
    final document = backup.document;
    if (document == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.settings_backup_restore_rounded),
        title: const Text('恢复此自动备份？'),
        content: Text(
          '将覆盖当前工作区、设置和全部历史记录。\n\n'
          '备份时间：${_formatHistoryTime(document.exportedAt)}\n'
          '来源版本：${document.appVersion}\n'
          '历史记录：${document.snapshot.history.length} 条\n\n'
          '恢复前会再次备份当前数据。',
        ),
        actions: [
          TextButton(
            key: const Key('cancelRestoreAutomaticBackupButton'),
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          FilledButton.icon(
            key: const Key('confirmRestoreAutomaticBackupButton'),
            onPressed: () => Navigator.of(context).pop(true),
            icon: const Icon(Icons.restore_rounded),
            label: const Text('恢复'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _operationInProgress = true);
    final restored = await widget.onRestore(backup);
    if (!mounted) return;
    setState(() => _operationInProgress = false);
    if (restored) await _load();
  }

  Future<void> _confirmDelete(AutomaticBackup backup) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        final colors = Theme.of(context).colorScheme;
        return AlertDialog(
          icon: Icon(Icons.delete_outline_rounded, color: colors.error),
          title: const Text('删除此自动备份？'),
          content: const Text('删除后无法恢复。'),
          actions: [
            TextButton(
              key: const Key('cancelDeleteAutomaticBackupButton'),
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('取消'),
            ),
            FilledButton.icon(
              key: const Key('confirmDeleteAutomaticBackupButton'),
              onPressed: () => Navigator.of(context).pop(true),
              style: FilledButton.styleFrom(
                backgroundColor: colors.error,
                foregroundColor: colors.onError,
              ),
              icon: const Icon(Icons.delete_outline_rounded),
              label: const Text('删除'),
            ),
          ],
        );
      },
    );
    if (confirmed != true || !mounted) return;

    setState(() => _operationInProgress = true);
    try {
      await widget.onDelete(backup);
      if (!mounted) return;
      setState(() {
        _operationInProgress = false;
        _backups = _backups
            .where((item) => item.fileName != backup.fileName)
            .toList(growable: false);
      });
      _showMessage('自动备份已删除');
    } catch (_) {
      if (!mounted) return;
      setState(() => _operationInProgress = false);
      _showMessage('自动备份删除失败');
    }
  }

  Future<void> _confirmClear() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        final colors = Theme.of(context).colorScheme;
        return AlertDialog(
          icon: Icon(Icons.delete_sweep_outlined, color: colors.error),
          title: const Text('清空全部自动备份？'),
          content: Text('将永久删除全部 ${_backups.length} 个自动备份，此操作无法撤销。'),
          actions: [
            TextButton(
              key: const Key('cancelClearAutomaticBackupsButton'),
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('取消'),
            ),
            FilledButton.icon(
              key: const Key('confirmClearAutomaticBackupsButton'),
              onPressed: () => Navigator.of(context).pop(true),
              style: FilledButton.styleFrom(
                backgroundColor: colors.error,
                foregroundColor: colors.onError,
              ),
              icon: const Icon(Icons.delete_sweep_outlined),
              label: const Text('全部清空'),
            ),
          ],
        );
      },
    );
    if (confirmed != true || !mounted) return;

    setState(() => _operationInProgress = true);
    try {
      await widget.onClear();
      if (!mounted) return;
      setState(() {
        _operationInProgress = false;
        _backups = const [];
      });
      _showMessage('自动备份已全部清空');
    } catch (_) {
      if (!mounted) return;
      setState(() => _operationInProgress = false);
      _showMessage('自动备份清空失败');
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('自动备份'),
        actions: [
          TextButton.icon(
            key: const Key('clearAutomaticBackupsButton'),
            onPressed: _backups.isEmpty || _operationInProgress
                ? null
                : _confirmClear,
            style: TextButton.styleFrom(
              foregroundColor: theme.colorScheme.error,
            ),
            icon: const Icon(Icons.delete_sweep_outlined, size: 19),
            label: const Text('清空'),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: _buildBody(context),
          ),
        ),
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    final theme = Theme.of(context);
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_loadError != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_loadError!),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _load,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('重试'),
            ),
          ],
        ),
      );
    }
    if (_backups.isEmpty) {
      return Center(
        child: Text(
          '暂无自动备份',
          style: theme.textTheme.bodyLarge?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      );
    }
    return ListView.separated(
      key: const Key('automaticBackupList'),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
      itemCount: _backups.length,
      separatorBuilder: (context, index) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final backup = _backups[index];
        final document = backup.document;
        return ListTile(
          key: Key('automaticBackup_$index'),
          contentPadding: const EdgeInsets.symmetric(vertical: 8),
          leading: Icon(
            document == null
                ? Icons.warning_amber_rounded
                : Icons.settings_backup_restore_rounded,
            color: document == null ? theme.colorScheme.error : null,
          ),
          title: Text(
            document == null
                ? '损坏的自动备份'
                : _formatHistoryTime(document.exportedAt),
          ),
          subtitle: Text(
            document == null
                ? '${backup.errorMessage} · ${_formatFileSize(backup.sizeBytes)}'
                : '版本 ${document.appVersion} · '
                      '${document.snapshot.history.length} 条历史 · '
                      '${_formatFileSize(backup.sizeBytes)}',
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                key: Key('restoreAutomaticBackup_$index'),
                onPressed: document == null || _operationInProgress
                    ? null
                    : () => _confirmRestore(backup),
                tooltip: '恢复',
                icon: const Icon(Icons.restore_rounded),
              ),
              IconButton(
                key: Key('deleteAutomaticBackup_$index'),
                onPressed: _operationInProgress
                    ? null
                    : () => _confirmDelete(backup),
                tooltip: '删除',
                color: theme.colorScheme.error,
                icon: const Icon(Icons.delete_outline_rounded),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ArchiveImportDialog extends StatefulWidget {
  const _ArchiveImportDialog({required this.document});

  final ArchiveDocument document;

  @override
  State<_ArchiveImportDialog> createState() => _ArchiveImportDialogState();
}

class _ArchiveImportDialogState extends State<_ArchiveImportDialog> {
  ArchiveImportMode _mode = ArchiveImportMode.smartMerge;

  @override
  Widget build(BuildContext context) {
    final document = widget.document;
    final theme = Theme.of(context);
    final selection = ArchiveImportSelection(_mode);
    return AlertDialog(
      icon: const Icon(Icons.archive_outlined),
      title: const Text('导入此存档？'),
      content: SizedBox(
        width: 440,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('导出时间：${_formatHistoryTime(document.exportedAt)}'),
              const SizedBox(height: 4),
              Text('来源版本：${document.appVersion}'),
              const SizedBox(height: 4),
              Text('历史记录：${document.snapshot.history.length} 条'),
              const Divider(height: 28),
              Text('导入模式', style: theme.textTheme.titleSmall),
              const SizedBox(height: 10),
              SegmentedButton<ArchiveImportMode>(
                key: const Key('importModeSelector'),
                segments: const [
                  ButtonSegment(
                    value: ArchiveImportMode.smartMerge,
                    label: Text('智能合并'),
                  ),
                  ButtonSegment(
                    value: ArchiveImportMode.overwrite,
                    label: Text('完全覆盖'),
                  ),
                ],
                selected: {_mode},
                showSelectedIcon: false,
                onSelectionChanged: (selection) =>
                    setState(() => _mode = selection.single),
              ),
              const SizedBox(height: 8),
              Text(
                switch (_mode) {
                  ArchiveImportMode.smartMerge =>
                    '保留当前设置；工作区为空时恢复存档工作区；历史记录去重合并。',
                  ArchiveImportMode.overwrite =>
                    '当前工作区、行为与外观设置、快捷键和历史记录都将替换为存档内容。',
                },
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '导入前会自动创建当前数据备份。',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          key: const Key('cancelImportArchiveButton'),
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
        FilledButton.icon(
          key: const Key('confirmImportArchiveButton'),
          onPressed: () => Navigator.of(context).pop(selection),
          icon: const Icon(Icons.file_download_outlined),
          label: const Text('导入'),
        ),
      ],
    );
  }
}

class _AboutSettingsPage extends StatelessWidget {
  const _AboutSettingsPage();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return _SettingsSubpage(
      title: '关于',
      children: [
        ListTile(
          key: const Key('aboutVersion'),
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.info_outline_rounded),
          title: const Text('版本'),
          trailing: Text(
            appVersion,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        ListTile(
          key: const Key('aboutAuthor'),
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.person_outline_rounded),
          title: const Text('作者'),
          subtitle: const Text('https://github.com/JO-Beacon/'),
          trailing: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(appAuthor),
              SizedBox(width: 6),
              Icon(Icons.open_in_new_rounded, size: 18),
            ],
          ),
          onTap: () => _openExternalUrl(context, appAuthorUrl),
        ),
        ListTile(
          key: const Key('aboutProjectLicense'),
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.description_outlined),
          title: const Text('项目许可证'),
          subtitle: const Text('Apache License 2.0'),
          trailing: const Icon(Icons.chevron_right_rounded),
          onTap: () => _openLicenseText(
            context,
            title: 'Apache License 2.0',
            assetPath: 'LICENSE',
          ),
        ),
        ListTile(
          key: const Key('aboutFontLicense'),
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.font_download_outlined),
          title: const Text('思源黑体许可证'),
          subtitle: const Text('SIL Open Font License 1.1'),
          trailing: const Icon(Icons.chevron_right_rounded),
          onTap: () => _openLicenseText(
            context,
            title: '思源黑体许可证',
            assetPath: 'assets/licenses/SourceHanSans-OFL-1.1.txt',
          ),
        ),
        ListTile(
          key: const Key('aboutOpenSourceLicenses'),
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.inventory_2_outlined),
          title: const Text('第三方开源许可证'),
          subtitle: const Text('Flutter 及第三方依赖'),
          trailing: const Icon(Icons.chevron_right_rounded),
          onTap: () => showLicensePage(
            context: context,
            applicationName: 'JO-引号转换',
            applicationVersion: appVersion,
            applicationLegalese: 'Copyright (C) 2026 $appAuthor',
            applicationIcon: const Icon(Icons.format_quote_rounded, size: 42),
          ),
        ),
      ],
    );
  }
}

class _SettingsSubpage extends StatelessWidget {
  const _SettingsSubpage({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 680),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
              children: children,
            ),
          ),
        ),
      ),
    );
  }
}

Future<void> _openExternalUrl(BuildContext context, Uri url) async {
  var opened = false;
  try {
    opened = await launchUrl(url, mode: LaunchMode.externalApplication);
  } on PlatformException {
    opened = false;
  }
  if (opened || !context.mounted) return;
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(const SnackBar(content: Text('无法打开链接')));
}

Future<void> _openLicenseText(
  BuildContext context, {
  required String title,
  required String assetPath,
}) async {
  final licenseText = await rootBundle.loadString(assetPath);
  if (!context.mounted) return;
  await Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (context) =>
          _LicenseTextPage(title: title, licenseText: licenseText),
    ),
  );
}

class _LicenseTextPage extends StatelessWidget {
  const _LicenseTextPage({required this.title, required this.licenseText});

  final String title;
  final String licenseText;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 820),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
              child: SelectableText(
                licenseText,
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(height: 1.55),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PaletteChoice extends StatelessWidget {
  const _PaletteChoice({
    required this.palette,
    required this.selected,
    required this.onSelected,
  });

  final AppPalette palette;
  final bool selected;
  final VoidCallback onSelected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final checkColor = palette == AppPalette.yellow
        ? const Color(0xFF2B2100)
        : Colors.white;

    return Semantics(
      button: true,
      selected: selected,
      label: '${palette.label}色配色',
      child: SizedBox(
        width: 52,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Tooltip(
              message: '${palette.label}色配色',
              child: InkResponse(
                key: Key('palette_${palette.name}'),
                onTap: onSelected,
                radius: 24,
                customBorder: const CircleBorder(),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 160),
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: palette.color,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: selected
                          ? theme.colorScheme.onSurface
                          : Colors.transparent,
                      width: 2,
                    ),
                  ),
                  alignment: Alignment.center,
                  child: selected
                      ? Icon(
                          Icons.check_rounded,
                          key: Key('selectedPalette_${palette.name}'),
                          color: checkColor,
                          size: 20,
                        )
                      : null,
                ),
              ),
            ),
            const SizedBox(height: 5),
            Text(palette.label, style: theme.textTheme.bodySmall),
          ],
        ),
      ),
    );
  }
}

class _SettingsSectionTitle extends StatelessWidget {
  const _SettingsSectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: Theme.of(context).textTheme.titleSmall?.copyWith(
        color: Theme.of(context).colorScheme.primary,
        fontWeight: FontWeight.w700,
      ),
    );
  }
}

class _EditorActions extends StatelessWidget {
  const _EditorActions({required this.onClear, required this.onConvert});

  final VoidCallback? onClear;
  final VoidCallback onConvert;

  @override
  Widget build(BuildContext context) {
    final buttonShape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(6),
    );
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        FilledButton.icon(
          key: const Key('clearButton'),
          onPressed: onClear,
          style: FilledButton.styleFrom(
            minimumSize: const Size(0, 30),
            padding: const EdgeInsets.symmetric(horizontal: 9),
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            visualDensity: VisualDensity.compact,
            textStyle: const TextStyle(fontSize: 13),
            shape: buttonShape,
            backgroundColor: Theme.of(context).colorScheme.error,
            foregroundColor: Theme.of(context).colorScheme.onError,
            disabledBackgroundColor: Theme.of(
              context,
            ).colorScheme.error.withValues(alpha: 0.12),
            disabledForegroundColor: Theme.of(
              context,
            ).colorScheme.error.withValues(alpha: 0.38),
          ),
          icon: const Icon(Icons.delete_outline_rounded, size: 16),
          label: const Text('清空', maxLines: 1),
        ),
        const SizedBox(width: 6),
        FilledButton.icon(
          key: const Key('convertButton'),
          onPressed: onConvert,
          style: FilledButton.styleFrom(
            minimumSize: const Size(0, 30),
            padding: const EdgeInsets.symmetric(horizontal: 9),
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            visualDensity: VisualDensity.compact,
            textStyle: const TextStyle(fontSize: 13),
            shape: buttonShape,
          ),
          icon: const Icon(Icons.sync_alt_rounded, size: 16),
          label: const Text('转换', maxLines: 1),
        ),
      ],
    );
  }
}

class _CopyAction extends StatelessWidget {
  const _CopyAction({required this.onCopy});

  final VoidCallback? onCopy;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      key: const Key('copyButton'),
      onPressed: onCopy,
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(0, 30),
        padding: const EdgeInsets.symmetric(horizontal: 9),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        visualDensity: VisualDensity.compact,
        textStyle: const TextStyle(fontSize: 13),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
      ),
      icon: const Icon(Icons.content_copy_rounded, size: 16),
      label: const Text('复制', maxLines: 1),
    );
  }
}

class _EditorPane extends StatelessWidget {
  const _EditorPane({
    required this.title,
    required this.characterCount,
    required this.controller,
    required this.hintText,
    this.focusNode,
    this.readOnly = false,
    this.titleActions,
  });

  final String title;
  final int characterCount;
  final TextEditingController controller;
  final String hintText;
  final FocusNode? focusNode;
  final bool readOnly;
  final Widget? titleActions;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: 40,
          child: Row(
            children: [
              Text(
                title,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (titleActions != null) ...[
                const SizedBox(width: 8),
                titleActions!,
              ],
              const Spacer(),
              Text(
                '$characterCount 字符',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        Expanded(
          child: TextField(
            controller: controller,
            focusNode: focusNode,
            readOnly: readOnly,
            expands: true,
            minLines: null,
            maxLines: null,
            textAlignVertical: TextAlignVertical.top,
            style: const TextStyle(fontSize: 16, height: 1.65),
            decoration: InputDecoration(hintText: hintText),
          ),
        ),
      ],
    );
  }
}
