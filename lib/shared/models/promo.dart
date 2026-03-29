class Promo {
  final String id;
  final String code;
  final String discountType;
  final double discountValue;
  final double? minOrderAmount;
  final int? usageLimit;
  final int usageCount;
  final String? expiresAt;
  final bool isActive;
  final String createdAt;

  Promo({
    required this.id,
    required this.code,
    required this.discountType,
    required this.discountValue,
    this.minOrderAmount,
    this.usageLimit,
    this.usageCount = 0,
    this.expiresAt,
    this.isActive = true,
    required this.createdAt,
  });

  bool get isPercentage => discountType == 'PERCENTAGE';

  double applyDiscount(double amount) {
    if (isPercentage) {
      return amount * (discountValue / 100);
    }
    return discountValue.clamp(0, amount);
  }

  factory Promo.fromJson(Map<String, dynamic> json) {
    return Promo(
      id: json['id']?.toString() ?? '',
      code: json['code']?.toString() ?? '',
      discountType: json['discountType']?.toString() ?? 'FIXED',
      discountValue:
          double.tryParse(json['discountValue']?.toString() ?? '0') ?? 0.0,
      minOrderAmount:
          double.tryParse(json['minOrderAmount']?.toString() ?? ''),
      usageLimit: int.tryParse(json['usageLimit']?.toString() ?? ''),
      usageCount:
          int.tryParse(json['usageCount']?.toString() ?? '0') ?? 0,
      expiresAt: json['expiresAt']?.toString(),
      isActive: json['isActive'] != false,
      createdAt: json['createdAt']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'code': code,
        'discountType': discountType,
        'discountValue': discountValue,
        'usageLimit': usageLimit,
        'expiresAt': expiresAt,
        'isActive': isActive,
        'createdAt': createdAt,
      };
}
