import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _previousCompanyName = 'com.localtools';
const _legacyProductName = 'JO-引号转换';
const _currentCompanyName = 'JO-Beacon';
const _appDataMigrationMarker = 'renamed_from_jo_quote_converter_v1';

/// Copies the previous Windows application data directory into the directory
/// used after the display name changed, without overwriting or deleting any
/// existing data.
Future<void> migratePreviousWindowsAppData({
  String? roamingAppDataPath,
  Future<Directory> Function()? supportDirectoryProvider,
  bool? isWindows,
}) async {
  if (!(isWindows ?? Platform.isWindows)) return;

  final supportDirectory =
      await (supportDirectoryProvider ?? getApplicationSupportDirectory)();
  final targetDirectory = Directory(supportDirectory.path);

  final roamingAppData = roamingAppDataPath ?? Platform.environment['APPDATA'];
  if (roamingAppData == null || roamingAppData.isEmpty) return;

  final legacyDirectory = Directory(
    p.join(roamingAppData, _currentCompanyName, _legacyProductName),
  );
  if (!await legacyDirectory.exists()) return;
  if (p.equals(legacyDirectory.path, targetDirectory.path)) return;

  final marker = File(p.join(targetDirectory.path, _appDataMigrationMarker));
  if (await marker.exists()) return;

  await targetDirectory.create(recursive: true);
  await _copyMissingFiles(legacyDirectory, targetDirectory);
  await marker.writeAsString('1', flush: true);
}

Future<void> _copyMissingFiles(Directory source, Directory target) async {
  await target.create(recursive: true);
  await for (final entity in source.list(followLinks: false)) {
    final targetPath = p.join(target.path, p.basename(entity.path));
    if (entity is Directory) {
      await _copyMissingFiles(entity, Directory(targetPath));
    } else if (entity is File) {
      final targetFile = File(targetPath);
      if (!await targetFile.exists()) {
        await entity.copy(targetPath);
      }
    }
  }
}

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
          _legacyProductName,
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
