import 'package:shared_preferences/shared_preferences.dart';
import '../../features/radar/models/available_order.dart';

class OrderFilterService {
  static final OrderFilterService _instance = OrderFilterService._internal();
  factory OrderFilterService() => _instance;
  OrderFilterService._internal();

  final Set<String> _rejectedOrderIds = {};
  bool _loaded = false;

  Future<void> load() async {
    if (_loaded) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = prefs.getStringList("rejected_orders_v1") ?? [];
      _rejectedOrderIds.addAll(list);
      _loaded = true;
    } catch (_) {}
  }

  Future<void> reject(String orderId) async {
    _rejectedOrderIds.add(orderId);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList("rejected_orders_v1", _rejectedOrderIds.toList());
    } catch (_) {}
  }

  bool isRejected(String orderId) => _rejectedOrderIds.contains(orderId);

  List<AvailableOrder> filter(List<AvailableOrder> orders) {
    if (_rejectedOrderIds.isEmpty) return orders;
    return orders.where((ord) => !_rejectedOrderIds.contains(ord.id)).toList();
  }
}
