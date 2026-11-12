import 'package:flutter/material.dart';
import '../../../models/detection_model.dart';

/// Selection only. The owning page invalidates processed photos on change.
class DetectionModelPicker extends StatelessWidget {
  const DetectionModelPicker(
      {super.key,
      required this.value,
      required this.enabled,
      required this.onChanged});
  final DetectionModel value;
  final bool enabled;
  final ValueChanged<DetectionModel> onChanged;

  @override
  Widget build(BuildContext context) => DropdownButtonFormField<DetectionModel>(
        key: ValueKey(value),
        initialValue: value,
        isExpanded: true,
        decoration: const InputDecoration(
            labelText: 'Detection model',
            prefixIcon: Icon(Icons.memory_outlined),
            border: OutlineInputBorder()),
        items: [
          for (final model in DetectionModel.values)
            DropdownMenuItem(value: model, child: Text(model.label))
        ],
        onChanged: enabled
            ? (model) {
                if (model != null) onChanged(model);
              }
            : null,
      );
}
