import 'package:flutter/material.dart';

class TripSummary extends StatelessWidget {
  final List<String> countryFlags;
  final bool isLoading;
  final String? nextBorderDistance;
  final String? nextBorderFlag;

  const TripSummary({
    super.key,
    required this.countryFlags,
    this.isLoading = false,
    this.nextBorderDistance,
    this.nextBorderFlag,
  });

  @override
  Widget build(BuildContext context) {
    if (countryFlags.isEmpty && !isLoading) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B), // Slate
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 15,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            "ITINÉRAIRE",
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.5),
              fontSize: 11,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.0,
            ),
          ),
          const SizedBox(height: 12),
          if (isLoading && countryFlags.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                      strokeWidth: 2, 
                      color: Colors.blueAccent,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    "Analyse des régions...", 
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.6), 
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          if (countryFlags.isNotEmpty) ...[
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
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(flag, style: const TextStyle(fontSize: 24)),
                      ),
                      if (i < countryFlags.length - 1)
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 6),
                          child: Icon(
                            Icons.chevron_right_rounded, 
                            color: Colors.white.withValues(alpha: 0.2), 
                            size: 20
                          ),
                        ),
                    ],
                  );
                }).toList(),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
