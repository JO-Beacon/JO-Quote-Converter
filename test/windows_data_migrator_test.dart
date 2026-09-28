import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:jo_symbol_converter/windows_data_migrator.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test(
    'copies legacy renamed app data without overwriting current data',
    () async {
      final root = await Directory.systemTemp.createTemp(
        'jo_symbol_converter_app_data_migration_test_',
      );
      addTearDown(() => root.delete(recursive: true));
      final legacy = Directory(
        p.join(root.path, 'roaming', 'JO-Beacon', 'JO-引号转换'),
      );
      await legacy.create(recursive: true);
      await File(
        p.join(legacy.path, 'shared_preferences.json'),
      ).writeAsString('legacy');
      final legacyBackups = Directory(p.join(legacy.path, 'backups'));
      await legacyBackups.create(recursive: true);
      await File(
        p.join(legacyBackups.path, 'before-import.joquoteconverter'),
      ).writeAsString('backup');

      final target = Directory(p.join(root.path, 'target'));
      await target.create(recursive: true);
      await File(
        p.join(target.path, 'shared_preferences.json'),
      ).writeAsString('current');

      await migratePreviousWindowsAppData(
        roamingAppDataPath: p.join(root.path, 'roaming'),
        supportDirectoryProvider: () async => target,
        isWindows: true,
      );

      expect(
        await File(
          p.join(target.path, 'shared_preferences.json'),
        ).readAsString(),
        'current',
      );
      expect(
        await File(
          p.join(target.path, 'backups', 'before-import.joquoteconverter'),
        ).readAsString(),
        'backup',
      );
    },
  );

  test('only migrates renamed app data once', () async {
    final root = await Directory.systemTemp.createTemp(
      'jo_symbol_converter_app_data_migration_once_test_',
    );
    addTearDown(() => root.delete(recursive: true));
    final legacy = Directory(
      p.join(root.path, 'roaming', 'JO-Beacon', 'JO-引号转换'),
    );
    await legacy.create(recursive: true);
    final legacyFile = File(p.join(legacy.path, 'draft.txt'));
    await legacyFile.writeAsString('first');
    final target = Directory(p.join(root.path, 'target'));

    Future<void> migrate() => migratePreviousWindowsAppData(
      roamingAppDataPath: p.join(root.path, 'roaming'),
      supportDirectoryProvider: () async => target,
      isWindows: true,
    );

    await migrate();
    await legacyFile.writeAsString('second');
    await migrate();

    expect(
      await File(p.join(target.path, 'draft.txt')).readAsString(),
      'first',
    );
  });

  test('does nothing when the legacy app data directory is missing', () async {
    final root = await Directory.systemTemp.createTemp(
      'jo_symbol_converter_app_data_missing_test_',
    );
    addTearDown(() => root.delete(recursive: true));
    final target = Directory(p.join(root.path, 'target'));

    await migratePreviousWindowsAppData(
      roamingAppDataPath: p.join(root.path, 'roaming'),
      supportDirectoryProvider: () async => target,
      isWindows: true,
    );

    expect(await target.exists(), isFalse);
  });

  test('fills missing preferences without overwriting new values', () async {
    final temporaryDirectory = await Directory.systemTemp.createTemp(
      'jo_symbol_converter_preferences_migration_test_',
    );
    addTearDown(() => temporaryDirectory.delete(recursive: true));
    final oldPreferencesPath = p.join(
      temporaryDirectory.path,
      'shared_preferences.json',
    );
    final oldFile = File(oldPreferencesPath);
    await oldFile.writeAsString(
      jsonEncode({
        'flutter.draft.input': '旧草稿原文',
        'flutter.draft.output': '旧草稿结果',
        'flutter.settings.themeMode': 'dark',
      }),
    );
    SharedPreferences.setMockInitialValues({'settings.themeMode': 'light'});

    await migratePreviousWindowsPreferences(
      previousPreferencesPath: oldPreferencesPath,
    );
    final preferences = await SharedPreferences.getInstance();

    expect(preferences.getString('draft.input'), '旧草稿原文');
    expect(preferences.getString('draft.output'), '旧草稿结果');
    expect(preferences.getString('settings.themeMode'), 'light');
  });
}
