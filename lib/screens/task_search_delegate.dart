import 'package:flutter/material.dart';
import '../models/task.dart';
import '../config/colors.dart';
import '../config/constants.dart';
import 'task_detail_screen.dart';
import 'package:provider/provider.dart';
import '../providers/task_provider.dart';
import '../widgets/priority_tag.dart';

class TaskSearchDelegate extends SearchDelegate {
  TaskSearchDelegate();

  @override
  ThemeData appBarTheme(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return theme.copyWith(
      appBarTheme: theme.appBarTheme.copyWith(
        backgroundColor: isDark
            ? AppColors.stormyNightBackground
            : theme.scaffoldBackgroundColor,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isDark ? AppColors.stormyDarkSlate : Colors.transparent,
        hintStyle: TextStyle(
          color: isDark
              ? AppColors.stormyMutedBlueGrey
              : theme.colorScheme.onSurface.withValues(alpha: 0.5),
        ),
        border: isDark
            ? OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide.none,
              )
            : InputBorder.none,
      ),
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: isDark
            ? AppColors.stormySkyBlue
            : theme.colorScheme.primary,
        selectionColor: isDark
            ? AppColors.stormySkyBlue.withValues(alpha: 0.3)
            : theme.colorScheme.primary.withValues(alpha: 0.3),
        selectionHandleColor: isDark
            ? AppColors.stormySkyBlue
            : theme.colorScheme.primary,
      ),
      textTheme: theme.textTheme.copyWith(
        titleLarge: TextStyle(
          color: isDark ? Colors.white : theme.colorScheme.onSurface,
        ),
      ),
    );
  }

  @override
  List<Widget>? buildActions(BuildContext context) {
    return [
      if (query.isNotEmpty)
        IconButton(
          icon: const Icon(Icons.clear),
          onPressed: () {
            query = '';
          },
        ),
    ];
  }

  @override
  Widget? buildLeading(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.arrow_back),
      onPressed: () {
        close(context, null);
      },
    );
  }

  @override
  Widget buildResults(BuildContext context) {
    return _buildSearchResults(context);
  }

  @override
  Widget buildSuggestions(BuildContext context) {
    return _buildSearchResults(context);
  }

  Widget _buildSearchResults(BuildContext context) {
    final theme = Theme.of(context);
    // Capture the provider at the beginning of the build method for a stable reference
    final taskProvider = Provider.of<TaskProvider>(context, listen: false);
    final allTasks = taskProvider.tasks;

    final results = allTasks.where((task) {
      if (task.isDeleted) return false;

      final queryLower = query.trim().toLowerCase();
      if (queryLower.isEmpty) return true;

      final titleMatch = task.title.toLowerCase().contains(queryLower);
      final descMatch = task.description.toLowerCase().contains(queryLower);
      return titleMatch || descMatch;
    }).toList();

    final isDark = theme.brightness == Brightness.dark;

    if (results.isEmpty) {
      return Container(
        color: isDark
            ? AppColors.stormyNightBackground
            : theme.scaffoldBackgroundColor,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.search_off,
                size: 80,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.1),
              ),
              const SizedBox(height: AppConstants.paddingMedium),
              Text(
                'ไม่พบผลลัพธ์สำหรับ "$query"',
                style: TextStyle(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Container(
      color: isDark
          ? AppColors.stormyNightBackground
          : theme.scaffoldBackgroundColor,
      child: ListView.builder(
        padding: const EdgeInsets.all(AppConstants.paddingMedium),
        itemCount: results.length,
        itemBuilder: (context, index) {
          final task = results[index];
          return _SearchTaskCard(
            task: task,
            taskProvider: taskProvider,
            onRefresh: () {
              // Force the SearchDelegate to rebuild its UI with latest data
              query = query;
            },
          );
        },
      ),
    );
  }
}

class _SearchTaskCard extends StatelessWidget {
  final Task task;
  final TaskProvider taskProvider;
  final VoidCallback onRefresh;

  const _SearchTaskCard({
    required this.task,
    required this.taskProvider,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      margin: const EdgeInsets.only(bottom: AppConstants.paddingSmall),
      decoration: BoxDecoration(
        color: theme.brightness == Brightness.dark
            ? AppColors.stormyDarkSlate
            : theme.cardColor,
        borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
        border: Border.all(
          color: theme.colorScheme.onSurface.withValues(alpha: 0.05),
        ),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.all(AppConstants.paddingMedium),
        onTap: () async {
          // Use the stable taskProvider reference
          taskProvider.selectTask(task);
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => TaskDetailScreen(task: task),
            ),
          );
          // Refresh the SearchDelegate state
          onRefresh();
        },
        title: Row(
          children: [
            Expanded(
              child: Text(
                task.title,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.onSurface,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            _buildTypeTag(context),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (task.description.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                task.description,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(
                  Icons.calendar_today,
                  size: 14,
                  color: theme.brightness == Brightness.dark
                      ? AppColors.stormySkyBlue
                      : AppColors.stormyMutedBlueGrey,
                ),
                const SizedBox(width: 4),
                Text(
                  _formatDate(task.dateTime),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.brightness == Brightness.dark
                        ? AppColors.stormySkyBlue
                        : AppColors.stormyMutedBlueGrey,
                  ),
                ),
                const Spacer(),
                _buildPriorityTag(context),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTypeTag(BuildContext context) {
    final isPersonal = task.isPersonal;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: (isPersonal ? AppColors.primaryBlue : AppColors.primaryPurple)
            .withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        isPersonal ? 'ส่วนตัว' : 'กลุ่ม',
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.bold,
          color: (isPersonal ? AppColors.primaryBlue : AppColors.primaryPurple),
        ),
      ),
    );
  }

  Widget _buildPriorityTag(BuildContext context) {
    return PriorityTag(priority: task.priorityLabel);
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
}
