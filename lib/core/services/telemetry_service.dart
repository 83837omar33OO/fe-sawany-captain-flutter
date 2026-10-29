import 'dart:async';
import 'package:battery_plus/battery_plus.dart';
import '../network/api_client.dart';
import '../network/api_endpoints.dart';
import '../storage/secure_storage_service.dart';
import 'location_service.dart';

typedef SuspensionCallback = void Function(bool isSuspended, String? message);

class TelemetryService {
  static final TelemetryService _instance = TelemetryService._internal();
  factory TelemetryService() => _instance;
  TelemetryService._internal();

  final Battery _battery = Battery();
  Timer? _telemetryTimer;
  bool _isStreaming = false;
  SuspensionCallback? _onSuspensionStatusChanged;

  void setSuspensionListener(SuspensionCallback listener) {
    _onSuspensionStatusChanged = listener;
  }

  void startStreaming({Duration interval = const Duration(seconds: 15)}) {
    if (_isStreaming) return;
    _isStreaming = true;

    // Immediately trigger first ping
    sendTelemetry();

    // Setup periodic ping
    _telemetryTimer?.cancel();
    _telemetryTimer = Timer.periodic(interval, (_) {
      sendTelemetry();
    });
  }

  void stopStreaming() {
    _isStreaming = false;
    _telemetryTimer?.cancel();
    _telemetryTimer = null;
  }

  Future<void> sendTelemetry({
    String? activeOrderId,
    String status = "available",
  }) async {
    try {
      final profile = await SecureStorageService.getRiderProfile();
      final riderId = profile["id"];
      if (riderId == null || riderId.isEmpty) return;

      int batteryLevel = 90;
      bool isCharging = false;
      try {
        batteryLevel = await _battery.batteryLevel;
        final state = await _battery.batteryState;
        isCharging = state == BatteryState.charging || state == BatteryState.full;
      } catch (_) {
        // Battery read fallback for desktop/testing
      }

      final position = await LocationService.getCurrentPosition();

      final payload = <String, dynamic>{
        "riderId": riderId,
        "battery": batteryLevel,
        "isCharging": isCharging,
        "status": status,
        if (activeOrderId != null) "activeOrderId": activeOrderId,
        if (position != null) ...{
          "lat": position.latitude,
          "lng": position.longitude,
          "speed": position.speed,
        },
      };

      final response = await ApiClient.post(ApiEndpoints.telemetry, payload);

      if (response["isSuspended"] == true) {
        _onSuspensionStatusChanged?.call(true, response["error"]);
      }
    } catch (e) {
      if (e is ApiException && e.code == "ACCOUNT_SUSPENDED") {
        _onSuspensionStatusChanged?.call(true, e.message);
      }
    }
  }
}
