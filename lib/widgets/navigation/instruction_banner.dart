import 'package:flutter/material.dart';

class InstructionBanner extends StatelessWidget {
  final String instruction;
  final String distance;
  final IconData icon;
  final String? nextBorderDist;
  final String? nextBorderFlag;
  final String? nextBorderInfo;
  final String? waitTime;

  const InstructionBanner({
    super.key,
    required this.instruction,
    required this.distance,
    this.icon = Icons.turn_right,
    this.nextBorderDist,
    this.nextBorderFlag,
    this.nextBorderInfo,
    this.waitTime,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: const Color(0xFF1E293B).withValues(alpha: 0.98),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.4),
                blurRadius: 15,
                offset: const Offset(0, 6),
              ),
            ],
            border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
          ),
          child: Row(
            children: [
              // Direction Icon
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.blueAccent.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: Colors.blueAccent, size: 28),
              ),
              const SizedBox(width: 12),
              
              // Instruction Text (Flexible part)
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      distance.toUpperCase(),
                      style: const TextStyle(
                        color: Colors.blueAccent,
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.2,
                      ),
                    ),
                    Text(
                      instruction,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              
              // Border Info
              if (nextBorderDist != null) ...[
                Container(
                  width: 1,
                  height: 30,
                  margin: const EdgeInsets.symmetric(horizontal: 12),
                  color: Colors.white12,
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(nextBorderFlag ?? "🌍", style: const TextStyle(fontSize: 16)),
                        const SizedBox(width: 6),
                        Text(
                          nextBorderDist!,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                    Text(
                      waitTime != null ? "Attente : $waitTime" : "Attente : ...",
                      style: TextStyle(
                        color: Colors.amberAccent.withValues(alpha: 0.9),
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
        
        // Secondary detail
        if (nextBorderInfo != null) ...[
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFF0F172A).withValues(alpha: 0.8),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              nextBorderInfo!,
              style: const TextStyle(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ],
    );
  }
}
