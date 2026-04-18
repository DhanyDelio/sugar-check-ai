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
              child: _buildThumbnail(entry),
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

  Widget _buildThumbnail(SugarEntry entry) {
    const double size = 60;

    // Prefer in-memory bytes (fresh scan) — no network call needed
    if (entry.imageBytes != null) {
      return Image.memory(
        entry.imageBytes!,
        width: size,
        height: size,
        fit: BoxFit.cover,
        cacheWidth: 120,
      );
    }

    // Fall back to Cloudinary URL (after app restart)
    if (entry.imageUrl != null) {
      return Image.network(
        entry.imageUrl!,
        width: size,
        height: size,
        fit: BoxFit.cover,
        loadingBuilder: (_, child, progress) => progress == null
            ? child
            : Container(
                width: size,
                height: size,
                color: Colors.white10,
                child: const Center(
                  child: SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white24,
                    ),
                  ),
                ),
              ),
        errorBuilder: (_, __, ___) => _placeholder(size),
      );
    }

    return _placeholder(size);
  }

  Widget _placeholder(double size) => Container(
        width: size,
        height: size,
        color: Colors.white10,
        child: const Icon(Icons.image_not_supported_outlined,
            color: Colors.white24),
      );
