/// 앱 표기 상수. 설정 화면의 버전·링크가 여기서 나온다(HOME_REDESIGN §2.3).
library;

/// 앱 버전 표기. `package_info_plus` 를 넣기 전까지 pubspec 과 손으로 맞춘다.
/// 심사에 필요한 건 표기 자체라 상수 하나로 충분하다.
abstract final class AppMeta {
  static const version = '0.1.0';
  static const build = '1';
  static const versionLabel = '$version ($build)';
}

/// 외부 링크.
abstract final class AppLinks {
  /// 배포 전 실제 URL 로 교체. placeholder 상태로 스토어에 올리지 않는다.
  static const privacyPolicy = 'https://example.com/mossol/privacy';
}
