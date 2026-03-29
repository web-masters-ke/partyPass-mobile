class LoyaltyEvent {
  final String id;
  final String userId;
  final String action;
  final int points;
  final String? description;
  final String? referenceId;
  final String createdAt;

  LoyaltyEvent({
    required this.id,
    required this.userId,
    required this.action,
    required this.points,
    this.description,
    this.referenceId,
    required this.createdAt,
  });

  bool get isEarning => points > 0;
  bool get isRedemption => points < 0;

  factory LoyaltyEvent.fromJson(Map<String, dynamic> json) {
    return LoyaltyEvent(
      id: json['id']?.toString() ?? '',
      userId: json['userId']?.toString() ?? '',
      action: json['action']?.toString() ?? '',
      points: int.tryParse(json['points']?.toString() ?? '0') ?? 0,
      description: json['description']?.toString(),
      referenceId: json['referenceId']?.toString(),
      createdAt: json['createdAt']?.toString() ?? '',
    );
  }
}
