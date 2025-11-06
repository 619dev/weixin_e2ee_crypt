class PGPKey {
  final String id;
  final String name;
  final String keyContent;
  final KeyType type;
  final DateTime createdAt;
  final String? userId; // PGP User ID
  final String? fingerprint; // PGP指纹

  PGPKey({
    required this.id,
    required this.name,
    required this.keyContent,
    required this.type,
    required this.createdAt,
    this.userId,
    this.fingerprint,
  });

  bool get isPrivate => type == KeyType.private;
  bool get isPublic => type == KeyType.public;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'keyContent': keyContent,
      'type': type.toString(),
      'createdAt': createdAt.toIso8601String(),
      'userId': userId,
      'fingerprint': fingerprint,
    };
  }

  factory PGPKey.fromJson(Map<String, dynamic> json) {
    return PGPKey(
      id: json['id'] as String,
      name: json['name'] as String,
      keyContent: json['keyContent'] as String,
      type: KeyType.values.firstWhere(
        (e) => e.toString() == json['type'],
        orElse: () => KeyType.public,
      ),
      createdAt: DateTime.parse(json['createdAt'] as String),
      userId: json['userId'] as String?,
      fingerprint: json['fingerprint'] as String?,
    );
  }
}

enum KeyType {
  private,
  public,
}

