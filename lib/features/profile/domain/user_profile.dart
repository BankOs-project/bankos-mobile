enum DocumentType {
  citizenship('CC', 'Cédula de ciudadanía'),
  foreigner('CE', 'Cédula de extranjería');

  const DocumentType(this.code, this.label);
  final String code;
  final String label;
}

class UserProfile {
  UserProfile.fromJson(Map<String, dynamic> json)
    : fullName = json['full_name'] as String,
      email = json['email'] as String,
      documentType = switch (json['document_type']) {
        'CC' => DocumentType.citizenship,
        'CE' => DocumentType.foreigner,
        _ => null,
      },
      documentNumber = json['document_number'] as String?,
      phone = json['phone'] as String?,
      address = json['address'] as String?,
      hasPhoto = json['photo_url'] is String;

  final String fullName;
  final String email;
  final DocumentType? documentType;
  final String? documentNumber;
  final String? phone;
  final String? address;
  final bool hasPhoto;
}

class PendingProfileEmail {
  const PendingProfileEmail(this.email, this.requestId, this.expiresAt);

  final String email;
  final String requestId;
  final DateTime expiresAt;
}

class ProfileException implements Exception {
  const ProfileException(
    this.message, {
    this.fields = const {},
    this.retryAfter,
  });

  final String message;
  final Map<String, String> fields;
  final Duration? retryAfter;
}
