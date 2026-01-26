import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/services.dart';
import 'package:native_camera_sound/native_camera_sound.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final audioServiceProvider = Provider((ref) => AudioService());

class AudioService {
  final AudioPlayer _player = AudioPlayer();

  Future<void> playPock() async {
    try {
      // Use native system click for the mascot for a clean, integrated feel
      await SystemSound.play(SystemSoundType.click);
    } on Object catch (_) {
      // Fail silently
    }
  }

  Future<void> playSwoosh() async {
    try {
      await _player.stop();
      await _player.play(AssetSource('audio/swoosh.mp3'), volume: 0.4);
    } on Object catch (_) {
      // Fail silently if sound asset is missing
    }
  }

  Future<void> playScanLaunch() async {
    try {
      // Use native camera shutter sound for professional feel
      await NativeCameraSound.playShutter();
    } on Object catch (_) {
      // Fail silently if native sound fails
    }
  }

  void dispose() {
    _player.dispose();
  }
}
