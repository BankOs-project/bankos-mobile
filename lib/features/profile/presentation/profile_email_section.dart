import 'dart:async';

import 'package:flutter/material.dart';

import '../domain/user_profile.dart';

class ProfileEmailSection extends StatefulWidget {
  const ProfileEmailSection({
    super.key,
    required this.pending,
    required this.busy,
    required this.onRequest,
    required this.onVerify,
  });

  final PendingProfileEmail? pending;
  final bool busy;
  final Future<void> Function(String, String) onRequest;
  final Future<void> Function(PendingProfileEmail, String) onVerify;

  @override
  State<ProfileEmailSection> createState() => _ProfileEmailSectionState();
}

class _ProfileEmailSectionState extends State<ProfileEmailSection> {
  static final _emailFormat = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');

  final _form = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _code = TextEditingController();
  Timer? _expiration;
  Timer? _rateLimit;
  bool _requesting = false;
  ProfileException? _error;

  @override
  void initState() {
    super.initState();
    _scheduleExpiry();
  }

  @override
  void didUpdateWidget(covariant ProfileEmailSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.pending != widget.pending) _scheduleExpiry();
  }

  void _scheduleExpiry() {
    _expiration?.cancel();
    final remaining = widget.pending?.expiresAt.difference(DateTime.now());
    if (remaining != null && remaining > Duration.zero) {
      _expiration = Timer(remaining, () => setState(() {}));
    }
  }

  @override
  void dispose() {
    _expiration?.cancel();
    _rateLimit?.cancel();
    _email.dispose();
    _password.dispose();
    _code.dispose();
    super.dispose();
  }

  void _startRequest() {
    _email.text = widget.pending?.email ?? '';
    setState(() {
      _requesting = true;
      _error = null;
    });
  }

  void _clearError() {
    if (_error != null) setState(() => _error = null);
  }

  Future<void> _submit(PendingProfileEmail? pending) async {
    if (!_form.currentState!.validate()) return;
    _clearError();
    try {
      if (pending == null) {
        await widget.onRequest(
          _email.text.trim().toLowerCase(),
          _password.text,
        );
        if (!mounted) return;
        _password.clear();
        _code.clear();
        setState(() => _requesting = false);
      } else {
        await widget.onVerify(pending, _code.text.trim());
        if (mounted) _code.clear();
      }
    } on ProfileException catch (error) {
      if (!mounted) return;
      final retry = error.retryAfter;
      if (retry != null) {
        _rateLimit?.cancel();
        _rateLimit = Timer(retry, () {
          setState(() {
            _rateLimit = null;
            _error = null;
          });
        });
      }
      setState(() => _error = error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final pending = widget.pending;
    final expired =
        pending != null && !pending.expiresAt.isAfter(DateTime.now());
    final disabled = widget.busy || (_rateLimit?.isActive ?? false);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 12,
      children: [
        if (pending != null)
          Text(
            expired
                ? 'El código para ${pending.email} venció. Solicita uno nuevo.'
                : 'Cambio pendiente. Confirma el código enviado a ${pending.email}.',
          ),
        if (_requesting || (pending != null && !expired))
          Form(
            key: _form,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: 12,
              children: [
                if (_requesting) ...[
                  TextFormField(
                    key: const Key('profile-new-email'),
                    controller: _email,
                    enabled: !widget.busy,
                    keyboardType: TextInputType.emailAddress,
                    autocorrect: false,
                    decoration: const InputDecoration(
                      labelText: 'Correo nuevo',
                    ),
                    forceErrorText: _error?.fields['new_email'],
                    onChanged: (_) => _clearError(),
                    validator: (value) {
                      final email = value?.trim() ?? '';
                      return email.length <= 255 && _emailFormat.hasMatch(email)
                          ? null
                          : 'Escribe un correo válido.';
                    },
                  ),
                  TextFormField(
                    key: const Key('profile-current-password'),
                    controller: _password,
                    enabled: !widget.busy,
                    obscureText: true,
                    enableSuggestions: false,
                    autocorrect: false,
                    decoration: const InputDecoration(
                      labelText: 'Contraseña actual',
                    ),
                    forceErrorText: _error?.fields['current_password'],
                    onChanged: (_) => _clearError(),
                    validator: (value) =>
                        value != null &&
                            value.isNotEmpty &&
                            value.length <= 1024
                        ? null
                        : 'Escribe tu contraseña actual.',
                  ),
                ] else
                  TextFormField(
                    key: const Key('profile-email-code'),
                    controller: _code,
                    enabled: !widget.busy,
                    autocorrect: false,
                    enableSuggestions: false,
                    decoration: const InputDecoration(
                      labelText: 'Código de verificación',
                    ),
                    forceErrorText: _error?.fields['email_code'],
                    onChanged: (_) => _clearError(),
                    validator: (value) {
                      final code = value?.trim() ?? '';
                      return code.isNotEmpty &&
                              code.length <= 128 &&
                              code.codeUnits.every((unit) => unit <= 127)
                          ? null
                          : 'Escribe el código recibido.';
                    },
                  ),
                FilledButton(
                  onPressed: disabled
                      ? null
                      : () => _submit(_requesting ? null : pending),
                  child: Text(
                    _requesting ? 'Enviar código' : 'Confirmar correo',
                  ),
                ),
              ],
            ),
          ),
        if (_error case final error?)
          Text(
            error.message,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        TextButton(
          onPressed: disabled
              ? null
              : _requesting
              ? () {
                  _password.clear();
                  setState(() {
                    _requesting = false;
                    _error = null;
                  });
                }
              : _startRequest,
          child: Text(
            _requesting
                ? 'Cancelar solicitud'
                : pending != null
                ? 'Solicitar otro código'
                : 'Cambiar correo',
          ),
        ),
      ],
    );
  }
}
