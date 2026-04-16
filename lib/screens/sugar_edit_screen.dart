import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../controllers/sugar_edit_controller.dart';
import '../controllers/sugar_provider.dart';
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
          appBar: AppBar(title: const Text("Nutrition Input")),
          body: Stack(
            children: [
              SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Captured photo preview
                    Center(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: Image.memory(
                          widget.ocrImage,
                          width: 220,
                          height: 220,
                          fit: BoxFit.cover,
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

                    // Dynamic nutrition form
                    DynamicNutritionForm(
                      category: _controller.selectedCategory,
                      productCtrl: _controller.productController,
                      varianCtrl: _controller.varianController,
                      totalCtrl: _controller.totalController,
                      perSajianCtrl: _controller.perSajianController,
                      gulaSajianCtrl: _controller.gulaSajianController,
                      productHint: widget.suggestionName,
                    ),
                    const SizedBox(height: 12),

                    // Google AI search shortcut
                    SizedBox(
                      width: double.infinity,
                      child: GoogleAISearchButton(
                        productCtrl: _controller.productController,
                        varianCtrl: _controller.varianController,
                        parentContext: context,
                      ),
                    ),
                    const SizedBox(height: 15),

                    // Calculated sugar preview
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.green.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.green.shade700),
                      ),
                      child: ListenableBuilder(
                        listenable: Listenable.merge([
                          _controller.totalController,
                          _controller.perSajianController,
                          _controller.gulaSajianController,
                        ]),
                        builder: (context, _) {
                          return Text(
                            "Total Sugar: ${_controller.calculatedTotalSugar}g",
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.greenAccent,
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 30),

                    // Confirm & upload button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        icon: const Icon(Icons.cloud_upload_outlined),
                        label: const Text("Confirm"),
                        onPressed: () async {
                          final provider = context.read<SugarProvider>();
                          final bool success = await _controller.uploadData(
                            widget.userEmail,
                            widget.ocrImage,
                            onSuccess: (totalSugar) {
                              provider.addEntry(SugarEntry(
                                id: DateTime.now().millisecondsSinceEpoch.toString(),
                                brandName: _controller.productController.text,
                                variantName: _controller.varianController.text,
                                totalSugar: totalSugar,
                                imageBytes: widget.ocrImage,
                                timestamp: DateTime.now(),
                              ));
                            },
                          );
                          if (success && mounted) {
                            Navigator.of(context).popUntil((r) => r.isFirst);
                            MainScreen.switchToHome();
                          }
                        },
                      ),
                    ),
                  ],
                ),
              ),

              // Upload loading overlay
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
