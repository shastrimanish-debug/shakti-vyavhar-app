class Business {
  final String id;
  final String name;
  final String? ownerName;
  final String? phone;
  final String? address;
  final String? gstin;
  final String? upiId;
  final String currency;
  final String language; // hi, en, mr, gu, ta, te, bn, pa, kn, ml
  final DateTime createdAt;

  Business({
    required this.id,
    required this.name,
    this.ownerName,
    this.phone,
    this.address,
    this.gstin,
    this.upiId,
    this.currency = 'INR',
    this.language = 'hi',
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'ownerName': ownerName,
      'phone': phone,
      'address': address,
      'gstin': gstin,
      'upiId': upiId,
      'currency': currency,
      'language': language,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory Business.fromMap(Map<String, dynamic> map) {
    return Business(
      id: map['id'],
      name: map['name'],
      ownerName: map['ownerName'],
      phone: map['phone'],
      address: map['address'],
      gstin: map['gstin'],
      upiId: map['upiId'],
      currency: map['currency'] ?? 'INR',
      language: map['language'] ?? 'hi',
      createdAt: DateTime.parse(map['createdAt']),
    );
  }
}
