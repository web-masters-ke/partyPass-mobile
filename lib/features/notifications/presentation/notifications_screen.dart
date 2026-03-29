import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/date_utils.dart';

class _Notification {
  final String id;
  final String title;
  final String body;
  final bool isRead;
  final String type;
  final String createdAt;

  _Notification({
    required this.id,
    required this.title,
    required this.body,
    required this.isRead,
    required this.type,
    required this.createdAt,
  });

  factory _Notification.fromJson(Map<String, dynamic> json) => _Notification(
        id: json['id']?.toString() ?? '',
        title: json['title']?.toString() ?? '',
        body: json['body']?.toString() ?? '',
        isRead: json['isRead'] == true,
        type: json['type']?.toString() ?? 'INFO',
        createdAt: json['createdAt']?.toString() ?? '',
      );
}

final _notificationsProvider =
    FutureProvider<List<_Notification>>((ref) async {
  final data =
      await DioClient.instance.get<dynamic>('/notifications');
  if (data is List) {
    return data
        .map((e) => _Notification.fromJson(e as Map<String, dynamic>))
        .toList();
  }
  final items =
      (data as Map<String, dynamic>)['items'] as List? ?? [];
  return items
      .map((e) => _Notification.fromJson(e as Map<String, dynamic>))
      .toList();
});

class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final notifAsync = ref.watch(_notificationsProvider);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20),
          onPressed: () => context.pop(),
        ),
        title: const Text('Notifications'),
        actions: [
          TextButton(
            onPressed: () async {
              try {
                await DioClient.instance
                    .post<dynamic>('/notifications/read-all');
                ref.invalidate(_notificationsProvider);
              } catch (_) {}
            },
            child: Text('Mark all read',
                style: GoogleFonts.inter(color: kPrimary, fontSize: 13)),
          ),
        ],
      ),
      body: notifAsync.when(
        loading: () =>
            const Center(child: CircularProgressIndicator(color: kPrimary)),
        error: (e, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.notifications_off_rounded,
                  size: 48, color: dark ? kDarkTextMuted : kTextMuted),
              const SizedBox(height: 12),
              Text('Could not load notifications',
                  style: GoogleFonts.inter(
                      color: dark ? kDarkTextMuted : kTextMuted)),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: () => ref.invalidate(_notificationsProvider),
                style: FilledButton.styleFrom(
                    backgroundColor: kPrimary,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(50))),
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
        data: (notifications) {
          if (notifications.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.notifications_rounded,
                      size: 56, color: dark ? kDarkTextMuted : kTextMuted),
                  const SizedBox(height: 16),
                  Text('No notifications yet',
                      style: GoogleFonts.inter(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: dark ? kDarkTextPrimary : kTextPrimary)),
                  const SizedBox(height: 8),
                  Text("You're all caught up!",
                      style: GoogleFonts.inter(
                          fontSize: 14,
                          color: dark ? kDarkTextMuted : kTextMuted)),
                ],
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: notifications.length,
            separatorBuilder: (_, __) =>
                const Divider(height: 1, indent: 72),
            itemBuilder: (context, i) =>
                _NotifTile(notif: notifications[i], ref: ref),
          );
        },
      ),
    );
  }
}

class _NotifTile extends StatelessWidget {
  final _Notification notif;
  final WidgetRef ref;

  const _NotifTile({required this.notif, required this.ref});

  IconData get _icon {
    switch (notif.type) {
      case 'REMINDER':
        return Icons.alarm_rounded;
      case 'PAYMENT':
        return Icons.payment_rounded;
      case 'TICKET':
        return Icons.confirmation_number_rounded;
      case 'PROMO':
        return Icons.local_offer_rounded;
      default:
        return Icons.notifications_rounded;
    }
  }

  Color get _iconBg {
    switch (notif.type) {
      case 'REMINDER':
        return kWarning;
      case 'PAYMENT':
        return kSuccess;
      case 'TICKET':
        return kPrimary;
      case 'PROMO':
        return const Color(0xFF8B5CF6);
      default:
        return const Color(0xFF3B82F6);
    }
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return InkWell(
      onTap: () async {
        if (!notif.isRead) {
          try {
            await DioClient.instance
                .patch<dynamic>('/notifications/${notif.id}/read');
            ref.invalidate(_notificationsProvider);
          } catch (_) {}
        }
      },
      child: Container(
        color: notif.isRead ? Colors.transparent : kPrimary.withValues(alpha: 0.04),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: _iconBg.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(_icon, size: 20, color: _iconBg),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    notif.title,
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: notif.isRead
                          ? FontWeight.w400
                          : FontWeight.w700,
                      color: dark ? kDarkTextPrimary : kTextPrimary,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    notif.body,
                    style: GoogleFonts.inter(
                        fontSize: 13,
                        color: dark ? kDarkTextMuted : kTextMuted),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  if (notif.createdAt.isNotEmpty)
                    Text(
                      AppDateUtils.formatDateTime(
                          DateTime.parse(notif.createdAt)),
                      style: GoogleFonts.inter(
                          fontSize: 11,
                          color: dark ? kDarkTextMuted : kTextMuted),
                    ),
                ],
              ),
            ),
            if (!notif.isRead)
              Container(
                width: 8,
                height: 8,
                margin: const EdgeInsets.only(top: 4),
                decoration: const BoxDecoration(
                  color: kPrimary,
                  shape: BoxShape.circle,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
