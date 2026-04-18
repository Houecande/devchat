import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final supabaseClient = Supabase.instance.client;

// Provider qui écoute l'état auth en temps réel
final authStateProvider = StreamProvider<AuthState>((ref) {
  return supabaseClient.auth.onAuthStateChange;
});

// Provider de l'utilisateur connecté
final currentUserProvider = Provider<User?>((ref) {
  return supabaseClient.auth.currentUser;
});

// Notifier pour les actions auth
class AuthNotifier extends StateNotifier<AsyncValue<void>> {
  AuthNotifier() : super(const AsyncValue.data(null));

  final _client = Supabase.instance.client;

  // Login email + password
  Future<void> signIn({
    required String email,
    required String password,
  }) async {
    state = const AsyncValue.loading();
    try {
      await _client.auth.signInWithPassword(
        email: email,
        password: password,
      );
      state = const AsyncValue.data(null);
    } on AuthException catch (e) {
      state = AsyncValue.error(e.message, StackTrace.current);
    }
  }

  // Register email + password
  Future<void> signUp({
    required String email,
    required String password,
    required String username,
  }) async {
    state = const AsyncValue.loading();
    try {
      await _client.auth.signUp(
        email: email,
        password: password,
        data: {'user_name': username},
      );
      state = const AsyncValue.data(null);
    } on AuthException catch (e) {
      state = AsyncValue.error(e.message, StackTrace.current);
    }
  }

  // GitHub OAuth
  Future<void> signInWithGitHub() async {
    state = const AsyncValue.loading();
    try {
      await _client.auth.signInWithOAuth(
        OAuthProvider.github,
        redirectTo: 'io.supabase.devchat://login-callback',
      );
      state = const AsyncValue.data(null);
    } on AuthException catch (e) {
      state = AsyncValue.error(e.message, StackTrace.current);
    }
  }

  // Logout
  Future<void> signOut() async {
    await _client.auth.signOut();
    state = const AsyncValue.data(null);
  }
}

final authNotifierProvider =
    StateNotifierProvider<AuthNotifier, AsyncValue<void>>(
  (ref) => AuthNotifier(),
);