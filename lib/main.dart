import 'dart:async';
import 'dart:ui' show AppExitResponse;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'draft_store.dart';
import 'history_store.dart';
import 'quote_converter.dart';
import 'windows_data_migrator.dart';

const appVersion = '0.0.1+1';
const appAuthor = 'JO-Beacon';

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
    AppPalette.gray => const Color(0xFF73777D),
  };
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await migratePreviousWindowsPreferences();
  } catch (_) {
    // Migration failure must not prevent the editor from opening.
  }
  runApp(const QuoteConverterApp());
}

class QuoteConverterApp extends StatefulWidget {
  const QuoteConverterApp({super.key, this.historyStore});

  final HistoryStore? historyStore;

  @override
  State<QuoteConverterApp> createState() => _QuoteConverterAppState();
}

class _QuoteConverterAppState extends State<QuoteConverterApp> {
  final _draftStore = DraftStore();
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
      theme: _buildAppTheme(Brightness.light, _palette),
      darkTheme: _buildAppTheme(Brightness.dark, _palette),
      themeMode: _themeMode,
      home: ConverterPage(
        historyStore: widget.historyStore,
        themeMode: _themeMode,
        palette: _palette,
        onThemeModeChanged: _changeThemeMode,
        onPaletteChanged: _changePalette,
      ),
    );
  }
}

ThemeData _buildAppTheme(Brightness brightness, AppPalette palette) {
  final isDark = brightness == Brightness.dark;
  final colorScheme = ColorScheme.fromSeed(
    seedColor: palette.color,
    brightness: brightness,
    surface: isDark ? const Color(0xFF171A19) : const Color(0xFFF8FAF8),
  );
  final scaffoldColor = isDark
      ? const Color(0xFF101312)
      : const Color(0xFFF3F5F3);

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
      fillColor: isDark ? const Color(0xFF1A1E1C) : Colors.white,
      contentPadding: const EdgeInsets.all(16),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(6),
        borderSide: BorderSide(
          color: isDark ? const Color(0xFF3A423F) : const Color(0xFFD5DAD7),
        ),
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
    required this.themeMode,
    required this.palette,
    required this.onThemeModeChanged,
    required this.onPaletteChanged,
  });

  final HistoryStore? historyStore;
  final ThemeMode themeMode;
  final AppPalette palette;
  final ValueChanged<ThemeMode> onThemeModeChanged;
  final ValueChanged<AppPalette> onPaletteChanged;

  @override
  State<ConverterPage> createState() => _ConverterPageState();
}

class _ConverterPageState extends State<ConverterPage> {
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  final _inputController = TextEditingController();
  final _outputController = TextEditingController();
  final _inputFocusNode = FocusNode();
  final _draftStore = DraftStore();
  late final HistoryStore _historyStore;
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
  List<ConversionHistoryEntry> _history = [];

  @override
  void initState() {
    super.initState();
    _historyStore = widget.historyStore ?? HistoryStore();
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
    List<ConversionHistoryEntry>? history;
    final historyFuture = _historyStore.load();
    try {
      draft = await _draftStore.load();
    } catch (_) {
      // A corrupt or unavailable preference store should not block the editor.
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
    if (history != null) _history = history;
    _isLoadingHistory = false;
    _inputController.addListener(_handleTextChanged);
    _outputController.addListener(_handleTextChanged);
    _listenersAttached = true;
    setState(() => _isRestoringDraft = false);
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

  Future<void> _restoreHistoryEntry(ConversionHistoryEntry entry) async {
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
      if (confirmed != true || !mounted) return;
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
    if (!mounted) return;
    _scaffoldKey.currentState?.closeEndDrawer();
    _inputFocusNode.requestFocus();
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(const SnackBar(content: Text('已恢复到工作区')));
  }

  Future<void> _deleteHistoryEntry(ConversionHistoryEntry entry) async {
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

    try {
      await _historySaveQueue;
      await _historyStore.delete(entry);
      final storedHistory = await _historyStore.load();
      if (!mounted) return;
      setState(() => _history = storedHistory);
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(content: Text('历史记录已删除')));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(content: Text('历史记录删除失败')));
    }
  }

  Future<void> _openSettings() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => SettingsPage(
          initialExcludeMarkdownCode: _excludeMarkdownCode,
          initialUseHeuristics: _useHeuristics,
          initialThemeMode: widget.themeMode,
          initialPalette: widget.palette,
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
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final isCompact = screenWidth < 760;
    final showTitleIcon = screenWidth >= 360;

    return Scaffold(
      key: _scaffoldKey,
      endDrawer: _HistoryDrawer(
        entries: _history,
        isLoading: _isLoadingHistory,
        hasStorageError: _historyLoadFailed,
        onRestore: _restoreHistoryEntry,
        onDelete: _deleteHistoryEntry,
      ),
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (showTitleIcon) ...[
              const Icon(Icons.format_quote_rounded, size: 27),
              const SizedBox(width: 9),
            ],
            const Text(
              'JO-引号转换',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
          ],
        ),
        actions: [
          Builder(
            builder: (context) => IconButton(
              onPressed: Scaffold.of(context).openEndDrawer,
              tooltip: '历史记录',
              icon: const Icon(Icons.history_rounded),
            ),
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

class _HistoryDrawer extends StatelessWidget {
  const _HistoryDrawer({
    required this.entries,
    required this.isLoading,
    required this.hasStorageError,
    required this.onRestore,
    required this.onDelete,
  });

  final List<ConversionHistoryEntry> entries;
  final bool isLoading;
  final bool hasStorageError;
  final ValueChanged<ConversionHistoryEntry> onRestore;
  final ValueChanged<ConversionHistoryEntry> onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final screenWidth = MediaQuery.sizeOf(context).width;

    return Drawer(
      width: screenWidth < 380 ? screenWidth : 380,
      shape: const RoundedRectangleBorder(),
      child: SafeArea(
        child: Column(
          children: [
            SizedBox(
              height: 64,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Row(
                  children: [
                    const SizedBox(width: 8),
                    const Icon(Icons.history_rounded),
                    const SizedBox(width: 12),
                    Text(
                      '历史记录',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const Spacer(),
                    if (!isLoading)
                      Text(
                        '${entries.length} 条',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    const SizedBox(width: 4),
                    IconButton(
                      onPressed: Navigator.of(context).pop,
                      tooltip: '关闭',
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
              ),
            ),
            const Divider(height: 1),
            if (hasStorageError)
              MaterialBanner(
                content: Text(
                  entries.isEmpty ? '历史记录读取失败，请重新启动应用后重试。' : '部分历史记录尚未写入磁盘。',
                ),
                leading: const Icon(Icons.error_outline_rounded),
                actions: const [SizedBox.shrink()],
              ),
            Expanded(child: _buildBody(context)),
          ],
        ),
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    final theme = Theme.of(context);
    if (isLoading) {
      return const Center(
        child: SizedBox.square(
          dimension: 26,
          child: CircularProgressIndicator(strokeWidth: 2.5),
        ),
      );
    }
    if (entries.isEmpty) {
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

    return ListView.separated(
      key: const Key('historyList'),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: entries.length,
      separatorBuilder: (context, index) => const Divider(height: 1),
      itemBuilder: (context, index) => _HistoryEntryView(
        entry: entries[index],
        index: index,
        onRestore: () => onRestore(entries[index]),
        onDelete: () => onDelete(entries[index]),
      ),
    );
  }
}

class _HistoryEntryView extends StatelessWidget {
  const _HistoryEntryView({
    required this.entry,
    required this.index,
    required this.onRestore,
    required this.onDelete,
  });

  final ConversionHistoryEntry entry;
  final int index;
  final VoidCallback onRestore;
  final VoidCallback onDelete;

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

String _formatHistoryTime(DateTime value) {
  String twoDigits(int number) => number.toString().padLeft(2, '0');
  final local = value.toLocal();
  return '${local.year}-${twoDigits(local.month)}-${twoDigits(local.day)} '
      '${twoDigits(local.hour)}:${twoDigits(local.minute)}:${twoDigits(local.second)}';
}

class SettingsPage extends StatefulWidget {
  const SettingsPage({
    super.key,
    required this.initialExcludeMarkdownCode,
    required this.initialUseHeuristics,
    required this.initialThemeMode,
    required this.initialPalette,
    required this.onExcludeMarkdownCodeChanged,
    required this.onUseHeuristicsChanged,
    required this.onThemeModeChanged,
    required this.onPaletteChanged,
  });

  final bool initialExcludeMarkdownCode;
  final bool initialUseHeuristics;
  final ThemeMode initialThemeMode;
  final AppPalette initialPalette;
  final ValueChanged<bool> onExcludeMarkdownCodeChanged;
  final ValueChanged<bool> onUseHeuristicsChanged;
  final ValueChanged<ThemeMode> onThemeModeChanged;
  final ValueChanged<AppPalette> onPaletteChanged;

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  late bool _excludeMarkdownCode;
  late bool _useHeuristics;
  late ThemeMode _themeMode;
  late AppPalette _palette;

  @override
  void initState() {
    super.initState();
    _excludeMarkdownCode = widget.initialExcludeMarkdownCode;
    _useHeuristics = widget.initialUseHeuristics;
    _themeMode = widget.initialThemeMode;
    _palette = widget.initialPalette;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('设置')),
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 680),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
              children: [
                const _SettingsSectionTitle('转换'),
                SwitchListTile(
                  key: const Key('excludeMarkdownCodeSetting'),
                  contentPadding: EdgeInsets.zero,
                  secondary: const Icon(Icons.code_rounded),
                  title: const Text('排除 Markdown 代码'),
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
                  value: _useHeuristics,
                  onChanged: (value) {
                    setState(() => _useHeuristics = value);
                    widget.onUseHeuristicsChanged(value);
                  },
                ),
                const Divider(height: 32),
                const _SettingsSectionTitle('外观'),
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
                const SizedBox(height: 24),
                Text('配色', style: theme.textTheme.titleSmall),
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
                const Divider(height: 32),
                const _SettingsSectionTitle('关于'),
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
                  subtitle: const Text('GitHub'),
                  trailing: Text(
                    appAuthor,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
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
                    applicationIcon: const Icon(
                      Icons.format_quote_rounded,
                      size: 42,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
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
