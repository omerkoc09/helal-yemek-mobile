import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:caiz_mi/core/api/api_client.dart';
import 'package:caiz_mi/core/api/api_endpoints.dart';
import 'package:caiz_mi/core/auth/auth_provider.dart';
import 'package:caiz_mi/core/auth/token_storage.dart';
import 'package:caiz_mi/core/models/user.dart';

class MockApiClient extends Mock implements ApiClient {}

class MockTokenStorage extends Mock implements TokenStorage {}

Response<Map<String, dynamic>> _ok(Map<String, dynamic> data) => Response(
      data: data,
      statusCode: 200,
      requestOptions: RequestOptions(path: ''),
    );

DioException _dioError() => DioException(
      requestOptions: RequestOptions(path: ''),
      response: Response(statusCode: 401, requestOptions: RequestOptions(path: '')),
    );

// Backend'in döndüğü tipik token+user gövdesi.
Map<String, dynamic> _authBody({Map<String, dynamic>? user}) => {
      'access_token': 'acc-123',
      'refresh_token': 'ref-456',
      if (user != null) 'user': user,
    };

Map<String, dynamic> _user({String role = 'traveler'}) => {
      'id': 'u1',
      'email': 'a@b.com',
      'name': 'Ali',
      'role': role,
    };

void main() {
  late MockApiClient mockApi;
  late MockTokenStorage mockStorage;
  late ProviderContainer container;

  setUpAll(() {
    registerFallbackValue(RequestOptions(path: ''));
  });

  setUp(() {
    mockApi = MockApiClient();
    mockStorage = MockTokenStorage();
    // saveTokens/clearTokens varsayılan olarak başarılı.
    when(() => mockStorage.saveTokens(
          accessToken: any(named: 'accessToken'),
          refreshToken: any(named: 'refreshToken'),
        )).thenAnswer((_) async {});
    when(() => mockStorage.clearTokens()).thenAnswer((_) async {});

    container = ProviderContainer(overrides: [
      apiClientProvider.overrideWithValue(mockApi),
      tokenStorageProvider.overrideWithValue(mockStorage),
    ]);
  });

  tearDown(() => container.dispose());

  AuthNotifier notifier() => container.read(authProvider.notifier);
  AuthState state() => container.read(authProvider);

  group('login', () {
    test('başarılı giriş token saklar ve authenticated olur', () async {
      when(() => mockApi.post(ApiEndpoints.login, data: any(named: 'data')))
          .thenAnswer((_) async => _ok(_authBody(user: _user())));

      await notifier().login(email: 'a@b.com', password: 'sifre123');

      // Token doğru değerlerle saklanmalı.
      verify(() => mockStorage.saveTokens(
            accessToken: 'acc-123',
            refreshToken: 'ref-456',
          )).called(1);
      expect(state().status, AuthStatus.authenticated);
      expect(state().user?.id, 'u1');
      expect(state().isLoading, isFalse);
      expect(state().error, isNull);
    });

    test('hatalı giriş token SAKLAMAZ, error set eder, authenticated OLMAZ', () async {
      when(() => mockApi.post(ApiEndpoints.login, data: any(named: 'data')))
          .thenThrow(_dioError());

      await notifier().login(email: 'a@b.com', password: 'yanlis');

      verifyNever(() => mockStorage.saveTokens(
            accessToken: any(named: 'accessToken'),
            refreshToken: any(named: 'refreshToken'),
          ));
      expect(state().status, isNot(AuthStatus.authenticated));
      expect(state().error, isNotNull);
      expect(state().isLoading, isFalse);
    });
  });

  group('register', () {
    test('başarılı kayıt token saklar ve authenticated olur', () async {
      when(() => mockApi.post(ApiEndpoints.register, data: any(named: 'data')))
          .thenAnswer((_) async => _ok(_authBody(user: _user())));

      await notifier().register(
        name: 'Ali',
        surname: 'Veli',
        phone: '555',
        email: 'a@b.com',
        password: 'sifre123',
      );

      verify(() => mockStorage.saveTokens(
            accessToken: 'acc-123',
            refreshToken: 'ref-456',
          )).called(1);
      expect(state().status, AuthStatus.authenticated);
      expect(state().isLoading, isFalse);
    });

    test('hatalı kayıt token saklamaz ve error set eder', () async {
      when(() => mockApi.post(ApiEndpoints.register, data: any(named: 'data')))
          .thenThrow(_dioError());

      await notifier().register(
        name: 'Ali',
        surname: 'Veli',
        phone: '555',
        email: 'a@b.com',
        password: 'sifre123',
      );

      verifyNever(() => mockStorage.saveTokens(
            accessToken: any(named: 'accessToken'),
            refreshToken: any(named: 'refreshToken'),
          ));
      expect(state().error, isNotNull);
      expect(state().status, isNot(AuthStatus.authenticated));
    });
  });

  group('_handleAuthResponse (login üzerinden)', () {
    test('yanıtta user objesi varsa /me çağrılmaz', () async {
      when(() => mockApi.post(ApiEndpoints.login, data: any(named: 'data')))
          .thenAnswer((_) async => _ok(_authBody(user: _user(role: 'guide'))));

      await notifier().login(email: 'a@b.com', password: 'x');

      verifyNever(() => mockApi.get(ApiEndpoints.me));
      expect(state().user?.role, 'guide');
      expect(state().isGuide, isTrue);
    });

    test('yanıtta user yoksa /me endpoint\'inden çekilir', () async {
      when(() => mockApi.post(ApiEndpoints.login, data: any(named: 'data')))
          .thenAnswer((_) async => _ok(_authBody())); // user yok
      when(() => mockApi.get(ApiEndpoints.me))
          .thenAnswer((_) async => _ok(_user(role: 'admin')));

      await notifier().login(email: 'a@b.com', password: 'x');

      verify(() => mockApi.get(ApiEndpoints.me)).called(1);
      expect(state().user?.role, 'admin');
      expect(state().isAdmin, isTrue);
    });

    test('user yok + /me hata verse bile token var olduğu için authenticated sayılır', () async {
      when(() => mockApi.post(ApiEndpoints.login, data: any(named: 'data')))
          .thenAnswer((_) async => _ok(_authBody()));
      when(() => mockApi.get(ApiEndpoints.me)).thenThrow(_dioError());

      await notifier().login(email: 'a@b.com', password: 'x');

      // Token saklandı, kullanıcı bilgisi alınamadı ama oturum açık kabul edilir.
      verify(() => mockStorage.saveTokens(
            accessToken: 'acc-123',
            refreshToken: 'ref-456',
          )).called(1);
      expect(state().status, AuthStatus.authenticated);
      expect(state().user, isNull);
      expect(state().isLoading, isFalse);
    });
  });

  group('checkAuthStatus', () {
    test('token yoksa unauthenticated, /me çağrılmaz', () async {
      when(() => mockStorage.hasTokens()).thenAnswer((_) async => false);
      when(() => mockStorage.hasSeenOnboarding()).thenAnswer((_) async => true);

      await notifier().checkAuthStatus();

      verifyNever(() => mockApi.get(ApiEndpoints.me));
      expect(state().status, AuthStatus.unauthenticated);
    });

    test('token varsa ve /me başarılıysa authenticated', () async {
      when(() => mockStorage.hasTokens()).thenAnswer((_) async => true);
      when(() => mockStorage.hasSeenOnboarding()).thenAnswer((_) async => true);
      when(() => mockApi.get(ApiEndpoints.me))
          .thenAnswer((_) async => _ok(_user()));

      await notifier().checkAuthStatus();

      expect(state().status, AuthStatus.authenticated);
      expect(state().user?.id, 'u1');
    });

    test('token var ama /me hata verirse token temizlenir ve unauthenticated olur', () async {
      when(() => mockStorage.hasTokens()).thenAnswer((_) async => true);
      when(() => mockStorage.hasSeenOnboarding()).thenAnswer((_) async => false);
      when(() => mockApi.get(ApiEndpoints.me)).thenThrow(_dioError());

      await notifier().checkAuthStatus();

      verify(() => mockStorage.clearTokens()).called(1);
      expect(state().status, AuthStatus.unauthenticated);
      // onboarding bilgisi korunmalı.
      expect(state().hasSeenOnboarding, isFalse);
    });
  });

  group('logout', () {
    test('token temizler ve unauthenticated state\'e döner', () async {
      // Önce authenticated bir state kur.
      when(() => mockApi.post(ApiEndpoints.login, data: any(named: 'data')))
          .thenAnswer((_) async => _ok(_authBody(user: _user())));
      await notifier().login(email: 'a@b.com', password: 'x');
      expect(state().status, AuthStatus.authenticated);

      await notifier().logout();

      verify(() => mockStorage.clearTokens()).called(1);
      expect(state().status, AuthStatus.unauthenticated);
      expect(state().user, isNull);
    });
  });

  group('markOnboardingSeen / updateUser', () {
    test('markOnboardingSeen storage\'a yazar ve state\'i günceller', () async {
      when(() => mockStorage.markOnboardingSeen()).thenAnswer((_) async {});

      await notifier().markOnboardingSeen();

      verify(() => mockStorage.markOnboardingSeen()).called(1);
      expect(state().hasSeenOnboarding, isTrue);
    });

    test('updateUser mevcut kullanıcıyı değiştirir', () {
      notifier().updateUser(User.fromJson(_user(role: 'guide')));
      expect(state().user?.role, 'guide');
      expect(state().isGuide, isTrue);
    });
  });
}
