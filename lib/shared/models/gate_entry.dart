import 'user.dart';
import 'ticket.dart';

class GateEntry {
  final String id;
  final String ticketId;
  final String eventId;
  final String gateId;
  final String scannedById;
  final String action;
  final String result;
  final String? denyReason;
  final int entryNumber;
  final String? scanDeviceId;
  final String? overriddenBy;
  final String scannedAt;
  final Ticket? ticket;
  final User? attendee;

  GateEntry({
    required this.id,
    required this.ticketId,
    required this.eventId,
    required this.gateId,
    required this.scannedById,
    required this.action,
    required this.result,
    this.denyReason,
    required this.entryNumber,
    this.scanDeviceId,
    this.overriddenBy,
    required this.scannedAt,
    this.ticket,
    this.attendee,
  });

  bool get isApproved =>
      result == 'APPROVED' ||
      result == 'OVERRIDE_APPROVED' ||
      action == 'RE_ENTRY';
  bool get isDenied => result.startsWith('DENIED');
  bool get isReEntry => action == 'RE_ENTRY';

  String get resultDisplayText {
    if (result == 'APPROVED') return 'APPROVED';
    if (result == 'OVERRIDE_APPROVED') return 'APPROVED (OVERRIDE)';
    if (action == 'RE_ENTRY') return 'RE-ENTRY #$entryNumber';
    if (result == 'DENIED_DUPLICATE') return 'Already inside venue';
    if (result == 'DENIED_USED') return 'Ticket already used';
    if (result == 'DENIED_CANCELLED') return 'Ticket cancelled';
    if (result == 'DENIED_WRONG_EVENT') return 'Wrong event';
    if (result == 'DENIED_REENTRY_NOT_ALLOWED') return 'Re-entry not allowed';
    if (result == 'DENIED_EXPIRED') return 'Ticket expired';
    if (result == 'DENIED_BLACKLISTED') return 'Attendee blacklisted';
    return denyReason ?? result;
  }

  factory GateEntry.fromJson(Map<String, dynamic> json) {
    return GateEntry(
      id: json['id']?.toString() ?? '',
      ticketId: json['ticketId']?.toString() ?? '',
      eventId: json['eventId']?.toString() ?? '',
      gateId: json['gateId']?.toString() ?? '',
      scannedById: json['scannedById']?.toString() ?? '',
      action: json['action']?.toString() ?? 'ENTRY',
      result: json['result']?.toString() ?? 'DENIED',
      denyReason: json['denyReason']?.toString(),
      entryNumber: int.tryParse(json['entryNumber']?.toString() ?? '1') ?? 1,
      scanDeviceId: json['scanDeviceId']?.toString(),
      overriddenBy: json['overriddenBy']?.toString(),
      scannedAt: json['scannedAt']?.toString() ?? '',
      ticket: json['ticket'] != null
          ? Ticket.fromJson(json['ticket'] as Map<String, dynamic>)
          : null,
      attendee: json['attendee'] != null
          ? User.fromJson(json['attendee'] as Map<String, dynamic>)
          : null,
    );
  }
}
