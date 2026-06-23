import 'package:flutter/material.dart';

/// Reusable pulsating shimmer skeleton widget for placeholders.
class ShimmerSkeleton extends StatefulWidget {
  final double width;
  final double height;
  final double borderRadius;

  const ShimmerSkeleton({
    super.key,
    required this.width,
    required this.height,
    this.borderRadius = 8,
  });

  @override
  State<ShimmerSkeleton> createState() => _ShimmerSkeletonState();
}

class _ShimmerSkeletonState extends State<ShimmerSkeleton> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _animation = Tween<double>(begin: 0.35, end: 0.75).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Opacity(
          opacity: _animation.value,
          child: Container(
            width: widget.width,
            height: widget.height,
            decoration: BoxDecoration(
              color: const Color(0xFFE0E3E7),
              borderRadius: BorderRadius.circular(widget.borderRadius),
            ),
          ),
        );
      },
    );
  }
}

/// A skeleton loader mimicking the Lootlo Game Card.
class GameCardSkeleton extends StatelessWidget {
  const GameCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE0E3E5)),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ShimmerSkeleton(width: 140, height: 18, borderRadius: 4),
                  SizedBox(height: 8),
                  ShimmerSkeleton(width: 100, height: 14, borderRadius: 4),
                ],
              ),
              ShimmerSkeleton(width: 70, height: 40, borderRadius: 8),
            ],
          ),
          SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              ShimmerSkeleton(width: 80, height: 12, borderRadius: 3),
              ShimmerSkeleton(width: 50, height: 12, borderRadius: 3),
            ],
          ),
          SizedBox(height: 8),
          ShimmerSkeleton(width: double.infinity, height: 8, borderRadius: 4),
          SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ShimmerSkeleton(width: 60, height: 10, borderRadius: 2),
                  SizedBox(height: 6),
                  ShimmerSkeleton(width: 70, height: 18, borderRadius: 4),
                ],
              ),
              ShimmerSkeleton(width: 90, height: 38, borderRadius: 10),
            ],
          )
        ],
      ),
    );
  }
}

/// A skeleton loader mimicking the Lootlo Ticket Group Card.
class TicketGroupCardSkeleton extends StatelessWidget {
  const TicketGroupCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE0E3E5)),
      ),
      child: const Row(
        children: [
          ShimmerSkeleton(width: 48, height: 48, borderRadius: 12),
          SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ShimmerSkeleton(width: 150, height: 16, borderRadius: 4),
                SizedBox(height: 6),
                ShimmerSkeleton(width: 110, height: 12, borderRadius: 4),
                SizedBox(height: 8),
                ShimmerSkeleton(width: 76, height: 20, borderRadius: 6),
              ],
            ),
          ),
          ShimmerSkeleton(width: 24, height: 24, borderRadius: 12),
        ],
      ),
    );
  }
}
