import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:d1vai_app/main.dart';
import 'package:d1vai_app/providers/auth_provider.dart';
import 'package:d1vai_app/providers/locale_provider.dart';
import 'package:d1vai_app/providers/macos_menu_controller.dart';
import 'package:d1vai_app/providers/profile_provider.dart';
import 'package:d1vai_app/providers/project_provider.dart';
import 'package:d1vai_app/providers/theme_provider.dart';
import 'package:d1vai_app/services/macos_folder_import_service.dart';
import 'package:d1vai_app/services/macos_open_service.dart';

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
          ChangeNotifierProvider(create: (_) => MacosMenuController()),
          ChangeNotifierProvider.value(value: MacosOpenService.instance),
          ChangeNotifierProvider.value(
            value: MacosFolderImportService.instance,
          ),
        ],
        child: const MyApp(),
      ),
    );
    await tester.pump();

    expect(find.byType(MyApp), findsOneWidget);
    expect(tester.takeException(), isNull);

    // Ensure any delayed timers from the splash screen are flushed without
    // triggering navigation logic.
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 3));
  });
}
