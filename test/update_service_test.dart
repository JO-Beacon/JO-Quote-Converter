import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:jo_quote_converter/update_service.dart';

void main() {
  test('parses a GitHub release and detects a newer build', () async {
    final service = GitHubUpdateService(
      fetchJson: (_) async => jsonEncode({
        'tag_name': 'v0.0.5+5',
        'name': 'JO-引号转换 0.0.5',
        'html_url':
            'https://github.com/JO-Beacon/JO-Quote-Converter/releases/tag/v0.0.5%2B5',
      }),
    );

    final result = await service.checkForUpdate('0.0.4+4');

    expect(result.updateAvailable, isTrue);
    expect(result.release.version, '0.0.5+5');
    expect(result.release.htmlUrl.host, 'github.com');
  });

  test('reports the current version when the release is not newer', () async {
    final service = GitHubUpdateService(
      fetchJson: (_) async => jsonEncode({
        'tag_name': '0.0.4+4',
        'name': '当前版本',
        'html_url':
            'https://github.com/JO-Beacon/JO-Quote-Converter/releases/tag/v0.0.4%2B4',
      }),
    );

    final result = await service.checkForUpdate('v0.0.4+4');

    expect(result.updateAvailable, isFalse);
    expect(result.comparison, 0);
  });

  test('compares build metadata after the semantic version', () {
    expect(GitHubUpdateService.compareVersions('0.0.4+5', '0.0.4+4'), 1);
    expect(GitHubUpdateService.compareVersions('0.1.0', '0.0.9+99'), 1);
    expect(GitHubUpdateService.compareVersions('v0.0.4', '0.0.4+1'), -1);
  });

  test('rejects a release with an unsupported tag', () async {
    final service = GitHubUpdateService(
      fetchJson: (_) async => jsonEncode({
        'tag_name': 'latest',
        'name': '不规范版本',
        'html_url':
            'https://github.com/JO-Beacon/JO-Quote-Converter/releases/latest',
      }),
    );

    await expectLater(
      service.fetchLatestRelease(),
      throwsA(
        isA<UpdateCheckException>().having(
          (error) => error.message,
          'message',
          'GitHub 返回的版本信息无效',
        ),
      ),
    );
  });

  test('turns a fetch failure into a user-facing update error', () async {
    final service = GitHubUpdateService(
      fetchJson: (_) async => throw StateError('offline'),
    );

    await expectLater(
      service.fetchLatestRelease(),
      throwsA(
        isA<UpdateCheckException>().having(
          (error) => error.message,
          'message',
          '无法连接 GitHub',
        ),
      ),
    );
  });
}
