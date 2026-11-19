import 'dart:convert';
import 'dart:typed_data';

import 'package:bankos_mobile/core/network/dio_provider.dart';
import 'package:bankos_mobile/core/theme/app_theme.dart';
import 'package:bankos_mobile/features/auth/data/repositories/auth_repository.dart';
import 'package:bankos_mobile/features/auth/domain/models/auth_models.dart';
import 'package:bankos_mobile/features/auth/presentation/providers/auth_provider.dart';
import 'package:bankos_mobile/features/auth/presentation/screens/login_screen.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

typedef _MockHandler = Future<ResponseBody> Function(RequestOptions options);

class _FakeHttpClientAdapter implements HttpClientAdapter {
  _FakeHttpClientAdapter(this.handler);

  final _MockHandler handler;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) {
    return handler(options);
  }

  @override
  void close({bool force = false}) {}
}

ResponseBody _jsonBody(Map<String, dynamic> payload, int statusCode) {
  return ResponseBody.fromString(
    jsonEncode(payload),
    statusCode,
    headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType],
    },
  );
}

class _StubAuthRepository extends AuthRepository {
  _StubAuthRepository({
    this.sessionToReturn,
    this.exceptionToThrow,
  }) : super(Dio());

  final AuthSession? sessionToReturn;
  final AuthException? exceptionToThrow;
  LoginRequest? lastRequest;

  @override
  Future<AuthSession> login(LoginRequest request) async {
    lastRequest = request;
    if (exceptionToThrow != null) {
      throw exceptionToThrow!;
    }
    return sessionToReturn!;
  }
}

void main() {
  group('AuthRepository', () {
    test('parses valid BankOS APIResponse login envelope', () async {
      RequestOptions? capturedOptions;
      final dio = Dio(BaseOptions(baseUrl: 'http://localhost:8000/api/v1'));
      dio.httpClientAdapter = _FakeHttpClientAdapter((options) async {
        capturedOptions = options;
        return _jsonBody(
          {
            'success': true,
            'internal_code': 'LOGIN_SUCCESS',
            'message': 'Inicio de sesión exitoso',
            'data': {
              'access_token': 'jwt-token-123',
              'token_type': 'bearer',
              'expires_in': 3600,
              'user_id': 'aaaaaaaa-0002-0000-0000-000000000001',
              'tenant_id': 'aaaaaaaa-0000-0000-0000-000000000001',
              'role': 'cliente',
            },
          },
          200,
        );
      });

      final repo = AuthRepository(dio);
      final session = await repo.login(
        const LoginRequest(
          tenantSlug: '  Banco-Andino ',
          email: ' Juan@Banco-Andino.com ',
          password: 'Cliente123!',
        ),
      );

      expect(capturedOptions?.path, '/auth/login');
      expect(capturedOptions?.data, {
        'tenant_slug': 'banco-andino',
        'email': 'juan@banco-andino.com',
        'password': 'Cliente123!',
      });
      expect(session.accessToken, 'jwt-token-123');
      expect(session.role, 'cliente');
      expect(session.tenantSlug, 'banco-andino');
    });

    test('maps 401 AUTHENTICATION_FAILED to AuthException', () async {
      final dio = Dio(BaseOptions(baseUrl: 'http://localhost:8000/api/v1'));
      dio.httpClientAdapter = _FakeHttpClientAdapter((options) async {
        return _jsonBody(
          {
            'success': false,
            'internal_code': 'AUTHENTICATION_FAILED',
            'message': 'Institución bancaria o credenciales no válidas',
            'data': null,
          },
          401,
        );
      });

      final repo = AuthRepository(dio);

      expect(
        () => repo.login(
          const LoginRequest(
            tenantSlug: 'banco-andino',
            email: 'juan@banco-andino.com',
            password: 'wrong-password',
          ),
        ),
        throwsA(
          isA<AuthException>()
              .having((e) => e.internalCode, 'internalCode',
                  'AUTHENTICATION_FAILED')
              .having((e) => e.statusCode, 'statusCode', 401)
              .having(
                (e) => e.message,
                'message',
                'Institución bancaria o credenciales no válidas',
              ),
        ),
      );
    });

    test('maps connectionError to helpful local API message', () async {
      final dio = Dio(BaseOptions(baseUrl: 'http://localhost:8000/api/v1'));
      dio.httpClientAdapter = _FakeHttpClientAdapter((options) async {
        throw DioException(
          requestOptions: options,
          type: DioExceptionType.connectionError,
          message: 'Connection refused',
        );
      });

      final repo = AuthRepository(dio);

      expect(
        () => repo.login(
          const LoginRequest(
            tenantSlug: 'banco-andino',
            email: 'juan@banco-andino.com',
            password: 'Cliente123!',
          ),
        ),
        throwsA(
          isA<AuthException>().having(
            (e) => e.internalCode,
            'internalCode',
            'CONNECTION_ERROR',
          ),
        ),
      );
    });
  });

  group('LoginScreen', () {
    Widget buildTestApp({required AuthRepository repository}) {
      final router = GoRouter(
        initialLocation: '/login',
        routes: [
          GoRoute(
            path: '/login',
            builder: (context, state) => const LoginScreen(),
          ),
          GoRoute(
            path: '/dashboard',
            builder: (context, state) => const Scaffold(
              body: Center(child: Text('DASHBOARD_READY')),
            ),
          ),
        ],
      );

      return ProviderScope(
        overrides: [
          authRepositoryProvider.overrideWithValue(repository),
        ],
        child: MaterialApp.router(
          theme: AppTheme.darkTheme,
          routerConfig: router,
        ),
      );
    }

    testWidgets('shows validation errors on empty submit', (tester) async {
      final repo = _StubAuthRepository();
      await tester.pumpWidget(buildTestApp(repository: repo));

      final submitFinder = find.text('Iniciar Sesión');
      await tester.ensureVisible(submitFinder);
      await tester.tap(submitFinder);
      await tester.pumpAndSettle();

      expect(
        find.text('Ingresa el identificador de tu institución (slug)'),
        findsOneWidget,
      );
      expect(
        find.text('Por favor ingresa tu correo electrónico'),
        findsOneWidget,
      );
      expect(find.text('Por favor ingresa tu contraseña'), findsOneWidget);
      expect(repo.lastRequest, isNull);
    });

    testWidgets('displays API error banner when authentication fails',
        (tester) async {
      final repo = _StubAuthRepository(
        exceptionToThrow: const AuthException(
          message: 'Institución bancaria o credenciales no válidas',
          internalCode: 'AUTHENTICATION_FAILED',
          statusCode: 401,
        ),
      );

      await tester.pumpWidget(buildTestApp(repository: repo));

      final fields = find.byType(TextFormField);
      await tester.enterText(fields.at(0), 'banco-andino');
      await tester.enterText(fields.at(1), 'juan@banco-andino.com');
      await tester.enterText(fields.at(2), 'ClaveMala1');

      final submitFinder = find.text('Iniciar Sesión');
      await tester.ensureVisible(submitFinder);
      await tester.tap(submitFinder);
      await tester.pumpAndSettle();

      expect(
        find.text('Institución bancaria o credenciales no válidas'),
        findsOneWidget,
      );
      expect(find.text('DASHBOARD_READY'), findsNothing);
    });

    testWidgets('navigates to /dashboard and saves JWT token on valid login',
        (tester) async {
      final repo = _StubAuthRepository(
        sessionToReturn: const AuthSession(
          accessToken: 'jwt-valid-token',
          tokenType: 'bearer',
          expiresIn: 3600,
          userId: 'user-1',
          tenantId: 'tenant-1',
          role: 'cliente',
          tenantSlug: 'banco-andino',
          email: 'juan@banco-andino.com',
        ),
      );

      late ProviderContainer container;
      final router = GoRouter(
        initialLocation: '/login',
        routes: [
          GoRoute(
            path: '/login',
            builder: (context, state) => const LoginScreen(),
          ),
          GoRoute(
            path: '/dashboard',
            builder: (context, state) => const Scaffold(
              body: Center(child: Text('DASHBOARD_READY')),
            ),
          ),
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authRepositoryProvider.overrideWithValue(repo),
          ],
          child: Consumer(
            builder: (context, ref, _) {
              container = ProviderScope.containerOf(context);
              return MaterialApp.router(
                theme: AppTheme.darkTheme,
                routerConfig: router,
              );
            },
          ),
        ),
      );

      final fields = find.byType(TextFormField);
      await tester.enterText(fields.at(0), 'banco-andino');
      await tester.enterText(fields.at(1), 'juan@banco-andino.com');
      await tester.enterText(fields.at(2), 'Cliente123!');

      final submitFinder = find.text('Iniciar Sesión');
      await tester.ensureVisible(submitFinder);
      await tester.tap(submitFinder);
      await tester.pumpAndSettle();

      expect(find.text('DASHBOARD_READY'), findsOneWidget);
      expect(container.read(authTokenProvider), 'jwt-valid-token');
      expect(container.read(authProvider).isAuthenticated, isTrue);
    });
  });
}
