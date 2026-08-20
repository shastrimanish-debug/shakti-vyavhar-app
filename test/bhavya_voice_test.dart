
import 'package:flutter_test/flutter_test.dart';
import 'package:shakti_vyavhar/services/bhavya_ai_service.dart';

void main() {
  final bhavya = BhavyaAIService();

  test('Hindi phonetic names produce stable keys', () {
    expect(bhavya.phoneticKey('रमेश'), isNotEmpty);
    expect(bhavya.phoneticKey('Ramesh'), isNotEmpty);
  });

  test('Hindi credit command parses correctly', () {
    final intent = bhavya.parseCommand('रमेश को 5000 क्रेडिट कर दो');
    expect(intent.action, IntentAction.addCredit);
    expect(intent.customerName, isNotNull);
    expect(intent.amount, 5000);
  });

  test('Hindi balance command parses correctly', () {
    final intent = bhavya.parseCommand('सुरेश का बैलेंस बताओ');
    expect(intent.action, IntentAction.checkBalance);
    expect(intent.customerName, isNotNull);
  });

  test('supplier Hindi name is accepted by phonetic layer', () {
    expect(bhavya.phoneticKey('लीना शास्त्री'), isNotEmpty);
    expect(bhavya.phoneticKey('Leena Shastri'), isNotEmpty);
    expect(bhavya.phoneticDistance('लीना शास्त्री', 'Leena Shastri'), lessThanOrEqualTo(1));
  });

  test('multi-word Hindi customer name is extracted', () {
    final intent = bhavya.parseCommand('लीना शास्त्री को 5000 क्रेडिट कर दो');
    expect(intent.action, IntentAction.addCredit);
    expect(intent.customerName, 'लीना शास्त्री');
    expect(intent.amount, 5000);
  });

  test('Indian STT Ridhesh variant remains close to Ritesh', () {
    expect(bhavya.phoneticDistance('Ridhesh', 'Ritesh'), lessThanOrEqualTo(3));
  });

  test('customer prefix is not included in Hindi party name', () {
    final intent = bhavya.parseCommand('कस्टमर कर्तव्य शास्त्री के 50000 डेबिट करो');
    expect(intent.action, IntentAction.addDebit);
    expect(intent.customerName, 'कर्तव्य शास्त्री');
    expect(intent.partyKind, PartyKind.customer);
    expect(intent.amount, 50000);
  });

  test('find customer command is parsed', () {
    final intent = bhavya.parseCommand('कस्टमर कर्तव्य शास्त्री के नाम को ढूंढो');
    expect(intent.action, IntentAction.findParty);
    expect(intent.customerName, 'कर्तव्य शास्त्री');
    expect(intent.partyKind, PartyKind.customer);
  });

  test('advanced customer actions parse', () {
    expect(bhavya.parseCommand('Ramesh ko WhatsApp reminder bhejo').action, IntentAction.whatsappReminder);
    expect(bhavya.parseCommand('Ramesh ko SMS bhejo').action, IntentAction.smsReminder);
    expect(bhavya.parseCommand('Ramesh se 5000 UPI payment mangao').action, IntentAction.collectUpi);
    expect(bhavya.parseCommand('Ramesh ka invoice banao').action, IntentAction.invoice);
    expect(bhavya.parseCommand('Ramesh ka statement share karo').action, IntentAction.shareStatement);
    expect(bhavya.parseCommand('Ramesh ka transaction history dikhao').action, IntentAction.showHistory);
  });

  test('supplier actions stay supplier-only', () {
    final wa = bhavya.parseCommand('supplier Mohan ko material steel ka WhatsApp reminder bhejo');
    expect(wa.action, IntentAction.supplierWhatsAppReminder);
    expect(wa.partyKind, PartyKind.supplier);
    expect(wa.customerName, 'Mohan');
  });

  test('new supplier command extracts clean name', () {
    final intent = bhavya.parseCommand('naya supplier Mohan jodo');
    expect(intent.action, IntentAction.addSupplier);
    expect(intent.customerName, 'Mohan');
    expect(intent.partyKind, PartyKind.supplier);
  });

  test('payment received is parsed as debit', () {
    final intent = bhavya.parseCommand('Ramesh se 5000 payment liya');
    expect(intent.action, IntentAction.addDebit);
    expect(intent.amount, 5000);
  });
}



  test('follow-up context references are detected', () {
    expect(bhavya.isContextReference('isme 50000 credit karo'), isTrue);
    expect(bhavya.isContextReference('uska balance batao'), isTrue);
    expect(bhavya.isContextReference('normal new command'), isFalse);
  });

  test('numeric Indian amount units are parsed', () {
    expect(bhavya.parseCommand('Ramesh ko 50 hazaar credit kar do').amount, 50000);
    expect(bhavya.parseCommand('Ramesh ko 1 lakh credit kar do').amount, 100000);
    expect(bhavya.parseCommand('Ramesh ko 2 crore credit kar do').amount, 20000000);
  });

  test('multi-word name with mein is extracted', () {
    final intent = bhavya.parseCommand('जोड़ो किशन ओपनिंग में 50000 क्रेडिट करो');
    expect(intent.action, IntentAction.addCredit);
    expect(intent.customerName, 'किशन ओपनिंग');
    expect(intent.amount, 50000);
  
  test('natural Hindi/Hinglish paraphrases are understood', () {
    expect(bhavya.parseCommand('Ramesh bhai ke khate mein 5000 daal do').action,
        IntentAction.addCredit);
    expect(bhavya.parseCommand('Ramesh ka account dikhao').action,
        IntentAction.showHistory);
    expect(bhavya.parseCommand('Ramesh se paise le liye 2500').action,
        IntentAction.addDebit);
    expect(bhavya.parseCommand('Ramesh ka kitna baaki hai').action,
        IntentAction.checkBalance);
  });

  test('small talk is recognized', () {
    expect(bhavya.parseCommand('Hello Bhavya').action, IntentAction.conversation);
    expect(bhavya.parseCommand('Bhavya kaisi ho').action, IntentAction.conversation);
    expect(bhavya.parseCommand('Thank you').action, IntentAction.conversation);
  });
});
