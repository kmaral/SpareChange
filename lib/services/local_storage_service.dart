import 'package:hive_flutter/hive_flutter.dart';
import '../models/denomination.dart';
import '../models/transaction.dart';
import '../models/inventory.dart';

class LocalStorageService {
  static const denominationsBoxName = 'denominations';
  static const transactionsBoxName = 'transactions';
  static const inventoryBoxName = 'inventory';
  static const _inventoryKey = 'inventory';

  static Future<void> init() async {
    await Hive.initFlutter();

    Hive.registerAdapter(DenominationAdapter());
    Hive.registerAdapter(DenominationTypeAdapter());
    Hive.registerAdapter(CurrencyTransactionAdapter());
    Hive.registerAdapter(TransactionTypeAdapter());
    Hive.registerAdapter(InventoryAdapter());

    await Hive.openBox<Denomination>(denominationsBoxName);
    await Hive.openBox<CurrencyTransaction>(transactionsBoxName);
    await Hive.openBox<Inventory>(inventoryBoxName);
  }

  Box<Denomination> get _denominationsBox =>
      Hive.box<Denomination>(denominationsBoxName);
  Box<CurrencyTransaction> get _transactionsBox =>
      Hive.box<CurrencyTransaction>(transactionsBoxName);
  Box<Inventory> get _inventoryBox => Hive.box<Inventory>(inventoryBoxName);

  // ===== Denominations =====

  List<Denomination> getDenominations() => _denominationsBox.values.toList();

  Future<void> addDenomination(Denomination denomination) =>
      _denominationsBox.put(denomination.id, denomination);

  Future<void> updateDenomination(Denomination denomination) =>
      _denominationsBox.put(denomination.id, denomination);

  Future<void> deleteDenomination(String denominationId) =>
      _denominationsBox.delete(denominationId);

  bool hasDenominationTransactions(String denominationId) => _transactionsBox
      .values
      .any((t) => t.denominationId == denominationId);

  // ===== Transactions =====

  List<CurrencyTransaction> getTransactions({
    DateTime? startDate,
    DateTime? endDate,
  }) {
    var transactions = _transactionsBox.values.toList();
    if (startDate != null) {
      transactions = transactions
          .where((t) => !t.timestamp.isBefore(startDate))
          .toList();
    }
    if (endDate != null) {
      final endOfDay = DateTime(
        endDate.year,
        endDate.month,
        endDate.day,
        23,
        59,
        59,
        999,
      );
      transactions = transactions
          .where((t) => !t.timestamp.isAfter(endOfDay))
          .toList();
    }
    transactions.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return transactions;
  }

  Future<void> addTransaction(CurrencyTransaction transaction) =>
      _transactionsBox.put(transaction.id, transaction);

  Future<void> updateTransaction(CurrencyTransaction transaction) =>
      _transactionsBox.put(transaction.id, transaction);

  Future<void> deleteTransaction(String transactionId) =>
      _transactionsBox.delete(transactionId);

  Future<void> deleteAllTransactions() => _transactionsBox.clear();

  // ===== Inventory =====

  Inventory getInventory() => _inventoryBox.get(_inventoryKey) ?? Inventory();

  Future<void> saveInventory(Inventory inventory) =>
      _inventoryBox.put(_inventoryKey, inventory);

  // Re-derive inventory counts from all stored transactions
  Future<Inventory> recalculateInventoryFromTransactions() async {
    var inventory = Inventory();
    for (final transaction in _transactionsBox.values) {
      inventory = transaction.transactionType == TransactionType.added
          ? inventory.addCount(transaction.denominationId, transaction.quantity)
          : inventory.subtractCount(
              transaction.denominationId,
              transaction.quantity,
            );
    }
    await saveInventory(inventory);
    return inventory;
  }

  // Atomically write a new transaction and update inventory to match
  Future<Inventory> addTransactionAndUpdateInventory(
    CurrencyTransaction transaction,
  ) async {
    await addTransaction(transaction);
    final inventory = getInventory();
    final updated = transaction.transactionType == TransactionType.added
        ? inventory.addCount(transaction.denominationId, transaction.quantity)
        : inventory.subtractCount(
            transaction.denominationId,
            transaction.quantity,
          );
    await saveInventory(updated);
    return updated;
  }
}
