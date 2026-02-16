import 'package:flutter/material.dart';
import '../../models/route_models.dart';

class SearchResults extends StatelessWidget {
  final List<SearchResult> results;
  final Function(SearchResult) onResultSelected;

  const SearchResults({
    super.key,
    required this.results,
    required this.onResultSelected,
  });

  @override
  Widget build(BuildContext context) {
    if (results.isEmpty) return const SizedBox.shrink();

    return Positioned(
      top: 125,
      left: 16,
      right: 16,
      child: Container(
        constraints: const BoxConstraints(maxHeight: 300),
        decoration: BoxDecoration(
          color: const Color(0xFF1E293B), // Slate
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.4),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: ListView.separated(
          shrinkWrap: true,
          padding: EdgeInsets.zero,
          itemCount: results.length,
          separatorBuilder: (context, index) => Divider(
            height: 1, 
            color: Colors.white.withValues(alpha: 0.1),
            indent: 60,
          ),
          itemBuilder: (ctx, i) {
            final res = results[i];
            return ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              title: Text(
                res.displayName,
                style: const TextStyle(
                  color: Colors.white, 
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.blueAccent.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.location_on_rounded, 
                  color: Colors.blueAccent, 
                  size: 20
                ),
              ),
              tileColor: Colors.transparent,
              onTap: () => onResultSelected(res),
            );
          },
        ),
      ),
    );
  }
}
