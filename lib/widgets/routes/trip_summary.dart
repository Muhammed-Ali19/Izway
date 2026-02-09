import 'dart:ui';
import 'package:flutter/material.dart';

class TripSummary extends StatelessWidget {
  final List<String> countryFlags;
  final bool isLoading;
  final String? nextBorderDistance;
  final String? nextBorderFlag;

  const TripSummary({
    Key? key,
    required this.countryFlags,
    this.isLoading = false,
    this.nextBorderDistance,
    this.nextBorderFlag,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (countryFlags.isEmpty && !isLoading) return const SizedBox.shrink();

    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: const Color(0xFF1E293B).withOpacity(0.6),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withOpacity(0.15)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                "Pays Traversés",
                style: TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                    fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              if (isLoading && countryFlags.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white70),
                      ),
                      SizedBox(width: 12),
                      Text("Détection des pays...", style: TextStyle(color: Colors.white54, fontSize: 13)),
                    ],
                  ),
                ),
              if (countryFlags.isNotEmpty) ...[
                const SizedBox(height: 8),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                child: Row(
                  children: countryFlags.asMap().entries.map((entry) {
                    final i = entry.key;
                    final flag = entry.value;
                    return Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.05),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(flag, style: const TextStyle(fontSize: 24)),
                        ),
                        if (i < countryFlags.length - 1)
                          const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 4),
                            child: Icon(Icons.chevron_right, color: Colors.white24, size: 16),
                          ),
                      ],
                    );
                  }).toList(),
                ),
              ),
            ],
          ],
        ),
      ),
    ),
  );
}
}
