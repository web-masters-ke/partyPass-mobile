import '../../../core/network/dio_client.dart';
import '../../../shared/models/event.dart';
import '../../../shared/models/ticket_tier.dart';

class EventsRepository {
  final _client = DioClient.instance;

  Future<List<Event>> getEvents({
    String? category,
    String? search,
    bool? isOnline,
    String? status,
    int page = 1,
    int limit = 20,
  }) async {
    final params = <String, dynamic>{
      'page': page,
      'limit': limit,
      if (category != null && category != 'All') 'category': category,
      if (search != null && search.isNotEmpty) 'search': search,
      if (isOnline != null) 'isOnline': isOnline,
      'status': status ?? 'PUBLISHED',
    };
    final data =
        await _client.get<Map<String, dynamic>>('/events', queryParameters: params);
    final items = data['items'] as List? ?? [];
    return items
        .map((e) => Event.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<Event> getEventById(String id) async {
    final data =
        await _client.get<Map<String, dynamic>>('/events/$id');
    return Event.fromJson(data);
  }

  Future<List<Event>> getFeaturedEvents() async {
    final data = await _client
        .get<Map<String, dynamic>>('/events', queryParameters: {
      'featured': true,
      'limit': 5,
      'status': 'PUBLISHED',
    });
    final items = data['items'] as List? ?? [];
    return items
        .map((e) => Event.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<List<Event>> getMyFavorites() async {
    final data =
        await _client.get<Map<String, dynamic>>('/users/me/favorites');
    final items = data['items'] as List? ?? data as List? ?? [];
    if (data is List) {
      return (data as List)
          .map((e) => Event.fromJson(e as Map<String, dynamic>))
          .toList();
    }
    return items
        .map((e) => Event.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<List<TicketTier>> getTicketTiers(String eventId) async {
    final data = await _client
        .get<dynamic>('/events/$eventId/ticket-tiers');
    if (data is List) {
      return data
          .map((e) => TicketTier.fromJson(e as Map<String, dynamic>))
          .toList();
    }
    return [];
  }

  Future<void> toggleFavorite(String eventId) async {
    await _client.post<dynamic>('/events/$eventId/favorite');
  }
}
