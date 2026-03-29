class TicketTier {
  final String id;
  final String eventId;
  final String name;
  final String? description;
  final double price;
  final String currency;
  final int totalQuantity;
  final int soldCount;
  final int maxPerOrder;
  final String? saleStartsAt;
  final String? saleEndsAt;
  final String tierType;
  final List<String> perks;
  final String? color;
  final bool isTransferable;
  final bool allowReEntry;
  final bool isActive;

  TicketTier({
    required this.id,
    required this.eventId,
    required this.name,
    this.description,
    required this.price,
    this.currency = 'KES',
    required this.totalQuantity,
    this.soldCount = 0,
    this.maxPerOrder = 4,
    this.saleStartsAt,
    this.saleEndsAt,
    this.tierType = 'GA',
    this.perks = const [],
    this.color,
    this.isTransferable = true,
    this.allowReEntry = false,
    this.isActive = true,
  });

  int get available => totalQuantity - soldCount;
  bool get isSoldOut => available <= 0;

  factory TicketTier.fromJson(Map<String, dynamic> json) {
    List<String> parseStringList(dynamic val) {
      if (val == null) return [];
      if (val is List) return val.map((e) => e?.toString() ?? '').toList();
      return [];
    }

    return TicketTier(
      id: json['id']?.toString() ?? '',
      eventId: json['eventId']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      description: json['description']?.toString(),
      price: double.tryParse(json['price']?.toString() ?? '0') ?? 0.0,
      currency: json['currency']?.toString() ?? 'KES',
      totalQuantity:
          int.tryParse(json['totalQuantity']?.toString() ?? '0') ?? 0,
      soldCount: int.tryParse(json['soldCount']?.toString() ?? '0') ?? 0,
      maxPerOrder: int.tryParse(json['maxPerOrder']?.toString() ?? '4') ?? 4,
      saleStartsAt: json['saleStartsAt']?.toString(),
      saleEndsAt: json['saleEndsAt']?.toString(),
      tierType: json['tierType']?.toString() ?? 'GA',
      perks: parseStringList(json['perks']),
      color: json['color']?.toString(),
      isTransferable: json['isTransferable'] != false,
      allowReEntry: json['allowReEntry'] == true,
      isActive: json['isActive'] != false,
    );
  }
}
