import 'dart:io';
import 'dart:convert';

import 'package:archive/archive.dart';
import 'package:crypto/crypto.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jo_quote_converter/archive_service.dart';
import 'package:jo_quote_converter/draft_store.dart';
import 'package:jo_quote_converter/history_store.dart';

void main() {
  late Directory temporaryDirectory;
  late ArchiveService service;

  setUp(() async {
    temporaryDirectory = await Directory.systemTemp.createTemp(
      'jo_quote_converter_archive_test_',
    );
    service = ArchiveService(
      supportDirectoryProvider: () async => temporaryDirectory,
    );
  });

  tearDown(() async {
    if (await temporaryDirectory.exists()) {
      await temporaryDirectory.delete(recursive: true);
    }
  });

  test('round-trips the complete snapshot in a compressed archive', () {
    final snapshot = _snapshot();
    final bytes = service.encode(
      snapshot: snapshot,
      appVersion: '0.0.2+2',
      exportedAt: DateTime.utc(2026, 8, 12, 12, 30),
    );

    final zip = ZipDecoder().decodeBytes(bytes);
    expect(
      zip.files.where((file) => file.isFile).map((file) => file.name).toSet(),
      {'manifest.json', 'workspace.json', 'history.jsonl', 'checksums.json'},
    );
    expect(
      zip.files.where((file) => file.isFile).map((file) => file.compression),
      everyElement(CompressionType.deflate),
    );
    final decoded = service.decode(bytes);

    expect(decoded.appVersion, '0.0.2+2');
    expect(decoded.exportedAt, DateTime.utc(2026, 8, 12, 12, 30).toLocal());
    expect(decoded.snapshot.draft.input, 'archive input');
    expect(decoded.snapshot.draft.output, 'archive output');
    expect(decoded.snapshot.draft.excludeMarkdownCode, isFalse);
    expect(decoded.snapshot.draft.useHeuristics, isFalse);
    expect(decoded.snapshot.themeMode, 'dark');
    expect(decoded.snapshot.palette, 'purple');
    expect(decoded.snapshot.keyboardShortcutsEnabled, isFalse);
    expect(decoded.snapshot.history, hasLength(2));
    expect(decoded.snapshot.history.first.input, 'new history');
  });

  test('rejects archive content that does not match its checksum', () {
    final bytes = service.encode(snapshot: _snapshot(), appVersion: '0.0.2+2');
    final decodedZip = ZipDecoder().decodeBytes(bytes);
    final tamperedZip = Archive();
    for (final file in decodedZip.files.where((file) => file.isFile)) {
      final content = file.name == 'workspace.json'
          ? '{"input":"tampered"}'.codeUnits
          : file.readBytes()!;
      tamperedZip.add(ArchiveFile.bytes(file.name, content));
    }
    final tamperedBytes = ZipEncoder().encodeBytes(tamperedZip);

    expect(
      () => service.decode(tamperedBytes),
      throwsA(
        isA<ArchiveFormatException>().having(
          (error) => error.message,
          'message',
          contains('workspace.json 校验失败'),
        ),
      ),
    );
  });

  test('rejects an unsupported format version', () {
    final original = ZipDecoder().decodeBytes(
      service.encode(snapshot: _snapshot(), appVersion: '0.0.2+2'),
    );
    final files = {
      for (final file in original.files.where((file) => file.isFile))
        file.name: file.readBytes()!,
    };
    final manifest =
        jsonDecode(utf8.decode(files['manifest.json']!))
            as Map<String, dynamic>;
    manifest['formatVersion'] = 999;
    files['manifest.json'] = utf8.encode(jsonEncode(manifest));
    final checksums =
        jsonDecode(utf8.decode(files['checksums.json']!))
            as Map<String, dynamic>;
    final checksumFiles = checksums['files'] as Map<String, dynamic>;
    checksumFiles['manifest.json'] = sha256
        .convert(files['manifest.json']!)
        .toString();
    files['checksums.json'] = utf8.encode(jsonEncode(checksums));
    final archive = Archive();
    for (final entry in files.entries) {
      archive.add(ArchiveFile.bytes(entry.key, entry.value));
    }

    expect(
      () => service.decode(ZipEncoder().encodeBytes(archive)),
      throwsA(
        isA<ArchiveFormatException>().having(
          (error) => error.message,
          'message',
          '不支持此存档版本。',
        ),
      ),
    );
  });

  test(
    'imports valid Android content when the plugin cache name has no extension',
    () async {
      final archiveFile = File(
        '${temporaryDirectory.path}${Platform.pathSeparator}'
        'file-selector-cache-42',
      );
      await archiveFile.writeAsBytes(
        service.encode(snapshot: _snapshot(), appVersion: '0.0.2+2'),
      );
      List<XTypeGroup>? receivedGroups;
      final androidService = ArchiveService(
        supportDirectoryProvider: () async => temporaryDirectory,
        isAndroid: true,
        filePicker: (groups) async {
          receivedGroups = groups;
          return XFile(archiveFile.path);
        },
      );

      final document = await androidService.pickAndDecode();

      expect(receivedGroups, hasLength(1));
      expect(receivedGroups!.single.allowsAny, isTrue);
      expect(document?.snapshot.history, hasLength(2));
    },
  );

  test('keeps the archive file filter outside Android', () async {
    List<XTypeGroup>? receivedGroups;
    final desktopService = ArchiveService(
      supportDirectoryProvider: () async => temporaryDirectory,
      isAndroid: false,
      filePicker: (groups) async {
        receivedGroups = groups;
        return null;
      },
    );

    expect(await desktopService.pickAndDecode(), isNull);
    expect(receivedGroups, hasLength(1));
    expect(receivedGroups!.single.allowsAny, isFalse);
    expect(receivedGroups!.single.extensions, [archiveExtension]);
    expect(receivedGroups!.single.mimeTypes, [archiveMimeType]);
  });

  test('rejects a selected file with the wrong extension', () async {
    final wrongFile = File(
      '${temporaryDirectory.path}${Platform.pathSeparator}not-an-archive.zip',
    );
    await wrongFile.writeAsBytes(
      service.encode(snapshot: _snapshot(), appVersion: '0.0.2+2'),
    );
    final desktopService = ArchiveService(
      supportDirectoryProvider: () async => temporaryDirectory,
      isAndroid: false,
      filePicker: (_) async => XFile(wrongFile.path),
    );

    expect(
      desktopService.pickAndDecode,
      throwsA(
        isA<ArchiveFormatException>().having(
          (error) => error.message,
          'message',
          '请选择 .joquoteconverter 存档文件。',
        ),
      ),
    );
  });

  test('decodes a Windows-associated archive file path', () async {
    final archiveFile = File(
      '${temporaryDirectory.path}${Platform.pathSeparator}'
      'associated.$archiveExtension',
    );
    await archiveFile.writeAsBytes(
      service.encode(snapshot: _snapshot(), appVersion: '0.0.3+3'),
    );

    final document = await service.decodeFilePath(archiveFile.path);

    expect(document.appVersion, '0.0.3+3');
    expect(document.snapshot.history, hasLength(2));
  });

  test(
    'rejects a Windows-associated file path with a wrong extension',
    () async {
      final archiveFile = File(
        '${temporaryDirectory.path}${Platform.pathSeparator}not-an-archive.zip',
      );
      await archiveFile.writeAsBytes(
        service.encode(snapshot: _snapshot(), appVersion: '0.0.3+3'),
      );

      expect(
        () => service.decodeFilePath(archiveFile.path),
        throwsA(
          isA<ArchiveFormatException>().having(
            (error) => error.message,
            'message',
            '请选择 .joquoteconverter 存档文件。',
          ),
        ),
      );
    },
  );

  test('rejects invalid Android archive content after selection', () async {
    final invalidFile = File(
      '${temporaryDirectory.path}${Platform.pathSeparator}android-cache-file',
    );
    await invalidFile.writeAsString('not an archive');
    final androidService = ArchiveService(
      supportDirectoryProvider: () async => temporaryDirectory,
      isAndroid: true,
      filePicker: (_) async => XFile(invalidFile.path),
    );

    expect(
      androidService.pickAndDecode,
      throwsA(isA<ArchiveFormatException>()),
    );
  });

  test('exports Android archives through the system document saver', () async {
    String? savedName;
    List<int>? savedBytes;
    final androidService = ArchiveService(
      supportDirectoryProvider: () async => temporaryDirectory,
      isAndroid: true,
      androidArchiveSaver: (name, bytes) async {
        savedName = name;
        savedBytes = bytes;
        return 'content://documents/exported-archive';
      },
    );

    final exported = await androidService.exportWithPicker(
      snapshot: _snapshot(),
      appVersion: '0.0.2+2',
      now: DateTime(2026, 8, 13, 14, 30),
    );

    expect(exported, isTrue);
    expect(savedName, 'JO-引号转换-20260813-143000-000.joquoteconverter');
    expect(androidService.decode(savedBytes!).snapshot.history, hasLength(2));
  });

  test('treats cancelling the Android document saver as no export', () async {
    final androidService = ArchiveService(
      supportDirectoryProvider: () async => temporaryDirectory,
      isAndroid: true,
      androidArchiveSaver: (_, _) async => null,
    );

    expect(
      await androidService.exportWithPicker(
        snapshot: _snapshot(),
        appVersion: '0.0.2+2',
      ),
      isFalse,
    );
  });

  test(
    'writes an automatic backup into the private backup directory',
    () async {
      final path = await service.createAutomaticBackup(
        snapshot: _snapshot(),
        appVersion: '0.0.2+2',
        now: DateTime(2026, 8, 12, 13, 45, 20),
      );
      final file = File(path);

      expect(await file.exists(), isTrue);
      expect(
        file.path,
        contains('${Platform.pathSeparator}backups${Platform.pathSeparator}'),
      );
      expect(file.path, endsWith('.joquoteconverter'));
      expect(
        service.decode(await file.readAsBytes()).snapshot.history,
        hasLength(2),
      );
    },
  );

  test('lists valid and damaged automatic backups newest first', () async {
    final validBackupPath = await service.createAutomaticBackup(
      snapshot: _snapshot(),
      appVersion: '0.0.2+2',
      now: DateTime(2026, 8, 13, 10),
    );
    await File(validBackupPath).setLastModified(DateTime(2026, 8, 13, 10));
    final backupDirectory = Directory(
      '${temporaryDirectory.path}${Platform.pathSeparator}backups',
    );
    final damaged = File(
      '${backupDirectory.path}${Platform.pathSeparator}'
      'before-import-20260813-110000-000.joquoteconverter',
    );
    await damaged.writeAsString('damaged');
    await damaged.setLastModified(DateTime(2026, 8, 13, 11));

    final backups = await service.listAutomaticBackups();

    expect(backups, hasLength(2));
    expect(
      backups.first.fileName,
      'before-import-20260813-110000-000.joquoteconverter',
    );
    expect(backups.first.canRestore, isFalse);
    expect(backups.first.errorMessage, isNotNull);
    expect(backups.last.canRestore, isTrue);
    expect(backups.last.document?.snapshot.history, hasLength(2));
  });

  test('deletes one automatic backup and can clear the remainder', () async {
    await service.createAutomaticBackup(
      snapshot: _snapshot(),
      appVersion: '0.0.2+2',
      now: DateTime(2026, 8, 13, 10),
    );
    await service.createAutomaticBackup(
      snapshot: _snapshot(),
      appVersion: '0.0.2+2',
      now: DateTime(2026, 8, 13, 11),
    );
    final backups = await service.listAutomaticBackups();

    await service.deleteAutomaticBackup(backups.first);
    expect(await service.listAutomaticBackups(), hasLength(1));
    expect(await service.clearAutomaticBackups(), 1);
    expect(await service.listAutomaticBackups(), isEmpty);
  });

  test('rejects backup deletion outside the private backup directory', () {
    final invalidBackup = AutomaticBackup(
      fileName: '../outside.joquoteconverter',
      sizeBytes: 1,
      modifiedAt: DateTime(2026, 8, 13),
    );

    expect(
      () => service.deleteAutomaticBackup(invalidBackup),
      throwsArgumentError,
    );
  });
}

ArchiveSnapshot _snapshot() => ArchiveSnapshot(
  draft: const SavedDraft(
    input: 'archive input',
    output: 'archive output',
    excludeMarkdownCode: false,
    useHeuristics: false,
  ),
  themeMode: 'dark',
  palette: 'purple',
  keyboardShortcutsEnabled: false,
  history: [
    ConversionHistoryEntry(
      input: 'new history',
      output: 'new output',
      createdAt: DateTime(2026, 8, 12, 12),
    ),
    ConversionHistoryEntry(
      input: 'old history',
      output: 'old output',
      createdAt: DateTime(2026, 8, 12, 11),
    ),
  ],
);
