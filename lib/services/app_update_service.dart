import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:stelliberty/utils/logger.dart';

// 应用更新信息
class AppUpdateInfo {
  final String currentVersion;
  final String latestVersion;
  final bool hasUpdate;
  final String? downloadUrl;
  final String? releaseNotes;
  final String? htmlUrl;

  AppUpdateInfo({
    required this.currentVersion,
    required this.latestVersion,
    required this.hasUpdate,
    this.downloadUrl,
    this.releaseNotes,
    this.htmlUrl,
  });
}

// 应用更新服务
class AppUpdateService {
  AppUpdateService._();

  static final AppUpdateService instance = AppUpdateService._();

  static const String _githubRepo = 'Kindness-Kismet/Stelliberty';
  static const String _githubApiUrl =
      'https://api.github.com/repos/$_githubRepo/releases/latest';

  // 检查更新
  Future<AppUpdateInfo?> checkForUpdate() async {
    try {
      Logger.info('开始检查应用更新...');

      // 获取当前版本
      final packageInfo = await PackageInfo.fromPlatform();
      final currentVersion = packageInfo.version;
      Logger.info('当前版本: $currentVersion');

      // 请求 GitHub API
      final response = await http
          .get(
            Uri.parse(_githubApiUrl),
            headers: {'Accept': 'application/vnd.github.v3+json'},
          )
          .timeout(
            const Duration(seconds: 10),
            onTimeout: () {
              throw Exception('请求超时');
            },
          );

      if (response.statusCode != 200) {
        Logger.error('GitHub API 请求失败: ${response.statusCode}');
        return null;
      }

      // 解析响应
      final data = json.decode(response.body) as Map<String, dynamic>;
      final latestVersion =
          (data['tag_name'] as String?)?.replaceFirst('v', '') ?? '';
      final htmlUrl = data['html_url'] as String?;
      final releaseNotes = data['body'] as String?;

      Logger.info('最新版本: $latestVersion');

      // 比较版本
      final hasUpdate = _compareVersions(currentVersion, latestVersion) < 0;

      // 根据当前平台和架构查找匹配的安装包
      String? downloadUrl;
      final assets = data['assets'] as List<dynamic>?;
      if (assets != null && assets.isNotEmpty) {
        downloadUrl = _findMatchingAsset(assets);
      }

      final updateInfo = AppUpdateInfo(
        currentVersion: currentVersion,
        latestVersion: latestVersion,
        hasUpdate: hasUpdate,
        downloadUrl: downloadUrl,
        releaseNotes: releaseNotes,
        htmlUrl: htmlUrl,
      );

      Logger.info('更新检查完成: ${hasUpdate ? "发现新版本" : "已是最新版本"}');
      return updateInfo;
    } catch (e) {
      Logger.error('检查更新失败: $e');
      return null;
    }
  }

  // 根据当前平台和架构查找匹配的安装包
  String? _findMatchingAsset(List<dynamic> assets) {
    // 获取当前平台和架构信息
    final platform =
        Platform.operatingSystem; // windows, linux, macos, android, ios
    final arch = _getCurrentArchitecture();

    Logger.info('当前平台: $platform, 架构: $arch');

    // 定义平台匹配规则
    final matchRules = _getPlatformMatchRules(platform, arch);

    if (matchRules == null) {
      Logger.warning('不支持的平台: $platform');
      return null;
    }

    // 遍历所有资源，查找匹配的安装包
    for (final asset in assets) {
      final assetData = asset as Map<String, dynamic>;
      final name = (assetData['name'] as String?)?.toLowerCase() ?? '';
      final url = assetData['browser_download_url'] as String?;

      // 检查文件扩展名
      if (!name.endsWith(matchRules.fileExtension)) {
        continue;
      }

      // 检查平台关键字
      if (!matchRules.platformKeywords.any(
        (keyword) => name.contains(keyword),
      )) {
        continue;
      }

      // 检查架构关键字（如果指定）
      if (matchRules.archKeywords.isNotEmpty &&
          !matchRules.archKeywords.any((keyword) => name.contains(keyword))) {
        continue;
      }

      // 检查必需的关键字（如 setup）
      if (matchRules.requiredKeywords.isNotEmpty &&
          !matchRules.requiredKeywords.every(
            (keyword) => name.contains(keyword),
          )) {
        continue;
      }

      Logger.info('找到匹配的安装包: $name');
      Logger.info('下载链接: $url');
      return url;
    }

    Logger.warning('未找到匹配当前平台的安装包');
    return null;
  }

  // 获取当前系统架构（仅支持 64 位）
  String _getCurrentArchitecture() {
    // Dart 的 Platform.version 包含架构信息
    // 例如: "2.19.0 (stable) (Wed Jan 11 18:19:33 2023 +0000) on "windows_x64""
    final version = Platform.version;

    if (version.contains('arm64') || version.contains('aarch64')) {
      return 'arm64';
    } else if (version.contains('x64') ||
        version.contains('x86_64') ||
        version.contains('amd64')) {
      return 'x64';
    }

    // 默认假设 x64（不支持 32 位）
    return 'x64';
  }

  // 获取平台匹配规则（仅支持 64 位架构）
  _PlatformMatchRules? _getPlatformMatchRules(String platform, String arch) {
    switch (platform) {
      case 'windows':
        // Windows 支持 x64 和 arm64
        return _PlatformMatchRules(
          fileExtension: '.exe',
          platformKeywords: ['win', 'windows'],
          archKeywords: arch == 'arm64'
              ? ['arm64', 'aarch64']
              : ['x64', 'amd64', 'x86_64'],
          requiredKeywords: ['setup'], // 必须包含 setup
        );

      case 'linux':
        // Linux 支持 x64 和 arm64
        return _PlatformMatchRules(
          fileExtension: '.AppImage',
          platformKeywords: ['linux'],
          archKeywords: arch == 'arm64'
              ? ['arm64', 'aarch64']
              : ['x64', 'amd64', 'x86_64'],
          requiredKeywords: [],
        );

      case 'macos':
        // macOS 支持 arm64 (Apple Silicon) 和 x64 (Intel)
        return _PlatformMatchRules(
          fileExtension: '.dmg',
          platformKeywords: ['macos', 'darwin', 'osx'],
          archKeywords: arch == 'arm64'
              ? ['arm64', 'aarch64', 'apple-silicon']
              : ['x64', 'intel', 'amd64'],
          requiredKeywords: [],
        );

      case 'android':
        return _PlatformMatchRules(
          fileExtension: '.apk',
          platformKeywords: ['android'],
          archKeywords: [],
          requiredKeywords: [],
        );

      default:
        return null;
    }
  }

  // 比较版本号（< 0: v1 < v2，= 0: 相等，> 0: v1 > v2）
  int _compareVersions(String v1, String v2) {
    final parts1 = v1.split('.').map((e) => int.tryParse(e) ?? 0).toList();
    final parts2 = v2.split('.').map((e) => int.tryParse(e) ?? 0).toList();

    final maxLength = parts1.length > parts2.length
        ? parts1.length
        : parts2.length;

    for (int i = 0; i < maxLength; i++) {
      final p1 = i < parts1.length ? parts1[i] : 0;
      final p2 = i < parts2.length ? parts2[i] : 0;

      if (p1 != p2) {
        return p1.compareTo(p2);
      }
    }

    return 0;
  }
}

// 平台匹配规则
class _PlatformMatchRules {
  final String fileExtension; // .exe, .dmg, .AppImage
  final List<String> platformKeywords; // 至少匹配一个
  final List<String> archKeywords; // 至少匹配一个，为空则不检查
  final List<String> requiredKeywords; // 必须全部匹配

  const _PlatformMatchRules({
    required this.fileExtension,
    required this.platformKeywords,
    required this.archKeywords,
    required this.requiredKeywords,
  });
}
