import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import 'dart:convert';
import '../services/auth_service.dart';
import '../providers/app_provider.dart';
import 'group_setup_screen.dart';
import 'group_management_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _authService = AuthService();
  String _selectedTheme = 'System';
  String _selectedCurrency = 'INR (₹)';
  String _selectedDateFormat = 'DD/MM/YYYY';
  String _selectedNumberFormat = '1,234.56';
  Map<String, dynamic>? _groupData;
  bool _isAdmin = false;

  @override
  void initState() {
    super.initState();
    _loadGroupData();
  }

  Future<void> _loadGroupData() async {
    final group = await _authService.getUserGroup();
    final isAdmin = await _authService.isUserAdmin();
    if (mounted) {
      setState(() {
        _groupData = group;
        _isAdmin = isAdmin;
      });
    }
  }

  Future<void> _signOut() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sign Out'),
        content: const Text('Are you sure you want to sign out?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Sign Out'),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      await _authService.signOut();
      if (mounted) {
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    }
  }

  Future<void> _copyGroupId() async {
    if (_groupData?['id'] != null) {
      await Clipboard.setData(ClipboardData(text: _groupData!['id']));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Group ID copied to clipboard')),
        );
      }
    }
  }

  Future<void> _showGroupMembers() async {
    if (_groupData?['id'] == null) return;

    final members = await _authService.getGroupMembers(_groupData!['id']);
    if (!mounted) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Group Members (${members.length}/6)'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: members.length,
            itemBuilder: (context, index) {
              final member = members[index];
              return ListTile(
                leading: CircleAvatar(
                  backgroundImage: member['photoURL'] != null
                      ? NetworkImage(member['photoURL'])
                      : null,
                  child: member['photoURL'] == null
                      ? Text(member['displayName'][0].toUpperCase())
                      : null,
                ),
                title: Text(member['displayName'] ?? 'User'),
                subtitle: Text(member['email'] ?? ''),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteAllTransactions() async {
    if (!_isAdmin) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Only admin can delete all transactions')),
      );
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete All Transactions'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Are you sure you want to delete ALL transactions?',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red, width: 1),
              ),
              child: Row(
                children: [
                  const Icon(Icons.warning, color: Colors.red, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'This action cannot be undone! All transaction history and inventory will be reset.',
                      style: TextStyle(color: Colors.red[900], fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete All'),
          ),
        ],
      ),
    );

    if (confirm != true || !mounted) return;

    final provider = Provider.of<AppProvider>(context, listen: false);
    final success = await provider.deleteAllTransactions();

    if (mounted) {
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('All transactions deleted successfully'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(provider.error ?? 'Failed to delete transactions'),
          ),
        );
      }
    }
  }

  Future<void> _deleteAccount() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    // First confirmation dialog
    final confirmFirst = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Account?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Are you sure you want to delete your account?',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red, width: 1),
              ),
              child: Row(
                children: [
                  const Icon(Icons.warning, color: Colors.red, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'This action is permanent and cannot be undone!',
                      style: TextStyle(color: Colors.red[900], fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            const Text('The following data will be permanently deleted:'),
            const SizedBox(height: 8),
            const Text('• Your account information'),
            const Text('• All your transactions'),
            const Text('• Your family member entries'),
            const Text('• Your group membership'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Continue'),
          ),
        ],
      ),
    );

    if (confirmFirst != true || !mounted) return;

    // Second confirmation dialog - type DELETE
    final controller = TextEditingController();
    final confirmSecond = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Account Deletion'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'To confirm, please type DELETE below:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                hintText: 'Type DELETE',
              ),
              textCapitalization: TextCapitalization.characters,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              if (controller.text.trim().toUpperCase() == 'DELETE') {
                Navigator.pop(context, true);
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Please type DELETE to confirm'),
                  ),
                );
              }
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete Account'),
          ),
        ],
      ),
    );

    if (confirmSecond != true || !mounted) return;

    // Show loading dialog
    if (mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: Card(
            child: Padding(
              padding: EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Deleting account...'),
                ],
              ),
            ),
          ),
        ),
      );
    }

    // Perform account deletion
    final success = await _authService.deleteAccount();

    // Close loading dialog
    if (mounted) {
      Navigator.pop(context);
    }

    if (mounted) {
      if (success) {
        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Account deleted successfully'),
            backgroundColor: Colors.green,
          ),
        );

        // Navigate to auth screen after a delay
        await Future.delayed(const Duration(seconds: 1));
        if (mounted) {
          Navigator.of(context).popUntil((route) => route.isFirst);
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Failed to delete account. Please try again or contact support.',
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _exportUserData() async {
    // Show loading dialog
    if (mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: Card(
            child: Padding(
              padding: EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Exporting your data...'),
                ],
              ),
            ),
          ),
        ),
      );
    }

    // Export data
    final data = await _authService.exportUserData();

    // Close loading dialog
    if (mounted) {
      Navigator.pop(context);
    }

    if (data != null && mounted) {
      // Convert to JSON
      final jsonString = const JsonEncoder.withIndent('  ').convert(data);

      // Copy to clipboard
      await Clipboard.setData(ClipboardData(text: jsonString));

      // Show success dialog with data preview
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('✅ Data Exported'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Your data has been copied to the clipboard.',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                const Text('Summary:'),
                const SizedBox(height: 8),
                Text(
                  '• Transactions: ${data['statistics']?['totalTransactions'] ?? 0}',
                ),
                Text(
                  '• Family Members: ${data['statistics']?['totalFamilyMembers'] ?? 0}',
                ),
                Text('• Exported: ${data['exportedAt'] ?? 'Unknown'}'),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    'You can now paste this data into a text file for your records.',
                    style: TextStyle(fontSize: 13),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
          ],
        ),
      );
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to export data. Please try again.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _requestDataDeletion() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Request Data Deletion'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'This will submit a request to delete your data while keeping your account active.',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue, width: 1),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'What will be deleted:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 8),
                  Text('• Your transaction history'),
                  Text('• Your family member entries'),
                  Text('• Your group data'),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.green.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.green, width: 1),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'What will be kept:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 8),
                  Text('• Your account login'),
                  Text('• Your email address'),
                ],
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Note: Requests are processed within 30 days.',
              style: TextStyle(fontSize: 13, fontStyle: FontStyle.italic),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.orange),
            child: const Text('Submit Request'),
          ),
        ],
      ),
    );

    if (confirm != true || !mounted) return;

    // Show loading
    if (mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: Card(
            child: Padding(
              padding: EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Submitting request...'),
                ],
              ),
            ),
          ),
        ),
      );
    }

    // Submit request
    final success = await _authService.requestDataDeletion();

    // Close loading
    if (mounted) {
      Navigator.pop(context);
    }

    if (mounted) {
      if (success) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('✅ Request Submitted'),
            content: const Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Your data deletion request has been submitted successfully.',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 16),
                Text('What happens next:'),
                SizedBox(height: 8),
                Text('• We will process your request within 30 days'),
                Text('• You will receive a confirmation email'),
                Text('• Your data will be permanently deleted'),
                SizedBox(height: 16),
                Text(
                  'If you need immediate deletion, please use "Delete Account" instead.',
                  style: TextStyle(fontSize: 13, fontStyle: FontStyle.italic),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to submit request. Please try again.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: [
          // Account & Group Section (only if authenticated)
          if (user != null) ...[
            _SettingsSection(
              title: 'Account',
              icon: Icons.account_circle,
              children: [
                ListTile(
                  leading: CircleAvatar(
                    backgroundImage: user.photoURL != null
                        ? NetworkImage(user.photoURL!)
                        : null,
                    child: user.photoURL == null
                        ? Text(user.displayName?[0].toUpperCase() ?? 'U')
                        : null,
                  ),
                  title: Text(user.displayName ?? 'User'),
                  subtitle: Text(user.email ?? ''),
                ),
                if (_groupData != null) ...[
                  ListTile(
                    leading: const Icon(Icons.group),
                    title: const Text('Group'),
                    subtitle: Text(_groupData!['name'] ?? 'Unnamed Group'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: _showGroupMembers,
                  ),
                  ListTile(
                    leading: const Icon(Icons.admin_panel_settings),
                    title: const Text('Manage Group'),
                    subtitle: const Text('Edit name, manage members'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () async {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const GroupManagementScreen(),
                        ),
                      );
                      _loadGroupData();
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.vpn_key),
                    title: const Text('Group ID'),
                    subtitle: Text(_groupData!['id'] ?? ''),
                    trailing: IconButton(
                      icon: const Icon(Icons.copy),
                      onPressed: _copyGroupId,
                      tooltip: 'Copy Group ID',
                    ),
                  ),
                ] else ...[
                  ListTile(
                    leading: const Icon(Icons.group_add),
                    title: const Text('Join or Create Group'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () async {
                      final result = await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const GroupSetupScreen(),
                        ),
                      );
                      if (result == true) {
                        _loadGroupData();
                      }
                    },
                  ),
                ],
                ListTile(
                  leading: const Icon(Icons.logout),
                  title: const Text('Sign Out'),
                  onTap: _signOut,
                ),
              ],
            ),
            const Divider(),

            // Privacy & Data Section
            _SettingsSection(
              title: 'Privacy & Data',
              icon: Icons.privacy_tip,
              children: [
                ListTile(
                  leading: const Icon(Icons.download),
                  title: const Text('Export My Data'),
                  subtitle: const Text('Download a copy of your data'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: _exportUserData,
                ),
                ListTile(
                  leading: const Icon(
                    Icons.delete_outline,
                    color: Colors.orange,
                  ),
                  title: const Text(
                    'Request Data Deletion',
                    style: TextStyle(color: Colors.orange),
                  ),
                  subtitle: const Text('Delete data without deleting account'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: _requestDataDeletion,
                ),
                ListTile(
                  leading: const Icon(Icons.delete_forever, color: Colors.red),
                  title: const Text(
                    'Delete Account',
                    style: TextStyle(color: Colors.red),
                  ),
                  subtitle: const Text(
                    'Permanently delete account and all data',
                  ),
                  onTap: _deleteAccount,
                ),
              ],
            ),
            const Divider(),
          ],

          // Admin Controls Section (only for admin)
          if (_isAdmin) ...[
            _SettingsSection(
              title: 'Admin Controls',
              icon: Icons.admin_panel_settings,
              children: [
                ListTile(
                  leading: const Icon(Icons.delete_forever, color: Colors.red),
                  title: const Text('Delete All Transactions'),
                  subtitle: const Text('Permanently delete all transactions'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: _deleteAllTransactions,
                ),
              ],
            ),
            const Divider(),
          ],

          // Theme Settings
          _SettingsSection(
            title: 'Appearance',
            icon: Icons.palette,
            children: [
              ListTile(
                leading: const Icon(Icons.brightness_6),
                title: const Text('Theme'),
                subtitle: Text(_selectedTheme),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _showThemeDialog(),
              ),
            ],
          ),
          const Divider(),

          // Currency Settings
          _SettingsSection(
            title: 'Regional',
            icon: Icons.language,
            children: [
              ListTile(
                leading: const Icon(Icons.currency_rupee),
                title: const Text('Currency'),
                subtitle: Text(_selectedCurrency),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _showCurrencyDialog(),
              ),
              ListTile(
                leading: const Icon(Icons.calendar_today),
                title: const Text('Date Format'),
                subtitle: Text(_selectedDateFormat),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _showDateFormatDialog(),
              ),
              ListTile(
                leading: const Icon(Icons.numbers),
                title: const Text('Number Format'),
                subtitle: Text(_selectedNumberFormat),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _showNumberFormatDialog(),
              ),
            ],
          ),
          const Divider(),

          // App Info
          _SettingsSection(
            title: 'About',
            icon: Icons.info,
            children: [
              ListTile(
                leading: const Icon(Icons.app_settings_alt),
                title: const Text('App Version'),
                subtitle: const Text('1.0.0'),
              ),
              ListTile(
                leading: const Icon(Icons.code),
                title: const Text('Build Number'),
                subtitle: const Text('1'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showThemeDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Select Theme'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            RadioListTile<String>(
              title: const Text('Light'),
              value: 'Light',
              groupValue: _selectedTheme,
              onChanged: (value) {
                setState(() => _selectedTheme = value!);
                Navigator.pop(context);
              },
            ),
            RadioListTile<String>(
              title: const Text('Dark'),
              value: 'Dark',
              groupValue: _selectedTheme,
              onChanged: (value) {
                setState(() => _selectedTheme = value!);
                Navigator.pop(context);
              },
            ),
            RadioListTile<String>(
              title: const Text('System'),
              value: 'System',
              groupValue: _selectedTheme,
              onChanged: (value) {
                setState(() => _selectedTheme = value!);
                Navigator.pop(context);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showCurrencyDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Select Currency'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            RadioListTile<String>(
              title: const Text('INR (₹)'),
              value: 'INR (₹)',
              groupValue: _selectedCurrency,
              onChanged: (value) {
                setState(() => _selectedCurrency = value!);
                Navigator.pop(context);
              },
            ),
            RadioListTile<String>(
              title: const Text('USD (\$)'),
              value: 'USD (\$)',
              groupValue: _selectedCurrency,
              onChanged: (value) {
                setState(() => _selectedCurrency = value!);
                Navigator.pop(context);
              },
            ),
            RadioListTile<String>(
              title: const Text('EUR (€)'),
              value: 'EUR (€)',
              groupValue: _selectedCurrency,
              onChanged: (value) {
                setState(() => _selectedCurrency = value!);
                Navigator.pop(context);
              },
            ),
            RadioListTile<String>(
              title: const Text('GBP (£)'),
              value: 'GBP (£)',
              groupValue: _selectedCurrency,
              onChanged: (value) {
                setState(() => _selectedCurrency = value!);
                Navigator.pop(context);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showDateFormatDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Select Date Format'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            RadioListTile<String>(
              title: const Text('DD/MM/YYYY'),
              subtitle: const Text('31/12/2026'),
              value: 'DD/MM/YYYY',
              groupValue: _selectedDateFormat,
              onChanged: (value) {
                setState(() => _selectedDateFormat = value!);
                Navigator.pop(context);
              },
            ),
            RadioListTile<String>(
              title: const Text('MM/DD/YYYY'),
              subtitle: const Text('12/31/2026'),
              value: 'MM/DD/YYYY',
              groupValue: _selectedDateFormat,
              onChanged: (value) {
                setState(() => _selectedDateFormat = value!);
                Navigator.pop(context);
              },
            ),
            RadioListTile<String>(
              title: const Text('YYYY-MM-DD'),
              subtitle: const Text('2026-12-31'),
              value: 'YYYY-MM-DD',
              groupValue: _selectedDateFormat,
              onChanged: (value) {
                setState(() => _selectedDateFormat = value!);
                Navigator.pop(context);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showNumberFormatDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Select Number Format'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            RadioListTile<String>(
              title: const Text('1,234.56'),
              subtitle: const Text('Comma separator, dot decimal'),
              value: '1,234.56',
              groupValue: _selectedNumberFormat,
              onChanged: (value) {
                setState(() => _selectedNumberFormat = value!);
                Navigator.pop(context);
              },
            ),
            RadioListTile<String>(
              title: const Text('1.234,56'),
              subtitle: const Text('Dot separator, comma decimal'),
              value: '1.234,56',
              groupValue: _selectedNumberFormat,
              onChanged: (value) {
                setState(() => _selectedNumberFormat = value!);
                Navigator.pop(context);
              },
            ),
            RadioListTile<String>(
              title: const Text('1 234.56'),
              subtitle: const Text('Space separator, dot decimal'),
              value: '1 234.56',
              groupValue: _selectedNumberFormat,
              onChanged: (value) {
                setState(() => _selectedNumberFormat = value!);
                Navigator.pop(context);
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _SettingsSection extends StatelessWidget {
  final String title;
  final IconData icon;
  final List<Widget> children;

  const _SettingsSection({
    required this.title,
    required this.icon,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Row(
            children: [
              Icon(
                icon,
                size: 20,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
            ],
          ),
        ),
        ...children,
      ],
    );
  }
}
