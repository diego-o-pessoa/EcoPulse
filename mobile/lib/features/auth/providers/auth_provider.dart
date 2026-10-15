import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/network/api_client.dart';
import '../data/repositories/auth_repository.dart';
import '../data/models/user_model.dart';

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  final dio = ref.watch(apiClientProvider);
  return AuthRepository(dio);
});

class AuthState {
  final bool isLoading;
  final UserModel? user;
  final String? error;

  const AuthState({
    this.isLoading = false,
    this.user,
    this.error,
  });

  bool get isAuthenticated => user != null;

  AuthState copyWith({
    bool? isLoading,
    UserModel? user,
    String? error,
  }) {
    return AuthState(
      isLoading: isLoading ?? this.isLoading,
      user: user ?? this.user,
      error: error,
    );
  }
}

class AuthNotifier extends Notifier<AuthState> {
  @override
  AuthState build() {
    checkAuthStatus();
    return const AuthState(isLoading: true);
  }

  Future<void> checkAuthStatus() async {
    final repo = ref.read(authRepositoryProvider);
    final user = await repo.getMe();
    if (user != null) {
      state = state.copyWith(isLoading: false, user: user, error: null);
    } else {
      state = const AuthState(isLoading: false);
    }
  }

  Future<bool> login(String email, String password) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final repo = ref.read(authRepositoryProvider);
      final success = await repo.login(email, password);
      if (success) {
        await checkAuthStatus();
        return true;
      }
      state = state.copyWith(isLoading: false, error: 'Erro ao fazer login.');
      return false;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString().replaceAll('Exception: ', ''));
      return false;
    }
  }

  Future<bool> register({
    required String name,
    required String email,
    required String password,
    required String city,
  }) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final repo = ref.read(authRepositoryProvider);
      final success = await repo.register(
        name: name,
        email: email,
        password: password,
        city: city,
      );
      if (success) {
        await checkAuthStatus();
        return true;
      }
      state = state.copyWith(isLoading: false, error: 'Erro ao cadastrar.');
      return false;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString().replaceAll('Exception: ', ''));
      return false;
    }
  }

  Future<void> logout() async {
    final repo = ref.read(authRepositoryProvider);
    await repo.clearTokens();
    state = const AuthState(isLoading: false, user: null, error: null);
  }
}

final authProvider = NotifierProvider<AuthNotifier, AuthState>(() {
  return AuthNotifier();
});
