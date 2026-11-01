import 'dart:async';
import 'package:battery_plus/battery_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class DutyController extends ChangeNotifier {
  static final DutyController _instance = DutyController._internal();
  factory DutyController() => _instance;
  DutyController._internal();

  final Battery _battery = Battery();
  StreamSubscription<BatteryState>? _batterySubscription;
  Timer? _shiftTimer;
  Timer? _batteryPollTimer;

  bool _isOnline = false;
  DateTime? _shiftStartTime;
  Duration _shiftDuration = Duration.zero;
  int _batteryLevel = 100;
  bool _isCharging = false;
  bool _isInitialized = false;

  bool get isOnline => _isOnline;
  DateTime? get shiftStartTime => _shiftStartTime;
  Duration get shiftDuration => _shiftDuration;
  int get batteryLevel => _batteryLevel;
  bool get isCharging => _isCharging;
  bool get isInitialized => _isInitialized;

  String get formattedShiftDuration {
    if (!_isOnline) return "الوردية مغلقة";
    final hours = _shiftDuration.inHours.toString().padLeft(2, '0');
    final minutes = (_shiftDuration.inMinutes % 60).toString().padLeft(2, '0');
    final seconds = (_shiftDuration.inSeconds % 60).toString().padLeft(2, '0');
    return "$hours:$minutes:$seconds";
  }

  String get formattedBattery => "$_batteryLevel%";

  Future<void> init() async {
    if (_isInitialized) return;
    _isInitialized = true;

    await _readBattery();
    _batterySubscription = _battery.onBatteryStateChanged.listen((state) {
      _isCharging = state == BatteryState.charging || state == BatteryState.full;
      _readBattery();
    });

    _batteryPollTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      _readBattery();
    });

    final prefs = await SharedPreferences.getInstance();
    final savedOnline = prefs.getBool("duty_is_online") ?? false;
    final savedStartMs = prefs.getInt("duty_shift_start_ms");

    _isOnline = savedOnline;
    if (_isOnline) {
      if (savedStartMs != null && savedStartMs > 0) {
        _shiftStartTime = DateTime.fromMillisecondsSinceEpoch(savedStartMs);
      } else {
        _shiftStartTime = DateTime.now();
        await prefs.setInt("duty_shift_start_ms", _shiftStartTime!.millisecondsSinceEpoch);
      }
      _startShiftTimer();
    }
    notifyListeners();
  }

  Future<void> _readBattery() async {
    try {
      final level = await _battery.batteryLevel;
      final state = await _battery.batteryState;
      _batteryLevel = level;
      _isCharging = state == BatteryState.charging || state == BatteryState.full;
      notifyListeners();
    } catch (_) {
      // Fallback for emulators/unsupported
    }
  }

  Future<void> setDutyStatus(bool online) async {
    _isOnline = online;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool("duty_is_online", online);

    if (online) {
      _shiftStartTime = DateTime.now();
      _shiftDuration = Duration.zero;
      await prefs.setInt("duty_shift_start_ms", _shiftStartTime!.millisecondsSinceEpoch);
      _startShiftTimer();
    } else {
      _shiftTimer?.cancel();
      _shiftTimer = null;
      _shiftStartTime = null;
      _shiftDuration = Duration.zero;
      await prefs.remove("duty_shift_start_ms");
    }
    notifyListeners();
  }

  void _startShiftTimer() {
    _shiftTimer?.cancel();
    _updateDuration();
    _shiftTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      _updateDuration();
    });
  }

  void _updateDuration() {
    if (_shiftStartTime != null) {
      _shiftDuration = DateTime.now().difference(_shiftStartTime!);
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _shiftTimer?.cancel();
    _batteryPollTimer?.cancel();
    _batterySubscription?.cancel();
    super.dispose();
  }
}
