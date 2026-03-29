import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../home/domain/events_provider.dart';
import '../../../shared/widgets/event_card_small.dart';
import '../../../shared/widgets/category_chip.dart';
import '../../../core/theme/app_theme.dart';

class SearchScreen extends ConsumerStatefulWidget {
  final String? initialQuery;
  const SearchScreen({super.key, this.initialQuery});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final _searchCtrl = TextEditingController();
  final _focus = FocusNode();
  String _query = '';
  List<String> _recentSearches = [];
  String? _selectedCategory;
  bool? _onlineOnly;
  bool _freeOnly = false;

  @override
  void initState() {
    super.initState();
    if (widget.initialQuery != null && widget.initialQuery!.isNotEmpty) {
      _query = widget.initialQuery!;
      _searchCtrl.text = _query;
    }
    _loadRecent();
    WidgetsBinding.instance.addPostFrameCallback((_) => _focus.requestFocus());
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _focus.dispose();
    super.dispose();
  }

  Future<void> _loadRecent() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _recentSearches = prefs.getStringList('recent_searches') ?? [];
    });
  }

  Future<void> _saveSearch(String q) async {
    if (q.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList('recent_searches') ?? [];
    list.remove(q);
    list.insert(0, q);
    if (list.length > 8) list.removeLast();
    await prefs.setStringList('recent_searches', list);
    setState(() => _recentSearches = list);
  }

  Future<void> _clearRecent() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('recent_searches');
    setState(() => _recentSearches = []);
  }

  void _onSubmit(String q) {
    setState(() => _query = q.trim());
    _saveSearch(q.trim());
  }

  void _showFilters() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _FilterSheet(
        selectedCategory: _selectedCategory,
        onlineOnly: _onlineOnly,
        freeOnly: _freeOnly,
        onApply: (cat, online, free) {
          setState(() {
            _selectedCategory = cat;
            _onlineOnly = online;
            _freeOnly = free;
          });
          context.pop();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? kDarkBackground : kBackground;
    final textColor = isDark ? kDarkTextPrimary : kTextPrimary;
    final mutedColor = isDark ? kDarkTextMuted : kTextMuted;
    final surfaceColor = isDark ? kDarkSurface : kSurface;

    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: Column(
          children: [
            // Search bar row
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => context.pop(),
                    child: Icon(Icons.arrow_back_ios_new,
                        size: 20, color: textColor),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Container(
                      height: 46,
                      decoration: BoxDecoration(
                        color: surfaceColor,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isDark ? kDarkBorder : kBorder,
                          width: 0.8,
                        ),
                      ),
                      child: TextField(
                        controller: _searchCtrl,
                        focusNode: _focus,
                        textInputAction: TextInputAction.search,
                        onSubmitted: _onSubmit,
                        onChanged: (v) {
                          if (v.isEmpty) setState(() => _query = '');
                        },
                        style: GoogleFonts.inter(
                            fontSize: 14, color: textColor),
                        decoration: InputDecoration(
                          hintText: 'Search events...',
                          hintStyle: GoogleFonts.inter(
                              fontSize: 14, color: mutedColor),
                          prefixIcon:
                              Icon(Icons.search_rounded, color: mutedColor, size: 20),
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          contentPadding:
                              const EdgeInsets.symmetric(vertical: 13),
                          filled: false,
                          suffixIcon: _query.isNotEmpty
                              ? IconButton(
                                  icon: Icon(Icons.close_rounded,
                                      color: mutedColor, size: 18),
                                  onPressed: () {
                                    _searchCtrl.clear();
                                    setState(() => _query = '');
                                  },
                                )
                              : null,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: _showFilters,
                    child: Container(
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(
                        color: (_selectedCategory != null ||
                                _onlineOnly != null ||
                                _freeOnly)
                            ? kPrimary
                            : surfaceColor,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        Icons.tune_rounded,
                        color: (_selectedCategory != null ||
                                _onlineOnly != null ||
                                _freeOnly)
                            ? Colors.white
                            : mutedColor,
                        size: 20,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: _query.isNotEmpty
                  ? _SearchResults(
                      query: _query,
                      category: _selectedCategory,
                      isOnline: _onlineOnly,
                      freeOnly: _freeOnly,
                    )
                  : _NoQuery(
                      recentSearches: _recentSearches,
                      onRecentTap: (q) {
                        _searchCtrl.text = q;
                        _onSubmit(q);
                      },
                      onClearRecent: _clearRecent,
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SearchResults extends ConsumerWidget {
  final String query;
  final String? category;
  final bool? isOnline;
  final bool freeOnly;

  const _SearchResults({
    required this.query,
    this.category,
    this.isOnline,
    this.freeOnly = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filters = <String, dynamic>{
      'search': query,
      if (category != null) 'category': category,
      if (isOnline != null) 'isOnline': isOnline,
    };
    final resultsAsync = ref.watch(eventsProvider(filters));

    return resultsAsync.when(
      loading: () =>
          const Center(child: CircularProgressIndicator(color: kPrimary)),
      error: (e, _) => _Empty(
        icon: Icons.error_rounded,
        message: 'Something went wrong',
        sub: e.toString(),
      ),
      data: (events) {
        final filtered = freeOnly
            ? events.where((e) => e.minPrice == null || e.minPrice == 0).toList()
            : events;
        if (filtered.isEmpty) {
          return _Empty(
            icon: Icons.search_off_rounded,
            message: 'No events found',
            sub: 'Try different keywords or filters',
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          itemCount: filtered.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (_, i) {
            final ev = filtered[i];
            return EventCardSmall(
              event: ev,
              onTap: () => context.push('/event/${ev.id}'),
            );
          },
        );
      },
    );
  }
}

class _NoQuery extends StatelessWidget {
  final List<String> recentSearches;
  final ValueChanged<String> onRecentTap;
  final VoidCallback onClearRecent;

  const _NoQuery({
    required this.recentSearches,
    required this.onRecentTap,
    required this.onClearRecent,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? kDarkTextPrimary : kTextPrimary;
    final mutedColor = isDark ? kDarkTextMuted : kTextMuted;

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (recentSearches.isNotEmpty) ...[
            Row(
              children: [
                Text(
                  'Recent Searches',
                  style: GoogleFonts.inter(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: textColor,
                  ),
                ),
                const Spacer(),
                TextButton(
                  onPressed: onClearRecent,
                  child: Text(
                    'Clear',
                    style: GoogleFonts.inter(color: kPrimary, fontSize: 13),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: recentSearches
                  .map((q) => GestureDetector(
                        onTap: () => onRecentTap(q),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(
                            color: isDark ? kDarkSurface : kSurface,
                            borderRadius: BorderRadius.circular(50),
                            border: Border.all(
                              color: isDark ? kDarkBorder : kBorder,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.history_rounded,
                                  size: 14, color: mutedColor),
                              const SizedBox(width: 6),
                              Text(q,
                                  style: GoogleFonts.inter(
                                      fontSize: 13, color: textColor)),
                            ],
                          ),
                        ),
                      ))
                  .toList(),
            ),
            const SizedBox(height: 24),
          ],
          Text(
            'Trending',
            style: GoogleFonts.inter(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: textColor,
            ),
          ),
          const SizedBox(height: 12),
          Consumer(
            builder: (context, ref, _) {
              final featuredAsync = ref.watch(featuredEventsProvider);
              return featuredAsync.when(
                loading: () => const Center(
                    child: CircularProgressIndicator(color: kPrimary)),
                error: (_, __) => const SizedBox.shrink(),
                data: (events) => ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: events.take(5).length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (_, i) => EventCardSmall(
                    event: events[i],
                    onTap: () => context.push('/event/${events[i].id}'),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  final IconData icon;
  final String message;
  final String? sub;

  const _Empty({required this.icon, required this.message, this.sub});

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 52, color: dark ? kDarkTextMuted : kTextMuted),
            const SizedBox(height: 12),
            Text(
              message,
              style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: dark ? kDarkTextMuted : kTextMuted),
            ),
            if (sub != null) ...[
              const SizedBox(height: 6),
              Text(sub!,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                      fontSize: 13,
                      color: dark ? kDarkTextMuted : kTextMuted)),
            ],
          ],
        ),
      ),
    );
  }
}

class _FilterSheet extends StatefulWidget {
  final String? selectedCategory;
  final bool? onlineOnly;
  final bool freeOnly;
  final void Function(String? cat, bool? online, bool free) onApply;

  const _FilterSheet({
    required this.selectedCategory,
    required this.onlineOnly,
    required this.freeOnly,
    required this.onApply,
  });

  @override
  State<_FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends State<_FilterSheet> {
  String? _category;
  bool? _online;
  bool _free = false;

  static const _cats = [
    'FAMILY',
    'FESTIVAL',
    'CLUB_NIGHT',
    'CONCERT',
    'SPORTS',
    'NETWORKING',
    'ARTS',
    'FOOD',
  ];

  @override
  void initState() {
    super.initState();
    _category = widget.selectedCategory;
    _online = widget.onlineOnly;
    _free = widget.freeOnly;
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        color: dark ? kDarkSurface : kBackground,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(
          20, 20, 20, MediaQuery.of(context).padding.bottom + 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: dark ? kDarkBorder : kBorder,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text('Filters',
              style: GoogleFonts.inter(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: dark ? kDarkTextPrimary : kTextPrimary)),
          const SizedBox(height: 16),
          Text('Category',
              style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: dark ? kDarkTextPrimary : kTextPrimary)),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _cats
                .map((c) => CategoryChip(
                      label: c.replaceAll('_', ' '),
                      isSelected: _category == c,
                      onTap: () =>
                          setState(() => _category = _category == c ? null : c),
                    ))
                .toList(),
          ),
          const SizedBox(height: 20),
          Text('Event Type',
              style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: dark ? kDarkTextPrimary : kTextPrimary)),
          const SizedBox(height: 10),
          Row(
            children: [
              _toggle(
                  'Online', _online == true, () => setState(() {
                    _online = _online == true ? null : true;
                  })),
              const SizedBox(width: 8),
              _toggle(
                  'In-person', _online == false, () => setState(() {
                    _online = _online == false ? null : false;
                  })),
              const SizedBox(width: 8),
              _toggle(
                  'Free', _free, () => setState(() => _free = !_free)),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () {
                    setState(() {
                      _category = null;
                      _online = null;
                      _free = false;
                    });
                    widget.onApply(null, null, false);
                  },
                  child: const Text('Clear'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  onPressed: () => widget.onApply(_category, _online, _free),
                  style: FilledButton.styleFrom(
                      backgroundColor: kPrimary,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(50))),
                  child: const Text('Apply'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _toggle(String label, bool selected, VoidCallback onTap) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? kPrimary : Colors.transparent,
          borderRadius: BorderRadius.circular(50),
          border: Border.all(
            color: selected ? kPrimary : (dark ? kDarkBorder : kBorder),
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 13,
            color: selected
                ? Colors.white
                : (dark ? kDarkTextPrimary : kTextPrimary),
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }
}
