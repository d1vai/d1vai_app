import 'package:d1vai_app/models/project.dart';
import 'package:d1vai_app/providers/locale_provider.dart';
import 'package:d1vai_app/providers/theme_provider.dart';
import 'package:d1vai_app/screens/docs_screen.dart';
import 'package:d1vai_app/screens/help_support_screen.dart';
import 'package:d1vai_app/screens/settings/developer_settings_screen.dart';
import 'package:d1vai_app/widgets/settings/settings_entry_hero.dart';
import 'package:d1vai_app/screens/login_screen.dart';
import 'package:d1vai_app/screens/projects/widgets/project_card_tile.dart';
import 'package:d1vai_app/utils/chat_entry.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _baseProject = UserProject(
  id: 'project-123',
  projectName: 'Customer portal',
  projectDescription: 'A production workspace for customer operations.',
  createdAt: '2026-08-01T00:00:00Z',
  updatedAt: '2026-08-02T00:00:00Z',
  userId: 1,
  projectPort: 3000,
  emoji: 'CP',
  tags: ['Next.js', 'Postgres'],
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('project entry opens chat and chooses code without a preview', () {
    expect(
      buildProjectChatDetailRoute(_baseProject),
      '/projects/project-123?tab=chat&chatTab=code',
    );
  });

  test('project entry opens the preview chat sub-tab when available', () {
    const project = UserProject(
      id: 'project-456',
      projectName: 'Storefront',
      projectDescription: 'Commerce storefront',
      createdAt: '2026-08-01T00:00:00Z',
      updatedAt: '2026-08-02T00:00:00Z',
      userId: 1,
      projectPort: 3000,
      latestPreviewUrl: 'https://preview.example.com',
    );

    expect(
      buildProjectChatDetailRoute(project),
      '/projects/project-456?tab=chat&chatTab=preview',
    );
  });

  testWidgets('compact project card fits and opens from the whole surface', (
    tester,
  ) async {
    var opened = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: 300,
              height: 174,
              child: ProjectCardTile(
                project: _baseProject,
                updatedText: '1h ago',
                onTap: () => opened = true,
              ),
            ),
          ),
        ),
      ),
    );

    await tester.pump();

    expect(tester.takeException(), isNull);
    await tester.tap(find.text('Customer portal'));
    expect(opened, isTrue);
  });

  testWidgets('project terminal action stays separate from the card action', (
    tester,
  ) async {
    var openedProject = false;
    var openedTerminal = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 360,
            height: 174,
            child: ProjectCardTile(
              project: _baseProject,
              updatedText: '1h ago',
              onTap: () => openedProject = true,
              onOpenTerminal: () => openedTerminal = true,
            ),
          ),
        ),
      ),
    );

    await tester.tap(
      find.byKey(const ValueKey('project-terminal-project-123')),
    );

    expect(openedTerminal, isTrue);
    expect(openedProject, isFalse);
  });

  testWidgets('project chat action stays separate from the card action', (
    tester,
  ) async {
    var openedProject = false;
    var openedChat = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 360,
            height: 174,
            child: ProjectCardTile(
              project: _baseProject,
              updatedText: '1h ago',
              onTap: () => openedProject = true,
              onOpenChat: () => openedChat = true,
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(const ValueKey('project-chat-project-123')));

    expect(openedChat, isTrue);
    expect(openedProject, isFalse);
  });

  testWidgets('login layout fits a mobile viewport', (tester) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => ThemeProvider()),
          ChangeNotifierProvider(create: (_) => LocaleProvider()),
        ],
        child: const MaterialApp(home: LoginScreen()),
      ),
    );
    await tester.pump();

    expect(find.byType(LoginScreen), findsOneWidget);
    expect(find.text('Welcome back'), findsNothing);
    expect(find.text('d1v'), findsNothing);
    expect(
      find.text(
        'Continuing signs you in. New accounts are created automatically.',
      ),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('login keeps secondary authentication choices collapsed', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => ThemeProvider()),
          ChangeNotifierProvider(create: (_) => LocaleProvider()),
        ],
        child: const MaterialApp(home: LoginScreen()),
      ),
    );
    await tester.pump();

    expect(find.text('Sign in with GitHub').hitTestable(), findsNothing);
    await tester.tap(find.text('More sign-in options'));
    await tester.pumpAndSettle();
    expect(find.text('Sign in with GitHub').hitTestable(), findsOneWidget);

    await tester.tap(find.text('More sign-in options'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Login with Password'));
    await tester.pumpAndSettle();
    expect(find.text('Login with Code'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('docs catalog fits a mobile viewport', (tester) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const MaterialApp(home: DocsScreen()));
    await tester.pump();

    expect(find.byType(DocsScreen), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('help and support keeps the docs catalog and email CTA', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: HelpSupportScreen()));
    await tester.pump();

    expect(find.text('Help & Support'), findsOneWidget);
    expect(find.text('Search docs, workflows, API, setup...'), findsOneWidget);
    expect(find.text('Browse all documents'), findsOneWidget);
    expect(find.text('Still need help?'), findsOneWidget);
    expect(find.text('Contact Support'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('developer settings is a standalone page with the entry hero', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: DeveloperSettingsScreen()));
    await tester.pump();

    expect(find.text('Developer'), findsWidgets);
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is Hero && widget.tag == SettingsEntryHero.developerTag,
      ),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });
}
