import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:taxi_mobile/core/theme/theme_controller.dart';
import 'package:taxi_mobile/features/auth/auth_controller.dart';
import 'package:taxi_mobile/features/auth/auth_page.dart';
import 'package:taxi_mobile/features/auth/otp_page.dart';
import 'package:taxi_mobile/features/chat/chat_page.dart';
import 'package:taxi_mobile/features/chat/chats_page.dart';
import 'package:taxi_mobile/features/driver/browse_passenger_requests_page.dart';
import 'package:taxi_mobile/features/driver/create_trip_page.dart';
import 'package:taxi_mobile/features/driver/driver_blocked_page.dart';
import 'package:taxi_mobile/features/driver/driver_home_page.dart';
import 'package:taxi_mobile/features/driver/my_received_ratings_page.dart';
import 'package:taxi_mobile/features/driver/my_trips_page.dart';
import 'package:taxi_mobile/features/driver/trip_passengers_page.dart';
import 'package:taxi_mobile/features/notifications/notifications_page.dart';
import 'package:taxi_mobile/features/passenger/create_request_page.dart';
import 'package:taxi_mobile/features/passenger/my_ratings_page.dart';
import 'package:taxi_mobile/features/passenger/passenger_home_page.dart';
import 'package:taxi_mobile/features/passenger/rate_trip_page.dart';
import 'package:taxi_mobile/features/passenger/request_status_page.dart';
import 'package:taxi_mobile/features/role/role_page.dart';
import 'package:taxi_mobile/features/settings/profile_page.dart';
import 'package:taxi_mobile/features/settings/profile_setup_page.dart';
import 'package:taxi_mobile/features/settings/settings_page.dart';

class TaxiApp extends ConsumerWidget {
  const TaxiApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);

    final router = GoRouter(
      initialLocation: '/splash',
      routes: [
        GoRoute(path: '/splash', builder: (_, __) => const _SplashPage()),
        GoRoute(path: '/auth', builder: (_, __) => const AuthPage()),
        GoRoute(
          path: '/otp',
          builder: (_, state) {
            final reason =
                state.uri.queryParameters['reason'] ?? 'register';
            return OtpPage(reason: reason);
          },
        ),
        GoRoute(path: '/role', builder: (_, __) => const RolePage()),
        GoRoute(
            path: '/profile-setup',
            builder: (_, __) => const ProfileSetupPage()),
        GoRoute(path: '/profile', builder: (_, __) => const ProfilePage()),
        GoRoute(path: '/settings', builder: (_, __) => const SettingsPage()),
        GoRoute(path: '/driver', builder: (_, __) => const DriverHomePage()),
        GoRoute(
            path: '/driver-blocked',
            builder: (_, __) => const DriverBlockedPage()),
        GoRoute(
            path: '/driver/create-trip',
            builder: (_, __) => const CreateTripPage()),
        GoRoute(
            path: '/driver/my-trips', builder: (_, __) => const MyTripsPage()),
        GoRoute(
            path: '/driver/my-ratings',
            builder: (_, __) => const MyReceivedRatingsPage()),
        GoRoute(
            path: '/driver/open-requests',
            builder: (_, __) => const BrowsePassengerRequestsPage()),
        GoRoute(
          path: '/driver/trip-passengers/:id',
          builder: (_, state) {
            final id = int.parse(state.pathParameters['id']!);
            return TripPassengersPage(tripId: id);
          },
        ),
        GoRoute(
            path: '/passenger', builder: (_, __) => const PassengerHomePage()),
        GoRoute(
            path: '/passenger/create-request',
            builder: (_, __) => const CreateRequestPage()),
        GoRoute(
            path: '/passenger/rate-trip',
            builder: (_, __) => const RateTripPage()),
        GoRoute(
            path: '/passenger/my-ratings',
            builder: (_, __) => const MyRatingsPage()),
        GoRoute(
          path: '/passenger/request-status',
          builder: (_, state) {
            final q = state.uri.queryParameters['requestId'];
            final requestId = q == null ? null : int.tryParse(q);
            return RequestStatusPage(requestId: requestId);
          },
        ),
        GoRoute(path: '/chats', builder: (_, __) => const ChatsPage()),
        GoRoute(
            path: '/notifications',
            builder: (_, __) => const NotificationsPage()),
        GoRoute(
          path: '/chat/:id',
          builder: (_, state) {
            final id = int.parse(state.pathParameters['id']!);
            return ChatPage(chatId: id);
          },
        ),
      ],
    );

    return MaterialApp.router(
      debugShowCheckedModeBanner: false,
      title: 'SafarUz',
      themeMode: themeMode,
      theme: _buildLightTheme(),
      darkTheme: _buildDarkTheme(),
      builder: (context, child) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: isDark
                  ? const [
                      Color(0xFF0B1220),
                      Color(0xFF111B2E),
                      Color(0xFF0F172A)
                    ]
                  : const [
                      Color(0xFFE0EAFF),
                      Color(0xFFF4F8FF),
                      Color(0xFFEAFBF2)
                    ],
            ),
          ),
          child: child ?? const SizedBox.shrink(),
        );
      },
      routerConfig: router,
    );
  }
}

class _NoTransitionsBuilder extends PageTransitionsBuilder {
  const _NoTransitionsBuilder();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    return child;
  }
}

ThemeData _buildLightTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: const Color(0xFF0B7A75),
    brightness: Brightness.light,
    primary: const Color(0xFF0B7A75),
    secondary: const Color(0xFF145DA0),
  );
  final text = GoogleFonts.manropeTextTheme(ThemeData.light().textTheme);

  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: Colors.transparent,
    textTheme: text,
    pageTransitionsTheme: const PageTransitionsTheme(
      builders: {
        TargetPlatform.android: _NoTransitionsBuilder(),
        TargetPlatform.iOS: _NoTransitionsBuilder(),
      },
    ),
    appBarTheme: AppBarTheme(
      centerTitle: false,
      backgroundColor: Colors.white.withValues(alpha: 0.58),
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      titleTextStyle: text.titleLarge?.copyWith(
        fontWeight: FontWeight.w800,
        letterSpacing: -0.4,
        color: const Color(0xFF0F172A),
      ),
    ),
    cardTheme: CardThemeData(
      margin: const EdgeInsets.symmetric(vertical: 8),
      color: Colors.white.withValues(alpha: 0.84),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: Colors.black.withValues(alpha: 0.06)),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white.withValues(alpha: 0.9),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: Colors.black.withValues(alpha: 0.08)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: Colors.black.withValues(alpha: 0.08)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Color(0xFF0B7A75), width: 1.4),
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: Colors.white.withValues(alpha: 0.86),
      elevation: 0,
      height: 72,
      indicatorColor: scheme.primaryContainer.withValues(alpha: 0.9),
      labelTextStyle: WidgetStatePropertyAll(
        text.labelMedium?.copyWith(fontWeight: FontWeight.w700),
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: Colors.white.withValues(alpha: 0.96),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: const Color(0xFF0F172A).withValues(alpha: 0.92),
      contentTextStyle: text.bodyMedium?.copyWith(color: Colors.white),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        minimumSize: const Size.fromHeight(52),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        textStyle: text.titleMedium?.copyWith(fontWeight: FontWeight.w800),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size.fromHeight(52),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    ),
  );
}

ThemeData _buildDarkTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: const Color(0xFF2DD4BF),
    brightness: Brightness.dark,
  );
  final text = GoogleFonts.manropeTextTheme(ThemeData.dark().textTheme);

  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: Colors.transparent,
    textTheme: text,
    pageTransitionsTheme: const PageTransitionsTheme(
      builders: {
        TargetPlatform.android: _NoTransitionsBuilder(),
        TargetPlatform.iOS: _NoTransitionsBuilder(),
      },
    ),
    appBarTheme: AppBarTheme(
      centerTitle: false,
      backgroundColor: const Color(0xFF0F172A).withValues(alpha: 0.58),
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      titleTextStyle: text.titleLarge?.copyWith(
        fontWeight: FontWeight.w800,
        letterSpacing: -0.4,
        color: Colors.white,
      ),
    ),
    cardTheme: CardThemeData(
      margin: const EdgeInsets.symmetric(vertical: 8),
      color: const Color(0xFF0F172A).withValues(alpha: 0.72),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white.withValues(alpha: 0.06),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.18)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.18)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Color(0xFF2DD4BF), width: 1.4),
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: const Color(0xFF0F172A).withValues(alpha: 0.82),
      elevation: 0,
      height: 72,
      indicatorColor: scheme.primaryContainer.withValues(alpha: 0.4),
      labelTextStyle: WidgetStatePropertyAll(
        text.labelMedium?.copyWith(fontWeight: FontWeight.w700),
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: const Color(0xFF111827),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: const Color(0xFF020617).withValues(alpha: 0.95),
      contentTextStyle: text.bodyMedium?.copyWith(color: Colors.white),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        minimumSize: const Size.fromHeight(52),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        textStyle: text.titleMedium?.copyWith(fontWeight: FontWeight.w800),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size.fromHeight(52),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    ),
  );
}

class _SplashPage extends ConsumerStatefulWidget {
  const _SplashPage();

  @override
  ConsumerState<_SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends ConsumerState<_SplashPage> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() async {
      await ref.read(authControllerProvider.notifier).restore();
      final auth = ref.read(authControllerProvider);
      if (!mounted) return;
      if (!auth.isLoggedIn) {
        context.go('/auth');
      } else if (auth.role == 'driver') {
        final blocked = auth.profile?['driver_blocked'] == true;
        context.go(blocked ? '/driver-blocked' : '/driver');
      } else if (auth.role == 'passenger') {
        context.go('/passenger');
      } else {
        context.go('/role');
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: CircularProgressIndicator()));
  }
}
