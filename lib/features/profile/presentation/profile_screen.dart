import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../auth/domain/models/auth_models.dart';
import '../../auth/presentation/providers/auth_provider.dart';
import '../data/profile_repository.dart';
import '../domain/user_profile.dart';
import 'profile_email_section.dart';
import 'profile_form.dart';
import 'profile_providers.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(activeSessionProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mi perfil'),
        leading: BackButton(
          onPressed: () =>
              context.canPop() ? context.pop() : context.go('/menu'),
        ),
      ),
      body: SafeArea(
        child: session == null
            ? const SizedBox.shrink()
            : _SessionProfile(key: ObjectKey(session), session: session),
      ),
    );
  }
}

class _SessionProfile extends ConsumerStatefulWidget {
  const _SessionProfile({super.key, required this.session});

  final AuthSession session;

  @override
  ConsumerState<_SessionProfile> createState() => _SessionProfileState();
}

class _SessionProfileState extends ConsumerState<_SessionProfile> {
  final _cancel = CancelToken();
  UserProfile? _saved;
  bool _editing = false;
  bool _showAddress = false;
  bool _busy = false;
  ProfileException? _error;

  bool get _current =>
      mounted && identical(ref.read(activeSessionProvider), widget.session);

  ProfileRepository get _repository => ref.read(profileRepositoryProvider);

  @override
  void dispose() {
    _cancel.cancel();
    super.dispose();
  }

  Future<T> _run<T>(Future<T> Function() change) async {
    if (!_current || _busy) {
      throw const ProfileException('La solicitud no está disponible.');
    }
    setState(() => _busy = true);
    try {
      final result = await change();
      if (!_current) {
        throw const ProfileException('La sesión cambió.');
      }
      return result;
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _save(Map<String, String?> fields) async {
    if (fields.isEmpty) {
      setState(() => _editing = false);
      return;
    }
    setState(() => _error = null);
    try {
      final saved = await _run(
        () => _repository.update(widget.session, _cancel, fields),
      );
      if (!_current) return;
      await ref
          .read(authProvider.notifier)
          .updateProfileIdentity(widget.session, name: saved.fullName);
      if (!mounted || !_current) return;
      setState(() {
        _saved = saved;
        _editing = false;
        _showAddress = false;
      });
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Perfil actualizado.')));
    } on ProfileException catch (error) {
      if (_current) setState(() => _error = error);
    }
  }

  Future<void> _changePhoto({required bool remove}) async {
    setState(() => _error = null);
    try {
      final profile = await _run(() async {
        if (remove) return _repository.removePhoto(widget.session, _cancel);
        final file = await ref.read(profileFilePickerProvider)();
        if (file == null || !_current) return null;
        if (await file.length() > ProfileRepository.maxPhotoBytes) {
          throw const ProfileException('La foto debe pesar hasta 2 MiB.');
        }
        final bytes = await file.readAsBytes();
        if (!_current) return null;
        return _repository.uploadPhoto(widget.session, _cancel, bytes);
      });
      if (profile == null || !_current) return;
      ref.invalidate(profilePhotoProvider(widget.session));
      setState(() => _saved = profile);
    } on ProfileException catch (error) {
      if (_current) setState(() => _error = error);
    } catch (_) {
      if (_current) {
        setState(
          () => _error = const ProfileException('No pudimos abrir la foto.'),
        );
      }
    }
  }

  Future<void> _requestEmail(String email, String password) async {
    final pending = await _run(
      () => _repository.startEmailChange(
        widget.session,
        _cancel,
        email: email,
        password: password,
      ),
    );
    if (_current) {
      ref.read(pendingProfileEmailProvider.notifier).setPending(pending);
    }
  }

  Future<void> _verifyEmail(PendingProfileEmail pending, String code) async {
    final profile = await _run(
      () => _repository.verifyEmail(widget.session, _cancel, pending, code),
    );
    if (!_current) return;
    ref.read(pendingProfileEmailProvider.notifier).clearPending();
    setState(() => _saved = profile);
    final auth = ref.read(authProvider.notifier);
    final persisted = auth.updateProfileIdentity(
      widget.session,
      name: profile.fullName,
      email: profile.email,
    );
    // La confirmación cambia el correo local y recarga la vista desde FastAPI.
    final updated = ref.read(activeSessionProvider);
    if (!await persisted &&
        mounted &&
        identical(ref.read(activeSessionProvider), updated)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Correo confirmado. No pudimos actualizar la copia local de la sesión.',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = myProfileProvider(widget.session);
    final result = ref.watch(provider);
    if (result.isLoading) {
      return const Center(
        child: CircularProgressIndicator(semanticsLabel: 'Cargando perfil'),
      );
    }
    final profile = _saved ?? result.asData?.value;
    if (profile == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('No pudimos cargar tu perfil.'),
              TextButton(
                onPressed: () => ref.invalidate(provider),
                child: const Text('Reintentar'),
              ),
            ],
          ),
        ),
      );
    }

    final photo = profile.hasPhoto
        ? ref.watch(profilePhotoProvider(widget.session))
        : null;
    final image = photo == null || photo.isLoading ? null : photo.asData?.value;
    final pending = ref.watch(pendingProfileEmailProvider);
    final colors = Theme.of(context).colorScheme;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (_busy)
          const LinearProgressIndicator(semanticsLabel: 'Actualizando perfil'),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: 16,
              children: [
                Center(
                  child: CircleAvatar(
                    radius: 44,
                    foregroundColor: colors.onPrimaryContainer,
                    backgroundColor: colors.primaryContainer,
                    child: image == null
                        ? const Icon(
                            Icons.person_outline_rounded,
                            size: 40,
                            semanticLabel: 'Avatar genérico',
                          )
                        : ClipOval(
                            child: Semantics(
                              label: 'Foto de perfil',
                              image: true,
                              child: RawImage(
                                image: image,
                                width: 88,
                                height: 88,
                                fit: BoxFit.cover,
                              ),
                            ),
                          ),
                  ),
                ),
                if (!_editing)
                  Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 8,
                    children: [
                      TextButton(
                        onPressed: _busy
                            ? null
                            : () => _changePhoto(remove: false),
                        child: Text(
                          profile.hasPhoto ? 'Cambiar foto' : 'Agregar foto',
                        ),
                      ),
                      if (profile.hasPhoto)
                        TextButton(
                          onPressed: _busy
                              ? null
                              : () => _changePhoto(remove: true),
                          child: const Text('Quitar foto'),
                        ),
                    ],
                  ),
                if (photo?.hasError ?? false)
                  TextButton(
                    onPressed: _busy
                        ? null
                        : () => ref.invalidate(
                            profilePhotoProvider(widget.session),
                          ),
                    child: const Text('Reintentar cargar foto'),
                  ),
                if (_error case final error?)
                  Text(error.message, style: TextStyle(color: colors.error)),
                if (_editing)
                  ProfileForm(
                    profile: profile,
                    busy: _busy,
                    errors: _error?.fields ?? const {},
                    onFieldChanged: (field) {
                      final error = _error;
                      if (error == null || !error.fields.containsKey(field)) {
                        return;
                      }
                      final remaining = {...error.fields}..remove(field);
                      setState(
                        () => _error = remaining.isEmpty
                            ? null
                            : ProfileException(
                                error.message,
                                fields: remaining,
                              ),
                      );
                    },
                    onSave: _save,
                    onCancel: () => setState(() {
                      _editing = false;
                      _error = null;
                    }),
                  )
                else ...[
                  _ProfileValue('Nombre completo', profile.fullName),
                  _ProfileValue(
                    'Tipo de documento',
                    profile.documentType?.label,
                  ),
                  _ProfileValue('Número de documento', profile.documentNumber),
                  _ProfileValue('Celular', profile.phone),
                  _ProfileValue(
                    'Dirección',
                    _showAddress
                        ? profile.address
                        : profile.address == null
                        ? 'Sin dirección'
                        : 'Dirección oculta',
                  ),
                  if (profile.address != null)
                    Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: TextButton(
                        onPressed: () =>
                            setState(() => _showAddress = !_showAddress),
                        child: Text(
                          _showAddress ? 'Ocultar dirección' : 'Ver dirección',
                        ),
                      ),
                    ),
                  OutlinedButton.icon(
                    onPressed: _busy
                        ? null
                        : () => setState(() {
                            _editing = true;
                            _showAddress = false;
                            _error = null;
                          }),
                    icon: const Icon(Icons.edit_outlined),
                    label: const Text('Editar perfil'),
                  ),
                ],
                const Divider(),
                _ProfileValue('Correo', profile.email),
                if (!_editing)
                  ProfileEmailSection(
                    pending: pending,
                    busy: _busy,
                    onRequest: _requestEmail,
                    onVerify: _verifyEmail,
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _ProfileValue extends StatelessWidget {
  const _ProfileValue(this.label, this.value);

  final String label;
  final String? value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: 4,
      children: [
        Text(label, style: Theme.of(context).textTheme.labelLarge),
        Text(value ?? 'Sin registrar'),
      ],
    );
  }
}
