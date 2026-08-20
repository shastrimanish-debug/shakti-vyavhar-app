import 'package:flutter/foundation.dart';
import '../models/customer.dart';
import '../models/business.dart';
import '../models/transaction.dart';
import '../services/database_service.dart';
import '../services/bhavya_ai_service.dart';
import '../services/bhavya_llm_service.dart';
import '../services/business_tools_service.dart';

class AppProvider extends ChangeNotifier {
  final DatabaseService _db = DatabaseService();
  final BhavyaAIService _bhavya = BhavyaAIService();
  final BhavyaLlmService _bhavyaLlm = BhavyaLlmService();
  late final BusinessToolsService _tools = BusinessToolsService(_db);

  List<Customer> _customers = [];
  final List<Transaction> _transactions = [];
  Map<String, double> _stats = {};
  bool _isLoading = false;
  String _currentLanguage = 'hi';
  String? _error;
  List<Business> _businesses = [];
  String _activeBusinessId = DatabaseService.defaultBusinessId;

  // Bhavya conversation memory: the last resolved party stays available for
  // natural follow-up commands such as "isme 50000 credit karo" or
  // "uska balance batao". It is scoped to the active business.
  Customer? _lastBhavyaParty;
  PartyKind _lastBhavyaPartyKind = PartyKind.any;

  List<Customer> get customers => _customers;
  List<Customer> get customerParties => _customers.where((c) => !c.isSupplier).toList(growable: false);
  List<Customer> get supplierParties => _customers.where((c) => c.isSupplier).toList(growable: false);
  List<Transaction> get transactions => _transactions;
  Map<String, double> get stats => _stats;
  bool get isLoading => _isLoading;
  String get currentLanguage => _currentLanguage;
  String? get error => _error;
  BhavyaAIService get bhavya => _bhavya;
  List<Business> get businesses => _businesses;
  String get activeBusinessId => _activeBusinessId;
  Business? get activeBusiness => _businesses.where((b) => b.id == _activeBusinessId).isEmpty ? null : _businesses.firstWhere((b) => b.id == _activeBusinessId);

  Future<void> init() async {
    _isLoading = true;
    notifyListeners();
    try {
      await _bhavya.initialize(languageCode: _currentLanguage);
      await loadBusinesses();
      await loadCustomers();
      await loadStats();
    } catch (e) {
      _error = e.toString();
    }
    _isLoading = false;
    notifyListeners();
  }

  Future<void> loadBusinesses() async {
    _businesses = await _db.getBusinesses();
    if (_businesses.isNotEmpty && !_businesses.any((b) => b.id == _activeBusinessId)) {
      _activeBusinessId = _businesses.first.id;
      _currentLanguage = _businesses.first.language;
      await _bhavya.setLanguage(_currentLanguage);
    }
    notifyListeners();
  }

  Future<void> createBusiness(String name) async {
    final id = await _db.createBusiness(name);
    await loadBusinesses();
    await switchBusiness(id);
  }

  Future<void> saveBusiness(Business business) async {
    await _db.saveBusiness(business);
    await loadBusinesses();
    if (business.id == _activeBusinessId) {
      _currentLanguage = business.language;
      await _bhavya.setLanguage(_currentLanguage);
      notifyListeners();
    }
  }

  Future<void> switchBusiness(String id) async {
    if (!_businesses.any((b) => b.id == id)) return;
    _activeBusinessId = id;
    _lastBhavyaParty = null;
    _lastBhavyaPartyKind = PartyKind.any;
    final business = _businesses.firstWhere((b) => b.id == id);
    _currentLanguage = business.language;
    await _bhavya.setLanguage(_currentLanguage);
    await loadCustomers();
    await loadStats();
    notifyListeners();
  }

  Future<void> loadCustomers() async {
    _customers = await _db.getAllCustomers(businessId: _activeBusinessId);
    notifyListeners();
  }

  Future<void> loadStats() async {
    _stats = await _db.getDashboardStats(businessId: _activeBusinessId);
    notifyListeners();
  }

  Future<void> addCustomer(Customer customer) async {
    await _db.insertCustomer(customer.copyWith(businessId: _activeBusinessId), businessId: _activeBusinessId);
    await loadCustomers();
    await loadStats();
  }

  Future<void> updateCustomer(Customer customer) async {
    await _db.updateCustomer(customer);
    await loadCustomers();
  }

  Future<void> deleteCustomer(String id) async {
    await _db.deleteCustomer(id, businessId: _activeBusinessId);
    await loadCustomers();
    await loadStats();
  }

  Future<void> addTransaction(Transaction txn) async {
    if (txn.amount <= 0) throw ArgumentError('Transaction amount must be greater than zero');
    if (txn.customerId.trim().isEmpty) throw ArgumentError('Party is required');
    await _db.insertTransaction(txn.copyWith(businessId: _activeBusinessId), businessId: _activeBusinessId);
    await loadStats();
  }

  Future<List<Transaction>> getCustomerTransactions(String customerId) async {
    return await _db.getTransactionsByCustomer(customerId, businessId: _activeBusinessId);
  }

  Future<double> getBalance(String customerId) async {
    return await _db.getCustomerBalance(customerId, businessId: _activeBusinessId);
  }

  Future<List<Customer>> searchCustomers(String query) async {
    if (query.isEmpty) return _customers;
    return await _db.searchCustomers(query, businessId: _activeBusinessId);
  }

  void setLanguage(String code) {
    _currentLanguage = code;
    _bhavya.setLanguage(code);
    notifyListeners();
  }

  // ========== BHAVYA VOICE COMMAND HANDLER ==========

  void _rememberBhavyaParty(Customer party) {
    _lastBhavyaParty = party;
    _lastBhavyaPartyKind = party.isSupplier ? PartyKind.supplier : PartyKind.customer;
  }

  Customer? _resolveBhavyaParty(BhavyaIntent intent, String originalText) {
    final name = intent.customerName ??
        (_bhavya.isContextReference(originalText) ? _lastBhavyaParty?.name : null);
    if (name == null || name.trim().isEmpty) return null;

    final kind = intent.partyKind == PartyKind.any
        ? (_bhavya.isContextReference(originalText) ? _lastBhavyaPartyKind : PartyKind.any)
        : intent.partyKind;

    final party = _findPartyByName(name, kind: kind);
    if (party != null) _rememberBhavyaParty(party);
    return party;
  }

  String _missingPartyMessage({bool customerOnly = false}) {
    if (_currentLanguage == 'hi') {
      return customerOnly
          ? 'Customer ka naam boliye, ya jis customer ki baat abhi hui thi uske liye "usko" bol sakte hain.'
          : 'Party ka naam boliye, ya pichhli party ke liye "usko", "uska" ya "isme" bol sakte hain.';
    }
    return customerOnly
        ? 'Please say the customer name, or use "him/her" for the customer from the previous turn.'
        : 'Please say the party name, or use "that party", "it", or "same party" for the previous turn.';
  }

  String? _extractSupplierNameCandidate(String text) {
    final t = text.trim().replaceAll(RegExp(r'\\s+'), ' ');
    final m = RegExp(
      r'(?:naya\\s+supplier|new\\s+supplier|supplier)\\s+(?:jodo|jod|add|banao|bana)\\s+(.+)$',
      caseSensitive: false,
    ).firstMatch(t);
    if (m == null) return null;
    final raw = m.group(1)?.trim();
    if (raw == null || raw.isEmpty) return null;
    return raw.split(RegExp(r'\\s+(?:ko|ji|please|bhai|bhaiya)$', caseSensitive: false)).first.trim();
  }

  bool _looksLikeExplicitNamePhrase(String text) {
    final t = text.toLowerCase().replaceAll(RegExp(r'\\s+'), ' ').trim();
    return RegExp(r'\\b(?:naam|name)\\s+(?:lena|leena)\\b').hasMatch(t) ||
        RegExp(r'\\b(?:lena|leena)\\s+(?:ko|ji)\\b').hasMatch(t);
  }

  bool _isBhavyaCommandOnlyName(String name) {
    final t = name.toLowerCase().trim().replaceAll(RegExp(r'\s+'), ' ');
    const filler = {
      'jodo', 'jod', 'add', 'lena', 'lene', 'le', 'dena', 'dene', 'do', 'de',
      'kar', 'karo', 'karna', 'karke', 'rakhna', 'rakho', 'naya', 'new',
      'supplier', 'सप्लायर', 'जोड़ो', 'जोड़', 'लेना', 'लेने', 'ले', 'देना', 'देने',
      'नया', 'करना', 'करके', 'रखना', 'रखो',
    };
    final words = t.split(' ');
    return words.isNotEmpty && words.every(filler.contains);
  }

  Future<String> processVoiceCommand(String text) async {
    final localIntent = _bhavya.parseCommand(text);
    BhavyaIntent intent = localIntent;
    if (_bhavyaLlm.enabled) {
      final aiIntent = await _bhavyaLlm.interpret(
        text: text,
        partyNames: _customers.map((p) => p.name).toList(growable: false),
        lastPartyKind: _lastBhavyaPartyKind,
        lastPartyName: _lastBhavyaParty?.name,
      );
      if (aiIntent != null) {
        intent = BhavyaIntent(
          action: aiIntent.action,
          amount: aiIntent.amount ?? localIntent.amount,
          customerName: aiIntent.customerName ?? localIntent.customerName,
          partyKind: aiIntent.partyKind == PartyKind.any ? localIntent.partyKind : aiIntent.partyKind,
          material: aiIntent.material ?? localIntent.material,
          rawText: text,
        );
      }
    }
    final contextParty = _resolveBhavyaParty(intent, text);

    switch (intent.action) {
      case IntentAction.findParty:
        final found = contextParty;
        if (found == null) {
          return _currentLanguage == 'hi'
              ? 'Customer ya supplier ka naam nahi mila. Naam boliye, ya pichhli party ke liye "usko" boliye.'
              : 'I could not resolve the party. Please say the name or refer to the previous party.';
        }
        final balance = await getBalance(found.id);
        final role = found.isSupplier ? 'supplier' : 'customer';
        return _currentLanguage == 'hi'
            ? '${found.name} mil gaya. Ye $role hai. Balance ₹${balance.abs().toStringAsFixed(0)} hai.'
            : '${found.name} found. This is a $role. Balance is ₹${balance.abs().toStringAsFixed(0)}.';

      case IntentAction.addCredit:
        if (contextParty == null || intent.amount == null) {
          return intent.amount == null ? 'Amount bhi boliye, jaise "50 hazaar".' : _missingPartyMessage();
        }

        final party = contextParty;
        await addTransaction(Transaction(
          customerId: party.id,
          type: TransactionType.credit,
          amount: intent.amount!,
          description: party.isSupplier
              ? 'Voice entry by Bhavya (Supplier)'
              : 'Voice entry by Bhavya (Customer)',
        ));

        if (party.isSupplier) {
          return _currentLanguage == 'hi'
              ? '${party.name} supplier hai. Uske supplier ledger mein ₹${intent.amount!.toStringAsFixed(0)} credit kar diya.'
              : '${party.name} is a supplier. Added ₹${intent.amount!.toStringAsFixed(0)} credit to the supplier ledger.';
        }

        return _currentLanguage == 'hi'
            ? '${party.name} customer ko ₹${intent.amount!.toStringAsFixed(0)} credit kar diya gaya.'
            : 'Added ₹${intent.amount!.toStringAsFixed(0)} credit to ${party.name}.';

      case IntentAction.addDebit:
        if (contextParty == null || intent.amount == null) {
          return intent.amount == null ? 'Amount bhi boliye, jaise "50 hazaar".' : _missingPartyMessage();
        }

        final party = contextParty;
        await addTransaction(Transaction(
          customerId: party.id,
          type: TransactionType.debit,
          amount: intent.amount!,
          description: party.isSupplier
              ? 'Voice entry by Bhavya (Supplier)'
              : 'Voice entry by Bhavya (Customer)',
        ));

        if (party.isSupplier) {
          return _currentLanguage == 'hi'
              ? '${party.name} supplier hai. Uske supplier ledger mein ₹${intent.amount!.toStringAsFixed(0)} debit kar diya.'
              : '${party.name} is a supplier. Added ₹${intent.amount!.toStringAsFixed(0)} debit to the supplier ledger.';
        }

        return _currentLanguage == 'hi'
            ? '${party.name} customer ko ₹${intent.amount!.toStringAsFixed(0)} debit kar diya gaya.'
            : 'Added ₹${intent.amount!.toStringAsFixed(0)} debit to ${party.name}.';

      case IntentAction.checkBalance:
        final party = contextParty;
        if (party == null) return _missingPartyMessage();
        final bal = await getBalance(party.id);
        final isSupplier = party.isSupplier;
        final status = bal >= 0
            ? (_currentLanguage == 'hi'
                ? (isSupplier ? 'dena hai' : 'lena hai')
                : (isSupplier ? 'payable' : 'receivable'))
            : (_currentLanguage == 'hi'
                ? (isSupplier ? 'lena hai' : 'dena hai')
                : (isSupplier ? 'receivable' : 'payable'));

        return _currentLanguage == 'hi'
            ? '${party.name} ${isSupplier ? 'supplier' : 'customer'} hai. Balance ₹${bal.abs().toStringAsFixed(0)} $status.'
            : '${party.name} is a ${isSupplier ? 'supplier' : 'customer'}. Balance is ₹${bal.abs().toStringAsFixed(0)} ($status).';

      case IntentAction.showReport:
        await loadStats();
        return _currentLanguage == 'hi'
            ? 'Total lena: ₹${_stats['totalReceivable']?.toStringAsFixed(0) ?? 0}, Total dena: ₹${_stats['totalPayable']?.toStringAsFixed(0) ?? 0}'
            : 'Total Receivable: ₹${_stats['totalReceivable']?.toStringAsFixed(0) ?? 0}, Payable: ₹${_stats['totalPayable']?.toStringAsFixed(0) ?? 0}';

      case IntentAction.showHistory:
        final historyParty = contextParty;
        if (historyParty == null) {
          return _currentLanguage == 'hi' ? 'Kis customer ya supplier ka len-den dikhana hai?' : 'Whose transaction history should I show?';
        }
        final history = await getCustomerTransactions(historyParty.id);
        if (history.isEmpty) {
          return _currentLanguage == 'hi' ? '${historyParty.name} ka abhi koi transaction nahi hai.' : '${historyParty.name} has no transactions yet.';
        }
        final recent = history.take(5).map((t) => '${t.isCredit ? '+' : '-'}₹${t.amount.toStringAsFixed(0)}').join(', ');
        return _currentLanguage == 'hi'
            ? '${historyParty.name} ke last ${history.length < 5 ? history.length : 5} transactions: $recent. Total entries ${history.length}.'
            : 'Last ${history.length < 5 ? history.length : 5} transactions for ${historyParty.name}: $recent. Total entries ${history.length}.';

      case IntentAction.whatsappReminder:
      case IntentAction.smsReminder:
      case IntentAction.collectUpi:
      case IntentAction.invoice:
      case IntentAction.gstInvoice:
      case IntentAction.shareStatement:
      case IntentAction.printStatement:
        final customer = contextParty;
        if (customer == null || customer.isSupplier) {
          return _missingPartyMessage(customerOnly: true);
        }
        try {
          final balance = await getBalance(customer.id);
          switch (intent.action) {
            case IntentAction.whatsappReminder:
              await _tools.sendWhatsAppReminder(customer, balance);
              return 'WhatsApp reminder ${customer.name} ke liye khol diya.';
            case IntentAction.smsReminder:
              await _tools.sendSmsReminder(customer, balance);
              return 'SMS reminder ${customer.name} ke liye khol diya.';
            case IntentAction.collectUpi:
              if (intent.amount == null || intent.amount! <= 0) return 'UPI ke liye amount bhi boliye, jaise ${customer.name} se 5000 UPI payment mangao.';
              await _tools.collectUpi(customer, intent.amount!);
              return '₹${intent.amount!.toStringAsFixed(0)} ka UPI payment ${customer.name} ke liye khol diya.';
            case IntentAction.invoice:
              await _tools.shareInvoice(customer, await getCustomerTransactions(customer.id));
              return '${customer.name} ka customer invoice share karne ke liye khol diya.';
            case IntentAction.gstInvoice:
              if (intent.amount == null || intent.amount! <= 0) return 'GST invoice ke liye taxable amount boliye, jaise Ramesh ka 10000 GST invoice banao.';
              await _tools.shareGstInvoice(customer, intent.amount!, 18);
              return '${customer.name} ka 18% GST invoice share karne ke liye khol diya.';
            case IntentAction.shareStatement:
              await _tools.shareInvoice(customer, await getCustomerTransactions(customer.id));
              return '${customer.name} ka statement share karne ke liye khol diya.';
            case IntentAction.printStatement:
              await _tools.printInvoice(customer, await getCustomerTransactions(customer.id));
              return '${customer.name} ka statement print karne ke liye khol diya.';
            default:
              break;
          }
        } catch (e) {
          return 'Bhavya: ${e.toString().replaceFirst('Exception: ', '')}';
        }
        return 'Command complete.';

      case IntentAction.supplierWhatsAppReminder:
      case IntentAction.supplierSmsReminder:
        final supplier = contextParty;
        if (supplier == null || !supplier.isSupplier) return 'Supplier ka naam ya pichhli supplier party ke liye "usko" boliye.';
        try {
          if (intent.action == IntentAction.supplierWhatsAppReminder) {
            await _tools.sendSupplierMaterialReminder(supplier, material: intent.material);
            return '${supplier.name} supplier ke liye material reminder WhatsApp mein khol diya.';
          }
          await _tools.sendSupplierMaterialSms(supplier, material: intent.material);
          return '${supplier.name} supplier ke liye material reminder SMS mein khol diya.';
        } catch (e) {
          return 'Bhavya: ${e.toString().replaceFirst('Exception: ', '')}';
        }

      case IntentAction.addSupplier:
        var supplierName = intent.customerName?.trim();

        // Speech-to-text can hear the real name "Leena" as "lena".
        // If that candidate already exists, resolve it to the stored spelling.
        // If it does not exist and the phrase is ambiguous, do NOT silently
        // create a supplier from the verb "lena"; ask for confirmation.
        if (supplierName == null || supplierName.isEmpty) {
          final candidate = _extractSupplierNameCandidate(text);
          if (candidate != null) {
            final known = _findPartyByName(candidate, kind: PartyKind.supplier);
            if (known != null) {
              return '${known.name} supplier mil gaya.';
            }
            supplierName = candidate;
          }
        }

        // If STT produced "lena" in a phrase where it is clearly the verb,
        // never create a bogus supplier. For a real person name, say it
        // explicitly once (e.g. "Leena ko supplier jodo").
        if (supplierName != null && supplierName.toLowerCase() == 'lena' &&
            !_looksLikeExplicitNamePhrase(text)) {
          return 'Maine "lena" suna hai. Agar naam Leena hai to bolo: "Leena ko supplier jodo."';
        }
        // Never create a supplier from command/filler words. For example,
        // Never silently turn an ambiguous STT token into a supplier.
        // "lena" can be the verb OR the spoken form of the name "Leena".
        if (supplierName == null || supplierName.isEmpty || _isBhavyaCommandOnlyName(supplierName)) {
          return 'Supplier ka naam saaf-saaf boliye. Jaise: Ramesh ko supplier jodo.';
        }
        final existingSupplier = _findPartyByName(supplierName, kind: PartyKind.supplier);
        if (existingSupplier != null) return '${existingSupplier.name} pehle se supplier list mein hai.';
        await addCustomer(Customer(name: supplierName, isSupplier: true));
        return '$supplierName supplier add ho gaya.';

      case IntentAction.partyCount:
        await loadCustomers();
        final count = intent.partyKind == PartyKind.supplier ? supplierParties.length : customerParties.length;
        return intent.partyKind == PartyKind.supplier ? 'Abhi $count suppliers hain.' : 'Abhi $count customers hain.';

      case IntentAction.addCustomer:
        if (intent.customerName == null) {
          return _currentLanguage == 'hi'
              ? 'Customer ka naam boliye.'
              : 'Please say the customer name.';
        }

        final existing = _findPartyByName(intent.customerName!, kind: intent.partyKind);
        if (existing != null) {
          return _currentLanguage == 'hi'
              ? '${existing.name} pehle se ${existing.isSupplier ? 'supplier' : 'customer'} list mein hai.'
              : '${existing.name} already exists as a ${existing.isSupplier ? 'supplier' : 'customer'}.';
        }

        await addCustomer(Customer(name: intent.customerName!));
        return _currentLanguage == 'hi'
            ? '${intent.customerName} customer add ho gaya.'
            : 'Customer ${intent.customerName} added successfully.';

      case IntentAction.conversation:
        final llmReply = await _bhavyaLlm.chat(text: text, language: _currentLanguage, businessName: activeBusiness?.name ?? 'Shakti Vyavhar');
        if (llmReply != null) return llmReply;
        final lower = text.toLowerCase();
        if (lower.contains('thank') || lower.contains('thanks') ||
            lower.contains('shukriya') || lower.contains('धन्यवाद')) {
          return _currentLanguage == 'hi'
              ? 'Arre koi baat nahi. Main yahin hoon. Jo kaam hai seedha bol do.'
              : 'You are welcome. I am here. Just tell me what you need.';
        }
        if (lower.contains('kaise ho') || lower.contains('कैसी हो') ||
            lower.contains('कैसे हो') || lower.contains('kya haal')) {
          return _currentLanguage == 'hi'
              ? 'Main badhiya hoon. Aap batao, aaj kya karna hai?'
              : 'I am doing well. What would you like to do?';
        }
        return _currentLanguage == 'hi'
            ? 'Namaste! Main Bhavya hoon. Aap normal Hindi, Hinglish ya English mein baat kar sakte ho.'
            : 'Hello! I am Bhavya. You can speak naturally in Hindi, Hinglish or English.';

      case IntentAction.help:
        return _bhavya.getHelpText(_currentLanguage);

      case IntentAction.unknown:
        final llmReply = await _bhavyaLlm.chat(text: text, language: _currentLanguage, businessName: activeBusiness?.name ?? 'Shakti Vyavhar');
        if (llmReply != null) return llmReply;
        return _currentLanguage == 'hi'
            ? 'Samajh nahi aaya. Customer ya supplier ka naam aur command dobara boliye.'
            : 'I did not understand. Please say the customer or supplier name and command again.';
    }
  }

  /// Finds the live party in the active business. Exact, substring and
  /// phonetic/fuzzy matching are used so Indian speech recognition mistakes
  /// such as "Ridhesh" for "Ritesh" do not break the command.
  Customer? _findPartyByName(String name, {PartyKind kind = PartyKind.any}) {
    final query = name.trim();
    if (query.isEmpty || _customers.isEmpty) return null;

    final candidates = kind == PartyKind.customer
        ? _customers.where((p) => !p.isSupplier).toList(growable: false)
        : kind == PartyKind.supplier
            ? _customers.where((p) => p.isSupplier).toList(growable: false)
            : _customers;
    if (candidates.isEmpty) return null;

    // 1) Exact and substring matches always win.
    final lower = query.toLowerCase();
    for (final p in candidates) {
      final stored = p.name.trim().toLowerCase();
      if (stored == lower || stored.contains(lower) || lower.contains(stored)) {
        return p;
      }
    }

    // 2) Phonetic match handles Hindi Devanagari, transliteration and common
    // Indian STT substitutions such as Ridhesh -> Ritesh.
    Customer? best;
    var bestDistance = 999;
    for (final p in candidates) {
      final distance = _bhavya.phoneticDistance(query, p.name);
      if (distance < bestDistance) {
        bestDistance = distance;
        best = p;
      }
    }

    // Conservative threshold prevents a short name from matching an
    // unrelated customer merely because it sounds vaguely similar.
    final keyLength = _bhavya.phoneticKey(query).length;
    final maxAllowed = keyLength <= 4 ? 1 : (keyLength <= 7 ? 2 : 3);
    return best != null && bestDistance <= maxAllowed ? best : null;
  }

  Customer? _findCustomerByName(String name) {
    final party = _findPartyByName(name);
    return party?.isSupplier == true ? null : party;
  }


}
