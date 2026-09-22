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
  /// 공용 안내 사이트(github.com/humsleep/apps, GitHub Pages). App Store 의 개인정보처리방침 URL 과 같아야 한다.
  static const privacyPolicy = 'https://humsleep.github.io/apps/mossol/privacy/';

  /// App Store 지원 URL 과 같은 안내·문의 페이지.
  static const support = 'https://humsleep.github.io/apps/mossol/';
}
