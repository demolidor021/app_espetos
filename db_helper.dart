import 'dart:async';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

class Sale {
  final int? id;
  final int dateMillis;
  final String item;
  final int qty;
  final double unitPrice;
  final double unitCost;

  Sale({
    this.id,
    required this.dateMillis,
    required this.item,
    required this.qty,
    required this.unitPrice,
    required this.unitCost,
  });

  double get total => qty * unitPrice;
  double get profit => qty * (unitPrice - unitCost);
  double get marginPct => unitPrice == 0 ? 0 : ((unitPrice - unitCost) / unitPrice) * 100.0;

  Map<String, dynamic> toMap() => {
        'id': id,
        'dateMillis': dateMillis,
        'item': item,
        'qty': qty,
        'unitPrice': unitPrice,
        'unitCost': unitCost,
      };

  static Sale fromMap(Map<String, dynamic> m) => Sale(
        id: m['id'] as int?,
        dateMillis: m['dateMillis'] as int,
        item: m['item'] as String,
        qty: m['qty'] as int,
        unitPrice: (m['unitPrice'] as num).toDouble(),
        unitCost: ((m['unitCost'] ?? 0) as num).toDouble(),
      );
}

class Preset {
  final int? id;
  final String name;
  final double defaultPrice;
  final String category;
  final double unitCost;

  Preset({
    this.id,
    required this.name,
    required this.defaultPrice,
    required this.category,
    required this.unitCost,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'defaultPrice': defaultPrice,
        'category': category,
        'unitCost': unitCost,
      };

  static Preset fromMap(Map<String, dynamic> m) => Preset(
        id: m['id'] as int?,
        name: m['name'] as String,
        defaultPrice: (m['defaultPrice'] as num).toDouble(),
        category: m['category'] as String,
        unitCost: ((m['unitCost'] ?? 0) as num).toDouble(),
      );
}

class DBHelper {
  static final DBHelper _i = DBHelper._internal();
  factory DBHelper() => _i;
  DBHelper._internal();

  static const _dbName = 'espetos_vendas.db';
  static const _dbVersion = 4; // inclui custos em sales e presets
  Database? _db;

  Future<Database> get db async {
    if (_db != null) return _db!;
    final path = join(await getDatabasesPath(), _dbName);
    _db = await openDatabase(
      path,
      version: _dbVersion,
      onCreate: (db, v) async {
        await _createV1(db); // sales
        await _createV2(db); // presets (sem unitCost)
        await _migrateV3(db); // add unitCost em sales
        await _migrateV4(db); // add unitCost em presets
      },
      onUpgrade: (db, oldV, newV) async {
        if (oldV < 1) await _createV1(db);
        if (oldV < 2) await _createV2(db);
        if (oldV < 3) await _migrateV3(db);
        if (oldV < 4) await _migrateV4(db);
      },
    );
    return _db!;
  }

  Future<void> _createV1(Database db) async {
    await db.execute('''
      CREATE TABLE sales(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        dateMillis INTEGER NOT NULL,
        item TEXT NOT NULL,
        qty INTEGER NOT NULL,
        unitPrice REAL NOT NULL
      )
    ''');
  }

  Future<void> _createV2(Database db) async {
    await db.execute('''
      CREATE TABLE presets(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        defaultPrice REAL NOT NULL,
        category TEXT NOT NULL
      )
    ''');

    // seeds básicos (unitCost entra na migração v4)
    final seeds = [
      Preset(name: 'Carne', defaultPrice: 10.0, category: 'Carnes', unitCost: 6.5),
      Preset(name: 'Frango', defaultPrice: 8.0, category: 'Frango', unitCost: 4.5),
      Preset(name: 'Linguiça', defaultPrice: 9.0, category: 'Carnes', unitCost: 5.0),
      Preset(name: 'Coração', defaultPrice: 9.0, category: 'Frango', unitCost: 4.8),
      Preset(name: 'Kafta', defaultPrice: 12.0, category: 'Carnes', unitCost: 7.0),
      Preset(name: 'Queijo Coalho', defaultPrice: 10.0, category: 'Queijos', unitCost: 6.0),
      Preset(name: 'Pão de Alho', defaultPrice: 7.0, category: 'Acompanhamentos', unitCost: 3.0),
      Preset(name: 'Banana c/ Canela', defaultPrice: 8.0, category: 'Doces', unitCost: 3.5),
    ];
    for (final p in seeds) {
      await db.insert('presets', {
        'name': p.name,
        'defaultPrice': p.defaultPrice,
        'category': p.category,
      });
    }
  }

  Future<void> _migrateV3(Database db) async {
    await db.execute("ALTER TABLE sales ADD COLUMN unitCost REAL NOT NULL DEFAULT 0");
  }

  Future<void> _migrateV4(Database db) async {
    try {
      await db.execute("ALTER TABLE presets ADD COLUMN unitCost REAL NOT NULL DEFAULT 0");
      // define custo padrão onde ainda for 0 (ajuste livre depois pela tela)
      await db.update('presets', {'unitCost': 5.0});
    } catch (_) {/* coluna já existe */}
  }

  // ---------------- SALES ----------------
  Future<int> insertSale(Sale s) async {
    final d = await db;
    return d.insert('sales', s.toMap());
  }

  Future<List<Sale>> getSalesByDay(DateTime day) async {
    final d = await db;
    final start = DateTime(day.year, day.month, day.day).millisecondsSinceEpoch;
    final end = DateTime(day.year, day.month, day.day, 23, 59, 59, 999).millisecondsSinceEpoch;
    final rows = await d.query('sales',
        where: 'dateMillis BETWEEN ? AND ?', whereArgs: [start, end], orderBy: 'dateMillis DESC');
    return rows.map(Sale.fromMap).toList();
  }

  Future<List<Sale>> getSalesBetween(DateTime startDt, DateTime endDt) async {
    final d = await db;
    final start = DateTime(startDt.year, startDt.month, startDt.day).millisecondsSinceEpoch;
    final end = DateTime(endDt.year, endDt.month, endDt.day, 23, 59, 59, 999).millisecondsSinceEpoch;
    final rows = await d.query('sales',
        where: 'dateMillis BETWEEN ? AND ?', whereArgs: [start, end], orderBy: 'dateMillis ASC');
    return rows.map(Sale.fromMap).toList();
  }

  Future<double> getDailyTotal(DateTime day) async {
    final d = await db;
    final start = DateTime(day.year, day.month, day.day).millisecondsSinceEpoch;
    final end = DateTime(day.year, day.month, day.day, 23, 59, 59, 999).millisecondsSinceEpoch;
    final rows = await d.rawQuery(
        'SELECT SUM(qty * unitPrice) as total FROM sales WHERE dateMillis BETWEEN ? AND ?', [start, end]);
    final t = rows.first['total'] as num?;
    return (t ?? 0).toDouble();
  }

  /// "YYYY-MM" -> total
  Future<Map<String, double>> getMonthlyTotals({int monthsBack = 6}) async {
    final d = await db;
    final now = DateTime.now();
    final firstMonth = DateTime(now.year, now.month - (monthsBack - 1));
    final start = DateTime(firstMonth.year, firstMonth.month).millisecondsSinceEpoch;

    final rows = await d.rawQuery('''
      SELECT 
        strftime('%Y-%m', datetime(dateMillis/1000, 'unixepoch')) as ym,
        SUM(qty * unitPrice) as total
      FROM sales
      WHERE dateMillis >= ?
      GROUP BY ym
      ORDER BY ym ASC
    ''', [start]);

    final map = <String, double>{};
    for (final r in rows) {
      final ym = r['ym'] as String;
      final total = (r['total'] as num?)?.toDouble() ?? 0.0;
      map[ym] = total;
    }
    for (int i = 0; i < monthsBack; i++) {
      final dt = DateTime(now.year, now.month - (monthsBack - 1 - i));
      final ym = '${dt.year.toString().padLeft(4, '0')}-${dt.month.toString().padLeft(2, '0')}';
      map.putIfAbsent(ym, () => 0.0);
    }
    return map;
  }

  Future<Map<String, dynamic>> getMonthlySummary(int year, int month) async {
    final d = await db;
    final start = DateTime(year, month, 1).millisecondsSinceEpoch;
    final end = DateTime(year, month + 1, 0, 23, 59, 59, 999).millisecondsSinceEpoch;
    final rows = await d.rawQuery('''
      SELECT 
        COUNT(*) as salesCount,
        SUM(qty) as itemsCount,
        SUM(qty * unitPrice) as totalRevenue,
        SUM(qty * (unitPrice - unitCost)) as totalProfit
      FROM sales
      WHERE dateMillis BETWEEN ? AND ?
    ''', [start, end]);

    final m = rows.first;
    final salesCount = (m['salesCount'] as num?)?.toInt() ?? 0;
    final itemsCount = (m['itemsCount'] as num?)?.toInt() ?? 0;
    final totalRevenue = (m['totalRevenue'] as num?)?.toDouble() ?? 0.0;
    final totalProfit = (m['totalProfit'] as num?)?.toDouble() ?? 0.0;
    final avgTicket = salesCount == 0 ? 0.0 : totalRevenue / salesCount;
    final marginPct = totalRevenue == 0 ? 0.0 : (totalProfit / totalRevenue) * 100.0;

    return {
      'salesCount': salesCount,
      'itemsCount': itemsCount,
      'totalRevenue': totalRevenue,
      'totalProfit': totalProfit,
      'avgTicket': avgTicket,
      'marginPct': marginPct,
    };
  }

  // ---------------- PRESETS ----------------
  Future<List<Preset>> getAllPresets() async {
    final d = await db;
    final rows = await d.query('presets', orderBy: 'category ASC, name ASC');
    return rows.map(Preset.fromMap).toList();
  }

  Future<int> upsertPreset(Preset p) async {
    final d = await db;
    if (p.id == null) {
      return d.insert('presets', p.toMap());
    } else {
      return d.update('presets', p.toMap(), where: 'id = ?', whereArgs: [p.id]);
    }
  }

  Future<int> deletePreset(int id) async {
    final d = await db;
    return d.delete('presets', where: 'id = ?', whereArgs: [id]);
  }
}
