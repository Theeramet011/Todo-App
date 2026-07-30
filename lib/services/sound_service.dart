import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

class SoundService {
  SoundService._();

  static final SoundService instance = SoundService._();

  static const _taskCompleteAsset = 'sounds/complete.mp3';
  static const _levelUpAsset = 'sounds/levelup.mp3';
  static const _fastCompletionFailAsset = 'sounds/fail.mp3';
  static const _clickAsset = 'sounds/click.mp3';

  final AudioPlayer _taskCompletePlayer = AudioPlayer(
    playerId: 'task_complete_sound',
  );
  final AudioPlayer _levelUpPlayer = AudioPlayer(playerId: 'level_up_sound');
  final AudioPlayer _fastCompletionFailPlayer = AudioPlayer(
    playerId: 'fast_completion_fail_sound',
  );
  final AudioPlayer _clickPlayer = AudioPlayer(playerId: 'click_sound');
  bool _isConfigured = false;

  Future<void> playTaskCompleteSound({required bool isSoundEnabled}) {
    return _play(
      player: _taskCompletePlayer,
      assetPath: _taskCompleteAsset,
      isSoundEnabled: isSoundEnabled,
    );
  }

  Future<void> playLevelUpSound({required bool isSoundEnabled}) {
    return _play(
      player: _levelUpPlayer,
      assetPath: _levelUpAsset,
      isSoundEnabled: isSoundEnabled,
    );
  }

  Future<void> playFastCompletionFailSound({required bool isSoundEnabled}) {
    return _play(
      player: _fastCompletionFailPlayer,
      assetPath: _fastCompletionFailAsset,
      isSoundEnabled: isSoundEnabled,
    );
  }

  Future<void> playClickSound({required bool isSoundEnabled}) {
    return _play(
      player: _clickPlayer,
      assetPath: _clickAsset,
      isSoundEnabled: isSoundEnabled,
    );
  }

  Future<void> _play({
    required AudioPlayer player,
    required String assetPath,
    required bool isSoundEnabled,
  }) async {
    if (!isSoundEnabled) return;

    try {
      await _configurePlayers();
      await player.stop();
      await player.resume();
    } catch (error) {
      debugPrint('Unable to play sound effect "$assetPath": $error');
    }
  }

  Future<void> _configurePlayers() async {
    if (_isConfigured) return;

    await Future.wait([
      _taskCompletePlayer.setReleaseMode(ReleaseMode.stop),
      _levelUpPlayer.setReleaseMode(ReleaseMode.stop),
      _fastCompletionFailPlayer.setReleaseMode(ReleaseMode.stop),
      _clickPlayer.setReleaseMode(ReleaseMode.stop),
      // พรีโหลดไฟล์เสียงเพื่อลดความหน่วงแทนการใช้ lowLatency
      _taskCompletePlayer.setSource(AssetSource(_taskCompleteAsset)),
      _levelUpPlayer.setSource(AssetSource(_levelUpAsset)),
      _fastCompletionFailPlayer.setSource(
        AssetSource(_fastCompletionFailAsset),
      ),
      _clickPlayer.setSource(AssetSource(_clickAsset)),
    ]);
    _isConfigured = true;
  }
}
