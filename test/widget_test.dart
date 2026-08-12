import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jo_quote_converter/archive_service.dart';
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

    expect(find.text('2 条记录'), findsOneWidget);
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
    expect(find.byType(HistoryPage), findsOneWidget);

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
    expect(find.text('2 条记录'), findsOneWidget);

    await tester.tap(find.byKey(const Key('historyDelete_0')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('confirmDeleteHistoryButton')));
    await tester.pumpAndSettle();

    expect(find.text('1 条记录'), findsOneWidget);
    expect(find.text('删除记录'), findsNothing);
    expect(find.text('保留记录'), findsOneWidget);
    expect(find.text('历史记录已删除'), findsOneWidget);
  });

  testWidgets('shows history storage size and opens complete details', (
    tester,
  ) async {
    String? copiedText;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          copiedText =
              (call.arguments as Map<Object?, Object?>)['text'] as String;
        }
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );
    const longInput = '这是一段不会在详情页截断的完整历史原文。';
    const longOutput = '这是一段不会在详情页截断的完整转换结果。';
    historyStore = _MemoryHistoryStore()
      ..seed(
        ConversionHistoryEntry(
          id: 1,
          input: longInput,
          output: longOutput,
          createdAt: DateTime(2026, 8, 13, 10),
        ),
      );
    await tester.pumpWidget(QuoteConverterApp(historyStore: historyStore));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('历史记录'));
    await tester.pumpAndSettle();

    expect(find.text('占用 4.0 KB'), findsOneWidget);
    await tester.tap(find.byKey(const Key('historyDetails_0')));
    await tester.pumpAndSettle();
    expect(find.text('历史记录详情'), findsOneWidget);
    expect(find.text(longInput), findsOneWidget);
    expect(find.text(longOutput), findsOneWidget);

    await tester.tap(find.byTooltip('复制原文'));
    await tester.pumpAndSettle();
    expect(copiedText, longInput);
    expect(find.text('原文已复制'), findsOneWidget);
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
    expect(find.text('1 条记录'), findsOneWidget);
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
    expect(find.text('语言'), findsOneWidget);
    expect(find.text('外观'), findsOneWidget);
    expect(find.text('行为'), findsOneWidget);
    expect(find.text('快捷键'), findsOneWidget);
    expect(find.text('关于'), findsOneWidget);
    await tester.tap(find.byKey(const Key('settingsAbout')));
    await tester.pumpAndSettle();
    expect(find.text('https://github.com/JO-Beacon/'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('shows author and opens bundled license texts', (tester) async {
    await tester.pumpWidget(QuoteConverterApp(historyStore: historyStore));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('设置'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('settingsAbout')));
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(find.byKey(const Key('aboutAuthor')), 300);
    expect(find.text('JO-Beacon'), findsOneWidget);
    expect(find.text('https://github.com/JO-Beacon/'), findsOneWidget);
    expect(
      tester.widget<ListTile>(find.byKey(const Key('aboutAuthor'))).onTap,
      isNotNull,
    );
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
    await tester.tap(find.byKey(const Key('settingsAppearance')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('深色'));
    await tester.pumpAndSettle();

    final appearanceContext = tester.element(
      find.byType(SegmentedButton<ThemeMode>),
    );
    expect(Theme.of(appearanceContext).brightness, Brightness.dark);
    expect(await DraftStore().loadThemeMode(), ThemeMode.dark.name);
  });

  testWidgets('defaults to gray and persists the selected color palette', (
    tester,
  ) async {
    await tester.pumpWidget(QuoteConverterApp(historyStore: historyStore));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('设置'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('settingsAppearance')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('selectedPalette_gray')), findsOneWidget);
    final appearanceContext = tester.element(
      find.byType(SegmentedButton<ThemeMode>),
    );
    final initialTheme = Theme.of(appearanceContext);
    final initialPrimary = initialTheme.colorScheme.primary;
    expect(initialTheme.scaffoldBackgroundColor, const Color(0xFFF5F5F5));
    expect(initialTheme.colorScheme.surface, const Color(0xFFFAFAFA));
    expect(
      initialTheme.inputDecorationTheme.enabledBorder,
      isA<OutlineInputBorder>().having(
        (border) => border.borderSide.color,
        'border color',
        const Color(0xFFD8D8D8),
      ),
    );
    for (final color in _colorSchemeColors(initialTheme.colorScheme)) {
      expect(color.r, color.g);
      expect(color.g, color.b);
    }

    await tester.tap(find.text('深色'));
    await tester.pumpAndSettle();
    final darkTheme = Theme.of(appearanceContext);
    expect(darkTheme.scaffoldBackgroundColor, const Color(0xFF121212));
    expect(darkTheme.colorScheme.surface, const Color(0xFF1A1A1A));
    expect(
      darkTheme.inputDecorationTheme.enabledBorder,
      isA<OutlineInputBorder>().having(
        (border) => border.borderSide.color,
        'border color',
        const Color(0xFF424242),
      ),
    );
    for (final color in _colorSchemeColors(darkTheme.colorScheme)) {
      expect(color.r, color.g);
      expect(color.g, color.b);
    }

    await tester.tap(find.byKey(const Key('palette_red')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('selectedPalette_red')), findsOneWidget);
    expect(
      Theme.of(appearanceContext).colorScheme.primary,
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
    await tester.tap(find.byKey(const Key('settingsBehavior')));
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
    await tester.tap(find.byKey(const Key('settingsBehavior')));
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

  testWidgets('searches history input and output text', (tester) async {
    historyStore = _MemoryHistoryStore()
      ..seed(
        ConversionHistoryEntry(
          id: 1,
          input: 'Apple source',
          output: '苹果结果',
          createdAt: DateTime(2026, 8, 12, 11),
        ),
      )
      ..seed(
        ConversionHistoryEntry(
          id: 2,
          input: 'Banana source',
          output: '香蕉结果',
          createdAt: DateTime(2026, 8, 12, 12),
        ),
      );
    await tester.pumpWidget(QuoteConverterApp(historyStore: historyStore));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('历史记录'));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const Key('historySearchField')),
      'apple',
    );
    await tester.pump();
    expect(find.text('Apple source'), findsOneWidget);
    expect(find.text('Banana source'), findsNothing);
    expect(find.text('1 条结果，共 2 条记录'), findsOneWidget);

    await tester.enterText(find.byKey(const Key('historySearchField')), '香蕉');
    await tester.pump();
    expect(find.text('Apple source'), findsNothing);
    expect(find.text('香蕉结果'), findsOneWidget);

    await tester.enterText(
      find.byKey(const Key('historySearchField')),
      'not found',
    );
    await tester.pump();
    expect(find.text('没有匹配的历史记录'), findsOneWidget);
  });

  testWidgets('requires confirmation before clearing all history', (
    tester,
  ) async {
    historyStore = _MemoryHistoryStore()
      ..seed(
        ConversionHistoryEntry(
          id: 1,
          input: '第一条',
          output: '第一条结果',
          createdAt: DateTime(2026, 8, 12, 11),
        ),
      )
      ..seed(
        ConversionHistoryEntry(
          id: 2,
          input: '第二条',
          output: '第二条结果',
          createdAt: DateTime(2026, 8, 12, 12),
        ),
      );
    await tester.pumpWidget(QuoteConverterApp(historyStore: historyStore));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('历史记录'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('clearAllHistoryButton')));
    await tester.pumpAndSettle();
    expect(find.text('清空全部历史记录？'), findsOneWidget);
    expect(find.textContaining('全部 2 条历史记录'), findsOneWidget);
    await tester.tap(find.byKey(const Key('cancelClearHistoryButton')));
    await tester.pumpAndSettle();
    expect(find.text('2 条记录'), findsOneWidget);

    await tester.tap(find.byKey(const Key('clearAllHistoryButton')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('confirmClearHistoryButton')));
    await tester.pumpAndSettle();
    expect(find.text('暂无历史记录'), findsOneWidget);
    expect(find.text('历史记录已全部清空'), findsOneWidget);
    expect(await historyStore.load(), isEmpty);
  });

  testWidgets('settings list opens language and shortcut pages', (
    tester,
  ) async {
    await tester.pumpWidget(QuoteConverterApp(historyStore: historyStore));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('设置'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('settingsLanguage')));
    await tester.pumpAndSettle();
    expect(find.text('当前唯一支持的界面语言'), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('settingsShortcuts')));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<SwitchListTile>(
            find.byKey(const Key('keyboardShortcutsEnabledSetting')),
          )
          .value,
      isTrue,
    );
    expect(find.byKey(const Key('shortcutConvert')), findsOneWidget);
    expect(find.text('Ctrl'), findsOneWidget);
    expect(find.text('Enter'), findsOneWidget);
  });

  testWidgets('Ctrl+Enter converts the current text', (tester) async {
    await tester.pumpWidget(QuoteConverterApp(historyStore: historyStore));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, '"快捷键"');

    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pumpAndSettle();

    expect(
      tester.widget<TextField>(find.byType(TextField).last).controller?.text,
      '“快捷键”',
    );
    expect(await historyStore.load(), hasLength(1));
  });

  testWidgets('disables shortcuts without disabling the convert button', (
    tester,
  ) async {
    await tester.pumpWidget(QuoteConverterApp(historyStore: historyStore));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('设置'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('settingsShortcuts')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('keyboardShortcutsEnabledSetting')));
    await tester.pumpAndSettle();
    expect(
      tester.widget<ListTile>(find.byKey(const Key('shortcutConvert'))).enabled,
      isFalse,
    );
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('已关闭'), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).first, '"关闭快捷键"');
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pumpAndSettle();
    expect(
      tester.widget<TextField>(find.byType(TextField).last).controller?.text,
      isEmpty,
    );
    expect(await historyStore.load(), isEmpty);

    await tester.tap(find.byKey(const Key('convertButton')));
    await tester.pumpAndSettle();
    expect(
      tester.widget<TextField>(find.byType(TextField).last).controller?.text,
      '“关闭快捷键”',
    );
    expect(await historyStore.load(), hasLength(1));
  });

  testWidgets('restores the disabled shortcut setting after restart', (
    tester,
  ) async {
    await DraftStore().saveKeyboardShortcutsEnabled(false);
    await tester.pumpWidget(QuoteConverterApp(historyStore: historyStore));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('设置'));
    await tester.pumpAndSettle();
    expect(find.text('已关闭'), findsOneWidget);
    await tester.tap(find.byKey(const Key('settingsShortcuts')));
    await tester.pumpAndSettle();

    expect(
      tester
          .widget<SwitchListTile>(
            find.byKey(const Key('keyboardShortcutsEnabledSetting')),
          )
          .value,
      isFalse,
    );
  });

  testWidgets('exports the complete current archive snapshot', (tester) async {
    final archiveService = _MemoryArchiveService();
    historyStore = _MemoryHistoryStore()
      ..seed(
        ConversionHistoryEntry(
          id: 1,
          input: '历史原文',
          output: '历史结果',
          createdAt: DateTime(2026, 8, 12, 12),
        ),
      );
    await tester.pumpWidget(
      QuoteConverterApp(
        historyStore: historyStore,
        archiveService: archiveService,
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, '导出工作区');
    await tester.tap(find.byTooltip('设置'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('settingsDataArchive')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('exportArchive')));
    await tester.pumpAndSettle();

    expect(archiveService.exportCalls, 1);
    expect(archiveService.exportedSnapshot?.draft.input, '导出工作区');
    expect(archiveService.exportedSnapshot?.history, hasLength(1));
    expect(find.text('存档导出成功'), findsOneWidget);
  });

  testWidgets('restores an automatic backup after confirmation', (
    tester,
  ) async {
    final backupDocument = ArchiveDocument(
      appVersion: '0.0.1+1',
      exportedAt: DateTime(2026, 8, 13, 9),
      snapshot: ArchiveSnapshot(
        draft: const SavedDraft(
          input: '备份原文',
          output: '备份结果',
          excludeMarkdownCode: false,
          useHeuristics: false,
        ),
        themeMode: 'dark',
        palette: 'blue',
        keyboardShortcutsEnabled: false,
        history: [
          ConversionHistoryEntry(
            input: '备份历史',
            output: '备份历史结果',
            createdAt: DateTime(2026, 8, 13, 9),
          ),
        ],
      ),
    );
    final archiveService = _MemoryArchiveService(
      backups: [
        AutomaticBackup(
          fileName: 'before-import.joquoteconverter',
          sizeBytes: 2048,
          modifiedAt: DateTime(2026, 8, 13, 9),
          document: backupDocument,
        ),
      ],
    );
    historyStore = _MemoryHistoryStore()
      ..seed(
        ConversionHistoryEntry(
          id: 1,
          input: '当前历史',
          output: '当前历史结果',
          createdAt: DateTime(2026, 8, 13, 10),
        ),
      );
    await tester.pumpWidget(
      QuoteConverterApp(
        historyStore: historyStore,
        archiveService: archiveService,
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, '当前工作区');
    await tester.tap(find.byTooltip('设置'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('settingsDataArchive')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('manageAutomaticBackups')));
    await tester.pumpAndSettle();

    expect(find.text('版本 0.0.1+1 · 1 条历史 · 2.0 KB'), findsOneWidget);
    await tester.tap(find.byKey(const Key('restoreAutomaticBackup_0')));
    await tester.pumpAndSettle();
    expect(find.text('恢复此自动备份？'), findsOneWidget);
    expect(find.textContaining('覆盖当前工作区、设置和全部历史记录'), findsOneWidget);
    await tester.tap(
      find.byKey(const Key('cancelRestoreAutomaticBackupButton')),
    );
    await tester.pumpAndSettle();
    expect(archiveService.backupCalls, 0);

    await tester.tap(find.byKey(const Key('restoreAutomaticBackup_0')));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const Key('confirmRestoreAutomaticBackupButton')),
    );
    await tester.pumpAndSettle();

    expect(find.text('自动备份已恢复'), findsOneWidget);
    expect(archiveService.backupCalls, 1);
    final history = await historyStore.load();
    expect(history, hasLength(1));
    expect(history.single.input, '备份历史');
    final draft = await DraftStore().load();
    expect(draft.input, '备份原文');
    expect(await DraftStore().loadThemeMode(), 'dark');
    expect(await DraftStore().loadPalette(), 'blue');
  });

  testWidgets('confirms before deleting and clearing automatic backups', (
    tester,
  ) async {
    AutomaticBackup backup(String name, int hour) => AutomaticBackup(
      fileName: '$name.joquoteconverter',
      sizeBytes: 1024,
      modifiedAt: DateTime(2026, 8, 13, hour),
      document: ArchiveDocument(
        appVersion: '0.0.2+2',
        exportedAt: DateTime(2026, 8, 13, hour),
        snapshot: ArchiveSnapshot(
          draft: const SavedDraft(
            input: '',
            output: '',
            excludeMarkdownCode: true,
            useHeuristics: true,
          ),
          themeMode: 'system',
          palette: 'gray',
          keyboardShortcutsEnabled: true,
          history: const [],
        ),
      ),
    );
    final archiveService = _MemoryArchiveService(
      backups: [backup('newer', 11), backup('older', 10)],
    );
    await tester.pumpWidget(
      QuoteConverterApp(
        historyStore: historyStore,
        archiveService: archiveService,
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('设置'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('settingsDataArchive')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('manageAutomaticBackups')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('deleteAutomaticBackup_0')));
    await tester.pumpAndSettle();
    expect(find.text('删除此自动备份？'), findsOneWidget);
    await tester.tap(
      find.byKey(const Key('cancelDeleteAutomaticBackupButton')),
    );
    await tester.pumpAndSettle();
    expect(archiveService.deleteBackupCalls, 0);

    await tester.tap(find.byKey(const Key('deleteAutomaticBackup_0')));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const Key('confirmDeleteAutomaticBackupButton')),
    );
    await tester.pumpAndSettle();
    expect(archiveService.deleteBackupCalls, 1);
    expect(find.byKey(const Key('automaticBackup_1')), findsNothing);

    await tester.tap(find.byKey(const Key('clearAutomaticBackupsButton')));
    await tester.pumpAndSettle();
    expect(find.text('清空全部自动备份？'), findsOneWidget);
    await tester.tap(
      find.byKey(const Key('confirmClearAutomaticBackupsButton')),
    );
    await tester.pumpAndSettle();
    expect(archiveService.clearBackupCalls, 1);
    expect(find.text('暂无自动备份'), findsOneWidget);
  });

  testWidgets(
    'shows history details and automatic backups on a narrow screen',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final document = ArchiveDocument(
        appVersion: '0.0.2+2',
        exportedAt: DateTime(2026, 8, 13, 9),
        snapshot: ArchiveSnapshot(
          draft: const SavedDraft(
            input: '',
            output: '',
            excludeMarkdownCode: true,
            useHeuristics: true,
          ),
          themeMode: 'system',
          palette: 'gray',
          keyboardShortcutsEnabled: true,
          history: const [],
        ),
      );
      final archiveService = _MemoryArchiveService(
        backups: [
          AutomaticBackup(
            fileName: 'narrow.joquoteconverter',
            sizeBytes: 2048,
            modifiedAt: DateTime(2026, 8, 13, 9),
            document: document,
          ),
        ],
      );
      historyStore = _MemoryHistoryStore()
        ..seed(
          ConversionHistoryEntry(
            id: 1,
            input: '窄屏历史原文',
            output: '窄屏历史结果',
            createdAt: DateTime(2026, 8, 13, 9),
          ),
        );
      await tester.pumpWidget(
        QuoteConverterApp(
          historyStore: historyStore,
          archiveService: archiveService,
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('历史记录'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('historyDetails_0')));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.pageBack();
      await tester.pumpAndSettle();
      await tester.pageBack();
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('设置'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('settingsDataArchive')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('manageAutomaticBackups')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('automaticBackup_0')), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'validates import choices and imports the selected archive data',
    (tester) async {
      final duplicateTime = DateTime(2026, 8, 12, 12);
      final archiveService = _MemoryArchiveService(
        document: ArchiveDocument(
          appVersion: '0.0.1+1',
          exportedAt: DateTime(2026, 8, 12, 13),
          snapshot: ArchiveSnapshot(
            draft: const SavedDraft(
              input: '存档原文',
              output: '存档结果',
              excludeMarkdownCode: false,
              useHeuristics: false,
            ),
            themeMode: 'dark',
            palette: 'red',
            keyboardShortcutsEnabled: false,
            history: [
              ConversionHistoryEntry(
                input: '重复记录',
                output: '重复结果',
                createdAt: duplicateTime,
              ),
              ConversionHistoryEntry(
                input: '新增记录',
                output: '新增结果',
                createdAt: DateTime(2026, 8, 12, 13),
              ),
            ],
          ),
        ),
      );
      historyStore = _MemoryHistoryStore()
        ..seed(
          ConversionHistoryEntry(
            id: 1,
            input: '重复记录',
            output: '重复结果',
            createdAt: duplicateTime,
          ),
        );
      await tester.pumpWidget(
        QuoteConverterApp(
          historyStore: historyStore,
          archiveService: archiveService,
        ),
      );
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).first, '当前工作区');
      await tester.tap(find.byTooltip('设置'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('settingsDataArchive')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('importArchive')));
      await tester.pumpAndSettle();
      expect(find.text('导入此存档？'), findsOneWidget);
      expect(find.text('来源版本：0.0.1+1'), findsOneWidget);
      expect(find.text('历史记录：2 条'), findsOneWidget);
      await tester.tap(find.byKey(const Key('cancelImportArchiveButton')));
      await tester.pumpAndSettle();
      expect(archiveService.backupCalls, 0);

      await tester.tap(find.byKey(const Key('importArchive')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('importWorkspaceOption')));
      await tester.tap(find.byKey(const Key('importSettingsOption')));
      await tester.tap(find.text('不导入'));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<FilledButton>(
              find.byKey(const Key('confirmImportArchiveButton')),
            )
            .onPressed,
        isNull,
      );
      await tester.tap(find.byKey(const Key('importWorkspaceOption')));
      await tester.tap(find.byKey(const Key('importSettingsOption')));
      await tester.tap(find.text('合并'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('confirmImportArchiveButton')));
      await tester.pumpAndSettle();

      expect(archiveService.backupCalls, 1);
      expect(find.text('存档导入成功'), findsOneWidget);
      expect(await historyStore.load(), hasLength(2));
      final savedDraft = await DraftStore().load();
      expect(savedDraft.input, '存档原文');
      expect(savedDraft.output, '存档结果');
      expect(savedDraft.excludeMarkdownCode, isFalse);
      expect(savedDraft.useHeuristics, isFalse);
      expect(await DraftStore().loadThemeMode(), 'dark');
      expect(await DraftStore().loadPalette(), 'red');
      expect(await DraftStore().loadKeyboardShortcutsEnabled(), isFalse);

      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.text('深色 · 红色'), findsOneWidget);
      expect(find.text('已关闭'), findsOneWidget);
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(
        tester.widget<TextField>(find.byType(TextField).first).controller?.text,
        '存档原文',
      );
      expect(
        tester.widget<TextField>(find.byType(TextField).last).controller?.text,
        '存档结果',
      );
    },
  );

  testWidgets('overwrites current history with archive history', (
    tester,
  ) async {
    final archiveService = _MemoryArchiveService(
      document: ArchiveDocument(
        appVersion: '0.0.2+2',
        exportedAt: DateTime(2026, 8, 12, 13),
        snapshot: ArchiveSnapshot(
          draft: const SavedDraft(
            input: '存档工作区',
            output: '存档结果',
            excludeMarkdownCode: true,
            useHeuristics: true,
          ),
          themeMode: 'system',
          palette: 'gray',
          keyboardShortcutsEnabled: true,
          history: [
            ConversionHistoryEntry(
              input: '存档历史',
              output: '存档历史结果',
              createdAt: DateTime(2026, 8, 12, 13),
            ),
          ],
        ),
      ),
    );
    historyStore = _MemoryHistoryStore()
      ..seed(
        ConversionHistoryEntry(
          id: 1,
          input: '应被删除的历史',
          output: '应被删除的结果',
          createdAt: DateTime(2026, 8, 12, 12),
        ),
      );
    await tester.pumpWidget(
      QuoteConverterApp(
        historyStore: historyStore,
        archiveService: archiveService,
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, '保留当前工作区');
    await tester.tap(find.byTooltip('设置'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('settingsDataArchive')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('importArchive')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('importWorkspaceOption')));
    await tester.tap(find.byKey(const Key('importSettingsOption')));
    await tester.tap(find.text('覆盖'));
    await tester.pumpAndSettle();
    expect(find.text('删除当前历史记录，替换为存档中的记录'), findsOneWidget);
    await tester.tap(find.byKey(const Key('confirmImportArchiveButton')));
    await tester.pumpAndSettle();

    final storedHistory = await historyStore.load();
    expect(storedHistory, hasLength(1));
    expect(storedHistory.single.input, '存档历史');
    expect(storedHistory.single.output, '存档历史结果');
    expect(archiveService.backupCalls, 1);
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(
      tester.widget<TextField>(find.byType(TextField).first).controller?.text,
      '保留当前工作区',
    );
  });

  testWidgets('rolls history back when archive import fails', (tester) async {
    final archiveService = _MemoryArchiveService(
      document: ArchiveDocument(
        appVersion: '0.0.1+1',
        exportedAt: DateTime(2026, 8, 12, 13),
        snapshot: ArchiveSnapshot(
          draft: const SavedDraft(
            input: '无法导入的原文',
            output: '无法导入的结果',
            excludeMarkdownCode: false,
            useHeuristics: false,
          ),
          themeMode: 'dark',
          palette: 'red',
          keyboardShortcutsEnabled: false,
          history: [
            ConversionHistoryEntry(
              input: '不应保留的新记录',
              output: '不应保留的新结果',
              createdAt: DateTime(2026, 8, 12, 13),
            ),
          ],
        ),
      ),
    );
    historyStore = _MemoryHistoryStore()
      ..seed(
        ConversionHistoryEntry(
          id: 1,
          input: '导入前记录',
          output: '导入前结果',
          createdAt: DateTime(2026, 8, 12, 12),
        ),
      );
    final draftStore = _FailingArchiveDraftStore();
    await tester.pumpWidget(
      QuoteConverterApp(
        historyStore: historyStore,
        archiveService: archiveService,
        draftStore: draftStore,
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('设置'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('settingsDataArchive')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('importArchive')));
    await tester.pumpAndSettle();

    draftStore.failNextArchiveSave = true;
    await tester.tap(find.byKey(const Key('confirmImportArchiveButton')));
    await tester.pumpAndSettle();

    expect(find.text('存档导入失败，已恢复导入前的数据'), findsOneWidget);
    final restoredHistory = await historyStore.load();
    expect(restoredHistory, hasLength(1));
    expect(restoredHistory.single.input, '导入前记录');
    expect(archiveService.backupCalls, 1);
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
    _entries.removeWhere(
      (candidate) =>
          identical(candidate, entry) ||
          (entry.id != null && candidate.id == entry.id),
    );
  }

  @override
  Future<void> clear() async => _entries.clear();

  @override
  Future<int> merge(List<ConversionHistoryEntry> entries) async {
    final existing = _entries
        .map(
          (entry) => (
            entry.input,
            entry.output,
            entry.createdAt.millisecondsSinceEpoch,
          ),
        )
        .toSet();
    var inserted = 0;
    for (final entry in entries) {
      final identity = (
        entry.input,
        entry.output,
        entry.createdAt.millisecondsSinceEpoch,
      );
      if (!existing.add(identity)) continue;
      _entries.add(entry);
      inserted++;
    }
    _entries.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return inserted;
  }

  @override
  Future<void> replaceAll(List<ConversionHistoryEntry> entries) async {
    _entries
      ..clear()
      ..addAll(entries);
  }

  @override
  Future<int> storageSizeBytes() async => 4096;

  @override
  Future<void> close() async {}
}

class _FailingHistoryStore extends _MemoryHistoryStore {
  @override
  Future<void> add(ConversionHistoryEntry entry) async {
    throw StateError('history write failed');
  }
}

class _MemoryArchiveService extends ArchiveService {
  _MemoryArchiveService({this.document, List<AutomaticBackup>? backups})
    : backups = List.of(backups ?? const []);

  final ArchiveDocument? document;
  final List<AutomaticBackup> backups;
  int exportCalls = 0;
  int backupCalls = 0;
  int deleteBackupCalls = 0;
  int clearBackupCalls = 0;
  ArchiveSnapshot? exportedSnapshot;

  @override
  Future<bool> exportWithPicker({
    required ArchiveSnapshot snapshot,
    required String appVersion,
    DateTime? now,
  }) async {
    exportCalls++;
    exportedSnapshot = snapshot;
    return true;
  }

  @override
  Future<ArchiveDocument?> pickAndDecode() async => document;

  @override
  Future<String> createAutomaticBackup({
    required ArchiveSnapshot snapshot,
    required String appVersion,
    DateTime? now,
  }) async {
    backupCalls++;
    if (backups.isNotEmpty) {
      backups.insert(
        0,
        AutomaticBackup(
          fileName: 'memory-backup-$backupCalls.$archiveExtension',
          sizeBytes: 1024,
          modifiedAt: DateTime(2026, 8, 13, 12, backupCalls),
          document: ArchiveDocument(
            appVersion: appVersion,
            exportedAt: DateTime(2026, 8, 13, 12, backupCalls),
            snapshot: snapshot,
          ),
        ),
      );
    }
    return 'memory-backup.$archiveExtension';
  }

  @override
  Future<List<AutomaticBackup>> listAutomaticBackups() async =>
      List.of(backups);

  @override
  Future<void> deleteAutomaticBackup(AutomaticBackup backup) async {
    deleteBackupCalls++;
    backups.removeWhere((item) => item.fileName == backup.fileName);
  }

  @override
  Future<int> clearAutomaticBackups() async {
    clearBackupCalls++;
    final count = backups.length;
    backups.clear();
    return count;
  }
}

class _FailingArchiveDraftStore extends DraftStore {
  bool failNextArchiveSave = false;

  @override
  Future<void> saveArchiveState({
    required SavedDraft draft,
    required String themeMode,
    required String palette,
    required bool keyboardShortcutsEnabled,
  }) async {
    if (failNextArchiveSave) {
      failNextArchiveSave = false;
      throw StateError('archive preferences write failed');
    }
    await super.saveArchiveState(
      draft: draft,
      themeMode: themeMode,
      palette: palette,
      keyboardShortcutsEnabled: keyboardShortcutsEnabled,
    );
  }
}

Iterable<Color> _colorSchemeColors(ColorScheme scheme) => [
  scheme.primary,
  scheme.onPrimary,
  scheme.primaryContainer,
  scheme.onPrimaryContainer,
  scheme.primaryFixed,
  scheme.primaryFixedDim,
  scheme.onPrimaryFixed,
  scheme.onPrimaryFixedVariant,
  scheme.secondary,
  scheme.onSecondary,
  scheme.secondaryContainer,
  scheme.onSecondaryContainer,
  scheme.secondaryFixed,
  scheme.secondaryFixedDim,
  scheme.onSecondaryFixed,
  scheme.onSecondaryFixedVariant,
  scheme.tertiary,
  scheme.onTertiary,
  scheme.tertiaryContainer,
  scheme.onTertiaryContainer,
  scheme.tertiaryFixed,
  scheme.tertiaryFixedDim,
  scheme.onTertiaryFixed,
  scheme.onTertiaryFixedVariant,
  scheme.surface,
  scheme.surfaceDim,
  scheme.surfaceBright,
  scheme.surfaceContainerLowest,
  scheme.surfaceContainerLow,
  scheme.surfaceContainer,
  scheme.surfaceContainerHigh,
  scheme.surfaceContainerHighest,
  scheme.onSurface,
  scheme.onSurfaceVariant,
  scheme.outline,
  scheme.outlineVariant,
  scheme.shadow,
  scheme.scrim,
  scheme.inverseSurface,
  scheme.onInverseSurface,
  scheme.inversePrimary,
];
