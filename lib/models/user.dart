import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hive/hive.dart';
import '../services/encryption_service.dart';

@HiveType(typeId: 2)
class User {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String name;

  @HiveField(2)
  final String avatarColor;

  @HiveField(3)
  final DateTime createdAt;

  User({
    required this.id,
    required this.name,
    required this.avatarColor,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  // Convert to JSON for Firestore
  Map<String, dynamic> toJson() {
    final encryption = EncryptionService();
    return {
      'id': id,
      'name': encryption.encrypt(name),
      'avatarColor': avatarColor,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  // Create from Firestore document
  factory User.fromJson(Map<String, dynamic> json) {
    final encryption = EncryptionService();
    final encryptedName = json['name'] as String? ?? 'User';
    return User(
      id: json['id'] as String? ?? '',
      name: encryption.decrypt(encryptedName),
      avatarColor: json['avatarColor'] as String? ?? '#4CAF50',
      createdAt: json['createdAt'] != null
          ? (json['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
    );
  }

  // Create a copy with updated fields
  User copyWith({
    String? id,
    String? name,
    String? avatarColor,
    DateTime? createdAt,
  }) {
    return User(
      id: id ?? this.id,
      name: name ?? this.name,
      avatarColor: avatarColor ?? this.avatarColor,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  // Get initials for avatar
  String get initials {
    final names = name.trim().split(' ');
    if (names.isEmpty) return '?';
    if (names.length == 1) {
      return names[0].substring(0, 1).toUpperCase();
    }
    return '${names[0].substring(0, 1)}${names[1].substring(0, 1)}'
        .toUpperCase();
  }

  @override
  String toString() {
    return 'User(id: $id, name: $name, avatarColor: $avatarColor)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is User && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}
