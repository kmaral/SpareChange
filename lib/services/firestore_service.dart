import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/denomination.dart';
import '../models/user.dart';
import '../models/transaction.dart';
import '../models/inventory.dart';

/// FirestoreService handles all Firestore operations with group-based data isolation
///
/// All denominations, transactions, and inventory are linked to a groupId:
/// - Denominations: Filtered by 'groupId' field
/// - Transactions: Filtered by 'groupId' field
/// - Inventory: Stored per group in 'inventory/{groupId}' documents
///
/// This ensures data isolation between different groups.
class FirestoreService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Collection references
  CollectionReference get _denominations =>
      _firestore.collection('denominations');
  CollectionReference get _users => _firestore.collection('family_members');
  CollectionReference get _transactions =>
      _firestore.collection('transactions');

  // Get group-specific inventory
  DocumentReference _getInventoryRef(String? groupId) {
    return _firestore.collection('inventory').doc(groupId ?? 'default');
  }

  // ===== DENOMINATION OPERATIONS =====

  Stream<List<Denomination>> streamDenominations({String? groupId}) {
    Query query = _denominations.orderBy('value', descending: false);

    if (groupId != null) {
      query = query.where('groupId', isEqualTo: groupId);
    }

    return query.snapshots().map(
      (snapshot) => snapshot.docs
          .map(
            (doc) => Denomination.fromJson(doc.data() as Map<String, dynamic>),
          )
          .toList(),
    );
  }

  Future<void> addDenomination(Denomination denomination) async {
    final data = denomination.toJson();
    print('FirestoreService: Saving denomination with data: $data');
    await _denominations.doc(denomination.id).set(data);
    print('FirestoreService: Denomination saved successfully');
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
    String? groupId,
  }) {
    Query query = _transactions.orderBy('timestamp', descending: true);

    if (groupId != null) {
      query = query.where('groupId', isEqualTo: groupId);
    }

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

  Future<List<CurrencyTransaction>> getAllTransactions({
    String? groupId,
  }) async {
    Query query = _transactions.orderBy('timestamp', descending: false);

    if (groupId != null) {
      query = query.where('groupId', isEqualTo: groupId);
    }

    final snapshot = await query.get();
    return snapshot.docs
        .map(
          (doc) =>
              CurrencyTransaction.fromJson(doc.data() as Map<String, dynamic>),
        )
        .toList();
  }

  Future<void> addTransaction(CurrencyTransaction transaction) async {
    final data = transaction.toJson();
    print('FirestoreService: Saving transaction with data: $data');
    await _transactions.doc(transaction.id).set(data);
    print('FirestoreService: Transaction saved successfully');
  }

  Future<void> updateTransaction(CurrencyTransaction transaction) async {
    await _transactions.doc(transaction.id).update(transaction.toJson());
  }

  Future<void> deleteTransaction(String transactionId) async {
    await _transactions.doc(transactionId).delete();
  }

  // ===== INVENTORY OPERATIONS =====

  Stream<Inventory> streamInventory({String? groupId}) {
    return _getInventoryRef(groupId).snapshots().map((snapshot) {
      if (!snapshot.exists) {
        return Inventory(groupId: groupId);
      }
      return Inventory.fromJson(snapshot.data() as Map<String, dynamic>);
    });
  }

  Future<Inventory> getInventory({String? groupId}) async {
    final snapshot = await _getInventoryRef(groupId).get();
    if (!snapshot.exists) {
      return Inventory(groupId: groupId);
    }
    return Inventory.fromJson(snapshot.data() as Map<String, dynamic>);
  }

  Future<void> updateInventory(Inventory inventory, {String? groupId}) async {
    // Ensure inventory has the correct groupId
    final inventoryWithGroupId = inventory.groupId == groupId
        ? inventory
        : inventory.copyWith(groupId: groupId);

    print('FirestoreService: Updating inventory with groupId = $groupId');
    await _getInventoryRef(
      groupId,
    ).set(inventoryWithGroupId.toJson(), SetOptions(merge: true));
  }

  // ===== INVENTORY RECALCULATION =====

  Future<void> recalculateInventoryFromTransactions({String? groupId}) async {
    // Get all transactions for this group
    final allTransactions = await getAllTransactions(groupId: groupId);

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

    await updateInventory(inventory, groupId: groupId);
  }

  // ===== BATCH OPERATIONS =====

  Future<void> addTransactionAndUpdateInventory(
    CurrencyTransaction transaction,
    String denominationId, {
    String? groupId,
  }) async {
    print(
      'FirestoreService: addTransactionAndUpdateInventory called with groupId = $groupId',
    );
    print('FirestoreService: Transaction groupId = ${transaction.groupId}');

    final batch = _firestore.batch();

    final transactionData = transaction.toJson();
    print('FirestoreService: Transaction data to save: $transactionData');

    // Add transaction
    batch.set(_transactions.doc(transaction.id), transactionData);

    // Update inventory
    final inventoryRef = _getInventoryRef(groupId);
    print('FirestoreService: Using inventory ref for groupId = $groupId');
    final inventorySnapshot = await inventoryRef.get();
    Inventory inventory;
    if (inventorySnapshot.exists) {
      inventory = Inventory.fromJson(
        inventorySnapshot.data() as Map<String, dynamic>,
      );
    } else {
      inventory = Inventory(groupId: groupId);
    }

    if (transaction.transactionType == TransactionType.added) {
      inventory = inventory.addCount(denominationId, transaction.quantity);
    } else {
      inventory = inventory.subtractCount(denominationId, transaction.quantity);
    }

    // Ensure inventory has the correct groupId before saving
    if (inventory.groupId != groupId) {
      inventory = inventory.copyWith(groupId: groupId);
    }

    // Always set the full inventory, not merge
    batch.set(inventoryRef, inventory.toJson());

    print('FirestoreService: Committing batch...');
    await batch.commit();
    print('FirestoreService: Batch committed successfully');
  }
}
