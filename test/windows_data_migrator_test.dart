import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:jo_quote_converter/windows_data_migrator.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('fills missing preferences without overwriting new values', () async {
    final temporaryDirectory = await Directory.systemTemp.createTemp(
      'jo_quote_converter_preferences_migration_test_',
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
