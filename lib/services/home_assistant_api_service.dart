import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:ha_flutter_dashboard/models/entity_state.dart';
import 'package:ha_flutter_dashboard/models/home_assistant_instance.dart';
import 'package:ha_flutter_dashboard/utils/debug_logger.dart';
import 'package:ha_flutter_dashboard/config/constants.dart';
import 'package:ha_flutter_dashboard/services/storage_service.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:web_socket_channel/status.dart' as status;
import 'package:fluttertoast/fluttertoast.dart';

class HomeAssistantApiService {
  final Dio _dio = Dio();
  final HomeAssistantInstance _instance;
  final String _token;
  final StorageService _storageService;

  WebSocketChannel? _wsChannel;
  StreamController<EntityState>? _stateUpdateController;
  StreamController<void>? _reconnectController = StreamController<void>.broadcast();

  // Reconnection and connection monitoring
  Timer? _reconnectTimer;
  Timer? _messageTimeoutTimer;
  DateTime? _lastMessageTime;
  bool _isReconnecting = false;
  bool _connectionActive = false;

  int _wsMessageId = 2; // 1 is used for subscribe_events
  int? _pendingGetStatesId;

  HomeAssistantApiService({
    required HomeAssistantInstance instance,
    required String token,
    required StorageService storageService,
  }) : _instance = instance,
         _token = token,
         _storageService = storageService {
    _initDio();
    _stateUpdateController = StreamController<EntityState>.broadcast();
  }

  void _initDio() {
    _dio.options.baseUrl = _instance.url;
    _dio.options.headers = {
      'Authorization': 'Bearer $_token',
      'Content-Type': 'application/json',
    };
  }

  Future<void> initializeRealTimeUpdates() async {
    // Close previous connection if any
    await disposeRealTimeUpdates();

    // Reset connection state
    _isReconnecting = false;
    _connectionActive = false;

    await _connectToWebSocket();
  }

  Future<void> _connectToWebSocket() async {
    final wsUrl = _instance.url.replaceFirst('http', 'ws') + "/api/websocket";
    debugPrint('HA_WS: Connecting to WebSocket at $wsUrl');
    DebugLogger.log('Connecting to WebSocket at $wsUrl');

    try {
      // Cancel any existing reconnect timer
      _reconnectTimer?.cancel();
      _reconnectTimer = null;

      _wsChannel = WebSocketChannel.connect(Uri.parse(wsUrl));
      // DO NOT recreate _stateUpdateController here!

      // Authenticate
      debugPrint('HA_WS: Sending authentication request');
      DebugLogger.log('Sending authentication request');
      _wsChannel!.sink.add('{"type": "auth", "access_token": "$_token"}');
      bool authenticated = false;

      // Update last message time and start timeout timer
      _lastMessageTime = DateTime.now();
      _startMessageTimeoutTimer();

      _wsChannel!.stream.listen(
        (message) {
          // Update last message time on any message
          _lastMessageTime = DateTime.now();
          _connectionActive = true;

          try {
            final data = jsonDecode(message);
            if (!authenticated && data['type'] == 'auth_ok') {
              debugPrint('HA_WS: Authentication successful, subscribing to state changes');
              DebugLogger.log('Authentication successful, subscribing to state changes');
              authenticated = true;
              // Subscribe to all state changes
              _wsChannel!.sink.add('{"id": 1, "type": "subscribe_events", "event_type": "state_changed"}');

              // If we were reconnecting, show a toast
              if (_isReconnecting) {
                Fluttertoast.showToast(
                  msg: "Reconnected to Home Assistant",
                  toastLength: Toast.LENGTH_SHORT,
                  gravity: ToastGravity.BOTTOM,
                  backgroundColor: Colors.green,
                  textColor: Colors.white,
                );
                _isReconnecting = false;
                // Notify listeners about reconnect
                _reconnectController?.add(null);
                // Request all entity states via WebSocket
                _pendingGetStatesId = _wsMessageId++;
                final getStatesMsg = jsonEncode({
                  'id': _pendingGetStatesId,
                  'type': 'get_states',
                });
                _wsChannel!.sink.add(getStatesMsg);
                debugPrint('HA_WS: Sent get_states command with id \\$_pendingGetStatesId');
                DebugLogger.log('Sent get_states command with id \\$_pendingGetStatesId');
              }
            } else if (authenticated && data['type'] == 'event' && data['event'] != null && data['event']['data'] != null) {
              final eventData = data['event']['data'];

              if (eventData['new_state'] != null && eventData['new_state'] is Map<String, dynamic>) {
                try {
                  final entityState = EntityState.fromJson(eventData['new_state']);
                  _stateUpdateController?.add(entityState);
                } catch (e) {
                  debugPrint('HA_WS: Error parsing entity state: $e');
                  DebugLogger.log('Error parsing entity state: $e');
                  debugPrint('HA_WS: Raw new_state data: \\${eventData['new_state']}');
                  DebugLogger.log('Raw new_state data: \\${eventData['new_state']}');
                }
              } else if (eventData['new_state'] != null) {
                debugPrint('HA_WS: Ignoring new_state that is not a Map: \\${eventData['new_state']}');
                DebugLogger.log('Ignoring new_state that is not a Map: \\${eventData['new_state']}');
              }
            } else if (authenticated && data['type'] == 'result' && data['id'] == _pendingGetStatesId && data['success'] == true && data['result'] is List) {
              // Handle get_states result
              final List<dynamic> states = data['result'];
              debugPrint('HA_WS: Received get_states result with \\${states.length} entities');
              DebugLogger.log('Received get_states result with \\${states.length} entities');
              for (final item in states) {
                try {
                  final entityState = EntityState.fromJson(item);
                  _stateUpdateController?.add(entityState);
                } catch (e) {
                  debugPrint('HA_WS: Error parsing entity state from get_states: $e');
                  DebugLogger.log('Error parsing entity state from get_states: $e');
                }
              }
              _pendingGetStatesId = null;
            }
          } catch (e) {
            debugPrint('HA_WS: Error processing WebSocket message: $e');
            DebugLogger.log('Error processing WebSocket message: $e');
          }
        },
        onError: (e) {
          debugPrint('HA_WS: WebSocket error: $e');
          DebugLogger.log('WebSocket error: $e');
          _handleConnectionFailure('WebSocket error occurred');
        },
        onDone: () {
          debugPrint('HA_WS: WebSocket connection closed');
          DebugLogger.log('WebSocket connection closed');
          _handleConnectionFailure('WebSocket connection closed');
        },
      );
    } catch (e) {
      debugPrint('HA_WS: Failed to connect to WebSocket: $e');
      DebugLogger.log('Failed to connect to WebSocket: $e');
      _handleConnectionFailure('Failed to connect to WebSocket');
    }
  }

  void _handleConnectionFailure(String message) {
    _connectionActive = false;
    _messageTimeoutTimer?.cancel();

    if (!_isReconnecting) {
      _isReconnecting = true;
      Fluttertoast.showToast(
        msg: "Connection to Home Assistant lost. Reconnecting...",
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.BOTTOM,
        backgroundColor: Colors.orange,
        textColor: Colors.white,
      );
      
      // Log the disconnection
      debugPrint('HA_WS: Connection failure: $message');
      DebugLogger.log('Connection failure: $message');
    }

    // Start reconnection timer if not already running
    _reconnectTimer ??= Timer(
      Duration(milliseconds: _storageService.getWebsocketMessageTimeout() ~/ 2), // Use half the message timeout as reconnection delay
      () {
        _reconnectTimer = null;
        if (!_connectionActive) {
          _connectToWebSocket();
        }
      },
    );
  }

  void _startMessageTimeoutTimer() {
    _messageTimeoutTimer?.cancel();

    final timeout = _storageService.getWebsocketMessageTimeout();
    _messageTimeoutTimer = Timer.periodic(
      Duration(milliseconds: timeout ~/ 2), // Check twice as often as the timeout
      (timer) {
        if (_lastMessageTime != null) {
          final now = DateTime.now();
          final diff = now.difference(_lastMessageTime!).inMilliseconds;

          if (diff > timeout) {
            debugPrint('HA_WS: Message timeout reached ($timeout ms)');
            DebugLogger.log('Message timeout reached ($timeout ms)');

            // Force reconnection
            _handleConnectionFailure('Message timeout reached');

            // Close current connection
            _wsChannel?.sink.close(1000); // Use 1000 (normal closure) instead of status.goingAway
            _wsChannel = null;

            // Try to reconnect immediately
            _connectToWebSocket();
          }
        }
      },
    );
  }

  // Provide access to the state update stream
  Stream<EntityState>? get stateUpdateStream => _stateUpdateController?.stream;
  Stream<void>? get reconnectStream => _reconnectController?.stream;

  Future<void> disposeRealTimeUpdates() async {
    // Cancel timers
    _reconnectTimer?.cancel();
    _reconnectTimer = null;

    _messageTimeoutTimer?.cancel();
    _messageTimeoutTimer = null;

    // Close connections
    await _wsChannel?.sink.close(1000); // Use 1000 (normal closure) instead of status.goingAway
    await _reconnectController?.close();

    _wsChannel = null;
    // DO NOT close _stateUpdateController here unless shutting down the app
    _reconnectController = null;
    _connectionActive = false;
  }

  // Get all entity states
  Future<List<EntityState>> getStates() async {
    try {
      final response = await _dio.get('/api/states');

      if (response.statusCode == 200) {
        final List<dynamic> data = response.data;
        return data.map((item) => EntityState.fromJson(item)).toList();
      } else {
        throw Exception('Failed to get states: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Failed to get states: $e');
    }
  }

  // Get entities grouped by domain
  Future<Map<String, List<EntityState>>> getEntitiesByDomain() async {
    try {
      final List<EntityState> allStates = await getStates();

      // Group entities by domain
      final Map<String, List<EntityState>> entitiesByDomain = {};

      for (final entity in allStates) {
        final domain = entity.entityId.split('.').first;
        if (!entitiesByDomain.containsKey(domain)) {
          entitiesByDomain[domain] = [];
        }
        entitiesByDomain[domain]!.add(entity);
      }

      return entitiesByDomain;
    } catch (e) {
      throw Exception('Failed to get entities by domain: $e');
    }
  }

  // Get a specific entity state
  Future<EntityState> getState(String entityId) async {
    try {
      final response = await _dio.get('/api/states/$entityId');

      if (response.statusCode == 200) {
        return EntityState.fromJson(response.data);
      } else {
        throw Exception('Failed to get state: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Failed to get state: $e');
    }
  }

  // Call a service
  Future<void> callService(String domain, String service, Map<String, dynamic> data) async {
    try {
      final response = await _dio.post(
        '/api/services/$domain/$service',
        data: jsonEncode(data),
      );

      if (response.statusCode != 200 && response.statusCode != 201) {
        throw Exception('Failed to call service: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Failed to call service: $e');
    }
  }

  // Turn on/off a light
  Future<void> turnOnLight(String entityId, {double? brightness}) async {
    final data = {'entity_id': entityId};

    if (brightness != null) {
      data['brightness'] = brightness.toInt().toString();
    }

    await callService('light', 'turn_on', data);
  }

  Future<void> turnOffLight(String entityId) async {
    await callService('light', 'turn_off', {'entity_id': entityId});
  }

  // Toggle a switch
  Future<void> toggleSwitch(String entityId) async {
    await callService('switch', 'toggle', {'entity_id': entityId});
  }

  // Control blinds
  Future<void> openBlind(String entityId) async {
    await callService('cover', 'open_cover', {'entity_id': entityId});
  }

  Future<void> closeBlind(String entityId) async {
    await callService('cover', 'close_cover', {'entity_id': entityId});
  }

  Future<void> stopBlind(String entityId) async {
    await callService('cover', 'stop_cover', {'entity_id': entityId});
  }

  Future<void> setBlindPosition(String entityId, int position) async {
    await callService('cover', 'set_cover_position', {
      'entity_id': entityId,
      'position': position,
    });
  }

  // Control locks
  Future<void> unlockLock(String entityId) async {
    await callService('lock', 'unlock', {'entity_id': entityId});
  }

  Future<void> lockLock(String entityId) async {
    await callService('lock', 'lock', {'entity_id': entityId});
  }

  Future<void> openLock(String entityId) async {
    await callService('lock', 'open', {'entity_id': entityId});
  }

  // Control climate
  Future<void> setClimateTemperature(String entityId, double temperature) async {
    await callService('climate', 'set_temperature', {
      'entity_id': entityId,
      'temperature': temperature,
    });
  }

  Future<void> turnOnClimate(String entityId) async {
    await callService('climate', 'turn_on', {'entity_id': entityId});
  }

  Future<void> turnOffClimate(String entityId) async {
    await callService('climate', 'turn_off', {'entity_id': entityId});
  }
}
