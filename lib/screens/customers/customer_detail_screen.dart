import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../models/customer.dart';
import '../../models/transaction.dart';
import '../../providers/app_providers.dart';
import 'add_customer_screen.dart';

class CustomerDetailScreen extends StatefulWidget {
  final Customer customer;

  const CustomerDetailScreen({super.key, required this.customer});

  @override
  State<CustomerDetailScreen> createState() => _CustomerDetailScreenState();
}

class _CustomerDetailScreenState extends State<CustomerDetailScreen> {
  List<Transaction> _txns = [];
  double _balance = 0;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final provider = Provider.of<AppProvider>(context, listen: false);
    final txns = await provider.getCustomerTransactions(widget.customer.id);
    final bal = await provider.getBalance(widget.customer.id);
    setState(() {
      _txns = txns;
      _balance = bal;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.customer;
    final dateFormat = DateFormat('dd MMM yyyy');

    return Scaffold(
      appBar: AppBar(
        title: Text(c.name),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => AddCustomerScreen(customer: c),
                ),
              ).then((_) => _load());
            },
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Balance Card
                Container(
                  width: double.infinity,
                  margin: const EdgeInsets.all(16),
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: _balance >= 0
                          ? [Colors.green.shade600, Colors.green.shade400]
                          : [Colors.red.shade600, Colors.red.shade400],
                    ),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Column(
                    children: [
                      Text(
                        c.isSupplier
                            ? (_balance >= 0 ? 'Supplier ko Dena Hai' : 'Supplier se Lena Hai')
                            : (_balance >= 0 ? 'Aapko Lena Hai' : 'Aapko Dena Hai'),
                        style: const TextStyle(color: Colors.white70, fontSize: 14),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '₹${_balance.abs().toStringAsFixed(0)}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 36,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (c.phone != null) ...[
                        const SizedBox(height: 8),
                        Text(
                          c.phone!,
                          style: const TextStyle(color: Colors.white70),
                        ),
                      ],
                    ],
                  ),
                ),

                // Action Buttons
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () => _showAddTxn(TransactionType.credit),
                          icon: const Icon(Icons.add),
                          label: Text(c.isSupplier ? 'Purchase / Credit' : 'Credit (Lena)'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () => _showAddTxn(TransactionType.debit),
                          icon: const Icon(Icons.remove),
                          label: Text(c.isSupplier ? 'Payment / Debit' : 'Debit (Dena)'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Transactions List
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Transactions (${_txns.length})',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: _txns.isEmpty
                      ? const Center(child: Text('Abhi koi transaction nahi'))
                      : ListView.builder(
                          itemCount: _txns.length,
                          itemBuilder: (context, index) {
                            final t = _txns[index];
                            return ListTile(
                              leading: CircleAvatar(
                                backgroundColor: t.isCredit
                                    ? Colors.green.withOpacity(0.15)
                                    : Colors.red.withOpacity(0.15),
                                child: Icon(
                                  t.isCredit
                                      ? Icons.arrow_downward
                                      : Icons.arrow_upward,
                                  color: t.isCredit ? Colors.green : Colors.red,
                                ),
                              ),
                              title: Text(
                                '₹${t.amount.toStringAsFixed(0)}',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: t.isCredit ? Colors.green : Colors.red,
                                ),
                              ),
                              subtitle: Text(
                                '${dateFormat.format(t.date)} • ${t.paymentMode.name.toUpperCase()}'
                                '${t.description != null ? '\n${t.description}' : ''}',
                              ),
                              isThreeLine: t.description != null,
                            );
                          },
                        ),
                ),
              ],
            ),
    );
  }

  void _showAddTxn(TransactionType type) {
    final amountController = TextEditingController();
    final descController = TextEditingController();
    PaymentMode mode = PaymentMode.cash;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: MediaQuery.of(context).viewInsets.bottom + 20,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    type == TransactionType.credit
                        ? (widget.customer.isSupplier ? 'Supplier Credit / Purchase' : 'Credit Entry (Lena)')
                        : (widget.customer.isSupplier ? 'Supplier Debit / Payment' : 'Debit Entry (Dena)'),
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: amountController,
                    decoration: const InputDecoration(
                      labelText: 'Amount (₹)',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.currency_rupee),
                    ),
                    keyboardType: TextInputType.number,
                    autofocus: true,
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: descController,
                    decoration: const InputDecoration(
                      labelText: 'Description (optional)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<PaymentMode>(
                    value: mode,
                    decoration: const InputDecoration(
                      labelText: 'Payment Mode',
                      border: OutlineInputBorder(),
                    ),
                    items: PaymentMode.values
                        .map((m) => DropdownMenuItem(
                              value: m,
                              child: Text(m.name.toUpperCase()),
                            ))
                        .toList(),
                    onChanged: (v) {
                      if (v != null) setModalState(() => mode = v);
                    },
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () async {
                        final amount = double.tryParse(amountController.text);
                        if (amount == null || amount <= 0) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Sahi amount daalo')),
                          );
                          return;
                        }
                        final provider =
                            Provider.of<AppProvider>(context, listen: false);
                        final navigator = Navigator.of(context);
                        await provider.addTransaction(Transaction(
                          customerId: widget.customer.id,
                          type: type,
                          amount: amount,
                          description: descController.text.trim().isEmpty
                              ? null
                              : descController.text.trim(),
                          paymentMode: mode,
                        ));
                        navigator.pop();
                        _load();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: type == TransactionType.credit
                            ? Colors.green
                            : Colors.red,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: const Text('Save Entry'),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
