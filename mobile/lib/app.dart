import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'features/auth/auth_controller.dart';
import 'features/auth/auth_page.dart';
import 'features/auth/otp_page.dart';
import 'features/chat/chat_page.dart';
import 'features/driver/browse_passenger_requests_page.dart';
import 'features/driver/create_trip_page.dart';
import 'features/driver/driver_home_page.dart';
import 'features/driver/my_trips_page.dart';
import 'features/passenger/create_request_page.dart';
import 'features/passenger/passenger_home_page.dart';
import 'features/passenger/request_status_page.dart';
import 'features/role/role_page.dart';

class TaxiApp extends ConsumerWidget {
  const TaxiApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = GoRouter(
      initialLocation: '/splash',
      routes: [
        GoRoute(path: '/splash', builder: (_, __) => const _SplashPage()),
        GoRoute(path: '/auth', builder: (_, __) => const AuthPage()),
        GoRoute(path: '/otp', builder: (_, __) => const OtpPage()),
        GoRoute(path: '/role', builder: (_, __) => const RolePage()),
        GoRoute(path: '/driver', builder: (_, __) => const DriverHomePage()),
        GoRoute(path: '/driver/create-trip', builder: (_, __) => const CreateTripPage()),
        GoRoute(path: '/driver/my-trips', builder: (_, __) => const MyTripsPage()),
        GoRoute(path: '/driver/open-requests', builder: (_, __) => const BrowsePassengerRequestsPage()),
        GoRoute(path: '/passenger', builder: (_, __) => const PassengerHomePage()),
        GoRoute(path: '/passenger/create-request', builder: (_, __) => const CreateRequestPage()),
        GoRoute(
          path: '/passenger/request-status',
          builder: (_, state) {
            final q = state.uri.queryParameters['requestId'];
            final requestId = q == null ? null : int.tryParse(q);
            return RequestStatusPage(requestId: requestId);
          },
        ),
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
      title: 'Surxon Taxi',
      theme: ThemeData(useMaterial3: true, colorSchemeSeed: Colors.green),
      routerConfig: router,
    );
  }
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
        context.go('/driver');
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
