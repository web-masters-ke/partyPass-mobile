class Order {
  final String id;
  final String userId;
  final String eventId;
  final String status;
  final double subtotal;
  final double platformFee;
  final double discount;
  final double total;
  final String currency;
  final String? paymentMethod;
  final String? paymentRef;
  final String? mpesaAccountRef;
  final String? paidAt;
  final String? expiresAt;
  final String createdAt;
  // Paybill instructions
  final String? paybill;

  Order({
    required this.id,
    required this.userId,
    required this.eventId,
    required this.status,
    required this.subtotal,
    required this.platformFee,
    required this.discount,
    required this.total,
    this.currency = 'KES',
    this.paymentMethod,
    this.paymentRef,
    this.mpesaAccountRef,
    this.paidAt,
    this.expiresAt,
    required this.createdAt,
    this.paybill,
  });

  bool get isPaid => status == 'PAID';
  bool get isPending => status == 'PENDING' || status == 'AWAITING_PAYMENT';
  bool get isExpired => status == 'EXPIRED' || status == 'CANCELLED';

  factory Order.fromJson(Map<String, dynamic> json) {
    return Order(
      id: json['id']?.toString() ?? '',
      userId: json['userId']?.toString() ?? '',
      eventId: json['eventId']?.toString() ?? '',
      status: json['status']?.toString() ?? 'PENDING',
      subtotal: double.tryParse(json['subtotal']?.toString() ?? '0') ?? 0.0,
      platformFee:
          double.tryParse(json['platformFee']?.toString() ?? '0') ?? 0.0,
      discount: double.tryParse(json['discount']?.toString() ?? '0') ?? 0.0,
      total: double.tryParse(json['total']?.toString() ?? '0') ?? 0.0,
      currency: json['currency']?.toString() ?? 'KES',
      paymentMethod: json['paymentMethod']?.toString(),
      paymentRef: json['paymentRef']?.toString(),
      mpesaAccountRef: json['mpesaAccountRef']?.toString(),
      paidAt: json['paidAt']?.toString(),
      expiresAt: json['expiresAt']?.toString(),
      createdAt: json['createdAt']?.toString() ?? '',
      paybill: json['paybill']?.toString(),
    );
  }
}
