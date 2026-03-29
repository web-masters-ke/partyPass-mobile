import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/events_repository.dart';
import '../../../shared/models/event.dart';
import '../../../shared/models/ticket_tier.dart';
import '../../../shared/providers/auth_provider.dart';

final eventsRepositoryProvider =
    Provider((ref) => EventsRepository());

final selectedCategoryProvider = StateProvider<String>((ref) => 'All');

final eventsProvider =
    FutureProvider.family<List<Event>, Map<String, dynamic>>(
  (ref, filters) {
    final repo = ref.read(eventsRepositoryProvider);
    return repo.getEvents(
      category: filters['category'] as String?,
      search: filters['search'] as String?,
      isOnline: filters['isOnline'] as bool?,
    );
  },
);

final featuredEventsProvider = FutureProvider<List<Event>>((ref) {
  return ref.read(eventsRepositoryProvider).getFeaturedEvents();
});

final homeEventsProvider = FutureProvider<List<Event>>((ref) {
  final category = ref.watch(selectedCategoryProvider);
  return ref.read(eventsRepositoryProvider).getEvents(
        category: category == 'All' ? null : category,
      );
});

final eventDetailProvider =
    FutureProvider.family<Event, String>((ref, id) {
  return ref.read(eventsRepositoryProvider).getEventById(id);
});

final ticketTiersProvider =
    FutureProvider.family<List<TicketTier>, String>((ref, eventId) {
  return ref.read(eventsRepositoryProvider).getTicketTiers(eventId);
});

final favoritesProvider = FutureProvider<List<Event>>((ref) async {
  final user = await ref.watch(currentUserProvider.future);
  if (user == null) return [];
  return ref.read(eventsRepositoryProvider).getMyFavorites();
});
