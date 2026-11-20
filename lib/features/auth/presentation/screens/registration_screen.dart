import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../domain/models/auth_models.dart';
import '../../domain/models/public_bank.dart';
import '../providers/auth_provider.dart';

class RegistrationScreen extends ConsumerStatefulWidget {
  const RegistrationScreen({super.key, required this.bank});

  final PublicBank bank;

  @override
  ConsumerState<RegistrationScreen> createState() => _RegistrationScreenState();
}

class _RegistrationScreenState extends ConsumerState<RegistrationScreen> {
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _code = TextEditingController();
  final _name = TextEditingController();
  final _password = TextEditingController();
  RegistrationChallenge? _challenge;
  Timer? _expiryTimer;
  bool _expired = false;
  bool _busy = false;
  bool _verified = false;
  String? _error;

  @override
  void dispose() {
    _expiryTimer?.cancel();
    _email.dispose();
    _code.dispose();
    _name.dispose();
    _password.dispose();
    super.dispose();
  }

  void _goToLogin() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/login', extra: widget.bank);
    }
  }

  Future<void> _requestCode() async {
    if (_challenge == null && _form.currentState?.validate() != true) return;
    await _run(() async {
      final challenge = await ref
          .read(authRepositoryProvider)
          .startRegistration(bankId: widget.bank.id, email: _email.text);
      if (!mounted) return;
      FocusScope.of(context).unfocus();
      _code.clear();
      _expiryTimer?.cancel();
      _expiryTimer = Timer(challenge.validFor, () {
        if (mounted) setState(() => _expired = true);
      });
      setState(() {
        _challenge = challenge;
        _expired = false;
      });
    }, fallback: 'No pudimos solicitar el código. Intenta de nuevo.');
  }

  Future<void> _verify() async {
    final challenge = _challenge;
    if (challenge == null) return;
    if (_expired || !challenge.expiresAt.isAfter(DateTime.now())) {
      setState(() => _expired = true);
      return;
    }
    if (_form.currentState?.validate() != true) return;
    await _run(
      () async {
        await ref
            .read(authRepositoryProvider)
            .verifyRegistration(
              registrationId: challenge.id,
              code: _code.text,
              fullName: _name.text,
              password: _password.text,
            );
        if (!mounted) return;
        _expiryTimer?.cancel();
        _code.clear();
        _password.clear();
        setState(() => _verified = true);
      },
      fallback: 'No pudimos completar la verificación. Revisa el código o solicita uno nuevo.',
    );
  }

  Future<void> _run(
    Future<void> Function() action, {
    required String fallback,
  }) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await action();
    } on DioException catch (error) {
      if (!mounted) return;
      // Evita mostrar respuestas del servidor que puedan revelar el estado de un usuario.
      setState(
        () => _error = error.response?.statusCode == 429
            ? 'Espera unos minutos antes de volver a intentarlo.'
            : fallback,
      );
    } catch (_) {
      if (mounted) setState(() => _error = fallback);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Crear usuario'),
        leading: BackButton(onPressed: _goToLogin),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: ListView(
              shrinkWrap: true,
              padding: const EdgeInsets.all(16),
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Form(
                      key: _form,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        spacing: 12,
                        children: [
                          Text(
                            widget.bank.name,
                            style: theme.textTheme.titleLarge,
                          ),
                          if (_verified)
                            const Text(
                              'Correo verificado. Ya puedes iniciar sesión en este banco.',
                            )
                          else if (_challenge == null)
                            ..._emailFields()
                          else
                            ..._verificationFields(),
                          if (_error case final error?)
                            Text(
                              error,
                              style: TextStyle(color: theme.colorScheme.error),
                            ),
                          if (_busy) const LinearProgressIndicator(),
                          TextButton(
                            onPressed: _goToLogin,
                            child: const Text('Volver al login'),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _emailFields() => [
    TextFormField(
      controller: _email,
      enabled: !_busy,
      keyboardType: TextInputType.emailAddress,
      autofillHints: const [AutofillHints.email],
      decoration: const InputDecoration(labelText: 'Correo electrónico'),
      validator: (value) {
        final email = value?.trim() ?? '';
        return RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(email)
            ? null
            : 'Ingresa un correo electrónico válido.';
      },
    ),
    FilledButton(
      onPressed: _busy ? null : _requestCode,
      child: const Text('Solicitar código'),
    ),
  ];

  List<Widget> _verificationFields() => [
    Text('Verifica el correo ${_email.text.trim()}'),
    if (_expired) const Text('El código venció. Solicita uno nuevo.'),
    TextFormField(
      controller: _code,
      enabled: !_busy && !_expired,
      autocorrect: false,
      decoration: const InputDecoration(labelText: 'Código de verificación'),
      validator: (value) {
        final code = value?.trim() ?? '';
        return code.isEmpty || code.length > 128
            ? 'Ingresa el código que recibiste por correo.'
            : null;
      },
    ),
    TextFormField(
      controller: _name,
      enabled: !_busy,
      autofillHints: const [AutofillHints.name],
      decoration: const InputDecoration(labelText: 'Nombre completo'),
      validator: (value) {
        final length = value?.trim().runes.length ?? 0;
        return length < 3 || length > 150
            ? 'Ingresa entre 3 y 150 caracteres.'
            : null;
      },
    ),
    TextFormField(
      controller: _password,
      enabled: !_busy,
      obscureText: true,
      autofillHints: const [AutofillHints.newPassword],
      decoration: const InputDecoration(
        labelText: 'Contraseña del nuevo usuario',
      ),
      validator: (value) {
        final length = value?.runes.length ?? 0;
        return length < 8 || length > 128
            ? 'Usa entre 8 y 128 caracteres.'
            : null;
      },
    ),
    FilledButton(
      onPressed: _busy || _expired ? null : _verify,
      child: const Text('Verificar y crear usuario'),
    ),
    OutlinedButton(
      onPressed: _busy ? null : _requestCode,
      child: const Text('Reenviar código'),
    ),
  ];
}
