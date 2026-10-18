import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/services.dart';

class AudioAlertService {

  static Future<void> triggerNewOrderAlert() async {
    try {
      // 1. Tactile Haptic Vibration Pulses
      HapticFeedback.heavyImpact();
      await Future.delayed(const Duration(milliseconds: 150));
      HapticFeedback.heavyImpact();

      // 2. Audible Alert
      // Plays system alert or embedded chime
      SystemSound.play(SystemSoundType.alert);
    } catch (_) {
      // Fallback
      HapticFeedback.vibrate();
    }
  }

  static Future<void> triggerSuccessFeedback() async {
    HapticFeedback.mediumImpact();
  }
}
