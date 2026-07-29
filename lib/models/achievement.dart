import 'package:flutter/material.dart';

import '../config/colors.dart';
import 'user.dart';

class Achievement {
  final String id;
  final String title;
  final String description;
  final String type;
  final int targetValue;
  final IconData icon;
  final Color color;
  final String?
  unlockedImagePath; // Path สำหรับไฟล์รูปภาพเมื่อปลดล็อกแล้ว เช่น 'assets/images/achievements/badge_unlocked.png'
  final String?
  lockedImagePath; // Path สำหรับไฟล์รูปภาพเมื่อยังล็อกอยู่ เช่น 'assets/images/achievements/badge_locked.png'
  final int xpReward; // คะแนน XP ที่ได้รับเมื่อปลดล็อกสำเร็จ

  const Achievement({
    required this.id,
    required this.title,
    required this.description,
    required this.type,
    required this.targetValue,
    required this.icon,
    required this.color,
    this.unlockedImagePath,
    this.lockedImagePath,
    this.xpReward = 100, // ค่าเริ่มต้นคือ 100 XP
  });
}

class EvaluatedAchievement {
  final Achievement achievement;
  final int progressCount;
  final bool isUnlocked;

  const EvaluatedAchievement({
    required this.achievement,
    required this.progressCount,
    required this.isUnlocked,
  });

  int get targetCount => achievement.targetValue;
}

class AchievementEvaluation {
  final List<EvaluatedAchievement> all;

  const AchievementEvaluation(this.all);

  List<EvaluatedAchievement> get unlocked =>
      all.where((item) => item.isUnlocked).toList();

  List<EvaluatedAchievement> get locked =>
      all.where((item) => !item.isUnlocked).toList();

  int get unlockedCount => unlocked.length;
  int get totalCount => all.length;
  String get displayRatio => '$unlockedCount/$totalCount';
}

const List<Achievement> availableAchievements = [
  Achievement(
    id: 'pathfinder',
    title: 'นักบุกเบิก',
    description: 'ทำภารกิจส่วนตัวให้สำเร็จ 10 ภารกิจ',
    type: 'personal_tasks',
    targetValue: 10,
    icon: Icons.explore,
    color: AppColors.primaryBlue,
    unlockedImagePath: 'assets/images/achievements/pathfinder_unlocked.png',
    lockedImagePath: 'assets/images/achievements/pathfinder_locked.png',
    xpReward: 100,
  ),
  Achievement(
    id: 'task_master',
    title: 'เจ้าแห่งภารกิจ',
    description: 'ทำภารกิจส่วนตัวให้สำเร็จ 50 ภารกิจ',
    type: 'personal_tasks',
    targetValue: 50,
    icon: Icons.task_alt,
    color: AppColors.primaryPink,
    unlockedImagePath: 'assets/images/achievements/task_master_unlocked.png',
    lockedImagePath: 'assets/images/achievements/task_master_locked.png',
    xpReward: 300,
  ),
  Achievement(
    id: 'legendary_worker',
    title: 'นักทำภารกิจระดับตำนาน',
    description: 'ทำภารกิจส่วนตัวให้สำเร็จ 100 ภารกิจ',
    type: 'personal_tasks',
    targetValue: 100,
    icon: Icons.workspace_premium,
    color: AppColors.primaryPurple,
    unlockedImagePath:
        'assets/images/achievements/legendary_worker_unlocked.png',
    lockedImagePath: 'assets/images/achievements/legendary_worker_locked.png',
    xpReward: 500,
  ),
  Achievement(
    id: 'spark',
    title: 'ประกายไฟแรก',
    description: 'รักษา Streak ให้ได้ 3 วัน',
    type: 'streak',
    targetValue: 3,
    icon: Icons.local_fire_department,
    color: AppColors.accentOrange,
    unlockedImagePath: 'assets/images/achievements/spark_unlocked.png',
    lockedImagePath: 'assets/images/achievements/spark_locked.png',
    xpReward: 100,
  ),
  Achievement(
    id: 'on_fire',
    title: 'ไฟลุกไม่หยุด',
    description: 'รักษา Streak ให้ได้ 7 วัน',
    type: 'streak',
    targetValue: 7,
    icon: Icons.whatshot,
    color: AppColors.accentRed,
    unlockedImagePath: 'assets/images/achievements/on_fire_unlocked.png',
    lockedImagePath: 'assets/images/achievements/on_fire_locked.png',
    xpReward: 250,
  ),
  Achievement(
    id: 'unstoppable',
    title: 'ไม่มีใครหยุดได้',
    description: 'รักษา Streak ให้ได้ 30 วัน',
    type: 'streak',
    targetValue: 30,
    icon: Icons.bolt,
    color: AppColors.accentYellow,
    unlockedImagePath: 'assets/images/achievements/unstoppable_unlocked.png',
    lockedImagePath: 'assets/images/achievements/unstoppable_locked.png',
    xpReward: 1000,
  ),
  Achievement(
    id: 'team_player',
    title: 'เพื่อนร่วมทีม',
    description: 'ทำภารกิจกลุ่มโดยเป็นสมาชิกให้สำเร็จ 5 ภารกิจ',
    type: 'member_group_tasks',
    targetValue: 5,
    icon: Icons.groups,
    color: AppColors.primaryGreen,
    unlockedImagePath: 'assets/images/achievements/team_player_unlocked.png',
    lockedImagePath: 'assets/images/achievements/team_player_locked.png',
    xpReward: 200,
  ),
  Achievement(
    id: 'squad_captain',
    title: 'หัวหน้าทีม',
    description: 'ทำภารกิจกลุ่มโดยเป็นหัวหน้าให้สำเร็จ 20 ภารกิจ',
    type: 'leader_group_tasks',
    targetValue: 20,
    icon: Icons.emoji_events,
    color: AppColors.accentYellow,
    unlockedImagePath: 'assets/images/achievements/squad_captain_unlocked.png',
    lockedImagePath: 'assets/images/achievements/squad_captain_locked.png',
    xpReward: 500,
  ),
  Achievement(
    id: 'max_level',
    title: 'ผู้ก้าวข้ามขีดจำกัด',
    description: 'ปลดล็อก Level สูงสุดที่ 25',
    type: 'level',
    targetValue: 25,
    icon: Icons.star,

    color: AppColors.accentYellow,
    unlockedImagePath: 'assets/images/achievements/maxlevel_unlocked.png',
    lockedImagePath: 'assets/images/achievements/maxlevel_locked.png',
    xpReward: 50,
  ),
];

bool isAchievementUnlocked(User user, Achievement achievement) {
  return user.achievementsUnlocked.contains(achievement.id) ||
      achievementProgressValue(user, achievement) >= achievement.targetValue;
}

int unlockedAchievementCount(User user) {
  return evaluateAchievements(user).unlockedCount;
}

AchievementEvaluation evaluateAchievements(User user) {
  return AchievementEvaluation(
    availableAchievements
        .map(
          (achievement) => EvaluatedAchievement(
            achievement: achievement,
            progressCount: achievementProgressValue(user, achievement),
            isUnlocked: isAchievementUnlocked(user, achievement),
          ),
        )
        .toList(),
  );
}

List<String> mergedUnlockedAchievementIds({
  required Iterable<String> existingIds,
  required int tasksCompleted,
  required int currentStreak,
  required int groupTasksCompleted,
  required int memberGroupTasksCompleted,
  required int leaderGroupTasksCompleted,
  required int currentLevel,
}) {
  final unlockedIds = existingIds.toSet();
  for (final achievement in availableAchievements) {
    if (achievement.type == 'level') {
      if (currentLevel >= achievement.targetValue) {
        unlockedIds.add(achievement.id);
      }
    } else if (_progressValueForCounts(
          achievement,
          tasksCompleted: tasksCompleted,
          currentStreak: currentStreak,
          groupTasksCompleted: groupTasksCompleted,
          memberGroupTasksCompleted: memberGroupTasksCompleted,
          leaderGroupTasksCompleted: leaderGroupTasksCompleted,
        ) >=
        achievement.targetValue) {
      unlockedIds.add(achievement.id);
    }
  }
  return unlockedIds.toList();
}

int achievementProgressValue(User user, Achievement achievement) {
  if (achievement.type == 'level') {
    return user.currentLevel;
  }
  return _progressValueForCounts(
    achievement,
    tasksCompleted: user.tasksCompleted,
    currentStreak: user.currentStreak,
    groupTasksCompleted: user.groupTasksCompleted,
    memberGroupTasksCompleted: user.memberGroupTasksCompleted,
    leaderGroupTasksCompleted: user.leaderGroupTasksCompleted,
  );
}

int _progressValueForCounts(
  Achievement achievement, {
  required int tasksCompleted,
  required int currentStreak,
  required int groupTasksCompleted,
  required int memberGroupTasksCompleted,
  required int leaderGroupTasksCompleted,
}) {
  switch (achievement.type) {
    case 'personal_tasks':
      return tasksCompleted;
    case 'streak':
      return currentStreak;
    case 'group_tasks':
      return groupTasksCompleted;
    case 'member_group_tasks':
      return memberGroupTasksCompleted;
    case 'leader_group_tasks':
      return leaderGroupTasksCompleted;
    default:
      return 0;
  }
}

String achievementProgressUnit(Achievement achievement) {
  switch (achievement.type) {
    case 'streak':
      return 'วัน';
    case 'group_tasks':
    case 'member_group_tasks':
    case 'leader_group_tasks':
    case 'personal_tasks':
      return 'ภารกิจ';
    case 'level':
      return 'Level';
    default:
      return '';
  }
}
