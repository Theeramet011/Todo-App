class AppConstants {
  // Border Radius
  static const double radiusSmall = 8.0;
  static const double radiusMedium = 12.0;
  static const double radiusLarge = 16.0;
  static const double radiusXLarge = 20.0;
  static const double radiusCircular = 50.0;

  // Padding & Margin
  static const double paddingSmall = 8.0;
  static const double paddingMedium = 16.0;
  static const double paddingLarge = 24.0;
  static const double paddingXLarge = 32.0;

  // Icon Sizes
  static const double iconSmall = 16.0;
  static const double iconMedium = 24.0;
  static const double iconLarge = 32.0;
  static const double iconXLarge = 48.0;

  // Avatar Sizes
  static const double avatarSmall = 32.0;
  static const double avatarMedium = 40.0;
  static const double avatarLarge = 56.0;
  static const double avatarXLarge = 80.0;

  // Card Heights
  static const double cardHeightSmall = 80.0;
  static const double cardHeightMedium = 120.0;
  static const double cardHeightLarge = 160.0;

  // Animation Durations
  static const int animationDurationFast = 200;
  static const int animationDurationNormal = 300;
  static const int animationDurationSlow = 500;

  // Screen Names
  static const String screenLogin = 'login';
  static const String screenHome = 'home';
  static const String screenCalendar = 'calendar';
  static const String screenSettings = 'settings';
  static const String screenTaskDetail = 'task_detail';
  static const String screenFriends = 'friends';

  // Storage Keys
  static const String keyUserLoggedIn = 'user_logged_in';
  static const String keyUserData = 'user_data';
  static const String keyTasks = 'tasks';
  static const String keyProjects = 'projects';

  // API Endpoints (for future use)
  static const String baseUrl = 'https://api.taskmanager.com';
  static const String endpointLogin = '/auth/login';
  static const String endpointTasks = '/tasks';
  static const String endpointProjects = '/projects';
  static const String endpointFriends = '/friends';

  // Pagination
  static const int pageSize = 20;

  // Max Values
  static const int maxTaskTitleLength = 100;
  static const int maxCommentLength = 500;
  static const int maxMembersPerProject = 50;
  static const int maxLevel = 25;
  static const int maxXp = 12000;
}
