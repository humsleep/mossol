// 미니게임 등장 순번이 **앱을 껐다 켜도 남는지**.
//
// 왜 중요한가: 하트 경제가 한 세션을 10분쯤으로 끊으므로 거의 모든 세션이
// 콜드 스타트다. 순번이 메모리에만 있으면 `variation.dart` 가 만드는 판별
// 변주를 플레이어가 평생 한 번도 못 본다 — 매번 round 0 의 기준 판만 만난다.
import 'package:flutter_test/flutter_test.dart';
import 'package:mossol/engine/meta_service.dart';
import 'package:mossol/minigames/variation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 메모리 저장소. 실제 `SharedPreferences` 대신 끼워 순번만 본다.
class _FakeStore extends MetaService {
  Map<String, int> data = {};
  int saves = 0;

  @override
  Future<Map<String, int>> loadMinigameRounds() async => Map.of(data);

  @override
  Future<void> saveMinigameRounds(Map<String, int> rounds) async {
    saves++;
    data = Map.of(rounds);
  }
}

void main() {
  late _FakeStore store;

  setUp(() {
    store = _FakeStore();
    MinigameRotation.store = store;
    MinigameRotation.resetForLoad();
  });

  tearDown(() {
    MinigameRotation.store = MetaService();
    MinigameRotation.reset();
  });

  test('센 순번이 저장소에 적힌다', () async {
    await MinigameRotation.ready();
    expect(MinigameRotation.next('7:1:nerve_gauge'), 0);
    expect(MinigameRotation.next('7:1:nerve_gauge'), 1);
    // 저장은 기다리지 않으므로 마이크로태스크를 한 번 돌린다.
    await Future<void>.delayed(Duration.zero);
    expect(store.data['7:1:nerve_gauge'], 1);
  });

  test('앱을 껐다 켜도 이어 센다 — 기준 판으로 되돌아가지 않는다', () async {
    await MinigameRotation.ready();
    MinigameRotation.next('7:1:reply_timing'); // 0
    MinigameRotation.next('7:1:reply_timing'); // 1
    await Future<void>.delayed(Duration.zero);

    // === 앱 재시작 ===
    MinigameRotation.resetForLoad();
    await MinigameRotation.ready();
    expect(
      MinigameRotation.next('7:1:reply_timing'),
      2,
      reason: '콜드 스타트마다 0 으로 돌아가면 변주가 영원히 안 보인다',
    );
  });

  test('회차가 바뀌면 지난 회차 기록은 버린다 (무한히 자라지 않는다)', () async {
    await MinigameRotation.ready();
    MinigameRotation.next('7:1:outfit');
    MinigameRotation.next('7:1:outfit');
    // 새 게임: 씨앗·회차가 바뀐다.
    expect(MinigameRotation.next('9:2:outfit'), 0, reason: '새 회차의 첫 판은 기준 판');
    await Future<void>.delayed(Duration.zero);
    expect(store.data.keys, ['9:2:outfit']);
  });

  test('저장된 기록이 없으면(예전 기기) 0 부터 센다', () async {
    store.data = {};
    await MinigameRotation.ready();
    expect(MinigameRotation.next('7:1:group_chat'), 0);
  });

  test('저장된 값이 메모리보다 크면 저장된 값을 쓴다 (뒤로 감기지 않는다)', () async {
    store.data = {'7:1:pick_meme': 5};
    // 읽기가 도착하기 전에 한 판이 시작된 경우.
    MinigameRotation.next('7:1:pick_meme'); // 0
    await MinigameRotation.ready();
    expect(MinigameRotation.next('7:1:pick_meme'), 6);
  });

  test('reset 은 저장된 값을 되살리지 않는다 (테스트 격리)', () async {
    store.data = {'7:1:x': 9};
    MinigameRotation.reset();
    expect(MinigameRotation.next('7:1:x'), 0);
  });

  group('MetaService 저장 형식', () {
    test('순번은 PlayerMeta 와 다른 키에 적힌다 — 메타 JSON 은 그대로다', () async {
      SharedPreferences.setMockInitialValues({});
      final m = MetaService();
      await m.saveMinigameRounds({'7:1:outfit': 3});
      final p = await SharedPreferences.getInstance();
      expect(p.getString('mossol_minigame_rounds_v1'), isNotNull);
      expect(p.getString('mossol_meta_v1'), isNull, reason: '메타를 건드리지 않는다');
      expect(await m.loadMinigameRounds(), {'7:1:outfit': 3});
    });

    test('이 키가 없던 예전 세이브는 빈 map 으로 읽힌다', () async {
      SharedPreferences.setMockInitialValues({
        'mossol_meta_v1': '{"totalRuns":3,"streakDays":2}',
      });
      final m = MetaService();
      expect(await m.loadMinigameRounds(), isEmpty);
      // 예전 메타는 그대로 읽힌다.
      final meta = await m.load();
      expect(meta.totalRuns, 3);
      expect(meta.streakDays, 2);
    });

    test('깨진 값은 빈 map 이다 (앱이 죽지 않는다)', () async {
      SharedPreferences.setMockInitialValues({
        'mossol_minigame_rounds_v1': '[1,2,3]',
      });
      expect(await MetaService().loadMinigameRounds(), isEmpty);
    });

    test('저장 데이터 초기화는 순번까지 지운다', () async {
      SharedPreferences.setMockInitialValues({});
      final m = MetaService();
      await m.save(PlayerMeta(totalRuns: 1));
      await m.saveMinigameRounds({'7:1:outfit': 3});
      await m.clear();
      final p = await SharedPreferences.getInstance();
      expect(p.getString('mossol_meta_v1'), isNull);
      expect(p.getString('mossol_minigame_rounds_v1'), isNull);
    });
  });
}
