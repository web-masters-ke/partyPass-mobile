import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/app_snackbar.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Role meta data
// ─────────────────────────────────────────────────────────────────────────────

const _kRoles = [
  (value: 'MANAGER',    label: 'Manager',    icon: Icons.manage_accounts_rounded,   color: Color(0xFF7C3AED)),
  (value: 'SCANNER',    label: 'Scanner',    icon: Icons.qr_code_scanner_rounded,   color: Color(0xFF2563EB)),
  (value: 'BOX_OFFICE', label: 'Box Office', icon: Icons.point_of_sale_rounded,     color: Color(0xFF16A34A)),
  (value: 'SECURITY',   label: 'Security',   icon: Icons.security_rounded,          color: Color(0xFFDC2626)),
  (value: 'HOST',       label: 'Host',       icon: Icons.record_voice_over_rounded, color: Color(0xFF0D9488)),
  (value: 'BARTENDER',  label: 'Bartender',  icon: Icons.local_bar_rounded,         color: Color(0xFFD97706)),
];

const _kCriticalRoles = ['MANAGER', 'SECURITY', 'SCANNER'];

Color _roleColor(String role) =>
    _kRoles.firstWhere((r) => r.value == role, orElse: () => _kRoles[1]).color;

String _roleLabel(String role) =>
    _kRoles.firstWhere((r) => r.value == role, orElse: () => _kRoles[1]).label;

IconData _roleIcon(String role) =>
    _kRoles.firstWhere((r) => r.value == role, orElse: () => _kRoles[1]).icon;

Widget _buildRoleBadge(String role, {double fontSize = 10}) {
  final color = _roleColor(role);
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(_roleIcon(role), size: fontSize + 2, color: color),
        const SizedBox(width: 4),
        Text(
          _roleLabel(role),
          style: GoogleFonts.inter(fontSize: fontSize, fontWeight: FontWeight.w700, color: color),
        ),
      ],
    ),
  );
}

Widget _buildAvatar(Map<String, dynamic> user, {double size = 40}) {
  final first = (user['firstName'] as String? ?? '').isNotEmpty
      ? (user['firstName'] as String)[0]
      : '?';
  final last = (user['lastName'] as String? ?? '').isNotEmpty
      ? (user['lastName'] as String)[0]
      : '';
  final initials = '$first$last'.toUpperCase();
  final role = user['role'] as String? ?? '';
  final color = role.isNotEmpty ? _roleColor(role) : kPrimary;

  final avatarUrl = user['avatarUrl'] as String?;
  if (avatarUrl != null && avatarUrl.isNotEmpty) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(size / 2),
      child: Image.network(
        avatarUrl,
        width: size, height: size,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _fallbackAvatar(initials, color, size),
      ),
    );
  }
  return _fallbackAvatar(initials, color, size);
}

Widget _fallbackAvatar(String initials, Color color, double size) {
  return Container(
    width: size, height: size,
    decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(size / 2)),
    alignment: Alignment.center,
    child: Text(
      initials,
      style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w700, fontSize: size * 0.37),
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// Main Screen
// ─────────────────────────────────────────────────────────────────────────────

class ManageStaffScreen extends ConsumerStatefulWidget {
  const ManageStaffScreen({super.key});

  @override
  ConsumerState<ManageStaffScreen> createState() => _ManageStaffScreenState();
}

class _ManageStaffScreenState extends ConsumerState<ManageStaffScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;

  // All members state
  List<Map<String, dynamic>> _members = [];
  bool _membersLoading = true;
  String _searchQuery = '';
  String _roleFilter = 'ALL';
  String _statusFilter = 'ALL'; // ALL | ACTIVE | SUSPENDED
  Set<String> _expanded = {};

  // Stats
  int _totalCount = 0;
  int _activeCount = 0;
  int _suspendedCount = 0;
  Map<String, int> _roleBreakdown = {};

  // By Event state
  List<Map<String, dynamic>> _events = [];
  String? _selectedEventId;
  List<Map<String, dynamic>> _eventStaff = [];
  bool _eventsLoading = true;
  bool _eventStaffLoading = false;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
    _loadAll();
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  // ── Data loading ───────────────────────────────────────────────────────────

  Future<void> _loadAll() async {
    await Future.wait([_loadMembers(), _loadEvents(), _loadStats()]);
  }

  Future<void> _loadMembers() async {
    setState(() => _membersLoading = true);
    try {
      final data = await DioClient.instance.get<dynamic>('/users/my-team');
      if (mounted) {
        setState(() {
          _members = List<Map<String, dynamic>>.from(data as List? ?? []);
          _membersLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _membersLoading = false);
    }
  }

  Future<void> _loadStats() async {
    try {
      final data = await DioClient.instance.get<dynamic>('/users/my-team/stats');
      if (mounted && data is Map<String, dynamic>) {
        setState(() {
          _totalCount = (data['total'] as int?) ?? 0;
          _activeCount = (data['active'] as int?) ?? 0;
          _suspendedCount = (data['suspended'] as int?) ?? 0;
          _roleBreakdown = Map<String, int>.from(
              (data['roleBreakdown'] as Map?)?.map((k, v) => MapEntry(k.toString(), v as int)) ?? {});
        });
      }
    } catch (_) {}
  }

  Future<void> _loadEvents() async {
    setState(() => _eventsLoading = true);
    try {
      final data = await DioClient.instance.get<dynamic>('/organizer/events');
      List<Map<String, dynamic>> items;
      if (data is List) {
        items = data.cast<Map<String, dynamic>>();
      } else if (data is Map<String, dynamic>) {
        items = ((data['items'] as List?) ?? []).cast<Map<String, dynamic>>();
      } else {
        items = [];
      }
      if (mounted) {
        setState(() {
          _events = items;
          _eventsLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _eventsLoading = false);
    }
  }

  Future<void> _loadEventStaff(String eventId) async {
    setState(() => _eventStaffLoading = true);
    try {
      final data = await DioClient.instance.get<dynamic>('/events/$eventId/staff');
      if (mounted) {
        setState(() {
          _eventStaff = List<Map<String, dynamic>>.from(data as List? ?? []);
          _eventStaffLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _eventStaffLoading = false);
    }
  }

  // ── Filtered list ──────────────────────────────────────────────────────────

  List<Map<String, dynamic>> get _filteredMembers {
    return _members.where((m) {
      final name = '${m['firstName'] ?? ''} ${m['lastName'] ?? ''}'.toLowerCase();
      final email = (m['email'] as String? ?? '').toLowerCase();
      final phone = m['phone'] as String? ?? '';
      final badge = (m['badgeNumber'] as String? ?? '').toLowerCase();
      final q = _searchQuery.toLowerCase();

      if (q.isNotEmpty && !name.contains(q) && !email.contains(q) && !phone.contains(q) && !badge.contains(q)) return false;

      if (_statusFilter == 'ACTIVE' && m['isActive'] != true) return false;
      if (_statusFilter == 'SUSPENDED' && m['isActive'] == true) return false;

      if (_roleFilter != 'ALL') {
        final assignments = (m['assignments'] as List?)?.cast<Map<String, dynamic>>() ?? [];
        final hasRole = assignments.any((a) => a['role'] == _roleFilter) || m['role'] == _roleFilter;
        if (!hasRole) return false;
      }

      return true;
    }).toList();
  }

  String _primaryRole(Map<String, dynamic> m) {
    final assignments = (m['assignments'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    if (assignments.isEmpty) return m['role'] as String? ?? '';
    final counts = <String, int>{};
    for (final a in assignments) {
      final r = a['role'] as String? ?? '';
      counts[r] = (counts[r] ?? 0) + 1;
    }
    return (counts.entries.toList()..sort((a, b) => b.value.compareTo(a.value))).first.key;
  }

  // ── Actions ────────────────────────────────────────────────────────────────

  Future<void> _setMemberStatus(String userId, bool isActive) async {
    try {
      await DioClient.instance.patch<dynamic>('/users/$userId/status', data: {'isActive': isActive});
      if (mounted) {
        AppSnackbar.showSuccess(context, isActive ? 'Member activated' : 'Member suspended');
        _loadAll();
      }
    } catch (e) {
      if (mounted) AppSnackbar.showError(context, e.toString());
    }
  }

  Future<void> _changeRole(String assignmentId, String newRole) async {
    try {
      await DioClient.instance.patch<dynamic>('/users/assignments/$assignmentId/role', data: {'role': newRole});
      if (mounted) {
        AppSnackbar.showSuccess(context, 'Role updated');
        _loadMembers();
      }
    } catch (e) {
      if (mounted) AppSnackbar.showError(context, e.toString());
    }
  }

  Future<void> _removeFromEvent(String eventId, String assignmentId) async {
    try {
      await DioClient.instance.delete<dynamic>('/events/$eventId/staff/$assignmentId');
      if (mounted) {
        AppSnackbar.showSuccess(context, 'Removed from event');
        _loadEventStaff(eventId);
        _loadMembers();
      }
    } catch (e) {
      if (mounted) AppSnackbar.showError(context, e.toString());
    }
  }

  // ── Bottom sheets ──────────────────────────────────────────────────────────

  void _openAddWizard() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _AddMemberWizard(events: _events, onDone: _loadAll),
    );
  }

  void _openProfile(Map<String, dynamic> member) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _StaffProfileSheet(
        userId: member['id'] as String,
        events: _events,
        onUpdated: _loadAll,
      ),
    );
  }

  void _showRoleChangeDialog(Map<String, dynamic> assignment) {
    String selectedRole = assignment['role'] as String? ?? 'SCANNER';
    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setD) => AlertDialog(
          backgroundColor: kSurface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text('Change Role', style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: _kRoles.map((r) => RadioListTile<String>(
              dense: true,
              value: r.value,
              groupValue: selectedRole,
              onChanged: (v) => setD(() => selectedRole = v!),
              title: Row(children: [
                Icon(r.icon, size: 16, color: r.color),
                const SizedBox(width: 8),
                Text(r.label, style: GoogleFonts.inter(fontSize: 13)),
              ]),
            )).toList(),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('Cancel', style: GoogleFonts.inter(color: kTextMuted)),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: kPrimary,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(50)),
              ),
              onPressed: () {
                Navigator.pop(ctx);
                _changeRole(assignment['assignmentId'] as String, selectedRole);
              },
              child: Text('Save', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w700)),
            ),
          ],
        ),
      ),
    );
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: dark ? kDarkBackground : kBackground,
      body: NestedScrollView(
        headerSliverBuilder: (_, __) => [
          SliverAppBar(
            pinned: true,
            backgroundColor: dark ? kDarkBackground : kBackground,
            foregroundColor: dark ? kDarkTextPrimary : kTextPrimary,
            title: Text('My Team', style: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 20, color: dark ? kDarkTextPrimary : kTextPrimary)),
            actions: [
              IconButton(
                icon: const Icon(Icons.refresh_rounded),
                onPressed: _loadAll,
                color: dark ? kDarkTextMuted : kTextMuted,
              ),
              Padding(
                padding: const EdgeInsets.only(right: 12),
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: kPrimary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    textStyle: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700),
                  ),
                  icon: const Icon(Icons.person_add_rounded, size: 15),
                  label: const Text('Add'),
                  onPressed: _openAddWizard,
                ),
              ),
            ],
            bottom: TabBar(
              controller: _tabs,
              indicatorColor: kPrimary,
              labelColor: kPrimary,
              unselectedLabelColor: dark ? kDarkTextMuted : kTextMuted,
              labelStyle: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 13),
              unselectedLabelStyle: GoogleFonts.inter(fontWeight: FontWeight.w500, fontSize: 13),
              tabs: const [Tab(text: 'All Members'), Tab(text: 'By Event')],
            ),
          ),
        ],
        body: TabBarView(
          controller: _tabs,
          children: [
            _buildAllMembersTab(),
            _buildByEventTab(),
          ],
        ),
      ),
    );
  }

  // ── All Members Tab ────────────────────────────────────────────────────────

  Widget _buildAllMembersTab() {
    return RefreshIndicator(
      color: kPrimary,
      onRefresh: _loadAll,
      child: CustomScrollView(
        slivers: [
          // Stats
          SliverToBoxAdapter(child: _buildStatsRow()),

          // Role breakdown chips
          if (_roleBreakdown.isNotEmpty)
            SliverToBoxAdapter(child: _buildRoleBreakdown()),

          // Search + filters
          SliverToBoxAdapter(child: _buildSearchAndFilters()),

          // Members list
          if (_membersLoading)
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (_, i) => Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  child: _shimmerCard(),
                ),
                childCount: 5,
              ),
            )
          else if (_filteredMembers.isEmpty)
            SliverFillRemaining(child: _buildEmptyState())
          else
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (_, i) => Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  child: _buildMemberCard(_filteredMembers[i]),
                ),
                childCount: _filteredMembers.length,
              ),
            ),

          const SliverToBoxAdapter(child: SizedBox(height: 100)),
        ],
      ),
    );
  }

  Widget _buildStatsRow() {
    final total = _totalCount > 0 ? _totalCount : _members.length;
    final active = _activeCount > 0 ? _activeCount : _members.where((m) => m['isActive'] == true).length;
    final suspended = _suspendedCount > 0 ? _suspendedCount : _members.where((m) => m['isActive'] != true).length;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Row(
        children: [
          _statCard('Total', total.toString(), kPrimary, Icons.groups_rounded),
          const SizedBox(width: 8),
          _statCard('Active', active.toString(), const Color(0xFF16A34A), Icons.check_circle_outline_rounded),
          const SizedBox(width: 8),
          _statCard('Suspended', suspended.toString(), const Color(0xFFD97706), Icons.pause_circle_outline_rounded),
        ],
      ),
    );
  }

  Widget _statCard(String label, String value, Color color, IconData icon) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        decoration: BoxDecoration(
          color: dark ? kDarkSurface : kSurface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: dark ? kDarkBorder : kBorder),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(height: 8),
            Text(value, style: GoogleFonts.inter(fontSize: 22, fontWeight: FontWeight.w900, color: dark ? kDarkTextPrimary : kTextPrimary)),
            const SizedBox(height: 2),
            Text(label, style: GoogleFonts.inter(fontSize: 11, color: dark ? kDarkTextMuted : kTextMuted)),
          ],
        ),
      ),
    );
  }

  Widget _buildRoleBreakdown() {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: dark ? kDarkSurface : kSurface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: dark ? kDarkBorder : kBorder),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Roles', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: dark ? kDarkTextMuted : kTextMuted, letterSpacing: 0.8)),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _roleBreakdown.entries.map((e) {
                final color = _roleColor(e.key);
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: color.withValues(alpha: 0.25)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(_roleIcon(e.key), size: 12, color: color),
                      const SizedBox(width: 5),
                      Text(
                        '${_roleLabel(e.key)}  ${e.value}',
                        style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: color),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchAndFilters() {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Search field
          Container(
            decoration: BoxDecoration(
              color: dark ? kDarkSurface : kSurface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: dark ? kDarkBorder : kBorder),
            ),
            child: Row(
              children: [
                const Padding(padding: EdgeInsets.only(left: 12), child: Icon(Icons.search_rounded, color: Color(0xFF9CA3AF), size: 18)),
                Expanded(
                  child: TextField(
                    onChanged: (v) => setState(() => _searchQuery = v),
                    style: GoogleFonts.inter(fontSize: 14, color: dark ? kDarkTextPrimary : kTextPrimary),
                    decoration: InputDecoration(
                      hintText: 'Search by name, email, phone, badge…',
                      hintStyle: GoogleFonts.inter(fontSize: 13, color: dark ? kDarkTextMuted : kTextMuted),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                    ),
                  ),
                ),
                if (_searchQuery.isNotEmpty)
                  IconButton(
                    icon: const Icon(Icons.clear_rounded, size: 16, color: Color(0xFF9CA3AF)),
                    onPressed: () => setState(() => _searchQuery = ''),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          // Role filter chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _filterChip('ALL', 'All Roles', Icons.groups_rounded),
                const SizedBox(width: 6),
                ..._kRoles.map((r) => Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: _filterChip(r.value, r.label, r.icon),
                )),
              ],
            ),
          ),
          const SizedBox(height: 8),
          // Status filter
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _statusChip('ALL', 'All'),
                const SizedBox(width: 6),
                _statusChip('ACTIVE', 'Active'),
                const SizedBox(width: 6),
                _statusChip('SUSPENDED', 'Suspended'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _filterChip(String value, String label, IconData icon) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final selected = _roleFilter == value;
    final color = value != 'ALL' ? _roleColor(value) : kPrimary;
    return GestureDetector(
      onTap: () => setState(() => _roleFilter = value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? color.withValues(alpha: 0.12) : (dark ? kDarkSurface : kSurface),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: selected ? color : (dark ? kDarkBorder : kBorder)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 12, color: selected ? color : (dark ? kDarkTextMuted : kTextMuted)),
            const SizedBox(width: 5),
            Text(label, style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: selected ? color : (dark ? kDarkTextMuted : kTextMuted))),
          ],
        ),
      ),
    );
  }

  Widget _statusChip(String value, String label) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final selected = _statusFilter == value;
    return GestureDetector(
      onTap: () => setState(() => _statusFilter = value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? kPrimary.withValues(alpha: 0.1) : (dark ? kDarkSurface : kSurface),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: selected ? kPrimary : (dark ? kDarkBorder : kBorder)),
        ),
        child: Text(
          label,
          style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: selected ? kPrimary : (dark ? kDarkTextMuted : kTextMuted)),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final hasFilter = _searchQuery.isNotEmpty || _roleFilter != 'ALL' || _statusFilter != 'ALL';
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(hasFilter ? Icons.search_off_rounded : Icons.group_add_rounded, size: 52, color: dark ? kDarkTextMuted : kTextMuted),
            const SizedBox(height: 16),
            Text(
              hasFilter ? 'No results found' : 'No team members yet',
              style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w800, color: dark ? kDarkTextPrimary : kTextPrimary),
            ),
            const SizedBox(height: 8),
            Text(
              hasFilter
                  ? 'Try adjusting your filters or search.'
                  : 'Add staff to manage gate access, box office, and event operations.',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(fontSize: 13, color: dark ? kDarkTextMuted : kTextMuted),
            ),
            if (!hasFilter) ...[
              const SizedBox(height: 24),
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: kPrimary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                icon: const Icon(Icons.person_add_rounded, size: 16),
                label: Text('Add First Member', style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
                onPressed: _openAddWizard,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildMemberCard(Map<String, dynamic> m) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final userId = m['id'] as String? ?? '';
    final firstName = m['firstName'] as String? ?? '';
    final lastName = m['lastName'] as String? ?? '';
    final fullName = '$firstName $lastName'.trim();
    final email = m['email'] as String?;
    final phone = m['phone'] as String?;
    final isActive = m['isActive'] as bool? ?? true;
    final badgeNumber = m['badgeNumber'] as String?;
    final assignments = (m['assignments'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    final role = _primaryRole(m);
    final isExpanded = _expanded.contains(userId);

    return GestureDetector(
      onTap: () => _openProfile(m),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        decoration: BoxDecoration(
          color: dark ? kDarkSurface : kSurface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: isExpanded ? kPrimary.withValues(alpha: 0.4) : (dark ? kDarkBorder : kBorder)),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 8, offset: const Offset(0, 2))],
        ),
        child: Column(
          children: [
            // Main row
            Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  Stack(
                    children: [
                      _buildAvatar(m, size: 46),
                      Positioned(
                        bottom: 0, right: 0,
                        child: Container(
                          width: 12, height: 12,
                          decoration: BoxDecoration(
                            color: isActive ? const Color(0xFF22C55E) : const Color(0xFFF59E0B),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: dark ? kDarkSurface : kSurface, width: 2),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: [
                          Flexible(
                            child: Text(
                              fullName.isEmpty ? 'Unknown' : fullName,
                              style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700, color: dark ? kDarkTextPrimary : kTextPrimary),
                              maxLines: 1, overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (!isActive) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(color: const Color(0xFFFEF3C7), borderRadius: BorderRadius.circular(10)),
                              child: Text('Suspended', style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.w700, color: const Color(0xFFD97706))),
                            ),
                          ],
                        ]),
                        const SizedBox(height: 4),
                        Row(children: [
                          if (role.isNotEmpty) _buildRoleBadge(role, fontSize: 9),
                          if (badgeNumber != null) ...[
                            const SizedBox(width: 6),
                            Row(children: [
                              Icon(Icons.tag_rounded, size: 10, color: dark ? kDarkTextMuted : kTextMuted),
                              Text(badgeNumber, style: GoogleFonts.inter(fontSize: 10, color: dark ? kDarkTextMuted : kTextMuted)),
                            ]),
                          ],
                        ]),
                        const SizedBox(height: 3),
                        Text(
                          email ?? phone ?? '',
                          style: GoogleFonts.inter(fontSize: 11, color: dark ? kDarkTextMuted : kTextMuted),
                          maxLines: 1, overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '${assignments.length} event${assignments.length != 1 ? 's' : ''}',
                        style: GoogleFonts.inter(fontSize: 11, color: dark ? kDarkTextMuted : kTextMuted, fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 6),
                      GestureDetector(
                        onTap: () => setState(() {
                          if (isExpanded) _expanded.remove(userId); else _expanded.add(userId);
                        }),
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(color: dark ? kDarkBackground : kBackground, borderRadius: BorderRadius.circular(8), border: Border.all(color: dark ? kDarkBorder : kBorder)),
                          child: Icon(isExpanded ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded, size: 16, color: dark ? kDarkTextMuted : kTextMuted),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Expanded assignments
            if (isExpanded) ...[
              Container(
                width: double.infinity,
                height: 1,
                color: dark ? kDarkBorder : kBorder,
              ),
              if (assignments.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  child: Text('Not assigned to any events yet.', style: GoogleFonts.inter(fontSize: 12, color: dark ? kDarkTextMuted : kTextMuted)),
                )
              else
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Event Assignments', style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w700, color: dark ? kDarkTextMuted : kTextMuted, letterSpacing: 0.8)),
                      const SizedBox(height: 8),
                      ...assignments.map((a) => _buildAssignmentRow(a, userId)),
                    ],
                  ),
                ),

              // Quick actions
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                child: Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () => _openProfile(m),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          decoration: BoxDecoration(
                            color: dark ? kDarkBackground : kBackground, borderRadius: BorderRadius.circular(10), border: Border.all(color: dark ? kDarkBorder : kBorder),
                          ),
                          alignment: Alignment.center,
                          child: Text('View Profile', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: dark ? kDarkTextPrimary : kTextPrimary)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: GestureDetector(
                        onTap: () => _setMemberStatus(userId, !isActive),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          decoration: BoxDecoration(
                            color: isActive ? const Color(0xFFFFFBEB) : const Color(0xFFF0FDF4),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: isActive ? const Color(0xFFFDE68A) : const Color(0xFFBBF7D0)),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            isActive ? 'Suspend' : 'Activate',
                            style: GoogleFonts.inter(
                              fontSize: 12, fontWeight: FontWeight.w700,
                              color: isActive ? const Color(0xFFD97706) : const Color(0xFF16A34A),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildAssignmentRow(Map<String, dynamic> a, String userId) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final role = a['role'] as String? ?? '';
    final eventTitle = a['eventTitle'] as String? ?? 'Unknown Event';
    final gateName = a['gateName'] as String?;
    final eventId = a['eventId'] as String?;
    final assignmentId = a['assignmentId'] as String? ?? '';

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: dark ? kDarkBackground : kBackground,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: dark ? kDarkBorder : kBorder),
        ),
        child: Row(
          children: [
            _buildRoleBadge(role, fontSize: 9),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(eventTitle, style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: dark ? kDarkTextPrimary : kTextPrimary), maxLines: 1, overflow: TextOverflow.ellipsis),
                  if (gateName != null)
                    Text(gateName, style: GoogleFonts.inter(fontSize: 10, color: dark ? kDarkTextMuted : kTextMuted)),
                ],
              ),
            ),
            PopupMenuButton<String>(
              icon: Icon(Icons.more_vert_rounded, size: 16, color: dark ? kDarkTextMuted : kTextMuted),
              color: dark ? kDarkSurface : kSurface,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              onSelected: (val) {
                if (val == 'role') _showRoleChangeDialog(a);
                if (val == 'remove' && eventId != null) _removeFromEvent(eventId, assignmentId);
              },
              itemBuilder: (_) => [
                PopupMenuItem(value: 'role', child: Row(children: [
                  Icon(Icons.swap_horiz_rounded, size: 14, color: dark ? kDarkTextMuted : kTextMuted),
                  const SizedBox(width: 8),
                  Text('Change Role', style: GoogleFonts.inter(fontSize: 13)),
                ])),
                PopupMenuItem(value: 'remove', child: Row(children: [
                  const Icon(Icons.remove_circle_outline_rounded, size: 14, color: Color(0xFFEF4444)),
                  const SizedBox(width: 8),
                  Text('Remove from Event', style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFFEF4444))),
                ])),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _shimmerCard() {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      height: 80,
      decoration: BoxDecoration(
        color: dark ? kDarkSurface : kSurface,
        borderRadius: BorderRadius.circular(16),
      ),
    );
  }

  // ── By Event Tab ───────────────────────────────────────────────────────────

  Widget _buildByEventTab() {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return RefreshIndicator(
      color: kPrimary,
      onRefresh: () async { await _loadEvents(); if (_selectedEventId != null) await _loadEventStaff(_selectedEventId!); },
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Event selector
            Container(
              decoration: BoxDecoration(
                color: dark ? kDarkSurface : kSurface, borderRadius: BorderRadius.circular(14), border: Border.all(color: dark ? kDarkBorder : kBorder),
              ),
              child: _eventsLoading
                  ? const Padding(padding: EdgeInsets.all(16), child: Center(child: CircularProgressIndicator()))
                  : DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _selectedEventId,
                        isExpanded: true,
                        hint: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: Text('Select an event', style: GoogleFonts.inter(fontSize: 14, color: dark ? kDarkTextMuted : kTextMuted)),
                        ),
                        dropdownColor: dark ? kDarkSurface : kSurface,
                        icon: const Padding(padding: EdgeInsets.only(right: 8), child: Icon(Icons.keyboard_arrow_down_rounded)),
                        items: _events.map((ev) => DropdownMenuItem<String>(
                          value: ev['id'] as String,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            child: Text(ev['title'] as String? ?? '', style: GoogleFonts.inter(fontSize: 14), overflow: TextOverflow.ellipsis),
                          ),
                        )).toList(),
                        onChanged: (id) {
                          setState(() { _selectedEventId = id; _eventStaff = []; });
                          if (id != null) _loadEventStaff(id);
                        },
                      ),
                    ),
            ),

            if (_selectedEventId != null) ...[
              const SizedBox(height: 16),

              // Missing critical role warning
              Builder(builder: (_) {
                if (_eventStaffLoading) return const SizedBox.shrink();
                final presentRoles = _eventStaff.map((s) => s['role'] as String? ?? '').toSet();
                final missing = _kCriticalRoles.where((r) => !presentRoles.contains(r)).toList();
                if (missing.isEmpty) return const SizedBox.shrink();
                return Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFFBEB),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFFDE68A)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.warning_amber_rounded, color: Color(0xFFD97706), size: 18),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Missing critical roles: ${missing.map(_roleLabel).join(', ')}. Assign staff before the event.',
                          style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF92400E)),
                        ),
                      ),
                    ],
                  ),
                );
              }),

              // Staff list grouped by role
              if (_eventStaffLoading)
                const Center(child: Padding(padding: EdgeInsets.all(32), child: CircularProgressIndicator()))
              else if (_eventStaff.isEmpty)
                Container(
                  padding: const EdgeInsets.all(32),
                  decoration: BoxDecoration(color: dark ? kDarkSurface : kSurface, borderRadius: BorderRadius.circular(16), border: Border.all(color: dark ? kDarkBorder : kBorder)),
                  child: Column(
                    children: [
                      Icon(Icons.group_off_rounded, size: 36, color: dark ? kDarkTextMuted : kTextMuted),
                      const SizedBox(height: 12),
                      Text('No staff assigned', style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w700, color: dark ? kDarkTextPrimary : kTextPrimary)),
                      const SizedBox(height: 4),
                      Text('Add staff from member profiles.', style: GoogleFonts.inter(fontSize: 12, color: dark ? kDarkTextMuted : kTextMuted)),
                    ],
                  ),
                )
              else ..._buildEventStaffGrouped(),

              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: kPrimary, foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  icon: const Icon(Icons.person_add_rounded, size: 16),
                  label: Text('Add Staff to This Event', style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
                  onPressed: _openAddWizard,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  List<Widget> _buildEventStaffGrouped() {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final grouped = <String, List<Map<String, dynamic>>>{};
    for (final s in _eventStaff) {
      final role = s['role'] as String? ?? 'SCANNER';
      grouped.putIfAbsent(role, () => []).add(s);
    }

    return grouped.entries.map((entry) {
      final role = entry.key;
      final staffList = entry.value;
      return Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(children: [
                _buildRoleBadge(role),
                const SizedBox(width: 8),
                Text('${staffList.length}', style: GoogleFonts.inter(fontSize: 12, color: dark ? kDarkTextMuted : kTextMuted, fontWeight: FontWeight.w600)),
              ]),
            ),
            ...staffList.map((s) {
              final user = (s['user'] as Map<String, dynamic>?) ?? {};
              final assignmentId = s['assignmentId'] as String? ?? '';
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: dark ? kDarkSurface : kSurface, borderRadius: BorderRadius.circular(14), border: Border.all(color: dark ? kDarkBorder : kBorder),
                ),
                child: Row(
                  children: [
                    _buildAvatar(user, size: 36),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${user['firstName'] ?? ''} ${user['lastName'] ?? ''}'.trim(),
                            style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700, color: dark ? kDarkTextPrimary : kTextPrimary),
                          ),
                          if ((s['gateName'] as String?) != null)
                            Text(s['gateName'] as String, style: GoogleFonts.inter(fontSize: 11, color: dark ? kDarkTextMuted : kTextMuted)),
                        ],
                      ),
                    ),
                    PopupMenuButton<String>(
                      icon: Icon(Icons.more_vert_rounded, size: 16, color: dark ? kDarkTextMuted : kTextMuted),
                      color: dark ? kDarkSurface : kSurface,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      onSelected: (val) {
                        if (val == 'role') _showRoleChangeDialog({...s, 'assignmentId': assignmentId});
                        if (val == 'remove' && _selectedEventId != null) _removeFromEvent(_selectedEventId!, assignmentId);
                      },
                      itemBuilder: (_) => [
                        PopupMenuItem(value: 'role', child: Row(children: [
                          Icon(Icons.swap_horiz_rounded, size: 14, color: dark ? kDarkTextMuted : kTextMuted), const SizedBox(width: 8),
                          Text('Change Role', style: GoogleFonts.inter(fontSize: 13)),
                        ])),
                        PopupMenuItem(value: 'remove', child: Row(children: [
                          const Icon(Icons.remove_circle_outline_rounded, size: 14, color: Color(0xFFEF4444)), const SizedBox(width: 8),
                          Text('Remove', style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFFEF4444))),
                        ])),
                      ],
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      );
    }).toList();
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Staff Profile Bottom Sheet
// ─────────────────────────────────────────────────────────────────────────────

class _StaffProfileSheet extends ConsumerStatefulWidget {
  final String userId;
  final List<Map<String, dynamic>> events;
  final VoidCallback onUpdated;

  const _StaffProfileSheet({required this.userId, required this.events, required this.onUpdated});

  @override
  ConsumerState<_StaffProfileSheet> createState() => _StaffProfileSheetState();
}

class _StaffProfileSheetState extends ConsumerState<_StaffProfileSheet> {
  Map<String, dynamic>? _profile;
  bool _loading = true;
  bool _editing = false;
  bool _saving = false;

  final _firstNameCtrl = TextEditingController();
  final _lastNameCtrl = TextEditingController();
  final _badgeCtrl = TextEditingController();
  final _emergencyNameCtrl = TextEditingController();
  final _emergencyPhoneCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _firstNameCtrl.dispose(); _lastNameCtrl.dispose(); _badgeCtrl.dispose();
    _emergencyNameCtrl.dispose(); _emergencyPhoneCtrl.dispose(); _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final data = await DioClient.instance.get<dynamic>('/users/my-team/${widget.userId}');
      if (mounted && data is Map<String, dynamic>) {
        setState(() {
          _profile = data;
          _firstNameCtrl.text = data['firstName'] as String? ?? '';
          _lastNameCtrl.text = data['lastName'] as String? ?? '';
          _badgeCtrl.text = data['badgeNumber'] as String? ?? '';
          _emergencyNameCtrl.text = data['emergencyContactName'] as String? ?? '';
          _emergencyPhoneCtrl.text = data['emergencyContactPhone'] as String? ?? '';
          _notesCtrl.text = data['staffNotes'] as String? ?? '';
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await DioClient.instance.patch<dynamic>('/users/my-team/${widget.userId}', data: {
        'firstName': _firstNameCtrl.text.trim(),
        'lastName': _lastNameCtrl.text.trim(),
        'badgeNumber': _badgeCtrl.text.trim(),
        'emergencyContactName': _emergencyNameCtrl.text.trim(),
        'emergencyContactPhone': _emergencyPhoneCtrl.text.trim(),
        'staffNotes': _notesCtrl.text.trim(),
      });
      if (mounted) {
        AppSnackbar.showSuccess(context, 'Profile saved');
        setState(() => _editing = false);
        _load();
        widget.onUpdated();
      }
    } catch (e) {
      if (mounted) AppSnackbar.showError(context, e.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _toggleStatus() async {
    if (_profile == null) return;
    final isActive = _profile!['isActive'] as bool? ?? true;
    final next = !isActive;
    if (!await _confirm('${next ? 'Activate' : 'Suspend'} this member?')) return;
    try {
      await DioClient.instance.patch<dynamic>('/users/${widget.userId}/status', data: {'isActive': next});
      if (mounted) {
        AppSnackbar.showSuccess(context, next ? 'Activated' : 'Suspended');
        _load();
        widget.onUpdated();
      }
    } catch (e) {
      if (mounted) AppSnackbar.showError(context, e.toString());
    }
  }

  Future<bool> _confirm(String msg) async {
    return await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: kSurface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Confirm', style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
        content: Text(msg, style: GoogleFonts.inter(fontSize: 14)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text('Cancel', style: GoogleFonts.inter(color: kTextMuted))),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: kPrimary,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(50)),
            ),
            onPressed: () => Navigator.pop(context, true),
            child: Text('Confirm', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    ) ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      maxChildSize: 0.95,
      minChildSize: 0.4,
      builder: (ctx, scroll) => Container(
        decoration: BoxDecoration(
          color: dark ? kDarkBackground : kBackground,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            // Drag handle
            Center(
              child: Padding(
                padding: const EdgeInsets.only(top: 12, bottom: 4),
                child: Container(width: 36, height: 4, decoration: BoxDecoration(color: dark ? kDarkBorder : kBorder, borderRadius: BorderRadius.circular(2))),
              ),
            ),

            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 12, 0),
              child: Row(
                children: [
                  Text('Staff Profile', style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w800, color: dark ? kDarkTextPrimary : kTextPrimary)),
                  const Spacer(),
                  if (!_editing && !_loading)
                    TextButton.icon(
                      onPressed: () => setState(() => _editing = true),
                      icon: const Icon(Icons.edit_rounded, size: 14),
                      label: Text('Edit', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700)),
                      style: TextButton.styleFrom(foregroundColor: kPrimary),
                    ),
                  IconButton(
                    onPressed: () => context.pop(),
                    icon: Icon(Icons.close_rounded, color: dark ? kDarkTextMuted : kTextMuted),
                  ),
                ],
              ),
            ),

            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _profile == null
                      ? Center(child: Text('Failed to load', style: GoogleFonts.inter(color: dark ? kDarkTextMuted : kTextMuted)))
                      : ListView(
                          controller: scroll,
                          padding: const EdgeInsets.fromLTRB(20, 12, 20, 100),
                          children: [
                            if (!_editing) _buildProfileView() else _buildProfileForm(),
                          ],
                        ),
            ),

            // Footer
            if (!_editing && _profile != null)
              Container(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
                decoration: BoxDecoration(
                  color: dark ? kDarkBackground : kBackground,
                  border: Border(top: BorderSide(color: dark ? kDarkBorder : kBorder)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: _toggleStatus,
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          decoration: BoxDecoration(
                            color: (_profile!['isActive'] as bool? ?? true) ? const Color(0xFFFFFBEB) : const Color(0xFFF0FDF4),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: (_profile!['isActive'] as bool? ?? true) ? const Color(0xFFFDE68A) : const Color(0xFFBBF7D0),
                            ),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            (_profile!['isActive'] as bool? ?? true) ? 'Suspend Member' : 'Activate Member',
                            style: GoogleFonts.inter(
                              fontSize: 14, fontWeight: FontWeight.w700,
                              color: (_profile!['isActive'] as bool? ?? true) ? const Color(0xFFD97706) : const Color(0xFF16A34A),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileView() {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final p = _profile!;
    final firstName = p['firstName'] as String? ?? '';
    final lastName = p['lastName'] as String? ?? '';
    final email = p['email'] as String?;
    final phone = p['phone'] as String?;
    final badgeNumber = p['badgeNumber'] as String?;
    final emergencyName = p['emergencyContactName'] as String?;
    final emergencyPhone = p['emergencyContactPhone'] as String?;
    final notes = p['staffNotes'] as String?;
    final isActive = p['isActive'] as bool? ?? true;
    final role = p['role'] as String? ?? '';
    final createdAt = p['createdAt'] as String?;
    final stats = p['stats'] as Map<String, dynamic>?;
    final assignments = (p['assignments'] as List?)?.cast<Map<String, dynamic>>() ?? [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Avatar + name
        Row(
          children: [
            _buildAvatar(p, size: 60),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Container(
                      width: 8, height: 8,
                      margin: const EdgeInsets.only(right: 6),
                      decoration: BoxDecoration(
                        color: isActive ? const Color(0xFF22C55E) : const Color(0xFFF59E0B),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    Flexible(child: Text('$firstName $lastName'.trim(), style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.w800, color: dark ? kDarkTextPrimary : kTextPrimary))),
                  ]),
                  const SizedBox(height: 4),
                  if (role.isNotEmpty) _buildRoleBadge(role),
                  if (createdAt != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      'Since ${_formatDate(createdAt)}',
                      style: GoogleFonts.inter(fontSize: 11, color: dark ? kDarkTextMuted : kTextMuted),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),

        const SizedBox(height: 20),

        // Stats
        Row(
          children: [
            _profileStat('Events', '${(stats?['eventsWorked'] as int?) ?? assignments.length}', Icons.event_rounded),
            const SizedBox(width: 12),
            _profileStat('Scans', '${(stats?['totalScans'] as int?) ?? 0}', Icons.qr_code_scanner_rounded),
          ],
        ),

        const SizedBox(height: 20),

        // Contact
        _sectionCard('Contact', [
          if (email != null) _infoRow(Icons.email_rounded, email),
          if (phone != null) _infoRow(Icons.phone_rounded, phone),
          if (badgeNumber != null) _infoRow(Icons.badge_rounded, 'Badge #$badgeNumber'),
        ]),

        if (emergencyName != null || emergencyPhone != null) ...[
          const SizedBox(height: 12),
          _sectionCard('Emergency Contact', [
            if (emergencyName != null) _infoRow(Icons.person_outline_rounded, emergencyName),
            if (emergencyPhone != null) _infoRow(Icons.phone_rounded, emergencyPhone, color: const Color(0xFFD97706)),
          ], borderColor: const Color(0xFFFDE68A), bgColor: const Color(0xFFFFFBEB)),
        ],

        if (notes != null && notes.isNotEmpty) ...[
          const SizedBox(height: 12),
          _sectionCard('Organizer Notes', [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Text(notes, style: GoogleFonts.inter(fontSize: 13, color: dark ? kDarkTextMuted : kTextMuted, fontStyle: FontStyle.italic)),
            ),
          ]),
        ],

        const SizedBox(height: 20),

        // Assignments
        Text('Event Assignments (${assignments.length})', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700, color: dark ? kDarkTextPrimary : kTextPrimary)),
        const SizedBox(height: 10),

        if (assignments.isEmpty)
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(color: dark ? kDarkSurface : kSurface, borderRadius: BorderRadius.circular(14), border: Border.all(color: dark ? kDarkBorder : kBorder)),
            child: Center(child: Text('Not assigned to any events.', style: GoogleFonts.inter(fontSize: 13, color: dark ? kDarkTextMuted : kTextMuted))),
          )
        else
          ...assignments.map((a) => Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: dark ? kDarkSurface : kSurface, borderRadius: BorderRadius.circular(14), border: Border.all(color: dark ? kDarkBorder : kBorder)),
            child: Row(
              children: [
                _buildRoleBadge(a['role'] as String? ?? '', fontSize: 10),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(a['eventTitle'] as String? ?? '', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: dark ? kDarkTextPrimary : kTextPrimary), maxLines: 1, overflow: TextOverflow.ellipsis),
                      Row(children: [
                        if (a['gateName'] != null)
                          Text(a['gateName'] as String, style: GoogleFonts.inter(fontSize: 11, color: dark ? kDarkTextMuted : kTextMuted)),
                        if (a['eventDate'] != null) ...[
                          if (a['gateName'] != null) Text(' · ', style: GoogleFonts.inter(fontSize: 11, color: dark ? kDarkTextMuted : kTextMuted)),
                          Text(_formatDateShort(a['eventDate'] as String), style: GoogleFonts.inter(fontSize: 11, color: dark ? kDarkTextMuted : kTextMuted)),
                        ],
                      ]),
                    ],
                  ),
                ),
              ],
            ),
          )),
      ],
    );
  }

  Widget _profileStat(String label, String value, IconData icon) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(color: dark ? kDarkSurface : kSurface, borderRadius: BorderRadius.circular(14), border: Border.all(color: dark ? kDarkBorder : kBorder)),
        child: Column(children: [
          Icon(icon, size: 20, color: kPrimary),
          const SizedBox(height: 6),
          Text(value, style: GoogleFonts.inter(fontSize: 22, fontWeight: FontWeight.w900, color: dark ? kDarkTextPrimary : kTextPrimary)),
          Text(label, style: GoogleFonts.inter(fontSize: 11, color: dark ? kDarkTextMuted : kTextMuted)),
        ]),
      ),
    );
  }

  Widget _sectionCard(String title, List<Widget> children, {Color? borderColor, Color? bgColor}) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: bgColor ?? (dark ? kDarkSurface : kSurface),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor ?? (dark ? kDarkBorder : kBorder)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w700, color: dark ? kDarkTextMuted : kTextMuted, letterSpacing: 0.8)),
          const SizedBox(height: 10),
          ...children,
        ],
      ),
    );
  }

  Widget _infoRow(IconData icon, String text, {Color? color}) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Icon(icon, size: 15, color: color ?? (dark ? kDarkTextMuted : kTextMuted)),
          const SizedBox(width: 10),
          Flexible(child: Text(text, style: GoogleFonts.inter(fontSize: 13, color: color ?? (dark ? kDarkTextPrimary : kTextPrimary)))),
        ],
      ),
    );
  }

  Widget _buildProfileForm() {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Editing Profile', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w800, color: dark ? kDarkTextPrimary : kTextPrimary)),
        const SizedBox(height: 16),

        Row(children: [
          Expanded(child: _formField('First Name', _firstNameCtrl)),
          const SizedBox(width: 12),
          Expanded(child: _formField('Last Name', _lastNameCtrl)),
        ]),
        const SizedBox(height: 12),
        _formField('Badge / ID Number', _badgeCtrl, hint: 'e.g. PP-0042'),
        const SizedBox(height: 20),

        Text('Emergency Contact', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: dark ? kDarkTextMuted : kTextMuted, letterSpacing: 0.8)),
        const SizedBox(height: 10),
        _formField('Contact Name', _emergencyNameCtrl, hint: 'Full name'),
        const SizedBox(height: 12),
        _formField('Contact Phone', _emergencyPhoneCtrl, hint: '07XXXXXXXX', keyboardType: TextInputType.phone),
        const SizedBox(height: 20),

        Text('Organizer Notes', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: dark ? kDarkTextMuted : kTextMuted, letterSpacing: 0.8)),
        const SizedBox(height: 10),
        Container(
          decoration: BoxDecoration(color: dark ? kDarkSurface : kSurface, borderRadius: BorderRadius.circular(12), border: Border.all(color: dark ? kDarkBorder : kBorder)),
          child: TextField(
            controller: _notesCtrl,
            maxLines: 4,
            style: GoogleFonts.inter(fontSize: 14, color: dark ? kDarkTextPrimary : kTextPrimary),
            decoration: InputDecoration(
              hintText: 'Internal notes about this staff member…',
              hintStyle: GoogleFonts.inter(fontSize: 13, color: dark ? kDarkTextMuted : kTextMuted),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.all(14),
            ),
          ),
        ),
        const SizedBox(height: 24),

        Row(children: [
          Expanded(
            child: OutlinedButton(
              onPressed: () => setState(() => _editing = false),
              style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
              child: Text('Cancel', style: GoogleFonts.inter(fontWeight: FontWeight.w700, color: dark ? kDarkTextMuted : kTextMuted)),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: FilledButton(
              onPressed: _saving ? null : _save,
              style: FilledButton.styleFrom(
                backgroundColor: kPrimary, foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              child: _saving
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : Text('Save Changes', style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
            ),
          ),
        ]),
      ],
    );
  }

  Widget _formField(String label, TextEditingController ctrl, {String? hint, TextInputType? keyboardType}) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: dark ? kDarkTextMuted : kTextMuted)),
        const SizedBox(height: 6),
        Container(
          decoration: BoxDecoration(color: dark ? kDarkSurface : kSurface, borderRadius: BorderRadius.circular(12), border: Border.all(color: dark ? kDarkBorder : kBorder)),
          child: TextField(
            controller: ctrl,
            keyboardType: keyboardType,
            style: GoogleFonts.inter(fontSize: 14, color: dark ? kDarkTextPrimary : kTextPrimary),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: GoogleFonts.inter(fontSize: 13, color: dark ? kDarkTextMuted : kTextMuted),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            ),
          ),
        ),
      ],
    );
  }

  String _formatDate(String iso) {
    try {
      final dt = DateTime.parse(iso);
      const months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
      return '${months[dt.month - 1]} ${dt.year}';
    } catch (_) { return ''; }
  }

  String _formatDateShort(String iso) {
    try {
      final dt = DateTime.parse(iso);
      const months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
      return '${months[dt.month - 1]} ${dt.day}';
    } catch (_) { return ''; }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Add Member Wizard (3-step)
// ─────────────────────────────────────────────────────────────────────────────

class _AddMemberWizard extends ConsumerStatefulWidget {
  final List<Map<String, dynamic>> events;
  final VoidCallback onDone;

  const _AddMemberWizard({required this.events, required this.onDone});

  @override
  ConsumerState<_AddMemberWizard> createState() => _AddMemberWizardState();
}

class _AddMemberWizardState extends ConsumerState<_AddMemberWizard> {
  int _step = 0; // 0=search, 1=create, 2=assign
  ScrollController? _scrollRef; // stored from DraggableScrollableSheet builder

  // Search state
  final _searchCtrl = TextEditingController();
  bool _searching = false;
  List<Map<String, dynamic>> _results = [];
  bool _searched = false;
  Map<String, dynamic>? _selectedUser;

  // Create form
  final _firstNameCtrl = TextEditingController();
  final _lastNameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _badgeCtrl = TextEditingController();
  final _emergencyNameCtrl = TextEditingController();
  final _emergencyPhoneCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  String _defaultRole = 'SCANNER';
  bool _showPassword = false;
  bool _creating = false;

  // Assign
  String? _assignEventId;
  String _assignRole = 'SCANNER';
  String? _assignGateId;
  List<Map<String, dynamic>> _gates = [];
  bool _assigning = false;

  @override
  void dispose() {
    _searchCtrl.dispose(); _firstNameCtrl.dispose(); _lastNameCtrl.dispose();
    _emailCtrl.dispose(); _phoneCtrl.dispose(); _passwordCtrl.dispose();
    _badgeCtrl.dispose(); _emergencyNameCtrl.dispose(); _emergencyPhoneCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  String _generatePassword() {
    const chars = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789@#!';
    final rng = DateTime.now().millisecondsSinceEpoch;
    return List.generate(12, (i) => chars[(rng + i * 17) % chars.length]).join();
  }

  Future<void> _search() async {
    if (_searchCtrl.text.trim().isEmpty) return;
    setState(() { _searching = true; _results = []; _searched = false; });
    try {
      final data = await DioClient.instance.get<dynamic>('/users/staff/search', queryParameters: {'q': _searchCtrl.text.trim()});
      if (mounted) {
        setState(() {
          _results = List<Map<String, dynamic>>.from(data as List? ?? []);
          _searched = true;
          _searching = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() { _searching = false; _searched = true; });
    }
  }

  Future<void> _loadGates(String eventId) async {
    try {
      final data = await DioClient.instance.get<dynamic>('/events/$eventId/gates');
      if (mounted) setState(() => _gates = List<Map<String, dynamic>>.from(data as List? ?? []));
    } catch (_) {
      if (mounted) setState(() => _gates = []);
    }
  }

  void _scrollToTop() {
    _scrollRef?.animateTo(0,
        duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
  }

  Future<void> _create() async {
    if (_firstNameCtrl.text.trim().isEmpty || _lastNameCtrl.text.trim().isEmpty) {
      _scrollToTop();
      AppSnackbar.showError(context, 'Scroll up — first and last name are required'); return;
    }
    if (_emailCtrl.text.trim().isEmpty && _phoneCtrl.text.trim().isEmpty) {
      _scrollToTop();
      AppSnackbar.showError(context, 'Scroll up — email or phone is required'); return;
    }
    if (_passwordCtrl.text.length < 6) {
      _scrollToTop();
      AppSnackbar.showError(context, 'Scroll up — password must be at least 6 characters'); return;
    }
    setState(() => _creating = true);
    try {
      final resp = await DioClient.instance.post<dynamic>('/users/staff', data: {
        'firstName': _firstNameCtrl.text.trim(),
        'lastName': _lastNameCtrl.text.trim(),
        if (_emailCtrl.text.trim().isNotEmpty) 'email': _emailCtrl.text.trim(),
        if (_phoneCtrl.text.trim().isNotEmpty) 'phone': _phoneCtrl.text.trim(),
        'password': _passwordCtrl.text,
        'staffRole': _defaultRole,
        if (_badgeCtrl.text.trim().isNotEmpty) 'badgeNumber': _badgeCtrl.text.trim(),
        if (_emergencyNameCtrl.text.trim().isNotEmpty) 'emergencyContactName': _emergencyNameCtrl.text.trim(),
        if (_emergencyPhoneCtrl.text.trim().isNotEmpty) 'emergencyContactPhone': _emergencyPhoneCtrl.text.trim(),
        if (_notesCtrl.text.trim().isNotEmpty) 'staffNotes': _notesCtrl.text.trim(),
      });
      if (mounted) {
        AppSnackbar.showSuccess(context, 'Staff account created!');
        final staff = (resp is Map<String, dynamic> ? resp['staff'] : null) as Map<String, dynamic>?;
        setState(() { _selectedUser = staff; _step = 2; _creating = false; });
        widget.onDone();
      }
    } catch (e) {
      if (mounted) { AppSnackbar.showError(context, e.toString()); setState(() => _creating = false); }
    }
  }

  Future<void> _assign() async {
    if (_assignEventId == null || _selectedUser == null) { context.pop(); return; }
    setState(() => _assigning = true);
    try {
      await DioClient.instance.post<dynamic>('/events/$_assignEventId/staff', data: {
        'userId': _selectedUser!['id'],
        'role': _assignRole,
        if (_assignGateId != null) 'gateId': _assignGateId,
      });
      if (mounted) {
        AppSnackbar.showSuccess(context, 'Assigned to event');
        widget.onDone();
        context.pop();
      }
    } catch (e) {
      if (mounted) { AppSnackbar.showError(context, e.toString()); setState(() => _assigning = false); }
    }
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return DraggableScrollableSheet(
      initialChildSize: 0.9,
      maxChildSize: 0.95,
      minChildSize: 0.5,
      builder: (_, scroll) {
        _scrollRef = scroll;
        return Container(
        decoration: BoxDecoration(color: dark ? kDarkBackground : kBackground, borderRadius: const BorderRadius.vertical(top: Radius.circular(24))),
        child: Column(
          children: [
            Center(
              child: Padding(
                padding: const EdgeInsets.only(top: 12, bottom: 4),
                child: Container(width: 36, height: 4, decoration: BoxDecoration(color: dark ? kDarkBorder : kBorder, borderRadius: BorderRadius.circular(2))),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 12, 0),
              child: Row(
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Add Team Member', style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w800, color: dark ? kDarkTextPrimary : kTextPrimary)),
                      Text(['Find or Create', 'Create Account', 'Assign to Event'][_step], style: GoogleFonts.inter(fontSize: 12, color: dark ? kDarkTextMuted : kTextMuted)),
                    ],
                  ),
                  const Spacer(),
                  // Step indicators
                  Row(
                    children: List.generate(3, (i) => Container(
                      margin: const EdgeInsets.only(right: 6),
                      width: 24, height: 24,
                      decoration: BoxDecoration(
                        color: i == _step ? kPrimary : (i < _step ? const Color(0xFF22C55E) : (dark ? kDarkSurface : kSurface)),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: i == _step || i < _step ? Colors.transparent : (dark ? kDarkBorder : kBorder)),
                      ),
                      alignment: Alignment.center,
                      child: Text('${i + 1}', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: i == _step || i < _step ? Colors.white : (dark ? kDarkTextMuted : kTextMuted))),
                    )),
                  ),
                  IconButton(onPressed: () => context.pop(), icon: Icon(Icons.close_rounded, color: dark ? kDarkTextMuted : kTextMuted)),
                ],
              ),
            ),

            Expanded(
              child: ListView(
                controller: scroll,
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
                children: [
                  if (_step == 0) _buildSearchStep(),
                  if (_step == 1) _buildCreateStep(),
                  if (_step == 2) _buildAssignStep(),
                ],
              ),
            ),
          ],
        ),
      );
      },
    );
  }

  Widget _buildSearchStep() {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Search for an existing PartyPass user or create a new staff account.',
          style: GoogleFonts.inter(fontSize: 13, color: dark ? kDarkTextMuted : kTextMuted),
        ),
        const SizedBox(height: 16),

        Row(children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(color: dark ? kDarkSurface : kSurface, borderRadius: BorderRadius.circular(12), border: Border.all(color: dark ? kDarkBorder : kBorder)),
              child: TextField(
                controller: _searchCtrl,
                style: GoogleFonts.inter(fontSize: 14, color: dark ? kDarkTextPrimary : kTextPrimary),
                decoration: InputDecoration(
                  hintText: 'Email, phone, or name…',
                  hintStyle: GoogleFonts.inter(fontSize: 13, color: dark ? kDarkTextMuted : kTextMuted),
                  prefixIcon: const Icon(Icons.search_rounded, size: 18, color: Color(0xFF9CA3AF)),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 14),
                ),
                onSubmitted: (_) => _search(),
              ),
            ),
          ),
          const SizedBox(width: 10),
          GestureDetector(
            onTap: _search,
            child: Container(
              width: 48, height: 48,
              decoration: BoxDecoration(color: kPrimary, borderRadius: BorderRadius.circular(12)),
              child: _searching
                  ? const Padding(padding: EdgeInsets.all(12), child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.search_rounded, color: Colors.white, size: 20),
            ),
          ),
        ]),

        const SizedBox(height: 16),

        if (_searched && _results.isEmpty)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: dark ? kDarkSurface : kSurface, borderRadius: BorderRadius.circular(12), border: Border.all(color: dark ? kDarkBorder : kBorder)),
            child: Text('No users found for "${_searchCtrl.text}"', style: GoogleFonts.inter(fontSize: 13, color: dark ? kDarkTextMuted : kTextMuted), textAlign: TextAlign.center),
          ),

        if (_results.isNotEmpty) ..._results.map((u) => GestureDetector(
          onTap: () => setState(() { _selectedUser = u; _step = 2; }),
          child: Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: dark ? kDarkSurface : kSurface, borderRadius: BorderRadius.circular(14), border: Border.all(color: dark ? kDarkBorder : kBorder)),
            child: Row(
              children: [
                _buildAvatar(u, size: 40),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('${u['firstName'] ?? ''} ${u['lastName'] ?? ''}'.trim(), style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700, color: dark ? kDarkTextPrimary : kTextPrimary)),
                    Text(u['email'] ?? u['phone'] ?? '', style: GoogleFonts.inter(fontSize: 12, color: dark ? kDarkTextMuted : kTextMuted)),
                  ]),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(color: kPrimary.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                  child: Text('Select', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: kPrimary)),
                ),
              ],
            ),
          ),
        )),

        const SizedBox(height: 16),

        GestureDetector(
          onTap: () => setState(() => _step = 1),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: kPrimary.withValues(alpha: 0.4), width: 2, style: BorderStyle.solid),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.person_add_rounded, color: kPrimary, size: 18),
                const SizedBox(width: 8),
                Text('Create New Staff Account', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700, color: kPrimary)),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCreateStep() {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
          onTap: () => setState(() => _step = 0),
          child: Row(children: [
            Icon(Icons.arrow_back_rounded, size: 16, color: dark ? kDarkTextMuted : kTextMuted),
            const SizedBox(width: 4),
            Text('Back to search', style: GoogleFonts.inter(fontSize: 13, color: dark ? kDarkTextMuted : kTextMuted)),
          ]),
        ),
        const SizedBox(height: 20),

        Row(children: [
          Expanded(child: _wizardField('First Name *', _firstNameCtrl)),
          const SizedBox(width: 12),
          Expanded(child: _wizardField('Last Name *', _lastNameCtrl)),
        ]),
        const SizedBox(height: 12),
        _wizardField('Email', _emailCtrl, hint: 'staff@email.com', type: TextInputType.emailAddress),
        const SizedBox(height: 12),
        _wizardField('Phone', _phoneCtrl, hint: '07XXXXXXXX', type: TextInputType.phone),
        const SizedBox(height: 12),

        // Password
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Password *', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: dark ? kDarkTextMuted : kTextMuted)),
          const SizedBox(height: 6),
          Container(
            decoration: BoxDecoration(color: dark ? kDarkSurface : kSurface, borderRadius: BorderRadius.circular(12), border: Border.all(color: dark ? kDarkBorder : kBorder)),
            child: Row(children: [
              Expanded(
                child: TextField(
                  controller: _passwordCtrl,
                  obscureText: !_showPassword,
                  style: GoogleFonts.inter(fontSize: 14, color: dark ? kDarkTextPrimary : kTextPrimary),
                  decoration: InputDecoration(
                    hintText: 'Min. 6 characters', hintStyle: GoogleFonts.inter(fontSize: 13, color: dark ? kDarkTextMuted : kTextMuted),
                    border: InputBorder.none, contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  ),
                ),
              ),
              GestureDetector(
                onTap: () => setState(() => _showPassword = !_showPassword),
                child: Padding(padding: const EdgeInsets.symmetric(horizontal: 10), child: Icon(_showPassword ? Icons.visibility_off_rounded : Icons.visibility_rounded, size: 18, color: dark ? kDarkTextMuted : kTextMuted)),
              ),
            ]),
          ),
          const SizedBox(height: 6),
          GestureDetector(
            onTap: () {
              final pwd = _generatePassword();
              setState(() { _passwordCtrl.text = pwd; _showPassword = true; });
              AppSnackbar.showSuccess(context, 'Password generated — save it!');
            },
            child: Text('⚡ Generate strong password', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: kPrimary)),
          ),
        ]),

        const SizedBox(height: 20),

        // Default role
        Text('Default Role *', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: dark ? kDarkTextMuted : kTextMuted, letterSpacing: 0.8)),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8, runSpacing: 8,
          children: _kRoles.map((r) {
            final sel = _defaultRole == r.value;
            return GestureDetector(
              onTap: () => setState(() => _defaultRole = r.value),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: sel ? r.color.withValues(alpha: 0.12) : (dark ? kDarkSurface : kSurface),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: sel ? r.color : (dark ? kDarkBorder : kBorder), width: sel ? 1.5 : 1),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(r.icon, size: 14, color: sel ? r.color : (dark ? kDarkTextMuted : kTextMuted)),
                  const SizedBox(width: 6),
                  Text(r.label, style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: sel ? r.color : (dark ? kDarkTextMuted : kTextMuted))),
                ]),
              ),
            );
          }).toList(),
        ),

        const SizedBox(height: 20),
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(child: _wizardField('Badge / ID Number', _badgeCtrl, hint: 'e.g. PP-0042 (optional)')),
            const SizedBox(width: 10),
            GestureDetector(
              onTap: () {
                final n = (DateTime.now().millisecondsSinceEpoch % 9000 + 1000).toString();
                setState(() => _badgeCtrl.text = 'PP-$n');
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                decoration: BoxDecoration(
                  color: kPrimary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: kPrimary.withValues(alpha: 0.3)),
                ),
                child: Text('Generate', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: kPrimary)),
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),

        // Emergency contact
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: dark ? kDarkSurface : kSurface, borderRadius: BorderRadius.circular(14), border: Border.all(color: dark ? kDarkBorder : kBorder)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Emergency Contact', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: dark ? kDarkTextMuted : kTextMuted, letterSpacing: 0.8)),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(child: _wizardField('Contact Name', _emergencyNameCtrl, hint: 'Full name')),
              const SizedBox(width: 12),
              Expanded(child: _wizardField('Phone', _emergencyPhoneCtrl, hint: '07XXXXXXXX', type: TextInputType.phone)),
            ]),
          ]),
        ),

        const SizedBox(height: 12),
        _wizardTextArea('Organizer Notes (private)', _notesCtrl, hint: 'Internal notes about this staff member…'),
        const SizedBox(height: 24),

        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: _creating ? null : _create,
            style: FilledButton.styleFrom(
              backgroundColor: kPrimary, foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            child: _creating
                ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : Text('Create Account & Continue →', style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w700)),
          ),
        ),
      ],
    );
  }

  Widget _buildAssignStep() {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_selectedUser != null)
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: dark ? kDarkSurface : kSurface, borderRadius: BorderRadius.circular(14), border: Border.all(color: const Color(0xFFBBF7D0))),
            child: Row(
              children: [
                _buildAvatar(_selectedUser!, size: 40),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('${_selectedUser!['firstName'] ?? ''} ${_selectedUser!['lastName'] ?? ''}'.trim(),
                        style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700, color: dark ? kDarkTextPrimary : kTextPrimary)),
                    Text('Ready to assign', style: GoogleFonts.inter(fontSize: 12, color: dark ? kDarkTextMuted : kTextMuted)),
                  ]),
                ),
                const Icon(Icons.check_circle_rounded, color: Color(0xFF22C55E), size: 22),
              ],
            ),
          ),

        const SizedBox(height: 20),
        Text('Assign to an event (optional — you can do this later from the team page).', style: GoogleFonts.inter(fontSize: 13, color: dark ? kDarkTextMuted : kTextMuted)),
        const SizedBox(height: 16),

        // Event selector
        Text('Event', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: dark ? kDarkTextMuted : kTextMuted)),
        const SizedBox(height: 6),
        Container(
          decoration: BoxDecoration(color: dark ? kDarkSurface : kSurface, borderRadius: BorderRadius.circular(12), border: Border.all(color: dark ? kDarkBorder : kBorder)),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _assignEventId,
              isExpanded: true,
              dropdownColor: dark ? kDarkSurface : kSurface,
              hint: Padding(padding: const EdgeInsets.symmetric(horizontal: 14), child: Text('Select event', style: GoogleFonts.inter(fontSize: 14, color: dark ? kDarkTextMuted : kTextMuted))),
              icon: const Padding(padding: EdgeInsets.only(right: 8), child: Icon(Icons.keyboard_arrow_down_rounded)),
              items: widget.events.map((ev) => DropdownMenuItem<String>(
                value: ev['id'] as String,
                child: Padding(padding: const EdgeInsets.symmetric(horizontal: 14), child: Text(ev['title'] as String? ?? '', style: GoogleFonts.inter(fontSize: 14))),
              )).toList(),
              onChanged: (id) {
                setState(() { _assignEventId = id; _assignGateId = null; _gates = []; });
                if (id != null) _loadGates(id);
              },
            ),
          ),
        ),

        if (_assignEventId != null) ...[
          const SizedBox(height: 16),
          Text('Role *', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: dark ? kDarkTextMuted : kTextMuted, letterSpacing: 0.8)),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8, runSpacing: 8,
            children: _kRoles.map((r) {
              final sel = _assignRole == r.value;
              return GestureDetector(
                onTap: () => setState(() => _assignRole = r.value),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: sel ? r.color.withValues(alpha: 0.12) : (dark ? kDarkSurface : kSurface),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: sel ? r.color : (dark ? kDarkBorder : kBorder)),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(r.icon, size: 14, color: sel ? r.color : (dark ? kDarkTextMuted : kTextMuted)),
                    const SizedBox(width: 6),
                    Text(r.label, style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: sel ? r.color : (dark ? kDarkTextMuted : kTextMuted))),
                  ]),
                ),
              );
            }).toList(),
          ),

          if (_gates.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text('Gate (optional)', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: dark ? kDarkTextMuted : kTextMuted)),
            const SizedBox(height: 6),
            Container(
              decoration: BoxDecoration(color: dark ? kDarkSurface : kSurface, borderRadius: BorderRadius.circular(12), border: Border.all(color: dark ? kDarkBorder : kBorder)),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _assignGateId,
                  isExpanded: true,
                  dropdownColor: dark ? kDarkSurface : kSurface,
                  hint: Padding(padding: const EdgeInsets.symmetric(horizontal: 14), child: Text('Any gate', style: GoogleFonts.inter(fontSize: 14, color: dark ? kDarkTextMuted : kTextMuted))),
                  icon: const Padding(padding: EdgeInsets.only(right: 8), child: Icon(Icons.keyboard_arrow_down_rounded)),
                  items: _gates.map((g) => DropdownMenuItem<String>(
                    value: g['id'] as String,
                    child: Padding(padding: const EdgeInsets.symmetric(horizontal: 14), child: Text(g['name'] as String? ?? '', style: GoogleFonts.inter(fontSize: 14))),
                  )).toList(),
                  onChanged: (id) => setState(() => _assignGateId = id),
                ),
              ),
            ),
          ],
        ],

        const SizedBox(height: 28),

        Row(children: [
          Expanded(
            child: OutlinedButton(
              onPressed: () => context.pop(),
              style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
              child: Text('Skip', style: GoogleFonts.inter(fontWeight: FontWeight.w700, color: dark ? kDarkTextMuted : kTextMuted)),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: FilledButton(
              onPressed: _assigning ? null : _assign,
              style: FilledButton.styleFrom(
                backgroundColor: kPrimary, foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              child: _assigning
                  ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : Text(_assignEventId != null ? 'Assign & Finish' : 'Done', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700)),
            ),
          ),
        ]),
      ],
    );
  }

  Widget _wizardField(String label, TextEditingController ctrl, {String? hint, TextInputType? type}) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: dark ? kDarkTextMuted : kTextMuted)),
        const SizedBox(height: 6),
        Container(
          decoration: BoxDecoration(color: dark ? kDarkSurface : kSurface, borderRadius: BorderRadius.circular(12), border: Border.all(color: dark ? kDarkBorder : kBorder)),
          child: TextField(
            controller: ctrl, keyboardType: type,
            style: GoogleFonts.inter(fontSize: 14, color: dark ? kDarkTextPrimary : kTextPrimary),
            decoration: InputDecoration(
              hintText: hint, hintStyle: GoogleFonts.inter(fontSize: 13, color: dark ? kDarkTextMuted : kTextMuted),
              border: InputBorder.none, contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            ),
          ),
        ),
      ],
    );
  }

  Widget _wizardTextArea(String label, TextEditingController ctrl, {String? hint}) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: dark ? kDarkTextMuted : kTextMuted)),
        const SizedBox(height: 6),
        Container(
          decoration: BoxDecoration(color: dark ? kDarkSurface : kSurface, borderRadius: BorderRadius.circular(12), border: Border.all(color: dark ? kDarkBorder : kBorder)),
          child: TextField(
            controller: ctrl, maxLines: 3,
            style: GoogleFonts.inter(fontSize: 14, color: dark ? kDarkTextPrimary : kTextPrimary),
            decoration: InputDecoration(
              hintText: hint, hintStyle: GoogleFonts.inter(fontSize: 13, color: dark ? kDarkTextMuted : kTextMuted),
              border: InputBorder.none, contentPadding: const EdgeInsets.all(14),
            ),
          ),
        ),
      ],
    );
  }
}
