import 'package:flutter_test/flutter_test.dart';
import 'package:todo_app/models/user.dart';

void main() {
  test('User reads legacy streak as current streak fallback', () {
    final user = User.fromMap({
      'name': 'Test User',
      'email': 'test@example.com',
      'avatarUrl': '',
      'totalXP': 3200,
      'currentLevel': 99,
      'streak': 6,
    }, 'user-1');

    expect(user.currentLevel, 7);
    expect(user.progressToNextLevel, 200);
    expect(user.nextLevelPoints, 500);
    expect(user.currentStreak, 6);
    expect(user.longestStreak, 6);
    expect(user.streak, 6);
  });
}
