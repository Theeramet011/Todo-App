import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:todo_app/config/theme.dart';
import 'package:todo_app/screens/bin_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;

  test('bin screen and app themes are constructible', () {
    expect(const BinScreen(), isA<BinScreen>());
    expect(AppTheme.lightTheme.dialogTheme.backgroundColor, isNotNull);
    expect(AppTheme.darkTheme.dialogTheme.backgroundColor, isNotNull);
  });
}
