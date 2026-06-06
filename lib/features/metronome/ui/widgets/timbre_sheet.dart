import 'package:flutter/material.dart';

import '../../../../core/audio/timbre.dart';

/// Bottom-sheet page for choosing the click timbre (sound voice).
/// Calls [onSelect] and pops on tap.
class TimbreSheet extends StatelessWidget {
  final Timbre selected;
  final ValueChanged<Timbre> onSelect;

  const TimbreSheet({
    super.key,
    required this.selected,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('音色', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            ...kTimbres.map((t) {
              final isSelected = t.id == selected.id;
              return ListTile(
                leading: Icon(
                  Icons.graphic_eq,
                  color: isSelected ? scheme.primary : null,
                ),
                title: Text(t.name),
                trailing: isSelected
                    ? Icon(Icons.check, color: scheme.primary)
                    : null,
                onTap: () {
                  onSelect(t);
                  Navigator.of(context).pop();
                },
              );
            }),
          ],
        ),
      ),
    );
  }
}
