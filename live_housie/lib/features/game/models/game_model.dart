/// Game Model — represents an upcoming game from the API.

class GameModel {
  final String id;
  final String gameName;
  final DateTime scheduledStartTime;
  final int ticketPriceCents;
  final int maxTicketCount;
  final int soldTicketCount;
  final int availableTickets;
  final int commissionPercentage;
  final int prizePoolCents;
  final String state;

  GameModel({
    required this.id,
    required this.gameName,
    required this.scheduledStartTime,
    required this.ticketPriceCents,
    required this.maxTicketCount,
    required this.soldTicketCount,
    required this.availableTickets,
    required this.commissionPercentage,
    required this.prizePoolCents,
    required this.state,
  });

  factory GameModel.fromJson(Map<String, dynamic> json) {
    return GameModel(
      id: json['id'] as String,
      gameName: json['gameName'] as String,
      scheduledStartTime: DateTime.parse(json['scheduledStartTime'] as String),
      ticketPriceCents: json['ticketPriceCents'] as int,
      maxTicketCount: json['maxTicketCount'] as int,
      soldTicketCount: json['soldTicketCount'] as int,
      availableTickets: json['availableTickets'] as int,
      commissionPercentage: json['commissionPercentage'] as int,
      prizePoolCents: json['prizePoolCents'] as int,
      state: json['state'] as String,
    );
  }

  /// Format price from cents to display string
  String get formattedPrice => '₹${(ticketPriceCents / 100).toStringAsFixed(0)}';

  /// Time until game starts
  Duration get timeUntilStart => scheduledStartTime.difference(DateTime.now());

  /// Is the game sold out?
  bool get isSoldOut => availableTickets <= 0;
}
