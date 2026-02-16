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

    return Container(
      height: 320, // Taller for vertical list
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.9), // Darker background
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
          // Drag handle / Title
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[700],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              itemCount: routes.length,
              separatorBuilder: (c, i) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final route = routes[index];
                final isSelected = index == selectedIndex;
                
                return GestureDetector(
                  onTap: () => onRouteSelected(index),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: isSelected 
                        ? const Color(0xFF1E293B) // Selected Slate
                        : Colors.white.withValues(alpha: 0.05), // Unselected dim
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSelected ? Colors.blueAccent : Colors.transparent,
                        width: isSelected ? 2.0 : 1.0,
                      ),
                    ),
                    child: Row(
                      children: [
                        // Left: Label & Duration
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
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
                                    route.formattedDistance,
                                    style: TextStyle(
                                      color: Colors.white.withValues(alpha: 0.6),
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                route.formattedDuration,
                                style: TextStyle(
                                  color: isSelected ? const Color(0xFF34D399) : Colors.white.withValues(alpha: 0.8),
                                  fontWeight: FontWeight.w900,
                                  fontSize: 20,
                                ),
                              ),
                            ],
                          ),
                        ),
                        
                        // Right: Selection Indicator
                        Container(
                          width: 24,
                          height: 24,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: isSelected ? Colors.blueAccent : Colors.white.withValues(alpha: 0.3),
                              width: 2,
                            ),
                            color: isSelected ? Colors.blueAccent : Colors.transparent,
                          ),
                          child: isSelected 
                            ? const Icon(Icons.check, size: 16, color: Colors.white) 
                            : null,
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          
          // Fixed Bottom Button
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24), // Bottom padding for safe area
            child: SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: onStartNavigation,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blueAccent,
                  foregroundColor: Colors.white,
                  elevation: 4,
                  shadowColor: Colors.blueAccent.withValues(alpha: 0.4),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  "PARTIR",
                  style: TextStyle(
                    fontWeight: FontWeight.w900, 
                    fontSize: 16,
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
