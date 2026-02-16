import 'package:flutter/material.dart';

class ModernSearchBar extends StatelessWidget {
  final TextEditingController controller;
  final Function(String) onSubmitted;
  final Function(String) onChanged;
  final bool isSearching;
  final VoidCallback onClear;

  const ModernSearchBar({
    super.key,
    required this.controller,
    required this.onSubmitted,
    required this.onChanged,
    this.isSearching = false,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 60, left: 16, right: 16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B), // Slate
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 15,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: TextField(
        controller: controller,
        style: const TextStyle(
          fontSize: 16, 
          color: Colors.white,
          fontWeight: FontWeight.w500,
        ),
        decoration: InputDecoration(
          hintText: "Où allez-vous ?",
          hintStyle: TextStyle(
            color: Colors.white.withValues(alpha: 0.4), 
            fontSize: 16,
          ),
          prefixIcon: const Icon(
            Icons.search_rounded, 
            color: Colors.blueAccent,
            size: 24,
          ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 14),
          suffixIcon: isSearching
              ? UnconstrainedBox(
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.blueAccent),
                    ),
                  ),
                )
              : controller.text.isNotEmpty
                  ? IconButton(
                      icon: Icon(Icons.close_rounded, color: Colors.white.withValues(alpha: 0.5)),
                      onPressed: onClear,
                    )
                  : null,
        ),
        onSubmitted: onSubmitted,
        onChanged: onChanged,
        textInputAction: TextInputAction.search,
      ),
    );
  }
}
