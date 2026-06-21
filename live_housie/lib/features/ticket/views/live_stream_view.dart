import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import '../../../data/services/webrtc_service.dart';

class LiveStreamView extends StatefulWidget {
  final String gameId;
  final String gameName;

  const LiveStreamView({
    Key? key,
    required this.gameId,
    required this.gameName,
  }) : super(key: key);

  /// Shows the dialog over the current context
  static void show(BuildContext context, String gameId, String gameName) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => LiveStreamView(gameId: gameId, gameName: gameName),
    );
  }

  @override
  State<LiveStreamView> createState() => _LiveStreamViewState();
}

class _LiveStreamViewState extends State<LiveStreamView> {
  final RTCVideoRenderer _remoteRenderer = RTCVideoRenderer();
  final WebRTCService _webRTCService = WebRTCService();
  bool _isLoading = true;
  String? _errorMsg;

  @override
  void initState() {
    super.initState();
    _initRendererAndConnect();
  }

  Future<void> _initRendererAndConnect() async {
    try {
      setState(() {
        _isLoading = true;
        _errorMsg = null;
      });

      await _remoteRenderer.initialize();
      await _webRTCService.startSubscriber(widget.gameId, _remoteRenderer);

      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e, stackTrace) {
      debugPrint('[LiveStreamView] Error: $e');
      debugPrint('[LiveStreamView] Stack: $stackTrace');
      if (mounted) {
        final msg = e.toString();
        setState(() {
          _isLoading = false;
          if (msg.contains('offline') || msg.contains('no active publisher')) {
            _errorMsg = 'Live telecast is currently offline';
          } else if (msg.contains('JSEP offer')) {
            _errorMsg = 'Live telecast is currently offline';
          } else {
            _errorMsg = 'Failed to connect to streaming server';
          }
        });
      }
    }
  }

  @override
  void dispose() {
    _webRTCService.stop();
    _remoteRenderer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.black,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Container(
          width: double.infinity,
          constraints: const BoxConstraints(maxHeight: 360),
          color: const Color(0xFF111116),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header bar
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                color: const Color(0xFF1C1C24),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 8,
                                height: 8,
                                decoration: BoxDecoration(
                                  color: _errorMsg == null && !_isLoading
                                      ? Colors.red
                                      : Colors.grey,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 6),
                              const Text(
                                'LIVE STREAM',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 0.8,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            widget.gameName,
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white70, size: 20),
                      onPressed: () => Navigator.pop(context),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
              ),

              // Player viewport
              AspectRatio(
                aspectRatio: 4 / 3,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // Remote video stream
                    if (!_isLoading && _errorMsg == null)
                      RTCVideoView(
                        _remoteRenderer,
                        objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitContain,
                      ),

                    // Loading overlay
                    if (_isLoading)
                      const Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          CircularProgressIndicator(
                            color: Color(0xFF4648D4),
                            strokeWidth: 3,
                          ),
                          SizedBox(height: 12),
                          Text(
                            'Connecting to host stream...',
                            style: TextStyle(color: Colors.white70, fontSize: 13),
                          ),
                        ],
                      ),

                    // Error overlay
                    if (_errorMsg != null)
                      Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              Icons.videocam_off_rounded,
                              color: Colors.white38,
                              size: 48,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              _errorMsg!,
                              textAlign: TextAlign.center,
                              style: const TextStyle(color: Colors.white70, fontSize: 13),
                            ),
                            const SizedBox(height: 16),
                            ElevatedButton(
                              onPressed: _initRendererAndConnect,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF4648D4),
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              child: const Text('Retry'),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
