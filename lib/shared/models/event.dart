class Event {
  final String id;
  final String title;
  final String description;
  final String? coverImageUrl;
  final String? promoVideoUrl;
  final String category;
  final List<String> genreTags;
  final String status;
  final DateTime startDateTime;
  final DateTime endDateTime;
  final DateTime? doorsOpenAt;
  final String timezone;
  final int? ageRestriction;
  final String? dressCode;
  final int maxCapacity;
  final bool isPrivate;
  final bool isOnline;
  final double? minPrice;
  final double? maxPrice;
  final String currency;
  final double? rating;
  final int? reviewCount;
  final int? attendeeCount;
  final List<String> attendeeAvatars;
  final String organizerId;
  final String? organizerName;
  final String? venueName;
  final String? venueCity;
  final bool isFavorited;
  final String? refundPolicy;
  final String createdAt;

  Event({
    required this.id,
    required this.title,
    required this.description,
    this.coverImageUrl,
    this.promoVideoUrl,
    required this.category,
    this.genreTags = const [],
    required this.status,
    required this.startDateTime,
    required this.endDateTime,
    this.doorsOpenAt,
    this.timezone = 'Africa/Nairobi',
    this.ageRestriction,
    this.dressCode,
    required this.maxCapacity,
    this.isPrivate = false,
    this.isOnline = false,
    this.minPrice,
    this.maxPrice,
    this.currency = 'KES',
    this.rating,
    this.reviewCount,
    this.attendeeCount,
    this.attendeeAvatars = const [],
    required this.organizerId,
    this.organizerName,
    this.venueName,
    this.venueCity,
    this.isFavorited = false,
    this.refundPolicy,
    required this.createdAt,
  });

  factory Event.fromJson(Map<String, dynamic> json) {
    List<String> parseStringList(dynamic val) {
      if (val == null) return [];
      if (val is List) return val.map((e) => e?.toString() ?? '').toList();
      return [];
    }

    return Event(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      coverImageUrl: json['coverImageUrl']?.toString(),
      promoVideoUrl: json['promoVideoUrl']?.toString(),
      category: json['category']?.toString() ?? '',
      genreTags: parseStringList(json['genreTags']),
      status: json['status']?.toString() ?? 'DRAFT',
      startDateTime: json['startDateTime'] != null
          ? DateTime.parse(json['startDateTime'].toString())
          : DateTime.now(),
      endDateTime: json['endDateTime'] != null
          ? DateTime.parse(json['endDateTime'].toString())
          : DateTime.now().add(const Duration(hours: 4)),
      doorsOpenAt: json['doorsOpenAt'] != null
          ? DateTime.parse(json['doorsOpenAt'].toString())
          : null,
      timezone: json['timezone']?.toString() ?? 'Africa/Nairobi',
      ageRestriction:
          int.tryParse(json['ageRestriction']?.toString() ?? ''),
      dressCode: json['dressCode']?.toString(),
      maxCapacity:
          int.tryParse(json['maxCapacity']?.toString() ?? '0') ?? 0,
      isPrivate: json['isPrivate'] == true,
      isOnline: json['isOnline'] == true,
      minPrice: double.tryParse(json['minPrice']?.toString() ?? ''),
      maxPrice: double.tryParse(json['maxPrice']?.toString() ?? ''),
      currency: json['currency']?.toString() ?? 'KES',
      rating: double.tryParse(json['rating']?.toString() ?? ''),
      reviewCount: int.tryParse(json['reviewCount']?.toString() ?? ''),
      attendeeCount: int.tryParse(json['attendeeCount']?.toString() ?? ''),
      attendeeAvatars: parseStringList(json['attendeeAvatars']),
      organizerId: json['organizerId']?.toString() ?? '',
      organizerName: json['organizerName']?.toString(),
      venueName: json['venueName']?.toString(),
      venueCity: json['venueCity']?.toString(),
      isFavorited: json['isFavorited'] == true,
      refundPolicy: json['refundPolicy']?.toString(),
      createdAt: json['createdAt']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'description': description,
        'coverImageUrl': coverImageUrl,
        'category': category,
        'status': status,
        'startDateTime': startDateTime.toIso8601String(),
        'endDateTime': endDateTime.toIso8601String(),
        'maxCapacity': maxCapacity,
        'isOnline': isOnline,
        'minPrice': minPrice,
        'currency': currency,
        'organizerId': organizerId,
        'createdAt': createdAt,
      };

  String get priceDisplay {
    if (minPrice == null || minPrice == 0) return 'Free';
    return '${currency} ${minPrice!.toStringAsFixed(0)}';
  }
}
