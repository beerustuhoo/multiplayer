import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'theme/app_theme.dart';
import 'services/api_service.dart';
import 'services/socket_service.dart';
import 'providers/auth_provider.dart';
import 'providers/game_provider.dart';
import 'screens/auth/login_screen.dart';
import 'screens/auth/register_screen.dart';
import 'screens/auth/verify_email_screen.dart';
import 'screens/auth/forgot_password_screen.dart';
import 'screens/home/home_screen.dart';
import 'screens/game/game_screen.dart';
import 'screens/game/bot_game_screen.dart';
import 'screens/search/search_screen.dart';

final GlobalKey<NavigatorState> appNavigatorKey = GlobalKey<NavigatorState>();
final GlobalKey<ScaffoldMessengerState> appScaffoldMessengerKey =
    GlobalKey<ScaffoldMessengerState>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  final apiService = ApiService();
  final socketService = SocketService();
  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    _handleCriticalError('A critical UI error occurred. Returning to lobby.');
  };
  PlatformDispatcher.instance.onError = (error, stack) {
    _handleCriticalError('A critical runtime error occurred. Returning to lobby.');
    return true;
  };

  runApp(
    MultiProvider(
      providers: [
        Provider<ApiService>.value(value: apiService),
        Provider<SocketService>.value(value: socketService),
        ChangeNotifierProvider(
          create: (_) => AuthProvider(api: apiService, socket: socketService),
        ),
        ChangeNotifierProvider(
          create: (_) => GameProvider(api: apiService, socket: socketService),
        ),
      ],
      child: const TicTacToeApp(),
    ),
  );
}

class TicTacToeApp extends StatelessWidget {
  const TicTacToeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Tic Tac Toe',
      debugShowCheckedModeBanner: false,
      navigatorKey: appNavigatorKey,
      scaffoldMessengerKey: appScaffoldMessengerKey,
      theme: AppTheme.darkTheme,
      home: const _SplashGate(),
      routes: {
        '/login': (_) => const LoginScreen(),
        '/register': (_) => const RegisterScreen(),
        '/verify-email': (_) => const VerifyEmailScreen(),
        '/forgot-password': (_) => const ForgotPasswordScreen(),
        '/home': (_) => const HomeScreen(),
        '/game': (_) => const GameScreen(),
        '/bot-game': (_) => const BotGameScreen(),
        '/search': (_) => const SearchScreen(),
      },
    );
  }
}

void _handleCriticalError(String message) {
  appNavigatorKey.currentState
      ?.pushNamedAndRemoveUntil('/home', (route) => false);
  appScaffoldMessengerKey.currentState?.showSnackBar(
    SnackBar(content: Text(message)),
  );
}

class _SplashGate extends StatelessWidget {
  const _SplashGate();

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    if (auth.isLoading) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.grid_3x3_rounded,
                  size: 80, color: AppTheme.primary),
              const SizedBox(height: 16),
              Text('Tic Tac Toe',
                  style: Theme.of(context)
                      .textTheme
                      .headlineMedium
                      ?.copyWith(
                          fontWeight: FontWeight.bold, color: Colors.white)),
              const SizedBox(height: 24),
              const CircularProgressIndicator(),
            ],
          ),
        ),
      );
    }

    if (!auth.isAuthenticated) {
      return const LoginScreen();
    }

    if (auth.user?.emailVerified == false) {
      return const VerifyEmailScreen();
    }

    return const HomeScreen();
  }
}
