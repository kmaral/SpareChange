import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import '../models/transaction.dart';
import '../models/denomination.dart';
import '../models/user.dart';

class AddTransactionScreen extends StatefulWidget {
  final TransactionType transactionType;

  const AddTransactionScreen({super.key, required this.transactionType});

  @override
  State<AddTransactionScreen> createState() => _AddTransactionScreenState();
}

class _AddTransactionScreenState extends State<AddTransactionScreen> {
  final _formKey = GlobalKey<FormState>();
  final _quantityController = TextEditingController();
  final _reasonController = TextEditingController();

  Denomination? _selectedDenomination;
  User? _selectedUser;
  DateTime _selectedDateTime = DateTime.now();

  @override
  void initState() {
    super.initState();
    // Pre-select the current user
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = Provider.of<AppProvider>(context, listen: false);
      setState(() {
        _selectedUser = provider.selectedUser;
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
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.transactionType == TransactionType.added
              ? 'Add Money'
              : 'Take Money',
        ),
      ),
      body: Consumer<AppProvider>(
        builder: (context, provider, child) {
          final activeDenominations = provider.activeDenominations;

          if (activeDenominations.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.warning, size: 64, color: Colors.orange),
                  const SizedBox(height: 16),
                  const Text(
                    'No active denominations available',
                    style: TextStyle(fontSize: 18),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Please add denominations in settings first',
                    style: TextStyle(color: Colors.grey),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Go Back'),
                  ),
                ],
              ),
            );
          }

          return Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // User selection
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'User',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 12),
                        DropdownButtonFormField<User>(
                          initialValue: _selectedUser,
                          decoration: const InputDecoration(
                            border: OutlineInputBorder(),
                            hintText: 'Select user',
                          ),
                          items: provider.users.map((user) {
                            return DropdownMenuItem(
                              value: user,
                              child: Row(
                                children: [
                                  CircleAvatar(
                                    radius: 16,
                                    backgroundColor: Color(
                                      int.parse(
                                        user.avatarColor.replaceFirst(
                                          '#',
                                          '0xFF',
                                        ),
                                      ),
                                    ),
                                    child: Text(
                                      user.initials,
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Text(user.name),
                                ],
                              ),
                            );
                          }).toList(),
                          validator: (value) {
                            if (value == null) {
                              return 'Please select a user';
                            }
                            return null;
                          },
                          onChanged: (user) {
                            setState(() {
                              _selectedUser = user;
                            });
                          },
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Date and Time selection
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Date & Time',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 12),
                        InkWell(
                          onTap: () async {
                            final date = await showDatePicker(
                              context: context,
                              initialDate: _selectedDateTime,
                              firstDate: DateTime(2020),
                              lastDate: DateTime.now(),
                            );
                            if (date != null && mounted) {
                              final time = await showTimePicker(
                                context: context,
                                initialTime: TimeOfDay.fromDateTime(
                                  _selectedDateTime,
                                ),
                              );
                              if (time != null && mounted) {
                                setState(() {
                                  _selectedDateTime = DateTime(
                                    date.year,
                                    date.month,
                                    date.day,
                                    time.hour,
                                    time.minute,
                                  );
                                });
                              }
                            }
                          },
                          child: InputDecorator(
                            decoration: const InputDecoration(
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.calendar_today),
                            ),
                            child: Text(
                              '${_selectedDateTime.day}/${_selectedDateTime.month}/${_selectedDateTime.year} ${_selectedDateTime.hour.toString().padLeft(2, '0')}:${_selectedDateTime.minute.toString().padLeft(2, '0')}',
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Denomination selection
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Denomination',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: activeDenominations.map((denomination) {
                            final isSelected =
                                _selectedDenomination?.id == denomination.id;
                            final available = provider.inventory.getCount(
                              denomination.id,
                            );
                            final canUse =
                                widget.transactionType ==
                                    TransactionType.added ||
                                available > 0;

                            return FilterChip(
                              selected: isSelected,
                              label: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(denomination.displayValue),
                                  if (widget.transactionType ==
                                      TransactionType.taken)
                                    Text(
                                      '($available)',
                                      style: TextStyle(
                                        fontSize: 10,
                                        color: available > 0
                                            ? Colors.grey[600]
                                            : Colors.red,
                                      ),
                                    ),
                                ],
                              ),
                              avatar: CircleAvatar(
                                backgroundColor:
                                    denomination.type == DenominationType.coin
                                    ? Colors.amber
                                    : Colors.green,
                                child: Text(
                                  denomination.type == DenominationType.coin
                                      ? 'C'
                                      : 'N',
                                  style: const TextStyle(
                                    fontSize: 10,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                              onSelected: canUse
                                  ? (selected) {
                                      setState(() {
                                        _selectedDenomination = selected
                                            ? denomination
                                            : null;
                                      });
                                    }
                                  : null,
                              backgroundColor: canUse ? null : Colors.grey[200],
                            );
                          }).toList(),
                        ),
                        if (_selectedDenomination == null)
                          const Padding(
                            padding: EdgeInsets.only(top: 8),
                            child: Text(
                              'Please select a denomination',
                              style: TextStyle(color: Colors.red, fontSize: 12),
                            ),
                          ),
                        if (_selectedDenomination != null &&
                            widget.transactionType == TransactionType.taken)
                          Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.blue.shade50,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.blue.shade200),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.info_outline,
                                    size: 16,
                                    color: Colors.blue.shade700,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      'You have ${provider.inventory.getCount(_selectedDenomination!.id)} notes of ${_selectedDenomination!.displayValue} available',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.blue.shade700,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Quantity input
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Quantity',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _quantityController,
                          decoration: const InputDecoration(
                            border: OutlineInputBorder(),
                            hintText: 'Enter quantity',
                            prefixIcon: Icon(Icons.format_list_numbered),
                          ),
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                          ],
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Please enter quantity';
                            }
                            final quantity = int.tryParse(value);
                            if (quantity == null || quantity <= 0) {
                              return 'Please enter a valid positive number';
                            }

                            // Validate available inventory for withdrawals
                            if (widget.transactionType ==
                                    TransactionType.taken &&
                                _selectedDenomination != null) {
                              final available = provider.inventory.getCount(
                                _selectedDenomination!.id,
                              );
                              if (quantity > available) {
                                return 'Only $available notes available';
                              }
                            }
                            return null;
                          },
                        ),
                        if (_selectedDenomination != null &&
                            _quantityController.text.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Total: ₹${(_selectedDenomination!.value * (int.tryParse(_quantityController.text) ?? 0)).toStringAsFixed(2)}',
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.green,
                                  ),
                                ),
                                if (widget.transactionType ==
                                    TransactionType.taken)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 4),
                                    child: Text(
                                      'Available: ${provider.inventory.getCount(_selectedDenomination!.id)} notes',
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: Colors.grey[600],
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Reason input
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Reason (Optional)',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _reasonController,
                          decoration: const InputDecoration(
                            border: OutlineInputBorder(),
                            hintText: 'e.g., Groceries, Transport, etc.',
                            prefixIcon: Icon(Icons.notes),
                          ),
                          maxLines: 3,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Submit button
                ElevatedButton(
                  onPressed:
                      (_selectedDenomination != null &&
                          _selectedUser != null &&
                          _quantityController.text.isNotEmpty)
                      ? () => _submitTransaction(provider)
                      : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor:
                        widget.transactionType == TransactionType.added
                        ? Colors.green
                        : Colors.red,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.all(16),
                    disabledBackgroundColor: Colors.grey,
                    disabledForegroundColor: Colors.white70,
                  ),
                  child: Text(
                    widget.transactionType == TransactionType.added
                        ? 'Add Money'
                        : 'Take Money',
                    style: const TextStyle(fontSize: 18),
                  ),
                ),
                const SizedBox(
                  height: 100,
                ), // Extra padding to avoid navigation bar
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _submitTransaction(AppProvider provider) async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_selectedDenomination == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a denomination')),
      );
      return;
    }

    if (_selectedUser == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please select a user')));
      return;
    }

    final quantity = int.parse(_quantityController.text);
    final reason = _reasonController.text.trim().isEmpty
        ? null
        : _reasonController.text.trim();

    // Double-check inventory for withdrawals
    if (widget.transactionType == TransactionType.taken) {
      final available = provider.inventory.getCount(_selectedDenomination!.id);
      if (quantity > available) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Insufficient notes! Only $available notes of ${_selectedDenomination!.displayValue} available.',
            ),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
            action: SnackBarAction(
              label: 'OK',
              textColor: Colors.white,
              onPressed: () {},
            ),
          ),
        );
        return;
      }
    }

    await provider.addTransaction(
      user: _selectedUser!,
      denomination: _selectedDenomination!,
      quantity: quantity,
      type: widget.transactionType,
      reason: reason,
      timestamp: _selectedDateTime,
    );

    if (mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            widget.transactionType == TransactionType.added
                ? 'Money added successfully'
                : 'Money taken successfully',
          ),
          backgroundColor: Colors.green,
        ),
      );
    }
  }
}
