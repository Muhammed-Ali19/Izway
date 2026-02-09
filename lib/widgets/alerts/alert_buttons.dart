import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import '../../models/alert.dart';

class AlertButtons extends StatefulWidget {
  final Function(AlertType) onAlertSelected;

  const AlertButtons({Key? key, required this.onAlertSelected}) : super(key: key);

  @override
  _AlertButtonsState createState() => _AlertButtonsState();
}

class _AlertButtonsState extends State<AlertButtons> with SingleTickerProviderStateMixin {
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
      curve: Curves.easeOut,
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
        if (_isExpanded) ...[
          _buildAlertButton(AlertType.police, "Police", Colors.blue),
          const SizedBox(height: 10),
          _buildAlertButton(AlertType.accident, "Accident", Colors.red),
          const SizedBox(height: 15),
        ],
        FloatingActionButton(
          onPressed: _toggleMenu,
          backgroundColor: _isExpanded ? Colors.grey[800] : Colors.orangeAccent,
          child: Icon(
            _isExpanded ? Icons.close : Icons.add_alert_rounded,
            color: Colors.white,
            size: 28,
          ),
        ),
      ],
    );
  }

  Widget _buildAlertButton(AlertType type, String label, Color color) {
    final alert = Alert(
      id: '', 
      type: type, 
      position: const LatLng(0,0), // Dummy
      timestamp: DateTime.now()
    );

    return ScaleTransition(
      scale: _animation,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.black87,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              label,
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(width: 10),
          FloatingActionButton.small(
            heroTag: "btn_$label",
            onPressed: () {
              widget.onAlertSelected(type);
              _toggleMenu();
            },
            backgroundColor: color,
            child: Text(
              alert.icon,
              style: const TextStyle(fontSize: 20),
            ),
          ),
        ],
      ),
    );
  }
}
