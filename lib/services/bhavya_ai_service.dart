import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:flutter_tts/flutter_tts.dart';
import 'package:permission_handler/permission_handler.dart';

/// Bhavya AI Service - powered by SHIV SHAKTI.
///
/// Understands Indian Hindi speech (Devanagari), Hinglish and English.
/// Customer names are matched phonetically so "रमेश" can match "Ramesh".
class BhavyaAIService {
  static final BhavyaAIService _instance = BhavyaAIService._internal();
  factory BhavyaAIService() => _instance;
  BhavyaAIService._internal();

  final stt.SpeechToText _speech = stt.SpeechToText();
  final FlutterTts _tts = FlutterTts();

  bool _isListening = false;
  bool _isInitialized = false;
  String _currentLocale = 'hi_IN';

  // Keep the latest partial result so a manual stop never loses the command.
  String _lastRecognizedText = '';
  bool _resultDelivered = false;
  Function(String text)? _activeOnResult;
  Function(String status)? _activeOnStatus;

  static const Map<String, String> supportedLocales = {
    'hi': 'hi_IN',
    'en': 'en_IN',
    'mr': 'mr_IN',
    'gu': 'gu_IN',
    'ta': 'ta_IN',
    'te': 'te_IN',
    'bn': 'bn_IN',
    'pa': 'pa_IN',
    'kn': 'kn_IN',
    'ml': 'ml_IN',
  };

  Future<bool> initialize({String languageCode = 'hi'}) async {
    final status = await Permission.microphone.request();
    if (!status.isGranted) return false;

    _currentLocale = supportedLocales[languageCode] ?? 'hi_IN';

    if (!_isInitialized) {
      final available = await _speech.initialize(
        onStatus: (status) {
          if (status == 'done' || status == 'notListening') {
            final pending = _lastRecognizedText.trim();
            final callback = _activeOnResult;
            final statusCallback = _activeOnStatus;
            _isListening = false;

            // Some Android speech services finish without sending a
            // finalResult callback. Do not lose the live command.
            if (!_resultDelivered && pending.isNotEmpty && callback != null) {
              _resultDelivered = true;
              statusCallback?.call('done');
              callback(pending);
              _clearListeningCallbacks();
            }
          }
        },
        onError: (_) {
          _isListening = false;
          final pending = _lastRecognizedText.trim();
          final callback = _activeOnResult;
          final statusCallback = _activeOnStatus;
          if (!_resultDelivered && pending.isNotEmpty && callback != null) {
            _resultDelivered = true;
            statusCallback?.call('done');
            callback(pending);
          }
          _clearListeningCallbacks();
        },
      );
      if (!available) return false;
      _isInitialized = true;
    }

    await _configureTts();
    return true;
  }

  Future<void> _configureTts() async {
    await _tts.setLanguage(_currentLocale);
    await _selectIndianVoice();
    await _tts.awaitSpeakCompletion(true);
    await _tts.setSpeechRate(_currentLocale == 'hi_IN' ? 0.42 : 0.45);
    await _tts.setVolume(1.0);
    await _tts.setPitch(1.0);
  }

  Future<void> setLanguage(String languageCode) async {
    _currentLocale = supportedLocales[languageCode] ?? 'hi_IN';
    if (_isInitialized) await _configureTts();
  }

  /// Only choose an exact Indian locale. Never choose an English voice as a
  /// fallback for Hindi, which can make Hindi sound like an English accent.
  Future<void> _selectIndianVoice() async {
    try {
      final voices = await _tts.getVoices;
      if (voices is! List) return;

      final locale = _currentLocale.toLowerCase().replaceAll('-', '_');
      final candidates = voices.where((raw) {
        if (raw is! Map) return false;
        final vLocale = (raw['locale'] ?? '')
            .toString()
            .toLowerCase()
            .replaceAll('-', '_');
        return vLocale == locale;
      }).toList();

      if (candidates.isEmpty) return;

      candidates.sort((a, b) {
        final aName = (a['name'] ?? '').toString().toLowerCase();
        final bName = (b['name'] ?? '').toString().toLowerCase();

        int score(String n) {
          var x = 0;
          // Google Hindi voice IDs commonly use "hia" for a female voice.
          if (n.contains('hia')) x += 10;
          if (n.contains('female') || n.contains('fem')) x += 8;
          if (n.contains('india') || n.contains('indian')) x += 3;
          if (n.contains('network')) x += 2;
          if (n.contains('local')) x += 1;
          // Avoid obvious male voice IDs when a female option exists.
          if (n.contains('hid') || n.contains('male')) x -= 6;
          return x;
        }

        return score(bName).compareTo(score(aName));
      });

      final voice = candidates.first;
      final name = voice['name']?.toString();
      if (name != null && name.isNotEmpty) {
        await _tts.setVoice({
          'name': name,
          'locale': voice['locale']?.toString() ?? _currentLocale,
        });
      }
    } catch (_) {}
  }

  bool get isListening => _isListening;

  /// Start a proper listening session. The UI uses tap-to-toggle, not
  /// tap-and-hold, so Android has time to return the final recognition result.
  Future<void> startListening({
    required Function(String text) onResult,
    Function(String status)? onStatus,
  }) async {
    if (!_isInitialized) {
      final ok = await initialize(languageCode: 'hi');
      if (!ok) {
        onStatus?.call('error');
        return;
      }
    }
    if (_isListening) return;

    _lastRecognizedText = '';
    _resultDelivered = false;
    _activeOnResult = onResult;
    _activeOnStatus = onStatus;
    _isListening = true;
    onStatus?.call('listening');

    try {
      await _speech.listen(
        onResult: (result) {
          final words = result.recognizedWords.trim();
          if (words.isNotEmpty) {
            _lastRecognizedText = words;
            onStatus?.call('partial');
          }

          if (result.finalResult && words.isNotEmpty && !_resultDelivered) {
            _resultDelivered = true;
            _isListening = false;
            onStatus?.call('done');
            onResult(words);
            _clearListeningCallbacks();
          }
        },
        localeId: _currentLocale,
        listenFor: const Duration(seconds: 25),
        pauseFor: const Duration(seconds: 5),
        listenOptions: stt.SpeechListenOptions(
          // Dictation handles natural Hindi/Hinglish speech better than
          // confirmation mode and allows partial results.
          listenMode: stt.ListenMode.dictation,
          cancelOnError: false,
          partialResults: true,
        ),
      );
    } catch (_) {
      _isListening = false;
      onStatus?.call('error');
      _clearListeningCallbacks();
    }
  }

  Future<void> stopListening() async {
    if (!_isListening) return;

    // Android may return only a partial result when the user manually stops.
    // Deliver that latest text so the command is not silently lost.
    final pending = _lastRecognizedText.trim();
    final callback = _activeOnResult;
    final status = _activeOnStatus;

    await _speech.stop();
    _isListening = false;

    if (!_resultDelivered && pending.isNotEmpty && callback != null) {
      _resultDelivered = true;
      status?.call('done');
      callback(pending);
    }

    _clearListeningCallbacks();
  }

  void _clearListeningCallbacks() {
    _activeOnResult = null;
    _activeOnStatus = null;
    _lastRecognizedText = '';
  }

  Future<void> speak(String text) async {
    if (text.trim().isEmpty) return;
    await _tts.stop();
    await _configureTts();
    await _tts.speak(text);
  }

  Future<void> stopSpeaking() async {
    await _tts.stop();
  }


  /// True when the user is referring to the party from the previous turn.
  /// This is intentionally broad because Indian speech recognition often
  /// removes short postpositions such as "is mein" / "usko".
  bool isContextReference(String text) {
    final t = text.toLowerCase().trim();
    const refs = [
      'isme', 'is mein', 'is me', 'usme', 'us mein', 'us me',
      'isko', 'usko', 'usi', 'usse', 'iska', 'uska', 'iske', 'uske',
      'same party', 'same customer', 'same supplier', 'wahi', 'vohi',
      'वही', 'इसमें', 'इस में', 'इसको', 'उसमें', 'उस में', 'उसको',
      'उसी', 'उसका', 'उसके', 'उससे',
    ];
    return refs.any((r) => t.contains(r));
  }

  /// Common short follow-up confirmations/cancellations.
  bool isAffirmative(String text) {
    final t = text.toLowerCase().trim();
    return RegExp(
      r'^(haan|ha|han|yes|yep|ok|okay|theek|thik|sahi|kar do|karna hai|confirm|confirmed|जी|जी हाँ|हां|हाँ|हाँ कर दो|ठीक|सही|कर दो)$',
      caseSensitive: false,
    ).hasMatch(t);
  }

  bool isNegative(String text) {
    final t = text.toLowerCase().trim();
    return RegExp(
      r'^(nahi|nahin|no|cancel|cancel karo|mat karo|rehne do|रद्द|नहीं|मत करो|रहने दो)$',
      caseSensitive: false,
    ).hasMatch(t);
  }

  BhavyaIntent parseCommand(String text) {
    final normalized = _normalizeHindi(text);
    final lower = normalized.toLowerCase().trim();

    if (lower.isEmpty) {
      return BhavyaIntent(action: IntentAction.unknown, rawText: text);
    }

    // Small-talk is a real conversation, not a failed khata command.
    if (_containsAny(lower, [
      'hello', 'hi', 'hey', 'namaste', 'namaskar', 'good morning',
      'good afternoon', 'good evening', 'kaise ho', 'kya haal',
      'thank you', 'thanks', 'shukriya', 'धन्यवाद', 'नमस्ते', 'हैलो',
      'कैसी हो', 'कैसे हो'
    ])) {
      return BhavyaIntent(action: IntentAction.conversation, rawText: text);
    }

    // Strong, explicit intents are checked first. This prevents words such as
    // "lena" or "diya" from accidentally flipping a transaction's direction.
    if (_containsAny(lower, [
      'help', 'madad', 'kya kar sakte', 'commands', 'कमांड', 'मदद'
    ])) {
      return BhavyaIntent(action: IntentAction.help, rawText: text);
    }

    // Advanced business actions are detected before generic credit/debit words.
    if (_containsAny(lower, ['whatsapp', 'whats app', 'wa reminder', 'whatsapp par', 'whatsapp pe',
      'message whatsapp', 'व्हाट्सऐप', 'व्हाट्सएप'])) {
      final supplier = _containsAny(lower, ['supplier', 'सप्लायर', 'material', 'मटेरियल', 'order', 'ऑर्डर']);
      return BhavyaIntent(
        action: supplier ? IntentAction.supplierWhatsAppReminder : IntentAction.whatsappReminder,
        customerName: _extractName(lower),
        partyKind: supplier ? PartyKind.supplier : PartyKind.customer,
        rawText: text,
        material: supplier ? _extractMaterial(lower) : null,
      );
    }

    if (_containsAny(lower, ['sms', 'text bhejo', 'text send', 'message bhejo', 'message send',
      'msg bhejo', 'msg send', 'एसएमएस', 'मैसेज भेजो'])) {
      final supplier = _containsAny(lower, ['supplier', 'सप्लायर', 'material', 'मटेरियल', 'order', 'ऑर्डर']);
      return BhavyaIntent(
        action: supplier ? IntentAction.supplierSmsReminder : IntentAction.smsReminder,
        customerName: _extractName(lower),
        partyKind: supplier ? PartyKind.supplier : PartyKind.customer,
        rawText: text,
        material: supplier ? _extractMaterial(lower) : null,
      );
    }

    if (_containsAny(lower, ['upi', 'up i', 'upi se', 'payment link', 'payment mangao',
      'payment maang', 'paise mangao', 'paise maang', 'collect payment',
      'collect karo', 'यूपीआई', 'पेमेंट मंगाओ', 'पैसे मांगो'])) {
      return BhavyaIntent(
        action: IntentAction.collectUpi,
        amount: _extractAmount(lower),
        customerName: _extractName(lower),
        partyKind: PartyKind.customer,
        rawText: text,
      );
    }

    if (_containsAny(lower, ['invoice', 'bill banao', 'bill bana', 'bill nikal', 'bill bhejo',
      'invoice nikal', 'इनवॉइस', 'बिल बनाओ', 'बिल निकालो'])) {
      final gst = _containsAny(lower, ['gst', 'जीएसटी']);
      return BhavyaIntent(
        action: gst ? IntentAction.gstInvoice : IntentAction.invoice,
        amount: _extractAmount(lower),
        customerName: _extractName(lower),
        partyKind: PartyKind.customer,
        rawText: text,
      );
    }

    if (_containsAny(lower, ['statement', 'statment', 'hisab share', 'hisab bhejo', 'print statement', 'statement print', 'स्टेटमेंट', 'हिसाब भेजो'])) {
      return BhavyaIntent(
        action: _containsAny(lower, ['print', 'प्रिंट']) ? IntentAction.printStatement : IntentAction.shareStatement,
        customerName: _extractName(lower),
        partyKind: PartyKind.customer,
        rawText: text,
      );
    }

    if (_containsAny(lower, ['history', 'transactions', 'transaction history', 'len den', 'len-den',
      'len den dikhao', 'khata dikhao', 'khata dekhna hai', 'account dikhao',
      'hisab dikhao', 'लेनदेन', 'ट्रांजैक्शन', 'इतिहास', 'खाता दिखाओ'])) {
      return BhavyaIntent(
        action: IntentAction.showHistory,
        customerName: _extractName(lower),
        partyKind: _extractPartyKind(lower),
        rawText: text,
      );
    }

    if (_containsAny(lower, ['naya supplier', 'new supplier', 'supplier add', 'supplier banao', 'add supplier', 'नया सप्लायर', 'सप्लायर जोड़'])) {
      return BhavyaIntent(
        action: IntentAction.addSupplier,
        customerName: _extractName(lower),
        partyKind: PartyKind.supplier,
        rawText: text,
      );
    }

    if (_containsAny(lower, ['kitne customer', 'customer kitne', 'customers kitne', 'customer count', 'कितने ग्राहक', 'कितने कस्टमर'])) {
      return BhavyaIntent(action: IntentAction.partyCount, partyKind: PartyKind.customer, rawText: text);
    }

    if (_containsAny(lower, ['kitne supplier', 'supplier kitne', 'suppliers kitne', 'supplier count', 'कितने सप्लायर'])) {
      return BhavyaIntent(action: IntentAction.partyCount, partyKind: PartyKind.supplier, rawText: text);
    }

    if (_containsAny(lower, [
      'dhundho', 'dhoondo', 'dhundna', 'find', 'search', 'naam ko dhundo', 'naam ko dhoondo',
      'ढूंढो', 'ढूंढना', 'खोजो', 'सर्च',
    ])) {
      return BhavyaIntent(
        action: IntentAction.findParty,
        customerName: _extractName(lower),
        partyKind: _extractPartyKind(lower),
        rawText: text,
      );
    }

    if (_containsAny(lower, [
      'balance', 'baaki', 'baki', 'kitna', 'kitni', 'pending',
      'udhaar kitna', 'kitna dena hai', 'kitna lena hai', 'kitna baki hai',
      'kitna baaki', 'batao balance', 'check balance', 'account balance',
      'khate ka balance', 'hisab batao',
      'बैलेंस', 'बाकी', 'कितना', 'कितनी', 'पेंडिंग'
    ])) {
      return BhavyaIntent(
        action: IntentAction.checkBalance,
        customerName: _extractName(lower),
        partyKind: _extractPartyKind(lower),
        rawText: text,
      );
    }

    if (_containsAny(lower, [
      'report', 'hisab', 'hisaab', 'aaj ka', 'aaj ka hisab', 'mahine ka',
      'profit', 'nuksan', 'dashboard', 'summary', 'total batao',
      'overall batao', 'poora hisab', 'aaj ka total', 'रिपोर्ट', 'हिसाब',
      'आज का', 'महीने का', 'मुनाफा', 'नुकसान', 'डैशबोर्ड'
    ])) {
      return BhavyaIntent(action: IntentAction.showReport, rawText: text);
    }

    if (_containsAny(lower, [
      'naya customer', 'new customer', 'customer add', 'customer banao',
      'add customer', 'नया ग्राहक', 'नया कस्टमर', 'कस्टमर जोड़',
      'ग्राहक जोड़'
    ])) {
      return BhavyaIntent(
        action: IntentAction.addCustomer,
        customerName: _extractName(lower),
        partyKind: _extractPartyKind(lower),
        rawText: text,
      );
    }

    // Payment/settlement language means money has been received/paid.
    // In this app that is a debit entry for a customer and a debit/payment
    // entry for a supplier.
    if (_containsAny(lower, [
      'jama kar', 'jama kardo', 'payment kar', 'payment de', 'paid',
      'pay kiya', 'pay kar diya', 'payment kar diya', 'paise diye',
      'paise diya', 'paise le liye', 'paise le liya', 'paise liye', 'paise liya',
      'mil gaye', 'mil gaya', 'receive', 'received', 'vasool',
      'जमा कर', 'पेमेंट', 'पैसे दिए', 'पैसे लिया', 'मिल गए'
    ])) {
      return BhavyaIntent(
        action: IntentAction.addDebit,
        amount: _extractAmount(lower),
        customerName: _extractName(lower),
        partyKind: _extractPartyKind(lower),
        rawText: text,
      );
    }

    if (_containsAny(lower, [
      'credit', 'kredit', 'udhaar', 'udhar', 'udhaar de', 'udhaar diya',
      'credit kar', 'add credit', 'credit daal', 'credit chadha',
      'udhaar de', 'udhaar diya', 'udhaar daal', 'baaki mein daal',
      'उधार', 'क्रेडिट', 'उधार दिया', 'उधार डालो'
    ])) {
      return BhavyaIntent(
        action: IntentAction.addCredit,
        amount: _extractAmount(lower),
        customerName: _extractName(lower),
        partyKind: _extractPartyKind(lower),
        rawText: text,
      );
    }

    if (_containsAny(lower, [
      'debit', 'jama', 'dena', 'payment', 'paid', 'debit kar', 'add debit',
      'डेबिट', 'जमा', 'देना', 'पेमेंट', 'पेड'
    ])) {
      return BhavyaIntent(
        action: IntentAction.addDebit,
        amount: _extractAmount(lower),
        customerName: _extractName(lower),
        partyKind: _extractPartyKind(lower),
        rawText: text,
      );
    }

    return BhavyaIntent(action: IntentAction.unknown, rawText: text);
  }

  bool _containsAny(String text, List<String> keywords) {
    return keywords.any((k) => text.contains(k));
  }

  String _normalizeHindi(String input) {
    var text = input
        .replaceAll('।', ' ')
        .replaceAll(',', ' ')
        .replaceAll('?', ' ')
        .replaceAll('!', ' ')
        .replaceAll('₹', ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();

    const replacements = {
      'करदो': 'कर दो',
      'करदे': 'कर दे',
      'करना है': 'karna hai',
      'कस्टमर': 'customer',
      'ग्राहक': 'customer',
      'बैलेंस': 'balance',
      'क्रेडिट': 'credit',
      'डेबिट': 'debit',
      'रिपोर्ट': 'report',
      'हिसाब': 'hisab',
      'मदद': 'help',
      'कितना है': 'kitna hai',
    };
    replacements.forEach((a, b) => text = text.replaceAll(a, b));

    // Natural spoken-language cleanup: people speak in sentences, not
    // rigid command syntax. Remove harmless fillers and map common phrases.
    const spoken = {
      'bhai': ' ', 'bhaiya': ' ', 'bhaisaab': ' ', 'madam': ' ',
      'ji': ' ', 'zara': ' ', 'jara': ' ', 'please': ' ', 'pls': ' ',
      'na': ' ', 'toh': ' ', 'theek hai': 'theek ', 'haanji': 'haan ',
      'batao na': 'batao ', 'bata dena': 'batao ',
      'dikha dena': 'dikhao ', 'kar dena': 'kar do ',
      'bhej dena': 'bhejo ', 'jod dena': 'jodo ',
      'chadha de': 'credit kar do ', 'chadha do': 'credit kar do ',
      'udhaar chadha': 'credit ', 'khate mein': ' ', 'khate me': ' ',
      'account mein': ' ', 'account me': ' ',
    };
    spoken.forEach((a, b) => text = text.replaceAll(a, b));
    text = text.replaceAll(RegExp(r'\s+'), ' ').trim();
    return text;
  }

  double? _extractAmount(String text) {
    final digitText = _convertDevanagariDigits(text).toLowerCase();

    // Prefer a numeric amount followed by an Indian unit:
    // "50 hazaar", "1.5 lakh", "2 crore".
    final unitMatch = RegExp(
      r'(\d+(?:\.\d+)?)\s*(crore|करोड़|करोड़|lakh|lac|लाख|thousand|k|hazaar|hazar|हजार|हज़ार)',
      caseSensitive: false,
    ).firstMatch(digitText);
    if (unitMatch != null) {
      final value = double.tryParse(unitMatch.group(1)!);
      final unit = unitMatch.group(2)!.toLowerCase();
      if (value != null) {
        if (unit == 'crore' || unit == 'करोड़' || unit == 'करोड़') return value * 10000000;
        if (unit == 'lakh' || unit == 'lac' || unit == 'लाख') return value * 100000;
        if (unit == 'thousand' || unit == 'k' || unit == 'hazaar' ||
            unit == 'hazar' || unit == 'हजार' || unit == 'हज़ार') {
          return value * 1000;
        }
      }
    }

    final match = RegExp(r'(\d+(?:\.\d+)?)').firstMatch(digitText);
    if (match != null) return double.tryParse(match.group(1)!);
    return _parseHindiNumber(text);
  }

  String _convertDevanagariDigits(String text) {
    const from = '०१२३४५६७८९';
    const to = '0123456789';
    final b = StringBuffer();
    for (final ch in text.runes) {
      final s = String.fromCharCode(ch);
      final i = from.indexOf(s);
      b.write(i >= 0 ? to[i] : s);
    }
    return b.toString();
  }

  double? _parseHindiNumber(String text) {
    const units = {
      'zero': 0, 'shunya': 0, 'शून्य': 0,
      'ek': 1, 'एक': 1, 'do': 2, 'दो': 2, 'teen': 3, 'तीन': 3,
      'char': 4, 'चार': 4, 'paanch': 5, 'panch': 5, 'पांच': 5, 'पाँच': 5,
      'cheh': 6, 'छह': 6, 'chhe': 6, 'छः': 6, 'saat': 7, 'सात': 7,
      'aath': 8, 'आठ': 8, 'nau': 9, 'नौ': 9, 'das': 10, 'दस': 10,
      'gyarah': 11, 'ग्यारह': 11, 'barah': 12, 'बारह': 12,
      'terah': 13, 'तेरह': 13, 'chaudah': 14, 'चौदह': 14,
      'pandrah': 15, 'पंद्रह': 15, 'solah': 16, 'सोलह': 16,
      'satrah': 17, 'सत्रह': 17, 'atharah': 18, 'अठारह': 18,
      'unnis': 19, 'उन्नीस': 19, 'bees': 20, 'बीस': 20,
      'tees': 30, 'तीस': 30, 'chaalis': 40, 'चालीस': 40,
      'pachaas': 50, 'पचास': 50, 'saath': 60, 'साठ': 60,
      'sattar': 70, 'सत्तर': 70, 'assi': 80, 'अस्सी': 80,
      'nabbe': 90, 'नब्बे': 90,
    };

    final tokens = text.toLowerCase().split(RegExp(r'\s+'));
    double total = 0;
    double current = 0;
    bool found = false;

    for (final t in tokens) {
      if (units.containsKey(t)) {
        current += units[t]!;
        found = true;
      } else if (t == 'hundred' || t == 'सौ') {
        current = (current == 0 ? 1 : current) * 100;
      } else if (t == 'thousand' || t == 'hazaar' || t == 'hazar' ||
          t == 'हजार' || t == 'हज़ार') {
        total += (current == 0 ? 1 : current) * 1000;
        current = 0;
        found = true;
      } else if (t == 'lakh' || t == 'lac' || t == 'लाख') {
        total += (current == 0 ? 1 : current) * 100000;
        current = 0;
        found = true;
      } else if (t == 'crore' || t == 'करोड़' || t == 'करोड़') {
        total += (current == 0 ? 1 : current) * 10000000;
        current = 0;
        found = true;
      }
    }
    return found ? total + current : null;
  }

  PartyKind _extractPartyKind(String text) {
    final t = text.toLowerCase();
    if (RegExp(r'\b(customer|कस्टमर|ग्राहक)\b').hasMatch(t)) {
      return PartyKind.customer;
    }
    if (RegExp(r'\b(supplier|सप्लायर)\b').hasMatch(t)) {
      return PartyKind.supplier;
    }
    return PartyKind.any;
  }

  String? _extractName(String text) {
    var cleaned = text.trim();
    if (cleaned.isEmpty) return null;

    // Name normally appears before Hindi/Hinglish postpositions:
    // "Leena Shastri ko 5000 credit kar do" / "लीना शास्त्री का बैलेंस".
    final beforePostposition = RegExp(
      r'^(.+?)\s+(?:ko|ka|ki|ke|se|mein|me|में|मे|को|का|की|के|से)\s+',
      caseSensitive: false,
    ).firstMatch(cleaned);
    if (beforePostposition != null) {
      final name = _cleanName(beforePostposition.group(1) ?? '');
      if (name.isNotEmpty) return name;
    }

    // English command form: "credit 5000 to Ramesh" / "balance for Ramesh".
    final afterPreposition = RegExp(
      r'(?:\bto\b|\bfor\b)\s+([^\d]+?)(?=\s+(?:\d|credit|debit|balance|payment|please|kar|do|batao)\b|$)',
      caseSensitive: false,
    ).firstMatch(cleaned);
    if (afterPreposition != null) {
      final name = _cleanName(afterPreposition.group(1) ?? '');
      if (name.isNotEmpty) return name;
    }

    final customerName = RegExp(
      r'(?:customer|supplier|ग्राहक|कस्टमर|सप्लायर)\s+([^\d]+?)(?=\s+(?:ko|ka|ki|ke|balance|credit|debit|payment|reminder|invoice|statement|upi|whatsapp|sms|banao|bana|jodo|jod|add|करो|करना|बनाओ|बना|जोड़ो|जोड़|रिमाइंडर|इनवॉइस|स्टेटमेंट|बैलेंस|क्रेडिट|डेबिट|पेमेंट)\b|$)',
      caseSensitive: false,
    ).firstMatch(cleaned);
    if (customerName != null) {
      final name = _cleanName(customerName.group(1) ?? '');
      if (name.isNotEmpty) return name;
    }

    // Last-resort extraction for "balance Ramesh" and "credit Ramesh 5000".
    final fallback = RegExp(
      r'^(?:balance|credit|debit|payment|report)\s+([^\d]+?)(?=\s+\d|$)',
      caseSensitive: false,
    ).firstMatch(cleaned);
    if (fallback != null) {
      final name = _cleanName(fallback.group(1) ?? '');
      if (name.isNotEmpty) return name;
    }

    return null;
  }

  String? _extractMaterial(String text) {
    final m = RegExp(r'(?:material|item|order|मटेरियल|सामान|ऑर्डर)\s+(.+?)(?=\s+(?:reminder|bhejo|send|kar|do|करो|भेजो|भेजना)\b|$)', caseSensitive: false).firstMatch(text);
    if (m == null) return null;
    final value = m.group(1)?.trim();
    return value == null || value.isEmpty ? null : value;
  }

  String _cleanName(String name) {
    return name
        // STT/user may explicitly say 'customer Ritesh' or 'supplier Ritesh'.
        // The role is metadata, never part of the stored party name.
        .replaceFirst(RegExp(r'^(?:customer|supplier|ग्राहक|कस्टमर|सप्लायर)\s+', caseSensitive: false), '')
        .replaceFirst(RegExp(r'\s+(?:customer|supplier|ग्राहक|कस्टमर|सप्लायर)\s*$', caseSensitive: false), '')
        .replaceAll(RegExp(
          r'\b(credit|debit|balance|batao|bataiye|batana|kar|karo|do|de|add|show|report|hisab|please|bhai|bhaiya|ji|zara|reminder|invoice|statement|upi|whatsapp|sms|payment|material|order|banao|bana|jodo|jod|lene|le|dena|dene|dekar|karna|karke|rakhna|rakho|send|bhejo|mangao|dhundho|dhoondo|find|search|new|naya|नया|कर|करो|करना|करके|रखना|रखो|लेना|लेने|ले|देना|देने|दो|दे|बताओ|दिखाओ|जोड़ो|जोड़|भेजो|भेज|बनाओ|बना|ढूंढो|खोजो|रिमाइंडर|इनवॉइस|स्टेटमेंट|पेमेंट|मटेरियल|सामान|ऑर्डर|क्रेडिट|डेबिट|बैलेंस|रिपोर्ट|हिसाब)\b',
          caseSensitive: false,
        ), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  /// Converts common Devanagari Hindi to a stable Latin phonetic key.
  /// Example: "रमेश" -> "ramesh", matching a customer "Ramesh".
  String phoneticKey(String input) {
    final s = input.trim().toLowerCase();
    if (s.isEmpty) return '';

    const independent = {
      'अ':'a','आ':'aa','इ':'i','ई':'ee','उ':'u','ऊ':'oo','ए':'e','ऐ':'ai',
      'ओ':'o','औ':'au','ऋ':'ri',
    };
    const consonants = {
      'क':'k','ख':'kh','ग':'g','घ':'gh','ङ':'ng',
      'च':'ch','छ':'chh','ज':'j','झ':'jh','ञ':'ny',
      'ट':'t','ठ':'th','ड':'d','ढ':'dh','ण':'n',
      'त':'t','थ':'th','द':'d','ध':'dh','न':'n',
      'प':'p','फ':'ph','ब':'b','भ':'bh','म':'m',
      'य':'y','र':'r','ल':'l','व':'v','श':'sh','ष':'sh','स':'s','ह':'h',
      'क़':'q','ख़':'kh','ग़':'g','ज़':'z','फ़':'f',
    };
    const matras = {
      'ा':'aa','ि':'i','ी':'ee','ु':'u','ू':'oo','ृ':'ri','े':'e',
      'ै':'ai','ो':'o','ौ':'au',
    };

    final out = StringBuffer();
    final chars = s.runes.map(String.fromCharCode).toList();

    for (var i = 0; i < chars.length; i++) {
      final c = chars[i];
      if (independent.containsKey(c)) {
        out.write(independent[c]);
        continue;
      }
      if (consonants.containsKey(c)) {
        out.write(consonants[c]);
        if (i + 1 < chars.length) {
          final next = chars[i + 1];
          if (matras.containsKey(next)) {
            out.write(matras[next]);
            i++;
          } else if (next == '्') {
            i++;
          } else {
            out.write('a');
          }
        } else {
          out.write('a');
        }
        continue;
      }
      if (c == 'ं' || c == 'ँ') {
        out.write('n');
        continue;
      }
      if (c == 'ः') {
        out.write('h');
        continue;
      }
      if (c == '़') continue;
      if (RegExp(r'[a-z0-9]').hasMatch(c)) out.write(c);
    }

    return out.toString()
        .replaceAll(RegExp(r'[aeiou]+$'), '')
        .replaceAll(RegExp(r'[^a-z0-9]'), '');
  }

  /// Returns a small pronunciation distance. 0 means an exact phonetic
  /// match; lower values are better. Used by the live party matcher.
  int phoneticDistance(String a, String b) {
    final left = _phoneticComparisonKey(a);
    final right = _phoneticComparisonKey(b);
    if (left.isEmpty || right.isEmpty) return 999;
    return _levenshtein(left, right);
  }

  String _phoneticComparisonKey(String input) {
    var s = phoneticKey(input).toLowerCase();
    const replacements = <String, String>{
      'kh': 'k', 'gh': 'g', 'chh': 'c', 'ch': 'c', 'jh': 'j',
      'th': 't', 'dh': 'd', 'ph': 'p', 'bh': 'b', 'sh': 's',
      'aa': 'a', 'ee': 'i', 'oo': 'u', 'ai': 'e', 'au': 'o', 'ri': 'r',
      'v': 'w',
    };
    for (final e in replacements.entries) {
      s = s.replaceAll(e.key, e.value);
    }
    s = s.replaceAll(RegExp(r'([a-z])\1+'), r'$1');
    s = s.replaceAll(RegExp(r'[aeiou]+'), 'a');
    return s;
  }

  int _levenshtein(String a, String b) {
    if (a == b) return 0;
    if (a.isEmpty) return b.length;
    if (b.isEmpty) return a.length;
    var previous = List<int>.generate(b.length + 1, (i) => i);
    for (var i = 0; i < a.length; i++) {
      final current = List<int>.filled(b.length + 1, 0);
      current[0] = i + 1;
      for (var j = 0; j < b.length; j++) {
        final cost = a.codeUnitAt(i) == b.codeUnitAt(j) ? 0 : 1;
        final insert = current[j] + 1;
        final delete = previous[j + 1] + 1;
        final replace = previous[j] + cost;
        current[j + 1] = [insert, delete, replace].reduce((x, y) => x < y ? x : y);
      }
      previous = current;
    }
    return previous[b.length];
  }

  String getHelpText(String languageCode) {
    if (languageCode == 'hi' || languageCode.startsWith('hi')) {
      return '''
Namaste! Main Bhavya hoon, SHIV SHAKTI se powered.
Aap seedha Hindi mein bol sakte ho:

• "रमेश को 5000 क्रेडिट कर दो"
• "सुरेश का बैलेंस बताओ"
• "आज का हिसाब बताओ"
• "राहुल को 2000 जमा कर दो"
• "नया ग्राहक राहुल जोड़ो"

Hinglish bhi chalegi:
• "Ramesh ko 5000 credit kar do"
• "Suresh ka balance batao"
''';
    }
    return '''
Hello! I am Bhavya, powered by SHIV SHAKTI.
You can say:
• "Add 5000 credit to Ramesh"
• "What is Suresh balance"
• "Show today's report"
• "Add new customer Rahul"
• "What is Leena balance"
''';
  }
}

enum PartyKind { any, customer, supplier }

enum IntentAction {
  addCredit,
  addDebit,
  checkBalance,
  showReport,
  addCustomer,
  addSupplier,
  findParty,
  showHistory,
  whatsappReminder,
  smsReminder,
  supplierWhatsAppReminder,
  supplierSmsReminder,
  collectUpi,
  invoice,
  gstInvoice,
  shareStatement,
  printStatement,
  partyCount,
  help,
  conversation,
  unknown,
}

class BhavyaIntent {
  final IntentAction action;
  final double? amount;
  final String? customerName;
  final PartyKind partyKind;
  final String? material;
  final String rawText;

  BhavyaIntent({
    required this.action,
    this.amount,
    this.customerName,
    this.partyKind = PartyKind.any,
    this.material,
    required this.rawText,
  });
}
