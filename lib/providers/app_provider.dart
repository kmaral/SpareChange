import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import 'dart:async';
import '../models/user.dart';
import '../models/denomination.dart';
import '../models/transaction.dart';
import '../models/inventory.dart';
import '../services/firestore_service.dart';
import '../services/sync_service.dart';
import '../services/auth_service.dart';

class AppProvider with ChangeNotifier {
  final FirestoreService _firestoreService;
  final SyncService _syncService;
  final SharedPreferences _prefs;

  List<User> _users = [];
  List<Denomination> _denominations = [];
  List<CurrencyTransaction> _transactions = [];
  Inventory _inventory = Inventory();

  User? _selectedUser;
  DateTime? _filterStartDate;
  DateTime? _filterEndDate;
  String? _groupId;
  bool _isGroupIdLoaded = false;

  bool _isLoading = false;
  String? _error;
  String _themeMode = 'System';

  // Stream subscriptions
  StreamSubscription? _usersSubscription;
  StreamSubscription? _denominationsSubscription;
  StreamSubscription? _transactionsSubscription;
  StreamSubscription? _inventorySubscription;

  AppProvider({
    required FirestoreService firestoreService,
    required SyncService syncService,
    required SharedPreferences prefs,
  }) : _firestoreService = firestoreService,
       _syncService = syncService,
       _prefs = prefs {
    _loadSelectedUser();
    _loadThemeMode();
    _initializeGroupId();
  }

  // Getters
  List<User> get users => _users;
  List<Denomination> get denominations => _denominations;
  List<Denomination> get activeDenominations =>
      _denominations.where((d) => d.isActive).toList();
  List<CurrencyTransaction> get transactions => _transactions;
  Inventory get inventory => _inventory;
  User? get selectedUser => _selectedUser;
  DateTime? get filterStartDate => _filterStartDate;
  DateTime? get filterEndDate => _filterEndDate;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get isOnline => _syncService.isOnline;
  int get pendingSyncCount => _syncService.pendingCount;
  String get themeMode => _themeMode;
  String? get groupId => _groupId;

  // Reload groupId (useful after creating/joining a group)
  Future<void> reloadGroupId() async {
    try {
      print('AppProvider: Reloading groupId...');
      final authService = AuthService();
      final group = await authService.getUserGroup();
      print('AppProvider: getUserGroup returned: $group');
      _groupId = group?['id'];
      _isGroupIdLoaded = true;
      print('AppProvider: Reloaded groupId = $_groupId');

      if (_groupId == null) {
        print('AppProvider: WARNING - groupId is still null after reload!');
        print('AppProvider: Group data: $group');
      } else {
        // Cancel old subscriptions and restart with new groupId
        await _cancelSubscriptions();
        _subscribeToStreams();
      }

      notifyListeners();
    } catch (e) {
      print('AppProvider: Error reloading groupId: $e');
    }
  }

  // Reset all data when user signs out (clear cached data for previous user)
  Future<void> resetForNewUser() async {
    try {
      print('AppProvider: Resetting data for user sign out...');

      // Cancel all subscriptions
      await _cancelSubscriptions();

      // Clear all data
      _users = [];
      _denominations = [];
      _transactions = [];
      _inventory = Inventory();
      _selectedUser = null;
      _filterStartDate = null;
      _filterEndDate = null;
      _groupId = null;
      _isGroupIdLoaded = false;
      _error = null;

      // Clear saved selected user from SharedPreferences
      await _prefs.remove('selected_user_id');

      print('AppProvider: Data reset complete');
      notifyListeners();
    } catch (e) {
      print('AppProvider: Error resetting data: $e');
    }
  }

  // Initialize data for new user after sign in
  Future<void> initializeForNewUser() async {
    try {
      print('AppProvider: Initializing data for new user...');

      // Reset data first
      await resetForNewUser();

      // Reload groupId and subscribe to streams
      await _initializeGroupId();

      print('AppProvider: Initialization complete');
    } catch (e) {
      print('AppProvider: Error initializing for new user: $e');
    }
  }

  Future<void> _initializeGroupId() async {
    try {
      print('AppProvider: Loading groupId...');
      final authService = AuthService();
      final group = await authService.getUserGroup();
      print('AppProvider: getUserGroup returned: $group');
      _groupId = group?['id'];
      _isGroupIdLoaded = true;
      print('AppProvider: Loaded groupId = $_groupId');
      print('AppProvider: _isGroupIdLoaded = $_isGroupIdLoaded');

      if (_groupId == null) {
        print(
          'AppProvider: WARNING - groupId is null! User may not be in a group.',
        );
        print('AppProvider: Group data: $group');
      }

      // Only subscribe after groupId is loaded
      _subscribeToStreams();
      notifyListeners();
    } catch (e) {
      print('AppProvider: Error loading groupId: $e');
      print('AppProvider: Stack trace: ${StackTrace.current}');
      _isGroupIdLoaded = true;
      // Subscribe anyway to avoid blocking the app
      _subscribeToStreams();
      notifyListeners();
    }
  }

  // Ensure groupId is loaded before operations
  Future<void> _ensureGroupIdLoaded() async {
    if (!_isGroupIdLoaded) {
      print('AppProvider: Waiting for groupId to load...');
      // Wait for groupId to be loaded (with timeout)
      int attempts = 0;
      while (!_isGroupIdLoaded && attempts < 50) {
        await Future.delayed(const Duration(milliseconds: 100));
        attempts++;
      }

      if (!_isGroupIdLoaded) {
        print('AppProvider: Timeout waiting for groupId');
        throw Exception('System is initializing. Please wait and try again.');
      }
    }

    if (_groupId == null) {
      print(
        'AppProvider: ERROR - GroupId is null! User must create or join a group.',
      );
      throw Exception(
        'You must create or join a group before performing this action.',
      );
    }

    print('AppProvider: GroupId verified: $_groupId');
  }

  void _loadThemeMode() {
    _themeMode = _prefs.getString('themeMode') ?? 'System';
    notifyListeners();
  }

  Future<void> setThemeMode(String mode) async {
    _themeMode = mode;
    await _prefs.setString('themeMode', mode);
    notifyListeners();
  }

  // ===== USER OPERATIONS =====

  Future<User?> addUser(String name, String avatarColor) async {
    _setLoading(true);
    try {
      final user = User(
        id: const Uuid().v4(),
        name: name,
        avatarColor: avatarColor,
      );

      await _firestoreService.addUser(user);
      return user;
    } catch (e) {
      _setError('Failed to add user: $e');
      return null;
    } finally {
      _setLoading(false);
    }
  }

  Future<void> updateUser(User user) async {
    _setLoading(true);
    try {
      if (_syncService.isOnline) {
        await _firestoreService.updateUser(user);
      } else {
        _setError('Cannot update user while offline');
      }
    } catch (e) {
      _setError('Failed to update user: $e');
    } finally {
      _setLoading(false);
    }
  }

  Future<void> deleteUser(String userId) async {
    _setLoading(true);
    try {
      final hasTransactions = await _firestoreService.hasUserTransactions(
        userId,
      );
      if (hasTransactions) {
        _setError('Cannot delete user with existing transactions');
        _setLoading(false);
        return;
      }

      if (_syncService.isOnline) {
        await _firestoreService.deleteUser(userId);
        if (_selectedUser?.id == userId) {
          setSelectedUser(null);
        }
      } else {
        _setError('Cannot delete user while offline');
      }
    } catch (e) {
      _setError('Failed to delete user: $e');
    } finally {
      _setLoading(false);
    }
  }

  void setSelectedUser(User? user) {
    _selectedUser = user;
    if (user != null) {
      _prefs.setString('selected_user_id', user.id);
    } else {
      _prefs.remove('selected_user_id');
    }
    notifyListeners();
  }

  void _loadSelectedUser() {
    final userId = _prefs.getString('selected_user_id');
    if (userId != null) {
      // Will be set once users are loaded
    }
  }

  // ===== DENOMINATION OPERATIONS =====

  Future<void> addDenomination(double value, DenominationType type) async {
    _setLoading(true);
    try {
      // Ensure groupId is loaded
      await _ensureGroupIdLoaded();

      print('AppProvider: Adding denomination with groupId = $_groupId');

      // Check if denomination with this value already exists
      final exists = _denominations.any((d) => d.value == value);
      if (exists) {
        _setError('Denomination with value ₹$value already exists');
        _setLoading(false);
        return;
      }

      final denomination = Denomination(
        id: const Uuid().v4(),
        value: value,
        type: type,
        isActive: true,
        groupId: _groupId,
      );

      print(
        'AppProvider: Denomination created with groupId = ${denomination.groupId}',
      );

      if (_syncService.isOnline) {
        await _firestoreService.addDenomination(denomination);
        print('AppProvider: Denomination saved to Firestore');
      } else {
        _setError('Cannot add denomination while offline');
      }
    } catch (e) {
      print('AppProvider: Error adding denomination: $e');
      _setError('Failed to add denomination: $e');
    } finally {
      _setLoading(false);
    }
  }

  Future<void> toggleDenominationActive(Denomination denomination) async {
    _setLoading(true);
    try {
      final updated = denomination.copyWith(isActive: !denomination.isActive);
      await _firestoreService.updateDenomination(updated);
    } catch (e) {
      _setError('Failed to update denomination: $e');
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> deleteDenomination(String denominationId) async {
    _setLoading(true);
    try {
      final hasTransactions = await _firestoreService
          .hasDenominationTransactions(denominationId);
      if (hasTransactions) {
        _setLoading(false);
        return false; // Return false to show warning dialog
      }

      if (_syncService.isOnline) {
        await _firestoreService.deleteDenomination(denominationId);
        _setLoading(false);
        return true;
      } else {
        _setError('Cannot delete denomination while offline');
        _setLoading(false);
        return false;
      }
    } catch (e) {
      _setError('Failed to delete denomination: $e');
      _setLoading(false);
      return false;
    }
  }

  // ===== TRANSACTION OPERATIONS =====

  Future<void> addTransaction({
    required User user,
    required Denomination denomination,
    required int quantity,
    required TransactionType type,
    String? reason,
    DateTime? timestamp,
  }) async {
    _setLoading(true);
    try {
      // Ensure groupId is loaded
      await _ensureGroupIdLoaded();

      print('AppProvider: Adding transaction with groupId = $_groupId');

      final transaction = CurrencyTransaction(
        id: const Uuid().v4(),
        userId: user.id,
        userName: user.name,
        denominationValue: denomination.value,
        denominationId: denomination.id,
        quantity: quantity,
        transactionType: type,
        totalAmount: denomination.value * quantity,
        reason: reason,
        timestamp: timestamp ?? DateTime.now(),
        lastModified: DateTime.now(),
        syncStatus: _syncService.isOnline
            ? SyncStatus.synced
            : SyncStatus.pending,
        groupId: _groupId,
      );

      print(
        'AppProvider: Transaction created with groupId = ${transaction.groupId}',
      );

      if (_syncService.isOnline) {
        await _firestoreService.addTransactionAndUpdateInventory(
          transaction,
          denomination.id,
          groupId: _groupId,
        );
        print('AppProvider: Transaction saved to Firestore');
      } else {
        // Queue for later sync
        await _syncService.queueTransaction(transaction);
        // Update local inventory immediately for offline experience
        // Note: The actual Firestore inventory will be updated when synced
      }

      _clearError();
    } catch (e) {
      print('AppProvider: Error adding transaction: $e');
      _setError('Failed to add transaction: $e');
    } finally {
      _setLoading(false);
    }
  }

  Future<void> updateTransaction({
    required CurrencyTransaction transaction,
    required User user,
    required Denomination denomination,
    required int quantity,
    required TransactionType type,
    String? reason,
  }) async {
    _setLoading(true);
    try {
      final updated = transaction.copyWith(
        userId: user.id,
        userName: user.name,
        denominationValue: denomination.value,
        denominationId: denomination.id,
        quantity: quantity,
        transactionType: type,
        totalAmount: denomination.value * quantity,
        reason: reason,
        lastModified: DateTime.now(),
      );

      if (_syncService.isOnline) {
        await _firestoreService.updateTransaction(updated);
        // Recalculate inventory after edit
        await _firestoreService.recalculateInventoryFromTransactions(
          groupId: _groupId,
        );
      } else {
        _setError('Cannot edit transaction while offline');
      }

      _clearError();
    } catch (e) {
      _setError('Failed to update transaction: $e');
    } finally {
      _setLoading(false);
    }
  }

  Future<void> deleteTransaction(CurrencyTransaction transaction) async {
    _setLoading(true);
    try {
      if (_syncService.isOnline) {
        await _firestoreService.deleteTransaction(transaction.id);
        // Recalculate inventory after deletion
        await _firestoreService.recalculateInventoryFromTransactions(
          groupId: _groupId,
        );
      } else {
        _setError('Cannot delete transaction while offline');
      }

      _clearError();
    } catch (e) {
      _setError('Failed to delete transaction: $e');
    } finally {
      _setLoading(false);
    }
  }

  // Delete all transactions (admin only)
  Future<bool> deleteAllTransactions() async {
    _setLoading(true);
    try {
      if (!_syncService.isOnline) {
        _setError('Cannot delete all transactions while offline');
        _setLoading(false);
        return false;
      }

      // Delete all transactions
      for (var transaction in _transactions) {
        await _firestoreService.deleteTransaction(transaction.id);
      }

      // Reset inventory to zero with groupId
      await _firestoreService.updateInventory(
        Inventory(groupId: _groupId),
        groupId: _groupId,
      );

      _clearError();
      _setLoading(false);
      return true;
    } catch (e) {
      _setError('Failed to delete all transactions: $e');
      _setLoading(false);
      return false;
    }
  }

  // Recalculate inventory from all transactions
  Future<void> recalculateInventory() async {
    try {
      if (_syncService.isOnline) {
        await _firestoreService.recalculateInventoryFromTransactions(
          groupId: _groupId,
        );
        _clearError();
      }
    } catch (e) {
      _setError('Failed to recalculate inventory: $e');
    }
  }

  // ===== DATE FILTER =====

  void setDateFilter(DateTime? startDate, DateTime? endDate) {
    _filterStartDate = startDate;
    _filterEndDate = endDate;
    notifyListeners();
  }

  void clearDateFilter() {
    _filterStartDate = null;
    _filterEndDate = null;
    notifyListeners();
  }

  void setTodayFilter() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    setDateFilter(today, today);
  }

  void setThisWeekFilter() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final weekStart = today.subtract(Duration(days: now.weekday - 1));
    setDateFilter(weekStart, today);
  }

  void setThisMonthFilter() {
    final now = DateTime.now();
    final monthStart = DateTime(now.year, now.month, 1);
    final today = DateTime(now.year, now.month, now.day);
    setDateFilter(monthStart, today);
  }

  // ===== CALCULATED VALUES =====

  double getTotalBalance() {
    final denominationValues = {for (var d in _denominations) d.id: d.value};
    return _inventory.calculateTotalValue(denominationValues);
  }

  Map<Denomination, int> getDenominationBreakdown() {
    final breakdown = <Denomination, int>{};
    for (var denomination in _denominations) {
      final count = _inventory.getCount(denomination.id);
      if (count > 0) {
        breakdown[denomination] = count;
      }
    }
    return breakdown;
  }

  // ===== PRIVATE METHODS =====

  Future<void> _cancelSubscriptions() async {
    await _usersSubscription?.cancel();
    await _denominationsSubscription?.cancel();
    await _transactionsSubscription?.cancel();
    await _inventorySubscription?.cancel();
  }

  void _subscribeToStreams() {
    print('AppProvider: Subscribing to streams with groupId = $_groupId');

    _usersSubscription = _firestoreService.streamUsers().listen((users) {
      _users = users;
      // Set selected user if it was saved
      if (_selectedUser == null) {
        final userId = _prefs.getString('selected_user_id');
        if (userId != null) {
          final matchingUser = users.where((u) => u.id == userId);
          if (matchingUser.isNotEmpty) {
            _selectedUser = matchingUser.first;
          } else if (users.isNotEmpty) {
            _selectedUser = users.first;
          }
        }
      }
      notifyListeners();
    });

    _denominationsSubscription = _firestoreService
        .streamDenominations(groupId: _groupId)
        .listen((denominations) {
          print(
            'AppProvider: Received ${denominations.length} denominations for groupId $_groupId',
          );
          _denominations = denominations;
          notifyListeners();
        });

    _transactionsSubscription = _firestoreService
        .streamTransactions(
          startDate: _filterStartDate,
          endDate: _filterEndDate,
          groupId: _groupId,
        )
        .listen((transactions) {
          print(
            'AppProvider: Received ${transactions.length} transactions for groupId $_groupId',
          );
          _transactions = transactions;
          notifyListeners();
        });

    _inventorySubscription = _firestoreService
        .streamInventory(groupId: _groupId)
        .listen((inventory) {
          print('AppProvider: Received inventory for groupId $_groupId');
          _inventory = inventory;
          notifyListeners();
        });
  }

  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  void _setError(String error) {
    _error = error;
    notifyListeners();
  }

  void _clearError() {
    _error = null;
    notifyListeners();
  }

  // Sync pending transactions
  Future<void> syncNow() async {
    await _syncService.syncPendingTransactions();
    notifyListeners();
  }

  @override
  void dispose() {
    _cancelSubscriptions();
    super.dispose();
  }
}
