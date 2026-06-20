/// Ticket Model — represents a user's purchased Tambola/Housie ticket.
class TicketModel {
  final String id;
  final String gameId;
  final List<List<int?>> grid;
  final DateTime purchasedAt;
  final TicketGameModel game;
  final List<TicketWinningClaim>? _winningClaims;

  TicketModel({
    required this.id,
    required this.gameId,
    required this.grid,
    required this.purchasedAt,
    required this.game,
    List<TicketWinningClaim>? winningClaims,
  }) : _winningClaims = winningClaims;

  List<TicketWinningClaim> get winningClaims => _winningClaims ?? const [];

  factory TicketModel.fromJson(Map<String, dynamic> json) {
    // Parse the 3x9 grid
    final gridRaw = json['grid'] as List<dynamic>;
    final List<List<int?>> parsedGrid = gridRaw.map((row) {
      return (row as List<dynamic>).map((cell) => cell as int?).toList();
    }).toList();

    // Parse winningClaims
    final claimsRaw = json['winningClaims'] as List<dynamic>?;
    final List<TicketWinningClaim> parsedClaims = claimsRaw?.map((c) {
      return TicketWinningClaim.fromJson(c as Map<String, dynamic>);
    }).toList() ?? <TicketWinningClaim>[];

    return TicketModel(
      id: json['id'] as String,
      gameId: json['gameId'] as String,
      grid: parsedGrid,
      purchasedAt: DateTime.parse(json['purchasedAt'] as String),
      game: TicketGameModel.fromJson(json['game'] as Map<String, dynamic>),
      winningClaims: parsedClaims,
    );
  }

  int get totalWinningsCents => winningClaims
      .where((wc) => wc.status == 'valid')
      .fold(0, (sum, wc) => sum + wc.prizeAmountCents);

  String get winningsStatusText {
    final wonCents = totalWinningsCents;
    if (wonCents > 0) {
      return 'Won ₹${(wonCents / 100).toStringAsFixed(0)}';
    }
    final hasPending = winningClaims.any((wc) => wc.status == 'pending');
    if (hasPending) {
      return 'Claim Pending';
    }
    return 'No wins';
  }
}

class TicketWinningClaim {
  final String id;
  final String pattern;
  final String status;
  final int prizeAmountCents;

  TicketWinningClaim({
    required this.id,
    required this.pattern,
    required this.status,
    required this.prizeAmountCents,
  });

  factory TicketWinningClaim.fromJson(Map<String, dynamic> json) {
    return TicketWinningClaim(
      id: json['id'] as String,
      pattern: json['pattern'] as String,
      status: json['status'] as String,
      prizeAmountCents: json['prizeAmountCents'] as int,
    );
  }

  String get formattedPattern {
    switch (pattern) {
      case 'full_house':
        return 'Full House';
      case 'top_line':
        return 'Top Line';
      case 'middle_line':
        return 'Middle Line';
      case 'bottom_line':
        return 'Bottom Line';
      case 'early_five':
        return 'Early Five';
      case 'four_corners':
        return 'Four Corners';
      default:
        return pattern.replaceAll('_', ' ').toUpperCase();
    }
  }
}

class TicketGameModel {
  final String id;
  final String gameName;
  final String state;
  final DateTime scheduledStartTime;
  final int ticketPriceCents;
  final List<int>? _drawEvents;

  TicketGameModel({
    required this.id,
    required this.gameName,
    required this.state,
    required this.scheduledStartTime,
    required this.ticketPriceCents,
    List<int>? drawEvents,
  }) : _drawEvents = drawEvents;

  List<int> get drawEvents => _drawEvents ?? const [];

  factory TicketGameModel.fromJson(Map<String, dynamic> json) {
    final drawEventsRaw = json['drawEvents'] as List<dynamic>?;
    final drawEvents = drawEventsRaw?.map((e) => e as int).toList() ?? <int>[];

    return TicketGameModel(
      id: json['id'] as String,
      gameName: json['gameName'] as String? ?? 'Tambola Game',
      state: json['state'] as String,
      scheduledStartTime: DateTime.parse(json['scheduledStartTime'] as String),
      ticketPriceCents: json['ticketPriceCents'] as int,
      drawEvents: drawEvents,
    );
  }

  /// Format price from cents to display string
  String get formattedPrice =>
      '₹${(ticketPriceCents / 100).toStringAsFixed(0)}';
}
