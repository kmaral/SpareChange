import 'package:flutter/material.dart';
import '../services/auth_service.dart';

class GroupSetupScreen extends StatefulWidget {
  const GroupSetupScreen({super.key});

  @override
  State<GroupSetupScreen> createState() => _GroupSetupScreenState();
}

class _GroupSetupScreenState extends State<GroupSetupScreen> {
  final _authService = AuthService();
  final _groupNameController = TextEditingController();
  final _groupIdController = TextEditingController();
  final _userNameController = TextEditingController();
  final _userEmailController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _groupNameController.dispose();
    _groupIdController.dispose();
    _userNameController.dispose();
    _userEmailController.dispose();
    super.dispose();
  }

  Future<void> _createGroup() async {
    if (_groupNameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a group name')),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      final groupId = await _authService.createGroup(
        _groupNameController.text.trim(),
      );
      if (groupId != null && mounted) {
        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Group created successfully!'),
            backgroundColor: Colors.green,
          ),
        );
        // Navigate to home screen by replacing the entire stack
        Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
      } else if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Failed to create group')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: ${e.toString()}')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _joinGroup() async {
    if (_groupIdController.text.trim().isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please enter a group ID')));
      return;
    }

    if (_userNameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please enter your name')));
      return;
    }

    if (_userEmailController.text.trim().isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please enter your email')));
      return;
    }

    setState(() => _isLoading = true);
    try {
      final success = await _authService.joinGroupWithUserInfo(
        _groupIdController.text.trim(),
        _userNameController.text.trim(),
        _userEmailController.text.trim(),
      );
      if (mounted) {
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Joined group successfully!'),
              backgroundColor: Colors.green,
            ),
          );
          // Navigate to home screen by replacing the entire stack
          Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Group not found or full (max 6 members)'),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: ${e.toString()}')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _exitAndSignOut() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Exit & Sign Out'),
        content: const Text(
          'Are you sure you want to exit? You will be signed out and any data will be cleared.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Sign Out'),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      // Sign out the user
      await _authService.signOut();

      if (mounted) {
        // Navigate back to the auth screen
        Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Setup Group'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _exitAndSignOut,
            tooltip: 'Sign Out & Exit',
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Icon(
              Icons.group,
              size: 80,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 24),
            Text(
              'Join or Create a Group',
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Groups can have up to 6 members to track shared savings',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[600]),
            ),
            const SizedBox(height: 32),

            // Create Group Section
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Create New Group',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _groupNameController,
                      decoration: const InputDecoration(
                        labelText: 'Group Name',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.label),
                        hintText: 'e.g., Family Savings',
                      ),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: _isLoading ? null : _createGroup,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.all(16),
                        backgroundColor: Theme.of(context).colorScheme.primary,
                        foregroundColor: Colors.white,
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Text('Create Group'),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Divider
            Row(
              children: [
                Expanded(child: Divider(color: Colors.grey[400])),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text('OR', style: TextStyle(color: Colors.grey[600])),
                ),
                Expanded(child: Divider(color: Colors.grey[400])),
              ],
            ),
            const SizedBox(height: 24),

            // Join Group Section
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Join Existing Group',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _userNameController,
                      decoration: const InputDecoration(
                        labelText: 'Your Name',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.person),
                        hintText: 'e.g., John Doe',
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _userEmailController,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(
                        labelText: 'Your Email',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.email),
                        hintText: 'e.g., john@example.com',
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _groupIdController,
                      decoration: const InputDecoration(
                        labelText: 'Group ID',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.vpn_key),
                        hintText: 'Enter group ID',
                      ),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: _isLoading ? null : _joinGroup,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.all(16),
                        backgroundColor: Theme.of(context).colorScheme.primary,
                        foregroundColor: Colors.white,
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Text('Join Group'),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 32),

            // Exit Option
            TextButton.icon(
              onPressed: _exitAndSignOut,
              icon: const Icon(Icons.exit_to_app, color: Colors.red),
              label: const Text(
                'I don\'t want to join a group - Sign Out',
                style: TextStyle(color: Colors.red),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
