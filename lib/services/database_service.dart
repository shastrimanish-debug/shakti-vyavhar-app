import 'dart:convert';

import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import '../models/business.dart';
import '../models/product.dart';
import '../models/customer.dart';
import '../models/transaction.dart' as model;

class DatabaseService {
  static final DatabaseService _instance = DatabaseService._internal();
  factory DatabaseService() => _instance;
  DatabaseService._internal();

  static Database? _database;
  static const String defaultBusinessId = 'default';

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('shakti_vyavhar.db');
    return _database!;
  }

  Future<Database> _initDB(String fileName) async {
    final documentsDirectory = await getApplicationDocumentsDirectory();
    final dbPath = join(documentsDirectory.path, fileName);
    return openDatabase(
      dbPath,
      version: 4,
      onCreate: _createDB,
      onUpgrade: _upgradeDB,
      onOpen: (db) async {
        await db.execute('PRAGMA foreign_keys = ON');
        final rows = await db.query('business', limit: 1);
        if (rows.isEmpty) {
          await db.insert('business', {
            'id': defaultBusinessId,
            'name': 'Mera Business',
            'language': 'hi',
            'currency': 'INR',
            'createdAt': DateTime.now().toIso8601String(),
          }, conflictAlgorithm: ConflictAlgorithm.ignore);
        }
      },
    );
  }

  Future<void> _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE customers (
        id TEXT PRIMARY KEY,
        businessId TEXT NOT NULL DEFAULT 'default',
        name TEXT NOT NULL,
        phone TEXT,
        address TEXT,
        email TEXT,
        notes TEXT,
        openingBalance REAL DEFAULT 0,
        isSupplier INTEGER DEFAULT 0,
        createdAt TEXT NOT NULL,
        updatedAt TEXT NOT NULL,
        isActive INTEGER DEFAULT 1
      )
    ''');

    await db.execute('''
      CREATE TABLE transactions (
        id TEXT PRIMARY KEY,
        businessId TEXT NOT NULL DEFAULT 'default',
        customerId TEXT NOT NULL,
        type TEXT NOT NULL,
        amount REAL NOT NULL,
        description TEXT,
        paymentMode TEXT DEFAULT 'cash',
        date TEXT NOT NULL,
        createdAt TEXT NOT NULL,
        billNumber TEXT,
        isDeleted INTEGER DEFAULT 0,
        FOREIGN KEY (customerId) REFERENCES customers (id)
      )
    ''');

    await db.execute('''
      CREATE TABLE business (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        ownerName TEXT,
        phone TEXT,
        address TEXT,
        gstin TEXT,
        upiId TEXT,
        currency TEXT DEFAULT 'INR',
        language TEXT DEFAULT 'hi',
        createdAt TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE products (
        id TEXT PRIMARY KEY,
        businessId TEXT NOT NULL DEFAULT 'default',
        name TEXT NOT NULL,
        sku TEXT,
        salePrice REAL DEFAULT 0,
        purchasePrice REAL DEFAULT 0,
        stock REAL DEFAULT 0,
        unit TEXT DEFAULT 'pcs',
        lowStockAt REAL DEFAULT 5,
        isActive INTEGER DEFAULT 1
      )
    ''');

    await db.execute('CREATE INDEX idx_transactions_customer ON transactions(customerId)');
    await db.execute('CREATE INDEX idx_transactions_date ON transactions(date)');
    await db.execute('CREATE INDEX idx_customers_business ON customers(businessId)');
    await db.execute('CREATE INDEX idx_transactions_business ON transactions(businessId)');
    await db.execute('CREATE INDEX idx_products_business ON products(businessId)');

    await db.insert('business', {
      'id': defaultBusinessId,
      'name': 'Mera Business',
      'language': 'hi',
      'currency': 'INR',
      'createdAt': DateTime.now().toIso8601String(),
    });
  }

  Future<void> _upgradeDB(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS products (
          id TEXT PRIMARY KEY,
          name TEXT NOT NULL,
          sku TEXT,
          salePrice REAL DEFAULT 0,
          purchasePrice REAL DEFAULT 0,
          stock REAL DEFAULT 0,
          unit TEXT DEFAULT 'pcs',
          lowStockAt REAL DEFAULT 5,
          isActive INTEGER DEFAULT 1
        )
      ''');
    }
    if (oldVersion < 3) {
      await db.execute("ALTER TABLE customers ADD COLUMN businessId TEXT NOT NULL DEFAULT 'default'");
      await db.execute("ALTER TABLE transactions ADD COLUMN businessId TEXT NOT NULL DEFAULT 'default'");
      await db.execute("ALTER TABLE products ADD COLUMN businessId TEXT NOT NULL DEFAULT 'default'");
      await db.execute('CREATE INDEX IF NOT EXISTS idx_customers_business ON customers(businessId)');
      await db.execute('CREATE INDEX IF NOT EXISTS idx_transactions_business ON transactions(businessId)');
      await db.execute('CREATE INDEX IF NOT EXISTS idx_products_business ON products(businessId)');
      final businessRows = await db.query('business', limit: 1);
      if (businessRows.isEmpty) {
        await db.insert('business', {
          'id': defaultBusinessId,
          'name': 'Mera Business',
          'language': 'hi',
          'currency': 'INR',
          'createdAt': DateTime.now().toIso8601String(),
        }, conflictAlgorithm: ConflictAlgorithm.ignore);
      }
    }
    if (oldVersion < 4) {
      await db.execute("ALTER TABLE business ADD COLUMN upiId TEXT");
    }
  }

  // ==================== BUSINESS PROFILES ====================
  Future<List<Business>> getBusinesses() async {
    final db = await database;
    final rows = await db.query('business', orderBy: 'createdAt ASC');
    return rows.map((m) => Business.fromMap(m)).toList();
  }

  Future<Business?> getBusiness(String id) async {
    final db = await database;
    final rows = await db.query('business', where: 'id = ?', whereArgs: [id], limit: 1);
    return rows.isEmpty ? null : Business.fromMap(rows.first);
  }

  Future<String> saveBusiness(Business business) async {
    final db = await database;
    await db.insert('business', business.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
    return business.id;
  }

  Future<String> createBusiness(String name) async {
    final business = Business(id: const Uuid().v4(), name: name.trim().isEmpty ? 'New Business' : name.trim());
    return saveBusiness(business);
  }

  // ==================== CUSTOMER CRUD ====================
  Future<String> insertCustomer(Customer customer, {String businessId = defaultBusinessId}) async {
    final db = await database;
    final data = customer.businessId == businessId ? customer.toMap() : customer.copyWith(businessId: businessId).toMap();
    await db.insert('customers', data, conflictAlgorithm: ConflictAlgorithm.replace);
    return customer.id;
  }

  Future<List<Customer>> getAllCustomers({bool activeOnly = true, String businessId = defaultBusinessId}) async {
    final db = await database;
    final maps = await db.query(
      'customers',
      where: activeOnly ? 'isActive = 1 AND businessId = ?' : 'businessId = ?',
      whereArgs: [businessId],
      orderBy: 'name ASC',
    );
    return maps.map((m) => Customer.fromMap(m)).toList();
  }

  Future<Customer?> getCustomerById(String id, {String? businessId}) async {
    final db = await database;
    final where = businessId == null ? 'id = ?' : 'id = ? AND businessId = ?';
    final args = businessId == null ? [id] : [id, businessId];
    final maps = await db.query('customers', where: where, whereArgs: args, limit: 1);
    if (maps.isEmpty) return null;
    return Customer.fromMap(maps.first);
  }

  Future<int> updateCustomer(Customer customer) async {
    final db = await database;
    return db.update('customers', customer.toMap(), where: 'id = ? AND businessId = ?', whereArgs: [customer.id, customer.businessId]);
  }

  Future<int> deleteCustomer(String id, {String businessId = defaultBusinessId}) async {
    final db = await database;
    return db.update('customers', {'isActive': 0, 'updatedAt': DateTime.now().toIso8601String()}, where: 'id = ? AND businessId = ?', whereArgs: [id, businessId]);
  }

  Future<List<Customer>> searchCustomers(String query, {String businessId = defaultBusinessId}) async {
    final db = await database;
    final maps = await db.query(
      'customers',
      where: 'isActive = 1 AND businessId = ? AND (name LIKE ? OR phone LIKE ?)',
      whereArgs: [businessId, '%$query%', '%$query%'],
      orderBy: 'name ASC',
    );
    return maps.map((m) => Customer.fromMap(m)).toList();
  }

  // ==================== TRANSACTION CRUD ====================
  Future<String> insertTransaction(model.Transaction txn, {String businessId = defaultBusinessId}) async {
    if (txn.amount <= 0) throw ArgumentError('Transaction amount must be greater than zero');
    final db = await database;
    final data = txn.businessId == businessId ? txn.toMap() : txn.copyWith(businessId: businessId).toMap();
    await db.insert('transactions', data, conflictAlgorithm: ConflictAlgorithm.replace);
    return txn.id;
  }

  Future<List<model.Transaction>> getTransactionsByCustomer(String customerId, {String? businessId}) async {
    final db = await database;
    final where = businessId == null
        ? 'customerId = ? AND isDeleted = 0'
        : 'customerId = ? AND businessId = ? AND isDeleted = 0';
    final args = businessId == null ? [customerId] : [customerId, businessId];
    final maps = await db.query('transactions', where: where, whereArgs: args, orderBy: 'date DESC, createdAt DESC');
    return maps.map((m) => model.Transaction.fromMap(m)).toList();
  }

  Future<List<model.Transaction>> getAllTransactions({DateTime? from, DateTime? to, String businessId = defaultBusinessId}) async {
    final db = await database;
    String where = 'isDeleted = 0 AND businessId = ?';
    final args = <dynamic>[businessId];
    if (from != null) { where += ' AND date >= ?'; args.add(from.toIso8601String()); }
    if (to != null) { where += ' AND date <= ?'; args.add(to.toIso8601String()); }
    final maps = await db.query('transactions', where: where, whereArgs: args, orderBy: 'date DESC');
    return maps.map((m) => model.Transaction.fromMap(m)).toList();
  }

  Future<int> updateTransaction(model.Transaction txn) async => (await database).update('transactions', txn.toMap(), where: 'id = ? AND businessId = ?', whereArgs: [txn.id, txn.businessId]);
  Future<int> deleteTransaction(String id, {String businessId = defaultBusinessId}) async => (await database).update('transactions', {'isDeleted': 1}, where: 'id = ? AND businessId = ?', whereArgs: [id, businessId]);

  // ==================== BALANCE / REPORTS ====================
  Future<double> getCustomerBalance(String customerId, {String? businessId}) async {
    final customer = await getCustomerById(customerId, businessId: businessId);
    if (customer == null) return 0.0;
    final txns = await getTransactionsByCustomer(customerId, businessId: businessId ?? customer.businessId);
    var balance = customer.openingBalance;
    for (final txn in txns) { balance += txn.isCredit ? txn.amount : -txn.amount; }
    return balance;
  }

  Future<Map<String, double>> getDashboardStats({String businessId = defaultBusinessId}) async {
    final customers = await getAllCustomers(businessId: businessId);
    double totalReceivable = 0, totalPayable = 0;
    int customerCount = 0, supplierCount = 0;
    for (final c in customers) {
      final bal = await getCustomerBalance(c.id, businessId: businessId);
      if (c.isSupplier) {
        supplierCount++;
        if (bal > 0) totalPayable += bal;
      } else {
        customerCount++;
        if (bal > 0) totalReceivable += bal;
      }
    }
    return {
      'totalReceivable': totalReceivable,
      'totalPayable': totalPayable,
      'customerCount': customerCount.toDouble(),
      'supplierCount': supplierCount.toDouble(),
      'netBalance': totalReceivable - totalPayable,
    };
  }

  // ==================== INVENTORY ====================
  Future<String> insertProduct(Product product, {String businessId = defaultBusinessId}) async {
    final db = await database;
    final data = product.businessId == businessId ? product.toMap() : product.copyWith(businessId: businessId).toMap();
    await db.insert('products', data, conflictAlgorithm: ConflictAlgorithm.replace);
    return product.id;
  }

  Future<List<Product>> getProducts({bool activeOnly = true, String businessId = defaultBusinessId}) async {
    final db = await database;
    final maps = await db.query('products', where: activeOnly ? 'isActive = 1 AND businessId = ?' : 'businessId = ?', whereArgs: [businessId], orderBy: 'name ASC');
    return maps.map(Product.fromMap).toList();
  }

  Future<int> updateProduct(Product product) async => (await database).update('products', product.toMap(), where: 'id = ? AND businessId = ?', whereArgs: [product.id, product.businessId]);
  Future<int> deleteProduct(String id, {String businessId = defaultBusinessId}) async => (await database).update('products', {'isActive': 0}, where: 'id = ? AND businessId = ?', whereArgs: [id, businessId]);
  Future<void> adjustStock(String id, double delta, {String businessId = defaultBusinessId}) async => (await database).rawUpdate('UPDATE products SET stock = stock + ? WHERE id = ? AND businessId = ?', [delta, id, businessId]);

  // ==================== BACKUP / RESTORE ====================
  Future<Map<String, dynamic>> exportBackup() async {
    final db = await database;
    return {
      'format': 'shakti_vyavhar_backup',
      'version': 4,
      'createdAt': DateTime.now().toIso8601String(),
      'customers': await db.query('customers'),
      'transactions': await db.query('transactions'),
      'business': await db.query('business'),
      'products': await db.query('products'),
    };
  }

  Future<void> restoreBackup(String jsonText) async {
    final decoded = jsonDecode(jsonText);
    if (decoded is! Map || decoded['format'] != 'shakti_vyavhar_backup') {
      throw Exception('Invalid Shakti Vyavhar backup file');
    }
    final customers = decoded['customers'];
    final transactions = decoded['transactions'];
    final businesses = decoded['business'];
    final products = decoded['products'];
    if (customers is! List || transactions is! List || businesses is! List || products is! List) {
      throw Exception('Backup file is incomplete or corrupted');
    }

    final db = await database;
    await db.transaction((txn) async {
      // No dangling rows: transactions are removed before parties/businesses.
      await txn.delete('transactions');
      await txn.delete('customers');
      await txn.delete('products');
      await txn.delete('business');

      for (final row in businesses) {
        await txn.insert('business', Map<String, Object?>.from(row as Map));
      }
      if (businesses.isEmpty) {
        await txn.insert('business', {
          'id': defaultBusinessId,
          'name': 'Mera Business',
          'language': 'hi',
          'currency': 'INR',
          'createdAt': DateTime.now().toIso8601String(),
        });
      }
      for (final row in customers) {
        await txn.insert('customers', Map<String, Object?>.from(row as Map));
      }
      for (final row in transactions) {
        await txn.insert('transactions', Map<String, Object?>.from(row as Map));
      }
      for (final row in products) {
        await txn.insert('products', Map<String, Object?>.from(row as Map));
      }
    });
  }
}
