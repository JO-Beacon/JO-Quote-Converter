import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';

const _previousCompanyName = 'com.localtools';
const _productName = 'JO-引号转换';

Future<void> migratePreviousWindowsPreferences({
  String? previousPreferencesPath,
}) async {
  if (!Platform.isWindows) return;
  final roamingAppData = Platform.environment['APPDATA'];
  if (previousPreferencesPath == null &&
      (roamingAppData == null || roamingAppData.isEmpty)) {
    return;
  }

  final oldFile = File(
    previousPreferencesPath ??
        p.join(
          roamingAppData!,
          _previousCompanyName,
          _productName,
          'shared_preferences.json',
        ),
  );
  if (!await oldFile.exists()) return;

  final decoded = jsonDecode(await oldFile.readAsString());
  if (decoded is! Map<String, dynamic>) return;
  final preferences = await SharedPreferences.getInstance();

  for (final item in decoded.entries) {
    final key = item.key.startsWith('flutter.')
        ? item.key.substring('flutter.'.length)
        : item.key;
    if (preferences.containsKey(key)) continue;
    await _setPreference(preferences, key, item.value);
  }
}

Future<void> _setPreference(
  SharedPreferences preferences,
  String key,
  Object? value,
) async {
  switch (value) {
    case bool value:
      await preferences.setBool(key, value);
    case int value:
      await preferences.setInt(key, value);
    case double value:
      await preferences.setDouble(key, value);
    case String value:
      await preferences.setString(key, value);
    case List<dynamic> value when value.every((item) => item is String):
      await preferences.setStringList(key, value.cast<String>());
  }
}
