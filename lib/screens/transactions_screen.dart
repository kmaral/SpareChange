import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/app_provider.dart';
import '../models/transaction.dart';
import 'transaction_detail_screen.dart';
import 'add_transaction_screen.dart';

class TransactionsScreen extends StatelessWidget {
  const TransactionsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AppProvider>(
      builder: (context, provider, child) {
        return Scaffold(
          appBar: AppBar(
            title: const Text('Transactions'),
            actions: [
              // Sync status indicator
              if (!provider.isOnline)
                Padding(
                  padding: const EdgeInsets.only(right: 8.0),
                  child: Chip(
                    avatar: const Icon(Icons.cloud_off, size: 16),
                    label: Text('Offline (${provider.pendingSyncCount})'),
                    labelStyle: const TextStyle(fontSize: 12),
                  ),
                )
              else if (provider.pendingSyncCount > 0)
                Padding(
                  padding: const EdgeInsets.only(right: 8.0),
                  child: Chip(
                    avatar: const Icon(Icons.sync, size: 16),
                    label: Text('Syncing (${provider.pendingSyncCount})'),
                    labelStyle: const TextStyle(fontSize: 12),
                  ),
                ),
            ],
          ),
          body: Column(
            children: [
              // Date filter
              _DateFilterBar(),
              const Divider(height: 1),
              // Transactions list
              Expanded(child: _TransactionsList()),
            ],
          ),
          floatingActionButton: provider.selectedUser == null
              ? null
              : Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    // Add money FAB
                    FloatingActionButton.extended(
                      heroTag: 'add',
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const AddTransactionScreen(
                              transactionType: TransactionType.added,
                            ),
                          ),
                        );
                      },
                      backgroundColor: Colors.green,
                      icon: const Icon(Icons.add),
                      label: const Text('Add'),
                    ),
                    const SizedBox(height: 12),
                    // Take money FAB
                    FloatingActionButton.extended(
                      heroTag: 'take',
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const AddTransactionScreen(
                              transactionType: TransactionType.taken,
                            ),
                          ),
                        );
                      },
                      backgroundColor: Colors.red,
                      icon: const Icon(Icons.remove),
                      label: const Text('Take'),
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
        );
      },
    );
  }
}

class _DateFilterBar extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Consumer<AppProvider>(
      builder: (context, provider, child) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                FilterChip(
                  label: const Text('All'),
                  selected: provider.filterStartDate == null,
                  onSelected: (selected) {
                    if (selected) provider.clearDateFilter();
                  },
                ),
                const SizedBox(width: 8),
                FilterChip(
                  label: const Text('Today'),
                  selected: _isToday(
                    provider.filterStartDate,
                    provider.filterEndDate,
                  ),
                  onSelected: (selected) {
                    if (selected) provider.setTodayFilter();
                  },
                ),
                const SizedBox(width: 8),
                FilterChip(
                  label: const Text('This Week'),
                  selected: _isThisWeek(provider.filterStartDate),
                  onSelected: (selected) {
                    if (selected) provider.setThisWeekFilter();
                  },
                ),
                const SizedBox(width: 8),
                FilterChip(
                  label: const Text('This Month'),
                  selected: _isThisMonth(provider.filterStartDate),
                  onSelected: (selected) {
                    if (selected) provider.setThisMonthFilter();
                  },
                ),
                const SizedBox(width: 8),
                ActionChip(
                  label: const Text('Custom'),
                  avatar: const Icon(Icons.date_range, size: 18),
                  onPressed: () => _showCustomDatePicker(context, provider),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  bool _isToday(DateTime? start, DateTime? end) {
    if (start == null || end == null) return false;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return start.year == today.year &&
        start.month == today.month &&
        start.day == today.day &&
        end.year == today.year &&
        end.month == today.month &&
        end.day == today.day;
  }

  bool _isThisWeek(DateTime? start) {
    if (start == null) return false;
    final now = DateTime.now();
    final weekStart = now.subtract(Duration(days: now.weekday - 1));
    return start.year == weekStart.year &&
        start.month == weekStart.month &&
        start.day == weekStart.day;
  }

  bool _isThisMonth(DateTime? start) {
    if (start == null) return false;
    final now = DateTime.now();
    return start.year == now.year && start.month == now.month && start.day == 1;
  }

  Future<void> _showCustomDatePicker(
    BuildContext context,
    AppProvider provider,
  ) async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange:
          provider.filterStartDate != null && provider.filterEndDate != null
          ? DateTimeRange(
              start: provider.filterStartDate!,
              end: provider.filterEndDate!,
            )
          : null,
    );

    if (picked != null) {
      provider.setDateFilter(picked.start, picked.end);
    }
  }
}

class _TransactionsList extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Consumer<AppProvider>(
      builder: (context, provider, child) {
        final transactions = provider.transactions;

        if (transactions.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.receipt_long, size: 80, color: Colors.grey[400]),
                const SizedBox(height: 16),
                Text(
                  'No transactions yet',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w500,
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Start by adding or taking money',
                  style: TextStyle(fontSize: 14, color: Colors.grey[500]),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: transactions.length,
          itemBuilder: (context, index) {
            final transaction = transactions[index];
            final dateFormat = DateFormat('MMM dd, yyyy hh:mm a');

            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                leading: CircleAvatar(
                  radius: 24,
                  backgroundColor:
                      transaction.transactionType == TransactionType.added
                      ? Colors.green
                      : Colors.red,
                  child: Icon(
                    transaction.transactionType == TransactionType.added
                        ? Icons.add
                        : Icons.remove,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
                title: Text(
                  '${transaction.transactionType == TransactionType.added ? '+' : '-'}'
                  '${transaction.displayTotalAmount}',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                    color: transaction.transactionType == TransactionType.added
                        ? Colors.green
                        : Colors.red,
                  ),
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(height: 4),
                    Text(
                      '${transaction.displayDenomination} × ${transaction.quantity}',
                      style: const TextStyle(fontSize: 15),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      transaction.userName,
                      style: const TextStyle(fontSize: 13),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      dateFormat.format(transaction.timestamp),
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                    if (transaction.reason != null &&
                        transaction.reason!.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        transaction.reason!,
                        style: const TextStyle(
                          fontStyle: FontStyle.italic,
                          fontSize: 12,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
                trailing: transaction.syncStatus == SyncStatus.pending
                    ? const Icon(Icons.sync, color: Colors.orange)
                    : transaction.syncStatus == SyncStatus.failed
                    ? const Icon(Icons.error, color: Colors.red)
                    : const Icon(Icons.chevron_right, color: Colors.grey),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) =>
                          TransactionDetailScreen(transaction: transaction),
                    ),
                  );
                },
              ),
            );
          },
        );
      },
    );
  }
}
