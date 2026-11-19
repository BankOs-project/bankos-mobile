import 'dart:convert';
import 'dart:typed_data';

import 'package:bankos_mobile/core/network/dio_provider.dart';
import 'package:bankos_mobile/core/router/app_router.dart';
import 'package:bankos_mobile/core/theme/app_theme.dart';
import 'package:bankos_mobile/features/auth/data/repositories/auth_repository.dart';
import 'package:bankos_mobile/features/auth/domain/models/auth_models.dart';
import 'package:bankos_mobile/features/auth/presentation/providers/auth_provider.dart';
import 'package:bankos_mobile/features/auth/presentation/screens/login_screen.dart';
import 'package:bankos_mobile/main.dart';
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
  _StubAuthRepository({this.exceptionToThrow}) : super(Dio());

  final AuthException? exceptionToThrow;
  LoginRequest? lastRequest;

  @override
  Future<AuthSession> login(LoginRequest request) async {
    lastRequest = request;
    if (exceptionToThrow != null) {
      throw exceptionToThrow!;
    }
    throw StateError('No se esperaba una solicitud de inicio de sesión');
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

    testWidgets('el dashboard y Cuentas siguen al banco de la sesión activa',
        (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      final container = ProviderContainer();
      addTearDown(container.dispose);

      final profileTokens = <String>[];
      container.read(dioProvider).httpClientAdapter =
          _FakeHttpClientAdapter((options) async {
        if (options.path == '/auth/login') {
          final slug = (options.data as Map<String, dynamic>)['tenant_slug'];
          return _jsonBody({
            'success': true,
            'data': {
              'access_token': 'token-$slug',
              'user_id': 'user-$slug',
              'tenant_id': slug,
            },
          }, 200);
        }

        expect(options.path, '/auth/me');
        final token = options.headers['Authorization'] as String;
        profileTokens.add(token);
        return _jsonBody({
          'success': true,
          'data': {
            'full_name': token == 'Bearer token-banco-andino'
                ? 'Juan Pérez Gómez'
                : 'María Fernanda Lora',
          },
        }, 200);
      });

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const BankOsApp(),
        ),
      );
      await tester.pumpAndSettle();

      final router = container.read(appRouterProvider);
      router.go('/accounts');
      await tester.pumpAndSettle();
      expect(find.byType(LoginScreen), findsOneWidget);

      Future<void> login(String slug, String email) async {
        final fields = find.byType(TextFormField);
        await tester.enterText(fields.at(0), slug);
        await tester.enterText(fields.at(1), email);
        await tester.enterText(fields.at(2), 'Cliente123!');

        final submit = find.text('Iniciar Sesión');
        await tester.ensureVisible(submit);
        await tester.tap(submit);
        await tester.pumpAndSettle();
      }

      await login('banco-andino', 'juan@banco-andino.com');
      expect(find.text('Banco Andino'), findsOneWidget);
      expect(find.text('¡Hola, Juan Pérez Gómez!'), findsOneWidget);
      expect(container.read(authTokenProvider), 'token-banco-andino');

      await tester.tap(find.byKey(const Key('quick_action_accounts')));
      await tester.pumpAndSettle();
      expect(find.text('Banco Andino'), findsOneWidget);
      expect(find.text('Ahorros'), findsOneWidget);
      expect(find.text('Créditos'), findsOneWidget);
      expect(find.text('Tarjetas'), findsOneWidget);

      await tester.tap(find.text('Dashboard'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Cerrar sesión'));
      await tester.pumpAndSettle();
      expect(find.byType(LoginScreen), findsOneWidget);
      expect(container.read(authTokenProvider), isNull);

      await login('cooperativa-caribe', 'maria@cooperativa-caribe.com');
      expect(find.text('Cooperativa Caribe'), findsOneWidget);
      expect(find.text('¡Hola, María Fernanda Lora!'), findsOneWidget);
      expect(find.textContaining('Juan Pérez'), findsNothing);
      expect(profileTokens, containsAllInOrder([
        'Bearer token-banco-andino',
        'Bearer token-cooperativa-caribe',
      ]));
    });
  });
}
