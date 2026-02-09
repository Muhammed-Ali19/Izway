import 'dart:ui';
import 'package:flutter/material.dart';

class InstructionBanner extends StatelessWidget {
  final String instruction;
  final String distance;
  final IconData icon;

  const InstructionBanner({
    Key? key,
    required this.instruction,
    required this.distance,
    this.icon = Icons.turn_right,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 50,
      left: 16,
      right: 16,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF1E293B).withOpacity(0.7), // Glassy dark blue
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white.withOpacity(0.2)),
            ),
            child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.green,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: Colors.white, size: 32),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    distance,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    instruction,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 16,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
            ),
          ),
        ),
      ),
    );
  }
}
