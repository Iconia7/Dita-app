import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

/// Base skeleton widget that provides the shimmer effect
class DitaSkeleton extends StatelessWidget {
  final Widget child;

  const DitaSkeleton({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Shimmer.fromColors(
      baseColor: isDark ? Colors.grey[800]! : Colors.grey[300]!,
      highlightColor: isDark ? Colors.grey[700]! : Colors.grey[100]!,
      period: const Duration(milliseconds: 1500),
      child: child,
    );
  }
}

/// Simple box placeholder
class SkeletonBox extends StatelessWidget {
  final double? width;
  final double? height;
  final double borderRadius;
  final BoxShape shape;

  const SkeletonBox({
    super.key,
    this.width,
    this.height,
    this.borderRadius = 8,
    this.shape = BoxShape.rectangle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: shape == BoxShape.circle ? null : BorderRadius.circular(borderRadius),
        shape: shape,
      ),
    );
  }
}

/// Pre-built skeleton for a list of items
class SkeletonList extends StatelessWidget {
  final int itemCount;
  final Widget skeleton;
  final double spacing;
  final bool isHorizontal;
  final EdgeInsetsGeometry? padding;

  const SkeletonList({
    super.key,
    this.itemCount = 5,
    required this.skeleton,
    this.spacing = 16,
    this.isHorizontal = false,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      scrollDirection: isHorizontal ? Axis.horizontal : Axis.vertical,
      padding: padding,
      itemCount: itemCount,
      separatorBuilder: (context, index) => SizedBox(
        width: isHorizontal ? spacing : 0,
        height: isHorizontal ? 0 : spacing,
      ),
      itemBuilder: (context, index) => skeleton,
    );
  }
}

/// ---------------------------------------------------------
/// FEATURE-SPECIFIC SKELETONS
/// ---------------------------------------------------------

/// Skeleton for Announcement Card in HomeScreen
class AnnouncementSkeleton extends StatelessWidget {
  const AnnouncementSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return DitaSkeleton(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            const SkeletonBox(width: 50, height: 50, borderRadius: 12),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                   SkeletonBox(width: MediaQuery.of(context).size.width * 0.5, height: 16),
                  const SizedBox(height: 8),
                  const SkeletonBox(width: double.infinity, height: 12),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Skeleton for Event/Resource Card
class CardSkeleton extends StatelessWidget {
  final bool hasImage;
  const CardSkeleton({super.key, this.hasImage = true});

  @override
  Widget build(BuildContext context) {
    return DitaSkeleton(
      child: Container(
        width: 250,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (hasImage) 
              const SkeletonBox(width: double.infinity, height: 90, borderRadius: 20),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SkeletonBox(width: 150, height: 16),
                  const SizedBox(height: 8),
                  const SkeletonBox(width: 100, height: 12),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Skeleton for Community Post
class PostSkeleton extends StatelessWidget {
  const PostSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return DitaSkeleton(
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const SkeletonBox(width: 40, height: 40, shape: BoxShape.circle),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SkeletonBox(width: 120, height: 14),
                    const SizedBox(height: 4),
                    const SkeletonBox(width: 80, height: 10),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),
            const SkeletonBox(width: double.infinity, height: 14),
            const SizedBox(height: 8),
            const SkeletonBox(width: double.infinity, height: 14),
            const SizedBox(height: 8),
            const SkeletonBox(width: 150, height: 14),
            const SizedBox(height: 16),
            const SkeletonBox(width: double.infinity, height: 200, borderRadius: 12),
          ],
        ),
      ),
    );
  }
}

/// Skeleton for Leaderboard Entry
class LeaderboardSkeleton extends StatelessWidget {
  const LeaderboardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return DitaSkeleton(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
        child: Row(
          children: [
            const SkeletonBox(width: 30, height: 20),
            const SizedBox(width: 15),
            const SkeletonBox(width: 45, height: 45, shape: BoxShape.circle),
            const SizedBox(width: 15),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SkeletonBox(width: 150, height: 14),
                  const SizedBox(height: 4),
                  const SkeletonBox(width: 100, height: 10),
                ],
              ),
            ),
            const SkeletonBox(width: 60, height: 20, borderRadius: 20),
          ],
        ),
      ),
    );
  }
}

/// Skeleton for a single comment
class CommentSkeleton extends StatelessWidget {
  const CommentSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return DitaSkeleton(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SkeletonBox(width: 35, height: 35, shape: BoxShape.circle),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                   Row(
                    children: [
                      const SkeletonBox(width: 80, height: 12),
                      const Spacer(),
                      const SkeletonBox(width: 40, height: 10),
                    ],
                  ),
                  const SizedBox(height: 6),
                  const SkeletonBox(width: double.infinity, height: 12),
                  const SizedBox(height: 4),
                  const SkeletonBox(width: 150, height: 12),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Skeleton for a single task item
class TaskSkeleton extends StatelessWidget {
  const TaskSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return DitaSkeleton(
      child: Container(
        margin: const EdgeInsets.only(bottom: 15),
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(15),
        ),
        child: Row(
          children: [
            const SkeletonBox(width: 25, height: 25, borderRadius: 5),
            const SizedBox(width: 15),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                   SkeletonBox(width: MediaQuery.of(context).size.width * 0.4, height: 14),
                  const SizedBox(height: 8),
                  const SkeletonBox(width: 100, height: 10),
                ],
              ),
            ),
            const SkeletonBox(width: 60, height: 10),
          ],
        ),
      ),
    );
  }
}

/// Skeleton for timetable (Class/Exam)
class TimetableSkeleton extends StatelessWidget {
  const TimetableSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return DitaSkeleton(
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: List.generate(5, (index) => Padding(
            padding: const EdgeInsets.only(bottom: 20),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Column(
                  children: [
                    SkeletonBox(width: 40, height: 14),
                    SizedBox(height: 4),
                    SkeletonBox(width: 30, height: 10),
                  ],
                ),
                const SizedBox(width: 15),
                const Column(
                  children: [
                    SkeletonBox(width: 12, height: 12, shape: BoxShape.circle),
                    SizedBox(height: 4),
                    SkeletonBox(width: 2, height: 60),
                  ],
                ),
                const SizedBox(width: 15),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SkeletonBox(width: 150, height: 16),
                        SizedBox(height: 8),
                        SkeletonBox(width: 100, height: 12),
                        SizedBox(height: 8),
                        SkeletonBox(width: 80, height: 10),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          )),
        ),
      ),
    );
  }
}
