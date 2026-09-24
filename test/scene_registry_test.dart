/// 장면 그림 레지스트리(lib/ui/scene_registry.dart)와 데이터 계약(06_scene_plan §4).
///
/// 그림 파일은 아직 하나도 없다. 그래서 이 테스트는 "파일이 있는지" 가 아니라
/// **목록을 어떻게 읽고, 없을 때 무엇을 돌려주는지**를 본다.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:mossol/engine/models.dart';
import 'package:mossol/ui/scene_registry.dart';

import 'widget/scene_helpers.dart';

void main() {
  group('SceneRegistry.fromAssets', () {
    final r = SceneRegistry.fromAssets([
      'assets/story/characters.json',
      'assets/portraits/seoyeon.png',
      'assets/scenes/.gitkeep',
      'assets/scenes/m01.webp',
      'assets/scenes/mo_seoyeon_call_eleven.webp',
      'assets/scenes/drafts/m02.webp',
      'assets/scenes/readme.txt',
      'assets/photos/night.webp',
      'assets/photos/night.png',
      'assets/photos/mo_seoyeon_photo_night_0.webp',
      'assets/stickers/seoyeon_joy.webp',
      'assets/endings/common_bad.webp',
    ]);

    test('네 폴더의 <이름>.<확장자> 만 고른다', () {
      expect(r.scene('m01'), 'assets/scenes/m01.webp');
      expect(r.scene('mo_seoyeon_call_eleven'), isNotNull);
      expect(r.photo('mo_seoyeon_photo_night_0'), isNotNull);
      expect(r.sticker('seoyeon_joy'), 'assets/stickers/seoyeon_joy.webp');
      expect(r.ending('common_bad'), 'assets/endings/common_bad.webp');
      expect(r.scene('m02'), isNull, reason: '하위 폴더는 무시');
      expect(r.scene('readme'), isNull, reason: '목록에 없는 형식은 무시');
      expect(r.scene('.gitkeep'), isNull);
      expect(r.length, 7);
    });

    test('같은 이름이 여러 형식이면 extensions 앞쪽(png)을 쓴다', () {
      expect(SceneRegistry.extensions.first, 'png');
      expect(SceneRegistry.extensions.contains('webp'), isTrue);
      expect(r.photo('night'), 'assets/photos/night.png');
      // 어느 쪽이든 경로 자체를 적었으면 그 파일을 찾아 준다.
      expect(r.exact('assets/photos/night.webp'), 'assets/photos/night.webp');
    });

    test('모르는 이름·null·다른 폴더는 null', () {
      expect(r.scene('없는거'), isNull);
      expect(r.scene(null), isNull);
      expect(r.photo('m01'), isNull, reason: '폴더가 다르다');
      expect(r.sticker('seoyeon_sulk'), isNull);
      expect(r.exact('assets/scenes/없는거.webp'), isNull);
      expect(r.exact('assets/portraits/seoyeon.png'), isNull);
      expect(r.exact(null), isNull);
    });

    test('그림이 하나도 없으면 전부 null(지금 상태)', () {
      expect(SceneRegistry.empty.length, 0);
      expect(SceneRegistry.empty.scene('m01'), isNull);
      expect(SceneRegistry.empty.keysIn(SceneRegistry.photoDir), isEmpty);
    });

    test('실제 번들 매니페스트를 읽어도 던지지 않고, 찾은 이름은 규약을 지킨다', () async {
      TestWidgetsFlutterBinding.ensureInitialized();
      addTearDown(() => SceneRegistry.debugOverride(null));
      final live = await SceneRegistry.load();
      expect(identical(SceneRegistry.current, live), isTrue);
      for (final key in live.keysIn(SceneRegistry.stickerDir)) {
        expect(Sticker.isValid(key), isTrue, reason: '스티커 파일명 규약: $key');
      }
    });

    test('매니페스트를 못 읽으면 던지지 않고 빈 목록', () async {
      addTearDown(() => SceneRegistry.debugOverride(null));
      final r = await SceneRegistry.load(bundle: FixtureSceneBundle());
      expect(r.length, 0);
    });
  });

  group('Sticker 화이트리스트', () {
    test('<캐릭터>_<감정 4종> 과 5번째 넷만 통과', () {
      for (final e in Sticker.emotions) {
        expect(Sticker.isValid('seoyeon_$e'), isTrue);
      }
      for (final x in Sticker.extras) {
        expect(Sticker.isValid(x), isTrue, reason: x);
      }
      expect(Sticker.emotions, ['joy', 'sulk', 'shy', 'surprise']);
    });

    test('모르는 감정·빈 값·언더스코어 없는 값은 거부', () {
      for (final bad in [
        'seoyeon_angry',
        'seoyeon_sulky', // 규약은 sulk
        'seoyeon_surprised', // 규약은 surprise
        'joy',
        'seoyeon_',
        '_joy',
        '',
        'daeun_blankk',
      ]) {
        expect(Sticker.isValid(bad), isFalse, reason: bad);
      }
    });

    test('캐릭터·감정을 되뽑고, 규약 밖이면 null', () {
      expect(Sticker.characterOf('seoyeon_joy'), 'seoyeon');
      expect(Sticker.emotionOf('seoyeon_joy'), 'joy');
      expect(Sticker.characterOf('daeun_blank'), 'daeun');
      expect(Sticker.emotionOf('daeun_blank'), 'blank');
      expect(Sticker.characterOf('seoyeon_angry'), isNull);
      expect(Sticker.emotionOf('seoyeon_angry'), isNull);
      expect(Sticker.labels['joy'], '기쁨');
    });
  });

  group('AssetPath', () {
    test('assets/ 로 시작하는 한 줄만 통과(존재는 보지 않는다)', () {
      expect(AssetPath.isValid('assets/scenes/없는파일.webp'), isTrue);
      expect(AssetPath.isValid('assets/'), isFalse);
      expect(AssetPath.isValid('scenes/m01.webp'), isFalse);
      expect(AssetPath.isValid('/assets/scenes/m01.webp'), isFalse);
      expect(AssetPath.isValid('assets/scenes/a b.webp'), isFalse);
      expect(AssetPath.isValid('assets\\scenes\\m01.webp'), isFalse);
    });
  });

  group('SceneImages 규약 경로', () {
    final registry = SceneRegistry.fromAssets([
      'assets/scenes/m01.webp',
      'assets/scenes/공유.webp',
      'assets/photos/night.webp',
      'assets/photos/mo_seoyeon_photo_night_0.webp',
      'assets/stickers/seoyeon_joy.webp',
      'assets/endings/seoyeon.webp',
      'assets/endings/common_bad.webp',
      'assets/endings/ending_one.webp',
    ]);

    StoryEvent event(String id, {String? image}) =>
        StoryEvent(id: id, layer: EventLayer.main, image: image);

    test('이벤트: image 필드 → assets/scenes/<id>', () {
      expect(SceneImages.forEvent(event('m01'), registry: registry), isNotNull);
      expect(SceneImages.forEvent(event('m99'), registry: registry), isNull);
      expect(
        SceneImages.forEvent(
          event('m99', image: 'assets/scenes/공유.webp'),
          registry: registry,
        ),
        'assets/scenes/공유.webp',
      );
      // 적어 준 경로의 파일이 없으면 규약 경로로 되돌아간다.
      expect(
        SceneImages.forEvent(
          event('m01', image: 'assets/scenes/없는거.webp'),
          registry: registry,
        ),
        'assets/scenes/m01.webp',
      );
      expect(SceneImages.forEvent(null, registry: registry), isNull);
    });

    test('사진: photo.image → assets/photos/<icon>', () {
      expect(
        SceneImages.forPhoto(const Photo(icon: 'night'), registry: registry),
        'assets/photos/night.webp',
      );
      expect(
        SceneImages.forPhoto(
          const Photo(
            icon: 'night',
            image: 'assets/photos/mo_seoyeon_photo_night_0.webp',
          ),
          registry: registry,
        ),
        'assets/photos/mo_seoyeon_photo_night_0.webp',
      );
      expect(
        SceneImages.forPhoto(const Photo(icon: 'sea'), registry: registry),
        isNull,
      );
      expect(SceneImages.forPhoto(null, registry: registry), isNull);
    });

    test('엔딩: 엔딩 id → 캐릭터 id → common_<tier>', () {
      Ending e(String id, {String? character, String tier = 'good'}) =>
          Ending(id: id, name: '엔딩', tier: tier, character: character);
      expect(
        SceneImages.forEnding(e('ending_one'), registry: registry),
        'assets/endings/ending_one.webp',
      );
      expect(
        SceneImages.forEnding(
          e('seoyeon_happy', character: 'seoyeon'),
          registry: registry,
        ),
        'assets/endings/seoyeon.webp',
      );
      expect(
        SceneImages.forEnding(e('forever_solo', tier: 'bad'), registry: registry),
        'assets/endings/common_bad.webp',
      );
      expect(
        SceneImages.forEnding(e('그냥굿', tier: 'good'), registry: registry),
        isNull,
      );
      expect(SceneImages.commonEndingKey('solo'), 'common_solo');
      expect(SceneImages.commonEndingKey('happy'), isNull);
    });

    test('스티커: 화이트리스트를 통과한 이름만 찾는다', () {
      expect(
        SceneImages.forSticker('seoyeon_joy', registry: registry),
        'assets/stickers/seoyeon_joy.webp',
      );
      expect(SceneImages.forSticker('seoyeon_sulk', registry: registry), isNull);
      expect(SceneImages.forSticker('seoyeon_angry', registry: registry), isNull);
      expect(SceneImages.forSticker(null, registry: registry), isNull);
    });

    test('그림이 없으면 전부 null — 화면은 지금과 같다', () {
      const none = SceneRegistry.empty;
      expect(SceneImages.forEvent(event('m01'), registry: none), isNull);
      expect(
        SceneImages.forPhoto(const Photo(icon: 'night'), registry: none),
        isNull,
      );
      expect(SceneImages.forSticker('seoyeon_joy', registry: none), isNull);
      expect(
        SceneImages.forEnding(
          const Ending(id: 'x', name: '엔딩', tier: 'bad'),
          registry: none,
        ),
        isNull,
      );
    });
  });
}
