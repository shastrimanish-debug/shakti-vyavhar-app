import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/customer.dart';
import '../models/transaction.dart';
import 'database_service.dart';

class BusinessToolsService {
  final DatabaseService db;
  BusinessToolsService(this.db);

  Future<void> sendWhatsAppReminder(Customer customer, double balance) async {
    _requireCustomer(customer, 'WhatsApp payment reminder');
    final phone = _digits(customer.phone);
    if (phone.isEmpty) throw Exception('Customer mobile number missing');
    final text = balance >= 0
        ? 'Namaste ${customer.name}, aapka ₹${balance.abs().toStringAsFixed(0)} payment pending hai. Kripya payment kar dein.\n\nSHAKTI VYAVHAR'
        : 'Namaste ${customer.name}, aapko ₹${balance.abs().toStringAsFixed(0)} dena baki hai. Kripya details ke liye sampark karein.\n\nSHAKTI VYAVHAR';
    final uri = Uri.parse('https://wa.me/${_whatsAppPhone(phone)}?text=${Uri.encodeComponent(text)}');
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      throw Exception('WhatsApp open nahi hua');
    }
  }

  Future<void> sendSmsReminder(Customer customer, double balance) async {
    _requireCustomer(customer, 'SMS payment reminder');
    final phone = _digits(customer.phone);
    if (phone.isEmpty) throw Exception('Customer mobile number missing');
    final text = balance >= 0
        ? 'Namaste ${customer.name}, ₹${balance.abs().toStringAsFixed(0)} payment pending hai. - SHAKTI VYAVHAR'
        : 'Namaste ${customer.name}, ₹${balance.abs().toStringAsFixed(0)} dena baki hai. - SHAKTI VYAVHAR';
    final uri = Uri(scheme: 'sms', path: phone, queryParameters: {'body': text});
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      throw Exception('SMS app open nahi hua');
    }
  }

  Future<void> collectUpi(Customer customer, double amount, {String? upiId}) async {
    _requireCustomer(customer, 'UPI collection');
    if (amount <= 0) throw Exception('Amount invalid');
    final configuredUpi = upiId?.trim().isNotEmpty == true
        ? upiId!.trim()
        : (await db.getBusiness(customer.businessId))?.upiId?.trim();
    if (configuredUpi == null || configuredUpi.isEmpty) {
      throw Exception('Business UPI ID Settings me add karein');
    }
    final uri = Uri.parse(
      'upi://pay?pa=${Uri.encodeComponent(configuredUpi)}&pn=${Uri.encodeComponent('Shakti Vyavhar')}&am=${amount.toStringAsFixed(2)}&cu=INR&tn=${Uri.encodeComponent('Payment for ${customer.name}')}',
    );
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      throw Exception('UPI app open nahi hua');
    }
  }

  Future<void> shareInvoice(Customer customer, List<Transaction> txns) async {
    _requireCustomer(customer, 'Customer invoice');
    final bytes = await _invoicePdf(customer, txns);
    await Printing.sharePdf(bytes: bytes, filename: 'invoice_${customer.name}.pdf');
  }

  Future<void> shareGstInvoice(Customer customer, double taxable, double gstRate) async {
    _requireCustomer(customer, 'GST invoice');
    if (taxable <= 0) throw Exception('Taxable amount invalid');
    if (gstRate < 0 || gstRate > 100) throw Exception('GST rate 0-100 ke beech hona chahiye');
    final bytes = await _gstInvoicePdf(customer, taxable, gstRate);
    await Printing.sharePdf(bytes: bytes, filename: 'gst_invoice_${customer.name}.pdf');
  }

  Future<Uint8List> _gstInvoicePdf(Customer customer, double taxable, double gstRate) async {
    _requireCustomer(customer, 'GST invoice');
    final business = await db.getBusiness(customer.businessId);
    final doc = pw.Document();
    final gst = taxable * gstRate / 100;
    final total = taxable + gst;
    doc.addPage(pw.Page(
      pageFormat: PdfPageFormat.a4,
      build: (_) => pw.Padding(
        padding: const pw.EdgeInsets.all(28),
        child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
          pw.Text('TAX INVOICE', style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 4),
          pw.Text(business?.name ?? 'SHAKTI VYAVHAR', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
          pw.Text('Powered by SHIV SHAKTI'),
          pw.Divider(),
          pw.Text('BILL TO (CUSTOMER): ${customer.name}', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
          if (customer.phone != null) pw.Text('Mobile: ${customer.phone}'),
          pw.SizedBox(height: 24),
          pw.Table.fromTextArray(headers: const ['Particular', 'Amount'], data: [
            ['Taxable Value', 'Rs. ${taxable.toStringAsFixed(2)}'],
            ['GST (${gstRate.toStringAsFixed(2)}%)', 'Rs. ${gst.toStringAsFixed(2)}'],
            ['Grand Total', 'Rs. ${total.toStringAsFixed(2)}'],
          ]),
          pw.SizedBox(height: 24),
          pw.Text('GSTIN: ${business?.gstin?.isNotEmpty == true ? business!.gstin : 'Not set in Business Profile'}'),
        ]),
      ),
    ));
    return doc.save();
  }

  Future<void> printInvoice(Customer customer, List<Transaction> txns) async {
    _requireCustomer(customer, 'Customer statement print');
    final bytes = await _invoicePdf(customer, txns);
    await Printing.layoutPdf(onLayout: (_) async => bytes);
  }

  Future<Uint8List> _invoicePdf(Customer customer, List<Transaction> txns) async {
    _requireCustomer(customer, 'Customer statement');
    final business = await db.getBusiness(customer.businessId);
    final doc = pw.Document();
    final date = DateFormat('dd-MM-yyyy');
    final balance = await db.getCustomerBalance(customer.id);
    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        build: (_) => [
          pw.Text(business?.name ?? 'SHAKTI VYAVHAR', style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold)),
          if (business?.phone?.isNotEmpty == true) pw.Text('Business Mobile: ${business!.phone}'),
          if (business?.gstin?.isNotEmpty == true) pw.Text('GSTIN: ${business!.gstin}'),
          pw.SizedBox(height: 4),
          pw.Text('CUSTOMER ACCOUNT STATEMENT'),
          pw.Divider(),
          pw.Text('CUSTOMER: ${customer.name}', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
          if (customer.phone != null) pw.Text('Mobile: ${customer.phone}'),
          pw.SizedBox(height: 12),
          pw.Table.fromTextArray(
            headers: const ['Date', 'Type', 'Amount', 'Mode', 'Details'],
            data: txns.map((t) => [
              date.format(t.date),
              t.isCredit ? 'Credit' : 'Debit',
              'Rs. ${t.amount.toStringAsFixed(2)}',
              t.paymentMode.name.toUpperCase(),
              t.description ?? '',
            ]).toList(),
          ),
          pw.SizedBox(height: 16),
          pw.Align(
            alignment: pw.Alignment.centerRight,
            child: pw.Text(
              balance >= 0 ? 'Balance Receivable: Rs. ${balance.abs().toStringAsFixed(2)}' : 'Balance Payable: Rs. ${balance.abs().toStringAsFixed(2)}',
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 14),
            ),
          ),
          pw.SizedBox(height: 24),
          pw.Text('Generated by SHAKTI VYAVHAR • Powered by SHIV SHAKTI'),
        ],
      ),
    );
    return doc.save();
  }

  Future<String> exportBackup() async {
    final data = await db.exportBackup();
    final json = const JsonEncoder.withIndent('  ').convert(data);
    final dir = await getTemporaryDirectory();
    final path = '${dir.path}/shakti_vyavhar_backup.json';
    final file = File(path);
    await file.writeAsString(json, flush: true);
    await Share.shareXFiles([XFile(path)], subject: 'Shakti Vyavhar Backup');
    return json;
  }

  Future<bool> restoreBackup() async {
    final result = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['json'], withData: true);
    if (result == null || result.files.single.bytes == null) return false;
    final json = utf8.decode(result.files.single.bytes!);
    await db.restoreBackup(json);
    return true;
  }

  String _digits(String? value) => (value ?? '').replaceAll(RegExp(r'\D'), '');

  String _whatsAppPhone(String digits) {
    if (digits.startsWith('91') && digits.length == 12) return digits;
    if (digits.length == 10) return '91$digits';
    return digits;
  }

  Future<void> sendSupplierMaterialReminder(Customer supplier, {String? material}) async {
    if (!supplier.isSupplier) {
      throw Exception('Material reminder sirf Supplier ke liye hai');
    }
    final phone = _digits(supplier.phone);
    if (phone.isEmpty) throw Exception('Supplier mobile number missing');
    final item = (material ?? '').trim();
    final text = item.isEmpty
        ? 'Namaste ${supplier.name}, kripya pending material/order ki update bhej dein.\n\nSHAKTI VYAVHAR'
        : 'Namaste ${supplier.name}, kripya "$item" material/order ki update bhej dein.\n\nSHAKTI VYAVHAR';
    final uri = Uri.parse('https://wa.me/${_whatsAppPhone(phone)}?text=${Uri.encodeComponent(text)}');
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      throw Exception('WhatsApp open nahi hua');
    }
  }

  Future<void> sendSupplierMaterialSms(Customer supplier, {String? material}) async {
    if (!supplier.isSupplier) {
      throw Exception('Material reminder sirf Supplier ke liye hai');
    }
    final phone = _digits(supplier.phone);
    if (phone.isEmpty) throw Exception('Supplier mobile number missing');
    final item = (material ?? '').trim();
    final text = item.isEmpty
        ? 'Namaste ${supplier.name}, pending material/order ki update bhej dein. - SHAKTI VYAVHAR'
        : 'Namaste ${supplier.name}, "$item" material/order ki update bhej dein. - SHAKTI VYAVHAR';
    final uri = Uri(scheme: 'sms', path: phone, queryParameters: {'body': text});
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      throw Exception('SMS app open nahi hua');
    }
  }

  void _requireCustomer(Customer party, String action) {
    if (party.isSupplier) {
      throw Exception('$action sirf Customer ke liye available hai');
    }
  }


  Future<void> shareReport({required String businessName, required Map<String, double> stats, required List<Transaction> transactions}) async {
    final doc = pw.Document();
    final date = DateFormat('dd-MM-yyyy');
    doc.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      build: (_) => [
        pw.Text('SHAKTI VYAVHAR - REPORT', style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold)),
        pw.Text(businessName),
        pw.SizedBox(height: 12),
        pw.Table.fromTextArray(headers: const ['Metric', 'Amount'], data: [
          ['Total Receivable', 'Rs. ${(stats['totalReceivable'] ?? 0).toStringAsFixed(2)}'],
          ['Total Payable', 'Rs. ${(stats['totalPayable'] ?? 0).toStringAsFixed(2)}'],
          ['Net Position', 'Rs. ${(stats['netBalance'] ?? 0).toStringAsFixed(2)}'],
          ['Customers', '${(stats['customerCount'] ?? 0).toInt()}'],
          ['Suppliers', '${(stats['supplierCount'] ?? 0).toInt()}'],
        ]),
        pw.SizedBox(height: 18),
        pw.Text('Transactions', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
        pw.Table.fromTextArray(headers: const ['Date', 'Type', 'Amount', 'Details'], data: transactions.map((t) => [
          date.format(t.date), t.isCredit ? 'Credit' : 'Debit', 'Rs. ${t.amount.toStringAsFixed(2)}', t.description ?? '',
        ]).toList()),
      ],
    ));
    await Printing.sharePdf(bytes: await doc.save(), filename: 'shakti_report.pdf');
  }

  Future<void> shareTransactionsCsv(List<Transaction> transactions) async {
    final b = StringBuffer('Date,Type,Amount,Payment Mode,Description\n');
    for (final t in transactions) {
      final desc = (t.description ?? '').replaceAll('"', '""');
      b.writeln('${t.date.toIso8601String()},${t.isCredit ? 'Credit' : 'Debit'},${t.amount.toStringAsFixed(2)},${t.paymentMode.name},"$desc"');
    }
    await Share.share(b.toString(), subject: 'Shakti Vyavhar Transactions CSV');
  }

}
