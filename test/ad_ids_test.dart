import 'package:flutter_test/flutter_test.dart';
import 'package:mossol/ads/ad_manager.dart';

void main() {
  test('iOS 릴리스는 실제 광고 단위, 디버그는 Google 테스트 단위', () {
    final real = AdManager.idsFor(ios: true, release: true);
    final debug = AdManager.idsFor(ios: true, release: false);
    for (final kind in ['interstitial', 'rewarded', 'banner']) {
      expect(real[kind], startsWith('ca-app-pub-4073994600346533/'), reason: kind);
      expect(debug[kind], startsWith('ca-app-pub-3940256099942544/'), reason: kind);
    }
  });

  test('Android 는 AdMob 앱이 생기기 전까지 릴리스도 테스트 단위', () {
    final ids = AdManager.idsFor(ios: false, release: true);
    expect(ids.values, everyElement(startsWith('ca-app-pub-3940256099942544/')));
  });
}
