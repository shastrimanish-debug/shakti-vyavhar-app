import 'dart:convert';
import 'package:http/http.dart' as http;
import 'bhavya_ai_service.dart';

/// Optional LLM layer. It only returns an allow-listed intent; it never
/// receives database credentials and never executes a business action.
class BhavyaLlmService {
  static const endpoint = String.fromEnvironment('BHAVYA_LLM_URL', defaultValue: '');
  static const apiKey = String.fromEnvironment('BHAVYA_LLM_API_KEY', defaultValue: '');
  static const model = String.fromEnvironment('BHAVYA_LLM_MODEL', defaultValue: 'gpt-4o-mini');
  bool get enabled => endpoint.trim().isNotEmpty && apiKey.trim().isNotEmpty;

  Future<BhavyaIntent?> interpret({required String text, required List<String> partyNames, required PartyKind lastPartyKind, String? lastPartyName}) async {
    if (!enabled) return null;
    final actions = IntentAction.values.map((e) => e.name).join(', ');
    final parties = partyNames.take(200).join(', ');
    final system = 'You are Bhavya, a business voice assistant for an Indian digital khata. '
        'Convert natural Hindi, Hinglish, English, or mixed speech into ONLY valid JSON. '
        'Allowed actions: $actions. '
        'Return exactly {"action":"...","amount":null,"customerName":null,"partyKind":"customer|supplier|any","material":null}. '
        'Never invent names or amounts. Use null when missing. Words such as lena, lene, le, dena, kar lena, jodo, jod, add, naya/new are command words, NOT person names. For a request like naya supplier jodo lena, set customerName to null. Only return a supplier name when a distinct name is explicitly present. '
        'Understand colloquial word order, fillers, honorifics, STT mistakes and multi-word names. '
        'jama/payment diya/paise de diye/vasool normally means addDebit. '
        'udhaar/credit/khate mein chadha do normally means addCredit. '
        'baki/balance/dena/lena means checkBalance. '
        'hisab/len-den/transactions means showHistory unless it clearly asks for an aggregate report. '
        'Resolve uska/isko/isme/wahi/same party to the previous party when available. '
        'Prefer names from the known party list. Casual conversation => conversation. Unclear => unknown. '
        'Previous party: ${lastPartyName ?? 'none'} (${lastPartyKind.name}). Known parties: $parties';
    final body = {'model': model, 'temperature': 0, 'messages': [
      {'role':'system','content':system}, {'role':'user','content':text}
    ], 'response_format': {'type':'json_object'}};
    try {
      final r = await http.post(Uri.parse(endpoint), headers: {'Content-Type':'application/json','Authorization':'Bearer $apiKey'}, body: jsonEncode(body)).timeout(const Duration(seconds: 12));
      if (r.statusCode < 200 || r.statusCode >= 300) return null;
      final d=jsonDecode(r.body); final content=d['choices']?[0]?['message']?['content'];
      if (content is! String) return null;
      final raw=jsonDecode(content); if (raw is! Map) return null;
      final actionName=raw['action']?.toString(); IntentAction? action;
      for (final a in IntentAction.values) { if (a.name==actionName) { action=a; break; } }
      if (action==null) return null;
      final pk=raw['partyKind']?.toString();
      final kind=pk=='customer' ? PartyKind.customer : pk=='supplier' ? PartyKind.supplier : PartyKind.any;
      final ar=raw['amount']; final amount=ar is num ? ar.toDouble() : double.tryParse(ar?.toString() ?? '');
      final n=raw['customerName']?.toString().trim(); final m=raw['material']?.toString().trim();
      return BhavyaIntent(action: action, amount: amount!=null && amount>0 ? amount : null, customerName: n==null || n.isEmpty ? null : n, partyKind: kind, material: m==null || m.isEmpty ? null : m, rawText: text);
    } catch (_) { return null; }
  }

  Future<String?> chat({required String text, required String language, required String businessName}) async {
    if (!enabled) return null;
    final system='You are Bhavya, a concise friendly voice assistant inside Shakti Vyavhar. '
        'Reply naturally in the user language (Hindi/Hinglish/English). '
        'You do not have database access in this chat call, so never claim a balance, transaction, customer record, or action was completed. '
        'Business: $businessName. Language: $language.';
    final body={'model':model,'temperature':0.4,'messages':[{'role':'system','content':system},{'role':'user','content':text}]};
    try {
      final r=await http.post(Uri.parse(endpoint), headers:{'Content-Type':'application/json','Authorization':'Bearer $apiKey'}, body:jsonEncode(body)).timeout(const Duration(seconds:12));
      if(r.statusCode<200 || r.statusCode>=300) return null;
      final d=jsonDecode(r.body); final c=d['choices']?[0]?['message']?['content'];
      return c is String && c.trim().isNotEmpty ? c.trim() : null;
    } catch (_) { return null; }
  }
}