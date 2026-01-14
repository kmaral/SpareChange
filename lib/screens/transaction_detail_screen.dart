import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/app_provider.dart';
import '../models/transaction.dart';
import '../models/denomination.dart';
import '../models/user.dart';

class TransactionDetailScreen extends StatelessWidget {
  final CurrencyTransaction transaction;

  const TransactionDetailScreen({super.key, required this.transaction});

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('MMM dd, yyyy hh:mm a');

    return Scaffold(
      appBar: AppBar(
        title: const Text('Transaction Details'),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: () => _showEditDialog(context),
          ),
          IconButton(
            icon: const Icon(Icons.delete, color: Colors.red),
            onPressed: () => _showDeleteDialog(context),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Transaction type card
          Card(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 40,
                    backgroundColor:
                        transaction.transactionType == TransactionType.added
                        ? Colors.green
                        : Colors.red,
                    child: Icon(
                      transaction.transactionType == TransactionType.added
                          ? Icons.add
                          : Icons.remove,
                      size: 48,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    '${transaction.transactionType == TransactionType.added ? '+' : '-'}'
                    '${transaction.displayTotalAmount}',
                    style: TextStyle(
                      fontSize: 36,
                      fontWeight: FontWeight.bold,
                      color:
                          transaction.transactionType == TransactionType.added
                          ? Colors.green
                          : Colors.red,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    transaction.transactionType == TransactionType.added
                        ? 'Money Added'
                        : 'Money Taken',
                    style: const TextStyle(fontSize: 18, color: Colors.grey),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Details card
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _DetailRow(
                    icon: Icons.person,
                    label: 'User',
                    value: transaction.userName,
                  ),
                  const Divider(),
                  _DetailRow(
                    icon: Icons.monetization_on,
                    label: 'Denomination',
                    value: transaction.displayDenomination,
                  ),
                  const Divider(),
                  _DetailRow(
                    icon: Icons.format_list_numbered,
                    label: 'Quantity',
                    value: '${transaction.quantity}',
                  ),
                  const Divider(),
                  _DetailRow(
                    icon: Icons.calculate,
                    label: 'Total Amount',
                    value: transaction.displayTotalAmount,
                  ),
                  const Divider(),
                  _DetailRow(
                    icon: Icons.calendar_today,
                    label: 'Date & Time',
                    value: dateFormat.format(transaction.timestamp),
                  ),
                  if (transaction.reason != null &&
                      transaction.reason!.isNotEmpty) ...[
                    const Divider(),
                    _DetailRow(
                      icon: Icons.notes,
                      label: 'Reason',
                      value: transaction.reason!,
                    ),
                  ],
                  if (transaction.lastModified != transaction.timestamp) ...[
                    const Divider(),
                    _DetailRow(
                      icon: Icons.edit,
                      label: 'Last Modified',
                      value: dateFormat.format(transaction.lastModified),
                    ),
                  ],
                  const Divider(),
                  _DetailRow(
                    icon: Icons.sync,
                    label: 'Sync Status',
                    value: transaction.syncStatus
                        .toString()
                        .split('.')
                        .last
                        .toUpperCase(),
                    valueColor: transaction.syncStatus == SyncStatus.synced
                        ? Colors.green
                        : transaction.syncStatus == SyncStatus.failed
                        ? Colors.red
                        : Colors.orange,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showEditDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => _EditTransactionDialog(transaction: transaction),
    );
  }

  void _showDeleteDialog(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Transaction'),
        content: const Text(
          'Are you sure you want to delete this transaction? '
          'The inventory will be recalculated automatically.',
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
      final provider = Provider.of<AppProvider>(context, listen: false);
      await provider.deleteTransaction(transaction);

      if (context.mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Transaction deleted successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    }
  }
}

class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color? valueColor;

  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Colors.grey),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: valueColor,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _EditTransactionDialog extends StatefulWidget {
  final CurrencyTransaction transaction;

  const _EditTransactionDialog({required this.transaction});

  @override
  State<_EditTransactionDialog> createState() => _EditTransactionDialogState();
}

class _EditTransactionDialogState extends State<_EditTransactionDialog> {
  final _formKey = GlobalKey<FormState>();
  final _quantityController = TextEditingController();
  final _reasonController = TextEditingController();

  Denomination? _selectedDenomination;
  User? _selectedUser;
  late TransactionType _selectedType;

  @override
  void initState() {
    super.initState();
    _quantityController.text = widget.transaction.quantity.toString();
    _reasonController.text = widget.transaction.reason ?? '';
    _selectedType = widget.transaction.transactionType;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = Provider.of<AppProvider>(context, listen: false);
      setState(() {
        _selectedUser = provider.users.firstWhere(
          (u) => u.id == widget.transaction.userId,
          orElse: () => provider.users.first,
        );
        _selectedDenomination = provider.activeDenominations.firstWhere(
          (d) => d.value == widget.transaction.denominationValue,
          orElse: () => provider.activeDenominations.first,
        );
      });
    });
  }

  @override
  void dispose() {
    _quantityController.dispose();
    _reasonController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AppProvider>(
      builder: (context, provider, child) {
        return AlertDialog(
          title: const Text('Edit Transaction'),
          content: SingleChildScrollView(
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // User selection
                  const Text(
                    'User',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<User>(
                    initialValue: _selectedUser,
                    items: provider.users.map((user) {
                      return DropdownMenuItem(
                        value: user,
                        child: Text(user.name),
                      );
                    }).toList(),
                    onChanged: (user) {
                      setState(() {
                        _selectedUser = user;
                      });
                    },
                  ),
                  const SizedBox(height: 16),

                  // Transaction type
                  const Text(
                    'Type',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  SegmentedButton<TransactionType>(
                    segments: const [
                      ButtonSegment(
                        value: TransactionType.added,
                        label: Text('Added'),
                        icon: Icon(Icons.add),
                      ),
                      ButtonSegment(
                        value: TransactionType.taken,
                        label: Text('Taken'),
                        icon: Icon(Icons.remove),
                      ),
                    ],
                    selected: {_selectedType},
                    onSelectionChanged: (Set<TransactionType> newSelection) {
                      setState(() {
                        _selectedType = newSelection.first;
                      });
                    },
                  ),
                  const SizedBox(height: 16),

                  // Denomination selection
                  const Text(
                    'Denomination',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<Denomination>(
                    initialValue: _selectedDenomination,
                    items: provider.activeDenominations.map((denomination) {
                      return DropdownMenuItem(
                        value: denomination,
                        child: Text(denomination.displayValue),
                      );
                    }).toList(),
                    onChanged: (denomination) {
                      setState(() {
                        _selectedDenomination = denomination;
                      });
                    },
                  ),
                  const SizedBox(height: 16),

                  // Quantity
                  TextFormField(
                    controller: _quantityController,
                    decoration: const InputDecoration(
                      labelText: 'Quantity',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Please enter quantity';
                      }
                      final quantity = int.tryParse(value);
                      if (quantity == null || quantity <= 0) {
                        return 'Please enter a valid positive number';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  // Reason
                  TextFormField(
                    controller: _reasonController,
                    decoration: const InputDecoration(
                      labelText: 'Reason (Optional)',
                      border: OutlineInputBorder(),
                    ),
                    maxLines: 3,
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (_formKey.currentState!.validate() &&
                    _selectedUser != null &&
                    _selectedDenomination != null) {
                  await provider.updateTransaction(
                    transaction: widget.transaction,
                    user: _selectedUser!,
                    denomination: _selectedDenomination!,
                    quantity: int.parse(_quantityController.text),
                    type: _selectedType,
                    reason: _reasonController.text.trim().isEmpty
                        ? null
                        : _reasonController.text.trim(),
                  );

                  if (context.mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Transaction updated successfully'),
                        backgroundColor: Colors.green,
                      ),
                    );
                  }
                }
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }
}
