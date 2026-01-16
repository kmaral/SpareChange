import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import '../models/transaction.dart';
import '../widgets/denomination_chart.dart';
import '../widgets/ad_banner_widget.dart';
import '../services/auth_service.dart';
import 'denomination_settings_screen.dart';
import 'add_transaction_screen.dart';
import 'transactions_screen.dart';
import 'settings_screen.dart';
import 'auth_screen.dart';
import 'group_setup_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _authService = AuthService();
  bool _isAdmin = false;

  @override
  void initState() {
    super.initState();
    // Initialize default user if needed
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final provider = Provider.of<AppProvider>(context, listen: false);

        // Check admin status
        final isAdmin = await _authService.isUserAdmin();
        if (mounted) {
          setState(() => _isAdmin = isAdmin);
        }

        // Wait a bit for streams to load
        await Future.delayed(const Duration(milliseconds: 500));

        // Recalculate inventory to ensure it's in sync with transactions
        if (provider.isOnline && mounted) {
          await provider.recalculateInventory();
        }

        // Create a user entry if none exists for this authenticated user
        if (provider.users.isEmpty && mounted) {
          final displayName =
              user.displayName ?? user.email?.split('@').first ?? 'User';
          final newUser = await provider.addUser(
            displayName,
            '#4CAF50',
          ); // Green color

          // Auto-select the newly created user
          if (newUser != null && mounted) {
            provider.setSelectedUser(newUser);
          }
        } else if (provider.selectedUser == null &&
            provider.users.isNotEmpty &&
            mounted) {
          // Auto-select first user if none selected
          provider.setSelectedUser(provider.users.first);
        }
      }
    });
  }

  Future<void> _showAuthPrompt() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const AuthScreen()),
    );

    // After authentication, check if user needs to setup group
    final user = FirebaseAuth.instance.currentUser;
    if (user != null && mounted) {
      final group = await _authService.getUserGroup();
      if (group == null && mounted) {
        final result = await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) {
              final Widget screen = GroupSetupScreen();
              return screen;
            },
          ),
        );
        if (result == true && mounted) {
          setState(() {}); // Refresh the screen
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    // Show empty dashboard if not authenticated
    if (user == null) {
      return Scaffold(
        appBar: AppBar(
          title: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Image.asset('assests/sparechange.png', height: 32),
              const SizedBox(width: 8),
              const Text('Spare Change'),
            ],
          ),
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.account_balance_wallet,
                size: 100,
                color: Colors.grey[400],
              ),
              const SizedBox(height: 24),
              Text(
                'Welcome to Spare Change',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Start tracking your currency denominations',
                style: TextStyle(color: Colors.grey[600]),
              ),
              const SizedBox(height: 32),
              ElevatedButton.icon(
                onPressed: _showAuthPrompt,
                icon: const Icon(Icons.add),
                label: const Text('Add Transaction'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 32,
                    vertical: 16,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Consumer<AppProvider>(
      builder: (context, provider, child) {
        return Scaffold(
          appBar: AppBar(
            title: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Image.asset('assests/sparechange.png', height: 32),
                const SizedBox(width: 8),
                const Text('Spare Change'),
              ],
            ),
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

              // Settings button
              IconButton(
                icon: const Icon(Icons.settings),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const SettingsScreen(),
                    ),
                  );
                },
              ),
            ],
          ),
          body: SingleChildScrollView(
            child: Column(
              children: [
                // Balance summary card
                _BalanceSummaryCard(),

                // Denomination breakdown chart
                _DenominationBreakdown(),

                const SizedBox(height: 8),

                // Quick Actions
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Column(
                    children: [
                      // Transactions button
                      Card(
                        child: InkWell(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) =>
                                    const TransactionsScreen(),
                              ),
                            );
                          },
                          borderRadius: BorderRadius.circular(12),
                          child: Padding(
                            padding: const EdgeInsets.all(20.0),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: Theme.of(context).colorScheme.primary
                                        .withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Icon(
                                    Icons.receipt_long,
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.primary,
                                    size: 28,
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'View All Transactions',
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleMedium
                                            ?.copyWith(
                                              fontWeight: FontWeight.bold,
                                            ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        '${provider.transactions.length} transactions',
                                        style: TextStyle(
                                          color: Colors.grey[600],
                                          fontSize: 14,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Icon(
                                  Icons.chevron_right,
                                  color: Colors.grey[400],
                                  size: 32,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      // Manage Denominations button (Admin only)
                      if (_isAdmin)
                        Card(
                          child: InkWell(
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) =>
                                      const DenominationSettingsScreen(),
                                ),
                              );
                            },
                            borderRadius: BorderRadius.circular(12),
                            child: Padding(
                              padding: const EdgeInsets.all(20.0),
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: Colors.orange.withValues(
                                        alpha: 0.1,
                                      ),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: const Icon(
                                      Icons.payments,
                                      color: Colors.orange,
                                      size: 28,
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Manage Denominations',
                                          style: Theme.of(context)
                                              .textTheme
                                              .titleMedium
                                              ?.copyWith(
                                                fontWeight: FontWeight.bold,
                                              ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          'Add or edit notes & coins',
                                          style: TextStyle(
                                            color: Colors.grey[600],
                                            fontSize: 14,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Icon(
                                    Icons.chevron_right,
                                    color: Colors.grey[400],
                                    size: 32,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),

                // AdMob Banner
                const Padding(
                  padding: EdgeInsets.all(16.0),
                  child: AdBannerWidget(),
                ),

                const SizedBox(height: 16),
              ],
            ),
          ),
          floatingActionButton: provider.selectedUser == null
              ? null
              : Padding(
                  padding: const EdgeInsets.only(bottom: 80),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      // Add money FAB
                      FloatingActionButton.extended(
                        heroTag: 'add',
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => AddTransactionScreen(
                                transactionType: TransactionType.added,
                              ),
                            ),
                          );
                        },
                        backgroundColor: Colors.green,
                        icon: const Icon(Icons.add),
                        label: const Text('Add'),
                        elevation: 4,
                      ),
                      const SizedBox(height: 12),
                      // Take money FAB
                      FloatingActionButton.extended(
                        heroTag: 'take',
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => AddTransactionScreen(
                                transactionType: TransactionType.taken,
                              ),
                            ),
                          );
                        },
                        backgroundColor: Colors.red,
                        icon: const Icon(Icons.remove),
                        label: const Text('Take'),
                        elevation: 4,
                      ),
                    ],
                  ),
                ),
        );
      },
    );
  }
}

class _BalanceSummaryCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Consumer<AppProvider>(
      builder: (context, provider, child) {
        final totalBalance = provider.getTotalBalance();

        return Card(
          margin: const EdgeInsets.all(16),
          elevation: 4,
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Theme.of(context).colorScheme.primaryContainer,
                  Theme.of(context).colorScheme.secondaryContainer,
                ],
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.account_balance_wallet,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Total Balance',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w500,
                          color: Theme.of(
                            context,
                          ).colorScheme.onPrimaryContainer,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    '₹${totalBalance.toStringAsFixed(2)}',
                    style: TextStyle(
                      fontSize: 42,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.5,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _DenominationBreakdown extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Consumer<AppProvider>(
      builder: (context, provider, child) {
        final breakdown = provider.getDenominationBreakdown();
        return DenominationChart(breakdown: breakdown);
      },
    );
  }
}
