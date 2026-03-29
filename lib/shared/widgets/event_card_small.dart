import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/date_utils.dart';
import '../../shared/models/event.dart';

class EventCardSmall extends StatelessWidget {
  final Event event;
  final VoidCallback onTap;

  const EventCardSmall({super.key, required this.event, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: dark ? kDarkSurface : Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: const [
            BoxShadow(
              color: kCardShadow,
              blurRadius: 8,
              offset: Offset(0, 2),
            ),
          ],
          border: Border.all(color: dark ? kDarkBorder : kBorder, width: 0.5),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Cover image
            ClipRRect(
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(16)),
              child: SizedBox(
                height: 110,
                width: double.infinity,
                child: event.coverImageUrl != null
                    ? CachedNetworkImage(
                        imageUrl: event.coverImageUrl!,
                        fit: BoxFit.cover,
                        placeholder: (_, __) => Container(
                            color: kPrimary.withValues(alpha: 0.15)),
                        errorWidget: (_, __, ___) => Container(
                          color: kPrimary.withValues(alpha: 0.15),
                          child: Center(
                            child: Icon(Icons.image_not_supported_rounded,
                                color: dark ? kDarkTextMuted : kTextMuted),
                          ),
                        ),
                      )
                    : Container(
                        color: kPrimary.withValues(alpha: 0.15),
                        child: Center(
                          child: Icon(Icons.event_rounded,
                              color: dark ? kDarkTextMuted : kTextMuted, size: 32),
                        ),
                      ),
              ),
            ),

            // Details
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    event.title,
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: dark ? kDarkTextPrimary : kTextPrimary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Icon(Icons.calendar_today_rounded,
                          size: 11, color: dark ? kDarkTextMuted : kTextMuted),
                      const SizedBox(width: 3),
                      Expanded(
                        child: Text(
                          AppDateUtils.formatShortDate(event.startDateTime),
                          style: GoogleFonts.inter(
                              fontSize: 11, color: dark ? kDarkTextMuted : kTextMuted),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Icon(Icons.access_time_rounded,
                          size: 11, color: dark ? kDarkTextMuted : kTextMuted),
                      const SizedBox(width: 3),
                      Text(
                        AppDateUtils.formatTime(event.startDateTime),
                        style:
                            GoogleFonts.inter(fontSize: 11, color: dark ? kDarkTextMuted : kTextMuted),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
