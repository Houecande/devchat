import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../features/auth/providers/auth_provider.dart';
import '../features/auth/screens/splash_screen.dart';
import '../features/auth/screens/login_screen.dart';
import '../features/auth/screens/register_screen.dart';
import '../features/channels/screens/channels_screen.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final notifier = ref.watch(authChangeNotifierProvider);

  return GoRouter(
    initialLocation: '/splash',
    refreshListenable: notifier,
    redirect: (context, state) {
      final session = Supabase.instance.client.auth.currentSession;
      final isLoggedIn = session != null;
      final loc = state.matchedLocation;

      if (loc == '/splash') {
            return isLoggedIn ? '/channels' : '/login';
          }

      final isAuthRoute = loc == '/login' || loc == '/register';

      if (!isLoggedIn && !isAuthRoute) return '/login';
      if (isLoggedIn && isAuthRoute) return '/channels';

      return null;
    },
    routes: [
      GoRoute(
        path: '/splash',
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/register',
        builder: (context, state) => const RegisterScreen(),
      ),
      GoRoute(
        path: '/channels',
        builder: (context, state) => const ChannelsScreen(),
        routes: [
          GoRoute(
            path: ':channelId',
            builder: (context, state) {
              final channelId = state.pathParameters['channelId']!;
              final channelName = state.extra as String? ?? 'Salon';
              
              return ChannelsScreen(
                selectedChannelId: channelId,
                selectedChannelName: channelName,
              );
            },
          ),
        ],
      ),
    ],
  );
});
