// XPSystem Model - โมเดลระบบคำนวณค่าประสบการณ์และระดับเลเวล (XP & Level System)
//
// กำหนดโครงสร้างข้อมูลคำนวณเลเวลผู้ใช้งาน (LevelProgress) สถิติการทำภารกิจประจำวัน (PersonalTaskCounter)
// และฟังก์ชันแปลงค่า XP รวมเป็นระดับเลเวลปัจจุบันและเปอร์เซ็นต์ความคืบหน้า
import '../config/constants.dart';

class LevelProgress {
  final int currentLevel;
  final int progressXp;
  final int requiredXp;

  const LevelProgress({
    required this.currentLevel,
    required this.progressXp,
    required this.requiredXp,
  });

  double get progressValue {
    if (requiredXp <= 0) return 0;
    return (progressXp / requiredXp).clamp(0.0, 1.0);
  }
}

class PersonalTaskCounter {
  final int completedToday;
  final String resetDate;

  const PersonalTaskCounter({
    required this.completedToday,
    required this.resetDate,
  });
}

//แก้ไขเวลาที่ใช้ในการบล็อกกันกดเสร็จเร็ว
const fastCompletionRewardBlockThreshold = Duration(minutes: 5);

const milestoneRewards = <int, String>{
  5: 'bronze_frame',
  10: 'master_frame',
  15: 'ultimate_crown',
  20: 'diamond_frame',
  25: 'mythic_frame',
};

int getXpRequiredForNextLevel(int currentLevel) {
  return 500;
}

LevelProgress calculateLevelProgress(int totalXP) {
  final safeTotalXP = totalXP < 0 ? 0 : totalXP;
  const requiredXp = 500;

  int currentLevel = (safeTotalXP ~/ requiredXp) + 1;
  if (currentLevel > AppConstants.maxLevel) {
    currentLevel = AppConstants.maxLevel;
  }

  int progressXp = safeTotalXP % requiredXp;
  if (currentLevel == AppConstants.maxLevel) {
    progressXp = requiredXp; // Or 0, doesn't matter for max level
  }

  return LevelProgress(
    currentLevel: currentLevel,
    progressXp: progressXp,
    requiredXp: requiredXp,
  );
}

int calculateFinalXpWithLevelBonus(int currentXP, int xpDelta) {
  int newXP = currentXP + xpDelta;
  int currentCalculatedLevel = calculateLevelProgress(currentXP).currentLevel;

  while (true) {
    int nextLevel = calculateLevelProgress(newXP).currentLevel;
    if (nextLevel == currentCalculatedLevel) break;

    // Only award bonus if the new level is less than or equal to maxLevel
    // User said: "พอถึงเลเวล 25 แล้วไม่ต้องมีให้ คะแนน +50 อีก"
    for (int l = currentCalculatedLevel + 1; l <= nextLevel; l++) {
      if (l < AppConstants.maxLevel) {
        newXP += 50;
      }
    }

    currentCalculatedLevel = nextLevel;
  }

  if (newXP > AppConstants.maxXp) {
    newXP = AppConstants.maxXp;
  }

  return newXP < 0 ? 0 : newXP;
}

List<String> milestoneRewardIdsForLevelUp(int oldLevel, int newLevel) {
  if (newLevel <= oldLevel) return const [];

  final rewardIds = <String>[];
  for (var level = oldLevel + 1; level <= newLevel; level++) {
    final rewardId = milestoneRewards[level];
    if (rewardId != null) {
      rewardIds.add(rewardId);
    }
  }
  return rewardIds;
}

int calculateDiminishedPersonalTaskXp({
  required int baseXp,
  required int completedTaskNumber,
}) {
  return baseXp;
}

int calculateRestoredPersonalTaskXpRemoval({
  required int awardedXP,
  required int baseXP,
}) {
  if (awardedXP > 0) return awardedXP;
  return baseXP < 0 ? 0 : baseXP;
}

bool isCompletionRewardBlockedByAge({
  required DateTime createdAt,
  required DateTime completedAt,
  Duration threshold = fastCompletionRewardBlockThreshold,
}) {
  return completedAt.difference(createdAt) < threshold;
}

PersonalTaskCounter normalizePersonalTaskCounter({
  required int completedToday,
  required String? lastResetDate,
  required String todayString,
}) {
  if (lastResetDate == todayString) {
    return PersonalTaskCounter(
      completedToday: completedToday < 0 ? 0 : completedToday,
      resetDate: todayString,
    );
  }

  return PersonalTaskCounter(completedToday: 0, resetDate: todayString);
}
