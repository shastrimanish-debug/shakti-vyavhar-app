import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/app_providers.dart';
import '../../models/customer.dart';
import 'customer_detail_screen.dart';
import 'add_customer_screen.dart';

/// Separate Customer and Supplier ledgers.
/// Customer-only actions (invoice, statement, UPI collection and payment
/// reminders) are intentionally kept out of the Supplier tab.
class CustomersScreen extends StatefulWidget {
  const CustomersScreen({super.key});

  @override
  State<CustomersScreen> createState() => _CustomersScreenState();
}

class _CustomersScreenState extends State<CustomersScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
    _tabs.addListener(() => setState(() {}));
    _searchController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _tabs.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Parties'),
        bottom: TabBar(
          controller: _tabs,
          tabs: [
            Tab(text: 'Customers (${provider.customerParties.length})', icon: const Icon(Icons.people)),
            Tab(text: 'Suppliers (${provider.supplierParties.length})', icon: const Icon(Icons.store)),
          ],
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Naam ya mobile search karo...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchController.text.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: _searchController.clear,
                      ),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                filled: true,
              ),
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabs,
              children: [
                _PartyList(parties: provider.customerParties, isSupplier: false),
                _PartyList(parties: provider.supplierParties, isSupplier: true),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          final isSupplier = _tabs.index == 1;
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => AddCustomerScreen(initialIsSupplier: isSupplier),
            ),
          ).then((_) => provider.loadCustomers());
        },
        icon: const Icon(Icons.person_add),
        label: Text(_tabs.index == 1 ? 'Add Supplier' : 'Add Customer'),
      ),
    );
  }
}

class _PartyList extends StatelessWidget {
  final List<Customer> parties;
  final bool isSupplier;

  const _PartyList({required this.parties, required this.isSupplier});

  @override
  Widget build(BuildContext context) {
    final query = context.findAncestorStateOfType<_CustomersScreenState>()?._searchController.text.trim().toLowerCase() ?? '';
    final filtered = query.isEmpty
        ? parties
        : parties.where((p) => p.name.toLowerCase().contains(query) || (p.phone ?? '').contains(query)).toList();

    if (filtered.isEmpty) {
      return Center(
        child: Text(
          isSupplier ? 'Abhi koi supplier nahi hai.\n+ se supplier add karo.' : 'Abhi koi customer nahi hai.\n+ se customer add karo.',
          textAlign: TextAlign.center,
        ),
      );
    }

    final provider = context.read<AppProvider>();
    return RefreshIndicator(
      onRefresh: provider.loadCustomers,
      child: ListView.builder(
        padding: const EdgeInsets.only(bottom: 90),
        itemCount: filtered.length,
        itemBuilder: (context, index) {
          final party = filtered[index];
          return FutureBuilder<double>(
            future: provider.getBalance(party.id),
            builder: (context, snapshot) {
              final balance = snapshot.data ?? 0;
              final positiveLabel = party.isSupplier ? 'Dena' : 'Lena';
              final negativeLabel = party.isSupplier ? 'Lena' : 'Dena';
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: isSupplier
                        ? Colors.deepPurple.withOpacity(.12)
                        : const Color(0xFFFF6B00).withOpacity(.12),
                    child: Icon(isSupplier ? Icons.store : Icons.person,
                        color: isSupplier ? Colors.deepPurple : const Color(0xFFFF6B00)),
                  ),
                  title: Text(party.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: Text(party.phone ?? 'Mobile missing'),
                  trailing: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text('₹${balance.abs().toStringAsFixed(0)}',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16,
                              color: balance >= 0 ? Colors.green : Colors.red)),
                      Text(balance >= 0 ? positiveLabel : negativeLabel,
                          style: TextStyle(fontSize: 11,
                              color: balance >= 0 ? Colors.green : Colors.red)),
                    ],
                  ),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => CustomerDetailScreen(customer: party)),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
