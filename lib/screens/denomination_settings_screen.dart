import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import '../models/denomination.dart';

class DenominationSettingsScreen extends StatelessWidget {
  const DenominationSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Manage Denominations')),
      body: Consumer<AppProvider>(
        builder: (context, provider, child) {
          final denominations = provider.denominations;

          if (denominations.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.monetization_on,
                    size: 64,
                    color: Colors.grey,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'No denominations yet',
                    style: TextStyle(fontSize: 18, color: Colors.grey),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    onPressed: () =>
                        _showAddDenominationDialog(context, provider),
                    icon: const Icon(Icons.add),
                    label: const Text('Add First Denomination'),
                  ),
                ],
              ),
            );
          }

          // Separate coins and notes
          final coins =
              denominations
                  .where((d) => d.type == DenominationType.coin)
                  .toList()
                ..sort((a, b) => a.value.compareTo(b.value));

          final notes =
              denominations
                  .where((d) => d.type == DenominationType.note)
                  .toList()
                ..sort((a, b) => a.value.compareTo(b.value));

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (coins.isNotEmpty) ...[
                const Text(
                  'COINS',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey,
                  ),
                ),
                const SizedBox(height: 8),
                ...coins.map(
                  (denomination) => _DenominationListItem(
                    denomination: denomination,
                    provider: provider,
                  ),
                ),
                const SizedBox(height: 24),
              ],
              if (notes.isNotEmpty) ...[
                const Text(
                  'NOTES',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey,
                  ),
                ),
                const SizedBox(height: 8),
                ...notes.map(
                  (denomination) => _DenominationListItem(
                    denomination: denomination,
                    provider: provider,
                  ),
                ),
              ],
            ],
          );
        },
      ),
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: FloatingActionButton.extended(
          onPressed: () => _showAddDenominationDialog(
            context,
            Provider.of<AppProvider>(context, listen: false),
          ),
          icon: const Icon(Icons.add),
          label: const Text('Add Denomination'),
          elevation: 4,
        ),
      ),
    );
  }

  void _showAddDenominationDialog(BuildContext context, AppProvider provider) {
    showDialog(
      context: context,
      builder: (context) => _AddDenominationDialog(provider: provider),
    );
  }
}

class _DenominationListItem extends StatelessWidget {
  final Denomination denomination;
  final AppProvider provider;

  const _DenominationListItem({
    required this.denomination,
    required this.provider,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: denomination.type == DenominationType.coin
              ? Colors.amber
              : Colors.green,
          child: Text(
            denomination.type == DenominationType.coin ? 'C' : 'N',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        title: Text(
          denomination.displayValue,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            decoration: denomination.isActive
                ? null
                : TextDecoration.lineThrough,
            color: denomination.isActive ? null : Colors.grey,
          ),
        ),
        subtitle: Text(
          denomination.isActive ? 'Active' : 'Inactive',
          style: TextStyle(
            color: denomination.isActive ? Colors.green : Colors.grey,
          ),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Switch(
              value: denomination.isActive,
              onChanged: (value) {
                provider.toggleDenominationActive(denomination);
              },
            ),
            IconButton(
              icon: const Icon(Icons.delete, color: Colors.red),
              onPressed: () => _showDeleteDialog(context, denomination),
            ),
          ],
        ),
      ),
    );
  }

  void _showDeleteDialog(
    BuildContext context,
    Denomination denomination,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Denomination'),
        content: Text(
          'Are you sure you want to delete ${denomination.displayValue}? '
          'This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      final success = await provider.deleteDenomination(denomination.id);

      if (!success && context.mounted) {
        // Show warning dialog about existing transactions
        await showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Cannot Delete'),
            content: Text(
              'This denomination has existing transactions. '
              'You can deactivate it instead by turning off the switch.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('OK'),
              ),
              ElevatedButton(
                onPressed: () {
                  provider.toggleDenominationActive(denomination);
                  Navigator.pop(context);
                },
                child: const Text('Deactivate'),
              ),
            ],
          ),
        );
      }
    }
  }
}

class _AddDenominationDialog extends StatefulWidget {
  final AppProvider provider;

  const _AddDenominationDialog({required this.provider});

  @override
  State<_AddDenominationDialog> createState() => _AddDenominationDialogState();
}

class _AddDenominationDialogState extends State<_AddDenominationDialog> {
  final _formKey = GlobalKey<FormState>();
  final _valueController = TextEditingController();
  DenominationType _selectedType = DenominationType.coin;

  @override
  void dispose() {
    _valueController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add Denomination'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: _valueController,
              decoration: const InputDecoration(
                labelText: 'Value (₹)',
                hintText: 'e.g., 1, 2, 5, 10, 20',
                border: OutlineInputBorder(),
                prefixText: '₹ ',
              ),
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
              ],
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please enter a value';
                }
                final numValue = double.tryParse(value);
                if (numValue == null || numValue <= 0) {
                  return 'Please enter a valid positive number';
                }
                return null;
              },
              autofocus: true,
            ),
            const SizedBox(height: 16),
            SegmentedButton<DenominationType>(
              segments: const [
                ButtonSegment(
                  value: DenominationType.coin,
                  label: Text('Coin'),
                  icon: Icon(Icons.monetization_on),
                ),
                ButtonSegment(
                  value: DenominationType.note,
                  label: Text('Note'),
                  icon: Icon(Icons.note),
                ),
              ],
              selected: {_selectedType},
              onSelectionChanged: (Set<DenominationType> newSelection) {
                setState(() {
                  _selectedType = newSelection.first;
                });
              },
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () async {
            if (_formKey.currentState!.validate()) {
              final value = double.parse(_valueController.text.trim());
              await widget.provider.addDenomination(value, _selectedType);

              if (context.mounted) {
                Navigator.pop(context);
              }
            }
          },
          child: const Text('Add'),
        ),
      ],
    );
  }
}
