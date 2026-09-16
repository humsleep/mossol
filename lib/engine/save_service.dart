import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'models.dart';

/// 세이브 저장소. SharedPreferences 에 JSON 한 덩어리로 저장한다.
class SaveService {
  static const _key = 'mossol_save_v1';
  static const _endingsKey = 'mossol_endings_v1';

  Future<void> save(GameState s) async {
    final p = await SharedPreferences.getInstance();
    await p.setString(_key, jsonEncode(s.toJson()));
  }

  Future<GameState?> load() async {
    final p = await SharedPreferences.getInstance();
    final raw = p.getString(_key);
    if (raw == null) return null;
    try {
      return GameState.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      await p.remove(_key);
      return null;
    }
  }

  Future<bool> exists() async =>
      (await SharedPreferences.getInstance()).containsKey(_key);

  Future<void> clear() async =>
      (await SharedPreferences.getInstance()).remove(_key);

  /// 회차를 넘어 유지되는 엔딩 앨범.
  Future<List<String>> loadEndings() async =>
      (await SharedPreferences.getInstance()).getStringList(_endingsKey) ?? [];

  Future<void> addEnding(String id) async {
    final p = await SharedPreferences.getInstance();
    final list = p.getStringList(_endingsKey) ?? [];
    if (!list.contains(id)) {
      list.add(id);
      await p.setStringList(_endingsKey, list);
    }
  }
}
