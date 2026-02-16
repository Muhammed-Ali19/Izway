import 'package:flutter/material.dart';

class NavigationDashboard extends StatelessWidget {
  final String duration;
  final String distance;
  final String eta;
  final String? nextBorderDist;
  final String? nextBorderFlag;
  final int alertCount;
  final VoidCallback onStopNavigation;

  const NavigationDashboard({
    super.key,
    required this.duration,
    required this.distance,
    required this.eta,
    this.nextBorderDist,
    this.nextBorderFlag,
    this.alertCount = 0,
    required this.onStopNavigation,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: GestureDetector(
        onLongPress: () => _showDebugInfo(context),
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          decoration: BoxDecoration(
            color: const Color(0xFF0F172A).withOpacity(0.95),
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(20),
              topRight: Radius.circular(20),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.3),
                blurRadius: 10,
                offset: const Offset(0, -2),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Main Stats Row + Exit Button
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Duration (Main focus)
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          duration,
                          style: const TextStyle(
                            color: Color(0xFF34D399),
                            fontSize: 28, // Smaller than 32
                            fontWeight: FontWeight.w900,
                            height: 1.0,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            _buildInlineStat(distance, Icons.social_distance),
                            const SizedBox(width: 12),
                            _buildInlineStat("Arrivé à  $eta", Icons.schedule),
                          ],
                        ),
                      ],
                    ),
                  ),
                  
                  // Exit Button (Compact)
                  Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFFEF4444).withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: IconButton(
                      onPressed: onStopNavigation,
                      icon: const Icon(Icons.close, color: Color(0xFFEF4444)),
                      tooltip: "Quitter",
                    ),
                  ),
                ],
              ),
              
              // Optional Border Alert (Compact)
              if (nextBorderDist != null) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E293B),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.white.withOpacity(0.1)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(nextBorderFlag ?? "🌍", style: const TextStyle(fontSize: 16)),
                      const SizedBox(width: 8),
                      Text(
                        "Frontière dans $nextBorderDist",
                        style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  void _showDebugInfo(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Debug Info", style: TextStyle(color: Colors.black)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Next Border: $nextBorderDist"),
            Text("Flag: $nextBorderFlag"),
            Text("Active Alerts (Debug): $alertCount"),
            const SizedBox(height: 8),
            Text("Check Console logs for 'DEBUG: Border found' messages."),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("OK"))
        ],
      ),
    );
  }

  Widget _buildInlineStat(String value, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 14, color: Colors.white.withOpacity(0.5)),
        const SizedBox(width: 4),
        Text(
          value,
          style: TextStyle(
            color: Colors.white.withOpacity(0.8),
            fontSize: 14, 
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
