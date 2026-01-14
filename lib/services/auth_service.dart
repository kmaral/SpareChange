import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'encryption_service.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Get current user
  User? get currentUser => _auth.currentUser;

  // Auth state stream
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // Sign in with Google
  Future<UserCredential?> signInWithGoogle() async {
    try {
      // Trigger Google Sign In flow
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) return null;

      // Obtain auth details
      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;

      // Create credential
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      // Sign in to Firebase
      final userCredential = await _auth.signInWithCredential(credential);

      // Create user document in Firestore
      if (userCredential.user != null) {
        await _createUserDocument(userCredential.user!);
      }

      return userCredential;
    } catch (e) {
      print('Error signing in with Google: $e');
      return null;
    }
  }

  // Sign in with email/password
  Future<UserCredential?> signInWithEmail(String email, String password) async {
    try {
      final userCredential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      if (userCredential.user != null) {
        await _createUserDocument(userCredential.user!);
      }

      return userCredential;
    } catch (e) {
      print('Error signing in with email: $e');
      rethrow;
    }
  }

  // Sign up with email/password
  Future<UserCredential?> signUpWithEmail(
    String email,
    String password,
    String displayName,
  ) async {
    try {
      final userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      // Update display name
      await userCredential.user?.updateDisplayName(displayName);

      if (userCredential.user != null) {
        await _createUserDocument(userCredential.user!);
      }

      return userCredential;
    } catch (e) {
      print('Error signing up with email: $e');
      rethrow;
    }
  }

  // Create user document in Firestore
  Future<void> _createUserDocument(User user) async {
    final encryption = EncryptionService();
    final userDoc = _firestore.collection('users').doc(user.uid);
    final docSnapshot = await userDoc.get();

    if (!docSnapshot.exists) {
      await userDoc.set({
        'uid': user.uid,
        'email': encryption.encrypt(user.email ?? ''),
        'displayName': encryption.encrypt(user.displayName ?? 'User'),
        'photoURL': user.photoURL,
        'createdAt': FieldValue.serverTimestamp(),
        'groupId': null, // Will be assigned when user creates/joins a group
      });
    }
  }

  // Sign out
  Future<void> signOut() async {
    await _googleSignIn.signOut();
    await _auth.signOut();
  }

  // Delete user account and all associated data
  Future<bool> deleteAccount() async {
    try {
      final user = currentUser;
      if (user == null) return false;

      // Get user's group to remove them from it
      final userDoc = await _firestore.collection('users').doc(user.uid).get();
      if (userDoc.exists) {
        final groupId = userDoc.data()?['groupId'];

        if (groupId != null) {
          // Remove user from group members list
          final groupDoc = await _firestore
              .collection('groups')
              .doc(groupId)
              .get();
          if (groupDoc.exists) {
            final members = List<String>.from(
              groupDoc.data()?['members'] ?? [],
            );
            members.remove(user.uid);

            await _firestore.collection('groups').doc(groupId).update({
              'members': members,
            });
          }
        }
      }

      // Delete all user's family member entries (encrypted user names)
      final familyMembersQuery = await _firestore
          .collection('family_members')
          .where('id', isEqualTo: user.uid)
          .get();

      for (var doc in familyMembersQuery.docs) {
        await doc.reference.delete();
      }

      // Delete all user's transactions
      final transactionsQuery = await _firestore
          .collection('transactions')
          .where('userId', isEqualTo: user.uid)
          .get();

      for (var doc in transactionsQuery.docs) {
        await doc.reference.delete();
      }

      // Delete user's Firestore document
      await _firestore.collection('users').doc(user.uid).delete();

      // Delete Firebase Auth account
      await user.delete();

      // Sign out
      await _googleSignIn.signOut();

      return true;
    } catch (e) {
      print('Error deleting account: $e');
      return false;
    }
  }

  // Request data deletion without deleting account (marks for deletion)
  Future<bool> requestDataDeletion({String? reason}) async {
    try {
      final user = currentUser;
      if (user == null) return false;

      // Create a data deletion request in Firestore
      await _firestore.collection('data_deletion_requests').add({
        'userId': user.uid,
        'email': user.email,
        'displayName': user.displayName,
        'requestType': 'delete_data',
        'reason': reason ?? '',
        'status': 'pending',
        'requestedAt': FieldValue.serverTimestamp(),
      });

      return true;
    } catch (e) {
      print('Error requesting data deletion: $e');
      return false;
    }
  }

  // Export user data
  Future<Map<String, dynamic>?> exportUserData() async {
    try {
      final encryption = EncryptionService();
      final user = currentUser;
      if (user == null) return null;

      // Get user data
      final userDoc = await _firestore.collection('users').doc(user.uid).get();
      final userData = userDoc.exists ? userDoc.data() : {};

      // Get user's transactions
      final transactionsQuery = await _firestore
          .collection('transactions')
          .where('userId', isEqualTo: user.uid)
          .orderBy('timestamp', descending: true)
          .get();

      final transactions = transactionsQuery.docs
          .map((doc) => doc.data())
          .toList();

      // Get user's family members
      final familyMembersQuery = await _firestore
          .collection('family_members')
          .where('id', isEqualTo: user.uid)
          .get();

      final familyMembers = familyMembersQuery.docs
          .map((doc) => doc.data())
          .toList();

      // Get group data
      Map<String, dynamic>? groupData;
      if (userData?['groupId'] != null) {
        final groupDoc = await _firestore
            .collection('groups')
            .doc(userData!['groupId'])
            .get();
        if (groupDoc.exists) {
          groupData = groupDoc.data();
          // Decrypt group name
          if (groupData?['name'] != null) {
            groupData!['name'] = encryption.decrypt(groupData['name']);
          }
        }
      }

      return {
        'exportedAt': DateTime.now().toIso8601String(),
        'user': {
          'uid': user.uid,
          'email': user.email,
          'displayName': user.displayName,
          'photoURL': user.photoURL,
          'createdAt': userData?['createdAt']?.toDate()?.toIso8601String(),
        },
        'transactions': transactions,
        'familyMembers': familyMembers,
        'group': groupData,
        'statistics': {
          'totalTransactions': transactions.length,
          'totalFamilyMembers': familyMembers.length,
        },
      };
    } catch (e) {
      print('Error exporting user data: $e');
      return null;
    }
  }

  // Create a new group
  Future<String?> createGroup(String groupName) async {
    try {
      final encryption = EncryptionService();
      final user = currentUser;
      if (user == null) return null;

      final groupDoc = await _firestore.collection('groups').add({
        'name': encryption.encrypt(groupName),
        'createdBy': user.uid,
        'adminId': user.uid, // Set creator as admin
        'createdAt': FieldValue.serverTimestamp(),
        'members': [user.uid],
        'maxMembers': 6,
      });

      // Update user's groupId (use set with merge to create if doesn't exist)
      await _firestore.collection('users').doc(user.uid).set({
        'groupId': groupDoc.id,
      }, SetOptions(merge: true));

      return groupDoc.id;
    } catch (e) {
      print('Error creating group: $e');
      return null;
    }
  }

  // Join a group with user information (for non-authenticated users)
  Future<bool> joinGroupWithUserInfo(
    String groupId,
    String userName,
    String userEmail,
  ) async {
    try {
      final user = currentUser;
      if (user == null) return false;

      final groupDoc = _firestore.collection('groups').doc(groupId);
      final groupSnapshot = await groupDoc.get();

      if (!groupSnapshot.exists) return false;

      final groupData = groupSnapshot.data()!;
      final members = List<String>.from(groupData['members'] ?? []);

      // Check if group is full
      if (members.length >= (groupData['maxMembers'] ?? 6)) {
        return false;
      }

      // Add user to group
      members.add(user.uid);
      await groupDoc.update({'members': members});

      // Update user's Firestore document with name and email (use set with merge)
      await _firestore.collection('users').doc(user.uid).set({
        'groupId': groupId,
        'displayName': userName,
        'email': userEmail,
      }, SetOptions(merge: true));

      // Update Firebase Auth profile
      await user.updateDisplayName(userName);

      return true;
    } catch (e) {
      print('Error joining group with user info: $e');
      return false;
    }
  }

  // Join a group
  Future<bool> joinGroup(String groupId) async {
    try {
      final user = currentUser;
      if (user == null) return false;

      final groupDoc = _firestore.collection('groups').doc(groupId);
      final groupSnapshot = await groupDoc.get();

      if (!groupSnapshot.exists) return false;

      final groupData = groupSnapshot.data()!;
      final members = List<String>.from(groupData['members'] ?? []);

      // Check if group is full
      if (members.length >= (groupData['maxMembers'] ?? 6)) {
        return false;
      }

      // Add user to group
      members.add(user.uid);
      await groupDoc.update({'members': members});

      // Update user's groupId (use set with merge)
      await _firestore.collection('users').doc(user.uid).set({
        'groupId': groupId,
      }, SetOptions(merge: true));

      return true;
    } catch (e) {
      print('Error joining group: $e');
      return false;
    }
  }

  // Get group members
  Future<List<Map<String, dynamic>>> getGroupMembers(String groupId) async {
    try {
      final groupDoc = await _firestore.collection('groups').doc(groupId).get();
      if (!groupDoc.exists) return [];

      final members = List<String>.from(groupDoc.data()!['members'] ?? []);
      final memberDocs = await Future.wait(
        members.map((uid) => _firestore.collection('users').doc(uid).get()),
      );

      return memberDocs.where((doc) => doc.exists).map((doc) {
        final data = doc.data()!;
        // Ensure uid is in the data (use document ID if not present)
        if (!data.containsKey('uid')) {
          data['uid'] = doc.id;
        }
        return data;
      }).toList();
    } catch (e) {
      print('Error getting group members: $e');
      return [];
    }
  }

  // Get user's group
  Future<Map<String, dynamic>?> getUserGroup() async {
    try {
      final encryption = EncryptionService();
      final user = currentUser;
      if (user == null) return null;

      final userDoc = await _firestore.collection('users').doc(user.uid).get();
      if (!userDoc.exists) return null;

      final groupId = userDoc.data()!['groupId'];
      if (groupId == null) return null;

      final groupDoc = await _firestore.collection('groups').doc(groupId).get();
      if (!groupDoc.exists) return null;

      final groupData = groupDoc.data()!;
      // Decrypt group name
      return {
        'id': groupDoc.id,
        ...groupData,
        'name': encryption.decrypt(groupData['name'] ?? ''),
      };
    } catch (e) {
      print('Error getting user group: $e');
      return null;
    }
  }

  // Check if current user is admin of their group
  Future<bool> isUserAdmin() async {
    try {
      final user = currentUser;
      if (user == null) return false;

      final group = await getUserGroup();
      if (group == null) return false;

      return group['adminId'] == user.uid;
    } catch (e) {
      print('Error checking admin status: $e');
      return false;
    }
  }

  // Update group name (admin only)
  Future<bool> updateGroupName(String groupId, String newName) async {
    try {
      final encryption = EncryptionService();
      final user = currentUser;
      if (user == null) return false;

      // Check if user is admin
      final groupDoc = await _firestore.collection('groups').doc(groupId).get();
      if (!groupDoc.exists) return false;

      final groupData = groupDoc.data()!;
      if (groupData['adminId'] != user.uid) {
        print('User is not admin');
        return false;
      }

      // Update group name (encrypted)
      await _firestore.collection('groups').doc(groupId).update({
        'name': encryption.encrypt(newName),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      return true;
    } catch (e) {
      print('Error updating group name: $e');
      return false;
    }
  }

  // Remove member from group (admin only)
  Future<bool> removeMemberFromGroup(String groupId, String memberId) async {
    try {
      final user = currentUser;
      if (user == null) return false;

      // Check if user is admin
      final groupDoc = await _firestore.collection('groups').doc(groupId).get();
      if (!groupDoc.exists) return false;

      final groupData = groupDoc.data()!;
      if (groupData['adminId'] != user.uid) {
        print('User is not admin');
        return false;
      }

      // Cannot remove admin
      if (memberId == user.uid) {
        print('Cannot remove admin from group');
        return false;
      }

      // Remove member from group
      final members = List<String>.from(groupData['members'] ?? []);
      members.remove(memberId);

      await _firestore.collection('groups').doc(groupId).update({
        'members': members,
      });

      // Remove group from user's document (use set with merge)
      await _firestore.collection('users').doc(memberId).set({
        'groupId': null,
      }, SetOptions(merge: true));

      return true;
    } catch (e) {
      print('Error removing member: $e');
      return false;
    }
  }

  // Transfer admin role to another member (current admin only)
  Future<bool> transferAdminRole(String groupId, String newAdminId) async {
    try {
      final user = currentUser;
      if (user == null) return false;

      // Check if user is current admin
      final groupDoc = await _firestore.collection('groups').doc(groupId).get();
      if (!groupDoc.exists) return false;

      final groupData = groupDoc.data()!;
      if (groupData['adminId'] != user.uid) {
        print('User is not admin');
        return false;
      }

      // Check if new admin is a member of the group
      final members = List<String>.from(groupData['members'] ?? []);
      if (!members.contains(newAdminId)) {
        print('New admin is not a member of the group');
        return false;
      }

      // Transfer admin role
      await _firestore.collection('groups').doc(groupId).update({
        'adminId': newAdminId,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      return true;
    } catch (e) {
      print('Error transferring admin role: $e');
      return false;
    }
  }
}
