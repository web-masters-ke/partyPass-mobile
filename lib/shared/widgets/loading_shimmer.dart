import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import '../../core/theme/app_theme.dart';

class LoadingShimmer extends StatelessWidget {
  const LoadingShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _shimmerBox(height: 200, radius: 16),
          const SizedBox(height: 24),
          _shimmerBox(height: 18, width: 120),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _shimmerBox(height: 160, radius: 16)),
              const SizedBox(width: 12),
              Expanded(child: _shimmerBox(height: 160, radius: 16)),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _shimmerBox(height: 160, radius: 16)),
              const SizedBox(width: 12),
              Expanded(child: _shimmerBox(height: 160, radius: 16)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _shimmerBox({double? width, double height = 16, double radius = 8}) {
    return Shimmer.fromColors(
      baseColor: kSurface,
      highlightColor: const Color(0xFFEEEEEE),
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: kSurface,
          borderRadius: BorderRadius.circular(radius),
        ),
      ),
    );
  }
}

class ShimmerEventCard extends StatelessWidget {
  const ShimmerEventCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: kSurface,
      highlightColor: const Color(0xFFEEEEEE),
      child: Container(
        height: 160,
        decoration: BoxDecoration(
          color: kSurface,
          borderRadius: BorderRadius.circular(16),
        ),
      ),
    );
  }
}
