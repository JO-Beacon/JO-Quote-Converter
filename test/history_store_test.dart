import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:jo_quote_converter/history_store.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  late Directory temporaryDirectory;
  late String databasePath;
  late String previousDatabasePath;
  late List<HistoryStore> stores;

  HistoryStore createStore() {
    final store = HistoryStore(
      databaseFactory: databaseFactoryFfi,
      databasePath: databasePath,
      previousWindowsDatabasePath: previousDatabasePath,
    );
    stores.add(store);
    return store;
  }

  setUpAll(sqfliteFfiInit);

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    temporaryDirectory = await Directory.systemTemp.createTemp(
      'jo_quote_converter_history_test_',
    );
    databasePath = p.join(temporaryDirectory.path, 'history.db');
    previousDatabasePath = p.join(
      temporaryDirectory.path,
      'previous_history.db',
    );
    stores = [];
  });

  tearDown(() async {
    for (final store in stores.reversed) {
      try {
        await store.close();
      } catch (_) {
        // Multiple stores can share sqflite's single database connection.
      }
    }
    await databaseFactoryFfi.deleteDatabase(databasePath);
    await databaseFactoryFfi.deleteDatabase(previousDatabasePath);
    if (await temporaryDirectory.exists()) {
      await temporaryDirectory.delete(recursive: true);
    }
  });

  test('persists complete entries in newest-first order', () async {
    final store = createStore();
    final older = ConversionHistoryEntry(
      input: 'older input',
      output: 'older output',
      createdAt: DateTime(2026, 8, 12, 10),
    );
    final newer = ConversionHistoryEntry(
      input: 'newer input',
      output: 'newer output',
      createdAt: DateTime(2026, 8, 12, 11),
    );

    await store.add(older);
    await store.add(newer);
    await store.close();
    final restored = await createStore().load();

    expect(restored, hasLength(2));
    expect(restored[0].input, newer.input);
    expect(restored[0].output, newer.output);
    expect(restored[0].createdAt, newer.createdAt);
    expect(restored[1].input, older.input);
  });

  test('deletes only the selected entry', () async {
    final store = createStore();
    final first = ConversionHistoryEntry(
      input: '相同原文',
      output: '相同结果',
      createdAt: DateTime(2026, 8, 12, 10),
    );
    final second = ConversionHistoryEntry(
      input: '相同原文',
      output: '相同结果',
      createdAt: DateTime(2026, 8, 12, 11),
    );
    await store.add(first);
    await store.add(second);

    final beforeDelete = await store.load();
    await store.delete(beforeDelete.first);
    await store.close();
    final restored = await createStore().load();

    expect(restored, hasLength(1));
    expect(restored.single.createdAt, first.createdAt);
  });

  test('merges a previous Windows database only once', () async {
    final previousStore = HistoryStore(
      databaseFactory: databaseFactoryFfi,
      databasePath: previousDatabasePath,
      previousWindowsDatabasePath: p.join(
        temporaryDirectory.path,
        'no_previous_database.db',
      ),
    );
    stores.add(previousStore);
    final oldEntry = ConversionHistoryEntry(
      input: '旧目录原文',
      output: '旧目录结果',
      createdAt: DateTime(2026, 8, 12, 9),
    );
    await previousStore.add(oldEntry);
    await previousStore.close();

    final store = createStore();
    final firstLoad = await store.load();
    expect(firstLoad, hasLength(1));
    expect(firstLoad.single.input, '旧目录原文');

    await store.close();
    final secondLoad = await createStore().load();
    expect(secondLoad, hasLength(1));
  });

  test('migrates valid legacy entries once and skips damaged data', () async {
    final migratedAt = DateTime(2026, 8, 12, 12);
    SharedPreferences.setMockInitialValues({
      'history.entries': [
        'not json',
        jsonEncode({
          'input': '旧原文',
          'output': '旧结果',
          'createdAt': migratedAt.millisecondsSinceEpoch,
        }),
      ],
    });

    final store = createStore();
    final migrated = await store.load();
    expect(migrated, hasLength(1));
    expect(migrated.single.input, '旧原文');
    expect(migrated.single.output, '旧结果');
    expect(migrated.single.createdAt, migratedAt);

    final preferences = await SharedPreferences.getInstance();
    expect(preferences.containsKey('history.entries'), isFalse);

    await store.close();
    await preferences.setStringList('history.entries', [
      jsonEncode({
        'input': '不应再次迁移',
        'output': '不应再次迁移',
        'createdAt': migratedAt.millisecondsSinceEpoch,
      }),
    ]);
    final reopened = await createStore().load();
    expect(reopened, hasLength(1));
    expect(reopened.single.input, '旧原文');
  });
}
