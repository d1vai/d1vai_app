import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'dart:async';
import 'core/api_client.dart';
import 'providers/auth_provider.dart';
import 'providers/locale_provider.dart';
import 'providers/project_provider.dart';
import 'providers/profile_provider.dart';
import 'providers/theme_provider.dart';
import 'router/app_router.dart';
import 'l10n/app_localizations.dart';
import 'core/theme/app_theme.dart';
import 'core/auth_expiry_bus.dart';
import 'services/stripe_payment_service.dart';

final _appRouter = createAppRouter();

Future<void> main() async {
  WidgetsBinding widgetsBinding = WidgetsFlutterBinding.ensureInitialized();
  FlutterNativeSplash.preserve(widgetsBinding: widgetsBinding);
  await ApiClient.ensureInitialized();
  await StripePaymentService.initialize();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => LocaleProvider()),
        ChangeNotifierProvider(create: (_) => ProjectProvider()),
        ChangeNotifierProvider(create: (_) => ProfileProvider()),
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
      ],
      child: const _AuthExpiryGate(child: MyApp()),
    ),
  );

  // Remove splash screen after initialization (simulated delay in SplashScreen)
  Future.delayed(const Duration(seconds: 1), () {
    FlutterNativeSplash.remove();
  });
}

@immutable
class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer2<LocaleProvider, ThemeProvider>(
      builder: (context, localeProvider, themeProvider, child) {
        return MaterialApp.router(
          debugShowCheckedModeBanner: false,
          title: 'd1vai',
          locale: localeProvider.locale,
          themeMode: themeProvider.flutterThemeMode,
          supportedLocales: LocaleProvider.supportedLocales,
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          theme: AppTheme.light,
          darkTheme: AppTheme.dark,
          routerConfig: _appRouter,
        );
      },
    );
  }
}

class _AuthExpiryGate extends StatefulWidget {
  final Widget child;

  const _AuthExpiryGate({required this.child});

  @override
  State<_AuthExpiryGate> createState() => _AuthExpiryGateState();
}

class _AuthExpiryGateState extends State<_AuthExpiryGate> {
  StreamSubscription<AuthExpiredEvent>? _sub;

  @override
  void initState() {
    super.initState();
    _sub = AuthExpiryBus.stream.listen((event) {
      if (!mounted) return;
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      authProvider.logout();
      _appRouter.go('/login?expired=1');
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    _sub = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}
