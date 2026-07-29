import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../utils/thai_display.dart';

enum ProjectStatus { planning, active, onHold, completed }

class Project {
  final String id;
  final String title;
  final String description;
  final List<String> memberIds;
  final String leaderId;
  final ProjectStatus status;
  final DateTime createdAt;
  final DateTime? dueDate;
  final int totalTasks;
  final int completedTasks;
  final Color color;

  const Project({
    required this.id,
    required this.title,
    this.description = '',
    required this.memberIds,
    required this.leaderId,
    this.status = ProjectStatus.planning,
    required this.createdAt,
    this.dueDate,
    this.totalTasks = 0,
    this.completedTasks = 0,
    this.color = const Color(0xFFFF6B8A),
  });

  factory Project.fromMap(Map<String, dynamic> data, String documentId) {
    return Project(
      id: documentId,
      title: data['title'] ?? data['name'] ?? data['projectName'] ?? '',
      description: data['description'] ?? '',
      memberIds: List<String>.from(data['memberIds'] ?? data['members'] ?? []),
      leaderId: data['leaderId'] ?? data['ownerId'] ?? data['creatorId'] ?? '',
      status: _parseStatus(data['status']),
      createdAt: _dateFromFirestore(data['createdAt']) ?? DateTime.now(),
      dueDate: _dateFromFirestore(data['dueDate']),
      totalTasks: _intFromFirestore(data['totalTasks']),
      completedTasks: _intFromFirestore(data['completedTasks']),
      color: _colorFromFirestore(data['color']),
    );
  }

  Map<String, dynamic> toMap() => {
    'title': title,
    'description': description,
    'memberIds': memberIds,
    'leaderId': leaderId,
    'status': status.name,
    'createdAt': Timestamp.fromDate(createdAt),
    'dueDate': dueDate == null ? null : Timestamp.fromDate(dueDate!),
    'totalTasks': totalTasks,
    'completedTasks': completedTasks,
    'color': color.toARGB32(),
  };

  Project copyWith({
    String? id,
    String? title,
    String? description,
    List<String>? memberIds,
    String? leaderId,
    ProjectStatus? status,
    DateTime? createdAt,
    DateTime? dueDate,
    int? totalTasks,
    int? completedTasks,
    Color? color,
  }) {
    return Project(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      memberIds: memberIds ?? this.memberIds,
      leaderId: leaderId ?? this.leaderId,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      dueDate: dueDate ?? this.dueDate,
      totalTasks: totalTasks ?? this.totalTasks,
      completedTasks: completedTasks ?? this.completedTasks,
      color: color ?? this.color,
    );
  }

  String get ownerId => leaderId;
  String get creatorId => leaderId;

  double get progress => totalTasks > 0 ? completedTasks / totalTasks : 0;
  int get memberCount => memberIds.length;
  bool isLeader(String? userId) => userId != null && userId == leaderId;

  String get statusLabel {
    switch (status) {
      case ProjectStatus.planning:
        return thaiProjectStatusLabel('Planning');
      case ProjectStatus.active:
        return thaiProjectStatusLabel('Active');
      case ProjectStatus.onHold:
        return thaiProjectStatusLabel('On Hold');
      case ProjectStatus.completed:
        return thaiProjectStatusLabel('Completed');
    }
  }

  Color get statusColor {
    switch (status) {
      case ProjectStatus.planning:
        return const Color(0xFF3ABEF9);
      case ProjectStatus.active:
        return const Color(0xFF00D9A5);
      case ProjectStatus.onHold:
        return const Color(0xFFFFB347);
      case ProjectStatus.completed:
        return const Color(0xFF9B5DE5);
    }
  }

  static ProjectStatus _parseStatus(dynamic status) {
    final value = status?.toString().toLowerCase();
    switch (value) {
      case 'active':
      case 'projectstatus.active':
        return ProjectStatus.active;
      case 'onhold':
      case 'on_hold':
      case 'on hold':
      case 'projectstatus.onhold':
        return ProjectStatus.onHold;
      case 'completed':
      case 'projectstatus.completed':
        return ProjectStatus.completed;
      default:
        return ProjectStatus.planning;
    }
  }

  static DateTime? _dateFromFirestore(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value);
    return null;
  }

  static int _intFromFirestore(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  static Color _colorFromFirestore(dynamic value) {
    if (value is int) return Color(value);
    if (value is String) {
      final normalized = value.replaceFirst('#', '0xff');
      final parsed = int.tryParse(normalized);
      if (parsed != null) return Color(parsed);
    }
    return const Color(0xFFFF6B8A);
  }
}
