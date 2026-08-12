import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart' as sqflite;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class ConversionHistoryEntry {
  const ConversionHistoryEntry({
    this.id,
    required this.input,
    required this.output,
    required this.createdAt,
  });

  final int? id;
  final String input;
  final String output;
  final DateTime createdAt;

  factory ConversionHistoryEntry.fromLegacyJson(Map<String, Object?> json) {
    final input = json['input'];
    final output = json['output'];
    final createdAt = json['createdAt'];
    if (input is! String || output is! String || createdAt is! int) {
      throw const FormatException('Invalid conversion history entry.');
    }
    return ConversionHistoryEntry(
      input: input,
      output: output,
      createdAt: DateTime.fromMillisecondsSinceEpoch(createdAt),
    );
  }
}

class HistoryStore {
  HistoryStore({
    DatabaseFactory? databaseFactory,
    this.databasePath,
    this.previousWindowsDatabasePath,
  }) : _databaseFactory = databaseFactory ?? _defaultDatabaseFactory(),
       _preferences = SharedPreferences.getInstance();

  static const _databaseFileName = 'conversion_history.db';
  static const _historyTable = 'conversion_history';
  static const _metadataTable = 'history_metadata';
  static const _legacyHistoryKey = 'history.entries';
  static const _legacyMigrationKey = 'legacy_shared_preferences_migrated';
  static const _previousWindowsMigrationKey =
      'previous_windows_app_data_migrated_v1';

  final DatabaseFactory _databaseFactory;
  final String? databasePath;
  final String? previousWindowsDatabasePath;
  final Future<SharedPreferences> _preferences;
  Future<Database>? _database;

  static DatabaseFactory _defaultDatabaseFactory() {
    if (Platform.isWindows) {
      sqfliteFfiInit();
      return databaseFactoryFfi;
    }
    return sqflite.databaseFactory;
  }

  Future<List<ConversionHistoryEntry>> load() async {
    final database = await _getDatabase();
    final rows = await database.query(
      _historyTable,
      columns: const ['id', 'input', 'output', 'created_at'],
      orderBy: 'created_at DESC, id DESC',
    );
    return rows
        .map(
          (row) => ConversionHistoryEntry(
            id: row['id'] as int,
            input: row['input'] as String,
            output: row['output'] as String,
            createdAt: DateTime.fromMillisecondsSinceEpoch(
              row['created_at'] as int,
            ),
          ),
        )
        .toList(growable: false);
  }

  Future<void> add(ConversionHistoryEntry entry) async {
    final database = await _getDatabase();
    await database.insert(_historyTable, {
      'input': entry.input,
      'output': entry.output,
      'created_at': entry.createdAt.millisecondsSinceEpoch,
    });
  }

  Future<void> delete(ConversionHistoryEntry entry) async {
    final id = entry.id;
    if (id == null) {
      throw StateError('Cannot delete a history entry without an id.');
    }
    final database = await _getDatabase();
    final deleted = await database.delete(
      _historyTable,
      where: 'id = ?',
      whereArgs: [id],
    );
    if (deleted != 1) {
      throw StateError('History entry no longer exists.');
    }
  }

  Future<void> clear() async {
    final database = await _getDatabase();
    await database.delete(_historyTable);
  }

  Future<int> merge(List<ConversionHistoryEntry> entries) async {
    final database = await _getDatabase();
    return database.transaction<int>((transaction) async {
      final rows = await transaction.query(
        _historyTable,
        columns: const ['input', 'output', 'created_at'],
      );
      final existing = rows
          .map(
            (row) => (
              row['input'] as String,
              row['output'] as String,
              row['created_at'] as int,
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
        await transaction.insert(_historyTable, {
          'input': entry.input,
          'output': entry.output,
          'created_at': entry.createdAt.millisecondsSinceEpoch,
        });
        inserted++;
      }
      return inserted;
    });
  }

  Future<void> replaceAll(List<ConversionHistoryEntry> entries) async {
    final database = await _getDatabase();
    await database.transaction((transaction) async {
      await transaction.delete(_historyTable);
      for (final entry in entries) {
        await transaction.insert(_historyTable, {
          'input': entry.input,
          'output': entry.output,
          'created_at': entry.createdAt.millisecondsSinceEpoch,
        });
      }
    });
  }

  Future<int> storageSizeBytes() async {
    final database = await _getDatabase();
    final databases = await database.rawQuery('PRAGMA database_list');
    final databasePath = databases
        .map((row) => row['file'])
        .whereType<String>()
        .firstWhere((path) => path.isNotEmpty, orElse: () => '');
    if (databasePath.isEmpty) return 0;

    var total = 0;
    for (final suffix in const ['', '-wal', '-shm']) {
      final file = File('$databasePath$suffix');
      if (await file.exists()) total += await file.length();
    }
    return total;
  }

  Future<void> close() async {
    final database = await _database;
    _database = null;
    await database?.close();
  }

  Future<Database> _getDatabase() => _database ??= _openDatabase();

  Future<Database> _openDatabase() async {
    final path = await _resolveDatabasePath();
    final database = await _databaseFactory.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: 1,
        onCreate: (database, version) async {
          await database.execute('''
            CREATE TABLE $_historyTable (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              input TEXT NOT NULL,
              output TEXT NOT NULL,
              created_at INTEGER NOT NULL
            )
          ''');
          await database.execute('''
            CREATE TABLE $_metadataTable (
              key TEXT PRIMARY KEY,
              value TEXT NOT NULL
            )
          ''');
        },
      ),
    );
    await _migrateLegacyHistory(database);
    await _migratePreviousWindowsHistory(database, path);
    return database;
  }

  Future<String> _resolveDatabasePath() async {
    if (databasePath != null) return databasePath!;
    if (!Platform.isWindows) {
      return p.join(
        await _databaseFactory.getDatabasesPath(),
        _databaseFileName,
      );
    }

    final supportDirectory = await getApplicationSupportDirectory();
    final targetPath = p.join(supportDirectory.path, _databaseFileName);

    // Early debug builds used sqflite_common_ffi's working-directory path.
    // Preserve any history written there when moving to the stable app path.
    final oldPath = p.join(
      await databaseFactoryFfi.getDatabasesPath(),
      _databaseFileName,
    );
    final targetFile = File(targetPath);
    final oldFile = File(oldPath);
    if (!await targetFile.exists() && await oldFile.exists()) {
      await targetFile.parent.create(recursive: true);
      await oldFile.copy(targetPath);
    }
    return targetPath;
  }

  Future<void> _migrateLegacyHistory(Database database) async {
    SharedPreferences preferences;
    try {
      preferences = await _preferences;
    } catch (_) {
      return;
    }

    final legacyEntries = preferences.getStringList(_legacyHistoryKey);
    final migrated = await database.transaction<bool>((transaction) async {
      final marker = await transaction.query(
        _metadataTable,
        columns: const ['value'],
        where: 'key = ?',
        whereArgs: const [_legacyMigrationKey],
        limit: 1,
      );
      if (marker.isNotEmpty) return false;

      for (final encoded in legacyEntries ?? const <String>[]) {
        try {
          final decoded = jsonDecode(encoded);
          if (decoded is! Map<String, dynamic>) continue;
          final entry = ConversionHistoryEntry.fromLegacyJson(decoded);
          await transaction.insert(_historyTable, {
            'input': entry.input,
            'output': entry.output,
            'created_at': entry.createdAt.millisecondsSinceEpoch,
          });
        } catch (_) {
          // A damaged old entry should not prevent the remaining migration.
        }
      }
      await transaction.insert(_metadataTable, {
        'key': _legacyMigrationKey,
        'value': '1',
      });
      return true;
    });

    if (migrated && legacyEntries != null) {
      await preferences.remove(_legacyHistoryKey);
    }
  }

  Future<void> _migratePreviousWindowsHistory(
    Database database,
    String currentPath,
  ) async {
    final oldPath = previousWindowsDatabasePath ?? _previousWindowsHistoryPath;
    if (oldPath == null || p.equals(oldPath, currentPath)) return;

    final marker = await database.query(
      _metadataTable,
      columns: const ['value'],
      where: 'key = ?',
      whereArgs: const [_previousWindowsMigrationKey],
      limit: 1,
    );
    if (marker.isNotEmpty) return;

    List<Map<String, Object?>> oldRows = const [];
    if (await File(oldPath).exists()) {
      Database? oldDatabase;
      try {
        oldDatabase = await databaseFactoryFfi.openDatabase(
          oldPath,
          options: OpenDatabaseOptions(readOnly: true, singleInstance: false),
        );
        oldRows = await oldDatabase.query(
          _historyTable,
          columns: const ['input', 'output', 'created_at'],
          orderBy: 'id ASC',
        );
      } catch (_) {
        return;
      } finally {
        await oldDatabase?.close();
      }
    }

    await database.transaction((transaction) async {
      final existingRows = await transaction.query(
        _historyTable,
        columns: const ['input', 'output', 'created_at'],
      );
      final existingEntries = existingRows
          .map(
            (row) => (
              row['input'] as String,
              row['output'] as String,
              row['created_at'] as int,
            ),
          )
          .toSet();
      for (final row in oldRows) {
        final identity = (
          row['input'] as String,
          row['output'] as String,
          row['created_at'] as int,
        );
        if (!existingEntries.add(identity)) continue;
        await transaction.insert(_historyTable, row);
      }
      await transaction.insert(_metadataTable, {
        'key': _previousWindowsMigrationKey,
        'value': '1',
      });
    });
  }

  String? get _previousWindowsHistoryPath {
    if (!Platform.isWindows) return null;
    final roamingAppData = Platform.environment['APPDATA'];
    if (roamingAppData == null || roamingAppData.isEmpty) return null;
    return p.join(
      roamingAppData,
      'com.localtools',
      'JO-引号转换',
      _databaseFileName,
    );
  }
}
