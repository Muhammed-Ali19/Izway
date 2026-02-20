import 'package:flutter/material.dart';
import '../../models/route_models.dart';

class RouteSelector extends StatelessWidget {
  final List<RouteInfo> routes;
  final int selectedIndex;
  final Function(int) onRouteSelected;
  final VoidCallback onStartNavigation;

  const RouteSelector({
    super.key,
    required this.routes,
    required this.selectedIndex,
    required this.onRouteSelected,
    required this.onStartNavigation,
  });

  @override
  Widget build(BuildContext context) {
    if (routes.isEmpty) return const SizedBox.shrink();

    // Compact Mode: Max height 240
    return Container(
      height: 240, 
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.9), 
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.5),
            blurRadius: 20,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: Column(
        children: [
          // Drag handle
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Container(
              width: 30,
              height: 3,
              decoration: BoxDecoration(
                color: Colors.grey[700],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
              itemCount: routes.length,
              separatorBuilder: (c, i) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final route = routes[index];
                final isSelected = index == selectedIndex;
                
                return GestureDetector(
                  onTap: () => onRouteSelected(index),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: isSelected 
                        ? const Color(0xFF1E293B)
                        : Colors.white.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: isSelected ? Colors.blueAccent : Colors.transparent,
                        width: isSelected ? 1.5 : 0.0,
                      ),
                    ),
                    child: Row(
                      children: [
                        // Left: Label & Duration
                        Expanded(
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: isSelected ? Colors.blueAccent.withValues(alpha: 0.2) : Colors.grey.withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  route.label.toUpperCase(),
                                  style: TextStyle(
                                    color: isSelected ? Colors.blueAccent : Colors.grey,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 10,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                route.formattedDuration,
                                style: TextStyle(
                                  color: isSelected ? const Color(0xFF34D399) : Colors.white.withValues(alpha: 0.9),
                                  fontWeight: FontWeight.w800,
                                  fontSize: 16,
                                ),
                              ),
                              const Spacer(),
                              Text(
                                route.formattedDistance,
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.6),
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                        
                        // Right: Selection Indicator (minimal dot)
                        if (isSelected) ...[
                          const SizedBox(width: 8),
                          const Icon(Icons.check_circle, size: 18, color: Colors.blueAccent),
                        ],
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          
          // Compact Button
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
            child: SizedBox(
              width: double.infinity,
              height: 42,
              child: ElevatedButton(
                onPressed: onStartNavigation,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blueAccent,
                  foregroundColor: Colors.white,
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: const Text(
                  "PARTIR",
                  style: TextStyle(
                    fontWeight: FontWeight.w900, 
                    fontSize: 14,
                    letterSpacing: 1.0,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
