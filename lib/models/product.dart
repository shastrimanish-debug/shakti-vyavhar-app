import 'package:uuid/uuid.dart';

class Product {
  final String id;
  final String businessId;
  final String name;
  final String? sku;
  final double salePrice;
  final double purchasePrice;
  final double stock;
  final String unit;
  final double lowStockAt;
  final bool isActive;

  Product({
    String? id,
    this.businessId = 'default',
    required this.name,
    this.sku,
    this.salePrice = 0,
    this.purchasePrice = 0,
    this.stock = 0,
    this.unit = 'pcs',
    this.lowStockAt = 5,
    this.isActive = true,
  }) : id = id ?? const Uuid().v4();

  Map<String, dynamic> toMap() => {
        'id': id,
        'businessId': businessId,
        'name': name,
        'sku': sku,
        'salePrice': salePrice,
        'purchasePrice': purchasePrice,
        'stock': stock,
        'unit': unit,
        'lowStockAt': lowStockAt,
        'isActive': isActive ? 1 : 0,
      };

  factory Product.fromMap(Map<String, dynamic> map) => Product(
        id: map['id'],
        businessId: map['businessId'] ?? 'default',
        name: map['name'],
        sku: map['sku'],
        salePrice: (map['salePrice'] as num?)?.toDouble() ?? 0,
        purchasePrice: (map['purchasePrice'] as num?)?.toDouble() ?? 0,
        stock: (map['stock'] as num?)?.toDouble() ?? 0,
        unit: map['unit'] ?? 'pcs',
        lowStockAt: (map['lowStockAt'] as num?)?.toDouble() ?? 5,
        isActive: map['isActive'] != 0,
      );

  Product copyWith({
    String? businessId,
    String? name,
    String? sku,
    double? salePrice,
    double? purchasePrice,
    double? stock,
    String? unit,
    double? lowStockAt,
    bool? isActive,
  }) => Product(
        id: id,
        businessId: businessId ?? this.businessId,
        name: name ?? this.name,
        sku: sku ?? this.sku,
        salePrice: salePrice ?? this.salePrice,
        purchasePrice: purchasePrice ?? this.purchasePrice,
        stock: stock ?? this.stock,
        unit: unit ?? this.unit,
        lowStockAt: lowStockAt ?? this.lowStockAt,
        isActive: isActive ?? this.isActive,
      );
}
