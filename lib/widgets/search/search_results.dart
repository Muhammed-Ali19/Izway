import 'package:flutter/material.dart';
import '../../models/route_models.dart';

class SearchResults extends StatelessWidget {
  final List<SearchResult> results;
  final Function(SearchResult) onResultSelected;

  const SearchResults({
    Key? key,
    required this.results,
    required this.onResultSelected,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (results.isEmpty) return const SizedBox.shrink();

    return Positioned(
      top: 110,
      left: 16,
      right: 16,
      child: Container(
        constraints: const BoxConstraints(maxHeight: 300),
        decoration: BoxDecoration(
          color: const Color(0xFF1E293B),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: ListView.separated(
            padding: EdgeInsets.zero,
            itemCount: results.length,
            separatorBuilder: (_, __) => const Divider(height: 1, color: Colors.white10),
            itemBuilder: (ctx, i) {
              final res = results[i];
              return ListTile(
                title: Text(
                  res.displayName,
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                leading: const Icon(Icons.place, color: Colors.blueAccent),
                tileColor: Colors.transparent,
                hoverColor: Colors.white10,
                onTap: () => onResultSelected(res),
              );
            },
          ),
        ),
      ),
    );
  }
}
