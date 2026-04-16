import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../controllers/sugar_edit_controller.dart';
import '../utils/string_utils.dart';

// ── Category Toggle ───────────────────────────────────────────────────────────

class CategoryToggle extends StatelessWidget {
  final ProductCategory selected;
  final ValueChanged<ProductCategory> onChanged;

  const CategoryToggle({super.key, required this.selected, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return SegmentedButton<ProductCategory>(
      segments: const [
        ButtonSegment(
          value: ProductCategory.minuman,
          label: Text("🥤 Beverage"),
          icon: Icon(Icons.local_drink),
        ),
        ButtonSegment(
          value: ProductCategory.makanan,
          label: Text("🍱 Food"),
          icon: Icon(Icons.fastfood),
        ),
      ],
      selected: {selected},
      onSelectionChanged: (val) => onChanged(val.first),
    );
  }
}

// ── Dynamic Nutrition Form ────────────────────────────────────────────────────

/// Renders different fields based on [category]:
/// - Beverage: volume total (ml), volume per serving (ml), sugar per serving (g)
/// - Food: total weight (g), serving weight (g), sugar per serving (g)
class DynamicNutritionForm extends StatelessWidget {
  final ProductCategory category;
  final TextEditingController productCtrl;
  final TextEditingController varianCtrl;
  final TextEditingController totalCtrl;
  final TextEditingController perSajianCtrl;
  final TextEditingController gulaSajianCtrl;
  final String? productHint;

  const DynamicNutritionForm({
    super.key,
    required this.category,
    required this.productCtrl,
    required this.varianCtrl,
    required this.totalCtrl,
    required this.perSajianCtrl,
    required this.gulaSajianCtrl,
    this.productHint,
  });

  @override
  Widget build(BuildContext context) {
    final bool isBeverage = category == ProductCategory.minuman;
    final String unit = isBeverage ? "ml" : "g";
    final String keyTotal = isBeverage ? "volume_total" : "total_weight";
    final String keySajian = isBeverage ? "volume_per_serving" : "serving_weight";

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Product name
        TextField(
          controller: productCtrl,
          decoration: InputDecoration(
            labelText: "Product Name",
            hintText: productHint != null
                ? "Maybe: $productHint"
                : "e.g. Coca-Cola, Indomie, Oreo...",
            border: const OutlineInputBorder(),
            prefixIcon: const Icon(Icons.label_outline),
            suffixIcon: productHint != null
                ? IconButton(
                    tooltip: "Use suggestion: $productHint",
                    icon: const Icon(Icons.check_circle_outline, color: Colors.greenAccent),
                    onPressed: () => productCtrl.text = productHint!,
                  )
                : null,
          ),
        ),
        const SizedBox(height: 14),

        // Variant
        TextField(
          controller: varianCtrl,
          decoration: const InputDecoration(
            labelText: "Variant",
            hintText: "e.g. Original, Chocolate, Less Sugar...",
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.tune_outlined),
          ),
        ),
        const SizedBox(height: 14),

        // Total volume / total weight
        TextField(
          controller: totalCtrl,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            labelText: formatLabel(keyTotal),
            hintText: "Check the front of the packaging",
            border: const OutlineInputBorder(),
            suffixText: unit,
            prefixIcon: const Icon(Icons.straighten),
          ),
        ),
        const SizedBox(height: 14),

        // Volume per serving / serving weight
        TextField(
          controller: perSajianCtrl,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            labelText: formatLabel(keySajian),
            hintText: "Check the nutrition table on the back",
            border: const OutlineInputBorder(),
            suffixText: unit,
            prefixIcon: const Icon(Icons.pie_chart_outline),
          ),
        ),
        const SizedBox(height: 14),

        // Sugar per serving
        TextField(
          controller: gulaSajianCtrl,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: "Sugar Per Serving",
            hintText: "Found in the nutrition table",
            border: OutlineInputBorder(),
            suffixText: "g",
            prefixIcon: Icon(Icons.water_drop_outlined),
          ),
        ),
      ],
    );
  }
}

// ── Image Selection Grid ──────────────────────────────────────────────────────

class ImageSelectionGrid extends StatelessWidget {
  final List<Uint8List> images;
  final List<bool> selection;
  final Function(int) onTap;

  const ImageSelectionGrid({
    super.key,
    required this.images,
    required this.selection,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
      ),
      itemCount: images.length,
      itemBuilder: (context, index) {
        return GestureDetector(
          onTap: () => onTap(index),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: selection[index] ? Colors.green : Colors.grey,
                width: 3,
              ),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(5),
              child: Image.memory(images[index], fit: BoxFit.cover),
            ),
          ),
        );
      },
    );
  }
}

// ── Google AI Search Button ───────────────────────────────────────────────────

class GoogleAISearchButton extends StatelessWidget {
  final TextEditingController productCtrl;
  final TextEditingController varianCtrl;
  final BuildContext parentContext;

  const GoogleAISearchButton({
    super.key,
    required this.productCtrl,
    required this.varianCtrl,
    required this.parentContext,
  });

  Future<void> _search() async {
    final String product = productCtrl.text.trim();
    final String variant = varianCtrl.text.trim();

    if (product.isEmpty) {
      ScaffoldMessenger.of(parentContext).showSnackBar(
        const SnackBar(
          content: Text("Please enter a product name first"),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    if (variant.isEmpty) {
      ScaffoldMessenger.of(parentContext).showSnackBar(
        const SnackBar(
          content: Text("Please enter a variant first"),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final String query = '$product $variant sugar content per serving';
    final Uri url = Uri.parse(
      'https://www.google.com/search?q=${Uri.encodeComponent(query)}',
    );

    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      debugPrint("❌ Could not open browser: $url");
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([productCtrl, varianCtrl]),
      builder: (context, _) {
        final bool hasInput = productCtrl.text.trim().isNotEmpty &&
            varianCtrl.text.trim().isNotEmpty;
        return Opacity(
          opacity: hasInput ? 1.0 : 0.5,
          child: TextButton.icon(
            style: TextButton.styleFrom(
              foregroundColor: Colors.greenAccent,
              padding: EdgeInsets.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              alignment: Alignment.centerLeft,
            ),
            icon: const Icon(Icons.auto_awesome, size: 14),
            label: const Text(
              "Search sugar details with Google AI",
              style: TextStyle(fontSize: 12),
            ),
            onPressed: _search,
          ),
        );
      },
    );
  }
}
