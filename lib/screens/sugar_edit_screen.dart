import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../controllers/sugar_edit_controller.dart';
import '../controllers/sugar_provider.dart';
import '../core/app_colors.dart';
import '../models/sugar_entry.dart';
import '../widgets/loading_overlay_widget.dart';
import '../widgets/sugar_edit_widgets.dart';
import 'main_screen.dart';

class SugarEditScreen extends StatefulWidget {
  final Uint8List ocrImage;
  final List<Uint8List> silentImages;
  final int initialSugar;
  final String initialProductName;
  final String userEmail;
  final String? suggestionName;
  final double confidence;

  const SugarEditScreen({
    super.key,
    required this.ocrImage,
    required this.silentImages,
    required this.initialSugar,
    required this.initialProductName,
    required this.userEmail,
    this.suggestionName,
    this.confidence = 0,
  });

  @override
  State<SugarEditScreen> createState() => _SugarEditScreenState();
}

class _SugarEditScreenState extends State<SugarEditScreen> {
  final SugarEditController _controller = SugarEditController();

  @override
  void initState() {
    super.initState();
    _controller.init(
      widget.initialProductName,
      widget.initialSugar,
      widget.ocrImage,
      widget.silentImages,
      confidence: widget.confidence,
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _controller,
      builder: (context, _) {
        return Scaffold(
          backgroundColor: AppColors.background,
          appBar: AppBar(
            backgroundColor: AppColors.background,
            elevation: 0,
            title: const Text(
              "Nutrition Input",
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            iconTheme: const IconThemeData(color: Colors.white70),
          ),
          body: Stack(
            children: [
              SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Photo preview
                    Center(
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.tealAccent.withValues(alpha: 0.1),
                              blurRadius: 20,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(20),
                          child: Image.memory(
                            widget.ocrImage,
                            width: 200,
                            height: 200,
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Category toggle
                    Center(
                      child: CategoryToggle(
                        selected: _controller.selectedCategory,
                        onChanged: _controller.setCategory,
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Form card
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                            color: AppColors.card,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: DynamicNutritionForm(
                        category: _controller.selectedCategory,
                        productCtrl: _controller.productController,
                        varianCtrl: _controller.varianController,
                        totalCtrl: _controller.totalController,
                        perSajianCtrl: _controller.perSajianController,
                        gulaSajianCtrl: _controller.gulaSajianController,
                        productHint: widget.suggestionName,
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Google AI search
                    GoogleAISearchButton(
                      productCtrl: _controller.productController,
                      varianCtrl: _controller.varianController,
                      totalCtrl: _controller.totalController,
                      parentContext: context,
                    ),
                    const SizedBox(height: 16),

                    // Sugar preview card
                    ListenableBuilder(
                      listenable: Listenable.merge([
                        _controller.totalController,
                        _controller.perSajianController,
                        _controller.gulaSajianController,
                      ]),
                      builder: (context, _) {
                        return Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: AppColors.card,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: Colors.tealAccent.withValues(alpha: 0.3),
                            ),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.water_drop_outlined,
                                  color: Colors.tealAccent, size: 20),
                              const SizedBox(width: 10),
                              Text(
                                "Total Sugar: ",
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.white.withValues(alpha: 0.6),
                                ),
                              ),
                              Text(
                                "${_controller.calculatedTotalSugar}g",
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.tealAccent,
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 28),

                    // Confirm button
                    ListenableBuilder(
                      listenable: _controller.gulaSajianController,
                      builder: (context, _) {
                        final bool canSubmit = _controller.canSubmit;
                        return SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: canSubmit
                                  ? Colors.tealAccent
                                  : Colors.white12,
                              foregroundColor: canSubmit
                                  ? AppColors.background
                                  : Colors.white38,
                              padding:
                                  const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                              elevation: canSubmit ? 4 : 0,
                            ),
                            icon: const Icon(Icons.cloud_upload_outlined),
                            label: const Text(
                              "Confirm & Upload",
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 15,
                              ),
                            ),
                            onPressed: canSubmit
                                ? () async {
                                    final provider =
                                        context.read<SugarProvider>();
                                    final bool success =
                                        await _controller.uploadData(
                                      widget.userEmail,
                                      widget.ocrImage,
                                      onSuccess: (totalSugar, volumeTotal, imageUrl) {
                                        final bool isBeverage = _controller.selectedCategory == ProductCategory.minuman;
                                        final String unit = isBeverage ? 'ml' : 'g';
                                        final String label = volumeTotal > 0
                                            ? '${volumeTotal.toStringAsFixed(0)} $unit'
                                            : '';
                                        provider.addEntry(SugarEntry(
                                          id: DateTime.now()
                                              .millisecondsSinceEpoch
                                              .toString(),
                                          brandName: _controller
                                              .productController.text,
                                          variantName:
                                              _controller.varianController.text,
                                          rawSugarGrams: totalSugar,
                                          volumeTotal: volumeTotal,
                                          volumeLabel: label,
                                          imageBytes: widget.ocrImage,
                                          imageUrl: imageUrl,
                                          timestamp: DateTime.now(),
                                        ));
                                      },
                                    );
                                    if (success && mounted) {
                                      Navigator.of(context)
                                          .popUntil((r) => r.isFirst);
                                      MainScreen.switchToHome();
                                    }
                                  }
                                : null,
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),

              // Upload overlay
              if (_controller.isSaving)
                const LoadingOverlay(
                  message: "Uploading data...",
                  subMessage: "Please wait, don't close the app",
                ),
            ],
          ),
        );
      },
    );
  }
}
