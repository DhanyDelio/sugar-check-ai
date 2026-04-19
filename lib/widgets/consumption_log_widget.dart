import 'package:flutter/material.dart';
import '../models/sugar_entry.dart';

/// Horizontal scroll list of today's consumption entries
class ConsumptionLogWidget extends StatelessWidget {
  final List<SugarEntry> entries;

  const ConsumptionLogWidget({super.key, required this.entries});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "Today's Consumption",
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 14),
        if (entries.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Text(
              "No entries yet — scan a product to get started!",
              style: TextStyle(
                fontSize: 13,
                color: Colors.white.withValues(alpha: 0.35),
              ),
            ),
          )
        else
          SizedBox(
            height: 148,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: entries.length,
              itemBuilder: (context, index) =>
                  _LogCard(entry: entries[index]),
            ),
          ),
      ],
    );
  }
}

class _LogCard extends StatelessWidget {
  final SugarEntry entry;

  const _LogCard({required this.entry});

  String _emoji(String name) {
    final lower = name.toLowerCase();
    if (lower.contains('teh') || lower.contains('tea')) return '🍵';
    if (lower.contains('susu') || lower.contains('milk')) return '🥛';
    if (lower.contains('cokelat') || lower.contains('choco')) return '🍫';
    if (lower.contains('juice') || lower.contains('jus')) return '🧃';
    if (lower.contains('oreo') || lower.contains('cookie')) return '🍪';
    if (lower.contains('indomie') || lower.contains('noodle')) return '🍜';
    return '🍬';
  }

  String _formatTime(DateTime dt) {
    final h = dt.hour;
    final m = dt.minute.toString().padLeft(2, '0');
    final period = h >= 12 ? 'PM' : 'AM';
    final hour = h > 12 ? h - 12 : (h == 0 ? 12 : h);
    return "$hour:$m $period";
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 140,
      margin: const EdgeInsets.only(right: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E2E),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.06),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Time
          Text(
            _formatTime(entry.timestamp),
            style: TextStyle(
              fontSize: 10,
              color: Colors.white.withValues(alpha: 0.4),
            ),
          ),

          // Emoji
          Text(
            _emoji(entry.brandName),
            style: const TextStyle(fontSize: 26),
          ),

          // Product name
          Text(
            entry.brandName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),

          // Volume line — shown only when available
          if (entry.volumeLabel.isNotEmpty)
            Text(
              entry.volumeLabel,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: Colors.white.withValues(alpha: 0.55),
              ),
            )
          else
            const SizedBox.shrink(),

          // Sugar badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: Colors.tealAccent.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              "${entry.totalSugar.toStringAsFixed(0)}g",
              style: const TextStyle(
                fontSize: 11,
                color: Colors.tealAccent,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
