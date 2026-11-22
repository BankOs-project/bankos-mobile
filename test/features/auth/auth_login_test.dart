import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:bankos_mobile/core/network/dio_provider.dart';
import 'package:bankos_mobile/core/router/app_router.dart';
import 'package:bankos_mobile/core/theme/app_theme.dart';
import 'package:bankos_mobile/core/theme/bank_surface_card.dart';
import 'package:bankos_mobile/core/theme/bank_theme.dart';
import 'package:bankos_mobile/features/accounts/presentation/screens/main_shell_screen.dart';
import 'package:bankos_mobile/features/accounts/presentation/widgets/dashboard_accounts_carousel.dart';
import 'package:bankos_mobile/features/accounts/presentation/providers/session_accounts_provider.dart';
import 'package:bankos_mobile/features/accounts/presentation/providers/dashboard_finances_provider.dart';
import 'package:bankos_mobile/features/auth/data/repositories/auth_repository.dart';
import 'package:bankos_mobile/features/auth/data/repositories/session_store.dart';
import 'package:bankos_mobile/features/auth/domain/models/auth_models.dart';
import 'package:bankos_mobile/features/auth/domain/models/public_bank.dart';
import 'package:bankos_mobile/features/auth/presentation/providers/auth_provider.dart';
import 'package:bankos_mobile/features/auth/presentation/screens/bank_selector_screen.dart';
import 'package:bankos_mobile/features/auth/presentation/screens/login_screen.dart';
import 'package:bankos_mobile/features/auth/presentation/screens/session_startup_screen.dart';
import 'package:bankos_mobile/features/auth/presentation/widgets/bank_logo.dart';
import 'package:bankos_mobile/features/operations/presentation/screens/operations_screen.dart';
import 'package:bankos_mobile/features/settings/presentation/screens/dashboard_menu_screen.dart';
import 'package:bankos_mobile/features/settings/presentation/screens/general_settings_screen.dart';
import 'package:bankos_mobile/main.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

typedef _MockHandler = Future<ResponseBody> Function(RequestOptions options);

const _andinoBank = PublicBank(
  id: '5db5cd19-4ca4-46b0-9520-58691ef3f5cd',
  name: 'Bánco Andino S.A.',
);
const _caribeBank = PublicBank(
  id: 'c543bf65-36af-4bda-9a67-937645ac72ca',
  name: 'Cooperativa Caribe Ltda.',
);

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

ResponseBody _bankDirectory({String? andinoLogo, String? caribeLogo}) =>
    _jsonBody({
      'success': true,
      'data': [
        for (final bank in [_andinoBank, _caribeBank])
          {
            'bank_id': bank.id,
            'name': bank.name,
            'logo_url': bank == _andinoBank ? andinoLogo : caribeLogo,
          },
      ],
    }, 200);

AuthSession _savedSession({required DateTime expiresAt, Uri? bankLogoUrl}) =>
    AuthSession(
      accessToken: 'stored-token',
      tokenType: 'bearer',
      expiresAt: expiresAt,
      userId: 'user-andino',
      tenantId: 'tenant-andino',
      role: 'cliente',
      bankLabel: 'Banco Andino',
      bankLogoUrl: bankLogoUrl,
      email: 'juan@banco-andino.com',
    );

ResponseBody _activeProfile({String tenant = 'tenant-andino'}) => _jsonBody({
  'success': true,
  'data': {
    'id': 'user-andino',
    'tenant_id': tenant,
    'role': 'cliente',
    'is_active': true,
    'full_name': 'Juan Pérez',
  },
}, 200);

ResponseBody _emptyAccounts() => _jsonBody({
  'success': true,
  'data': {'items': [], 'total': 0},
}, 200);

ResponseBody _summary(
  RequestOptions options, [
  List<Map<String, String>> totals = const [],
]) => _jsonBody({
  'success': true,
  'internal_code': 'FINANCIAL_SUMMARY_FETCHED',
  'data': {
    'account_number': options.queryParameters['account_number'],
    'start_date': options.queryParameters['start_date'],
    'end_date': options.queryParameters['end_date'],
    'currencies': totals,
  },
}, 200);

ProviderContainer _restoringContainer(
  SessionStore store,
  _MockHandler handler,
) {
  final container = ProviderContainer(
    overrides: [sessionStoreProvider.overrideWithValue(store)],
  );
  container.read(dioProvider).httpClientAdapter = _FakeHttpClientAdapter(
    (request) async => switch (request.path) {
      '/banks' => _bankDirectory(),
      '/transactions/summary' => _summary(request),
      _ => handler(request),
    },
  );
  return container;
}

Widget _restoringApp(ProviderContainer container) =>
    UncontrolledProviderScope(container: container, child: const BankOsApp());

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

ResponseBody _pendingRegistration(String id, {int ttl = 1200}) => _jsonBody({
  'success': true,
  'internal_code': 'REGISTRATION_PENDING',
  'data': {'registration_id': id, 'expires_in': ttl},
}, 202);

Future<void> _tapText(WidgetTester tester, String label) async {
  final target = find.text(label);
  await tester.ensureVisible(target);
  await tester.tap(target);
  await tester.pumpAndSettle();
}

Future<void> _openDashboardMenu(WidgetTester tester) async {
  await tester.tap(find.byTooltip('Abrir menú'));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 350));
  expect(find.byType(DashboardMenuScreen), findsOneWidget);
}

Future<void> _logoutFromMenu(WidgetTester tester) async {
  await _openDashboardMenu(tester);
  await tester.tap(find.text('Cerrar sesión'));
  await tester.pumpAndSettle();
}

Future<void> _enterRegistration(
  WidgetTester tester,
  PublicBank bank,
  String email,
) async {
  await _tapText(tester, bank.name);
  await _tapText(tester, 'Crear usuario');
  expect(find.text(bank.name), findsOneWidget);
  await tester.enterText(find.byType(TextFormField), email);
  await _tapText(tester, 'Solicitar código');
}

Future<void> _enterRegistrationDetails(
  WidgetTester tester,
  String code,
  String password,
) async {
  final fields = find.byType(TextFormField);
  await tester.enterText(fields.at(0), code);
  await tester.enterText(fields.at(1), 'Cliente de prueba');
  await tester.enterText(fields.at(2), password);
}

void main() {
  testWidgets('verifica dos registros con credenciales y bancos distintos', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(430, 950));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    const andinoEmail = 'cliente.andino@example.com';
    const caribeEmail = 'cliente.caribe@example.com';
    const andinoCode = 'correo-A_1';
    const caribeCode = 'correo-B_2';
    const andinoPassword = 'Clave-Andino-1';
    const caribePassword = 'Clave-Caribe-2';
    const registrations = {
      'alta-andino': (andinoCode, andinoPassword),
      'alta-caribe': (caribeCode, caribePassword),
    };
    final verified = <String>{};
    final requests = <Object?>[];
    final container = ProviderContainer(
      overrides: [sessionStoreProvider.overrideWithValue(null)],
    );
    addTearDown(container.dispose);
    container.read(dioProvider).httpClientAdapter = _FakeHttpClientAdapter((
      options,
    ) async {
      if (options.path == '/banks') return _bankDirectory();
      expect(options.headers['Authorization'], isNull);
      if (options.path == '/auth/register') {
        requests.add(options.data);
        final id = (options.data as Map)['bank_id'] == _andinoBank.id
            ? 'alta-andino'
            : 'alta-caribe';
        return _pendingRegistration(id);
      }
      expect(options.path, '/auth/register/verify');
      final body = options.data as Map;
      final id = body['registration_id'] as String;
      final (code, password) = registrations[id]!;
      expect(body, {
        'registration_id': id,
        'email_code': body['email_code'],
        'full_name': 'Cliente de prueba',
        'password': password,
      });
      if (body['email_code'] != code) {
        return _jsonBody({
          'success': false,
          'internal_code': 'REGISTRATION_INVALID',
          'message': 'Registro encontrado en otra institución.',
        }, 400);
      }
      verified.add(id);
      return _jsonBody({
        'success': true,
        'internal_code': 'REGISTRATION_VERIFIED',
      }, 201);
    });
    await tester.pumpWidget(_restoringApp(container));
    await tester.pumpAndSettle();
    container.read(appRouterProvider).go('/register');
    await tester.pumpAndSettle();
    expect(find.text('Elige tu banco'), findsOneWidget);

    await _enterRegistration(tester, _andinoBank, andinoEmail);
    await _enterRegistrationDetails(tester, andinoCode, andinoPassword);
    await _tapText(tester, 'Verificar y crear usuario');
    expect(verified, {'alta-andino'});
    expect(find.textContaining('Correo verificado.'), findsOneWidget);
    await _tapText(tester, 'Volver al login');
    expect(
      tester.widget<LoginScreen>(find.byType(LoginScreen)).bank.id,
      _andinoBank.id,
    );
    expect(find.byType(TextFormField), findsNWidgets(2));
    await _tapText(tester, 'Cambiar banco');

    await _enterRegistration(tester, _caribeBank, caribeEmail);
    await _enterRegistrationDetails(tester, andinoCode, caribePassword);
    await _tapText(tester, 'Verificar y crear usuario');
    expect(verified, {'alta-andino'});
    expect(find.textContaining('Revisa el código'), findsOneWidget);
    expect(find.textContaining('otra institución'), findsNothing);
    await tester.enterText(find.byType(TextFormField).first, caribeCode);
    await _tapText(tester, 'Verificar y crear usuario');
    expect(verified, {'alta-andino', 'alta-caribe'});
    await _tapText(tester, 'Volver al login');
    expect(
      tester.widget<LoginScreen>(find.byType(LoginScreen)).bank.id,
      _caribeBank.id,
    );
    expect(requests, [
      {'bank_id': _andinoBank.id, 'email': andinoEmail},
      {'bank_id': _caribeBank.id, 'email': caribeEmail},
    ]);
  });

  testWidgets('vence el código y reenvía para el mismo correo y banco', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(430, 950));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final container = ProviderContainer(
      overrides: [sessionStoreProvider.overrideWithValue(null)],
    );
    addTearDown(container.dispose);
    var attempts = 0;
    String? verifiedId;
    container.read(dioProvider).httpClientAdapter = _FakeHttpClientAdapter((
      options,
    ) async {
      if (options.path == '/banks') return _bankDirectory();
      if (options.path == '/auth/register') {
        expect(options.data, {
          'bank_id': _caribeBank.id,
          'email': 'nuevo@example.com',
        });
        return switch (++attempts) {
          1 => _pendingRegistration('primero', ttl: 1),
          2 => _jsonBody({'success': false}, 429),
          _ => _pendingRegistration('segundo'),
        };
      }
      expect(options.path, '/auth/register/verify');
      verifiedId = (options.data as Map)['registration_id'] as String;
      return _jsonBody({
        'success': true,
        'internal_code': 'REGISTRATION_VERIFIED',
      }, 201);
    });
    await tester.pumpWidget(_restoringApp(container));
    await tester.pumpAndSettle();
    await _enterRegistration(tester, _caribeBank, 'nuevo@example.com');
    await _enterRegistrationDetails(
      tester,
      'codigo-anterior',
      'Clave-nueva-123',
    );
    await tester.pump(const Duration(seconds: 2));
    expect(find.text('El código venció. Solicita uno nuevo.'), findsOneWidget);
    final verifyButton = find.widgetWithText(
      FilledButton,
      'Verificar y crear usuario',
    );
    expect(tester.widget<FilledButton>(verifyButton).onPressed, isNull);
    await _tapText(tester, 'Reenviar código');
    expect(
      find.text('Espera unos minutos antes de volver a intentarlo.'),
      findsOneWidget,
    );
    await _tapText(tester, 'Reenviar código');
    expect(attempts, 3);
    expect(find.text('El código venció. Solicita uno nuevo.'), findsNothing);
    expect(
      tester
          .widget<TextFormField>(find.byType(TextFormField).first)
          .controller!
          .text,
      isEmpty,
    );
    await tester.enterText(find.byType(TextFormField).first, 'codigo-nuevo');
    await _tapText(tester, 'Verificar y crear usuario');
    expect(verifiedId, 'segundo');
    await _tapText(tester, 'Volver al login');
  });

  testWidgets('muestra los cinco bancos nuevos y resuelve sus avatares', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    const validUrl = 'https://logos.example.com/bancolombia.png';
    const failedUrl = 'https://logos.example.com/daviplata.png';
    final image = Completer<ImageInfo>();
    final failedImage = Completer<ImageInfo>();
    final imageCache = PaintingBinding.instance.imageCache;
    for (final (url, result) in [(validUrl, image), (failedUrl, failedImage)]) {
      final key = NetworkImage(url);
      imageCache.putIfAbsent(
        key,
        () => OneFrameImageStreamCompleter(result.future),
      );
      addTearDown(() => imageCache.evict(key));
    }

    const names = ['Bancolombia', 'Nu', 'DaviPlata', 'Uno', 'Falabella'];
    final banks = [
      for (final (index, name) in names.indexed)
        {
          'bank_id': 'public-bank-$index',
          'name': name,
          'logo_url': switch (name) {
            'Bancolombia' => validUrl,
            'DaviPlata' => failedUrl,
            _ => null,
          },
        },
    ];
    final container = ProviderContainer(
      overrides: [sessionStoreProvider.overrideWithValue(null)],
    );
    addTearDown(container.dispose);
    container.read(dioProvider).httpClientAdapter = _FakeHttpClientAdapter((
      options,
    ) async {
      expect(options.path, '/banks');
      return _jsonBody({'success': true, 'data': banks}, 200);
    });
    await tester.pumpWidget(_restoringApp(container));
    await tester.pumpAndSettle();

    Finder tile(String name) => find.widgetWithText(ListTile, name);
    Finder fallback(String name) => find.descendant(
      of: tile(name),
      matching: find.byIcon(Icons.account_balance_outlined),
    );
    Finder localLogo(String bank, String asset) => find.descendant(
      of: tile(bank),
      matching: find.byWidgetPredicate(
        (widget) =>
            widget is Image &&
            widget.image == AssetImage('resources/images/bank_$asset.png'),
      ),
    );

    for (final name in names) {
      expect(tile(name), findsOneWidget);
      expect(
        find.descendant(of: tile(name), matching: find.byType(BankLogo)),
        findsOneWidget,
      );
    }
    expect(fallback('Bancolombia'), findsOneWidget);
    expect(fallback('DaviPlata'), findsOneWidget);
    expect(localLogo('Nu', 'nu'), findsOneWidget);
    expect(localLogo('Falabella', 'falabella'), findsOneWidget);
    expect(find.text('UNO'), findsOneWidget);

    final recorder = ui.PictureRecorder();
    ui.Canvas(recorder).drawColor(Colors.blue, BlendMode.src);
    final picture = recorder.endRecording();
    image.complete(ImageInfo(image: picture.toImageSync(160, 40)));
    picture.dispose();
    failedImage.completeError(StateError('404 de prueba'));
    await tester.pumpAndSettle();

    final loaded = find.descendant(
      of: tile('Bancolombia'),
      matching: find.byType(RawImage),
    );
    final logo = tester.widget<RawImage>(loaded);
    expect(logo.image?.width, 160);
    expect(logo.image?.height, 40);
    expect(logo.fit, BoxFit.contain);
    expect(fallback('Bancolombia'), findsNothing);
    expect(localLogo('Nu', 'nu'), findsOneWidget);
    expect(localLogo('DaviPlata', 'daviplata'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'DÁVIPLATA');
    await tester.pumpAndSettle();
    expect(tile('Bancolombia'), findsNothing);
    expect(tile('DaviPlata'), findsOneWidget);
    await tester.tap(localLogo('DaviPlata', 'daviplata'));
    await tester.pumpAndSettle();
    final login = tester.widget<LoginScreen>(find.byType(LoginScreen));
    expect(login.bank.name, 'DaviPlata');
    expect(login.bank.id, banks[2]['bank_id']);
    final loginLogo = tester.widget<BankLogo>(find.byType(BankLogo));
    expect(loginLogo.bankName, 'DaviPlata');
    expect(loginLogo.logoUrl.toString(), failedUrl);
  });

  testWidgets('busca sin acentos, selecciona y cambia de banco', (
    tester,
  ) async {
    final waiting = Completer<ResponseBody>();
    var requests = 0;
    final container = ProviderContainer(
      overrides: [sessionStoreProvider.overrideWithValue(null)],
    );
    addTearDown(container.dispose);
    container.read(dioProvider).httpClientAdapter = _FakeHttpClientAdapter((
      options,
    ) async {
      expect(options.path, '/banks');
      expect(options.headers['Authorization'], isNull);
      return ++requests == 1 ? waiting.future : _bankDirectory();
    });
    await tester.pumpWidget(_restoringApp(container));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 750));
    await tester.pump();
    expect(find.bySemanticsLabel('Cargando bancos'), findsOneWidget);

    waiting.complete(_jsonBody({'success': false}, 503));
    await tester.pumpAndSettle();
    expect(find.text('No pudimos cargar los bancos.'), findsOneWidget);
    await tester.tap(find.text('Reintentar'));
    await tester.pumpAndSettle();
    expect(find.text('Elige tu banco'), findsOneWidget);
    expect(find.text(_caribeBank.name), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'sin coincidencias');
    await tester.pump();
    expect(find.text('No encontramos bancos con ese nombre.'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'BANCO ANDÍNO');
    await tester.pumpAndSettle();
    expect(find.text(_andinoBank.name), findsOneWidget);
    expect(find.text(_caribeBank.name), findsNothing);

    await tester.tap(find.text(_andinoBank.name));
    await tester.pumpAndSettle();
    expect(find.byType(TextFormField), findsNWidgets(2));
    expect(find.text(_andinoBank.name), findsOneWidget);
    await tester.enterText(
      find.byType(TextFormField).first,
      'usuario@ejemplo.com',
    );
    await tester.ensureVisible(find.text('Cambiar banco'));
    await tester.tap(find.text('Cambiar banco'));
    await tester.pumpAndSettle();
    expect(find.byType(SessionStartupScreen), findsNothing);
    await tester.tap(find.text(_caribeBank.name));
    await tester.pumpAndSettle();
    expect(find.text(_caribeBank.name), findsOneWidget);
    expect(find.text('usuario@ejemplo.com'), findsNothing);

    container.read(appRouterProvider).go('/login');
    await tester.pumpAndSettle();
    expect(find.byType(BankSelectorScreen), findsOneWidget);
  });

  group('Restauración de sesión', () {
    const store = SecureSessionStore(FlutterSecureStorage());
    setUp(() => FlutterSecureStorage.setMockInitialValues({}));

    testWidgets('el menú usa BankOS y guarda el tema al reabrir la app', (
      tester,
    ) async {
      await store.save(
        _savedSession(expiresAt: DateTime.now().add(const Duration(hours: 1))),
      );
      final container = _restoringContainer(
        store,
        (options) async =>
            options.path == '/auth/me' ? _activeProfile() : _emptyAccounts(),
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(_restoringApp(container));
      await tester.pumpAndSettle();
      final dashboard = find.text('¡Hola, Juan Pérez!');
      ThemeData themeAt(Finder finder) => Theme.of(tester.element(finder));
      expect(
        themeAt(dashboard).colorScheme.primary,
        BankPalette.andino.darkAccent,
      );
      await _openDashboardMenu(tester);
      final menu = find.byType(DashboardMenuScreen);
      final logout = tester.widget<Text>(find.text('Cerrar sesión'));
      expect(logout.style?.fontWeight, FontWeight.bold);
      expect(logout.style?.decoration, TextDecoration.underline);
      expect(find.byIcon(Icons.power_settings_new_rounded), findsOneWidget);
      expect(
        themeAt(menu).colorScheme.primary,
        AppTheme.darkTheme.colorScheme.primary,
      );
      for (final option in ['Documentos y certificados', 'Ayuda']) {
        await _tapText(tester, option);
        final toast = find.byType(SnackBar);
        expect(find.text('Funcionalidad aún no disponible'), findsOneWidget);
        expect(
          tester.widget<SnackBar>(toast).behavior,
          SnackBarBehavior.floating,
        );
        await tester.pump(const Duration(seconds: 2));
        await tester.pumpAndSettle();
      }
      await tester.tap(find.byTooltip('Volver al Dashboard'));
      await tester.pumpAndSettle();
      expect(dashboard, findsOneWidget);

      await _openDashboardMenu(tester);
      await _tapText(tester, 'Configuración general');
      final settings = find.byType(GeneralSettingsScreen);
      final preferenceCard = find.widgetWithText(Card, 'Tema');
      expect(
        find.descendant(of: preferenceCard, matching: find.text('Idioma')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: preferenceCard, matching: find.text('Español')),
        findsOneWidget,
      );
      expect(
        tester.getTopLeft(find.text('Tema')).dy,
        lessThan(tester.getTopLeft(find.text('Idioma')).dy),
      );
      expect(themeAt(settings).extension<BankSurfaceColors>(), isNull);
      expect(themeAt(settings).brightness, Brightness.dark);
      await _tapText(tester, 'Claro');
      expect(themeAt(settings).brightness, Brightness.light);
      expect(
        themeAt(settings).colorScheme.primary,
        AppTheme.lightTheme.colorScheme.primary,
      );
      await _tapText(tester, 'Oscuro');
      expect(themeAt(settings).brightness, Brightness.dark);
      await _tapText(tester, 'Claro');
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      expect(
        themeAt(menu).colorScheme.primary,
        AppTheme.lightTheme.colorScheme.primary,
      );
      await tester.tap(find.byTooltip('Volver al Dashboard'));
      await tester.pumpAndSettle();
      expect(
        themeAt(dashboard).colorScheme.primary,
        BankPalette.andino.lightAccent,
      );

      await _logoutFromMenu(tester);
      expect(await store.read(), isNull);
      expect(themeAt(find.text('Elige tu banco')).brightness, Brightness.light);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();

      final reopened = _restoringContainer(store, (options) async {
        fail('No se esperaba una solicitud a ${options.path}');
      });
      addTearDown(reopened.dispose);
      await tester.pumpWidget(_restoringApp(reopened));
      await tester.pumpAndSettle();
      expect(themeAt(find.text('Elige tu banco')).brightness, Brightness.light);
    });

    testWidgets('sin sesión anima una vez y luego abre el selector', (
      tester,
    ) async {
      final container = _restoringContainer(store, (options) async {
        fail('No se esperaba una solicitud a ${options.path}');
      });
      addTearDown(container.dispose);
      final intro = find.byType(SessionStartupScreen);
      final opacity = find.descendant(
        of: intro,
        matching: find.byType(Opacity),
      );
      final scale = find.descendant(
        of: opacity,
        matching: find.byType(Transform),
      );
      final halo = find.descendant(
        of: intro,
        matching: find.byWidgetPredicate(
          (widget) =>
              widget is DecoratedBox &&
              widget.decoration is BoxDecoration &&
              (widget.decoration as BoxDecoration).gradient is RadialGradient,
        ),
      );

      await tester.pumpWidget(_restoringApp(container));
      await tester.pump();
      expect(tester.widget<Opacity>(opacity).opacity, 0);
      expect(tester.widget<Transform>(scale).transform.entry(0, 0), 0.86);
      await tester.pump(const Duration(milliseconds: 200));
      expect(tester.widget<Opacity>(opacity).opacity, inExclusiveRange(0, 1));
      expect(
        tester.widget<Transform>(scale).transform.entry(0, 0),
        inExclusiveRange(0.86, 1),
      );
      expect(halo, findsNothing);
      await tester.pump(const Duration(milliseconds: 300));
      expect(tester.widget<Opacity>(opacity).opacity, 1);
      expect(halo, findsOneWidget);
      expect(find.byType(BankSelectorScreen), findsNothing);
      await tester.pump(const Duration(milliseconds: 199));
      expect(intro, findsOneWidget);
      await tester.pump(const Duration(milliseconds: 1));
      await tester.pumpAndSettle();
      expect(intro, findsNothing);
      expect(find.byType(BankSelectorScreen), findsOneWidget);

      for (final state in [
        AppLifecycleState.inactive,
        AppLifecycleState.hidden,
        AppLifecycleState.paused,
        AppLifecycleState.hidden,
        AppLifecycleState.inactive,
        AppLifecycleState.resumed,
      ]) {
        tester.binding.handleAppLifecycleStateChanged(state);
        await tester.pump();
      }
      expect(intro, findsNothing);
      expect(find.byType(BankSelectorScreen), findsOneWidget);
    });

    testWidgets('una sesión válida espera el final de la intro', (
      tester,
    ) async {
      final logo = Uri.parse('https://logos.example.com/restored-andino.png');
      await store.save(
        _savedSession(
          expiresAt: DateTime.now().add(const Duration(hours: 1)),
          bankLogoUrl: logo,
        ),
      );
      final paths = <String>[];
      final container = _restoringContainer(store, (options) async {
        paths.add(options.path);
        return options.path == '/auth/me' ? _activeProfile() : _emptyAccounts();
      });
      addTearDown(container.dispose);

      await tester.pumpWidget(_restoringApp(container));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(paths, ['/auth/me']);
      expect(container.read(activeSessionProvider), isNotNull);
      expect(find.byType(SessionStartupScreen), findsOneWidget);
      expect(find.text('¡Hola, Juan Pérez!'), findsNothing);
      await tester.pumpAndSettle();
      expect(find.text('¡Hola, Juan Pérez!'), findsOneWidget);
      expect(tester.widget<BankLogo>(find.byType(BankLogo)).logoUrl, logo);
      expect(paths, ['/auth/me', '/accounts']);
      await _logoutFromMenu(tester);
      expect(find.byType(SessionStartupScreen), findsNothing);
      expect(find.byType(BankSelectorScreen), findsOneWidget);
    });

    testWidgets(
      'movimiento reducido omite la animación y la espera de 700 ms',
      (tester) async {
        tester.platformDispatcher.accessibilityFeaturesTestValue =
            const FakeAccessibilityFeatures(disableAnimations: true);
        addTearDown(
          tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
        );
        final container = _restoringContainer(store, (options) async {
          fail('No se esperaba una solicitud a ${options.path}');
        });
        addTearDown(container.dispose);

        await tester.pumpWidget(_restoringApp(container));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));
        expect(find.byType(SessionStartupScreen), findsNothing);
        expect(find.byType(BankSelectorScreen), findsOneWidget);
      },
    );

    testWidgets('reapertura verifica perfil antes de habilitar cuentas', (
      tester,
    ) async {
      final session = _savedSession(
        expiresAt: DateTime.now().add(const Duration(hours: 1)),
      );
      await store.save(session);
      final pendingProfile = Completer<ResponseBody>();
      final paths = <String>[];
      var rejectAccounts = false;
      final container = _restoringContainer(store, (options) async {
        paths.add(options.path);
        expect(options.headers['Authorization'], 'Bearer stored-token');
        if (options.path == '/auth/me') return pendingProfile.future;
        expect(options.path, '/accounts');
        return rejectAccounts
            ? _jsonBody({'success': false}, 401)
            : _emptyAccounts();
      });
      addTearDown(container.dispose);

      await tester.pumpWidget(_restoringApp(container));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));
      expect(find.text('Verificando sesión…'), findsNothing);
      expect(paths, ['/auth/me']);
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('Verificando sesión…'), findsOneWidget);
      expect(find.bySemanticsLabel('BankOS'), findsOneWidget);
      expect(container.read(authTokenProvider), isNull);
      expect(paths, ['/auth/me']);

      pendingProfile.complete(_activeProfile());
      await tester.pumpAndSettle();
      expect(find.text('¡Hola, Juan Pérez!'), findsOneWidget);
      expect(container.read(authTokenProvider), 'stored-token');
      expect(paths, ['/auth/me', '/accounts']);

      rejectAccounts = true;
      final restoredSession = container.read(activeSessionProvider)!;
      container.invalidate(sessionAccountsProvider(restoredSession));
      await tester.pump();
      await tester.pumpAndSettle();
      expect(paths, ['/auth/me', '/accounts', '/accounts']);
      expect(container.read(authTokenProvider), isNull);
      expect(container.read(activeSessionProvider), isNull);
      expect(find.byType(BankSelectorScreen), findsOneWidget);
      expect(await store.read(), isNull);
    });

    testWidgets('reapertura elimina un token vencido sin consultar la API', (
      tester,
    ) async {
      await store.save(
        _savedSession(
          expiresAt: DateTime.now().subtract(const Duration(minutes: 1)),
        ),
      );
      final container = _restoringContainer(store, (options) async {
        fail('No se esperaba una solicitud a ${options.path}');
      });
      addTearDown(container.dispose);

      await tester.pumpWidget(_restoringApp(container));
      await tester.pumpAndSettle();

      expect(find.byType(BankSelectorScreen), findsOneWidget);
      expect(
        find.text('La sesión venció. Inicia sesión de nuevo.'),
        findsOneWidget,
      );
      expect(await store.read(), isNull);
      expect(container.read(authTokenProvider), isNull);
    });

    for (final scenario in ['rechazado', 'de otro banco']) {
      testWidgets('reapertura elimina un token $scenario', (tester) async {
        await store.save(
          _savedSession(
            expiresAt: DateTime.now().add(const Duration(hours: 1)),
          ),
        );
        final container = _restoringContainer(store, (options) async {
          expect(options.path, '/auth/me');
          expect(options.headers['Authorization'], 'Bearer stored-token');
          return scenario == 'rechazado'
              ? _jsonBody({'success': false}, 401)
              : _activeProfile(tenant: 'otro-banco');
        });
        addTearDown(container.dispose);

        await tester.pumpWidget(_restoringApp(container));
        await tester.pumpAndSettle();

        expect(find.byType(BankSelectorScreen), findsOneWidget);
        expect(await store.read(), isNull);
        expect(container.read(authTokenProvider), isNull);
      });
    }

    testWidgets(
      'sin red conserva el token y verifica el perfil al reintentar',
      (tester) async {
        await store.save(
          _savedSession(
            expiresAt: DateTime.now().add(const Duration(hours: 1)),
          ),
        );
        var online = false;
        final container = _restoringContainer(store, (options) async {
          if (options.path == '/accounts') return _emptyAccounts();
          expect(options.path, '/auth/me');
          if (!online) {
            throw DioException(
              requestOptions: options,
              type: DioExceptionType.connectionError,
            );
          }
          return _activeProfile();
        });
        addTearDown(container.dispose);

        await tester.pumpWidget(_restoringApp(container));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 450));
        expect(find.byType(SessionStartupScreen), findsOneWidget);
        expect(find.text('No pudimos verificar tu sesión.'), findsNothing);
        await tester.pumpAndSettle();
        expect(find.text('No pudimos verificar tu sesión.'), findsOneWidget);
        expect(find.text('Borrar sesión e ir al ingreso'), findsOneWidget);
        expect(find.text('¡Hola, Juan Pérez!'), findsNothing);
        expect(container.read(authTokenProvider), isNull);
        expect((await store.read())?.accessToken, 'stored-token');

        online = true;
        await tester.tap(find.text('Reintentar'));
        await tester.pump();
        await tester.pumpAndSettle();
        expect(find.text('¡Hola, Juan Pérez!'), findsOneWidget);

        await _logoutFromMenu(tester);
        expect(find.byType(SessionStartupScreen), findsNothing);
        expect(find.byType(BankSelectorScreen), findsOneWidget);
        expect(await store.read(), isNull);

        final reopened = _restoringContainer(store, (options) async {
          fail('No se esperaba consultar el token borrado');
        });
        addTearDown(reopened.dispose);
        await tester.pumpWidget(_restoringApp(reopened));
        await tester.pumpAndSettle();
        expect(find.byType(BankSelectorScreen), findsOneWidget);
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpAndSettle();
      },
    );
  });

  group('AuthRepository', () {
    test(
      'el almacenamiento puede leer una sesión guardada antes del selector',
      () async {
        final expiry = DateTime.now().toUtc().add(const Duration(hours: 1));
        addTearDown(() => FlutterSecureStorage.setMockInitialValues({}));
        FlutterSecureStorage.setMockInitialValues({
          'bankos.auth.session.v1': jsonEncode({
            'access_token': 'token-anterior',
            'user_id': 'usuario',
            'tenant_id': 'tenant-autenticado',
            'tenant_slug': 'banco-andino',
            'email': 'usuario@example.com',
            'expires_at': expiry.toIso8601String(),
          }),
        });
        final session = await const SecureSessionStore(FlutterSecureStorage())
            .read();
        expect(session?.tenantId, 'tenant-autenticado');
        expect(session?.bankLabel, 'Banco Andino');
      },
    );

    test('parses valid BankOS APIResponse login envelope', () async {
      RequestOptions? capturedOptions;
      final dio = Dio(BaseOptions(baseUrl: 'http://localhost:8000/api/v1'));
      dio.httpClientAdapter = _FakeHttpClientAdapter((options) async {
        capturedOptions = options;
        return _jsonBody({
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
        }, 200);
      });

      final repo = AuthRepository(dio);
      final session = await repo.login(
        LoginRequest(
          bankId: _andinoBank.id,
          bankName: _andinoBank.name,
          email: ' Juan@Banco-Andino.com ',
          password: 'Cliente123!',
        ),
      );

      expect(capturedOptions?.path, '/auth/login');
      expect(capturedOptions?.data, {
        'bank_id': _andinoBank.id,
        'email': 'juan@banco-andino.com',
        'password': 'Cliente123!',
      });
      expect(session.accessToken, 'jwt-token-123');
      expect(session.role, 'cliente');
      expect(session.bankLabel, _andinoBank.name);
    });

    test('maps 401 AUTHENTICATION_FAILED to AuthException', () async {
      final dio = Dio(BaseOptions(baseUrl: 'http://localhost:8000/api/v1'));
      dio.httpClientAdapter = _FakeHttpClientAdapter((options) async {
        return _jsonBody({
          'success': false,
          'internal_code': 'AUTHENTICATION_FAILED',
          'message': 'Institución bancaria o credenciales no válidas',
          'data': null,
        }, 401);
      });

      final repo = AuthRepository(dio);

      expect(
        () => repo.login(
          LoginRequest(
            bankId: _andinoBank.id,
            bankName: _andinoBank.name,
            email: 'juan@banco-andino.com',
            password: 'wrong-password',
          ),
        ),
        throwsA(
          isA<AuthException>()
              .having(
                (e) => e.internalCode,
                'internalCode',
                'AUTHENTICATION_FAILED',
              )
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
          LoginRequest(
            bankId: _andinoBank.id,
            bankName: _andinoBank.name,
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
    testWidgets('centra ambos logos sobre el formulario en ambos temas', (
      tester,
    ) async {
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      for (final (width, theme, bank) in [
        (
          320.0,
          AppTheme.lightTheme,
          const PublicBank(id: '32', name: 'Bancolombia'),
        ),
        (320.0, AppTheme.darkTheme, const PublicBank(id: '33', name: 'Nu')),
        (
          520.0,
          AppTheme.lightTheme,
          const PublicBank(id: '32', name: 'Bancolombia'),
        ),
        (520.0, AppTheme.darkTheme, const PublicBank(id: '33', name: 'Nu')),
      ]) {
        tester.view.physicalSize = Size(width, 900);
        await tester.pumpWidget(
          ProviderScope(
            overrides: [sessionStoreProvider.overrideWithValue(null)],
            child: MaterialApp(
              theme: theme,
              home: LoginScreen(key: ValueKey(bank.id), bank: bank),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final block = find.byKey(const Key('login_brand_logos'));
        final logo = find.descendant(
          of: block,
          matching: find.byType(BankLogo),
        );
        final pair = tester.getRect(block);
        expect(pair.center.dx, closeTo(width / 2, 1));
        expect(pair.width, lessThan(170));
        expect(tester.getRect(logo).right, closeTo(pair.right, 1));
        expect(tester.widget<BankLogo>(logo).bankName, bank.name);
        expect(
          tester.getTopLeft(find.byType(TextFormField).first).dy,
          greaterThan(pair.bottom),
        );
        expect(tester.takeException(), isNull);
      }
    });

    Widget buildTestApp({required AuthRepository repository}) {
      final router = GoRouter(
        initialLocation: '/login',
        routes: [
          GoRoute(
            path: '/login',
            builder: (context, state) => const LoginScreen(bank: _andinoBank),
          ),
          GoRoute(
            path: '/dashboard',
            builder: (context, state) =>
                const Scaffold(body: Center(child: Text('DASHBOARD_READY'))),
          ),
        ],
      );

      return ProviderScope(
        overrides: [authRepositoryProvider.overrideWithValue(repository)],
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

      expect(find.byType(TextFormField), findsNWidgets(2));
      expect(
        find.text('Por favor ingresa tu correo electrónico'),
        findsOneWidget,
      );
      expect(find.text('Por favor ingresa tu contraseña'), findsOneWidget);
      expect(repo.lastRequest, isNull);
    });

    testWidgets('displays API error banner when authentication fails', (
      tester,
    ) async {
      final repo = _StubAuthRepository(
        exceptionToThrow: const AuthException(
          message: 'Institución bancaria o credenciales no válidas',
          internalCode: 'AUTHENTICATION_FAILED',
          statusCode: 401,
        ),
      );

      await tester.pumpWidget(buildTestApp(repository: repo));

      final fields = find.byType(TextFormField);
      await tester.enterText(fields.at(0), 'juan@banco-andino.com');
      await tester.enterText(fields.at(1), 'ClaveMala1');

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

    testWidgets('el dashboard y Cuentas siguen al banco de la sesión activa', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      FlutterSecureStorage.setMockInitialValues({});
      const store = SecureSessionStore(FlutterSecureStorage());
      final container = ProviderContainer(
        overrides: [sessionStoreProvider.overrideWithValue(store)],
      );
      addTearDown(container.dispose);

      // Las respuestas pendientes las controla el doble de transporte.
      container.read(dioProvider).options.receiveTimeout = Duration.zero;
      final profileTokens = <String>[];
      final accountsTokens = <String>[];
      final caribeFilters = <Object?>[];
      const andinoLogo = 'https://logos.example.com/andino.png';
      const caribeLogo = 'https://logos.example.com/caribe.png';
      final lateAndino = Completer<ResponseBody>();
      final caribeRetry = Completer<ResponseBody>();
      CancelToken? pendingAndinoToken;
      var delayAndino = false;
      var caribeRequests = 0;

      Map<String, dynamic> account(
        String tenant,
        String number,
        String balance,
        String currency,
        String status,
      ) => {
        'tenant_id': tenant,
        'owner_id': 'user-$tenant',
        'account_number': number,
        'balance': balance,
        'currency': currency,
        'status': status,
      };

      ResponseBody accounts(List<Map<String, dynamic>> items) => _jsonBody({
        'success': true,
        'data': {
          'total': items.length,
          'skip': 0,
          'limit': 100,
          'items': items,
        },
      }, 200);

      container.read(dioProvider).httpClientAdapter = _FakeHttpClientAdapter((
        options,
      ) async {
        if (options.path == '/banks') {
          return _bankDirectory(andinoLogo: andinoLogo, caribeLogo: caribeLogo);
        }
        if (options.path == '/auth/login') {
          final body = options.data as Map<String, dynamic>;
          final bankId = body['bank_id'];
          expect(body.keys, unorderedEquals(['bank_id', 'email', 'password']));
          expect(bankId, anyOf(_andinoBank.id, _caribeBank.id));
          final slug = bankId == _andinoBank.id
              ? 'banco-andino'
              : 'cooperativa-caribe';
          return _jsonBody({
            'success': true,
            'data': {
              'access_token': 'token-$slug',
              'user_id': 'user-$slug',
              'tenant_id': slug,
            },
          }, 200);
        }

        final token = options.headers['Authorization'] as String;
        if (options.path == '/transactions/summary') {
          if (token == 'Bearer token-banco-andino') {
            return _summary(options, const [
              {
                'currency': 'COP',
                'available_balance': '1500.25',
                'income': '10',
                'expenses': '1',
              },
            ]);
          }
          expect(token, 'Bearer token-cooperativa-caribe');
          caribeFilters.add(options.queryParameters['account_number']);
          return _summary(options, const [
            {
              'currency': 'EUR',
              'available_balance': '9.75',
              'income': '2',
              'expenses': '1',
            },
          ]);
        }
        if (options.path == '/accounts') {
          accountsTokens.add(token);
          if (token == 'Bearer token-banco-andino') {
            if (delayAndino) {
              pendingAndinoToken = options.cancelToken;
              return lateAndino.future;
            }
            return accounts([
              account('banco-andino', '1234564589', '1500.25', 'COP', 'ACTIVE'),
              account('banco-andino', '1234561111', '99.75', 'COP', 'INACTIVE'),
              account('banco-andino', '1234568821', '120.50', 'USD', 'BLOCKED'),
            ]);
          }
          expect(token, 'Bearer token-cooperativa-caribe');
          if (++caribeRequests == 1) {
            return _jsonBody({'success': false}, 503);
          }
          return caribeRetry.future;
        }

        if (options.path == '/transactions') {
          expect(token, 'Bearer token-cooperativa-caribe');
          expect(options.queryParameters['skip'], 0);
          return _jsonBody({
            'success': true,
            'data': {'items': [], 'total': 0, 'skip': 0, 'limit': 30},
          }, 200);
        }
        expect(options.path, '/auth/me');
        profileTokens.add(token);
        return _jsonBody({
          'success': true,
          'data': {
            'id': 'user-${token.substring('Bearer token-'.length)}',
            'tenant_id': token.substring('Bearer token-'.length),
            'role': 'cliente',
            'is_active': true,
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
      expect(find.byType(BankSelectorScreen), findsOneWidget);

      Future<void> login(PublicBank bank, String email) async {
        await tester.tap(find.text(bank.name));
        await tester.pumpAndSettle();
        final fields = find.byType(TextFormField);
        await tester.enterText(fields.at(0), email);
        await tester.enterText(fields.at(1), 'Cliente123!');

        final submit = find.text('Iniciar Sesión');
        await tester.ensureVisible(submit);
        await tester.tap(submit);
        await tester.pumpAndSettle();
      }

      await login(_andinoBank, 'juan@banco-andino.com');
      Color activeAccent() =>
          Theme.of(tester.element(find.byType(BankNavigationBar)))
              .colorScheme
              .primary;
      expect(activeAccent(), BankPalette.andino.darkAccent);
      expect(find.text(_andinoBank.name), findsOneWidget);
      expect(find.text('¡Hola, Juan Pérez Gómez!'), findsOneWidget);
      expect(
        tester.widget<BankLogo>(find.byType(BankLogo)).logoUrl.toString(),
        andinoLogo,
      );
      expect(container.read(authTokenProvider), 'token-banco-andino');
      expect((await store.read())?.bankLabel, _andinoBank.name);
      expect((await store.read())?.bankLogoUrl.toString(), andinoLogo);
      expect(find.text(r'$1.500,25 COP'), findsNWidgets(2));
      expect(find.text('Finanzas'), findsOneWidget);
      for (final title in ['Saldo actual', 'Ingresos', 'Gastos']) {
        final card = find.ancestor(
          of: find.text(title),
          matching: find.byType(BankSurfaceCard),
        );
        expect(card, findsOneWidget);
        expect(
          tester
              .widget<Card>(
                find.descendant(of: card, matching: find.byType(Card)),
              )
              .color,
          BankPalette.andino.brandColor,
        );
      }

      await _openDashboardMenu(tester);
      await _tapText(tester, 'Configuración general');
      await _tapText(tester, 'Claro');
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Volver al Dashboard'));
      await tester.pumpAndSettle();
      expect(activeAccent(), BankPalette.andino.lightAccent);

      await tester.tap(find.byKey(const Key('quick_action_accounts')));
      await tester.pumpAndSettle();
      expect(activeAccent(), BankPalette.andino.lightAccent);
      expect(find.text(_andinoBank.name), findsOneWidget);
      expect(find.text(r'$1.500,25 COP'), findsOneWidget);
      expect(find.text(r'$99,75 COP'), findsOneWidget);
      expect(find.text(r'$120.50 USD'), findsOneWidget);
      expect(find.text('ACTIVA'), findsOneWidget);
      expect(find.text('INACTIVA'), findsOneWidget);
      expect(find.text('BLOQUEADA'), findsOneWidget);
      expect(find.text('•••• 4589'), findsOneWidget);
      expect(find.text('1234564589'), findsNothing);

      await tester.tap(find.text('Dashboard'));
      await tester.pumpAndSettle();
      container
          .read(dashboardFinanceFiltersProvider.notifier)
          .selectAccount('1234564589');
      await tester.pumpAndSettle();
      final firstSession = container.read(activeSessionProvider)!;
      delayAndino = true;
      container.invalidate(sessionAccountsProvider(firstSession));
      await tester.pump();
      await tester.pump();
      expect(find.text(r'$1.500,25 COP'), findsWidgets);
      await _logoutFromMenu(tester);
      expect(find.byType(BankSelectorScreen), findsOneWidget);
      expect(container.read(authTokenProvider), isNull);
      expect(await store.read(), isNull);
      expect(pendingAndinoToken?.isCancelled, isTrue);

      await login(_caribeBank, 'maria@cooperativa-caribe.com');
      expect(activeAccent(), BankPalette.caribe.lightAccent);
      expect(find.text(_caribeBank.name), findsOneWidget);
      expect(
        tester.widget<BankLogo>(find.byType(BankLogo)).logoUrl.toString(),
        caribeLogo,
      );
      expect(caribeFilters, [null]);
      expect(find.text('¡Hola, María Fernanda Lora!'), findsOneWidget);
      expect((await store.read())?.bankLabel, _caribeBank.name);
      expect(find.textContaining('Juan Pérez'), findsNothing);
      expect(find.text('No pudimos cargar tus cuentas.'), findsOneWidget);
      expect(find.text(r'$120.50 USD'), findsNothing);

      await tester.tap(find.text('Reintentar'));
      await tester.pump();
      await tester.pump();
      expect(find.bySemanticsLabel('Cargando cuentas'), findsOneWidget);
      lateAndino.complete(
        accounts([
          account('banco-andino', '1234564589', '8888', 'COP', 'ACTIVE'),
        ]),
      );
      await tester.pump();
      expect(find.text(r'$8.888 COP'), findsNothing);

      caribeRetry.complete(
        accounts([
          account('cooperativa-caribe', '1234560002', '9.75', 'EUR', 'ACTIVE'),
        ]),
      );
      await tester.pumpAndSettle();
      expect(find.text('€9.75 EUR'), findsNWidgets(2));
      expect(
        find.descendant(
          of: find.byType(DashboardAccountsCarousel),
          matching: find.textContaining(' de '),
        ),
        findsNothing,
      );
      expect(find.text(r'$8.888 COP'), findsNothing);
      expect(
        accountsTokens,
        containsAllInOrder([
          'Bearer token-banco-andino',
          'Bearer token-cooperativa-caribe',
          'Bearer token-cooperativa-caribe',
        ]),
      );
      expect(
        profileTokens,
        containsAllInOrder([
          'Bearer token-banco-andino',
          'Bearer token-cooperativa-caribe',
        ]),
      );

      router.go('/dashboard');
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('quick_action_transfer')));
      await tester.pumpAndSettle();
      expect(find.text('Bre-B'), findsOneWidget);
      await tester.tap(find.text('Mismo banco'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('review_transfer_button')), findsOneWidget);
      expect(
        find.byKey(const Key('destination_account_field')),
        findsOneWidget,
      );

      router.go('/operations');
      await tester.pumpAndSettle();
      expect(find.byType(OperationsScreen), findsOneWidget);
      expect(activeAccent(), BankPalette.caribe.lightAccent);
      router.go('/dashboard');
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('quick_action_deposit')));
      await tester.pumpAndSettle();
      expect(
        router.routeInformationProvider.value.uri.queryParameters['type'],
        'deposit',
      );
      router.go('/dashboard');
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('quick_action_history')));
      await tester.pumpAndSettle();
      expect(find.text('Todavía no hay movimientos.'), findsOneWidget);
      expect(activeAccent(), BankPalette.caribe.lightAccent);
      await container.read(authProvider.notifier).logout();
      await tester.pumpAndSettle();
    });
  });
}
