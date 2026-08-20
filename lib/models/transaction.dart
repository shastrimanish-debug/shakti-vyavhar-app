import 'package:uuid/uuid.dart';

enum TransactionType { credit, debit }

enum PaymentMode { cash, bank, upi, cheque, other }

class Transaction {
  final String id;
  final String businessId;
  final String customerId;
  final TransactionType type; // credit = customer ne diya / aapko mila, debit = aapne diya
  final double amount;
  final String? description;
  final PaymentMode paymentMode;
  final DateTime date;
  final DateTime createdAt;
  final String? billNumber;
  final bool isDeleted;

  Transaction({
    String? id,
    this.businessId = 'default',
    required this.customerId,
    required this.type,
    required this.amount,
    this.description,
    this.paymentMode = PaymentMode.cash,
    DateTime? date,
    DateTime? createdAt,
    this.billNumber,
    this.isDeleted = false,
  })  : id = id ?? const Uuid().v4(),
        date = date ?? DateTime.now(),
        createdAt = createdAt ?? DateTime.now();

  Transaction copyWith({
    String? businessId,
    TransactionType? type,
    double? amount,
    String? description,
    PaymentMode? paymentMode,
    DateTime? date,
    String? billNumber,
    bool? isDeleted,
  }) {
    return Transaction(
      id: id,
      businessId: businessId ?? this.businessId,
      customerId: customerId,
      type: type ?? this.type,
      amount: amount ?? this.amount,
      description: description ?? this.description,
      paymentMode: paymentMode ?? this.paymentMode,
      date: date ?? this.date,
      createdAt: createdAt,
      billNumber: billNumber ?? this.billNumber,
      isDeleted: isDeleted ?? this.isDeleted,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'businessId': businessId,
      'customerId': customerId,
      'type': type.name,
      'amount': amount,
      'description': description,
      'paymentMode': paymentMode.name,
      'date': date.toIso8601String(),
      'createdAt': createdAt.toIso8601String(),
      'billNumber': billNumber,
      'isDeleted': isDeleted ? 1 : 0,
    };
  }

  factory Transaction.fromMap(Map<String, dynamic> map) {
    return Transaction(
      id: map['id'],
      businessId: map['businessId'] ?? 'default',
      customerId: map['customerId'],
      type: TransactionType.values.firstWhere(
        (e) => e.name == map['type'],
        orElse: () => TransactionType.credit,
      ),
      amount: (map['amount'] as num).toDouble(),
      description: map['description'],
      paymentMode: PaymentMode.values.firstWhere(
        (e) => e.name == map['paymentMode'],
        orElse: () => PaymentMode.cash,
      ),
      date: DateTime.parse(map['date']),
      createdAt: DateTime.parse(map['createdAt']),
      billNumber: map['billNumber'],
      isDeleted: map['isDeleted'] == 1,
    );
  }

  bool get isCredit => type == TransactionType.credit;
  bool get isDebit => type == TransactionType.debit;
}
