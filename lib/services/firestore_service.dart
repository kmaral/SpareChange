import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/denomination.dart';
import '../models/user.dart';
import '../models/transaction.dart';
import '../models/inventory.dart';

class FirestoreService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Collection references
  CollectionReference get _denominations =>
      _firestore.collection('denominations');
  CollectionReference get _users => _firestore.collection('family_members');
  CollectionReference get _transactions =>
      _firestore.collection('transactions');
  DocumentReference get _inventory =>
      _firestore.collection('inventory').doc('current');

  // ===== DENOMINATION OPERATIONS =====

  Stream<List<Denomination>> streamDenominations() {
    return _denominations
        .orderBy('value', descending: false)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map(
                (doc) =>
                    Denomination.fromJson(doc.data() as Map<String, dynamic>),
              )
              .toList(),
        );
  }

  Future<void> addDenomination(Denomination denomination) async {
    await _denominations.doc(denomination.id).set(denomination.toJson());
  }

  Future<void> updateDenomination(Denomination denomination) async {
    await _denominations.doc(denomination.id).update(denomination.toJson());
  }

  Future<void> deleteDenomination(String denominationId) async {
    await _denominations.doc(denominationId).delete();
  }

  Future<bool> hasDenominationTransactions(String denominationId) async {
    final snapshot = await _transactions
        .where('denominationValue', isEqualTo: denominationId)
        .limit(1)
        .get();
    return snapshot.docs.isNotEmpty;
  }

  // ===== USER OPERATIONS =====

  Stream<List<User>> streamUsers() {
    return _users
        .orderBy('createdAt', descending: false)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => User.fromJson(doc.data() as Map<String, dynamic>))
              .toList(),
        );
  }

  Future<void> addUser(User user) async {
    await _users.doc(user.id).set(user.toJson());
  }

  Future<void> updateUser(User user) async {
    await _users.doc(user.id).update(user.toJson());
  }

  Future<void> deleteUser(String userId) async {
    await _users.doc(userId).delete();
  }

  Future<bool> hasUserTransactions(String userId) async {
    final snapshot = await _transactions
        .where('userId', isEqualTo: userId)
        .limit(1)
        .get();
    return snapshot.docs.isNotEmpty;
  }

  // ===== TRANSACTION OPERATIONS =====

  Stream<List<CurrencyTransaction>> streamTransactions({
    DateTime? startDate,
    DateTime? endDate,
  }) {
    Query query = _transactions.orderBy('timestamp', descending: true);

    if (startDate != null) {
      query = query.where(
        'timestamp',
        isGreaterThanOrEqualTo: Timestamp.fromDate(startDate),
      );
    }

    if (endDate != null) {
      // Add one day to include the entire end date
      final adjustedEndDate = endDate.add(const Duration(days: 1));
      query = query.where(
        'timestamp',
        isLessThan: Timestamp.fromDate(adjustedEndDate),
      );
    }

    return query.snapshots().map(
      (snapshot) => snapshot.docs
          .map(
            (doc) => CurrencyTransaction.fromJson(
              doc.data() as Map<String, dynamic>,
            ),
          )
          .toList(),
    );
  }

  Future<List<CurrencyTransaction>> getAllTransactions() async {
    final snapshot = await _transactions
        .orderBy('timestamp', descending: false)
        .get();
    return snapshot.docs
        .map(
          (doc) =>
              CurrencyTransaction.fromJson(doc.data() as Map<String, dynamic>),
        )
        .toList();
  }

  Future<void> addTransaction(CurrencyTransaction transaction) async {
    await _transactions.doc(transaction.id).set(transaction.toJson());
  }

  Future<void> updateTransaction(CurrencyTransaction transaction) async {
    await _transactions.doc(transaction.id).update(transaction.toJson());
  }

  Future<void> deleteTransaction(String transactionId) async {
    await _transactions.doc(transactionId).delete();
  }

  // ===== INVENTORY OPERATIONS =====

  Stream<Inventory> streamInventory() {
    return _inventory.snapshots().map((snapshot) {
      if (!snapshot.exists) {
        return Inventory();
      }
      return Inventory.fromJson(snapshot.data() as Map<String, dynamic>);
    });
  }

  Future<Inventory> getInventory() async {
    final snapshot = await _inventory.get();
    if (!snapshot.exists) {
      return Inventory();
    }
    return Inventory.fromJson(snapshot.data() as Map<String, dynamic>);
  }

  Future<void> updateInventory(Inventory inventory) async {
    await _inventory.set(inventory.toJson(), SetOptions(merge: true));
  }

  // ===== INVENTORY RECALCULATION =====

  Future<void> recalculateInventoryFromTransactions() async {
    // Get all transactions
    final allTransactions = await getAllTransactions();

    // Calculate counts for each denomination ID
    final Map<String, int> denominationCounts = {};

    for (final transaction in allTransactions) {
      // Use denominationId if available, otherwise fallback to value-based lookup
      String? denominationId = transaction.denominationId.isNotEmpty
          ? transaction.denominationId
          : null;

      // Fallback: If no ID, look up by value (for old transactions)
      if (denominationId == null || denominationId.isEmpty) {
        final denominationsSnapshot = await _denominations
            .where('value', isEqualTo: transaction.denominationValue)
            .limit(1)
            .get();
        if (denominationsSnapshot.docs.isNotEmpty) {
          denominationId = denominationsSnapshot.docs.first.id;
        }
      }

      if (denominationId != null && denominationId.isNotEmpty) {
        final currentCount = denominationCounts[denominationId] ?? 0;

        if (transaction.transactionType == TransactionType.added) {
          denominationCounts[denominationId] =
              currentCount + transaction.quantity;
        } else {
          denominationCounts[denominationId] =
              currentCount - transaction.quantity;
        }
      }
    }

    // Remove zero or negative counts
    denominationCounts.removeWhere((key, value) => value <= 0);

    // Update inventory
    final inventory = Inventory(
      denominationCounts: denominationCounts,
      lastUpdated: DateTime.now(),
    );

    await updateInventory(inventory);
  }

  // ===== BATCH OPERATIONS =====

  Future<void> addTransactionAndUpdateInventory(
    CurrencyTransaction transaction,
    String denominationId,
  ) async {
    final batch = _firestore.batch();

    // Add transaction
    batch.set(_transactions.doc(transaction.id), transaction.toJson());

    // Update inventory
    final inventorySnapshot = await _inventory.get();
    Inventory inventory;
    if (inventorySnapshot.exists) {
      inventory = Inventory.fromJson(
        inventorySnapshot.data() as Map<String, dynamic>,
      );
    } else {
      inventory = Inventory();
    }

    if (transaction.transactionType == TransactionType.added) {
      inventory = inventory.addCount(denominationId, transaction.quantity);
    } else {
      inventory = inventory.subtractCount(denominationId, transaction.quantity);
    }

    // Always set the full inventory, not merge
    batch.set(_inventory, inventory.toJson());

    await batch.commit();
  }
}
