// ConnectivityProvider - ตัวจัดการสถานะการเชื่อมต่ออินเทอร์เน็ต (Network Connectivity State Management)
//
// ติดตามและแจ้งเตือนสถานะการเชื่อมต่อเครือข่าย (Online/Offline) แบบ Realtime
// เพื่อให้แอปพลิเคชันตอบสนองได้อย่างถูกต้องเมื่อสัญญาณอินเทอร์เน็ตขาดหาย
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

class ConnectivityProvider with ChangeNotifier {
  final Connectivity _connectivity = Connectivity();
  late StreamSubscription<List<ConnectivityResult>> _connectivitySubscription;
  bool _isOffline = false;

  bool get isOffline => _isOffline;

  ConnectivityProvider() {
    _initConnectivity();
    _connectivitySubscription = _connectivity.onConnectivityChanged.listen(
      _updateConnectionStatus,
    );
  }

  Future<void> _initConnectivity() async {
    late List<ConnectivityResult> result;
    try {
      result = await _connectivity.checkConnectivity();
    } catch (e) {
      debugPrint('Couldn\'t check connectivity status: $e');
      return;
    }
    _updateConnectionStatus(result);
  }

  void _updateConnectionStatus(List<ConnectivityResult> result) {
    bool wasOffline = _isOffline;
    if (result.contains(ConnectivityResult.none)) {
      _isOffline = true;
    } else {
      _isOffline = false;
    }
    if (wasOffline != _isOffline) {
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _connectivitySubscription.cancel();
    super.dispose();
  }
}
