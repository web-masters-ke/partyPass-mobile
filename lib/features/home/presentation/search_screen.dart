import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../home/data/events_repository.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/models/event.dart';
import '../../../shared/widgets/event_card_small.dart';
import '../../../shared/widgets/category_chip.dart';
import '../../../shared/widgets/loading_shimmer.dart';

class SearchScreen extends ConsumerStatefulWidget {
  final String? initialQuery;
  final bool autoLoad;
  const SearchScreen({super.key, this.initialQuery, this.autoLoad = false});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final _searchCtrl = TextEditingController();
  final _repo = EventsRepository();

  String _selectedCategory = 'All';
  List<Event> _results = [];
  bool _loading = false;
  bool _searched = false;

  static const _categories = [
    'All', 'CLUB_NIGHT', 'FESTIVAL', 'CONCERT',
    'COMEDY', 'SPORTS', 'CORPORATE', 'BOAT_PARTY',
  ];
  static const _categoryLabels = {
    'All': 'All',
    'CLUB_NIGHT': 'Club Nights',
    'FESTIVAL': 'Festivals',
    'CONCERT': 'Concerts',
    'COMEDY': 'Comedy',
    'SPORTS': 'Sports',
    'CORPORATE': 'Corporate',
    'BOAT_PARTY': 'Boat Party',
  };

  @override
  void initState() {
    super.initState();
    if (widget.initialQuery != null) {
      _searchCtrl.text = widget.initialQuery!;
      _search();
    } else if (widget.autoLoad) {
      _search();
    }
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    setState(() { _loading = true; _searched = true; });
    try {
      final results = await _repo.getEvents(
        search: _searchCtrl.text.trim().isEmpty ? null : _searchCtrl.text.trim(),
        category: _selectedCategory == 'All' ? null : _selectedCategory,
      );
      if (mounted) setState(() { _results = results; _loading = false; });
    } catch (_) {
      if (mounted) setState(() { _results = []; _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: widget.autoLoad
            ? null
            : IconButton(
                icon: const Icon(Icons.arrow_back_ios_new, size: 20),
                onPressed: () => context.pop(),
              ),
        automaticallyImplyLeading: false,
        title: TextField(
          controller: _searchCtrl,
          autofocus: widget.initialQuery == null,
          textInputAction: TextInputAction.search,
          onSubmitted: (_) => _search(),
          decoration: InputDecoration(
            hintText: 'Search events, venues...',
            hintStyle: GoogleFonts.inter(color: kTextMuted, fontSize: 14),
            border: InputBorder.none,
            enabledBorder: InputBorder.none,
            focusedBorder: InputBorder.none,
            filled: false,
            contentPadding: EdgeInsets.zero,
            suffixIcon: _searchCtrl.text.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear_rounded, size: 18, color: kTextMuted),
                    onPressed: () { _searchCtrl.clear(); setState(() { _results = []; _searched = false; }); },
                  )
                : null,
          ),
          style: GoogleFonts.inter(fontSize: 16, color: kTextPrimary),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.search_rounded),
            onPressed: _search,
          ),
        ],
      ),
      body: Column(
        children: [
          // Category filter
          SizedBox(
            height: 48,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              itemCount: _categories.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (_, i) {
                final cat = _categories[i];
                return CategoryChip(
                  label: _categoryLabels[cat] ?? cat,
                  isSelected: _selectedCategory == cat,
                  onTap: () {
                    setState(() => _selectedCategory = cat);
                    _search();
                  },
                );
              },
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: _loading
                ? const LoadingShimmer()
                : !_searched
                    ? _buildSuggestions()
                    : _results.isEmpty
                        ? Builder(
                            builder: (context) {
                              final dark = Theme.of(context).brightness == Brightness.dark;
                              return Center(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.search_off_rounded, size: 48, color: dark ? kDarkTextMuted : kTextMuted),
                                    const SizedBox(height: 12),
                                    Text('No events found',
                                        style: GoogleFonts.inter(
                                            color: dark ? kDarkTextMuted : kTextMuted, fontSize: 16)),
                                    const SizedBox(height: 8),
                                    Text('Try a different search or category',
                                        style: GoogleFonts.inter(color: dark ? kDarkTextMuted : kTextMuted, fontSize: 13)),
                                  ],
                                ),
                              );
                            },
                          )
                        : GridView.builder(
                            padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 2,
                              crossAxisSpacing: 12,
                              mainAxisSpacing: 12,
                              childAspectRatio: 0.85,
                            ),
                            itemCount: _results.length,
                            itemBuilder: (_, i) => EventCardSmall(
                              event: _results[i],
                              onTap: () => context.push('/event/${_results[i].id}'),
                            ),
                          ),
          ),
        ],
      ),
    );
  }

  Widget _buildSuggestions() {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final suggestions = ['Afro Fridays', 'Club Night', 'Festival', 'Comedy Show', 'Boat Party'];
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('Popular searches',
            style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: dark ? kDarkTextMuted : kTextMuted)),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: suggestions.map((s) => GestureDetector(
            onTap: () { _searchCtrl.text = s; _search(); },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: dark ? kDarkSurface : kSurface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: dark ? kDarkBorder : kBorder),
              ),
              child: Text(s, style: GoogleFonts.inter(fontSize: 13, color: dark ? kDarkTextPrimary : kTextPrimary)),
            ),
          )).toList(),
        ),
      ],
    );
  }
}
