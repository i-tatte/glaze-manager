import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class MixingCalculatorScreen extends StatefulWidget {
  final Map<String, double> recipe; // Material ID -> Percentage
  final Map<String, String> materialNames; // Material ID -> Name

  const MixingCalculatorScreen({
    super.key,
    required this.recipe,
    required this.materialNames,
  });

  @override
  State<MixingCalculatorScreen> createState() => _MixingCalculatorScreenState();
}

class _MixingCalculatorScreenState extends State<MixingCalculatorScreen> {
  // Current total weight in grams
  double _totalWeight = 1000.0;

  // Controllers for each material input to manage text state
  late Map<String, TextEditingController> _controllers;
  late TextEditingController _totalController;

  @override
  void initState() {
    super.initState();
    _totalController = TextEditingController(
      text: _totalWeight.toStringAsFixed(1),
    );
    _controllers = {};

    // Initialize controllers for each material
    for (var entry in widget.recipe.entries) {
      final weight = (_totalWeight * entry.value) / 100.0;
      _controllers[entry.key] = TextEditingController(
        text: weight.toStringAsFixed(1),
      );
    }
  }

  @override
  void dispose() {
    _totalController.dispose();
    for (var controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  void _updateFromTotal(String value) {
    final newTotal = double.tryParse(value);
    if (newTotal == null) return;

    setState(() {
      _totalWeight = newTotal;
      // Update all material inputs
      for (var entry in widget.recipe.entries) {
        final weight = (_totalWeight * entry.value) / 100.0;
        _controllers[entry.key]?.text = weight.toStringAsFixed(1);
      }
    });
  }

  void _updateFromMaterial(String materialId, String value) {
    final newWeight = double.tryParse(value);
    if (newWeight == null) return;

    final percentage = widget.recipe[materialId];
    if (percentage == null || percentage == 0) return;

    // Calculate new total based on this material's weight and percentage
    // weight = (total * percentage) / 100  =>  total = (weight * 100) / percentage
    final newTotal = (newWeight * 100.0) / percentage;

    setState(() {
      _totalWeight = newTotal;
      _totalController.text = _totalWeight.toStringAsFixed(1);

      // Update OTHER material inputs
      for (var entry in widget.recipe.entries) {
        if (entry.key == materialId) continue; // Skip the one being edited

        final weight = (_totalWeight * entry.value) / 100.0;
        _controllers[entry.key]?.text = weight.toStringAsFixed(1);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('調合計算')),
      body: Column(
        children: [
          // Total Weight Input Section
          Container(
            padding: const EdgeInsets.all(16.0),
            color: Theme.of(context).colorScheme.surfaceContainer,
            child: Row(
              children: [
                const Text(
                  '総重量:',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: TextField(
                    controller: _totalController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
                    ],
                    decoration: const InputDecoration(
                      suffixText: 'g',
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                    ),
                    onChanged: _updateFromTotal,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          // Materials List
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16.0),
              itemCount: widget.recipe.length,
              itemBuilder: (context, index) {
                final entry = widget.recipe.entries.elementAt(index);
                final materialId = entry.key;
                final percentage = entry.value;
                final name = widget.materialNames[materialId] ?? '不明な材料';

                return Padding(
                  padding: const EdgeInsets.only(bottom: 16.0),
                  child: Row(
                    children: [
                      // Material Name & Percentage
                      Expanded(
                        flex: 3,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(name, style: const TextStyle(fontSize: 16)),
                            Text(
                              '${percentage.toStringAsFixed(1)}%',
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.secondary,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),
                      // Weight Input
                      Expanded(
                        flex: 2,
                        child: TextField(
                          controller: _controllers[materialId],
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(
                              RegExp(r'^\d*\.?\d*'),
                            ),
                          ],
                          decoration: const InputDecoration(
                            suffixText: 'g',
                            border: OutlineInputBorder(),
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                          ),
                          onChanged: (value) =>
                              _updateFromMaterial(materialId, value),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
