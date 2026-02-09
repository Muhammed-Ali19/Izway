import 'dart:ui';
import 'package:flutter/material.dart';

class NavigationDashboard extends StatelessWidget {
  final String duration;
  final String distance;
  final String eta;
  final String? nextBorderDist;
  final String? nextBorderFlag;
  final VoidCallback onStopNavigation;

  const NavigationDashboard({
    Key? key,
    required this.duration,
    required this.distance,
    required this.eta,
    this.nextBorderDist,
    this.nextBorderFlag,
    required this.onStopNavigation,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: const BorderRadius.only(
        topLeft: Radius.circular(30),
        topRight: Radius.circular(30),
      ),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
        child: Container(
          padding: const EdgeInsets.only(top: 25, left: 25, right: 25, bottom: 40),
          decoration: BoxDecoration(
            color: const Color(0xFF1E293B).withOpacity(0.7),
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(30),
              topRight: Radius.circular(30),
            ),
            border: Border(
              top: BorderSide(color: Colors.white.withOpacity(0.2), width: 1),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    duration,
                    style: const TextStyle(
                      color: Colors.greenAccent,
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Text(
                        distance,
                        style: const TextStyle(color: Colors.white70, fontSize: 16),
                      ),
                      const SizedBox(width: 10),
                      const Text(
                        "•",
                        style: TextStyle(color: Colors.white30),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        "Arrivée à $eta",
                        style: const TextStyle(color: Colors.white70, fontSize: 16),
                      ),
                    ],
                  ),
                  if (nextBorderDist != null) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.blueAccent.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.blueAccent.withOpacity(0.5)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(nextBorderFlag ?? "🌍", style: const TextStyle(fontSize: 14)),
                          const SizedBox(width: 6),
                          Text(
                            "Frontière dans $nextBorderDist",
                            style: const TextStyle(color: Colors.blueAccent, fontSize: 13, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    onPressed: onStopNavigation,
                    icon: const Icon(Icons.close, color: Colors.white, size: 32),
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.redAccent,
                      padding: const EdgeInsets.all(12),
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text("Quitter",
                      style: TextStyle(
                          color: Colors.redAccent,
                          fontSize: 12,
                          fontWeight: FontWeight.bold)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
