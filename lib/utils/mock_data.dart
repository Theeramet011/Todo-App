import 'package:flutter/material.dart';
import '../models/task.dart';
import '../models/user.dart';
import '../models/project.dart';

class MockData {
  // Current User
  static User currentUser = User(
    id: 'user_001',
    name: 'Alex Johnson',
    email: 'alex.johnson@email.com',
    avatarUrl: 'https://i.pravatar.cc/150?img=1',
    totalXP: 450,
    currentLevel: 5,
    tasksCompleted: 45,
    streak: 7,
    joinedAt: DateTime(2024, 1, 15),
    isOnline: true,
  );

  // Friends List
  static List<User> friends = [
    User(
      id: 'user_002',
      name: 'Sarah Williams',
      email: 'sarah.w@email.com',
      avatarUrl: 'https://i.pravatar.cc/150?img=5',
      totalXP: 680,
      currentLevel: 7,
      tasksCompleted: 68,
      streak: 12,
      joinedAt: DateTime(2024, 2, 1),
      isOnline: true,
    ),
    User(
      id: 'user_003',
      name: 'Mike Chen',
      email: 'mike.chen@email.com',
      avatarUrl: 'https://i.pravatar.cc/150?img=3',
      totalXP: 320,
      currentLevel: 4,
      tasksCompleted: 32,
      streak: 3,
      joinedAt: DateTime(2024, 3, 10),
      isOnline: false,
    ),
    User(
      id: 'user_004',
      name: 'Emma Davis',
      email: 'emma.d@email.com',
      avatarUrl: 'https://i.pravatar.cc/150?img=9',
      totalXP: 890,
      currentLevel: 9,
      tasksCompleted: 89,
      streak: 21,
      joinedAt: DateTime(2024, 1, 20),
      isOnline: true,
    ),
    User(
      id: 'user_005',
      name: 'James Wilson',
      email: 'james.w@email.com',
      avatarUrl: 'https://i.pravatar.cc/150?img=11',
      totalXP: 150,
      currentLevel: 2,
      tasksCompleted: 15,
      streak: 2,
      joinedAt: DateTime(2024, 6, 1),
      isOnline: false,
    ),
    User(
      id: 'user_006',
      name: 'Lisa Brown',
      email: 'lisa.b@email.com',
      avatarUrl: 'https://i.pravatar.cc/150?img=10',
      totalXP: 520,
      currentLevel: 6,
      tasksCompleted: 52,
      streak: 9,
      joinedAt: DateTime(2024, 2, 28),
      isOnline: true,
    ),
  ];

  // Projects
  static List<Project> projects = [
    Project(
      id: 'proj_001',
      title: 'Mobile App Redesign',
      description: 'Redesign the company mobile application with new branding',
      memberIds: ['user_001', 'user_002', 'user_004'],
      leaderId: 'user_001',
      status: ProjectStatus.active,
      createdAt: DateTime(2024, 11, 1),
      dueDate: DateTime(2025, 1, 15),
      totalTasks: 12,
      completedTasks: 5,
      color: const Color(0xFFFF6B8A),
    ),
    Project(
      id: 'proj_002',
      title: 'Website Launch',
      description: 'Launch the new company website',
      memberIds: ['user_001', 'user_003', 'user_005'],
      leaderId: 'user_003',
      status: ProjectStatus.planning,
      createdAt: DateTime(2024, 12, 1),
      dueDate: DateTime(2025, 2, 28),
      totalTasks: 8,
      completedTasks: 1,
      color: const Color(0xFF9B5DE5),
    ),
    Project(
      id: 'proj_003',
      title: 'Marketing Campaign',
      description: 'Q1 2025 marketing campaign planning and execution',
      memberIds: ['user_002', 'user_004', 'user_006'],
      leaderId: 'user_002',
      status: ProjectStatus.active,
      createdAt: DateTime(2024, 11, 15),
      dueDate: DateTime(2025, 1, 31),
      totalTasks: 15,
      completedTasks: 8,
      color: const Color(0xFF3ABEF9),
    ),
    Project(
      id: 'proj_004',
      title: 'Database Migration',
      description: 'Migrate legacy database to new cloud infrastructure',
      memberIds: ['user_001', 'user_003'],
      leaderId: 'user_001',
      status: ProjectStatus.onHold,
      createdAt: DateTime(2024, 10, 1),
      dueDate: DateTime(2025, 3, 31),
      totalTasks: 20,
      completedTasks: 10,
      color: const Color(0xFFFFB347),
    ),
  ];

  // Tasks
  static List<Task> tasks = [
    Task(
      id: 'task_001',
      title: 'Complete UI Design Mockups',
      description:
          'Create high-fidelity mockups for the new mobile app screens',
      category: 'Design',
      location: 'Office',
      dateTime: DateTime.now().add(const Duration(hours: 2)),
      priority: Priority.high,
      status: TaskStatus.inProgress,
      type: TaskType.personal,
      creatorId: 'user_001',
      assigneeIds: ['user_001'],
      createdAt: DateTime.now().subtract(const Duration(days: 2)),
      difficulty: 3,
      workload: 3,
      risk: 2,
    ),
    Task(
      id: 'task_002',
      title: 'Review Pull Request #234',
      description: 'Review and approve the authentication module changes',
      category: 'Development',
      dateTime: DateTime.now().add(const Duration(hours: 4)),
      priority: Priority.medium,
      status: TaskStatus.pending,
      type: TaskType.personal,
      creatorId: 'user_001',
      assigneeIds: ['user_001'],
      createdAt: DateTime.now().subtract(const Duration(days: 1)),
      difficulty: 2,
      workload: 1,
      risk: 2,
    ),
    Task(
      id: 'task_003',
      title: 'Team Meeting Preparation',
      description: 'Prepare slides and agenda for weekly team meeting',
      category: 'Meeting',
      location: 'Conference Room A',
      dateTime: DateTime.now().add(const Duration(days: 1, hours: 3)),
      priority: Priority.high,
      status: TaskStatus.pending,
      type: TaskType.group,
      projectId: 'proj_001',
      creatorId: 'user_001',
      assigneeIds: ['user_001', 'user_002', 'user_004'],
      createdAt: DateTime.now().subtract(const Duration(days: 1)),
      difficulty: 1,
      workload: 2,
      risk: 1,
    ),
    Task(
      id: 'task_004',
      title: 'Write Documentation',
      description: 'Document the new API endpoints for the mobile app',
      category: 'Documentation',
      dateTime: DateTime.now().add(const Duration(days: 2)),
      priority: Priority.low,
      status: TaskStatus.pending,
      type: TaskType.personal,
      creatorId: 'user_001',
      assigneeIds: ['user_001'],
      createdAt: DateTime.now(),
      difficulty: 1,
      workload: 3,
      risk: 1,
    ),
    Task(
      id: 'task_005',
      title: 'Client Presentation',
      description: 'Present the final designs to the client',
      category: 'Presentation',
      location: 'Client Office',
      dateTime: DateTime.now().add(const Duration(days: 3)),
      priority: Priority.urgent,
      status: TaskStatus.pending,
      type: TaskType.group,
      projectId: 'proj_001',
      creatorId: 'user_002',
      assigneeIds: ['user_001', 'user_002'],
      createdAt: DateTime.now(),
      difficulty: 2,
      workload: 2,
      risk: 3,
    ),
    Task(
      id: 'task_006',
      title: 'Code Review Session',
      description: 'Weekly code review with the development team',
      category: 'Development',
      location: 'Online',
      dateTime: DateTime.now().add(const Duration(days: 1)),
      priority: Priority.medium,
      status: TaskStatus.pending,
      type: TaskType.group,
      projectId: 'proj_002',
      creatorId: 'user_003',
      assigneeIds: ['user_001', 'user_003', 'user_005'],
      createdAt: DateTime.now(),
      difficulty: 2,
      workload: 1,
      risk: 2,
    ),
    Task(
      id: 'task_007',
      title: 'Update Dependencies',
      description: 'Update all npm packages to latest versions',
      category: 'Development',
      dateTime: DateTime.now().add(const Duration(days: 4)),
      priority: Priority.low,
      status: TaskStatus.pending,
      type: TaskType.personal,
      creatorId: 'user_001',
      assigneeIds: ['user_001'],
      createdAt: DateTime.now(),
      difficulty: 1,
      workload: 2,
      risk: 1,
    ),
    Task(
      id: 'task_008',
      title: 'Marketing Content Review',
      description: 'Review and approve marketing content for social media',
      category: 'Marketing',
      dateTime: DateTime.now().add(const Duration(days: 2)),
      priority: Priority.medium,
      status: TaskStatus.completed,
      type: TaskType.personal,
      projectId: 'proj_003',
      creatorId: 'user_004',
      assigneeIds: ['user_002', 'user_004', 'user_006'],
      createdAt: DateTime.now().subtract(const Duration(days: 3)),
      completedAt: DateTime.now().subtract(const Duration(days: 1)),
      difficulty: 2,
      workload: 2,
      risk: 1,
    ),
    Task(
      id: 'task_009',
      title: 'Design System Documentation',
      description: 'Create comprehensive design system documentation',
      category: 'Design',
      dateTime: DateTime.now().add(const Duration(days: 5)),
      priority: Priority.high,
      status: TaskStatus.completed,
      type: TaskType.personal,
      creatorId: 'user_001',
      assigneeIds: ['user_001'],
      createdAt: DateTime.now().subtract(const Duration(days: 5)),
      completedAt: DateTime.now().subtract(const Duration(days: 3)),
      difficulty: 3,
      workload: 3,
      risk: 2,
    ),
    Task(
      id: 'task_010',
      title: 'API Integration Testing',
      description: 'Test all API endpoints for the mobile application',
      category: 'Development',
      dateTime: DateTime.now().add(const Duration(days: 6)),
      priority: Priority.high,
      status: TaskStatus.completed,
      type: TaskType.personal,
      creatorId: 'user_001',
      assigneeIds: ['user_001'],
      createdAt: DateTime.now().subtract(const Duration(days: 6)),
      completedAt: DateTime.now().subtract(const Duration(days: 2)),
      difficulty: 2,
      workload: 3,
      risk: 2,
    ),
    Task(
      id: 'task_011',
      title: 'Database Schema Optimization',
      description: 'Optimize database queries and indexing',
      category: 'Development',
      dateTime: DateTime.now().add(const Duration(days: 7)),
      priority: Priority.medium,
      status: TaskStatus.completed,
      type: TaskType.personal,
      creatorId: 'user_001',
      assigneeIds: ['user_001'],
      createdAt: DateTime.now().subtract(const Duration(days: 7)),
      completedAt: DateTime.now().subtract(const Duration(days: 4)),
      difficulty: 3,
      workload: 2,
      risk: 1,
    ),
    Task(
      id: 'task_012',
      title: 'Security Audit Report',
      description: 'Complete security audit and create vulnerability report',
      category: 'Security',
      dateTime: DateTime.now().add(const Duration(days: 8)),
      priority: Priority.urgent,
      status: TaskStatus.completed,
      type: TaskType.personal,
      creatorId: 'user_001',
      assigneeIds: ['user_001'],
      createdAt: DateTime.now().subtract(const Duration(days: 8)),
      completedAt: DateTime.now().subtract(const Duration(days: 5)),
      difficulty: 3,
      workload: 3,
      risk: 3,
    ),
    Task(
      id: 'task_013',
      title: 'User Feedback Analysis',
      description: 'Analyze and categorize user feedback from beta testers',
      category: 'Analytics',
      dateTime: DateTime.now().add(const Duration(days: 9)),
      priority: Priority.medium,
      status: TaskStatus.completed,
      type: TaskType.personal,
      creatorId: 'user_001',
      assigneeIds: ['user_001'],
      createdAt: DateTime.now().subtract(const Duration(days: 9)),
      completedAt: DateTime.now().subtract(const Duration(days: 6)),
      difficulty: 2,
      workload: 3,
      risk: 1,
    ),
    Task(
      id: 'task_014',
      title: 'Performance Optimization',
      description: 'Optimize app performance and reduce load times',
      category: 'Development',
      dateTime: DateTime.now().add(const Duration(days: 10)),
      priority: Priority.high,
      status: TaskStatus.completed,
      type: TaskType.personal,
      creatorId: 'user_001',
      assigneeIds: ['user_001'],
      createdAt: DateTime.now().subtract(const Duration(days: 10)),
      completedAt: DateTime.now().subtract(const Duration(days: 7)),
      difficulty: 3,
      workload: 2,
      risk: 2,
    ),
  ];

  // Calendar Events (tasks organized by date)
  static Map<DateTime, List<Task>> getTasksByDate() {
    Map<DateTime, List<Task>> tasksByDate = {};
    for (var task in tasks) {
      DateTime date = DateTime(
        task.dateTime.year,
        task.dateTime.month,
        task.dateTime.day,
      );
      if (!tasksByDate.containsKey(date)) {
        tasksByDate[date] = [];
      }
      tasksByDate[date]!.add(task);
    }
    return tasksByDate;
  }

  // Get tasks for a specific date
  static List<Task> getTasksForDate(DateTime date) {
    DateTime targetDate = DateTime(date.year, date.month, date.day);
    return tasks.where((task) {
      DateTime taskDate = DateTime(
        task.dateTime.year,
        task.dateTime.month,
        task.dateTime.day,
      );
      return taskDate == targetDate;
    }).toList();
  }

  // Get personal tasks
  static List<Task> getPersonalTasks() {
    return tasks.where((task) => task.isPersonal).toList();
  }

  // Get group tasks
  static List<Task> getGroupTasks() {
    return tasks.where((task) => task.isGroup).toList();
  }

  // Get completed tasks
  static List<Task> getCompletedTasks() {
    return tasks.where((task) => task.isCompleted).toList();
  }

  // Get pending tasks
  static List<Task> getPendingTasks() {
    return tasks.where((task) => !task.isCompleted).toList();
  }

  // Get user by ID
  static User? getUserById(String userId) {
    if (userId == currentUser.id) return currentUser;
    try {
      return friends.firstWhere((friend) => friend.id == userId);
    } catch (e) {
      return null;
    }
  }

  // Get project by ID
  static Project? getProjectById(String projectId) {
    try {
      return projects.firstWhere((project) => project.id == projectId);
    } catch (e) {
      return null;
    }
  }

  // Get tasks for a project
  static List<Task> getTasksForProject(String projectId) {
    return tasks.where((task) => task.projectId == projectId).toList();
  }
}
