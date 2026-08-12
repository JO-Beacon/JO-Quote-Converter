import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:crypto/crypto.dart';
import 'package:file_saver/file_saver.dart';
import 'package:file_selector/file_selector.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'draft_store.dart';
import 'history_store.dart';

const archiveExtension = 'joquoteconverter';
const archiveMimeType = 'application/x-jo-quote-converter-archive';

typedef ArchiveFilePicker =
    Future<XFile?> Function(List<XTypeGroup> acceptedTypeGroups);
typedef AndroidArchiveSaver =
    Future<String?> Function(String name, Uint8List bytes);

class ArchiveSnapshot {
  const ArchiveSnapshot({
    required this.draft,
    required this.themeMode,
    required this.palette,
    required this.keyboardShortcutsEnabled,
    required this.history,
  });

  final SavedDraft draft;
  final String themeMode;
  final String palette;
  final bool keyboardShortcutsEnabled;
  final List<ConversionHistoryEntry> history;
}

class ArchiveDocument {
  const ArchiveDocument({
    required this.appVersion,
    required this.exportedAt,
    required this.snapshot,
  });

  final String appVersion;
  final DateTime exportedAt;
  final ArchiveSnapshot snapshot;
}

class ArchiveFormatException implements Exception {
  const ArchiveFormatException(this.message);

  final String message;

  @override
  String toString() => message;
}

class AutomaticBackup {
  const AutomaticBackup({
    required this.fileName,
    required this.sizeBytes,
    required this.modifiedAt,
    this.document,
    this.errorMessage,
  });

  final String fileName;
  final int sizeBytes;
  final DateTime modifiedAt;
  final ArchiveDocument? document;
  final String? errorMessage;

  bool get canRestore => document != null;
}

class ArchiveService {
  ArchiveService({
    Future<Directory> Function()? supportDirectoryProvider,
    ArchiveFilePicker? filePicker,
    AndroidArchiveSaver? androidArchiveSaver,
    bool? isAndroid,
  }) : _filePicker =
           filePicker ??
           ((acceptedTypeGroups) => openFile(
             acceptedTypeGroups: acceptedTypeGroups,
             confirmButtonText: '导入',
           )),
       _androidArchiveSaver =
           androidArchiveSaver ??
           ((name, bytes) => FileSaver.instance.saveAs(
             name: p.basenameWithoutExtension(name),
             bytes: bytes,
             fileExtension: archiveExtension,
             mimeType: MimeType.custom,
             customMimeType: archiveMimeType,
           )),
       _isAndroid = isAndroid ?? Platform.isAndroid,
       _supportDirectoryProvider =
           supportDirectoryProvider ?? getApplicationSupportDirectory;

  static const formatVersion = 1;
  static const _manifestName = 'manifest.json';
  static const _workspaceName = 'workspace.json';
  static const _historyName = 'history.jsonl';
  static const _checksumsName = 'checksums.json';
  static const _maxArchiveBytes = 256 * 1024 * 1024;
  static const _maxEntryBytes = 128 * 1024 * 1024;

  final Future<Directory> Function() _supportDirectoryProvider;
  final ArchiveFilePicker _filePicker;
  final AndroidArchiveSaver _androidArchiveSaver;
  final bool _isAndroid;

  Uint8List encode({
    required ArchiveSnapshot snapshot,
    required String appVersion,
    DateTime? exportedAt,
  }) {
    final exportTime = (exportedAt ?? DateTime.now()).toUtc();
    final workspaceBytes = _jsonBytes({
      'input': snapshot.draft.input,
      'output': snapshot.draft.output,
      'settings': {
        'excludeMarkdownCode': snapshot.draft.excludeMarkdownCode,
        'useHeuristics': snapshot.draft.useHeuristics,
        'themeMode': snapshot.themeMode,
        'palette': snapshot.palette,
        'keyboardShortcutsEnabled': snapshot.keyboardShortcutsEnabled,
      },
    });
    final historyBytes = Uint8List.fromList(
      utf8.encode(
        snapshot.history
            .map(
              (entry) => jsonEncode({
                'input': entry.input,
                'output': entry.output,
                'createdAt': entry.createdAt.toUtc().toIso8601String(),
              }),
            )
            .join('\n'),
      ),
    );
    final manifestBytes = _jsonBytes({
      'format': 'JO-Quote-Converter',
      'formatVersion': formatVersion,
      'appVersion': appVersion,
      'exportedAt': exportTime.toIso8601String(),
      'historyCount': snapshot.history.length,
      'compressed': true,
      'encrypted': false,
    });
    final dataFiles = <String, Uint8List>{
      _manifestName: manifestBytes,
      _workspaceName: workspaceBytes,
      _historyName: historyBytes,
    };
    final checksumsBytes = _jsonBytes({
      'algorithm': 'SHA-256',
      'files': {
        for (final entry in dataFiles.entries)
          entry.key: sha256.convert(entry.value).toString(),
      },
    });

    final archive = Archive();
    for (final entry in dataFiles.entries) {
      archive.add(ArchiveFile.bytes(entry.key, entry.value));
    }
    archive.add(ArchiveFile.bytes(_checksumsName, checksumsBytes));
    return ZipEncoder().encodeBytes(
      archive,
      level: DeflateLevel.bestCompression,
      modified: exportTime,
    );
  }

  ArchiveDocument decode(List<int> bytes) {
    if (bytes.isEmpty || bytes.length > _maxArchiveBytes) {
      throw const ArchiveFormatException('存档为空或文件过大。');
    }

    Archive archive;
    try {
      archive = ZipDecoder().decodeBytes(bytes, verify: true);
    } catch (_) {
      throw const ArchiveFormatException('无法解压存档。');
    }

    final files = <String, Uint8List>{};
    var totalUncompressedBytes = 0;
    for (final file in archive.files) {
      if (!file.isFile) continue;
      if (file.name.contains('/') || file.name.contains('\\')) {
        throw const ArchiveFormatException('存档包含无效路径。');
      }
      if (files.containsKey(file.name) || file.size > _maxEntryBytes) {
        throw const ArchiveFormatException('存档文件重复或内容过大。');
      }
      totalUncompressedBytes += file.size;
      if (totalUncompressedBytes > _maxArchiveBytes) {
        throw const ArchiveFormatException('存档解压后内容过大。');
      }
      final content = file.readBytes();
      if (content == null) {
        throw const ArchiveFormatException('存档内容无法读取。');
      }
      files[file.name] = content;
    }
    const requiredNames = {
      _manifestName,
      _workspaceName,
      _historyName,
      _checksumsName,
    };
    if (files.length != requiredNames.length ||
        !files.keys.toSet().containsAll(requiredNames)) {
      throw const ArchiveFormatException('存档结构不完整。');
    }

    final checksums = _decodeObject(files[_checksumsName]!, '校验信息');
    if (checksums['algorithm'] != 'SHA-256') {
      throw const ArchiveFormatException('不支持此校验算法。');
    }
    final checksumFiles = checksums['files'];
    if (checksumFiles is! Map<String, dynamic>) {
      throw const ArchiveFormatException('校验信息无效。');
    }
    for (final name in requiredNames.where((name) => name != _checksumsName)) {
      final expected = checksumFiles[name];
      final actual = sha256.convert(files[name]!).toString();
      if (expected is! String || expected != actual) {
        throw ArchiveFormatException('$name 校验失败。');
      }
    }

    final manifest = _decodeObject(files[_manifestName]!, '存档清单');
    if (manifest['format'] != 'JO-Quote-Converter' ||
        manifest['formatVersion'] != formatVersion) {
      throw const ArchiveFormatException('不支持此存档版本。');
    }
    final appVersion = manifest['appVersion'];
    final exportedAtValue = manifest['exportedAt'];
    final historyCount = manifest['historyCount'];
    if (appVersion is! String ||
        exportedAtValue is! String ||
        historyCount is! int ||
        manifest['encrypted'] != false) {
      throw const ArchiveFormatException('存档清单无效。');
    }
    final exportedAt = DateTime.tryParse(exportedAtValue);
    if (exportedAt == null) {
      throw const ArchiveFormatException('存档导出时间无效。');
    }

    final workspace = _decodeObject(files[_workspaceName]!, '工作区数据');
    final input = workspace['input'];
    final output = workspace['output'];
    final settings = workspace['settings'];
    if (input is! String ||
        output is! String ||
        settings is! Map<String, dynamic>) {
      throw const ArchiveFormatException('工作区数据无效。');
    }
    final excludeMarkdownCode = settings['excludeMarkdownCode'];
    final useHeuristics = settings['useHeuristics'];
    final themeMode = settings['themeMode'];
    final palette = settings['palette'];
    final keyboardShortcutsEnabled = settings['keyboardShortcutsEnabled'];
    if (excludeMarkdownCode is! bool ||
        useHeuristics is! bool ||
        keyboardShortcutsEnabled is! bool ||
        themeMode is! String ||
        !const {'system', 'light', 'dark'}.contains(themeMode) ||
        palette is! String ||
        !const {
          'red',
          'yellow',
          'green',
          'blue',
          'purple',
          'gray',
        }.contains(palette)) {
      throw const ArchiveFormatException('存档设置无效。');
    }

    final history = <ConversionHistoryEntry>[];
    final historyText = _decodeUtf8(files[_historyName]!, '历史记录');
    if (historyText.isNotEmpty) {
      for (final line in const LineSplitter().convert(historyText)) {
        final decoded = _decodeJsonLine(line);
        final historyInput = decoded['input'];
        final historyOutput = decoded['output'];
        final createdAtValue = decoded['createdAt'];
        final createdAt = createdAtValue is String
            ? DateTime.tryParse(createdAtValue)
            : null;
        if (historyInput is! String ||
            historyOutput is! String ||
            createdAt == null) {
          throw const ArchiveFormatException('历史记录内容无效。');
        }
        history.add(
          ConversionHistoryEntry(
            input: historyInput,
            output: historyOutput,
            createdAt: createdAt.toLocal(),
          ),
        );
      }
    }
    if (history.length != historyCount) {
      throw const ArchiveFormatException('历史记录数量与清单不一致。');
    }

    return ArchiveDocument(
      appVersion: appVersion,
      exportedAt: exportedAt.toLocal(),
      snapshot: ArchiveSnapshot(
        draft: SavedDraft(
          input: input,
          output: output,
          excludeMarkdownCode: excludeMarkdownCode,
          useHeuristics: useHeuristics,
        ),
        themeMode: themeMode,
        palette: palette,
        keyboardShortcutsEnabled: keyboardShortcutsEnabled,
        history: history,
      ),
    );
  }

  Future<bool> exportWithPicker({
    required ArchiveSnapshot snapshot,
    required String appVersion,
    DateTime? now,
  }) async {
    final exportTime = now ?? DateTime.now();
    final name = 'JO-引号转换-${_fileTimestamp(exportTime)}.$archiveExtension';
    final data = encode(
      snapshot: snapshot,
      appVersion: appVersion,
      exportedAt: exportTime,
    );
    if (_isAndroid) {
      return await _androidArchiveSaver(name, data) != null;
    }
    final location = await getSaveLocation(
      acceptedTypeGroups: const [
        XTypeGroup(
          label: 'JO-引号转换存档',
          extensions: [archiveExtension],
          mimeTypes: [archiveMimeType],
        ),
      ],
      suggestedName: name,
      confirmButtonText: '导出',
    );
    if (location == null) return false;
    final archiveFile = XFile.fromData(
      data,
      mimeType: archiveMimeType,
      name: name,
    );
    await archiveFile.saveTo(_ensureExtension(location.path));
    return true;
  }

  Future<ArchiveDocument?> pickAndDecode() async {
    final file = await _filePicker(
      _isAndroid
          ? const [XTypeGroup(label: 'JO-引号转换存档')]
          : const [
              XTypeGroup(
                label: 'JO-引号转换存档',
                extensions: [archiveExtension],
                mimeTypes: [archiveMimeType],
              ),
            ],
    );
    if (file == null) return null;
    if (!_isAndroid && !_hasArchiveExtension(file.name)) {
      throw const ArchiveFormatException('请选择 .joquoteconverter 存档文件。');
    }
    return decode(await file.readAsBytes());
  }

  Future<String> createAutomaticBackup({
    required ArchiveSnapshot snapshot,
    required String appVersion,
    DateTime? now,
  }) async {
    final backupTime = now ?? DateTime.now();
    final supportDirectory = await _supportDirectoryProvider();
    final backupDirectory = Directory(p.join(supportDirectory.path, 'backups'));
    await backupDirectory.create(recursive: true);
    final file = File(
      p.join(
        backupDirectory.path,
        'before-import-${_fileTimestamp(backupTime)}.$archiveExtension',
      ),
    );
    await file.writeAsBytes(
      encode(
        snapshot: snapshot,
        appVersion: appVersion,
        exportedAt: backupTime,
      ),
      flush: true,
    );
    return file.path;
  }

  Future<List<AutomaticBackup>> listAutomaticBackups() async {
    final backupDirectory = await _backupDirectory();
    if (!await backupDirectory.exists()) return const [];

    final backups = <AutomaticBackup>[];
    await for (final entity in backupDirectory.list(followLinks: false)) {
      if (entity is! File ||
          !entity.path.toLowerCase().endsWith('.$archiveExtension')) {
        continue;
      }
      final stat = await entity.stat();
      try {
        backups.add(
          AutomaticBackup(
            fileName: p.basename(entity.path),
            sizeBytes: stat.size,
            modifiedAt: stat.modified,
            document: decode(await entity.readAsBytes()),
          ),
        );
      } on ArchiveFormatException catch (error) {
        backups.add(
          AutomaticBackup(
            fileName: p.basename(entity.path),
            sizeBytes: stat.size,
            modifiedAt: stat.modified,
            errorMessage: error.message,
          ),
        );
      } catch (_) {
        backups.add(
          AutomaticBackup(
            fileName: p.basename(entity.path),
            sizeBytes: stat.size,
            modifiedAt: stat.modified,
            errorMessage: '备份文件无法读取。',
          ),
        );
      }
    }
    backups.sort((a, b) => b.modifiedAt.compareTo(a.modifiedAt));
    return backups;
  }

  Future<void> deleteAutomaticBackup(AutomaticBackup backup) async {
    final file = await _automaticBackupFile(backup.fileName);
    if (!await file.exists()) throw StateError('备份文件不存在。');
    await file.delete();
  }

  Future<int> clearAutomaticBackups() async {
    final backups = await listAutomaticBackups();
    for (final backup in backups) {
      final file = await _automaticBackupFile(backup.fileName);
      if (await file.exists()) await file.delete();
    }
    return backups.length;
  }

  Future<Directory> _backupDirectory() async {
    final supportDirectory = await _supportDirectoryProvider();
    return Directory(p.join(supportDirectory.path, 'backups'));
  }

  Future<File> _automaticBackupFile(String fileName) async {
    if (fileName != p.basename(fileName) ||
        !fileName.toLowerCase().endsWith('.$archiveExtension')) {
      throw ArgumentError.value(fileName, 'fileName', '无效的备份文件名');
    }
    final backupDirectory = await _backupDirectory();
    return File(p.join(backupDirectory.path, fileName));
  }

  static Uint8List _jsonBytes(Map<String, Object?> value) =>
      Uint8List.fromList(utf8.encode(jsonEncode(value)));

  static Map<String, dynamic> _decodeObject(Uint8List bytes, String label) {
    try {
      final decoded = jsonDecode(utf8.decode(bytes));
      if (decoded is Map<String, dynamic>) return decoded;
    } catch (_) {
      // Converted below to a stable user-facing format error.
    }
    throw ArchiveFormatException('$label无效。');
  }

  static Map<String, dynamic> _decodeJsonLine(String line) {
    try {
      final decoded = jsonDecode(line);
      if (decoded is Map<String, dynamic>) return decoded;
    } catch (_) {
      // Converted below to a stable user-facing format error.
    }
    throw const ArchiveFormatException('历史记录内容无效。');
  }

  static String _decodeUtf8(Uint8List bytes, String label) {
    try {
      return utf8.decode(bytes);
    } catch (_) {
      throw ArchiveFormatException('$label不是有效的 UTF-8 文本。');
    }
  }

  static String _fileTimestamp(DateTime value) {
    final local = value.toLocal();
    String two(int number) => number.toString().padLeft(2, '0');
    String three(int number) => number.toString().padLeft(3, '0');
    return '${local.year}${two(local.month)}${two(local.day)}-'
        '${two(local.hour)}${two(local.minute)}${two(local.second)}-'
        '${three(local.millisecond)}';
  }

  static String _ensureExtension(String path) =>
      _hasArchiveExtension(path) ? path : '$path.$archiveExtension';

  static bool _hasArchiveExtension(String path) =>
      path.toLowerCase().endsWith('.$archiveExtension');
}
