import 'package:flutter/material.dart';

class SpeedLimitWidget extends StatelessWidget {
  final int limit;
  final bool isSpeeding;

  const SpeedLimitWidget({
    Key? key,
    required this.limit,
    this.isSpeeding = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      width: 65,
      height: 65,
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        border: Border.all(
          color: isSpeeding ? Colors.redAccent : Colors.red, 
          width: isSpeeding ? 8 : 6
        ),
        boxShadow: [
          BoxShadow(
            color: isSpeeding ? Colors.red.withOpacity(0.6) : Colors.black.withOpacity(0.2),
            blurRadius: isSpeeding ? 15 : 6,
            spreadRadius: isSpeeding ? 5 : 0,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Center(
        child: Text(
          limit.toString(),
          style: TextStyle(
            color: isSpeeding ? Colors.red[900] : Colors.black,
            fontSize: 26,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}
