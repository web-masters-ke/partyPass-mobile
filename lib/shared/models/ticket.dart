import 'ticket_tier.dart';
import 'event.dart';

class Ticket {
  final String id;
  final String ticketTierId;
  final String orderId;
  final String userId;
  final String eventId;
  final String qrCode;
  final String status;
  final int entryCount;
  final String? lastEntryAt;
  final String? lastExitAt;
  final String currentStatus;
  final String? transferredFrom;
  final String? holderName;
  final String? holderEmail;
  final String? holderPhone;
  final String createdAt;
  final TicketTier? tier;
  final Event? event;

  Ticket({
    required this.id,
    required this.ticketTierId,
    required this.orderId,
    required this.userId,
    required this.eventId,
    required this.qrCode,
    required this.status,
    this.entryCount = 0,
    this.lastEntryAt,
    this.lastExitAt,
    this.currentStatus = 'OUTSIDE',
    this.transferredFrom,
    this.holderName,
    this.holderEmail,
    this.holderPhone,
    required this.createdAt,
    this.tier,
    this.event,
  });

  bool get isValid => status == 'VALID';
  bool get isUpcoming =>
      event != null && event!.startDateTime.isAfter(DateTime.now());

  String get shortId => id.length > 8 ? 'PP-${id.substring(id.length - 8).toUpperCase()}' : id;

  factory Ticket.fromJson(Map<String, dynamic> json) {
    return Ticket(
      id: json['id']?.toString() ?? '',
      ticketTierId: json['ticketTierId']?.toString() ?? '',
      orderId: json['orderId']?.toString() ?? '',
      userId: json['userId']?.toString() ?? '',
      eventId: json['eventId']?.toString() ?? '',
      qrCode: json['qrCode']?.toString() ?? '',
      status: json['status']?.toString() ?? 'VALID',
      entryCount: int.tryParse(json['entryCount']?.toString() ?? '0') ?? 0,
      lastEntryAt: json['lastEntryAt']?.toString(),
      lastExitAt: json['lastExitAt']?.toString(),
      currentStatus: json['currentStatus']?.toString() ?? 'OUTSIDE',
      transferredFrom: json['transferredFrom']?.toString(),
      holderName: json['holderName']?.toString(),
      holderEmail: json['holderEmail']?.toString(),
      holderPhone: json['holderPhone']?.toString(),
      createdAt: json['createdAt']?.toString() ?? '',
      tier: json['tier'] != null
          ? TicketTier.fromJson(json['tier'] as Map<String, dynamic>)
          : null,
      event: json['event'] != null
          ? Event.fromJson(json['event'] as Map<String, dynamic>)
          : null,
    );
  }
}
