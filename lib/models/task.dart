// Task Model - โมเดลหลักสำหรับจัดการภารกิจและงานย่อย (Task Data Structure)
//
// กำหนดโครงสร้างข้อมูลงาน (Task), งานย่อย (SubTask), ระดับความสำคัญ (Priority), ประเภทงาน (TaskType)
// รองรับงานส่วนตัว งานกลุ่ม งานทำซ้ำ (Recurring) ไฟล์แนบ การแจ้งเตือน และแปลงข้อมูลสำหรับ Firestore
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import 'user.dart';

enum Priority { low, medium, high, urgent }

enum TaskStatus { todo, inProgress, pending, completed }

enum TaskType { personal, group }

class SubTask {
  String title;
  bool isDone;

  SubTask({required this.title, this.isDone = false});

  factory SubTask.fromMap(Map<String, dynamic> map) {
    return SubTask(title: map['title'] ?? '', isDone: map['isDone'] ?? false);
  }

  Map<String, dynamic> toMap() => {'title': title, 'isDone': isDone};

  SubTask copyWith({String? title, bool? isDone}) {
    return SubTask(title: title ?? this.title, isDone: isDone ?? this.isDone);
  }
}

class Member {
  final String? _id;
  String get id => _id ?? '';
  final String? _name;
  String get name => _name ?? '';
  final String? _avatarUrl;
  String get avatarUrl => _avatarUrl ?? '';
  final String? taskTitle;
  final String? description;
  final String? _difficulty;
  String get difficulty => _difficulty ?? 'Easy';
  final String? _workload;
  String get workload => _workload ?? 'Small';
  final String? _risk;
  String get risk => _risk ?? 'None';
  final List<String>? _subTasks;
  List<String> get subTasks => _subTasks ?? const [];
  final List<String>? _completedSubTasks;
  List<String> get completedSubTasks => _completedSubTasks ?? const [];
  final String? score;
  final List<String>? _coAssigneeIds;
  List<String> get coAssigneeIds => _coAssigneeIds ?? const [];
  final String? submissionText;
  final DateTime? submittedAt;
  final String? _status;
  String get status {
    final s = _status;
    return (s != null && s.isNotEmpty) ? s : 'inProgress';
  }
  final List<TaskAttachment>? _attachments;
  List<TaskAttachment> get attachments => _attachments ?? const [];

  const Member({
    String id = '',
    String name = '',
    String avatarUrl = '',
    this.taskTitle,
    this.description,
    String difficulty = 'Easy',
    String workload = 'Small',
    String risk = 'None',
    List<String> subTasks = const [],
    List<String>? completedSubTasks,
    this.score,
    List<String> coAssigneeIds = const [],
    this.submissionText,
    this.submittedAt,
    String status = 'inProgress',
    List<TaskAttachment> attachments = const [],
  })  : _id = id,
        _name = name,
        _avatarUrl = avatarUrl,
        _difficulty = difficulty,
        _workload = workload,
        _risk = risk,
        _subTasks = subTasks,
        _completedSubTasks = completedSubTasks,
        _coAssigneeIds = coAssigneeIds,
        _status = status,
        _attachments = attachments;

  factory Member.fromUser(User user) {
    return Member(id: user.id, name: user.name, avatarUrl: user.avatarUrl);
  }

  factory Member.fromMap(Map<String, dynamic> data) {
    return Member(
      id: (data['id'] ?? data['userId'] ?? '').toString(),
      name: (data['name'] ?? '').toString(),
      avatarUrl: (data['avatarUrl'] ?? '').toString(),
      taskTitle: data['taskTitle']?.toString(),
      description: data['description']?.toString(),
      difficulty: (data['difficulty'] ?? 'Easy').toString(),
      workload: (data['workload'] ?? 'Small').toString(),
      risk: (data['risk'] ?? 'None').toString(),
      subTasks:
          (data['subTasks'] as List?)?.map((e) => e.toString()).toList() ??
          const [],
      completedSubTasks:
          (data['completedSubTasks'] as List?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
      score: data['score']?.toString(),
      coAssigneeIds:
          (data['coAssigneeIds'] as List?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
      submissionText: data['submissionText']?.toString(),
      submittedAt: Task._dateFromFirestore(data['submittedAt']),
      status: (data['status']?.toString().isNotEmpty == true)
          ? data['status'].toString()
          : 'inProgress',
      attachments: (data['attachments'] as List? ?? []).map((item) {
        if (item is Map) {
          return TaskAttachment.fromMap(Map<String, dynamic>.from(item));
        } else {
          final name = item.toString();
          final type = name.split('.').last.toLowerCase();
          return TaskAttachment(fileName: name, fileUrl: name, fileType: type);
        }
      }).toList(),
    );
  }

  Map<String, dynamic> toMap() => {
    'id': id,
    'name': name,
    'avatarUrl': avatarUrl,
    'taskTitle': taskTitle,
    'description': description,
    'difficulty': difficulty,
    'workload': workload,
    'risk': risk,
    'subTasks': subTasks,
    'completedSubTasks': completedSubTasks,
    'score': score,
    'coAssigneeIds': coAssigneeIds,
    'submissionText': submissionText,
    'submittedAt': submittedAt == null ? null : Timestamp.fromDate(submittedAt!),
    'status': status,
    'attachments': attachments.map((a) => a.toMap()).toList(),
  };

  Member copyWith({
    String? id,
    String? name,
    String? avatarUrl,
    String? taskTitle,
    String? description,
    String? difficulty,
    String? workload,
    String? risk,
    List<String>? subTasks,
    List<String>? completedSubTasks,
    String? score,
    List<String>? coAssigneeIds,
    String? submissionText,
    bool clearSubmissionText = false,
    DateTime? submittedAt,
    bool clearSubmittedAt = false,
    String? status,
    List<TaskAttachment>? attachments,
  }) {
    return Member(
      id: id ?? this.id,
      name: name ?? this.name,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      taskTitle: taskTitle ?? this.taskTitle,
      description: description ?? this.description,
      difficulty: difficulty ?? this.difficulty,
      workload: workload ?? this.workload,
      risk: risk ?? this.risk,
      subTasks: subTasks ?? this.subTasks,
      completedSubTasks: completedSubTasks ?? this.completedSubTasks,
      score: score ?? this.score,
      coAssigneeIds: coAssigneeIds ?? this.coAssigneeIds,
      submissionText: clearSubmissionText
          ? null
          : submissionText ?? this.submissionText,
      submittedAt: clearSubmittedAt ? null : submittedAt ?? this.submittedAt,
      status: status ?? this.status,
      attachments: attachments ?? this.attachments,
    );
  }
}

class Task {
  final String id;
  final String title;
  final String description;
  final String? category;
  final String? location;
  final DateTime dateTime;
  final Priority priority;
  final TaskStatus status;
  final TaskType type;
  final String? projectId;
  final List<String> assigneeIds;
  final List<Member> members;
  final int difficulty;
  final int workload;
  final int risk;
  final List<SubTask> subtasks;
  final List<Comment> comments;
  final List<TaskAttachment> attachments;
  final String creatorId;
  final DateTime createdAt;
  final DateTime? completedAt;
  final bool isDeleted;
  final DateTime? deletedAt;
  final List<String> deletedForUserIds;
  final List<String> hiddenForUserIds;
  final String notificationFormat;
  final Map<String, bool> customReminders;
  final bool isRecurring;
  final String recurringType;
  final DateTime? recurringDate;
  final String? recurringTime;
  final String? customRecurringMode;
  final int? customRecurringNum;
  final String? customRecurringUnit;
  final List<String>? customRecurringDays;
  final List<DateTime>? customRecurringFixedDates;
  final bool notified1Week;
  final bool notified1Day;
  final bool notified1Hour;
  final bool notifiedExact;
  final bool notifiedFollowUp;
  final String? submissionText;
  final String? submittedBy;
  final DateTime? submittedAt;
  final int awardedXP;
  final bool rewardBlocked;
  final String? rewardBlockedReason;
  final DateTime? rewardBlockedAt;
  final String? rewardBlockedBy;
  final int? completionAgeSeconds;

  const Task({
    required this.id,
    required this.title,
    this.description = '',
    this.category,
    this.location,
    required this.dateTime,
    this.priority = Priority.low,
    this.status = TaskStatus.todo,
    this.type = TaskType.personal,
    this.projectId,
    this.assigneeIds = const [],
    this.members = const [],
    this.difficulty = 1,
    this.workload = 1,
    this.risk = 1,
    this.subtasks = const [],
    this.comments = const [],
    this.attachments = const [],
    required this.creatorId,
    required this.createdAt,
    this.completedAt,
    this.isDeleted = false,
    this.deletedAt,
    this.deletedForUserIds = const [],
    this.hiddenForUserIds = const [],
    this.notificationFormat = 'No Notification',
    this.customReminders = const {},
    this.isRecurring = false,
    this.recurringType = 'daily',
    this.recurringDate,
    this.recurringTime,
    this.customRecurringMode,
    this.customRecurringNum,
    this.customRecurringUnit,
    this.customRecurringDays,
    this.customRecurringFixedDates,
    this.notified1Week = false,
    this.notified1Day = false,
    this.notified1Hour = false,
    this.notifiedExact = false,
    this.notifiedFollowUp = false,
    this.submissionText,
    this.submittedBy,
    this.submittedAt,
    this.awardedXP = 0,
    this.rewardBlocked = false,
    this.rewardBlockedReason,
    this.rewardBlockedAt,
    this.rewardBlockedBy,
    this.completionAgeSeconds,
  });

  factory Task.fromMap(Map<String, dynamic> data, String documentId) {
    final projectId = data['projectId'] as String?;
    final legacySubmitterId = data['submittedBy'] as String?;
    final legacySubmissionText = data['submissionText'] as String?;
    final legacySubmittedAt = _dateFromFirestore(data['submittedAt']);
    final legacyTaskStatus = _parseStatus(data['status']);

    final members = (data['members'] as List? ?? [])
        .whereType<Map>()
        .map((m) {
          var member = Member.fromMap(Map<String, dynamic>.from(m));
          if (legacySubmitterId != null &&
              legacySubmitterId.isNotEmpty &&
              member.id == legacySubmitterId) {
            if (member.submissionText == null && legacySubmissionText != null) {
              member = member.copyWith(
                submissionText: legacySubmissionText,
                submittedAt: legacySubmittedAt,
                status: legacyTaskStatus == TaskStatus.completed
                    ? 'completed'
                    : legacyTaskStatus == TaskStatus.pending
                    ? 'pending'
                    : member.status,
              );
            }
          }
          return member;
        })
        .toList();
    final assigneeIds = List<String>.from(data['assigneeIds'] ?? []);
    final legacyAssigneeId = data['assigneeId'] as String?;

    return Task(
      id: documentId,
      title: data['title'] ?? '',
      description: data['description'] ?? '',
      category: data['category'],
      location: data['location'],
      dateTime: _dateFromFirestore(data['dateTime']) ?? DateTime.now(),
      priority: _parsePriority(data['priority']),
      status: _parseStatus(data['status']),
      type: _parseType(data['type'], projectId),
      projectId: projectId,
      assigneeIds: assigneeIds.isNotEmpty
          ? assigneeIds
          : legacyAssigneeId != null && legacyAssigneeId.isNotEmpty
          ? [legacyAssigneeId]
          : members.map((member) => member.id).toList(),
      members: members,
      difficulty: _intFromFirestore(data['difficulty'], fallback: 1),
      workload: _intFromFirestore(data['workload'], fallback: 1),
      risk: _intFromFirestore(data['risk'], fallback: 1),
      creatorId: data['creatorId'] ?? data['leaderId'] ?? '',
      createdAt: _dateFromFirestore(data['createdAt']) ?? DateTime.now(),
      completedAt: _dateFromFirestore(data['completedAt']),
      isDeleted: data['isDeleted'] ?? false,
      deletedAt: _dateFromFirestore(data['deletedAt']),
      deletedForUserIds: List<String>.from(data['deletedForUserIds'] ?? []),
      hiddenForUserIds: List<String>.from(data['hiddenForUserIds'] ?? []),
      notificationFormat: data['notificationFormat'] ?? 'No Notification',
      customReminders: _parseCustomReminders(data['customReminders']),
      isRecurring: data['isRecurring'] ?? false,
      recurringType: _parseRecurringType(data['recurringType']),
      recurringDate: _dateFromFirestore(data['recurringDate']),
      recurringTime: data['recurringTime'] as String?,
      customRecurringMode: data['customRecurringMode'] as String?,
      customRecurringNum: data['customRecurringNum'] != null
          ? _intFromFirestore(data['customRecurringNum'], fallback: 1)
          : null,
      customRecurringUnit: data['customRecurringUnit'] as String?,
      customRecurringDays: data['customRecurringDays'] != null
          ? List<String>.from(data['customRecurringDays'])
          : null,
      customRecurringFixedDates: data['customRecurringFixedDates'] != null
          ? (data['customRecurringFixedDates'] as List<dynamic>)
              .map((e) {
                if (e is Timestamp) return e.toDate();
                if (e is String) return DateTime.parse(e);
                return DateTime.now();
              })
              .toList()
          : null,
      notified1Week: data['notified1Week'] ?? false,
      notified1Day: data['notified1Day'] ?? false,
      notified1Hour: data['notified1Hour'] ?? false,
      notifiedExact: data['notifiedExact'] ?? false,
      notifiedFollowUp: data['notifiedFollowUp'] ?? false,
      submissionText: data['submissionText'] as String?,
      submittedBy: data['submittedBy'] as String?,
      submittedAt: _dateFromFirestore(data['submittedAt']),
      awardedXP: _intFromFirestore(data['awardedXP'], fallback: 0),
      rewardBlocked: data['rewardBlocked'] ?? false,
      rewardBlockedReason: data['rewardBlockedReason'] as String?,
      rewardBlockedAt: _dateFromFirestore(data['rewardBlockedAt']),
      rewardBlockedBy: data['rewardBlockedBy'] as String?,
      completionAgeSeconds: data['completionAgeSeconds'] == null
          ? null
          : _intFromFirestore(data['completionAgeSeconds'], fallback: 0),
      subtasks: (data['subtasks'] as List? ?? [])
          .whereType<Map>()
          .map((s) => SubTask.fromMap(Map<String, dynamic>.from(s)))
          .toList(),
      comments: (data['comments'] as List? ?? [])
          .whereType<Map>()
          .map((c) => Comment.fromMap(Map<String, dynamic>.from(c)))
          .toList(),
      attachments: (data['attachments'] as List? ?? []).map((item) {
        if (item is Map) {
          return TaskAttachment.fromMap(Map<String, dynamic>.from(item));
        } else {
          final name = item.toString();
          final type = name.split('.').last.toLowerCase();
          return TaskAttachment(fileName: name, fileUrl: name, fileType: type);
        }
      }).toList(),
    );
  }

  Map<String, dynamic> toMap() => {
    'title': title,
    'description': description,
    'category': category,
    'location': location,
    'dateTime': Timestamp.fromDate(dateTime),
    'priority': priority.name,
    'status': status.name,
    'type': type.name,
    'projectId': projectId,
    'assigneeId': assigneeIds.length == 1 ? assigneeIds.first : null,
    'assigneeIds': assigneeIds,
    'members': members.map((member) => member.toMap()).toList(),
    'difficulty': difficulty,
    'workload': workload,
    'risk': risk,
    'creatorId': creatorId,
    'createdAt': Timestamp.fromDate(createdAt),
    'completedAt': completedAt == null
        ? null
        : Timestamp.fromDate(completedAt!),
    'isDeleted': isDeleted,
    'deletedAt': deletedAt == null ? null : Timestamp.fromDate(deletedAt!),
    'deletedForUserIds': deletedForUserIds,
    'hiddenForUserIds': hiddenForUserIds,
    'notificationFormat': notificationFormat,
    'customReminders': customReminders,
    'isRecurring': isRecurring,
    'recurringType': recurringType,
    'recurringDate': recurringDate == null
        ? null
        : Timestamp.fromDate(recurringDate!),
    'recurringTime': recurringTime,
    'customRecurringMode': customRecurringMode,
    'customRecurringNum': customRecurringNum,
    'customRecurringUnit': customRecurringUnit,
    'customRecurringDays': customRecurringDays,
    'customRecurringFixedDates': customRecurringFixedDates
        ?.map((d) => Timestamp.fromDate(d))
        .toList(),
    'notified1Week': notified1Week,
    'notified1Day': notified1Day,
    'notified1Hour': notified1Hour,
    'notifiedExact': notifiedExact,
    'notifiedFollowUp': notifiedFollowUp,
    'submissionText': submissionText,
    'submittedBy': submittedBy,
    'submittedAt': submittedAt == null
        ? null
        : Timestamp.fromDate(submittedAt!),
    'awardedXP': awardedXP,
    'rewardBlocked': rewardBlocked,
    'rewardBlockedReason': rewardBlockedReason,
    'rewardBlockedAt': rewardBlockedAt == null
        ? null
        : Timestamp.fromDate(rewardBlockedAt!),
    'rewardBlockedBy': rewardBlockedBy,
    'completionAgeSeconds': completionAgeSeconds,
    'subtasks': subtasks.map((subtask) => subtask.toMap()).toList(),
    'comments': comments.map((comment) => comment.toMap()).toList(),
    'attachments': attachments.map((a) => a.toMap()).toList(),
  };

  Task copyWith({
    String? id,
    String? title,
    String? description,
    String? category,
    String? location,
    DateTime? dateTime,
    Priority? priority,
    TaskStatus? status,
    TaskType? type,
    String? projectId,
    List<String>? assigneeIds,
    List<Member>? members,
    int? difficulty,
    int? workload,
    int? risk,
    List<SubTask>? subtasks,
    List<Comment>? comments,
    List<TaskAttachment>? attachments,
    String? creatorId,
    DateTime? createdAt,
    DateTime? completedAt,
    bool clearCompletedAt = false,
    bool? isDeleted,
    DateTime? deletedAt,
    bool clearDeletedAt = false,
    List<String>? deletedForUserIds,
    List<String>? hiddenForUserIds,
    String? notificationFormat,
    Map<String, bool>? customReminders,
    bool? isRecurring,
    String? recurringType,
    DateTime? recurringDate,
    bool clearRecurringDate = false,
    String? recurringTime,
    bool clearRecurringTime = false,
    String? customRecurringMode,
    int? customRecurringNum,
    String? customRecurringUnit,
    List<String>? customRecurringDays,
    List<DateTime>? customRecurringFixedDates,
    bool? notified1Week,
    bool? notified1Day,
    bool? notified1Hour,
    bool? notifiedExact,
    bool? notifiedFollowUp,
    String? submissionText,
    String? submittedBy,
    DateTime? submittedAt,
    bool clearSubmissionText = false,
    bool clearSubmittedBy = false,
    bool clearSubmittedAt = false,
    int? awardedXP,
    bool? rewardBlocked,
    String? rewardBlockedReason,
    DateTime? rewardBlockedAt,
    String? rewardBlockedBy,
    int? completionAgeSeconds,
    bool clearRewardBlockedReason = false,
    bool clearRewardBlockedAt = false,
    bool clearRewardBlockedBy = false,
    bool clearCompletionAgeSeconds = false,
  }) {
    return Task(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      category: category ?? this.category,
      location: location ?? this.location,
      dateTime: dateTime ?? this.dateTime,
      priority: priority ?? this.priority,
      status: status ?? this.status,
      type: type ?? this.type,
      projectId: projectId ?? this.projectId,
      assigneeIds: assigneeIds ?? this.assigneeIds,
      members: members ?? this.members,
      difficulty: difficulty ?? this.difficulty,
      workload: workload ?? this.workload,
      risk: risk ?? this.risk,
      subtasks: subtasks ?? this.subtasks,
      comments: comments ?? this.comments,
      attachments: attachments ?? this.attachments,
      creatorId: creatorId ?? this.creatorId,
      createdAt: createdAt ?? this.createdAt,
      completedAt: clearCompletedAt ? null : completedAt ?? this.completedAt,
      isDeleted: isDeleted ?? this.isDeleted,
      deletedAt: clearDeletedAt ? null : deletedAt ?? this.deletedAt,
      deletedForUserIds: deletedForUserIds ?? this.deletedForUserIds,
      hiddenForUserIds: hiddenForUserIds ?? this.hiddenForUserIds,
      notificationFormat: notificationFormat ?? this.notificationFormat,
      customReminders: customReminders ?? this.customReminders,
      isRecurring: isRecurring ?? this.isRecurring,
      recurringType: recurringType ?? this.recurringType,
      recurringDate: clearRecurringDate
          ? null
          : recurringDate ?? this.recurringDate,
      recurringTime: clearRecurringTime
          ? null
          : recurringTime ?? this.recurringTime,
      customRecurringMode: customRecurringMode ?? this.customRecurringMode,
      customRecurringNum: customRecurringNum ?? this.customRecurringNum,
      customRecurringUnit: customRecurringUnit ?? this.customRecurringUnit,
      customRecurringDays: customRecurringDays ?? this.customRecurringDays,
      customRecurringFixedDates:
          customRecurringFixedDates ?? this.customRecurringFixedDates,
      notified1Week: notified1Week ?? this.notified1Week,
      notified1Day: notified1Day ?? this.notified1Day,
      notified1Hour: notified1Hour ?? this.notified1Hour,
      notifiedExact: notifiedExact ?? this.notifiedExact,
      notifiedFollowUp: notifiedFollowUp ?? this.notifiedFollowUp,
      submissionText: clearSubmissionText
          ? null
          : submissionText ?? this.submissionText,
      submittedBy: clearSubmittedBy ? null : submittedBy ?? this.submittedBy,
      submittedAt: clearSubmittedAt ? null : submittedAt ?? this.submittedAt,
      awardedXP: awardedXP ?? this.awardedXP,
      rewardBlocked: rewardBlocked ?? this.rewardBlocked,
      rewardBlockedReason: clearRewardBlockedReason
          ? null
          : rewardBlockedReason ?? this.rewardBlockedReason,
      rewardBlockedAt: clearRewardBlockedAt
          ? null
          : rewardBlockedAt ?? this.rewardBlockedAt,
      rewardBlockedBy: clearRewardBlockedBy
          ? null
          : rewardBlockedBy ?? this.rewardBlockedBy,
      completionAgeSeconds: clearCompletionAgeSeconds
          ? null
          : completionAgeSeconds ?? this.completionAgeSeconds,
    );
  }

  static TaskStatus _parseStatus(dynamic status) {
    final value = status?.toString().toLowerCase();
    switch (value) {
      case 'completed':
      case 'taskstatus.completed':
        return TaskStatus.completed;
      case 'inprogress':
      case 'in_progress':
      case 'in progress':
      case 'taskstatus.inprogress':
        return TaskStatus.inProgress;
      case 'pending':
      case 'pending approval':
      case 'taskstatus.pending':
        return TaskStatus.pending;
      default:
        return TaskStatus.todo;
    }
  }

  static Priority _parsePriority(dynamic priority) {
    final value = priority?.toString().toLowerCase();
    switch (value) {
      case 'low':
      case 'priority.low':
        return Priority.low;
      case 'high':
      case 'priority.high':
        return Priority.high;
      case 'urgent':
      case 'priority.urgent':
        return Priority.urgent;
      default:
        return Priority.medium;
    }
  }

  static TaskType _parseType(dynamic type, String? projectId) {
    final value = type?.toString().toLowerCase();
    if (value == 'group' || value == 'tasktype.group' || projectId != null) {
      return TaskType.group;
    }
    return TaskType.personal;
  }

  static String _parseRecurringType(dynamic value) {
    switch (value?.toString()) {
      case 'weekly':
      case 'ทุกสัปดาห์':
        return 'weekly';
      case 'monthly':
      case 'รายเดือน':
        return 'monthly';
      case 'yearly':
      case 'รายปี':
        return 'yearly';
      case 'weekdays':
      case 'ทุกวันทำงาน':
        return 'weekdays';
      case 'custom':
      case 'กำหนดเอง':
        return 'custom';
      case 'daily':
      case 'ทุกวัน':
      default:
        return 'daily';
    }
  }

  static DateTime? _dateFromFirestore(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value);
    return null;
  }

  static int _intFromFirestore(dynamic value, {required int fallback}) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? fallback;
  }

  static Map<String, bool> _parseCustomReminders(dynamic value) {
    if (value is! Map) return const {};
    final reminders = <String, bool>{};
    value.forEach((key, isNotified) {
      final minutes = int.tryParse(key.toString());
      if (minutes == null || minutes <= 0) return;
      reminders[minutes.toString()] = isNotified == true;
    });
    return reminders;
  }

  // สูตรคำนวณ XP ที่จะได้รับจาก Task โดยพิจารณาจาก difficulty, workload และ risk
  int get calculateXP => (difficulty * 15) + (workload * 10) + (risk * 5);

  Color get priorityColor {
    switch (priority) {
      case Priority.low:
        return const Color(0xFF00D9A5);
      case Priority.medium:
        return const Color(0xFF3ABEF9);
      case Priority.high:
        return const Color(0xFFFF6B8A);
      case Priority.urgent:
        return const Color(0xFF9B5DE5);
    }
  }

  String get priorityLabel {
    switch (priority) {
      case Priority.low:
        return 'ต่ำ';
      case Priority.medium:
        return 'ปานกลาง';
      case Priority.high:
        return 'สูง';
      case Priority.urgent:
        return 'ด่วน';
    }
  }

  bool get isCompleted => status == TaskStatus.completed;
  bool get isPersonal => type == TaskType.personal;
  bool get isGroup => type == TaskType.group;

  double get progress {
    if (subtasks.isEmpty) return isCompleted ? 1.0 : 0.0;
    final completed = subtasks.where((t) => t.isDone).length;
    return completed / subtasks.length;
  }

  int get completedCount => subtasks.where((t) => t.isDone).length;
}

class Comment {
  final String id;
  final String userId;
  final String userName;
  final String userAvatarUrl;
  final String content;
  final DateTime createdAt;
  final List<TaskAttachment> attachments;

  const Comment({
    required this.id,
    required this.userId,
    required this.userName,
    required this.userAvatarUrl,
    required this.content,
    required this.createdAt,
    this.attachments = const [],
  });

  factory Comment.fromMap(Map<String, dynamic> data) {
    return Comment(
      id: data['id'] ?? '',
      userId: data['userId'] ?? '',
      userName: data['userName'] ?? '',
      userAvatarUrl: data['userAvatarUrl'] ?? data['userAvatar'] ?? '',
      content: data['content'] ?? '',
      createdAt: Task._dateFromFirestore(data['createdAt']) ?? DateTime.now(),
      attachments: (data['attachments'] as List? ?? []).map((item) {
        if (item is Map) {
          return TaskAttachment.fromMap(Map<String, dynamic>.from(item));
        } else {
          final name = item.toString();
          final type = name.split('.').last.toLowerCase();
          return TaskAttachment(fileName: name, fileUrl: name, fileType: type);
        }
      }).toList(),
    );
  }

  Map<String, dynamic> toMap() => {
    'id': id,
    'userId': userId,
    'userName': userName,
    'userAvatarUrl': userAvatarUrl,
    'content': content,
    'createdAt': Timestamp.fromDate(createdAt),
    'attachments': attachments.map((a) => a.toMap()).toList(),
  };
}

class TaskAttachment {
  final String fileName;
  final String fileUrl;
  final String fileType;
  final DateTime? uploadedAt;

  const TaskAttachment({
    required this.fileName,
    required this.fileUrl,
    required this.fileType,
    this.uploadedAt,
  });

  factory TaskAttachment.fromMap(Map<String, dynamic> data) {
    return TaskAttachment(
      fileName: data['fileName'] ?? '',
      fileUrl: data['fileUrl'] ?? '',
      fileType: data['fileType'] ?? '',
      uploadedAt: Task._dateFromFirestore(data['uploadedAt']),
    );
  }

  Map<String, dynamic> toMap() => {
    'fileName': fileName,
    'fileUrl': fileUrl,
    'fileType': fileType,
    'uploadedAt': uploadedAt == null ? null : Timestamp.fromDate(uploadedAt!),
  };
}
