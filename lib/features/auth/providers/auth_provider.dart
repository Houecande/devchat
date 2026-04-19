import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final supabaseClient = Supabase.instance.client;

// ─── Auth Change Notifier (pour go_router) ─────────────────
class AuthChangeNotifier extends ChangeNotifier {
  AuthChangeNotifier() {
    Supabase.instance.client.auth.onAuthStateChange.listen((_) {
      notifyListeners();
    });
  }
}

final authChangeNotifierProvider = Provider<AuthChangeNotifier>((ref) {
  return AuthChangeNotifier();
});

// ─── Stream auth state ─────────────────────────────────────
final authStateProvider = StreamProvider<AuthState>((ref) {
  return supabaseClient.auth.onAuthStateChange;
});

// ─── Utilisateur connecté ──────────────────────────────────
final currentUserProvider = Provider<User?>((ref) {
  return supabaseClient.auth.currentUser;
});

// ─── Auth Notifier (actions) ───────────────────────────────
class AuthNotifier extends StateNotifier<AsyncValue<void>> {
  AuthNotifier() : super(const AsyncValue.data(null));

  final _client = Supabase.instance.client;

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

  Future<void> signInWithGitHub() async {
  state = const AsyncValue.loading();
  try {
    await _client.auth.signInWithOAuth(
      OAuthProvider.github,
      redirectTo: 'https://houecande.github.io/devchat/',
    );
    state = const AsyncValue.data(null);
  } on AuthException catch (e) {
    state = AsyncValue.error(e.message, StackTrace.current);
  }
}

  Future<void> signOut() async {
    await _client.auth.signOut();
    state = const AsyncValue.data(null);
  }
}

final authNotifierProvider =
    StateNotifierProvider<AuthNotifier, AsyncValue<void>>(
  (ref) => AuthNotifier(),
);