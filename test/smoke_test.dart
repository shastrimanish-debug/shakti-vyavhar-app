import 'package:flutter_test/flutter_test.dart';
import 'package:shakti_vyavhar/models/customer.dart';
import 'package:shakti_vyavhar/models/transaction.dart';

void main() {
  test('customer and transaction models can be created', () {
    final customer = Customer(name: 'Test Customer');
    final transaction = Transaction(
      customerId: customer.id,
      type: TransactionType.credit,
      amount: 100,
    );

    expect(customer.name, 'Test Customer');
    expect(transaction.customerId, customer.id);
    expect(transaction.amount, 100);
    expect(transaction.isCredit, isTrue);
  });
}
