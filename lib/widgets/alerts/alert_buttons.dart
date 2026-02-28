import 'package:flutter/material.dart';
import '../../models/alert.dart';

class AlertButtons extends StatefulWidget {
  final Function(AlertType) onAlertSelected;

  const AlertButtons({super.key, required this.onAlertSelected});

  @override
  AlertButtonsState createState() => AlertButtonsState();
}

class AlertButtonsState extends State<AlertButtons> with SingleTickerProviderStateMixin {
  bool _isExpanded = false;
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 250),
      vsync: this,
    );
    _animation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutBack,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _toggleMenu() {
    setState(() {
      _isExpanded = !_isExpanded;
      if (_isExpanded) {
        _controller.forward();
      } else {
        _controller.reverse();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        if (_isExpanded || !_controller.isDismissed) ...[
          _buildAlertButton(AlertType.police, Icons.local_police_rounded, Colors.blueAccent),
          const SizedBox(height: 12),
          _buildAlertButton(AlertType.accident, Icons.warning_rounded, const Color(0xFFEF4444)),
          const SizedBox(height: 12),
        ],
        GestureDetector(
          onTap: _toggleMenu,
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF1E293B), // Slate
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.4),
                  blurRadius: 15,
                  offset: const Offset(0, 6),
                )
              ],
            ),
            child: RotationTransition(
              turns: Tween(begin: 0.0, end: 0.125).animate(_animation),
              child: Icon(
                _isExpanded ? Icons.add_rounded : Icons.report_rounded, 
                color: _isExpanded ? Colors.white.withValues(alpha: 0.5) : Colors.blueAccent, 
                size: 28
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAlertButton(AlertType type, IconData icon, Color color) {
    return ScaleTransition(
      scale: _animation,
      child: FadeTransition(
        opacity: _animation,
        child: GestureDetector(
          onTap: () {
            widget.onAlertSelected(type);
            _toggleMenu();
          },
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF1E293B), // Slate
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.4),
                  blurRadius: 18,
                  offset: const Offset(0, 8),
                )
              ],
            ),
            child: Icon(icon, color: color, size: 24),
          ),
        ),
      ),
    );
  }
}
