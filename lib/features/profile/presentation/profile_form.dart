import 'package:flutter/material.dart';

import '../domain/user_profile.dart';

class ProfileForm extends StatefulWidget {
  const ProfileForm({
    super.key,
    required this.profile,
    required this.busy,
    required this.errors,
    required this.onFieldChanged,
    required this.onSave,
    required this.onCancel,
  });

  final UserProfile profile;
  final bool busy;
  final Map<String, String> errors;
  final ValueChanged<String> onFieldChanged;
  final ValueChanged<Map<String, String?>> onSave;
  final VoidCallback onCancel;

  @override
  State<ProfileForm> createState() => _ProfileFormState();
}

class _ProfileFormState extends State<ProfileForm> {
  static final _documentFormat = RegExp(r'^[0-9]{3,12}$');
  static final _phoneFormat = RegExp(r'^\+[1-9][0-9]{7,14}$');
  static final _nonPrintable = RegExp(r'[\p{C}\p{Z}]', unicode: true);

  final _form = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.profile.fullName);
  late final _number = TextEditingController(
    text: widget.profile.documentNumber,
  );
  late final _phone = TextEditingController(text: widget.profile.phone);
  final _address = TextEditingController();
  late DocumentType? _type = widget.profile.documentType;
  bool _editingAddress = false;

  @override
  void dispose() {
    _name.dispose();
    _number.dispose();
    _phone.dispose();
    _address.dispose();
    super.dispose();
  }

  String? _optional(String value) => value.trim().isEmpty ? null : value.trim();

  bool _isPrintable(String value) =>
      !_nonPrintable.hasMatch(value.replaceAll(' ', ''));

  void _save() {
    if (!_form.currentState!.validate()) return;
    final previous = widget.profile;
    final name = _name.text.trim();
    final number = _optional(_number.text);
    final phone = _optional(_phone.text);
    final address = _optional(_address.text);
    widget.onSave({
      if (name != previous.fullName) 'full_name': name,
      if (_type != previous.documentType) 'document_type': _type?.code,
      if (number != previous.documentNumber) 'document_number': number,
      if (phone != previous.phone) 'phone': phone,
      if (_editingAddress && address != previous.address) 'address': address,
    });
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _form,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 16,
        children: [
          TextFormField(
            key: const Key('profile-full_name'),
            enabled: !widget.busy,
            controller: _name,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(labelText: 'Nombre completo'),
            forceErrorText: widget.errors['full_name'],
            onChanged: (_) => widget.onFieldChanged('full_name'),
            validator: (value) {
              final name = value?.trim() ?? '';
              if (name.runes.length < 3 ||
                  name.runes.length > 150 ||
                  !_isPrintable(name)) {
                return 'Escribe entre 3 y 150 caracteres imprimibles.';
              }
              return null;
            },
          ),
          DropdownButtonFormField<DocumentType>(
            key: const Key('profile-document_type'),
            initialValue: _type,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Tipo de documento'),
            forceErrorText: widget.errors['document_type'],
            items: [
              const DropdownMenuItem(child: Text('Sin documento')),
              for (final type in DocumentType.values)
                DropdownMenuItem(value: type, child: Text(type.label)),
            ],
            onChanged: widget.busy
                ? null
                : (type) {
                    setState(() => _type = type);
                    widget.onFieldChanged('document_type');
                    widget.onFieldChanged('document_number');
                  },
          ),
          TextFormField(
            key: const Key('profile-document_number'),
            enabled: !widget.busy,
            controller: _number,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Número de documento'),
            forceErrorText: widget.errors['document_number'],
            onChanged: (_) {
              widget.onFieldChanged('document_type');
              widget.onFieldChanged('document_number');
            },
            validator: (value) {
              final number = _optional(value ?? '');
              if ((number == null) != (_type == null)) {
                return 'Indica o elimina el tipo y el número juntos.';
              }
              if (number != null && !_documentFormat.hasMatch(number)) {
                return 'Escribe entre 3 y 12 dígitos del 0 al 9.';
              }
              return null;
            },
          ),
          TextFormField(
            key: const Key('profile-phone'),
            enabled: !widget.busy,
            controller: _phone,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(
              labelText: 'Celular',
              hintText: '+573001234567',
            ),
            forceErrorText: widget.errors['phone'],
            onChanged: (_) => widget.onFieldChanged('phone'),
            validator: (value) {
              final phone = _optional(value ?? '');
              return phone == null || _phoneFormat.hasMatch(phone)
                  ? null
                  : 'Usa + y entre 8 y 15 dígitos en formato internacional.';
            },
          ),
          if (_editingAddress)
            TextFormField(
              key: const Key('profile-address'),
              enabled: !widget.busy,
              controller: _address,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(labelText: 'Dirección'),
              forceErrorText: widget.errors['address'],
              onChanged: (_) => widget.onFieldChanged('address'),
              validator: (value) {
                final address = _optional(value ?? '');
                return address == null ||
                        (address.runes.length <= 250 && _isPrintable(address))
                    ? null
                    : 'Usa hasta 250 caracteres imprimibles.';
              },
            )
          else
            OutlinedButton(
              onPressed: widget.busy
                  ? null
                  : () {
                      _address.text = widget.profile.address ?? '';
                      setState(() => _editingAddress = true);
                    },
              child: const Text('Editar dirección'),
            ),
          ElevatedButton(
            onPressed: widget.busy ? null : _save,
            child: const Text('Guardar'),
          ),
          TextButton(
            onPressed: widget.busy ? null : widget.onCancel,
            child: const Text('Cancelar'),
          ),
        ],
      ),
    );
  }
}
