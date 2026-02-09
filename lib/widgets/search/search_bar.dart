import 'package:flutter/material.dart';

class ModernSearchBar extends StatelessWidget {
  final TextEditingController controller;
  final Function(String) onSubmitted;
  final Function(String) onChanged;
  final bool isSearching;
  final VoidCallback onClear;

  const ModernSearchBar({
    Key? key,
    required this.controller,
    required this.onSubmitted,
    required this.onChanged,
    this.isSearching = false,
    required this.onClear,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 50, left: 16, right: 16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: TextField(
        controller: controller,
        style: TextStyle(fontSize: 16, color: Theme.of(context).textTheme.bodyLarge?.color),
        decoration: InputDecoration(
          hintText: "Où allez-vous ?",
          hintStyle: TextStyle(color: Colors.grey[500]),
          prefixIcon: const Icon(Icons.search, color: Colors.blueAccent),
          suffixIcon: isSearching
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
                )
              : (controller.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear, color: Colors.grey),
                      onPressed: onClear,
                    )
                  : null),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
        ),
        onSubmitted: onSubmitted,
        onChanged: onChanged,
        textInputAction: TextInputAction.search,
      ),
    );
  }
}
