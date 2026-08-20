import 'package:flutter_test/flutter_test.dart';
import 'package:shakti_vyavhar/models/customer.dart';

void main() {
  test('customer and supplier are distinct party types', () {
    final customer = Customer(name: 'Ramesh', isSupplier: false);
    final supplier = Customer(name: 'ABC Traders', isSupplier: true);

    expect(customer.isSupplier, isFalse);
    expect(supplier.isSupplier, isTrue);
    expect(customer.name, isNot(supplier.name));
  });
}
