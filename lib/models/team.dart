import 'package:flutter/material.dart';

class Team {
  final String id;
  final String name;
  final String? description;
  final String ownerId;
  final String ownerName;
  final String? ownerEmail;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final int memberCount;
  final List<TeamMember> members;

  Team({
    required this.id,
    required this.name,
    this.description,
    required this.ownerId,
    required this.ownerName,
    this.ownerEmail,
    required this.createdAt,
    this.updatedAt,
    required this.memberCount,
    required this.members,
  });

  factory Team.fromJson(Map<String, dynamic> json) {
    return Team(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String?,
      ownerId: json['owner_id'] as String,
      ownerName: json['owner_name'] as String,
      ownerEmail: json['owner_email'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String)
          : null,
      memberCount: json['member_count'] as int? ?? 0,
      members: (json['members'] as List<dynamic>?)
              ?.map((e) => TeamMember.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'owner_id': ownerId,
      'owner_name': ownerName,
      'owner_email': ownerEmail,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
      'member_count': memberCount,
      'members': members.map((e) => e.toJson()).toList(),
    };
  }

  Team copyWith({
    String? id,
    String? name,
    String? description,
    String? ownerId,
    String? ownerName,
    String? ownerEmail,
    DateTime? createdAt,
    DateTime? updatedAt,
    int? memberCount,
    List<TeamMember>? members,
  }) {
    return Team(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      ownerId: ownerId ?? this.ownerId,
      ownerName: ownerName ?? this.ownerName,
      ownerEmail: ownerEmail ?? this.ownerEmail,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      memberCount: memberCount ?? this.memberCount,
      members: members ?? this.members,
    );
  }
}

class TeamMember {
  final String id;
  final String userId;
  final String name;
  final String? email;
  final String role;
  final String? picture;
  final DateTime joinedAt;

  TeamMember({
    required this.id,
    required this.userId,
    required this.name,
    this.email,
    required this.role,
    this.picture,
    required this.joinedAt,
  });

  factory TeamMember.fromJson(Map<String, dynamic> json) {
    return TeamMember(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      name: json['name'] as String,
      email: json['email'] as String?,
      role: json['role'] as String,
      picture: json['picture'] as String?,
      joinedAt: DateTime.parse(json['joined_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'name': name,
      'email': email,
      'role': role,
      'picture': picture,
      'joined_at': joinedAt.toIso8601String(),
    };
  }

  TeamMember copyWith({
    String? id,
    String? userId,
    String? name,
    String? email,
    String? role,
    String? picture,
    DateTime? joinedAt,
  }) {
    return TeamMember(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      name: name ?? this.name,
      email: email ?? this.email,
      role: role ?? this.role,
      picture: picture ?? this.picture,
      joinedAt: joinedAt ?? this.joinedAt,
    );
  }

  String get roleDisplayName {
    switch (role.toLowerCase()) {
      case 'owner':
        return 'Owner';
      case 'admin':
        return 'Admin';
      case 'member':
      default:
        return 'Member';
    }
  }

  Color get roleColor {
    switch (role.toLowerCase()) {
      case 'owner':
        return Colors.orange;
      case 'admin':
        return Colors.blue;
      case 'member':
      default:
        return Colors.green;
    }
  }
}

enum TeamRole { owner, admin, member }
