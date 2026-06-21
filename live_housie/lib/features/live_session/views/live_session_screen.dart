import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_constants.dart';
import '../../../data/services/webrtc_service.dart';
import '../../../data/services/websocket_service.dart';
import '../../ticket/models/ticket_model.dart';
import '../../ticket/repositories/ticket_repository.dart';
import '../../ticket/viewmodels/ticket_viewmodel.dart';
import '../../profile/viewmodels/profile_viewmodel.dart';

class LiveSessionScreen extends ConsumerStatefulWidget {
  final String gameId;

  const LiveSessionScreen({super.key, required this.gameId});

  @override
  ConsumerState<LiveSessionScreen> createState() => _LiveSessionScreenState();
}

class _LiveSessionScreenState extends ConsumerState<LiveSessionScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final RTCVideoRenderer _remoteRenderer = RTCVideoRenderer();
  final WebRTCService _webRTCService = WebRTCService();
  
  WebSocketService? _socketService;
  bool _isStreamLoading = true;
  String? _streamErrorMsg;

  // Local state for the live room
  TicketGameModel? _game;
  List<TicketModel> _userTickets = [];
  final List<int> _calledNumbers = [];
  final List<int> _recentNumbers = [];
  final List<Map<String, dynamic>> _chatMessages = [];
  final Map<String, Set<int>> _markedNumbersPerTicket = {};
  bool _claiming = false;
  int _currentPage = 0;
  final PageController _pageController = PageController();
  final TextEditingController _chatInputController = TextEditingController();
  final ScrollController _chatScrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _initWebRTC();
    _initWebSocket();
    _fetchTickets();
  }

  @override
  void dispose() {
    _webRTCService.stop();
    _remoteRenderer.dispose();
    _socketService?.disconnect();
    _pageController.dispose();
    _chatInputController.dispose();
    _chatScrollController.dispose();
    super.dispose();
  }

  // ─── WebRTC Connection ──────────────────────────────────────────────────────
  Future<void> _initWebRTC() async {
    try {
      setState(() {
        _isStreamLoading = true;
        _streamErrorMsg = null;
      });

      await _remoteRenderer.initialize();
      await _webRTCService.startSubscriber(widget.gameId, _remoteRenderer);

      if (mounted) {
        setState(() {
          _isStreamLoading = false;
        });
      }
    } catch (e) {
      debugPrint('[LiveSessionScreen] WebRTC Error: $e');
      if (mounted) {
        final msg = e.toString();
        setState(() {
          _isStreamLoading = false;
          if (msg.contains('offline') || msg.contains('no active publisher')) {
            _streamErrorMsg = 'Live telecast is currently offline';
          } else {
            _streamErrorMsg = 'Failed to connect to streaming server';
          }
        });
      }
    }
  }

  // ─── WebSocket Connections & Listeners ──────────────────────────────────────
  void _initWebSocket() {
    _socketService = WebSocketService();
    
    _socketService!.on('connect', (_) {
      debugPrint('[LiveSessionScreen] Socket connected. Joining game room...');
      _socketService!.emit('join', 'game:${widget.gameId}');
    });

    _socketService!.on('game:draw_number', (data) {
      debugPrint('[LiveSessionScreen] game:draw_number received: $data');
      if (data is Map<String, dynamic>) {
        final num = data['number'] as int;
        if (!_calledNumbers.contains(num)) {
          setState(() {
            _calledNumbers.add(num);
            _recentNumbers.insert(0, num);
          });
        }
      }
    });

    _socketService!.on('game:state_change', (data) {
      debugPrint('[LiveSessionScreen] game:state_change received: $data');
      if (data is Map<String, dynamic> && mounted) {
        final state = data['state'] as String;
        if (state == 'completed' || state == 'cancelled') {
          _showGameFinishedDialog(state);
        }
      }
    });

    _socketService!.on('game:claim_validation', (data) {
      debugPrint('[LiveSessionScreen] game:claim_validation received: $data');
      if (data is Map<String, dynamic> && mounted) {
        final displayName = data['displayName'] as String;
        final pattern = data['pattern'] as String;
        final status = data['status'] as String;

        // Auto announce claims inside Chat
        setState(() {
          _chatMessages.add({
            'displayName': 'SYSTEM',
            'message': '$displayName claimed $pattern - ${status.toUpperCase()}',
            'isSystem': true,
            'timestamp': DateTime.now().toIso8601String(),
          });
          _scrollToBottom();
        });

        // Invalidate tickets provider to refresh status from backend
        ref.invalidate(userTicketsProvider());
        _fetchTickets();
      }
    });

    _socketService!.on('chat:message', (data) {
      debugPrint('[LiveSessionScreen] chat:message received: $data');
      if (data is Map<String, dynamic> && mounted) {
        final userProfile = ref.read(userProfileProvider).value;
        final myName = userProfile?.displayName ?? 'Player';
        final senderName = data['displayName'] as String;

        setState(() {
          _chatMessages.add({
            'displayName': senderName,
            'message': data['message'] as String,
            'isMe': senderName == myName,
            'timestamp': data['timestamp'] as String? ?? DateTime.now().toIso8601String(),
          });
          _scrollToBottom();
        });
      }
    });

    _socketService!.connect();
  }

  // ─── Fetch Tickets & Sync Draw State ────────────────────────────────────────
  Future<void> _fetchTickets() async {
    try {
      final repository = TicketRepository();
      final tickets = await repository.getMyTickets(gameId: widget.gameId);
      
      if (mounted && tickets.isNotEmpty) {
        setState(() {
          _userTickets = tickets;
          _game = tickets.first.game;
          
          // Pre-populate drawn numbers from initial load
          if (_game != null && _game!.drawEvents.isNotEmpty) {
            _calledNumbers.clear();
            _calledNumbers.addAll(_game!.drawEvents);
            
            _recentNumbers.clear();
            _recentNumbers.addAll(_game!.drawEvents.reversed);
          }

          // Initialize local sets for marked numbers
          for (var t in _userTickets) {
            _markedNumbersPerTicket.putIfAbsent(t.id, () => <int>{});
          }
        });
      }
    } catch (e) {
      debugPrint('[LiveSessionScreen] Error fetching tickets: $e');
    }
  }

  void _sendChatMessage() {
    final text = _chatInputController.text.trim();
    if (text.isEmpty) return;

    final userProfile = ref.read(userProfileProvider).value;
    final displayName = userProfile?.displayName ?? 'Player';

    _socketService?.emit('chat:send', {
      'room': 'game:${widget.gameId}',
      'message': text,
      'displayName': displayName,
    });

    _chatInputController.clear();
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_chatScrollController.hasClients) {
        _chatScrollController.animateTo(
          _chatScrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _claimPattern(String pattern, String ticketId) async {
    if (_claiming) return;
    setState(() => _claiming = true);

    try {
      final repository = TicketRepository();
      await repository.submitClaim(
        ticketId: ticketId,
        gameId: widget.gameId,
        pattern: pattern,
      );

      // Invalidate tickets provider
      ref.invalidate(userTicketsProvider());
      await _fetchTickets();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Claim submitted successfully!'),
            backgroundColor: Color(0xFF00885D),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        String errMsg = e.toString().replaceAll('DioException:', '').trim();
        if (errMsg.contains('Blocked from claiming')) {
          errMsg = 'Blocked! 5 strikes reached for false claims.';
        } else if (errMsg.contains('already been successfully claimed')) {
          errMsg = 'This prize has already been claimed.';
        } else if (errMsg.contains('not been drawn yet')) {
          errMsg = 'Invalid Claim! Numbers not drawn yet. Strike added!';
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errMsg),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _claiming = false);
      }
    }
  }

  void _showGameFinishedDialog(String state) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1E2130),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(
            state == 'completed' ? 'Game Over!' : 'Game Cancelled',
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
          content: Text(
            state == 'completed'
                ? 'This game has finished. Check your winnings!'
                : 'This game has been cancelled by the host.',
            style: const TextStyle(color: Colors.white70),
          ),
          actions: [
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context); // Close dialog
                context.pop(); // Exit game room
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4648D4),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: const Text('Back to Lobby'),
            ),
          ],
        );
      },
    );
  }

  void _showClaimsBottomSheet(BuildContext context, TicketModel ticket) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      backgroundColor: const Color(0xFF131520),
      builder: (context) {
        final config = ticket.game.prizeConfig;
        final claims = ticket.winningClaims;

        Widget buildClaimItem(String patternKey, String label) {
          final share = config[patternKey] as num? ?? 0;
          if (share == 0) return const SizedBox.shrink();

          final amount = (ticket.game.prizePoolCents * share) / 10000; // In Rupees
          final hasClaimed = claims.any((c) => c.pattern == patternKey);
          final claimStatus = hasClaimed 
              ? claims.firstWhere((c) => c.pattern == patternKey).status 
              : null;

          Color statusColor = const Color(0xFF4648D4);
          String statusText = 'CLAIM';
          bool canClick = !hasClaimed;

          if (claimStatus == 'pending') {
            statusColor = const Color(0xFFFEA619);
            statusText = 'PENDING';
            canClick = false;
          } else if (claimStatus == 'valid') {
            statusColor = const Color(0xFF00885D);
            statusText = 'WON';
            canClick = false;
          } else if (claimStatus == 'invalid') {
            statusColor = Colors.red;
            statusText = 'INVALID';
            canClick = true; // allow retry if previously invalid
          }

          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFF1E2130),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Pool Share: ${share}%',
                      style: const TextStyle(color: Colors.white30, fontSize: 11),
                    ),
                  ],
                ),
                Row(
                  children: [
                    Text(
                      '₹${amount.toStringAsFixed(0)}',
                      style: const TextStyle(color: Color(0xFFFFB03A), fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    const SizedBox(width: 16),
                    SizedBox(
                      height: 36,
                      child: ElevatedButton(
                        onPressed: canClick
                            ? () {
                                Navigator.pop(context);
                                _claimPattern(patternKey, ticket.id);
                              }
                            : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: statusColor,
                          disabledBackgroundColor: statusColor.withOpacity(0.4),
                          foregroundColor: Colors.white,
                          disabledForegroundColor: Colors.white70,
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                        ),
                        child: Text(
                          statusText,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        }

        return Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Available Claims',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white70),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      buildClaimItem('early_five', 'Early Five'),
                      buildClaimItem('four_corners', 'Four Corners'),
                      buildClaimItem('top_line', 'Top Line'),
                      buildClaimItem('middle_line', 'Middle Line'),
                      buildClaimItem('bottom_line', 'Bottom Line'),
                      buildClaimItem('full_house', 'Full House'),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // Calculate ticket matched count
  int _getMatchedCount(TicketModel ticket) {
    int matched = 0;
    for (var row in ticket.grid) {
      for (var val in row) {
        if (val != null && _calledNumbers.contains(val)) {
          matched++;
        }
      }
    }
    return matched;
  }

  @override
  Widget build(BuildContext context) {
    final isLandscape = MediaQuery.of(context).orientation == Orientation.landscape;

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: const Color(0xFF0F101A),
      endDrawer: Drawer(
        width: 320,
        backgroundColor: const Color(0xFF131520),
        child: _buildChatPanel(),
      ),
      body: SafeArea(
        child: isLandscape 
            ? Row(
                children: [
                  Expanded(flex: 3, child: _buildLeftPanel(context)),
                  const VerticalDivider(width: 1, color: Colors.white12),
                  Expanded(flex: 2, child: _buildChatPanel()),
                ],
              )
            : _buildLeftPanel(context),
      ),
    );
  }

  Widget _buildLeftPanel(BuildContext context) {
    final isLandscape = MediaQuery.of(context).orientation == Orientation.landscape;

    return Column(
      children: [
        // ─── Header ──────────────────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back, color: Colors.white),
                    onPressed: () => context.pop(),
                  ),
                  const SizedBox(width: 4),
                  const Text(
                    'LOOTLO PRO',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      fontSize: 16,
                      letterSpacing: 0.8,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.red,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text(
                      'LIVE',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              if (!isLandscape)
                IconButton(
                  icon: const Icon(Icons.chat_bubble_outline, color: Colors.white),
                  onPressed: () => _scaffoldKey.currentState?.openEndDrawer(),
                ),
            ],
          ),
        ),

        // ─── Video Viewport (WebRTC) ─────────────────────────────────────────
        AspectRatio(
          aspectRatio: isLandscape ? 16 / 9 : 4 / 3,
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: const Color(0xFF131520),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white12, width: 1),
            ),
            clipBehavior: Clip.antiAlias,
            child: Stack(
              alignment: Alignment.center,
              children: [
                if (!_isStreamLoading && _streamErrorMsg == null)
                  RTCVideoView(
                    _remoteRenderer,
                    objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitContain,
                  ),

                if (_isStreamLoading)
                  const Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircularProgressIndicator(
                        color: Color(0xFF4648D4),
                        strokeWidth: 3,
                      ),
                      SizedBox(height: 12),
                      Text(
                        'Connecting to live feed...',
                        style: TextStyle(color: Colors.white70, fontSize: 13),
                      ),
                    ],
                  ),

                if (_streamErrorMsg != null)
                  Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.videocam_off_rounded,
                          color: Colors.white24,
                          size: 48,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          _streamErrorMsg!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.white70, fontSize: 13),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: _initWebRTC,
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

                // Overlays
                // 1. Viewer Count Pill
                Positioned(
                  top: 12,
                  left: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.6),
                      borderRadius: BorderRadius.circular(100),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.remove_red_eye_outlined, color: Colors.white, size: 12),
                        const SizedBox(width: 4),
                        Text(
                          '${120 + _calledNumbers.length * 15} VIEWERS', // MOCKED Viewers based on game time
                          style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                ),

                // 2. Centered Next Number card
                if (_calledNumbers.isNotEmpty)
                  Positioned(
                    bottom: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xCC1A1C29),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.white10),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text(
                            'DRAWN NUMBER',
                            style: TextStyle(color: Colors.white38, fontSize: 8, fontWeight: FontWeight.bold, letterSpacing: 0.6),
                          ),
                          Text(
                            '${_calledNumbers.last}',
                            style: const TextStyle(color: Color(0xFFFFB03A), fontSize: 32, fontWeight: FontWeight.w900),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 12),

        // ─── Recent Calls Ticker ─────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: SizedBox(
            height: 40,
            child: Row(
              children: [
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'RECENT',
                      style: TextStyle(color: Colors.white30, fontSize: 8, fontWeight: FontWeight.bold),
                    ),
                    Text(
                      'CALLS',
                      style: TextStyle(color: Colors.white30, fontSize: 8, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _recentNumbers.isEmpty
                      ? const Center(
                          child: Text(
                            'Waiting for numbers...',
                            style: TextStyle(color: Colors.white24, fontSize: 12, fontStyle: FontStyle.italic),
                          ),
                        )
                      : ListView.builder(
                          scrollDirection: Axis.horizontal,
                          itemCount: _recentNumbers.length,
                          itemBuilder: (context, index) {
                            final number = _recentNumbers[index];
                            final isLatest = index == 0;
                            return Container(
                              margin: const EdgeInsets.only(right: 6),
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: isLatest ? const Color(0xFF4648D4) : const Color(0xFF1E2130),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                number.toString().padLeft(2, '0'),
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: isLatest ? FontWeight.w900 : FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 16),

        // ─── Tickets Section ─────────────────────────────────────────────────
        Expanded(
          child: _userTickets.isEmpty
              ? const Center(
                  child: CircularProgressIndicator(color: Color(0xFF4648D4)),
                )
              : Column(
                  children: [
                    // loadout batch label
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'YOUR LOADOUT',
                            style: TextStyle(color: Colors.white30, fontWeight: FontWeight.bold, fontSize: 11, letterSpacing: 0.6),
                          ),
                          Text(
                            'BATCH #L-4${widget.gameId.hashCode.abs() % 1000}',
                            style: const TextStyle(color: Colors.white12, fontWeight: FontWeight.bold, fontSize: 10),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),

                    // PageView Carousel
                    Expanded(
                      child: PageView.builder(
                        controller: _pageController,
                        onPageChanged: (page) {
                          setState(() {
                            _currentPage = page;
                          });
                        },
                        itemCount: _userTickets.length,
                        itemBuilder: (context, index) {
                          final ticket = _userTickets[index];
                          final matchedCount = _getMatchedCount(ticket);
                          return _buildTicketCard(ticket, index + 1, matchedCount);
                        },
                      ),
                    ),

                    // Carousel Dots Indicator
                    if (_userTickets.length > 1) ...[
                      const SizedBox(height: 6),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(
                          _userTickets.length,
                          (idx) => Container(
                            margin: const EdgeInsets.symmetric(horizontal: 3),
                            width: _currentPage == idx ? 8 : 6,
                            height: _currentPage == idx ? 8 : 6,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: _currentPage == idx 
                                  ? const Color(0xFF4648D4) 
                                  : const Color(0xFFC7C4D7).withOpacity(0.3),
                            ),
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 8),
                  ],
                ),
        ),
      ],
    );
  }

  Widget _buildTicketCard(TicketModel ticket, int indexNo, int matchedCount) {
    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFF131520),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white10),
        ),
        constraints: const BoxConstraints(maxWidth: 362),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Ticket Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'TICKET ${indexNo.toString().padLeft(2, '0')}',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF4648D4).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(100),
                  ),
                  child: Text(
                    'PROGRESS: ${matchedCount.toString().padLeft(2, '0')}/15',
                    style: const TextStyle(color: Color(0xFF4C50E1), fontWeight: FontWeight.bold, fontSize: 10),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // 3x9 Grid
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 9,
                crossAxisSpacing: 4,
                mainAxisSpacing: 4,
                childAspectRatio: 1.0,
              ),
              itemCount: 27,
              itemBuilder: (context, gridIndex) {
                final row = gridIndex ~/ 9;
                final col = gridIndex % 9;
                final value = ticket.grid[row][col];

                if (value == null) {
                  return Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFF0F101A),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  );
                }

                final isCalled = _calledNumbers.contains(value);
                final isMarked = _markedNumbersPerTicket[ticket.id]?.contains(value) ?? false;

                Color cellColor = const Color(0xFF1E2130);
                Color textColor = Colors.white;

                if (isMarked) {
                  cellColor = const Color(0xFF4C50E1); // Marked is Purple/Blue
                  textColor = Colors.white;
                } else if (isCalled) {
                  cellColor = const Color(0xFFFFAE34); // Called but not marked is Yellow Alert
                  textColor = Colors.black;
                }

                return GestureDetector(
                  onTap: () {
                    setState(() {
                      final markedSet = _markedNumbersPerTicket[ticket.id]!;
                      if (markedSet.contains(value)) {
                        markedSet.remove(value);
                      } else {
                        markedSet.add(value);
                      }
                    });
                  },
                  child: Container(
                    decoration: BoxDecoration(
                      color: cellColor,
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(
                        color: isCalled && !isMarked 
                            ? const Color(0xFFFF9D00) 
                            : Colors.transparent,
                        width: 1,
                      ),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      value.toString().padLeft(2, '0'),
                      style: TextStyle(
                        color: textColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                );
              },
            ),

            const SizedBox(height: 12),

            // Footer / Claim Button
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'TICKET ID: #${ticket.id.substring(0, 8).toUpperCase()}',
                      style: const TextStyle(color: Colors.white24, fontSize: 9, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        const Icon(Icons.check_circle_outline, color: Color(0xFF00885D), size: 10),
                        const SizedBox(width: 3),
                        const Text(
                          'VERIFIED TICKET',
                          style: TextStyle(color: Color(0xFF00885D), fontSize: 9, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ],
                ),
                SizedBox(
                  height: 38,
                  child: ElevatedButton(
                    onPressed: () => _showClaimsBottomSheet(context, ticket),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFFB03A),
                      foregroundColor: Colors.black,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(100)),
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      elevation: 0,
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.stars, size: 14, color: Colors.black),
                        SizedBox(width: 6),
                        Text(
                          'CLAIM PRIZE',
                          style: TextStyle(fontWeight: FontWeight.w900, fontSize: 11, letterSpacing: 0.4),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ─── Live Comms Chat Panel Widget ──────────────────────────────────────────
  Widget _buildChatPanel() {
    return Column(
      children: [
        // Chat Header
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: const BoxDecoration(
            color: Color(0xFF1C1C24),
            border: Border(bottom: BorderSide(color: Colors.white10)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(Icons.chat_bubble, color: Color(0xFF4C50E1), size: 18),
                  SizedBox(width: 8),
                  Text(
                    'LIVE COMMS',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 13, letterSpacing: 0.6),
                  ),
                ],
              ),
              IconButton(
                icon: const Icon(Icons.close, color: Colors.white70, size: 18),
                onPressed: () {
                  final isLandscape = MediaQuery.of(context).orientation == Orientation.landscape;
                  if (!isLandscape) {
                    Navigator.pop(context); // Close Drawer
                  }
                },
              ),
            ],
          ),
        ),

        // Chat Message List
        Expanded(
          child: _chatMessages.isEmpty
              ? const Center(
                  child: Text(
                    'No messages yet. Say hello!',
                    style: TextStyle(color: Colors.white24, fontSize: 12),
                  ),
                )
              : ListView.builder(
                  controller: _chatScrollController,
                  padding: const EdgeInsets.all(16),
                  itemCount: _chatMessages.length,
                  itemBuilder: (context, index) {
                    final msg = _chatMessages[index];
                    final isSystem = msg['isSystem'] as bool? ?? false;
                    final isMe = msg['isMe'] as bool? ?? false;
                    final name = msg['displayName'] as String;
                    final body = msg['message'] as String;

                    if (isSystem) {
                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: const Color(0x1A00885D),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0x3300885D)),
                        ),
                        child: Text(
                          body,
                          style: const TextStyle(color: Color(0xFF00FF9D), fontSize: 11, fontWeight: FontWeight.bold),
                          textAlign: TextAlign.center,
                        ),
                      );
                    }

                    return Align(
                      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: isMe ? const Color(0xFF4C50E1) : const Color(0xFF1E2130),
                          borderRadius: BorderRadius.only(
                            topLeft: const Radius.circular(12),
                            topRight: const Radius.circular(12),
                            bottomLeft: Radius.circular(isMe ? 12 : 0),
                            bottomRight: Radius.circular(isMe ? 0 : 12),
                          ),
                        ),
                        constraints: const BoxConstraints(maxWidth: 240),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (!isMe)
                              Text(
                                name,
                                style: const TextStyle(color: Color(0xFFFFB03A), fontWeight: FontWeight.bold, fontSize: 10),
                              ),
                            if (!isMe) const SizedBox(height: 3),
                            Text(
                              body,
                              style: const TextStyle(color: Colors.white, fontSize: 13),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),

        // Chat Input Box
        Container(
          padding: const EdgeInsets.all(12),
          decoration: const BoxDecoration(
            color: Color(0xFF131520),
            border: Border(top: BorderSide(color: Colors.white10)),
          ),
          child: Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 40,
                  child: TextField(
                    controller: _chatInputController,
                    style: const TextStyle(color: Colors.white, fontSize: 13),
                    decoration: InputDecoration(
                      hintText: 'Enter message...',
                      hintStyle: const TextStyle(color: Colors.white24, fontSize: 13),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                      filled: true,
                      fillColor: const Color(0xFF1E2130),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(100),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    onSubmitted: (_) => _sendChatMessage(),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.send, color: Color(0xFF4C50E1)),
                onPressed: _sendChatMessage,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
