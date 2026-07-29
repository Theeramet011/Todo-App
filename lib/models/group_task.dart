class GroupMember {
  final String id;
  final String name;
  final String avatar;
  final String role;

  GroupMember({
    required this.id,
    required this.name,
    String? avatar,
    String? avatarUrl,
    required this.role,
  }) : avatar = avatar ?? avatarUrl ?? '';

  String get avatarUrl => avatar;
}

class GroupSubTask {
  final String title;
  bool isCompleted;
  final String? assignedToId;
  final int score;
  final String? submissionLink;
  final bool isLate;

  GroupSubTask({
    required this.title,
    this.isCompleted = false,
    this.assignedToId,
    this.score = 0,
    this.submissionLink,
    this.isLate = false,
  });
}

class GroupTask {
  final String id;
  final String title;
  final String description;
  final String status; // 'Active' or 'Planning'
  final List<GroupMember> members;
  final List<GroupSubTask> subTasks;
  final DateTime createdAt;
  final bool isLeader;

  GroupTask({
    required this.id,
    required this.title,
    required this.description,
    required this.status,
    required this.members,
    required this.subTasks,
    required this.createdAt,
    required this.isLeader,
  });

  double get progress {
    if (subTasks.isEmpty) return 0.0;
    final completed = subTasks.where((t) => t.isCompleted).length;
    return completed / subTasks.length;
  }

  int get completedCount => subTasks.where((t) => t.isCompleted).length;
}
