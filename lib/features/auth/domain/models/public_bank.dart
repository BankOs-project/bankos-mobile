class PublicBank {
  const PublicBank({required this.id, required this.name, this.logoUrl});

  final String id;
  final String name;
  final Uri? logoUrl;

  factory PublicBank.fromJson(Map<String, dynamic> json) {
    final id = json['bank_id'];
    final name = json['name'];
    if (id is! String ||
        id.trim().isEmpty ||
        name is! String ||
        name.trim().isEmpty) {
      throw const FormatException('Banco inválido en el directorio.');
    }
    final logo = json['logo_url'];
    final uri = logo is String ? Uri.tryParse(logo) : null;
    return PublicBank(
      id: id,
      name: name,
      logoUrl:
          uri != null &&
              (uri.scheme == 'https' || uri.scheme == 'http') &&
              uri.host.isNotEmpty &&
              uri.userInfo.isEmpty
          ? uri
          : null,
    );
  }
}

String normalizeBankSearch(String value) {
  const accents = {
    'a': '[àáâãäåāăą]',
    'c': '[çćč]',
    'e': '[èéêëēĕėęě]',
    'i': '[ìíîïĩīĭį]',
    'n': '[ñńň]',
    'o': '[òóôõöøōŏő]',
    's': '[śşš]',
    'u': '[ùúûüũūŭůűų]',
    'y': '[ýÿ]',
    'z': '[źżž]',
  };
  var normalized = value.trim().toLowerCase().replaceAll(
    RegExp(r'[\u0300-\u036f]'),
    '',
  );
  for (final entry in accents.entries) {
    normalized = normalized.replaceAll(RegExp(entry.value), entry.key);
  }
  return normalized;
}
