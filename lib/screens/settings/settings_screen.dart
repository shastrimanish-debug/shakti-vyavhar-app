import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/business.dart';
import '../../providers/app_providers.dart';
import '../../services/bhavya_ai_service.dart';
import '../tools/business_tools_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final active = provider.activeBusiness;
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(children: [
        const Padding(padding: EdgeInsets.all(16), child: Text('Business', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16))),
        ListTile(
          leading: const Icon(Icons.store),
          title: Text(active?.name ?? 'Mera Business'),
          subtitle: Text('Active business • ${provider.businesses.length} business profile(s)'),
          trailing: const Icon(Icons.edit),
          onTap: () => _editBusiness(context, provider, active),
        ),
        ListTile(
          leading: const Icon(Icons.add_business),
          title: const Text('Add another business'),
          subtitle: const Text('Business-wise customers, transactions and stock'),
          onTap: () async {
            final c = TextEditingController();
            final ok = await showDialog<bool>(context: context, builder: (_) => AlertDialog(title: const Text('New Business'), content: TextField(controller: c, autofocus: true, decoration: const InputDecoration(labelText: 'Business name')), actions: [TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')), ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('Create'))]));
            if (ok == true && c.text.trim().isNotEmpty) await provider.createBusiness(c.text);
          },
        ),
        if (provider.businesses.length > 1)
          ...provider.businesses.map((b) => RadioListTile<String>(value: b.id, groupValue: provider.activeBusinessId, title: Text(b.name), subtitle: Text(b.gstin ?? 'GSTIN not set'), onChanged: (id) { if (id != null) provider.switchBusiness(id); })),
        const Divider(),
        const Padding(padding: EdgeInsets.all(16), child: Text('Language / Bhasha', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16))),
        ...BhavyaAIService.supportedLocales.entries.map((e) => ListTile(
          leading: Icon(provider.currentLanguage == e.key ? Icons.radio_button_checked : Icons.radio_button_off, color: provider.currentLanguage == e.key ? const Color(0xFFFF6B00) : null),
          title: Text(_languageName(e.key)), subtitle: Text(e.value),
          onTap: () { provider.setLanguage(e.key); ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Language changed to ${_languageName(e.key)}'))); },
        )),
        const Divider(),
        ListTile(leading: const Icon(Icons.business_center), title: const Text('Business Tools'), subtitle: const Text('WhatsApp, SMS, UPI, PDF, GST, stock, backup'), trailing: const Icon(Icons.chevron_right), onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const BusinessToolsScreen()))),
        ListTile(leading: const Icon(Icons.cloud_off), title: const Text('Cloud Sync'), subtitle: const Text('Not configured — local backup/restore is active'), onTap: () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Cloud sync ke liye server/account configuration chahiye.')))),
        ListTile(leading: const Icon(Icons.info_outline), title: const Text('About Shakti Vyavhar'), subtitle: const Text('v1.8.0 • Bhavya powered by SHIV SHAKTI'), onTap: () => showAboutDialog(context: context, applicationName: 'Shakti Vyavhar', applicationVersion: '1.8.0', applicationLegalese: '© 2026 • Bhavya AI powered by SHIV SHAKTI', children: const [SizedBox(height: 16), Text('Advanced Digital Khata for Bharat.\nVoice se chalao, Bhavya ke saath.')]))
      ]),
    );
  }

  static Future<void> _editBusiness(BuildContext context, AppProvider provider, Business? business) async {
    if (business == null) return;
    final name = TextEditingController(text: business.name);
    final owner = TextEditingController(text: business.ownerName ?? '');
    final phone = TextEditingController(text: business.phone ?? '');
    final address = TextEditingController(text: business.address ?? '');
    final gst = TextEditingController(text: business.gstin ?? '');
    final upi = TextEditingController(text: business.upiId ?? '');
    final ok = await showDialog<bool>(context: context, builder: (_) => AlertDialog(title: const Text('Business Profile'), content: SingleChildScrollView(child: Column(children: [TextField(controller: name, decoration: const InputDecoration(labelText: 'Business name')), TextField(controller: owner, decoration: const InputDecoration(labelText: 'Owner name')), TextField(controller: phone, decoration: const InputDecoration(labelText: 'Phone')), TextField(controller: address, decoration: const InputDecoration(labelText: 'Address')), TextField(controller: gst, decoration: const InputDecoration(labelText: 'GSTIN')), TextField(controller: upi, decoration: const InputDecoration(labelText: 'Business UPI ID (e.g. shop@upi)'))])), actions: [TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')), ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('Save'))]));
    if (ok == true) await provider.saveBusiness(Business(id: business.id, name: name.text.trim().isEmpty ? business.name : name.text.trim(), ownerName: owner.text.trim(), phone: phone.text.trim(), address: address.text.trim(), gstin: gst.text.trim(), upiId: upi.text.trim(), currency: business.currency, language: business.language, createdAt: business.createdAt));
  }

  String _languageName(String code) => const {'hi': 'हिन्दी (Hindi)', 'en': 'English', 'mr': 'मराठी (Marathi)', 'gu': 'ગુજરાતી (Gujarati)', 'ta': 'தமிழ் (Tamil)', 'te': 'తెలుగు (Telugu)', 'bn': 'বাংলা (Bengali)', 'pa': 'ਪੰਜਾਬੀ (Punjabi)', 'kn': 'ಕನ್ನಡ (Kannada)', 'ml': 'മലയാളം (Malayalam)'}[code] ?? code;
}
