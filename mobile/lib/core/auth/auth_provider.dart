import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../api/api_client.dart';
import '../api/api_endpoints.dart';
import '../api/api_error.dart';
import '../models/user.dart';
import 'token_storage.dart';

// Token storage provider
final tokenStorageProvider = Provider<TokenStorage>((ref) {
  return TokenStorage();
});

// API client provider
final apiClientProvider = Provider<ApiClient>((ref) {
  final tokenStorage = ref.watch(tokenStorageProvider);
  return ApiClient(tokenStorage: tokenStorage);
});

// Auth durumu
enum AuthStatus { unknown, authenticated, unauthenticated }

class AuthState {
  final AuthStatus status;
  final User? user;
  final bool isLoading;
  final String? error;
  final bool hasSeenOnboarding;

  const AuthState({
    this.status = AuthStatus.unknown,
    this.user,
    this.isLoading = false,
    this.error,
    this.hasSeenOnboarding = true,
  });

  AuthState copyWith({
    AuthStatus? status,
    User? user,
    bool? isLoading,
    String? error,
    bool? hasSeenOnboarding,
  }) {
    return AuthState(
      status: status ?? this.status,
      user: user ?? this.user,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      hasSeenOnboarding: hasSeenOnboarding ?? this.hasSeenOnboarding,
    );
  }

  bool get isAuthenticated => status == AuthStatus.authenticated;
  bool get isAdmin => user?.role == 'admin';
  bool get isGuide => user?.role == 'guide';
  bool get isTraveler => user?.role == 'traveler';
}

class AuthNotifier extends Notifier<AuthState> {
  @override
  AuthState build() => const AuthState();

  ApiClient get _apiClient => ref.read(apiClientProvider);
  TokenStorage get _tokenStorage => ref.read(tokenStorageProvider);

  Future<void> checkAuthStatus() async {
    final results = await Future.wait([
      _tokenStorage.hasTokens(),
      _tokenStorage.hasSeenOnboarding(),
    ]);
    final hasTokens = results[0];
    final seenOnboarding = results[1];

    if (!hasTokens) {
      state = state.copyWith(
        status: AuthStatus.unauthenticated,
        hasSeenOnboarding: seenOnboarding,
      );
      return;
    }

    try {
      final response = await _apiClient.get(ApiEndpoints.me);
      final user = User.fromJson(response.data as Map<String, dynamic>);
      state = state.copyWith(
        status: AuthStatus.authenticated,
        user: user,
        hasSeenOnboarding: seenOnboarding,
      );
    } catch (_) {
      await _tokenStorage.clearTokens();
      state = state.copyWith(
        status: AuthStatus.unauthenticated,
        hasSeenOnboarding: seenOnboarding,
      );
    }
  }

  Future<void> markOnboardingSeen() async {
    await _tokenStorage.markOnboardingSeen();
    state = state.copyWith(hasSeenOnboarding: true);
  }

  Future<void> login({required String email, required String password}) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final response = await _apiClient.post(
        ApiEndpoints.login,
        data: {'email': email, 'password': password},
      );
      await _handleAuthResponse(response.data as Map<String, dynamic>);
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Giriş başarısız. Lütfen bilgilerinizi kontrol edin.',
      );
    }
  }

  Future<void> register({
    required String name,
    required String surname,
    required String phone,
    required String email,
    required String password,
  }) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final response = await _apiClient.post(
        ApiEndpoints.register,
        data: {
          'name': name,
          'surname': surname,
          'phone': phone,
          'email': email,
          'password': password,
        },
      );
      await _handleAuthResponse(response.data as Map<String, dynamic>);
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Kayıt başarısız. Lütfen tekrar deneyin.',
      );
    }
  }

  Future<void> signInWithGoogle() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final googleSignIn = GoogleSignIn.instance;
      final account = await googleSignIn.authenticate();
      final idToken = account.authentication.idToken;
      if (idToken == null) {
        state = state.copyWith(
          isLoading: false,
          error: 'Google token alınamadı.',
        );
        return;
      }
      final response = await _apiClient.post(
        ApiEndpoints.googleAuth,
        data: {'id_token': idToken},
      );
      await _handleAuthResponse(response.data as Map<String, dynamic>);
    } on GoogleSignInException catch (e) {
      if (e.code == GoogleSignInExceptionCode.canceled) {
        state = state.copyWith(isLoading: false);
        return;
      }
      state = state.copyWith(
        isLoading: false,
        error: 'Google ile giriş başarısız.',
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Google ile giriş başarısız.',
      );
    }
  }


  Future<void> logout() async {
    await _tokenStorage.clearTokens();
    state = const AuthState(status: AuthStatus.unauthenticated);
  }

  /// Hesabı kalıcı olarak siler ve oturumu kapatır.
  ///
  /// Sunucuda anonimleştirme uygulanır: kişisel veri temizlenir, kullanıcının
  /// eklediği mekanlar ve yorumlar anonim olarak kalır. Geri alınamaz.
  ///
  /// Hata mesajı döner; null ise silme başarılıdır.
  Future<String?> deleteAccount() async {
    try {
      await _apiClient.delete(ApiEndpoints.me);
      // Token'lar sunucudaki hesap gittiği için her durumda temizlenmeli.
      await logout();
      return null;
    } catch (e) {
      // Interceptor DioException'ı ApiError'a çeviriyor. Son admin engeli (403)
      // gibi sunucudan gelen anlamlı mesajlar kullanıcıya gösterilmeli.
      if (e is ApiError && e.message.isNotEmpty) return e.message;
      return 'Hesap silinemedi. Lütfen tekrar deneyin.';
    }
  }

  void updateUser(User user) {
    state = state.copyWith(user: user);
  }

  Future<void> _handleAuthResponse(Map<String, dynamic> data) async {
    await _tokenStorage.saveTokens(
      accessToken: data['access_token'] as String,
      refreshToken: data['refresh_token'] as String,
    );

    // Backend 'user' objesi dönerse kullan, dönmezse /me endpoint'inden çek
    if (data.containsKey('user') && data['user'] != null) {
      final user = User.fromJson(data['user'] as Map<String, dynamic>);
      state = state.copyWith(
        status: AuthStatus.authenticated,
        user: user,
        isLoading: false,
      );
    } else {
      try {
        final response = await _apiClient.get(ApiEndpoints.me);
        final user = User.fromJson(response.data as Map<String, dynamic>);
        state = state.copyWith(
          status: AuthStatus.authenticated,
          user: user,
          isLoading: false,
        );
      } catch (_) {
        // Token var ama kullanıcı bilgisi alınamadı, yine de authenticated say
        state = state.copyWith(
          status: AuthStatus.authenticated,
          isLoading: false,
        );
      }
    }
  }
}

final authProvider = NotifierProvider<AuthNotifier, AuthState>(
  AuthNotifier.new,
);
