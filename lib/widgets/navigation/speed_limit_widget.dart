import 'package:flutter/material.dart';

class SpeedLimitWidget extends StatelessWidget {
  final int limit;
  final bool isSpeeding;

  const SpeedLimitWidget({
    super.key,
    required this.limit,
    this.isSpeeding = false,
  });

  @override
  Widget build(BuildContext context) {
    if (limit <= 0) return const SizedBox.shrink();

    return Container(
      width: 54,
      height: 54,
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        border: Border.all(
          color: const Color(0xFFFF3B30), // iOS Red
          width: 5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.4),
            blurRadius: 15,
            offset: const Offset(0, 6),
          )
        ],
      ),
      child: Center(
        child: Text(
          limit.toString(),
          style: const TextStyle(
            color: Colors.black,
            fontSize: 22,
            fontWeight: FontWeight.w800,
            letterSpacing: -1,
          ),
        ),
      ),
    );
  }
}
