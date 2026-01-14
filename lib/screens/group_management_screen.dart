import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/auth_service.dart';

class GroupManagementScreen extends StatefulWidget {
  const GroupManagementScreen({super.key});

  @override
  State<GroupManagementScreen> createState() => _GroupManagementScreenState();
}

class _GroupManagementScreenState extends State<GroupManagementScreen> {
  final _authService = AuthService();
  final _groupNameController = TextEditingController();
  Map<String, dynamic>? _groupData;
  List<Map<String, dynamic>> _members = [];
  bool _isLoading = true;
  bool _isAdmin = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _groupNameController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final group = await _authService.getUserGroup();
      final isAdmin = await _authService.isUserAdmin();

      if (group != null) {
        final members = await _authService.getGroupMembers(group['id']);
        if (mounted) {
          setState(() {
            _groupData = group;
            _isAdmin = isAdmin;
            _members = members;
            _groupNameController.text = group['name'] ?? '';
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading data: ${e.toString()}')),
        );
      }
    }
  }

  Future<void> _updateGroupName() async {
    if (!_isAdmin) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Only admin can change group name')),
      );
      return;
    }

    if (_groupNameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Group name cannot be empty')),
      );
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Update Group Name'),
        content: Text(
          'Change group name to "${_groupNameController.text.trim()}"?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Update'),
          ),
        ],
      ),
    );

    if (confirm != true || !mounted) return;

    try {
      final success = await _authService.updateGroupName(
        _groupData!['id'],
        _groupNameController.text.trim(),
      );

      if (mounted) {
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Group name updated successfully'),
              backgroundColor: Colors.green,
            ),
          );
          _loadData();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to update group name')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: ${e.toString()}')));
      }
    }
  }

  Future<void> _removeMember(Map<String, dynamic> member) async {
    if (!_isAdmin) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Only admin can remove members')),
      );
      return;
    }

    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser?.uid == member['uid']) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Admin cannot remove themselves')),
      );
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove Member'),
        content: Text(
          'Are you sure you want to remove ${member['displayName']} from the group?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Remove'),
          ),
        ],
      ),
    );

    if (confirm != true || !mounted) return;

    try {
      final success = await _authService.removeMemberFromGroup(
        _groupData!['id'],
        member['uid'],
      );

      if (mounted) {
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${member['displayName']} removed from group'),
              backgroundColor: Colors.green,
            ),
          );
          _loadData();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to remove member')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: ${e.toString()}')));
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

  Future<void> _transferAdmin(Map<String, dynamic> member) async {
    if (!_isAdmin) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Only admin can transfer admin role')),
      );
      return;
    }

    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser?.uid == member['uid']) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You are already the admin')),
      );
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Transfer Admin Role'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Transfer admin role to ${member['displayName']}?',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange, width: 1),
              ),
              child: Row(
                children: [
                  const Icon(Icons.warning, color: Colors.orange, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'You will no longer be the admin and cannot undo this action.',
                      style: TextStyle(color: Colors.orange[900], fontSize: 13),
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
            style: TextButton.styleFrom(foregroundColor: Colors.orange),
            child: const Text('Transfer'),
          ),
        ],
      ),
    );

    if (confirm != true || !mounted) return;

    try {
      final success = await _authService.transferAdminRole(
        _groupData!['id'],
        member['uid'],
      );

      if (mounted) {
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Admin role transferred to ${member['displayName']}',
              ),
              backgroundColor: Colors.green,
            ),
          );
          _loadData();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to transfer admin role')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: ${e.toString()}')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Group Management'),
        actions: [
          if (_isAdmin)
            IconButton(
              icon: const Icon(Icons.save),
              onPressed: _updateGroupName,
              tooltip: 'Save Changes',
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _groupData == null
          ? const Center(child: Text('No group found'))
          : SingleChildScrollView(
              child: Column(
                children: [
                  // Admin Badge
                  if (_isAdmin)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      margin: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.amber.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.amber, width: 2),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.admin_panel_settings,
                            color: Colors.amber,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'You are the Admin',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.amber[900],
                            ),
                          ),
                        ],
                      ),
                    ),

                  // Group Name Section
                  Card(
                    margin: const EdgeInsets.all(16),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.group, color: Colors.blue),
                              const SizedBox(width: 8),
                              Text(
                                'Group Name',
                                style: Theme.of(context).textTheme.titleLarge
                                    ?.copyWith(fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          TextField(
                            controller: _groupNameController,
                            enabled: _isAdmin,
                            decoration: InputDecoration(
                              labelText: 'Group Name',
                              border: const OutlineInputBorder(),
                              prefixIcon: const Icon(Icons.edit),
                              suffixIcon: _isAdmin
                                  ? IconButton(
                                      icon: const Icon(Icons.check),
                                      onPressed: _updateGroupName,
                                      tooltip: 'Update Name',
                                    )
                                  : null,
                            ),
                          ),
                          if (!_isAdmin)
                            const Padding(
                              padding: EdgeInsets.only(top: 8),
                              child: Text(
                                'Only admin can change group name',
                                style: TextStyle(
                                  color: Colors.grey,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),

                  // Group ID Section
                  Card(
                    margin: const EdgeInsets.symmetric(horizontal: 16),
                    child: ListTile(
                      leading: const Icon(Icons.vpn_key, color: Colors.orange),
                      title: const Text('Group ID'),
                      subtitle: Text(_groupData!['id'] ?? ''),
                      trailing: IconButton(
                        icon: const Icon(Icons.copy),
                        onPressed: _copyGroupId,
                        tooltip: 'Copy Group ID',
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Members Section
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Members (${_members.length}/6)',
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        if (_isAdmin)
                          const Chip(
                            avatar: Icon(Icons.security, size: 16),
                            label: Text('Admin Controls'),
                            backgroundColor: Colors.amber,
                          ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 8),

                  // Members List
                  ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _members.length,
                    itemBuilder: (context, index) {
                      final member = _members[index];
                      final currentUser = FirebaseAuth.instance.currentUser;
                      final isCurrentUser = currentUser?.uid == member['uid'];
                      final isMemberAdmin =
                          _groupData!['adminId'] == member['uid'];

                      return Card(
                        margin: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 4,
                        ),
                        child: ListTile(
                          leading: Stack(
                            children: [
                              CircleAvatar(
                                backgroundImage: member['photoURL'] != null
                                    ? NetworkImage(member['photoURL'])
                                    : null,
                                child: member['photoURL'] == null
                                    ? Text(
                                        member['displayName']?[0]
                                                .toUpperCase() ??
                                            'U',
                                      )
                                    : null,
                              ),
                              if (isMemberAdmin)
                                Positioned(
                                  right: 0,
                                  bottom: 0,
                                  child: Container(
                                    padding: const EdgeInsets.all(2),
                                    decoration: const BoxDecoration(
                                      color: Colors.amber,
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(
                                      Icons.star,
                                      size: 12,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          title: Row(
                            children: [
                              Text(member['displayName'] ?? 'User'),
                              if (isMemberAdmin) ...[
                                const SizedBox(width: 8),
                                const Chip(
                                  label: Text(
                                    'Admin',
                                    style: TextStyle(fontSize: 10),
                                  ),
                                  backgroundColor: Colors.amber,
                                  padding: EdgeInsets.symmetric(horizontal: 4),
                                ),
                              ],
                              if (isCurrentUser) ...[
                                const SizedBox(width: 8),
                                const Chip(
                                  label: Text(
                                    'You',
                                    style: TextStyle(fontSize: 10),
                                  ),
                                  backgroundColor: Colors.blue,
                                  padding: EdgeInsets.symmetric(horizontal: 4),
                                ),
                              ],
                            ],
                          ),
                          subtitle: Text(member['email'] ?? ''),
                          trailing: _isAdmin && !isMemberAdmin && !isCurrentUser
                              ? Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      icon: const Icon(
                                        Icons.admin_panel_settings,
                                        color: Colors.amber,
                                      ),
                                      onPressed: () => _transferAdmin(member),
                                      tooltip: 'Make Admin',
                                    ),
                                    IconButton(
                                      icon: const Icon(
                                        Icons.remove_circle,
                                        color: Colors.red,
                                      ),
                                      onPressed: () => _removeMember(member),
                                      tooltip: 'Remove Member',
                                    ),
                                  ],
                                )
                              : null,
                        ),
                      );
                    },
                  ),

                  const SizedBox(height: 24),

                  // Info Section
                  if (!_isAdmin)
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.blue.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.blue, width: 1),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.info_outline, color: Colors.blue),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'Only the group admin can manage members and change the group name.',
                                style: TextStyle(
                                  color: Colors.blue[900],
                                  fontSize: 14,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
    );
  }
}
