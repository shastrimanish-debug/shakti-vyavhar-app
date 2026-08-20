import 'package:uuid/uuid.dart';

class Customer {
  final String id;
  final String businessId;
  final String name;
  final String? phone;
  final String? address;
  final String? email;
  final String? notes;
  final double openingBalance;
  final bool isSupplier; // false = customer, true = supplier
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isActive;

  Customer({
    String? id,
    this.businessId = 'default',
    required this.name,
    this.phone,
    this.address,
    this.email,
    this.notes,
    this.openingBalance = 0.0,
    this.isSupplier = false,
    DateTime? createdAt,
    DateTime? updatedAt,
    this.isActive = true,
  })  : id = id ?? const Uuid().v4(),
        createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  Customer copyWith({
    String? businessId,
    String? name,
    String? phone,
    String? address,
    String? email,
    String? notes,
    double? openingBalance,
    bool? isSupplier,
    DateTime? updatedAt,
    bool? isActive,
  }) {
    return Customer(
      id: id,
      businessId: businessId ?? this.businessId,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      address: address ?? this.address,
      email: email ?? this.email,
      notes: notes ?? this.notes,
      openingBalance: openingBalance ?? this.openingBalance,
      isSupplier: isSupplier ?? this.isSupplier,
      createdAt: createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
      isActive: isActive ?? this.isActive,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'businessId': businessId,
      'name': name,
      'phone': phone,
      'address': address,
      'email': email,
      'notes': notes,
      'openingBalance': openingBalance,
      'isSupplier': isSupplier ? 1 : 0,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'isActive': isActive ? 1 : 0,
    };
  }

  factory Customer.fromMap(Map<String, dynamic> map) {
    return Customer(
      id: map['id'],
      businessId: map['businessId'] ?? 'default',
      name: map['name'],
      phone: map['phone'],
      address: map['address'],
      email: map['email'],
      notes: map['notes'],
      openingBalance: (map['openingBalance'] as num?)?.toDouble() ?? 0.0,
      isSupplier: map['isSupplier'] == 1,
      createdAt: DateTime.parse(map['createdAt']),
      updatedAt: DateTime.parse(map['updatedAt']),
      isActive: map['isActive'] == 1,
    );
  }

  @override
  String toString() => 'Customer(id: $id, name: $name, phone: $phone)';
}
