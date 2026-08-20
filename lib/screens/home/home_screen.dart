import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/app_providers.dart';
import '../customers/customers_screen.dart';
import '../ai/bhavya_screen.dart';
import '../reports/reports_screen.dart';
import '../settings/settings_screen.dart';
import '../../widgets/stat_card.dart';
import '../tools/business_tools_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;

  void switchTab(int index) {
    setState(() => _currentIndex = index);
  }

  final List<Widget> _screens = const [
    DashboardTab(),
    CustomersScreen(),
    BhavyaScreen(),
    ReportsScreen(),
    SettingsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _screens[_currentIndex],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) {
          setState(() => _currentIndex = index);
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.dashboard_outlined),
            selectedIcon: Icon(Icons.dashboard),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.people_outline),
            selectedIcon: Icon(Icons.people),
            label: 'Customers',
          ),
          NavigationDestination(
            icon: Icon(Icons.mic_none),
            selectedIcon: Icon(Icons.mic),
            label: 'Bhavya',
          ),
          NavigationDestination(
            icon: Icon(Icons.bar_chart_outlined),
            selectedIcon: Icon(Icons.bar_chart),
            label: 'Reports',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings),
            label: 'Settings',
          ),
        ],
      ),
    );
  }
}

class DashboardTab extends StatelessWidget {
  const DashboardTab({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<AppProvider>(context);
    final stats = provider.stats;

    return Scaffold(
      appBar: AppBar(
        title: const Column(
          children: [
            Text(
              'Shakti Vyavhar',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
            ),
            Text(
              'Bhavya • SHIV SHAKTI',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w300),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Business Tools',
            icon: const Icon(Icons.business_center_outlined),
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const BusinessToolsScreen())),
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              provider.loadCustomers();
              provider.loadStats();
            },
          ),
        ],
      ),
      body: provider.isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: () async {
                await provider.loadCustomers();
                await provider.loadStats();
              },
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Welcome banner
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFFFF6B00), Color(0xFFFF8F00)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(14),
                                child: Image.asset('assets/shakti_vyavhar_logo.jpg', width: 58, height: 58, fit: BoxFit.cover),
                              ),
                              const SizedBox(width: 12),
                              const Expanded(
                                child: Text(
                                  '🙏 Namaste!',
                                  style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Bhavya ready hai. Voice se hisab-kitab chalao.',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.95),
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 12),
                          ElevatedButton.icon(
                            onPressed: () {
                              // Switch to Bhavya tab (index 2)
                              final homeState =
                                  context.findAncestorStateOfType<_HomeScreenState>();
                              if (homeState != null) {
                                homeState.switchTab(2);
                              }
                            },
                            icon: const Icon(Icons.mic, size: 18),
                            label: const Text('Bhavya se baat karo'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white,
                              foregroundColor: const Color(0xFFFF6B00),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Stats Grid
                    Text(
                      'Aaj ka Hisab',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const SizedBox(height: 12),
                    GridView.count(
                      crossAxisCount: 2,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      mainAxisSpacing: 12,
                      crossAxisSpacing: 12,
                      childAspectRatio: 1.4,
                      children: [
                        StatCard(
                          title: 'Lena Hai',
                          value: '₹${(stats['totalReceivable'] ?? 0).toStringAsFixed(0)}',
                          icon: Icons.arrow_downward,
                          color: Colors.green,
                        ),
                        StatCard(
                          title: 'Dena Hai',
                          value: '₹${(stats['totalPayable'] ?? 0).toStringAsFixed(0)}',
                          icon: Icons.arrow_upward,
                          color: Colors.red,
                        ),
                        StatCard(
                          title: 'Customers',
                          value: '${(stats['customerCount'] ?? 0).toInt()}',
                          icon: Icons.people,
                          color: Colors.blue,
                        ),
                        StatCard(
                          title: 'Suppliers',
                          value: '${(stats['supplierCount'] ?? 0).toInt()}',
                          icon: Icons.store,
                          color: Colors.purple,
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // Recent Customers
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Customers',
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                        TextButton(
                          onPressed: () {
                            final homeState =
                                context.findAncestorStateOfType<_HomeScreenState>();
                            if (homeState != null) {
                              homeState.switchTab(1);
                            }
                          },
                          child: const Text('Sab Dekho'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    if (provider.customerParties.isEmpty)
                      const Card(
                        child: Padding(
                          padding: EdgeInsets.all(24),
                          child: Center(
                            child: Text('Abhi koi customer nahi hai.\nPehla customer add karo!'),
                          ),
                        ),
                      )
                    else
                      ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: provider.customerParties.take(5).length,
                        itemBuilder: (context, index) {
                          final c = provider.customerParties[index];
                          return FutureBuilder<double>(
                            future: provider.getBalance(c.id),
                            builder: (context, snapshot) {
                              final bal = snapshot.data ?? 0;
                              return ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: const Color(0xFFFF6B00).withOpacity(0.15),
                                  child: Text(
                                    c.name.isNotEmpty ? c.name[0].toUpperCase() : '?',
                                    style: const TextStyle(
                                      color: Color(0xFFFF6B00),
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                title: Text(c.name),
                                subtitle: Text(c.phone ?? 'No phone'),
                                trailing: Text(
                                  '₹${bal.abs().toStringAsFixed(0)}',
                                  style: TextStyle(
                                    color: bal >= 0 ? Colors.green : Colors.red,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              );
                            },
                          );
                        },
                      ),
                  ],
                ),
              ),
            ),
    );
  }
}
