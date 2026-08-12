import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jo_quote_converter/draft_store.dart';
import 'package:jo_quote_converter/history_store.dart';
import 'package:jo_quote_converter/main.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late HistoryStore historyStore;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    historyStore = _MemoryHistoryStore();
  });

  testWidgets('converts text and displays the result', (tester) async {
    await tester.pumpWidget(QuoteConverterApp(historyStore: historyStore));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).first, 'He said, "Hello."');
    await tester.tap(find.widgetWithText(FilledButton, '转换'));
    await tester.pump();

    expect(
      tester.widget<TextField>(find.byType(TextField).last).controller?.text,
      'He said, “Hello.”',
    );
    expect(
      tester
          .widget<OutlinedButton>(find.byKey(const Key('copyButton')))
          .onPressed,
      isNotNull,
    );
  });

  testWidgets('adds one history entry for every conversion', (tester) async {
    await tester.pumpWidget(QuoteConverterApp(historyStore: historyStore));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, '"历史"');

    await tester.tap(find.byKey(const Key('convertButton')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('convertButton')));
    await tester.pump();
    await tester.tap(find.byTooltip('历史记录'));
    await tester.pumpAndSettle();

    expect(find.text('2 条'), findsOneWidget);
    expect(find.byKey(const Key('historyEntry_0')), findsOneWidget);
    expect(find.byKey(const Key('historyEntry_1')), findsOneWidget);
    expect(
      tester.widget<Text>(find.byKey(const Key('historyInput_0'))).data,
      '"历史"',
    );
    expect(
      tester.widget<Text>(find.byKey(const Key('historyOutput_0'))).data,
      '“历史”',
    );
  });

  testWidgets('restores a history entry directly into an empty workspace', (
    tester,
  ) async {
    historyStore = _MemoryHistoryStore()
      ..seed(
        ConversionHistoryEntry(
          input: '"旧原文"',
          output: '“旧原文”',
          createdAt: DateTime(2026, 8, 12, 12),
        ),
      );
    await tester.pumpWidget(QuoteConverterApp(historyStore: historyStore));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('历史记录'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('historyRestore_0')));
    await tester.pumpAndSettle();

    expect(find.text('恢复历史记录？'), findsNothing);
    expect(
      tester.widget<TextField>(find.byType(TextField).first).controller?.text,
      '"旧原文"',
    );
    expect(
      tester.widget<TextField>(find.byType(TextField).last).controller?.text,
      '“旧原文”',
    );
    expect(find.text('已恢复到工作区'), findsOneWidget);
  });

  testWidgets('confirms before restoring over a non-empty workspace', (
    tester,
  ) async {
    historyStore = _MemoryHistoryStore()
      ..seed(
        ConversionHistoryEntry(
          input: '历史原文',
          output: '历史结果',
          createdAt: DateTime(2026, 8, 12, 12),
        ),
      );
    await tester.pumpWidget(QuoteConverterApp(historyStore: historyStore));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, '当前工作区');

    await tester.tap(find.byTooltip('历史记录'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('historyRestore_0')));
    await tester.pumpAndSettle();
    expect(find.text('恢复历史记录？'), findsOneWidget);
    expect(find.text('当前工作区内容将被覆盖。'), findsOneWidget);

    await tester.tap(find.byKey(const Key('cancelRestoreButton')));
    await tester.pumpAndSettle();
    expect(find.text('当前工作区'), findsOneWidget);

    await tester.tap(find.byKey(const Key('historyRestore_0')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('confirmRestoreButton')));
    await tester.pumpAndSettle();

    expect(
      tester.widget<TextField>(find.byType(TextField).first).controller?.text,
      '历史原文',
    );
    expect(
      tester.widget<TextField>(find.byType(TextField).last).controller?.text,
      '历史结果',
    );
    final draft = await DraftStore().load();
    expect(draft.input, '历史原文');
    expect(draft.output, '历史结果');
  });

  testWidgets('requires confirmation before deleting one history entry', (
    tester,
  ) async {
    historyStore = _MemoryHistoryStore()
      ..seed(
        ConversionHistoryEntry(
          id: 1,
          input: '保留记录',
          output: '保留结果',
          createdAt: DateTime(2026, 8, 12, 11),
        ),
      )
      ..seed(
        ConversionHistoryEntry(
          id: 2,
          input: '删除记录',
          output: '删除结果',
          createdAt: DateTime(2026, 8, 12, 12),
        ),
      );
    await tester.pumpWidget(QuoteConverterApp(historyStore: historyStore));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('历史记录'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('historyDelete_0')));
    await tester.pumpAndSettle();
    expect(find.text('删除这条历史记录？'), findsOneWidget);
    expect(find.text('删除后无法恢复。'), findsOneWidget);
    await tester.tap(find.byKey(const Key('cancelDeleteHistoryButton')));
    await tester.pumpAndSettle();
    expect(find.text('2 条'), findsOneWidget);

    await tester.tap(find.byKey(const Key('historyDelete_0')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('confirmDeleteHistoryButton')));
    await tester.pumpAndSettle();

    expect(find.text('1 条'), findsOneWidget);
    expect(find.text('删除记录'), findsNothing);
    expect(find.text('保留记录'), findsOneWidget);
    expect(find.text('历史记录已删除'), findsOneWidget);
  });

  testWidgets('keeps the new entry visible when history storage fails', (
    tester,
  ) async {
    historyStore = _FailingHistoryStore();
    await tester.pumpWidget(QuoteConverterApp(historyStore: historyStore));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, '"保存失败"');

    await tester.tap(find.byKey(const Key('convertButton')));
    await tester.pumpAndSettle();
    expect(find.text('历史记录保存失败，本次记录尚未写入磁盘'), findsOneWidget);

    await tester.tap(find.byTooltip('历史记录'));
    await tester.pumpAndSettle();
    expect(find.text('1 条'), findsOneWidget);
    expect(find.text('部分历史记录尚未写入磁盘。'), findsOneWidget);
    expect(
      tester.widget<Text>(find.byKey(const Key('historyInput_0'))).data,
      '"保存失败"',
    );
    expect(
      tester.widget<Text>(find.byKey(const Key('historyOutput_0'))).data,
      '“保存失败”',
    );
  });

  testWidgets('requires confirmation before clearing both editors', (
    tester,
  ) async {
    await tester.pumpWidget(QuoteConverterApp(historyStore: historyStore));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, '待清空文本');
    await tester.pump();

    await tester.tap(find.byKey(const Key('clearButton')));
    await tester.pumpAndSettle();
    expect(find.text('确认清空？'), findsOneWidget);
    expect(find.text('待清空文本'), findsOneWidget);

    await tester.tap(find.byKey(const Key('cancelClearButton')));
    await tester.pumpAndSettle();
    expect(find.text('待清空文本'), findsOneWidget);

    await tester.tap(find.byKey(const Key('clearButton')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('confirmClearButton')));
    await tester.pumpAndSettle();
    expect(find.text('待清空文本'), findsNothing);
  });

  testWidgets('shows the compact layout without overflow', (tester) async {
    tester.view.physicalSize = const Size(320, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(QuoteConverterApp(historyStore: historyStore));
    await tester.pumpAndSettle();

    expect(find.byTooltip('设置'), findsOneWidget);
    await tester.tap(find.byTooltip('设置'));
    await tester.pumpAndSettle();
    expect(find.text('排除 Markdown 代码'), findsOneWidget);
    expect(find.text('启发式判断'), findsOneWidget);
    expect(find.text('0.0.1+1'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('shows author and opens bundled license texts', (tester) async {
    await tester.pumpWidget(QuoteConverterApp(historyStore: historyStore));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('设置'));
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(find.byKey(const Key('aboutAuthor')), 300);
    expect(find.text('JO-Beacon'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.byKey(const Key('aboutProjectLicense')),
      200,
    );
    expect(find.text('Apache License 2.0'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.byKey(const Key('aboutFontLicense')),
      200,
    );
    expect(find.text('SIL Open Font License 1.1'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.byKey(const Key('aboutOpenSourceLicenses')),
      200,
    );
    expect(find.text('第三方开源许可证'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.byKey(const Key('aboutProjectLicense')),
      -200,
    );
    await tester.tap(find.byKey(const Key('aboutProjectLicense')));
    await tester.pumpAndSettle();
    expect(find.textContaining('Apache License'), findsWidgets);
    expect(find.textContaining('Version 2.0, January 2004'), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.byKey(const Key('aboutFontLicense')),
      300,
    );
    await tester.tap(find.byKey(const Key('aboutFontLicense')));
    await tester.pumpAndSettle();
    expect(find.text('思源黑体许可证'), findsOneWidget);
    expect(
      find.textContaining('SIL OPEN FONT LICENSE Version 1.1'),
      findsOneWidget,
    );
  });

  testWidgets('switches to dark mode from settings', (tester) async {
    await tester.pumpWidget(QuoteConverterApp(historyStore: historyStore));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('设置'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('深色'));
    await tester.pumpAndSettle();

    final settingsContext = tester.element(find.byType(SettingsPage));
    expect(Theme.of(settingsContext).brightness, Brightness.dark);
    expect(await DraftStore().loadThemeMode(), ThemeMode.dark.name);
  });

  testWidgets('defaults to gray and persists the selected color palette', (
    tester,
  ) async {
    await tester.pumpWidget(QuoteConverterApp(historyStore: historyStore));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('设置'));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('selectedPalette_gray')), findsOneWidget);
    final settingsContext = tester.element(find.byType(SettingsPage));
    final initialPrimary = Theme.of(settingsContext).colorScheme.primary;

    await tester.tap(find.byKey(const Key('palette_red')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('selectedPalette_red')), findsOneWidget);
    expect(
      Theme.of(settingsContext).colorScheme.primary,
      isNot(initialPrimary),
    );
    expect(await DraftStore().loadPalette(), AppPalette.red.name);
  });

  testWidgets('uses the bundled Source Han Sans font', (tester) async {
    await tester.pumpWidget(QuoteConverterApp(historyStore: historyStore));
    await tester.pumpAndSettle();

    final scaffoldContext = tester.element(find.byType(Scaffold));
    expect(
      Theme.of(scaffoldContext).textTheme.bodyMedium?.fontFamily,
      'SourceHanSansSC',
    );
  });

  testWidgets('restores and automatically saves the current draft', (
    tester,
  ) async {
    await DraftStore().save(
      const SavedDraft(
        input: '之前的原文',
        output: '之前的结果',
        excludeMarkdownCode: false,
        useHeuristics: false,
      ),
    );
    await tester.pumpWidget(QuoteConverterApp(historyStore: historyStore));
    await tester.pumpAndSettle();

    expect(find.text('之前的原文'), findsOneWidget);
    expect(find.text('之前的结果'), findsOneWidget);

    await tester.tap(find.byTooltip('设置'));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<SwitchListTile>(
            find.byKey(const Key('excludeMarkdownCodeSetting')),
          )
          .value,
      isFalse,
    );
    expect(
      tester
          .widget<SwitchListTile>(find.byKey(const Key('useHeuristicsSetting')))
          .value,
      isFalse,
    );
    await tester.pageBack();
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).first, '刚刚输入的文本');
    await tester.pump(const Duration(milliseconds: 350));
    final saved = await DraftStore().load();
    expect(saved.input, '刚刚输入的文本');
    expect(saved.useHeuristics, isFalse);
  });

  testWidgets('heuristic and Markdown switches affect conversion separately', (
    tester,
  ) async {
    await tester.pumpWidget(QuoteConverterApp(historyStore: historyStore));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('设置'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('useHeuristicsSetting')));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<SwitchListTile>(
            find.byKey(const Key('excludeMarkdownCodeSetting')),
          )
          .value,
      isTrue,
    );
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byType(TextField).first,
      "'outside' `code 'x'` 'again'",
    );
    await tester.tap(find.widgetWithText(FilledButton, '转换'));
    await tester.pump();

    expect(find.text("‘outside’ `code 'x'` ‘again’"), findsOneWidget);
  });

  testWidgets('opens the history records UI', (tester) async {
    await tester.pumpWidget(QuoteConverterApp(historyStore: historyStore));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('历史记录'));
    await tester.pumpAndSettle();

    expect(find.text('历史记录'), findsOneWidget);
    expect(find.text('暂无历史记录'), findsOneWidget);
  });
}

class _MemoryHistoryStore extends HistoryStore {
  final List<ConversionHistoryEntry> _entries = [];

  void seed(ConversionHistoryEntry entry) => _entries.insert(0, entry);

  @override
  Future<List<ConversionHistoryEntry>> load() async => List.of(_entries);

  @override
  Future<void> add(ConversionHistoryEntry entry) async {
    _entries.insert(0, entry);
  }

  @override
  Future<void> delete(ConversionHistoryEntry entry) async {
    _entries.removeWhere((candidate) => identical(candidate, entry));
  }

  @override
  Future<void> close() async {}
}

class _FailingHistoryStore extends _MemoryHistoryStore {
  @override
  Future<void> add(ConversionHistoryEntry entry) async {
    throw StateError('history write failed');
  }
}
