import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/customer.dart';
import '../../models/product.dart';
import '../../providers/app_providers.dart';
import '../../services/business_tools_service.dart';
import '../../services/database_service.dart';

/// Business actions are party-aware:
/// - Customer tab/actions: payment reminder, UPI, invoice, statement.
/// - Supplier tab/actions: material/order reminders only.
/// A supplier can never accidentally appear in customer invoice/statement pickers.
class BusinessToolsScreen extends StatefulWidget {
  const BusinessToolsScreen({super.key});

  @override
  State<BusinessToolsScreen> createState() => _BusinessToolsScreenState();
}

class _BusinessToolsScreenState extends State<BusinessToolsScreen> {
  final DatabaseService _db = DatabaseService();
  late final BusinessToolsService _tools;
  List<Product> _products = [];

  @override
  void initState() {
    super.initState();
    _tools = BusinessToolsService(_db);
    _loadProducts();
  }

  Future<void> _loadProducts() async {
    final provider = context.read<AppProvider>();
    final rows = await _db.getProducts(businessId: provider.activeBusinessId);
    if (mounted) setState(() => _products = rows);
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    return Scaffold(
      appBar: AppBar(title: const Text('Business Tools')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _section('Customer Tools', [
            _tile(Icons.message, 'WhatsApp Payment Reminder',
                'Sirf Customer ko payment reminder', _customerWhatsApp),
            _tile(Icons.sms, 'SMS Payment Reminder',
                'Sirf Customer ko payment reminder', _customerSms),
            _tile(Icons.account_balance_wallet, 'UPI Collect',
                'Sirf Customer se payment collect', _pickUpiCustomer),
            _tile(Icons.picture_as_pdf, 'Customer PDF Statement / Invoice',
                'Sirf Customer ka statement/invoice', () => _pickCustomerStatement(false)),
            _tile(Icons.print, 'Print Customer Statement',
                'Print me sirf Customer ledger', () => _pickCustomerStatement(true)),
            _tile(Icons.receipt_long, 'GST Customer Invoice',
                'GST invoice sirf Customer ke liye', _gstInvoice),
          ]),
          _section('Supplier Tools', [
            _tile(Icons.local_shipping, 'WhatsApp Material Reminder',
                'Sirf Supplier se material/order update', _supplierWhatsApp),
            _tile(Icons.sms, 'SMS Material Reminder',
                'Sirf Supplier se material/order update', _supplierSms),
          ]),
          _section('Inventory / Stock', [
            _tile(Icons.inventory_2, 'Stock Manager',
                '${_products.length} products • low stock alerts', _showInventory),
          ]),
          _section('Backup & Restore', [
            _tile(Icons.backup, 'Backup Now',
                'Complete local database backup share kare', () async {
              try {
                await _tools.exportBackup();
                _snack('Backup ready hai.');
              } catch (e) {
                _snack('Backup failed: $e');
              }
            }),
            _tile(Icons.restore, 'Restore Backup',
                'JSON backup se data restore kare', () async {
              try {
                final ok = await _tools.restoreBackup();
                if (ok) {
                  await provider.loadBusinesses();
                  await provider.loadCustomers();
                  await provider.loadStats();
                  await _loadProducts();
                  _snack('Backup restore ho gaya.');
                }
              } catch (e) {
                _snack('Restore failed: $e');
              }
            }),
          ]),
          const SizedBox(height: 8),
          Card(
            color: Colors.amber.shade50,
            child: const Padding(
              padding: EdgeInsets.all(14),
              child: Text(
                'Cloud sync: local backup/restore available hai. Automatic multi-device cloud sync ke liye secure server/API account chahiye.',
                style: TextStyle(fontSize: 13),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _section(String title, List<Widget> children) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4, top: 10, bottom: 8),
            child: Text(title,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
          ),
          Card(child: Column(children: children)),
        ],
      );

  Widget _tile(IconData icon, String title, String subtitle, VoidCallback onTap) =>
      ListTile(
        leading: CircleAvatar(child: Icon(icon)),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      );

  Future<Customer?> _selectParty({required bool supplier}) async {
    final provider = context.read<AppProvider>();
    final parties = supplier ? provider.supplierParties : provider.customerParties;
    if (parties.isEmpty) {
      _snack(supplier ? 'Pehle Supplier add karein.' : 'Pehle Customer add karein.');
      return null;
    }
    return showModalBottomSheet<Customer>(
      context: context,
      builder: (_) => SafeArea(
        child: ListView(
          children: parties
              .map((party) => ListTile(
                    leading: Icon(supplier ? Icons.store : Icons.person),
                    title: Text(party.name),
                    subtitle: Text(party.phone ?? 'Mobile missing'),
                    onTap: () => Navigator.pop(context, party),
                  ))
              .toList(),
        ),
      ),
    );
  }

  Future<void> _customerWhatsApp() async {
    final customer = await _selectParty(supplier: false);
    if (customer == null) return;
    try {
      await _tools.sendWhatsAppReminder(customer,
          await context.read<AppProvider>().getBalance(customer.id));
    } catch (e) {
      _snack('$e');
    }
  }

  Future<void> _customerSms() async {
    final customer = await _selectParty(supplier: false);
    if (customer == null) return;
    try {
      await _tools.sendSmsReminder(customer,
          await context.read<AppProvider>().getBalance(customer.id));
    } catch (e) {
      _snack('$e');
    }
  }

  Future<void> _supplierWhatsApp() async {
    final supplier = await _selectParty(supplier: true);
    if (supplier == null) return;
    final material = await _materialDialog('WhatsApp Material Reminder');
    if (material == null) return;
    try {
      await _tools.sendSupplierMaterialReminder(supplier, material: material);
    } catch (e) {
      _snack('$e');
    }
  }

  Future<void> _supplierSms() async {
    final supplier = await _selectParty(supplier: true);
    if (supplier == null) return;
    final material = await _materialDialog('SMS Material Reminder');
    if (material == null) return;
    try {
      await _tools.sendSupplierMaterialSms(supplier, material: material);
    } catch (e) {
      _snack('$e');
    }
  }

  Future<String?> _materialDialog(String title) async {
    final controller = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: 'Material / Order (optional)',
            hintText: 'e.g. 50 kg rice',
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('Send')),
        ],
      ),
    );
    if (ok != true) return null;
    return controller.text.trim();
  }

  Future<void> _pickUpiCustomer() async {
    final customer = await _selectParty(supplier: false);
    if (customer == null) return;
    final provider = context.read<AppProvider>();
    final amountController = TextEditingController(
        text: (await provider.getBalance(customer.id)).abs().toStringAsFixed(0));
    final upiController = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('UPI Collect — Customer'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: amountController, keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Amount (₹)')),
            TextField(controller: upiController,
                decoration: const InputDecoration(labelText: 'Business UPI ID (e.g. shop@upi)')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('Open UPI')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await _tools.collectUpi(customer, double.parse(amountController.text), upiId: upiController.text);
    } catch (e) {
      _snack('$e');
    }
  }

  Future<void> _gstInvoice() async {
    final customer = await _selectParty(supplier: false);
    if (customer == null) return;
    final amount = TextEditingController();
    final rate = TextEditingController(text: '18');
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('GST Invoice — Customer'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: amount, keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Taxable Amount (₹)')),
            TextField(controller: rate, keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'GST %')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('Create PDF')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await _tools.shareGstInvoice(customer, double.parse(amount.text), double.parse(rate.text));
    } catch (e) {
      _snack('$e');
    }
  }

  Future<void> _pickCustomerStatement(bool print) async {
    final customer = await _selectParty(supplier: false);
    if (customer == null) return;
    final provider = context.read<AppProvider>();
    final txns = await provider.getCustomerTransactions(customer.id);
    try {
      if (print) {
        await _tools.printInvoice(customer, txns);
      } else {
        await _tools.shareInvoice(customer, txns);
      }
    } catch (e) {
      _snack('$e');
    }
  }

  Future<void> _showInventory() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => StatefulBuilder(
        builder: (context, setModalState) => SizedBox(
          height: MediaQuery.of(context).size.height * .82,
          child: Column(
            children: [
              ListTile(
                title: const Text('Stock Manager', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20)),
                trailing: IconButton(
                  icon: const Icon(Icons.add_circle),
                  onPressed: () async {
                    final p = await _productDialog();
                    if (p != null) {
                      final businessId = context.read<AppProvider>().activeBusinessId;
                      await _db.insertProduct(p.copyWith(businessId: businessId), businessId: businessId);
                      await _loadProducts();
                      setModalState(() {});
                    }
                  },
                ),
              ),
              const Divider(),
              Expanded(
                child: _products.isEmpty
                    ? const Center(child: Text('Product add karein'))
                    : ListView.builder(
                        itemCount: _products.length,
                        itemBuilder: (_, i) {
                          final p = _products[i];
                          final low = p.stock <= p.lowStockAt;
                          return ListTile(
                            leading: Icon(low ? Icons.warning_amber : Icons.inventory_2,
                                color: low ? Colors.red : Colors.green),
                            title: Text(p.name),
                            subtitle: Text('${p.stock} ${p.unit} • Sale ₹${p.salePrice.toStringAsFixed(0)}'),
                            trailing: Wrap(
                              children: [
                                IconButton(icon: const Icon(Icons.remove), onPressed: () async {
                                  await _db.adjustStock(p.id, -1);
                                  await _loadProducts();
                                  setModalState(() {});
                                }),
                                IconButton(icon: const Icon(Icons.add), onPressed: () async {
                                  await _db.adjustStock(p.id, 1);
                                  await _loadProducts();
                                  setModalState(() {});
                                }),
                              ],
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<Product?> _productDialog() async {
    final name = TextEditingController();
    final price = TextEditingController();
    final stock = TextEditingController(text: '0');
    return showDialog<Product>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Add Product'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: name, decoration: const InputDecoration(labelText: 'Product name')),
            TextField(controller: price, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Sale price')),
            TextField(controller: stock, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Opening stock')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              if (name.text.trim().isEmpty) return;
              Navigator.pop(context, Product(
                name: name.text.trim(),
                salePrice: double.tryParse(price.text) ?? 0,
                stock: double.tryParse(stock.text) ?? 0,
              ));
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _snack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }
}
