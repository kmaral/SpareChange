import 'package:flutter/material.dart';
import '../models/denomination.dart';

class DenominationChart extends StatelessWidget {
  final Map<Denomination, int> breakdown;

  const DenominationChart({super.key, required this.breakdown});

  @override
  Widget build(BuildContext context) {
    if (breakdown.isEmpty) {
      return const Card(
        margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Padding(
          padding: EdgeInsets.all(24.0),
          child: Center(
            child: Text(
              'No denominations in inventory',
              style: TextStyle(fontStyle: FontStyle.italic, color: Colors.grey),
            ),
          ),
        ),
      );
    }

    // Sort denominations by value (highest first)
    final sortedEntries = breakdown.entries.toList()
      ..sort((a, b) => b.key.value.compareTo(a.key.value));

    // Calculate total value
    final totalValue = sortedEntries.fold<double>(
      0.0,
      (sum, entry) => sum + (entry.key.value * entry.value),
    );

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Icon(
                        Icons.account_balance_wallet,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Denomination Breakdown',
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(fontWeight: FontWeight.bold),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.green.shade100, Colors.green.shade50],
                    ),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: Colors.green.shade400,
                      width: 1.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.green.withValues(alpha: 0.2),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Text(
                    '₹${totalValue.toStringAsFixed(2)}',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 17,
                      letterSpacing: 0.3,
                      height: 1.4,
                      color: Colors.green.shade900,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Compact horizontal scroll list
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: sortedEntries.map((entry) {
                  final denomination = entry.key;
                  final count = entry.value;
                  final value = denomination.value * count;

                  // Determine background colors for specific notes
                  Color? noteColor;
                  Color? noteAccent;
                  if (denomination.type == DenominationType.note) {
                    if (denomination.value == 500) {
                      noteColor = const Color(0xFFE8D5B5); // Beige/Stone
                      noteAccent = const Color(0xFFB89968);
                    } else if (denomination.value == 100) {
                      noteColor = const Color(0xFFB8D4E8); // Light Blue
                      noteAccent = const Color(0xFF7BA8C9);
                    } else if (denomination.value == 200) {
                      noteColor = const Color(0xFFE8C5A8); // Yellow
                      noteAccent = const Color(0xFFD4A574);
                    } else if (denomination.value == 50) {
                      noteColor = const Color(0xFFD8B8E8); // Purple
                      noteAccent = const Color(0xFFA87CC9);
                    } else if (denomination.value == 20) {
                      noteColor = const Color(0xFFE8C8B8); // Orange
                      noteAccent = const Color(0xFFD49874);
                    } else if (denomination.value == 10) {
                      noteColor = const Color(0xFFD4B8A8); // Brown
                      noteAccent = const Color(0xFFA88868);
                    }
                  }

                  return Container(
                    margin: const EdgeInsets.only(right: 12),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      gradient: noteColor != null
                          ? LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                noteColor.withValues(alpha: 0.3),
                                noteColor.withValues(alpha: 0.5),
                              ],
                            )
                          : LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: denomination.type == DenominationType.coin
                                  ? [
                                      Colors.amber.shade50,
                                      Colors.amber.shade100,
                                    ]
                                  : [
                                      Colors.green.shade50,
                                      Colors.green.shade100,
                                    ],
                            ),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color:
                            noteAccent ??
                            (denomination.type == DenominationType.coin
                                ? Colors.amber.shade300
                                : Colors.green.shade300),
                        width: 2,
                      ),
                      boxShadow: noteColor != null
                          ? [
                              BoxShadow(
                                color: noteAccent!.withValues(alpha: 0.3),
                                blurRadius: 8,
                                offset: const Offset(0, 3),
                              ),
                            ]
                          : null,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Denomination value with icon
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: denomination.type == DenominationType.coin
                                  ? [
                                      Colors.amber.shade400,
                                      Colors.amber.shade600,
                                    ]
                                  : [
                                      Colors.green.shade400,
                                      Colors.green.shade600,
                                    ],
                            ),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                denomination.type == DenominationType.coin
                                    ? Icons.monetization_on
                                    : Icons.receipt,
                                color: Colors.white,
                                size: 14,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                denomination.displayValue,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),
                        // Count
                        Text(
                          '$count',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 22,
                            color: denomination.type == DenominationType.coin
                                ? Colors.amber.shade900
                                : Colors.green.shade900,
                          ),
                        ),
                        Text(
                          count == 1 ? 'piece' : 'pieces',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
