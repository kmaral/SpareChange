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
                  const SizedBox(height: 8),
                  const Text(
                    'INR denominations are added automatically',
                    style: TextStyle(fontSize: 14, color: Colors.grey),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    onPressed: () =>
                        _showAddDenominationDialog(context, provider),
                    icon: const Icon(Icons.add),
                    label: const Text('Add Custom Denomination'),
                  ),
                ],
              ),
            );
          }

          // Separate auto-created and manual denominations
          final autoCreated =
              denominations.where((d) => d.isAutoCreated).toList()
                ..sort((a, b) => a.value.compareTo(b.value));
          final manual = denominations.where((d) => !d.isAutoCreated).toList()
            ..sort((a, b) => a.value.compareTo(b.value));

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (autoCreated.isNotEmpty) ...[
                Row(
                  children: [
                    const Text(
                      'INR DENOMINATIONS (Auto-created)',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey,
                      ),
                    ),
                    const Spacer(),
                    Icon(Icons.info_outline, size: 16, color: Colors.grey[600]),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'These are automatically added for INR currency',
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
                const SizedBox(height: 8),
                ...autoCreated.map(
                  (denomination) => _DenominationListItem(
                    denomination: denomination,
                    provider: provider,
                    isAutoCreated: true,
                  ),
                ),
                const SizedBox(height: 24),
              ],
              if (manual.isNotEmpty) ...[
                const Text(
                  'CUSTOM DENOMINATIONS',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey,
                  ),
                ),
                const SizedBox(height: 8),
                ...manual.map(
                  (denomination) => _DenominationListItem(
                    denomination: denomination,
                    provider: provider,
                    isAutoCreated: false,
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
          label: const Text('Add Custom'),
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
  final bool isAutoCreated;

  const _DenominationListItem({
    required this.denomination,
    required this.provider,
    this.isAutoCreated = false,
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
          denomination.displayValueWithCurrency(
            provider.currencySymbol,
            formatter: provider.formatNumber,
          ),
          style: TextStyle(
            fontWeight: FontWeight.bold,
            decoration: denomination.isActive
                ? null
                : TextDecoration.lineThrough,
            color: denomination.isActive ? null : Colors.grey,
          ),
        ),
        subtitle: Row(
          children: [
            Text(
              denomination.isActive ? 'Active' : 'Inactive',
              style: TextStyle(
                color: denomination.isActive ? Colors.green : Colors.grey,
              ),
            ),
            if (isAutoCreated) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.blue.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Auto',
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.blue.shade700,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!isAutoCreated) ...[
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
            ] else ...[
              // Auto-created denominations can only be toggled
              Switch(
                value: denomination.isActive,
                onChanged: (value) {
                  provider.toggleDenominationActive(denomination);
                },
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _showDeleteDialog(
    BuildContext context,
    Denomination denomination,
  ) async {
    final provider = Provider.of<AppProvider>(context, listen: false);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Denomination'),
        content: Text(
          'Are you sure you want to delete ${denomination.displayValueWithCurrency(provider.currencySymbol, formatter: provider.formatNumber)}? '
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
    final currencySymbol = widget.provider.currencySymbol;

    return AlertDialog(
      title: const Text('Add Denomination'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: _valueController,
              decoration: InputDecoration(
                labelText: 'Value ($currencySymbol)',
                hintText: 'e.g., 1, 2, 5, 10, 20',
                border: const OutlineInputBorder(),
                prefixText: '$currencySymbol ',
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
                // Check for duplicate value with same type
                final exists = widget.provider.denominations.any(
                  (d) => d.value == numValue && d.type == _selectedType,
                );
                if (exists) {
                  final typeName = _selectedType == DenominationType.coin
                      ? 'coin'
                      : 'note';
                  return '$typeName with value ${widget.provider.currencySymbol}$numValue already exists';
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
                  // Revalidate the form when type changes
                  _formKey.currentState?.validate();
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
