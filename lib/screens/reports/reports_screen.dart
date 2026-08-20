import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/app_providers.dart';
import '../../services/business_tools_service.dart';
import '../../services/database_service.dart';
import '../../widgets/stat_card.dart';
import '../../models/transaction.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});
  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  DateTimeRange? _range;
  List<Transaction> _transactions = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    final provider = context.read<AppProvider>();
    await provider.loadCustomers();
    await provider.loadStats();
    final txns = await DatabaseService().getAllTransactions(
      businessId: provider.activeBusinessId,
      from: _range?.start,
      to: _range == null ? null : DateTime(_range!.end.year, _range!.end.month, _range!.end.day, 23, 59, 59),
    );
    if (mounted) setState(() { _transactions = txns; _loading = false; });
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final stats = provider.stats;
    final partyCount = provider.customerParties.length + provider.supplierParties.length;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Reports & Hisab'),
        actions: [IconButton(onPressed: _refresh, icon: const Icon(Icons.refresh))],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _refresh,
              child: ListView(padding: const EdgeInsets.all(16), children: [
                Row(children: [
                  Expanded(child: Text('Overall Summary', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold))),
                  OutlinedButton.icon(
                    onPressed: () async {
                      final picked = await showDateRangePicker(context: context, firstDate: DateTime(2020), lastDate: DateTime.now());
                      if (picked != null) { setState(() => _range = picked); await _refresh(); }
                    },
                    icon: const Icon(Icons.date_range), label: Text(_range == null ? 'Date' : 'Filtered'),
                  ),
                ]),
                const SizedBox(height: 16),
                GridView.count(
                  crossAxisCount: 2, shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), mainAxisSpacing: 12, crossAxisSpacing: 12, childAspectRatio: 1.3,
                  children: [
                    StatCard(title: 'Total Receivable', value: '₹${(stats['totalReceivable'] ?? 0).toStringAsFixed(0)}', icon: Icons.trending_up, color: Colors.green),
                    StatCard(title: 'Total Payable', value: '₹${(stats['totalPayable'] ?? 0).toStringAsFixed(0)}', icon: Icons.trending_down, color: Colors.red),
                    StatCard(title: 'Net Position', value: '₹${(stats['netBalance'] ?? 0).toStringAsFixed(0)}', icon: Icons.account_balance_wallet, color: Colors.blue),
                    StatCard(title: 'Total Parties', value: '$partyCount', icon: Icons.groups, color: Colors.purple),
                  ],
                ),
                const SizedBox(height: 20),
                Card(child: ListTile(leading: const Icon(Icons.receipt_long), title: const Text('Transactions'), subtitle: Text('${_transactions.length} entries in selected period'))),
                Card(child: ListTile(leading: const Icon(Icons.picture_as_pdf), title: const Text('PDF Report'), onTap: () async {
                  final tools = BusinessToolsService(DatabaseService());
                  await tools.shareReport(businessName: provider.activeBusiness?.name ?? 'Shakti Vyavhar', stats: stats, transactions: _transactions);
                })),
                Card(child: ListTile(leading: const Icon(Icons.table_chart), title: const Text('Excel-compatible CSV'), subtitle: const Text('Share/download transaction data'), onTap: () async {
                  await BusinessToolsService(DatabaseService()).shareTransactionsCsv(_transactions);
                })),
                Card(child: ListTile(leading: const Icon(Icons.receipt), title: const Text('GST Summary'), subtitle: const Text('GST invoices are available in Business Tools'))),
                Card(child: ListTile(leading: const Icon(Icons.inventory_2), title: const Text('Inventory / Stock'), subtitle: const Text('Manage stock from Business Tools'))),
                Card(child: ListTile(leading: const Icon(Icons.backup), title: const Text('Backup / Restore'), subtitle: const Text('Complete local database backup in Business Tools'))),
                const SizedBox(height: 12),
                if (_range != null) TextButton(onPressed: () async { setState(() => _range = null); await _refresh(); }, child: const Text('Clear date filter')),
              ]),
            ),
    );
  }
}
