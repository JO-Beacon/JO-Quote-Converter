import 'dart:convert';
import 'dart:io';

final githubLatestReleaseUri = Uri.parse(
  'https://api.github.com/repos/JO-Beacon/JO-Quote-Converter/releases/latest',
);

typedef JsonFetcher = Future<String> Function(Uri uri);

class GitHubRelease {
  const GitHubRelease({
    required this.tagName,
    required this.name,
    required this.htmlUrl,
  });

  final String tagName;
  final String name;
  final Uri htmlUrl;

  String get version =>
      tagName.startsWith('v') ? tagName.substring(1) : tagName;
}

class UpdateCheckResult {
  const UpdateCheckResult({required this.release, required this.comparison});

  final GitHubRelease release;
  final int comparison;

  bool get updateAvailable => comparison > 0;
}

class UpdateCheckException implements Exception {
  const UpdateCheckException(this.message);

  final String message;

  @override
  String toString() => message;
}

class GitHubUpdateService {
  const GitHubUpdateService({this.fetchJson = _fetchJson});

  final JsonFetcher fetchJson;

  Future<UpdateCheckResult> checkForUpdate(String currentVersion) async {
    final release = await fetchLatestRelease();
    final comparison = compareVersions(release.version, currentVersion);
    return UpdateCheckResult(release: release, comparison: comparison);
  }

  Future<GitHubRelease> fetchLatestRelease() async {
    late final String body;
    try {
      body = await fetchJson(githubLatestReleaseUri);
    } on UpdateCheckException {
      rethrow;
    } catch (_) {
      throw const UpdateCheckException('无法连接 GitHub');
    }

    try {
      final decoded = jsonDecode(body);
      if (decoded is! Map<String, dynamic>) {
        throw const FormatException();
      }
      final tagName = decoded['tag_name'];
      final name = decoded['name'];
      final htmlUrl = decoded['html_url'];
      if (tagName is! String || tagName.trim().isEmpty || htmlUrl is! String) {
        throw const FormatException();
      }
      final parsedUrl = Uri.tryParse(htmlUrl);
      if (parsedUrl == null || parsedUrl.scheme != 'https') {
        throw const FormatException();
      }
      final release = GitHubRelease(
        tagName: tagName.trim(),
        name: name is String && name.trim().isNotEmpty
            ? name.trim()
            : tagName.trim(),
        htmlUrl: parsedUrl,
      );
      _parseVersion(release.version);
      return release;
    } on FormatException {
      throw const UpdateCheckException('GitHub 返回的版本信息无效');
    }
  }

  static int compareVersions(String left, String right) {
    final leftParts = _parseVersion(left);
    final rightParts = _parseVersion(right);
    for (var index = 0; index < leftParts.length; index++) {
      final comparison = leftParts[index].compareTo(rightParts[index]);
      if (comparison != 0) return comparison;
    }
    return 0;
  }

  static List<int> _parseVersion(String value) {
    final match = RegExp(
      r'^v?(\d+)\.(\d+)\.(\d+)(?:\+(\d+))?$',
    ).firstMatch(value.trim());
    if (match == null) throw const FormatException();
    return [
      int.parse(match.group(1)!),
      int.parse(match.group(2)!),
      int.parse(match.group(3)!),
      int.tryParse(match.group(4) ?? '0') ?? 0,
    ];
  }
}

Future<String> _fetchJson(Uri uri) async {
  final client = HttpClient()..connectionTimeout = const Duration(seconds: 10);
  try {
    final request = await client
        .getUrl(uri)
        .timeout(const Duration(seconds: 15));
    request.headers
      ..set(HttpHeaders.acceptHeader, 'application/vnd.github+json')
      ..set(HttpHeaders.userAgentHeader, 'JO-Quote-Converter');
    final response = await request.close().timeout(const Duration(seconds: 15));
    final body = await response.transform(utf8.decoder).join();
    if (response.statusCode != HttpStatus.ok) {
      throw UpdateCheckException(
        'GitHub 暂时无法提供版本信息（HTTP ${response.statusCode}）',
      );
    }
    return body;
  } finally {
    client.close(force: true);
  }
}
