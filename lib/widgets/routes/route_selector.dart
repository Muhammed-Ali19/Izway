import 'package:flutter/material.dart';
import '../../models/route_models.dart';

class RouteSelector extends StatelessWidget {
  final List<RouteInfo> routes;
  final int selectedIndex;
  final Function(int) onRouteSelected;
  final VoidCallback onStartNavigation;

  const RouteSelector({
    Key? key,
    required this.routes,
    required this.selectedIndex,
    required this.onRouteSelected,
    required this.onStartNavigation,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (routes.isEmpty) return const SizedBox.shrink();

    return Container(
      height: 220,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.transparent,
            Colors.black.withOpacity(0.8),
          ],
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          SizedBox(
            height: 140,
            child: PageView.builder(
              controller: PageController(viewportFraction: 0.85),
              itemCount: routes.length,
              onPageChanged: onRouteSelected,
              itemBuilder: (context, index) {
                final route = routes[index];
                final isSelected = index == selectedIndex;
                
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isSelected ? const Color(0xFF1E293B) : Colors.black54,
                    borderRadius: BorderRadius.circular(16),
                    border: isSelected 
                        ? Border.all(color: Colors.blueAccent, width: 2)
                        : null,
                    boxShadow: [
                      if (isSelected)
                        BoxShadow(
                          color: Colors.blueAccent.withOpacity(0.3),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: isSelected ? Colors.blueAccent : Colors.grey,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              route.label,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ),
                          Text(
                            route.formattedDuration,
                            style: TextStyle(
                              color: isSelected ? Colors.greenAccent : Colors.white70,
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                            ),
                          ),
                        ],
                      ),
                      const Spacer(),
                      Row(
                        children: [
                          const Icon(Icons.directions_car, color: Colors.white60, size: 16),
                          const SizedBox(width: 4),
                          Text(
                            route.formattedDistance,
                            style: const TextStyle(color: Colors.white70),
                          ),
                          const Spacer(),
                          if (isSelected)
                            ElevatedButton(
                              onPressed: onStartNavigation,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(20),
                                ),
                              ),
                              child: const Text("Démarrer"),
                            ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}
