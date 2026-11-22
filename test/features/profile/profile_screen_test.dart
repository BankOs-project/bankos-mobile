import 'dart:convert';
import 'dart:typed_data';

import 'package:bankos_mobile/core/network/dio_provider.dart';
import 'package:bankos_mobile/core/theme/theme_mode_provider.dart';
import 'package:bankos_mobile/features/auth/data/repositories/session_store.dart';
import 'package:bankos_mobile/features/auth/domain/models/auth_models.dart';
import 'package:bankos_mobile/features/auth/presentation/providers/auth_provider.dart';
import 'package:bankos_mobile/features/profile/presentation/profile_providers.dart';
import 'package:bankos_mobile/main.dart';
import 'package:dio/dio.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

const _oldEmail = 'cliente@example.com';
const _newEmail = 'nuevo@example.com';
const _address = 'Calle 10 # 20-30';
const _requestId = 'b2232afd-4d66-4416-8ebb-7a624415e92a';

final _png = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAIAAAADCAIAAAA2iEnWAAAAFElEQVR4nGPUDCpnYGBgYgADKAUAEfwA+NH21mQAAAAASUVORK5CYII=',
);

void main() {
  testWidgets(
    'edita perfil, protege la dirección y confirma el correo en la sesión',
    (tester) async {
      final (container, store, api) = await _launch(tester);
      api.failNextLoad = true;
      await _openProfile(tester);
      expect(find.text('No pudimos cargar tu perfil.'), findsOneWidget);
      await _tap(tester, 'Reintentar');
      expect(find.text('Sin dirección'), findsOneWidget);
      expect(_genericAvatar, findsOneWidget);
      expect(api.photoReads, 0);

      await _tap(tester, 'Editar perfil');
      expect(_field('address'), findsNothing);
      await _enter(tester, _field('full_name'), 'Al');
      await _enter(tester, _field('document_number'), '123');
      await _enter(tester, _field('phone'), '3012');
      await _tap(tester, 'Guardar');
      expect(
        find.text('Escribe entre 3 y 150 caracteres imprimibles.'),
        findsOneWidget,
      );
      expect(
        find.text('Indica o elimina el tipo y el número juntos.'),
        findsOneWidget,
      );
      expect(
        find.text('Usa + y entre 8 y 15 dígitos en formato internacional.'),
        findsOneWidget,
      );
      expect(api.patches, isEmpty);

      await _enter(tester, _field('full_name'), 'Ana Actualizada');
      await tester.ensureVisible(_field('document_type'));
      await tester.tap(_field('document_type'));
      await tester.pumpAndSettle();
      await _tap(tester, 'Cédula de extranjería');
      await _enter(tester, _field('document_number'), '0012345');
      await _enter(tester, _field('phone'), '+573001234567');
      api.rejectNextPatch = true;
      await _tap(tester, 'Guardar');
      expect(find.text('Celular rechazado por el servidor.'), findsOneWidget);
      expect(api.patches.single.containsKey('address'), isFalse);
      await _enter(tester, _field('phone'), '+573001234568');
      await _tap(tester, 'Editar dirección');
      await _enter(tester, _field('address'), _address);
      await _tap(tester, 'Guardar');

      expect(api.patches.last, {
        'full_name': 'Ana Actualizada',
        'document_type': 'CE',
        'document_number': '0012345',
        'phone': '+573001234568',
        'address': _address,
      });
      expect(find.text('Ana Actualizada'), findsOneWidget);
      expect(find.text('0012345'), findsOneWidget);
      expect(find.text(_address), findsNothing);
      await _tap(tester, 'Ver dirección');
      expect(find.text(_address), findsOneWidget);
      await _tap(tester, 'Ocultar dirección');
      expect(find.text(_address), findsNothing);
      expect(
        container.read(activeSessionProvider)?.accessToken,
        'token-andino',
      );
      expect(container.read(themeModeProvider).value, ThemeMode.light);

      await _back(tester);
      await tester.tap(find.byTooltip('Volver al Dashboard'));
      await tester.pumpAndSettle();
      expect(find.text('¡Hola, Ana Actualizada!'), findsOneWidget);
      expect(find.text('Banco Andino'), findsOneWidget);
      await _openProfile(tester);
      expect(find.text(_address), findsNothing);

      await _tap(tester, 'Cambiar correo');
      await _enter(
        tester,
        find.byKey(const Key('profile-new-email')),
        _newEmail,
      );
      await _enter(
        tester,
        find.byKey(const Key('profile-current-password')),
        'incorrecta',
      );
      await _tap(tester, 'Enviar código');
      expect(find.text('Comprueba la contraseña actual.'), findsOneWidget);
      expect(
        container.read(activeSessionProvider)?.accessToken,
        'token-andino',
      );

      await _enter(
        tester,
        find.byKey(const Key('profile-current-password')),
        'correcta',
      );
      api.limitNextEmail = true;
      await _tap(tester, 'Enviar código');
      expect(
        find.text('Espera 2 segundos antes de reintentar.'),
        findsOneWidget,
      );
      expect(
        tester
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, 'Enviar código'),
            )
            .onPressed,
        isNull,
      );
      await tester.pump(const Duration(seconds: 2));
      await _tap(tester, 'Enviar código');
      expect(find.textContaining('Cambio pendiente.'), findsOneWidget);
      expect(find.text(_oldEmail), findsOneWidget);
      expect((await store.read())?.email, _oldEmail);
      expect(
        container.read(pendingProfileEmailProvider)?.requestId,
        _requestId,
      );

      await _enter(
        tester,
        find.byKey(const Key('profile-email-code')),
        'incorrecto',
      );
      await _tap(tester, 'Confirmar correo');
      expect(find.text('El código es inválido o venció.'), findsOneWidget);
      expect(find.text(_oldEmail), findsOneWidget);

      await _enter(
        tester,
        find.byKey(const Key('profile-email-code')),
        'codigo-demo',
      );
      await _tap(tester, 'Confirmar correo');
      expect(find.text(_newEmail), findsOneWidget);
      expect(find.text(_oldEmail), findsNothing);
      expect(find.textContaining('Cambio pendiente.'), findsNothing);
      final verified = container.read(activeSessionProvider)!;
      expect(verified.email, _newEmail);
      expect(verified.accessToken, 'token-andino');
      expect(verified.tenantId, 'andino');
      expect((await store.read())?.email, _newEmail);
      expect(container.read(themeModeProvider).value, ThemeMode.light);
      await container.read(authProvider.notifier).logout();
      await tester.pumpAndSettle();
    },
  );

  testWidgets(
    'agrega, cambia y quita la foto privada y descarta el perfil al cambiar de banco',
    (tester) async {
      final (container, store, api) = await _launch(tester);
      await _openProfile(tester);
      expect(_genericAvatar, findsOneWidget);
      await _tap(tester, 'Agregar foto');
      expect(api.uploads, 1);
      expect(api.photoReads, 1);
      final renderedPhoto = find.descendant(
        of: find.byType(CircleAvatar),
        matching: find.byType(RawImage),
      );
      for (
        var attempt = 0;
        attempt < 10 && renderedPhoto.evaluate().isEmpty;
        attempt++
      ) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 20)),
        );
        await tester.pump();
      }
      expect(renderedPhoto, findsOneWidget);
      expect(find.text('Cambiar foto'), findsOneWidget);
      await _tap(tester, 'Cambiar foto');
      expect(api.uploads, 2);
      expect(api.photoReads, 2);
      await _tap(tester, 'Quitar foto');
      expect(api.photoDeletes, 1);
      expect(_genericAvatar, findsOneWidget);
      expect(find.text('Agregar foto'), findsOneWidget);

      await _tap(tester, 'Cambiar correo');
      await _enter(
        tester,
        find.byKey(const Key('profile-new-email')),
        _newEmail,
      );
      await _enter(
        tester,
        find.byKey(const Key('profile-current-password')),
        'correcta',
      );
      await _tap(tester, 'Enviar código');
      expect(container.read(pendingProfileEmailProvider)?.email, _newEmail);
      await _back(tester);
      await _openMenuProfile(tester);
      expect(find.textContaining('Cambio pendiente.'), findsOneWidget);
      await _back(tester);
      await _tap(tester, 'Cerrar sesión');
      expect(find.text('Elige tu banco'), findsOneWidget);
      expect(await store.read(), isNull);
      expect(container.read(pendingProfileEmailProvider), isNull);

      await _tap(tester, 'Cooperativa Caribe');
      final inputs = find.byType(TextFormField);
      await _enter(tester, inputs.first, 'caribe@example.com');
      await _enter(tester, inputs.last, 'correcta');
      await _tap(tester, 'Iniciar Sesión');
      await _openProfile(tester);
      expect(find.text('Cliente Caribe'), findsOneWidget);
      expect(find.text('caribe@example.com'), findsOneWidget);
      expect(find.text('Ana Original'), findsNothing);
      expect(find.text(_oldEmail), findsNothing);
      expect(find.textContaining('Cambio pendiente.'), findsNothing);
      expect(api.profileTenants.last, 'caribe');
      expect(container.read(themeModeProvider).value, ThemeMode.light);
      await container.read(authProvider.notifier).logout();
      await tester.pumpAndSettle();
    },
  );
}

Finder _field(String key) => find.byKey(Key('profile-$key'));
Finder get _genericAvatar =>
    find.widgetWithIcon(CircleAvatar, Icons.person_outline_rounded);

Future<void> _tap(WidgetTester tester, String text) async {
  final target = find.text(text).last;
  await tester.ensureVisible(target);
  await tester.pump();
  await tester.tap(target);
  await tester.pumpAndSettle();
}

Future<void> _enter(WidgetTester tester, Finder target, String text) async {
  await tester.ensureVisible(target);
  await tester.pump();
  await tester.enterText(target, text);
  await tester.pump();
}

Future<void> _back(WidgetTester tester) async {
  await tester.tap(find.byType(BackButton));
  await tester.pumpAndSettle();
}

Future<void> _openMenuProfile(WidgetTester tester) async {
  await _tap(tester, 'Perfil');
  expect(find.text('Mi perfil'), findsOneWidget);
}

Future<void> _openProfile(WidgetTester tester) async {
  await tester.tap(find.byTooltip('Abrir menú'));
  await tester.pumpAndSettle();
  await _openMenuProfile(tester);
}

Future<(ProviderContainer, SecureSessionStore, _ProfileApi)> _launch(
  WidgetTester tester,
) async {
  await tester.binding.setSurfaceSize(const Size(400, 950));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  FlutterSecureStorage.setMockInitialValues({'bankos.appearance.v1': 'light'});
  const store = SecureSessionStore(FlutterSecureStorage());
  await store.save(
    AuthSession(
      accessToken: 'token-andino',
      tokenType: 'bearer',
      expiresAt: DateTime.now().add(const Duration(hours: 1)),
      userId: 'andino-user',
      tenantId: 'andino',
      role: 'cliente',
      bankLabel: 'Banco Andino',
      email: _oldEmail,
    ),
  );
  final container = ProviderContainer(
    overrides: [
      sessionStoreProvider.overrideWithValue(store),
      profileFilePickerProvider.overrideWithValue(
        () async =>
            XFile.fromData(_png, name: 'demo.png', mimeType: 'image/png'),
      ),
    ],
  );
  addTearDown(container.dispose);
  final api = _ProfileApi();
  container.read(dioProvider).httpClientAdapter = api;
  await tester.pumpWidget(
    UncontrolledProviderScope(container: container, child: const BankOsApp()),
  );
  await tester.pumpAndSettle();
  return (container, store, api);
}

class _ProfileApi implements HttpClientAdapter {
  final patches = <Map<String, dynamic>>[];
  final profileTenants = <String>[];
  bool failNextLoad = false;
  bool rejectNextPatch = false;
  bool limitNextEmail = false;
  int uploads = 0;
  int photoReads = 0;
  int photoDeletes = 0;
  Uint8List? _photo;
  var _pendingEmail = '';

  final _andino = <String, dynamic>{
    'id': 'andino-user',
    'tenant_id': 'andino',
    'full_name': 'Ana Original',
    'email': _oldEmail,
    'role': 'cliente',
    'is_active': true,
  };

  final _caribe = <String, dynamic>{
    'id': 'caribe-user',
    'tenant_id': 'caribe',
    'full_name': 'Cliente Caribe',
    'email': 'caribe@example.com',
    'role': 'cliente',
    'is_active': true,
  };

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    ResponseBody response(int status, String code, Object? data) =>
        ResponseBody.fromString(
          jsonEncode({
            'success': status < 400,
            'internal_code': code,
            'data': data,
          }),
          status,
          headers: {
            Headers.contentTypeHeader: ['application/json'],
          },
        );

    final headers = options.headers;
    final request = (options.method, options.path);
    if (request == ('GET', '/banks')) {
      return response(200, 'BANKS', [
        {'bank_id': 'caribe', 'name': 'Cooperativa Caribe'},
      ]);
    }
    if (request == ('POST', '/auth/login')) {
      expect(options.data['bank_id'], 'caribe');
      return response(200, 'SUCCESS', {
        'access_token': 'token-caribe',
        'user_id': 'caribe-user',
        'tenant_id': 'caribe',
      });
    }
    expect(
      headers['Authorization'],
      anyOf('Bearer token-andino', 'Bearer token-caribe'),
    );
    final isAndino = headers['Authorization'] == 'Bearer token-andino';
    final profile = isAndino ? _andino : _caribe;
    switch (request) {
      case ('GET', '/auth/me'):
        profileTenants.add(profile['tenant_id'] as String);
        if (failNextLoad) {
          failNextLoad = false;
          return response(503, 'UNAVAILABLE', null);
        }
        return response(200, 'USER_PROFILE', profile);
      case ('PATCH', '/auth/me'):
        final fields = Map<String, dynamic>.from(options.data as Map);
        patches.add(fields);
        if (rejectNextPatch) {
          rejectNextPatch = false;
          return response(422, 'VALIDATION_ERROR', {
            'validation_errors': [
              {
                'field': 'body -> phone',
                'message': 'Celular rechazado por el servidor.',
              },
            ],
          });
        }
        profile.addAll(fields);
        return response(200, 'USER_PROFILE_UPDATED', profile);
      case ('PUT', '/auth/me/photo'):
        expect(isAndino, isTrue);
        expect(options.contentType, 'image/png');
        final bytes = await requestStream!.expand((chunk) => chunk).toList();
        expect(bytes, _png);
        _photo = Uint8List.fromList(bytes);
        profile['photo_url'] = '/api/v1/auth/me/photo';
        uploads++;
        return response(200, 'PROFILE_PHOTO_UPDATED', profile);
      case ('GET', '/auth/me/photo'):
        expect(isAndino, isTrue);
        expect(options.responseType, ResponseType.bytes);
        photoReads++;
        return ResponseBody.fromBytes(
          _photo!,
          200,
          headers: {
            Headers.contentTypeHeader: ['image/png'],
          },
        );
      case ('DELETE', '/auth/me/photo'):
        _photo = null;
        profile['photo_url'] = null;
        photoDeletes++;
        return response(200, 'PROFILE_PHOTO_REMOVED', profile);
      case ('POST', '/auth/me/email-change'):
        if (options.data['current_password'] != 'correcta') {
          return response(401, 'AUTHENTICATION_FAILED', null);
        }
        if (limitNextEmail) {
          limitNextEmail = false;
          return response(429, 'RATE_LIMIT_EXCEEDED', {
            'retry_after_seconds': 2,
          });
        }
        _pendingEmail = options.data['new_email'] as String;
        return response(202, 'PROFILE_EMAIL_PENDING', {
          'request_id': _requestId,
          'expires_in': 1200,
        });
      case ('POST', '/auth/me/email-change/verify'):
        expect(options.data['request_id'], _requestId);
        if (options.data['email_code'] != 'codigo-demo') {
          return response(400, 'PROFILE_EMAIL_INVALID', null);
        }
        profile['email'] = _pendingEmail;
        return response(200, 'PROFILE_EMAIL_UPDATED', profile);
      case ('GET', '/accounts'):
        return response(200, 'ACCOUNTS', {'items': [], 'total': 0, 'skip': 0});
      case ('GET', '/transactions/summary'):
        return response(200, 'SUMMARY', {
          'account_number': options.queryParameters['account_number'],
          'start_date': options.queryParameters['start_date'],
          'end_date': options.queryParameters['end_date'],
          'currencies': [],
        });
      default:
        fail('Ruta inesperada $request');
    }
  }
}
