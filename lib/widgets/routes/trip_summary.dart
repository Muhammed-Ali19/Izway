import 'package:flutter/material.dart';

class TripSummary extends StatelessWidget {
  final List<String> countryFlags;
  final bool isLoading;
  final String? nextBorderDistance;
  final String? nextBorderFlag;
  final String? waitTime;

  const TripSummary({
    super.key,
    required this.countryFlags,
    this.isLoading = false,
    this.nextBorderDistance,
    this.nextBorderFlag,
    this.waitTime,
  });

  @override
  Widget build(BuildContext context) {
    if (countryFlags.isEmpty && !isLoading) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B).withValues(alpha: 0.9), // Slate
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isLoading && countryFlags.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                children: [
                  const SizedBox(
                    width: 12,
                    height: 12,
                    child: CircularProgressIndicator(
                      strokeWidth: 2, 
                      color: Colors.blueAccent,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    "Analyse...", 
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.6), 
                      fontSize: 11,
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
                      Text(flag, style: const TextStyle(fontSize: 14)),
                      if (i < countryFlags.length - 1)
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: Icon(
                            Icons.chevron_right_rounded, 
                            color: Colors.white.withValues(alpha: 0.2), 
                            size: 14
                          ),
                        ),
                    ],
                  );
                }).toList(),
              ),
            ),
          ],
          
          if (nextBorderDistance != null) ...[
             const SizedBox(height: 4),
             Row(
               mainAxisSize: MainAxisSize.min,
               children: [
                 Text(nextBorderFlag ?? "🌍", style: const TextStyle(fontSize: 14)),
                 const SizedBox(width: 6),
                 Text(
                   nextBorderDistance!,
                   style: const TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w600),
                 ),
                  const SizedBox(width: 8),
                  Text(
                    waitTime != null ? "Attente : $waitTime" : "Attente : ...",
                    style: const TextStyle(color: Colors.amberAccent, fontSize: 10, fontWeight: FontWeight.bold),
                  ),
               ],
             ),
          ],
        ],
      ),
    );
  }
}
