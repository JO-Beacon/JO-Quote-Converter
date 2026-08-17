import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

class AppLocalizations {
  AppLocalizations(this.locale, this._values);

  final Locale locale;
  final Map<String, String> _values;

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates = [
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    delegate,
  ];
  static const List<Locale> supportedLocales = [Locale('zh'), Locale('en')];

  static AppLocalizations of(BuildContext context) =>
      Localizations.of<AppLocalizations>(context, AppLocalizations)!;

  @override
  dynamic noSuchMethod(Invocation invocation) {
    final key = _symbolName(invocation.memberName);
    final value = _values[key];
    if (value == null) return super.noSuchMethod(invocation);

    if (invocation.isMethod) {
      final placeholders = _placeholderOrder[key] ?? const <String>[];
      var result = value.toString();
      final arguments = invocation.positionalArguments;
      for (var index = 0; index < placeholders.length; index++) {
        result = result.replaceAll(
          '{${placeholders[index]}}',
          '${arguments[index]}',
        );
      }
      return result;
    }

    return value;
  }

  static String _symbolName(Symbol symbol) {
    final raw = symbol.toString();
    return raw.substring(8, raw.length - 2);
  }

  static const Map<String, String> _zh = _zhMessages;
  static const Map<String, String> _en = _enMessages;

  static const Map<String, List<String>> _placeholderOrder = {
    'historyClearContent': ['count'],
    'historyCount': ['count'],
    'historySearchCount': ['matched', 'total'],
    'historyStorageUsage': ['size'],
    'characterCount': ['count'],
    'paletteName': ['color'],
    'settingsAppearanceSubtitle': ['theme', 'palette'],
    'restoreAutomaticBackupContent': [
      'backupTime',
      'appVersion',
      'historyCount',
    ],
    'clearAutomaticBackupsContent': ['count'],
    'automaticBackupSummary': ['appVersion', 'historyCount', 'size'],
    'exportedAtLabel': ['time'],
    'sourceVersionLabel': ['version'],
    'historyCountLabel': ['count'],
    'latestVersion': ['version', 'name'],
    'currentVersionUpToDate': ['version'],
    'aboutSubtitle': ['version'],
    'copyTitle': ['title'],
  };
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) => AppLocalizations.supportedLocales.any(
    (supported) => supported.languageCode == locale.languageCode,
  );

  @override
  Future<AppLocalizations> load(Locale locale) async {
    return AppLocalizations(
      locale,
      locale.languageCode == 'en' ? AppLocalizations._en : AppLocalizations._zh,
    );
  }

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

const Map<String, String> _zhMessages = {
  'appTitle': 'JO-引号转换',
  'appName': 'JO-引号转换',
  'history': '历史记录',
  'settings': '设置',
  'source': '原文',
  'sourceHint': '在此输入或粘贴文本',
  'result': '转换结果',
  'resultHint': '转换结果将在此显示',
  'clear': '清空',
  'convert': '转换',
  'copy': '复制',
  'copyTitle': '复制{title}',
  'cancel': '取消',
  'delete': '删除',
  'restore': '恢复',
  'import': '导入',
  'export': '导出',
  'close': '关闭',
  'retry': '重试',
  'openReleasePage': '打开发布页',
  'resultCopied': '结果已复制',
  'historySaveFailed': '历史记录保存失败，本次记录尚未写入磁盘',
  'confirmClearTitle': '确认清空？',
  'confirmClearContent': '原文和转换结果都会被清空。',
  'confirmRestoreTitle': '恢复历史记录？',
  'confirmRestoreContent': '当前工作区内容将被覆盖。',
  'restoreSuccess': '已恢复到工作区',
  'historyDeleteTitle': '删除这条历史记录？',
  'historyDeleteContent': '删除后无法恢复。',
  'historyDeleted': '历史记录已删除',
  'historyDeleteFailed': '历史记录删除失败',
  'historyClearTitle': '清空全部历史记录？',
  'historyClearContent': '将永久删除全部 {count} 条历史记录，此操作无法撤销。',
  'clearAll': '全部清空',
  'historyCleared': '历史记录已全部清空',
  'historyClearFailed': '历史记录清空失败',
  'historySearchHint': '搜索原文或转换结果',
  'clearSearch': '清除搜索',
  'historyCount': '{count} 条记录',
  'historySearchCount': '{matched} 条结果，共 {total} 条记录',
  'historyStorageUsage': '占用 {size}',
  'historyLoadFailedRestart': '历史记录读取失败，请重新启动应用后重试。',
  'historyPartiallySaved': '部分历史记录尚未写入磁盘。',
  'noHistory': '暂无历史记录',
  'noMatchingHistory': '没有匹配的历史记录',
  'viewDetails': '查看详情',
  'historyDetailTitle': '历史记录详情',
  'historyDetailSourceCopied': '原文已复制',
  'historyDetailResultCopied': '转换结果已复制',
  'emptyText': '（空文本）',
  'characterCount': '{count} 字符',
  'languageTitle': '语言',
  'languageSimplifiedChinese': '简体中文',
  'languageEnglish': 'English',
  'appearanceTitle': '外观',
  'appearanceModeSectionTitle': '模式',
  'appearancePaletteSectionTitle': '配色',
  'themeSystem': '跟随系统',
  'themeLight': '浅色',
  'themeDark': '深色',
  'paletteRed': '红',
  'paletteYellow': '黄',
  'paletteGreen': '绿',
  'paletteBlue': '蓝',
  'palettePurple': '紫',
  'paletteGray': '灰',
  'paletteName': '{color}色配色',
  'settingsAppearanceSubtitle': '{theme} · {palette}色',
  'behaviorTitle': '行为',
  'behaviorSubtitle': '转换规则与 Markdown 代码排除',
  'excludeMarkdownCodeTitle': '排除 Markdown 代码',
  'excludeMarkdownCodeSubtitle': '保留围栏代码块和行内代码中的原始引号',
  'useHeuristicsTitle': '启发式判断',
  'useHeuristicsSubtitle': '尽量保留缩写、所有格、单位和年代中的撇号',
  'shortcutsTitle': '快捷键',
  'shortcutsSubtitleEnabled': '已启用',
  'shortcutsSubtitleDisabled': '已关闭',
  'enableKeyboardShortcutsTitle': '启用键盘快捷键',
  'enableKeyboardShortcutsSubtitle': '关闭后，所有键盘快捷键将停止响应',
  'shortcutConvertTitle': '转换',
  'dataArchiveTitle': '数据与存档',
  'dataArchiveSubtitle': '导出、导入与自动回退备份',
  'exportArchiveTitle': '导出存档',
  'exportArchiveSubtitle': '保存工作区、设置和全部历史记录',
  'importArchiveTitle': '导入存档',
  'importArchiveSubtitle': '校验后选择完全覆盖或智能合并',
  'automaticBackupsTitle': '自动备份',
  'automaticBackupsSubtitle': '查看、恢复或清理导入前备份',
  'archiveNotesSectionTitle': '存档说明',
  'archiveNotes':
      '存档使用 .joquoteconverter 后缀并采用 ZIP Deflate 压缩。存档包含原文、转换结果、设置和历史记录，不加密，请妥善保管。确认导入后，应用会先在本机自动保存一份导入前备份。',
  'automaticBackupsLoadFailed': '自动备份读取失败',
  'restoreAutomaticBackupTitle': '恢复此自动备份？',
  'restoreAutomaticBackupContent':
      '将覆盖当前工作区、设置和全部历史记录。\n\n备份时间：{backupTime}\n来源版本：{appVersion}\n历史记录：{historyCount} 条\n\n恢复前会再次备份当前数据。',
  'deleteAutomaticBackupTitle': '删除此自动备份？',
  'deleteAutomaticBackupContent': '删除后无法恢复。',
  'automaticBackupDeleted': '自动备份已删除',
  'automaticBackupDeleteFailed': '自动备份删除失败',
  'clearAutomaticBackupsTitle': '清空全部自动备份？',
  'clearAutomaticBackupsContent': '将永久删除全部 {count} 个自动备份，此操作无法撤销。',
  'automaticBackupsCleared': '自动备份已全部清空',
  'automaticBackupsClearFailed': '自动备份清空失败',
  'noAutomaticBackups': '暂无自动备份',
  'corruptedAutomaticBackup': '损坏的自动备份',
  'automaticBackupSummary': '版本 {appVersion} · {historyCount} 条历史 · {size}',
  'importArchiveTitleDialog': '导入此存档？',
  'exportedAtLabel': '导出时间：{time}',
  'sourceVersionLabel': '来源版本：{version}',
  'historyCountLabel': '历史记录：{count} 条',
  'importModeLabel': '导入模式',
  'smartMergeLabel': '智能合并',
  'overwriteLabel': '完全覆盖',
  'smartMergeDescription': '保留当前设置；工作区为空时恢复存档工作区；历史记录去重合并。',
  'overwriteDescription': '当前工作区、行为与外观设置、快捷键和历史记录都将替换为存档内容。',
  'automaticBackupBeforeImport': '导入前会自动创建当前数据备份。',
  'archiveReadFailed': '存档读取失败',
  'archiveExportSuccess': '存档导出成功',
  'archiveExportFailed': '存档导出失败',
  'archiveImportSuccess': '存档导入成功',
  'archiveImportFailedRolledBack': '存档导入失败，已恢复导入前的数据',
  'automaticBackupRestored': '自动备份已恢复',
  'aboutTitle': '关于',
  'aboutSubtitle': 'JO-引号转换 {version}',
  'versionTitle': '版本',
  'checkForUpdatesTitle': '检查更新',
  'checkingForUpdates': '正在检查 GitHub 最新版本',
  'checkGitHubReleases': '检查 GitHub Releases',
  'authorTitle': '作者',
  'projectLicenseTitle': '项目许可证',
  'sourceHanSansLicenseTitle': '思源黑体许可证',
  'openSourceLicensesTitle': '第三方开源许可证',
  'openSourceLicensesSubtitle': 'Flutter 及第三方依赖',
  'updateAvailable': '发现新版本',
  'upToDate': '已是最新版本',
  'latestVersion': '最新版本：{version}\n{name}',
  'currentVersionUpToDate': '当前版本 {version} 已是 GitHub 上的最新版本。',
  'checkForUpdatesFailed': '检查更新失败，请稍后重试',
  'unableToOpenLink': '无法打开链接',
};

const Map<String, String> _enMessages = {
  'appTitle': 'JO Quote Converter',
  'appName': 'JO Quote Converter',
  'history': 'History',
  'settings': 'Settings',
  'source': 'Source',
  'sourceHint': 'Enter or paste text here',
  'result': 'Result',
  'resultHint': 'Converted text will appear here',
  'clear': 'Clear',
  'convert': 'Convert',
  'copy': 'Copy',
  'copyTitle': 'Copy {title}',
  'cancel': 'Cancel',
  'delete': 'Delete',
  'restore': 'Restore',
  'import': 'Import',
  'export': 'Export',
  'close': 'Close',
  'retry': 'Retry',
  'openReleasePage': 'Open release page',
  'resultCopied': 'Result copied',
  'historySaveFailed':
      'Failed to save history; this entry has not been written to disk.',
  'confirmClearTitle': 'Clear workspace?',
  'confirmClearContent': 'Both the source and converted text will be cleared.',
  'confirmRestoreTitle': 'Restore history entry?',
  'confirmRestoreContent': 'The current workspace will be overwritten.',
  'restoreSuccess': 'Restored to workspace',
  'historyDeleteTitle': 'Delete this history entry?',
  'historyDeleteContent': 'This action cannot be undone.',
  'historyDeleted': 'History entry deleted',
  'historyDeleteFailed': 'Failed to delete history entry',
  'historyClearTitle': 'Clear all history?',
  'historyClearContent':
      'This will permanently delete all {count} history entries and cannot be undone.',
  'clearAll': 'Clear all',
  'historyCleared': 'All history cleared',
  'historyClearFailed': 'Failed to clear history',
  'historySearchHint': 'Search source or converted text',
  'clearSearch': 'Clear search',
  'historyCount': '{count} entries',
  'historySearchCount': '{matched} matches out of {total} entries',
  'historyStorageUsage': 'Uses {size}',
  'historyLoadFailedRestart':
      'Failed to load history. Restart the app and try again.',
  'historyPartiallySaved':
      'Some history entries have not been written to disk.',
  'noHistory': 'No history yet',
  'noMatchingHistory': 'No matching history entries',
  'viewDetails': 'View details',
  'historyDetailTitle': 'History details',
  'historyDetailSourceCopied': 'Source copied',
  'historyDetailResultCopied': 'Result copied',
  'emptyText': '(Empty)',
  'characterCount': '{count} characters',
  'languageTitle': 'Language',
  'languageSimplifiedChinese': '简体中文',
  'languageEnglish': 'English',
  'appearanceTitle': 'Appearance',
  'appearanceModeSectionTitle': 'Mode',
  'appearancePaletteSectionTitle': 'Palette',
  'themeSystem': 'System',
  'themeLight': 'Light',
  'themeDark': 'Dark',
  'paletteRed': 'Red',
  'paletteYellow': 'Yellow',
  'paletteGreen': 'Green',
  'paletteBlue': 'Blue',
  'palettePurple': 'Purple',
  'paletteGray': 'Gray',
  'paletteName': '{color} theme',
  'settingsAppearanceSubtitle': '{theme} · {palette}',
  'behaviorTitle': 'Behavior',
  'behaviorSubtitle': 'Conversion rules and Markdown code exclusions',
  'excludeMarkdownCodeTitle': 'Exclude Markdown code',
  'excludeMarkdownCodeSubtitle':
      'Keep original quotes in fenced code blocks and inline code',
  'useHeuristicsTitle': 'Heuristics',
  'useHeuristicsSubtitle':
      'Preserve apostrophes in contractions, possessives, units, and decades when possible',
  'shortcutsTitle': 'Shortcuts',
  'shortcutsSubtitleEnabled': 'Enabled',
  'shortcutsSubtitleDisabled': 'Disabled',
  'enableKeyboardShortcutsTitle': 'Enable keyboard shortcuts',
  'enableKeyboardShortcutsSubtitle':
      'When disabled, all keyboard shortcuts stop responding',
  'shortcutConvertTitle': 'Convert',
  'dataArchiveTitle': 'Data & archive',
  'dataArchiveSubtitle': 'Export, import, and automatic rollback backups',
  'exportArchiveTitle': 'Export archive',
  'exportArchiveSubtitle': 'Save workspace, settings, and all history',
  'importArchiveTitle': 'Import archive',
  'importArchiveSubtitle': 'Validate, then choose overwrite or smart merge',
  'automaticBackupsTitle': 'Automatic backups',
  'automaticBackupsSubtitle': 'View, restore, or clean up pre-import backups',
  'archiveNotesSectionTitle': 'Archive notes',
  'archiveNotes':
      'Archives use the .joquoteconverter extension and ZIP Deflate compression. They contain the source text, converted result, settings, and history, and are not encrypted; keep them safe. Before an import completes, the app automatically saves a pre-import backup on this device.',
  'automaticBackupsLoadFailed': 'Failed to load automatic backups',
  'restoreAutomaticBackupTitle': 'Restore this automatic backup?',
  'restoreAutomaticBackupContent':
      'This will overwrite the current workspace, settings, and all history.\n\nBackup time: {backupTime}\nSource version: {appVersion}\nHistory entries: {historyCount}\n\nYour current data will be backed up again before restoring.',
  'deleteAutomaticBackupTitle': 'Delete this automatic backup?',
  'deleteAutomaticBackupContent': 'This action cannot be undone.',
  'automaticBackupDeleted': 'Automatic backup deleted',
  'automaticBackupDeleteFailed': 'Failed to delete automatic backup',
  'clearAutomaticBackupsTitle': 'Clear all automatic backups?',
  'clearAutomaticBackupsContent':
      'This will permanently delete all {count} automatic backups and cannot be undone.',
  'automaticBackupsCleared': 'All automatic backups cleared',
  'automaticBackupsClearFailed': 'Failed to clear automatic backups',
  'noAutomaticBackups': 'No automatic backups',
  'corruptedAutomaticBackup': 'Corrupted automatic backup',
  'automaticBackupSummary':
      'Version {appVersion} · {historyCount} history entries · {size}',
  'importArchiveTitleDialog': 'Import this archive?',
  'exportedAtLabel': 'Exported at: {time}',
  'sourceVersionLabel': 'Source version: {version}',
  'historyCountLabel': 'History entries: {count}',
  'importModeLabel': 'Import mode',
  'smartMergeLabel': 'Smart merge',
  'overwriteLabel': 'Overwrite',
  'smartMergeDescription':
      'Keep current settings; restore the archived workspace only when the workspace is empty; merge history without duplicates.',
  'overwriteDescription':
      'The current workspace, behavior and appearance settings, shortcuts, and history will be replaced with archive contents.',
  'automaticBackupBeforeImport':
      'A backup of your current data will be created before importing.',
  'archiveReadFailed': 'Failed to read archive',
  'archiveExportSuccess': 'Archive exported',
  'archiveExportFailed': 'Failed to export archive',
  'archiveImportSuccess': 'Archive imported',
  'archiveImportFailedRolledBack':
      'Archive import failed; pre-import data restored',
  'automaticBackupRestored': 'Automatic backup restored',
  'aboutTitle': 'About',
  'aboutSubtitle': 'JO Quote Converter {version}',
  'versionTitle': 'Version',
  'checkForUpdatesTitle': 'Check for updates',
  'checkingForUpdates': 'Checking GitHub for the latest version',
  'checkGitHubReleases': 'Check GitHub Releases',
  'authorTitle': 'Author',
  'projectLicenseTitle': 'Project license',
  'sourceHanSansLicenseTitle': 'Source Han Sans license',
  'openSourceLicensesTitle': 'Open-source licenses',
  'openSourceLicensesSubtitle': 'Flutter and third-party dependencies',
  'updateAvailable': 'Update available',
  'upToDate': 'Up to date',
  'latestVersion': 'Latest version: {version}\n{name}',
  'currentVersionUpToDate': 'Version {version} is the latest GitHub release.',
  'checkForUpdatesFailed':
      'Failed to check for updates. Please try again later.',
  'unableToOpenLink': 'Unable to open link',
};
