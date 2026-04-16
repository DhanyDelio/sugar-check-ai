import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../controllers/sugar_provider.dart';
import '../models/sugar_entry.dart';

class SugarHistoryWidget extends StatelessWidget {
  const SugarHistoryWidget({super.key});

  @override
  Widget build(BuildContext context) {
    final entries = context.watch<SugarProvider>().entries;

    if (entries.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 32),
          child: Text(
            "No scan history yet",
            style: TextStyle(color: Colors.white.withOpacity(0.35)),
          ),
        ),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: entries.length,
      itemBuilder: (context, index) => _EntryCard(entry: entries[index]),
    );
  }
}

class _EntryCard extends StatelessWidget {
  final SugarEntry entry;

  const _EntryCard({required this.entry});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      color: Colors.white.withOpacity(0.06),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            // Thumbnail
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: entry.imageBytes != null
                  ? Image.memory(
                      entry.imageBytes!,
                      width: 60,
                      height: 60,
                      fit: BoxFit.cover,
                      cacheWidth: 120,
                    )
                  : Container(
                      width: 60,
                      height: 60,
                      color: Colors.white10,
                      child: const Icon(Icons.image_not_supported_outlined,
                          color: Colors.white24),
                    ),
            ),
            const SizedBox(width: 14),

            // Product info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    entry.brandName,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (entry.variantName.isNotEmpty)
                    Text(
                      entry.variantName,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.white.withOpacity(0.5),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  const SizedBox(height: 6),
                  Text(
                    "${entry.totalSugar.toStringAsFixed(1)}g sugar",
                    style: const TextStyle(
                      fontSize: 13,
                      color: Colors.greenAccent,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),

            // Timestamp
            Text(
              _formatTime(entry.timestamp),
              style: TextStyle(
                fontSize: 11,
                color: Colors.white.withOpacity(0.3),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatTime(DateTime dt) {
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return "$h:$m";
  }
}
