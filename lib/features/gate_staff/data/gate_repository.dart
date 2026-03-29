import '../../../core/network/dio_client.dart';
import '../../../shared/models/gate_entry.dart';

class GateRepository {
  final _client = DioClient.instance;

  Future<GateEntry> scanQR(String qrCode, String gateId) async {
    final data = await _client.post<Map<String, dynamic>>(
      '/gates/$gateId/scan',
      data: {'qrCode': qrCode},
    );
    return GateEntry.fromJson(data);
  }

  Future<void> exitTicket(String ticketId, String gateId) async {
    await _client.post<dynamic>(
      '/gates/$gateId/exit',
      data: {'ticketId': ticketId},
    );
  }

  Future<Map<String, dynamic>> getDashboard(String eventId) async {
    final data = await _client
        .get<Map<String, dynamic>>('/events/$eventId/gate-dashboard');
    return data;
  }

  Future<GateEntry> overrideScan(
      String gateEntryId, String gateId, String pin) async {
    final data = await _client.post<Map<String, dynamic>>(
      '/gates/$gateId/override',
      data: {'gateEntryId': gateEntryId, 'pin': pin},
    );
    return GateEntry.fromJson(data);
  }

  Future<List<GateEntry>> getRecentScans(String eventId,
      {int limit = 20}) async {
    final data = await _client.get<dynamic>(
      '/events/$eventId/recent-scans',
      queryParameters: {'limit': limit},
    );
    if (data is List) {
      return data
          .map((e) => GateEntry.fromJson(e as Map<String, dynamic>))
          .toList();
    }
    return [];
  }
}
