import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:todo_app/widgets/fast_completion_warning_dialog.dart';

void main() {
  testWidgets('fast completion warning dialog shows message and action', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: FastCompletionWarningDialog())),
    );

    expect(find.text(FastCompletionWarningDialog.message), findsOneWidget);
    expect(find.text('เข้าใจแล้ว'), findsOneWidget);
    expect(find.text('ไม่ได้รับ XP'), findsOneWidget);
  });
}
