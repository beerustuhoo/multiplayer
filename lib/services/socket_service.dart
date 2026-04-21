import 'dart:async';
import 'dart:convert';
import 'dart:io';
import '../config/constants.dart';

typedef MessageCallback = void Function(dynamic data);

class SocketService {
  WebSocket? _socket;
  bool _isConnected = false;
  bool _shouldReconnect = false;
  String? _token;
  Timer? _reconnectTimer;
  int _reconnectAttempts = 0;

  final Map<String, List<MessageCallback>> _listeners = {};
  final List<void Function(bool)> _connectionListeners = [];

  bool get isConnected => _isConnected;

  Future<void> connect(String token) async {
    _token = token;
    _shouldReconnect = true;
    _reconnectAttempts = 0;
    await _doConnect();
  }

  Future<void> _doConnect() async {
    try {
      _socket = await WebSocket.connect(AppConstants.wsUrl);
      _isConnected = true;
      _reconnectAttempts = 0;
      _notifyConnectionListeners(true);

      // Authenticate immediately
      emit('authenticate', {'token': _token});

      _socket!.listen(
        (data) {
          try {
            final msg = jsonDecode(data as String) as Map<String, dynamic>;
            final type = msg['type'] as String;
            final payload = msg['data'];
            _notifyListeners(type, payload);
          } catch (e) {
            // Ignore malformed messages
          }
        },
        onDone: () {
          _isConnected = false;
          _notifyConnectionListeners(false);
          _tryReconnect();
        },
        onError: (_) {
          _isConnected = false;
          _notifyConnectionListeners(false);
          _tryReconnect();
        },
      );
    } catch (e) {
      _isConnected = false;
      _notifyConnectionListeners(false);
      _tryReconnect();
    }
  }

  void _tryReconnect() {
    if (!_shouldReconnect || _reconnectAttempts > 10) return;
    _reconnectTimer?.cancel();
    final delay = Duration(seconds: (_reconnectAttempts + 1).clamp(1, 10));
    _reconnectAttempts++;
    _reconnectTimer = Timer(delay, _doConnect);
  }

  void disconnect() {
    _shouldReconnect = false;
    _reconnectTimer?.cancel();
    _socket?.close();
    _socket = null;
    _isConnected = false;
    _notifyConnectionListeners(false);
  }

  void emit(String type, [Map<String, dynamic>? data]) {
    if (_socket == null) return;
    try {
      _socket!.add(jsonEncode({'type': type, 'data': data ?? {}}));
    } catch (_) {}
  }

  void on(String event, MessageCallback callback) {
    _listeners.putIfAbsent(event, () => []).add(callback);
  }

  void off(String event, [MessageCallback? callback]) {
    if (callback != null) {
      _listeners[event]?.remove(callback);
    } else {
      _listeners.remove(event);
    }
  }

  void addConnectionListener(void Function(bool) listener) {
    _connectionListeners.add(listener);
  }

  void removeConnectionListener(void Function(bool) listener) {
    _connectionListeners.remove(listener);
  }

  void _notifyListeners(String event, dynamic data) {
    final handlers = _listeners[event];
    if (handlers != null) {
      for (final h in List.of(handlers)) {
        h(data);
      }
    }
  }

  void _notifyConnectionListeners(bool connected) {
    for (final l in List.of(_connectionListeners)) {
      l(connected);
    }
  }
}
