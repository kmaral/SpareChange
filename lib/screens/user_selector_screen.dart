import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import '../models/user.dart';

class UserSelectorScreen extends StatelessWidget {
  const UserSelectorScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset('assests/sparechange.png', height: 32),
            const SizedBox(width: 8),
            const Text('Select User'),
          ],
        ),
      ),
      body: Consumer<AppProvider>(
        builder: (context, provider, child) {
          final users = provider.users;

          if (users.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.person_add, size: 64, color: Colors.grey),
                  const SizedBox(height: 16),
                  const Text(
                    'No users yet',
                    style: TextStyle(fontSize: 18, color: Colors.grey),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    onPressed: () => _showAddUserDialog(context, provider),
                    icon: const Icon(Icons.add),
                    label: const Text('Add First User'),
                  ),
                ],
              ),
            );
          }

          return GridView.builder(
            padding: const EdgeInsets.all(16),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              childAspectRatio: 1.0,
            ),
            itemCount: users.length,
            itemBuilder: (context, index) {
              final user = users[index];
              final isSelected = provider.selectedUser?.id == user.id;

              return Card(
                elevation: isSelected ? 8 : 2,
                color: isSelected
                    ? Theme.of(context).colorScheme.primaryContainer
                    : null,
                child: InkWell(
                  onTap: () {
                    provider.setSelectedUser(user);
                    Navigator.pop(context);
                  },
                  onLongPress: () {
                    _showUserOptions(context, provider, user);
                  },
                  child: Stack(
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            CircleAvatar(
                              radius: 32,
                              backgroundColor: Color(
                                int.parse(
                                  user.avatarColor.replaceFirst('#', '0xFF'),
                                ),
                              ),
                              child: Text(
                                user.initials,
                                style: const TextStyle(
                                  fontSize: 24,
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              user.name,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                              textAlign: TextAlign.center,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            if (isSelected)
                              const Padding(
                                padding: EdgeInsets.only(top: 8),
                                child: Icon(
                                  Icons.check_circle,
                                  color: Colors.green,
                                ),
                              ),
                          ],
                        ),
                      ),
                      Positioned(
                        top: 4,
                        right: 4,
                        child: IconButton(
                          icon: const Icon(Icons.more_vert, size: 20),
                          onPressed: () {
                            _showUserOptions(context, provider, user);
                          },
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: FloatingActionButton.extended(
          onPressed: () => _showAddUserDialog(
            context,
            Provider.of<AppProvider>(context, listen: false),
          ),
          icon: const Icon(Icons.person_add),
          label: const Text('Add User'),
          elevation: 4,
        ),
      ),
    );
  }

  void _showAddUserDialog(BuildContext context, AppProvider provider) {
    showDialog(
      context: context,
      builder: (context) => _AddUserDialog(provider: provider),
    );
  }

  void _showUserOptions(BuildContext context, AppProvider provider, User user) {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit),
              title: const Text('Edit User'),
              onTap: () {
                Navigator.pop(context);
                _showEditUserDialog(context, provider, user);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete, color: Colors.red),
              title: const Text(
                'Delete User',
                style: TextStyle(color: Colors.red),
              ),
              onTap: () {
                Navigator.pop(context);
                _confirmDeleteUser(context, provider, user);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showEditUserDialog(
    BuildContext context,
    AppProvider provider,
    User user,
  ) {
    showDialog(
      context: context,
      builder: (context) => _EditUserDialog(provider: provider, user: user),
    );
  }

  void _confirmDeleteUser(
    BuildContext context,
    AppProvider provider,
    User user,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete User'),
        content: Text('Are you sure you want to delete ${user.name}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              await provider.deleteUser(user.id);
              if (context.mounted) {
                Navigator.pop(context);
                if (provider.error != null) {
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(SnackBar(content: Text(provider.error!)));
                }
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}

class _EditUserDialog extends StatefulWidget {
  final AppProvider provider;
  final User user;

  const _EditUserDialog({required this.provider, required this.user});

  @override
  State<_EditUserDialog> createState() => _EditUserDialogState();
}

class _EditUserDialogState extends State<_EditUserDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;

  final List<int> _colors = [
    0xFFE91E63, // Pink
    0xFF9C27B0, // Purple
    0xFF673AB7, // Deep Purple
    0xFF3F51B5, // Indigo
    0xFF2196F3, // Blue
    0xFF00BCD4, // Cyan
    0xFF009688, // Teal
    0xFF4CAF50, // Green
    0xFF8BC34A, // Light Green
    0xFFFF9800, // Orange
    0xFFFF5722, // Deep Orange
    0xFF795548, // Brown
  ];

  late int _selectedColor;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.user.name);
    _selectedColor = int.parse(
      widget.user.avatarColor.replaceFirst('#', '0xFF'),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Edit User'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Name',
                  hintText: 'Enter user name',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter a name';
                  }
                  return null;
                },
                autofocus: true,
              ),
              const SizedBox(height: 24),
              const Text('Select Color:'),
              const SizedBox(height: 12),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: _colors.map((color) {
                  final isSelected = color == _selectedColor;
                  return InkWell(
                    onTap: () {
                      setState(() {
                        _selectedColor = color;
                      });
                    },
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: Color(color),
                        shape: BoxShape.circle,
                        border: isSelected
                            ? Border.all(color: Colors.black, width: 3)
                            : null,
                      ),
                      child: isSelected
                          ? const Icon(Icons.check, color: Colors.white)
                          : null,
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () async {
            if (_formKey.currentState!.validate()) {
              final updatedUser = User(
                id: widget.user.id,
                name: _nameController.text.trim(),
                avatarColor:
                    '#${_selectedColor.toRadixString(16).substring(2).toUpperCase()}',
              );

              await widget.provider.updateUser(updatedUser);

              if (context.mounted) {
                Navigator.pop(context);
              }
            }
          },
          child: const Text('Update'),
        ),
      ],
    );
  }
}

class _AddUserDialog extends StatefulWidget {
  final AppProvider provider;

  const _AddUserDialog({required this.provider});

  @override
  State<_AddUserDialog> createState() => _AddUserDialogState();
}

class _AddUserDialogState extends State<_AddUserDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();

  final List<int> _colors = [
    0xFFE91E63, // Pink
    0xFF9C27B0, // Purple
    0xFF673AB7, // Deep Purple
    0xFF3F51B5, // Indigo
    0xFF2196F3, // Blue
    0xFF00BCD4, // Cyan
    0xFF009688, // Teal
    0xFF4CAF50, // Green
    0xFF8BC34A, // Light Green
    0xFFFF9800, // Orange
    0xFFFF5722, // Deep Orange
    0xFF795548, // Brown
  ];

  int _selectedColor = 0xFFE91E63;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add New User'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Name',
                  hintText: 'Enter user name',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter a name';
                  }
                  return null;
                },
                autofocus: true,
              ),
              const SizedBox(height: 24),
              const Text('Select Color:'),
              const SizedBox(height: 12),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: _colors.map((color) {
                  final isSelected = color == _selectedColor;
                  return InkWell(
                    onTap: () {
                      setState(() {
                        _selectedColor = color;
                      });
                    },
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: Color(color),
                        shape: BoxShape.circle,
                        border: isSelected
                            ? Border.all(color: Colors.black, width: 3)
                            : null,
                      ),
                      child: isSelected
                          ? const Icon(Icons.check, color: Colors.white)
                          : null,
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () async {
            if (_formKey.currentState!.validate()) {
              final newUser = await widget.provider.addUser(
                _nameController.text.trim(),
                '0x${_selectedColor.toRadixString(16).toUpperCase()}',
              );

              if (context.mounted && newUser != null) {
                // Auto-select the newly added user
                widget.provider.setSelectedUser(newUser);
                Navigator.pop(context);
              }
            }
          },
          child: const Text('Add'),
        ),
      ],
    );
  }
}
