import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:dio/dio.dart';

import '../../core/constants/app_constants.dart';

/// WebRTC service for Janus WebRTC VideoRoom integration.
/// Handles subscriber signaling, ICE negotiation, and remote stream rendering.
class WebRTCService {
  final Dio _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 10),
    headers: {
      'Content-Type': 'application/json',
      'ngrok-skip-browser-warning': 'true',
    },
  ));

  RTCPeerConnection? _peerConnection;
  RTCVideoRenderer? remoteRenderer;
  MediaStream? _remoteStream;
  String? _sessionId;
  String? _handleId;
  bool isConnected = false;

  /// Dynamic Janus HTTP base URL
  String get janusUrl {
    final baseUrl = AppConstants.baseUrl;
    if (baseUrl.contains('ngrok')) {
      // Through tunnel proxy (signaling only — media won't work over ngrok)
      final janusBase = baseUrl.replaceAll('/api', '');
      return '$janusBase/janus';
    }
    // Direct connection — extract host from baseUrl for Janus on port 8088
    final uri = Uri.parse(baseUrl);
    return 'http://${uri.host}:8088/janus';
  }

  /// Calculates deterministic Janus Room ID matching backend getJanusRoomId()
  static int getJanusRoomId(String gameId) {
    int hash = 0;
    for (int i = 0; i < gameId.length; i++) {
      hash = (hash << 5) - hash + gameId.codeUnitAt(i);
      hash = hash.toSigned(32); // Convert to signed 32-bit integer
    }
    return hash.abs() % 100000000;
  }

  /// Helper to generate random alphanumeric transaction strings
  String _randomTx() {
    final rand = Random();
    const chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
    return List.generate(12, (index) => chars[rand.nextInt(chars.length)]).join();
  }

  /// Connect to the Janus VideoRoom as a Subscriber and play host stream
  Future<void> startSubscriber(String gameId, RTCVideoRenderer renderer) async {
    remoteRenderer = renderer;
    final roomId = getJanusRoomId(gameId);
    final url = janusUrl;

    try {
      debugPrint('[WebRTCService] Connecting to Janus at $url for room $roomId...');

      // 1. Create Janus Session
      final sessionRes = await _dio.post(url, data: {
        'janus': 'create',
        'transaction': _randomTx(),
      });
      final sessionData = sessionRes.data;
      if (sessionData == null || sessionData['data'] == null || sessionData['data']['id'] == null) {
        throw Exception('Failed to create Janus session. Response: $sessionData');
      }
      _sessionId = sessionData['data']['id'].toString();
      debugPrint('[WebRTCService] Created Session: $_sessionId');

      // 2. Attach VideoRoom Plugin
      final attachRes = await _dio.post('$url/$_sessionId', data: {
        'janus': 'attach',
        'plugin': 'janus.plugin.videoroom',
        'transaction': _randomTx(),
      });
      final attachData = attachRes.data;
      if (attachData == null || attachData['data'] == null || attachData['data']['id'] == null) {
        throw Exception('Failed to attach VideoRoom plugin. Response: $attachData');
      }
      _handleId = attachData['data']['id'].toString();
      debugPrint('[WebRTCService] Attached Handle: $_handleId');

      // 3. Query participants to discover the active publisher feed ID
      debugPrint('[WebRTCService] Querying participants to discover host feed ID...');
      int? hostFeedId;
      
      for (int i = 0; i < 3; i++) {
        final listRes = await _dio.post('$url/$_sessionId/$_handleId', data: {
          'janus': 'message',
          'transaction': _randomTx(),
          'body': {
            'request': 'listparticipants',
            'room': roomId,
          }
        });
        
        final listData = listRes.data;
        debugPrint('[WebRTCService] Participants response (attempt ${i + 1}): ${jsonEncode(listData)}');
        
        if (listData['janus'] == 'success') {
          final participants = listData['plugindata']?['data']?['participants'];
          if (participants is List) {
            for (var p in participants) {
              if (p['publisher'] == true) {
                hostFeedId = p['id'] as int?;
                break;
              }
            }
          }
        }
        
        if (hostFeedId != null) break;
        await Future.delayed(const Duration(milliseconds: 250));
      }
      
      if (hostFeedId == null) {
        throw Exception('Host live telecast is currently offline (no active publisher feed).');
      }
      
      debugPrint('[WebRTCService] Found active host publisher feed ID: $hostFeedId');

      // 4. Join Room as Subscriber (Listening to discovered host feed ID)
      final joinRes = await _dio.post('$url/$_sessionId/$_handleId', data: {
        'janus': 'message',
        'transaction': _randomTx(),
        'body': {
          'request': 'join',
          'room': roomId,
          'ptype': 'subscriber',
          'feed': hostFeedId,
        }
      });

      final resData = joinRes.data;
      debugPrint('[WebRTCService] Join room response: ${jsonEncode(resData)}');

      // 3b. Long-poll to retrieve the JSEP Offer from the session queue
      debugPrint('[WebRTCService] Long-polling to retrieve JSEP Offer...');
      Map<String, dynamic>? eventData;
      
      for (int i = 0; i < 15; i++) {
        try {
          final pollRes = await _dio.get('$url/$_sessionId', queryParameters: {
            'rid': DateTime.now().millisecondsSinceEpoch,
          });
          
          final data = pollRes.data;
          debugPrint('[WebRTCService] Long-poll attempt ${i + 1} response: ${jsonEncode(data)}');
          
          if (data is Map<String, dynamic>) {
            if (data['janus'] == 'event' && data['jsep'] != null) {
              eventData = data;
              break;
            } else if (data['janus'] == 'event' && data['plugindata']?['data']?['error'] != null) {
              final pluginErr = data['plugindata']['data']['error'];
              throw Exception('Janus plugin error: $pluginErr');
            }
          }
        } catch (pollErr) {
          debugPrint('[WebRTCService] Poll error during attempt ${i + 1}: $pollErr');
          if (pollErr.toString().contains('Janus plugin error')) {
            rethrow;
          }
        }
        
        // Always wait between poll attempts if we haven't found the JSEP offer yet
        await Future.delayed(const Duration(milliseconds: 200));
      }

      if (eventData == null || eventData['jsep'] == null) {
        throw Exception('Janus did not return a JSEP offer (long-poll timed out). Is the host telecast offline?');
      }

      final remoteJsep = eventData['jsep'];
      final sdp = remoteJsep['sdp'] as String;
      final type = remoteJsep['type'] as String;

      // 4. Create Peer Connection
      final pcConstraints = {
        'mandatory': {},
        'optional': [
          {'DtlsSrtpKeyAgreement': true},
        ],
      };

      final iceConfig = {
        'iceServers': [
          {'urls': 'stun:stun.l.google.com:19302'},
        ],
      };

      _peerConnection = await createPeerConnection(iceConfig, pcConstraints);
      debugPrint('[WebRTCService] Created PeerConnection');

      // Handle Remote Tracks
      _peerConnection!.onTrack = (RTCTrackEvent event) {
        debugPrint('[WebRTCService] onTrack received: ${event.streams.length} streams');
        if (event.streams.isNotEmpty) {
          _remoteStream = event.streams[0];
          remoteRenderer!.srcObject = _remoteStream;
        }
      };

      _peerConnection!.onAddStream = (MediaStream stream) {
        debugPrint('[WebRTCService] onAddStream received');
        _remoteStream = stream;
        remoteRenderer!.srcObject = _remoteStream;
      };

      // Handle and trickle local ICE candidates
      _peerConnection!.onIceCandidate = (RTCIceCandidate candidate) async {
        if (candidate.candidate == null) return;
        debugPrint('[WebRTCService] Trickling ICE candidate');
        try {
          await _dio.post('$url/$_sessionId/$_handleId', data: {
            'janus': 'trickle',
            'transaction': _randomTx(),
            'candidate': {
              'candidate': candidate.candidate,
              'sdpMid': candidate.sdpMid,
              'sdpMLineIndex': candidate.sdpMLineIndex,
            }
          });
        } catch (e) {
          debugPrint('[WebRTCService] Error trickling ICE: $e');
        }
      };

      // 5. Set Remote Offer (Janus Offer)
      await _peerConnection!.setRemoteDescription(RTCSessionDescription(sdp, type));
      debugPrint('[WebRTCService] Set remote description');

      // 6. Create Local SDP Answer
      final answerConstraints = {
        'mandatory': {
          'OfferToReceiveAudio': true,
          'OfferToReceiveVideo': true,
        },
        'optional': [],
      };
      final answer = await _peerConnection!.createAnswer(answerConstraints);
      await _peerConnection!.setLocalDescription(answer);
      debugPrint('[WebRTCService] Created and set local answer');

      // 7. Send Answer to Janus to Start receiving Media
      final startRes = await _dio.post('$url/$_sessionId/$_handleId', data: {
        'janus': 'message',
        'transaction': _randomTx(),
        'body': {
          'request': 'start',
          'room': roomId,
        },
        'jsep': {
          'type': answer.type,
          'sdp': answer.sdp,
        }
      });
      debugPrint('[WebRTCService] Sent start request to Janus: ${startRes.data}');

      isConnected = true;
    } catch (e) {
      debugPrint('[WebRTCService] Connection Error: $e');
      await stop();
      rethrow;
    }
  }

  /// Cleanly stop stream, close PeerConnection, and destroy Janus Session
  Future<void> stop() async {
    debugPrint('[WebRTCService] Stopping and cleaning up WebRTC connection...');
    isConnected = false;

    // 1. Close WebRTC Connection
    if (_peerConnection != null) {
      await _peerConnection!.close();
      _peerConnection = null;
    }

    // 2. Unbind UI Renderer
    if (remoteRenderer != null) {
      remoteRenderer!.srcObject = null;
    }
    _remoteStream = null;

    // 3. Destroy Session on Janus Gateway
    if (_sessionId != null) {
      final url = janusUrl;
      final sessId = _sessionId;
      _sessionId = null;
      _handleId = null;

      try {
        await _dio.post('$url/$sessId', data: {
          'janus': 'destroy',
          'transaction': _randomTx(),
        });
        debugPrint('[WebRTCService] Janus session destroyed cleanly.');
      } catch (e) {
        debugPrint('[WebRTCService] Error destroying Janus session: $e');
      }
    }
  }
}
