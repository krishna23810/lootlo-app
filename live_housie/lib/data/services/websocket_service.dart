import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import '../../core/constants/app_constants.dart';

/// Lightweight, zero-dependency Socket.io client using native WebSockets.
/// Supports connection, namespaces, events, pings/pongs, and auto-reconnection.
class WebSocketService {
  final String serverUrl;
  WebSocket? _ws;
  bool _isConnected = false;
  bool _isDisposed = false;
  Timer? _reconnectTimer;

  // Listeners map: event -> list of callbacks
  final Map<String, List<Function(dynamic)>> _listeners = {};

  WebSocketService({String? url}) : serverUrl = url ?? AppConstants.wsUrl;

  bool get isConnected => _isConnected;

  /// Register callback for socket events (like 'connect', 'game:draw_number', etc.)
  void on(String event, Function(dynamic data) callback) {
    _listeners.putIfAbsent(event, () => []).add(callback);
  }

  /// Remove callback for socket events
  void off(String event) {
    _listeners.remove(event);
  }

  /// Connect to the Socket.io server
  Future<void> connect() async {
    if (_isConnected) return;
    _isDisposed = false;

    // Socket.io path format: wss://api.yourdomain.com/socket.io/?EIO=4&transport=websocket
    final baseWsUrl = serverUrl
        .replaceAll('https://', 'wss://')
        .replaceAll('http://', 'ws://');
    final fullWsUrl = '$baseWsUrl/socket.io/?EIO=4&transport=websocket';

    debugPrint('[WebSocketService] Connecting to: $fullWsUrl');
    
    try {
      _ws = await WebSocket.connect(fullWsUrl).timeout(const Duration(seconds: 10));
      _ws!.listen(
        _onMessage,
        onError: _onError,
        onDone: _onDisconnected,
        cancelOnError: true,
      );

      // Establish Socket.io connection on root namespace
      debugPrint('[WebSocketService] WebSocket connected, sending Socket.io namespace connect (40)...');
      _ws!.add('40');
    } catch (e) {
      debugPrint('[WebSocketService] Connection error: $e');
      _trigger('error', e);
      _scheduleReconnect();
    }
  }

  /// Emit an event with dynamic data
  void emit(String event, dynamic data) {
    if (_ws == null || !_isConnected) {
      debugPrint('[WebSocketService] Cannot emit, not connected');
      return;
    }
    // Socket.io event frame format: 42["event_name", data]
    final payload = '42${jsonEncode([event, data])}';
    _ws!.add(payload);
  }

  /// Disconnect socket cleanly
  void disconnect() {
    _isDisposed = true;
    _reconnectTimer?.cancel();
    _ws?.close();
    _ws = null;
    _isConnected = false;
    debugPrint('[WebSocketService] Disconnected cleanly');
  }

  void _onMessage(dynamic message) {
    if (message is! String) return;

    // 1. Engine.io Ping Request (2) -> Pong Response (3)
    if (message == '2') {
      _ws?.add('3');
      return;
    }

    // 2. Socket.io Namespace Connect (40)
    if (message.startsWith('40')) {
      _isConnected = true;
      debugPrint('[WebSocketService] Socket.io namespace connected');
      _trigger('connect', null);
      return;
    }

    // 3. Socket.io Event Packet (42)
    if (message.startsWith('42')) {
      try {
        final parsed = jsonDecode(message.substring(2)) as List<dynamic>;
        if (parsed.length >= 2) {
          final event = parsed[0] as String;
          final data = parsed[1];
          _trigger(event, data);
        }
      } catch (e) {
        debugPrint('[WebSocketService] Failed to parse event body: $message (Err: $e)');
      }
    }
  }

  void _onError(dynamic err) {
    debugPrint('[WebSocketService] Socket error: $err');
    _trigger('error', err);
    _onDisconnected();
  }

  void _onDisconnected() {
    _isConnected = false;
    _ws = null;
    _trigger('disconnect', null);
    _scheduleReconnect();
  }

  void _scheduleReconnect() {
    if (_isDisposed) return;
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(const Duration(seconds: 5), () {
      if (!_isConnected && !_isDisposed) {
        debugPrint('[WebSocketService] Attempting auto-reconnection...');
        connect();
      }
    });
  }

  void _trigger(String event, dynamic data) {
    final list = _listeners[event];
    if (list != null) {
      // Create a copy of the list to avoid ConcurrentModificationError if handlers modify listeners list
      final handlers = List<Function(dynamic)>.from(list);
      for (var handler in handlers) {
        try {
          handler(data);
        } catch (e) {
          debugPrint('[WebSocketService] Error executing listener for event $event: $e');
        }
      }
    }
  }
}
