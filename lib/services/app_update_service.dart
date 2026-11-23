import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:open_filex/open_filex.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppUpdateInfo {
  final String version;
  final int buildNumber;
  final String downloadUrl;
  final String releaseNotes;

  const AppUpdateInfo({
    required this.version,
    required this.buildNumber,
    required this.downloadUrl,
    required this.releaseNotes,
  });

  String get versionLabel => '$version+$buildNumber';
}

class AppUpdateService {
  static const _releasesUrl =
      'https://api.github.com/repos/Saibharath548/article-pulse/releases?per_page=20';
  static const _autoCheckKey = 'auto_check_app_updates';
  static const _lastCheckKey = 'last_app_update_check_ms';
  static const _checkInterval = Duration(hours: 6);

  final http.Client _client;

  AppUpdateService({http.Client? client}) : _client = client ?? http.Client();

  static Future<bool> getAutoCheckEnabled() async {
    final preferences = await SharedPreferences.getInstance();
    return preferences.getBool(_autoCheckKey) ?? true;
  }

  static Future<void> setAutoCheckEnabled(bool enabled) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setBool(_autoCheckKey, enabled);
  }

  /// Checks public GitHub Releases, including prereleases made from feature branches.
  /// Automatic checks are throttled to once every six hours; manual checks bypass the throttle.
  Future<AppUpdateInfo?> checkForUpdate({bool force = false}) async {
    if (!Platform.isAndroid) return null;

    final preferences = await SharedPreferences.getInstance();
    final lastCheck = preferences.getInt(_lastCheckKey);
    if (!force && lastCheck != null) {
      final elapsed = DateTime.now().difference(
        DateTime.fromMillisecondsSinceEpoch(lastCheck),
      );
      if (elapsed < _checkInterval) return null;
    }

    final response = await _client.get(
      Uri.parse(_releasesUrl),
      headers: const {
        'Accept': 'application/vnd.github+json',
        'X-GitHub-Api-Version': '2022-11-28',
        'User-Agent': 'ArticlePulse-Android-App',
      },
    ).timeout(const Duration(seconds: 20));

    if (response.statusCode != 200) {
      throw Exception('GitHub update check failed (HTTP ${response.statusCode}).');
    }

    await preferences.setInt(_lastCheckKey, DateTime.now().millisecondsSinceEpoch);

    final decoded = jsonDecode(response.body);
    if (decoded is! List) {
      throw const FormatException('GitHub returned an unexpected releases response.');
    }

    final packageInfo = await PackageInfo.fromPlatform();
    final currentVersion = _parseVersion(packageInfo.version, packageInfo.buildNumber);
    if (currentVersion == null) return null;

    AppUpdateInfo? newestUpdate;
    List<int>? newestVersion;

    for (final item in decoded) {
      if (item is! Map<String, dynamic> || item['draft'] == true) continue;

      final remoteVersion = _parseTag(item['tag_name']?.toString() ?? '');
      if (remoteVersion == null || _compareVersions(remoteVersion, currentVersion) <= 0) {
        continue;
      }

      final assets = item['assets'];
      if (assets is! List) continue;

      Map<String, dynamic>? apkAsset;
      for (final asset in assets) {
        if (asset is Map<String, dynamic> &&
            (asset['name']?.toString().toLowerCase().endsWith('.apk') ?? false)) {
          apkAsset = asset;
          break;
        }
      }

      final downloadUrl = apkAsset?['browser_download_url']?.toString();
      if (downloadUrl == null || downloadUrl.isEmpty) continue;

      if (newestVersion == null || _compareVersions(remoteVersion, newestVersion) > 0) {
        newestVersion = remoteVersion;
        newestUpdate = AppUpdateInfo(
          version: '${remoteVersion[0]}.${remoteVersion[1]}.${remoteVersion[2]}',
          buildNumber: remoteVersion[3],
          downloadUrl: downloadUrl,
          releaseNotes: item['body']?.toString().trim() ?? '',
        );
      }
    }

    return newestUpdate;
  }

  Future<void> downloadAndInstall(AppUpdateInfo update) async {
    if (!Platform.isAndroid) {
      throw UnsupportedError('In-app APK installation is available only on Android.');
    }

    final response = await _client.get(
      Uri.parse(update.downloadUrl),
      headers: const {'User-Agent': 'ArticlePulse-Android-App'},
    ).timeout(const Duration(minutes: 3));

    if (response.statusCode != 200 || response.bodyBytes.length < 1024) {
      throw Exception('The APK download did not complete successfully.');
    }

    // APK files are ZIP containers. Reject an HTML error page or other unexpected response.
    if (response.bodyBytes[0] != 0x50 || response.bodyBytes[1] != 0x4b) {
      throw Exception('GitHub did not return a valid APK file.');
    }

    final directory = await getTemporaryDirectory();
    final apkFile = File('${directory.path}/article-pulse-update-${update.buildNumber}.apk');
    await apkFile.writeAsBytes(response.bodyBytes, flush: true);

    final result = await OpenFilex.open(
      apkFile.path,
      type: 'application/vnd.android.package-archive',
    );

    if (result.type != ResultType.done) {
      throw Exception('Could not open the Android installer: ${result.message}');
    }
  }

  static List<int>? _parseTag(String tag) {
    final match = RegExp(r'^v?(\d+(?:\.\d+){1,2})(?:\+(\d+))?$')
        .firstMatch(tag.trim());
    if (match == null) return null;

    final parts = match.group(1)!.split('.').map(int.tryParse).toList();
    if (parts.any((part) => part == null)) return null;
    while (parts.length < 3) {
      parts.add(0);
    }

    return [
      parts[0]!,
      parts[1]!,
      parts[2]!,
      int.tryParse(match.group(2) ?? '0') ?? 0,
    ];
  }

  static List<int>? _parseVersion(String version, String buildNumber) {
    final parts = version.split('.').map(int.tryParse).toList();
    if (parts.isEmpty || parts.any((part) => part == null)) return null;
    while (parts.length < 3) {
      parts.add(0);
    }
    if (parts.length > 3) return null;

    return [
      parts[0]!,
      parts[1]!,
      parts[2]!,
      int.tryParse(buildNumber) ?? 0,
    ];
  }

  static int _compareVersions(List<int> a, List<int> b) {
    for (var i = 0; i < 4; i++) {
      if (a[i] != b[i]) return a[i].compareTo(b[i]);
    }
    return 0;
  }
}
