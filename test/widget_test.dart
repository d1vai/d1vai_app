import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:d1vai_app/main.dart';
import 'package:d1vai_app/providers/auth_provider.dart';
import 'package:d1vai_app/providers/locale_provider.dart';
import 'package:d1vai_app/providers/profile_provider.dart';
import 'package:d1vai_app/providers/project_provider.dart';
import 'package:d1vai_app/providers/theme_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('App shows splash screen', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => AuthProvider()),
          ChangeNotifierProvider(create: (_) => LocaleProvider()),
          ChangeNotifierProvider(create: (_) => ProjectProvider()),
          ChangeNotifierProvider(create: (_) => ProfileProvider()),
          ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ],
        child: const MyApp(),
      ),
    );
    await tester.pump();

    expect(find.text('d1vai'), findsWidgets);

    // Ensure any delayed timers from the splash screen are flushed without
    // triggering navigation logic.
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 3));
  });
}
