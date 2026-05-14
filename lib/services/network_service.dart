import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';

enum NetworkStatus { wifi, mobile, none }

class NetworkService {
  final Connectivity _connectivity = Connectivity();
  final StreamController<NetworkStatus> _controller =
      StreamController<NetworkStatus>.broadcast();

  Stream<NetworkStatus> get statusStream => _controller.stream;

  NetworkStatus _currentStatus = NetworkStatus.none;
  NetworkStatus get currentStatus => _currentStatus;

  bool get isConnected => _currentStatus != NetworkStatus.none;

  void init() {
    _connectivity.onConnectivityChanged.listen((result) {
      _currentStatus = _parseResult(result);
      if (!_controller.isClosed) {
        _controller.add(_currentStatus);
      }
    });
  }

  Future<NetworkStatus> check() async {
    final result = await _connectivity.checkConnectivity();
    _currentStatus = _parseResult(result);
    return _currentStatus;
  }

  NetworkStatus _parseResult(List<ConnectivityResult> result) {
    if (result.contains(ConnectivityResult.wifi)) return NetworkStatus.wifi;
    if (result.contains(ConnectivityResult.mobile)) {
      return NetworkStatus.mobile;
    }
    if (result.contains(ConnectivityResult.ethernet)) return NetworkStatus.wifi;
    return NetworkStatus.none;
  }

  void dispose() {
    _controller.close();
  }
}