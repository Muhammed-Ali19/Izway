import 'package:flutter/material.dart';

class NavigationDashboard extends StatelessWidget {
  final String duration;
  final String distance;
  final String eta;
  final String? nextBorderDist;
  final String? nextBorderFlag;
  final VoidCallback onStopNavigation;

  const NavigationDashboard({
    super.key,
    required this.duration,
    required this.distance,
    required this.eta,
    this.nextBorderDist,
    this.nextBorderFlag,
    required this.onStopNavigation,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 40),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A), // Navy
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.5),
            blurRadius: 20,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "ARRIVÉE",
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.5), 
                        fontSize: 12, 
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.0,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      duration,
                      style: const TextStyle(
                        color: Color(0xFF34D399), // Emerald/Green (Improved Base)
                        fontSize: 32,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ),
              _buildStatBlock("DIST.", distance),
              const SizedBox(width: 24),
              _buildStatBlock("ETA", eta),
            ],
          ),
          const SizedBox(height: 24),
          if (nextBorderDist != null) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: const Color(0xFF1E293B), // Slate
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Text(nextBorderFlag ?? "🌍", style: const TextStyle(fontSize: 22)),
                  const SizedBox(width: 12),
                  Text(
                    "FRONTIÈRE: ",
                    style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                  Text(
                    nextBorderDist!,
                    style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w900),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
          ],
          SizedBox(
            width: double.infinity,
            height: 60,
            child: ElevatedButton(
              onPressed: onStopNavigation,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFEF4444), // Red-500
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                "ARRÊTER LA NAVIGATION",
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, letterSpacing: 0.5),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatBlock(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.5), 
            fontSize: 11, 
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}
