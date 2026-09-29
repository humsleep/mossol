import 'choice_games.dart';
import 'minigame.dart';
import 'push_games.dart';
import 'tap_games.dart';
import 'timing_games.dart';
import 'variation.dart';

/// 앱 시작 시 한 번 부른다. 이벤트 JSON 의 `"minigame"` 값이 여기 키와 맞아야 한다.
void registerMinigames() {
  // 저장된 등장 순번을 여기서 미리 읽어 둔다(기다리지 않는다).
  // [playMinigame] 은 순번을 **동기로** 세야 하므로 — 버튼을 누른 그 프레임에
  // 라우트가 덮어야 한다 — 읽기를 판정 경로 밖으로 뺀다. 홈·룰렛·행동·이벤트를
  // 지나 첫 미니게임에 닿기까지 몇 초가 걸리니 그 사이에 끝난다.
  MinigameRotation.ready();
  if (minigameRegistry.isNotEmpty) return;
  minigameRegistry.addAll({
    'reply_timing': (ctx, done) => ReplyTimingGame(ctx: ctx, done: done),
    'word_order': (ctx, done) => WordOrderGame(ctx: ctx, done: done),
    'date_course': (ctx, done) => DateCourseGame(ctx: ctx, done: done),
    'read_emotion': (ctx, done) => ReadEmotionGame(ctx: ctx, done: done),
    'pick_meme': (ctx, done) => PickMemeGame(ctx: ctx, done: done),
    'delete_fast': (ctx, done) => DeleteFastGame(ctx: ctx, done: done),
    'nerve_gauge': (ctx, done) => NerveGaugeGame(ctx: ctx, done: done),
    'group_chat': (ctx, done) => GroupChatGame(ctx: ctx, done: done),
    // 선 지키기(드립 한 번 더). id 는 세이브·데이터 호환 때문에 drink_limit 그대로.
    'drink_limit': (ctx, done) => DrinkLimitGame(ctx: ctx, done: done),
    'outfit': (ctx, done) => OutfitGame(ctx: ctx, done: done),
    'profile_swipe': (ctx, done) => ProfileSwipeGame(ctx: ctx, done: done),
    'call_rhythm': (ctx, done) => CallRhythmGame(ctx: ctx, done: done),
  });
}

/// 미니게임 12종의 이름. 데이터 검증과 표시에 쓴다.
const minigameLabels = {
  'reply_timing': '답장 타이밍',
  'word_order': '문장 만들기',
  'date_course': '코스 짜기',
  'read_emotion': '표정 읽기',
  'pick_meme': '짤 고르기',
  'delete_fast': '5초 삭제',
  'nerve_gauge': '결심의 순간',
  'group_chat': '단톡방 대응',
  'drink_limit': '선 지키기',
  'outfit': '옷장 코디',
  'profile_swipe': '프로필 고르기',
  'call_rhythm': '맞장구',
};
