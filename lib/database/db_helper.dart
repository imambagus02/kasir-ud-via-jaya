import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class DBHelper {
  static final DBHelper _instance = DBHelper._internal();
  factory DBHelper() => _instance;
  DBHelper._internal();

  static Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB();
    return _database!;
  }

  Future<Database> _initDB() async {
    String path = join(await getDatabasesPath(), 'kasir_offline.db');
    return await openDatabase(
      path,
      version: 1,
      onCreate: _onCreate,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    // Tabel kategori
    await db.execute('''
      CREATE TABLE kategori (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        nama TEXT
      )
    ''');

    // Tabel produk
    await db.execute('''
  CREATE TABLE produk (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    nama TEXT NOT NULL,
    foto_path TEXT,
    kategori_id INTEGER,
    harga_beli REAL NOT NULL,
    harga_jual REAL NOT NULL,
    stok INTEGER NOT NULL DEFAULT 0
  )
''');

    // Tabel transaksi
    await db.execute('''
      CREATE TABLE transaksi (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        tanggal TEXT NOT NULL,
        total_bayar REAL NOT NULL,
        total_diterima REAL NOT NULL,
        kembalian REAL NOT NULL
      )
    ''');

    // Tabel transaksi_item
    await db.execute('''
      CREATE TABLE transaksi_item (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        transaksi_id INTEGER NOT NULL,
        produk_id INTEGER NOT NULL,
        nama_produk TEXT NOT NULL,
        harga_jual REAL NOT NULL,
        harga_beli REAL NOT NULL,
        qty INTEGER NOT NULL,
        subtotal REAL NOT NULL,
        FOREIGN KEY (transaksi_id) REFERENCES transaksi (id),
        FOREIGN KEY (produk_id) REFERENCES produk (id)
      )
    ''');

    // Tabel stok_log
    await db.execute('''
      CREATE TABLE stok_log (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        produk_id INTEGER NOT NULL,
        jenis TEXT NOT NULL,
        jumlah INTEGER NOT NULL,
        tanggal TEXT NOT NULL,
        keterangan TEXT,
        FOREIGN KEY (produk_id) REFERENCES produk (id)
      )
    ''');
  }
}