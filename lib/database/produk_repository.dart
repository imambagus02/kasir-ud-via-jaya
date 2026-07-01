import '../models/produk.dart';
import '../models/stok_log.dart';
import 'db_helper.dart';

class ProdukRepository {
  final dbHelper = DBHelper();

  // Tambah produk baru
  Future<int> tambah(Produk produk) async {
    final db = await dbHelper.database;
    return await db.insert('produk', produk.toMap());
  }

  // Ambil semua produk
  Future<List<Produk>> getAll() async {
    final db = await dbHelper.database;
    final result = await db.query('produk', orderBy: 'nama ASC');
    return result.map((map) => Produk.fromMap(map)).toList();
  }

  // Ambil produk berdasarkan kategori
  Future<List<Produk>> getByKategori(int kategoriId) async {
    final db = await dbHelper.database;
    final result = await db.query(
      'produk',
      where: 'kategori_id = ?',
      whereArgs: [kategoriId],
      orderBy: 'nama ASC',
    );
    return result.map((map) => Produk.fromMap(map)).toList();
  }

  // Update produk (edit nama, harga, dll)
  Future<int> update(Produk produk) async {
    final db = await dbHelper.database;
    return await db.update(
      'produk',
      produk.toMap(),
      where: 'id = ?',
      whereArgs: [produk.id],
    );
  }

  // Hapus produk
  Future<int> hapus(int id) async {
    final db = await dbHelper.database;
    return await db.delete(
      'produk',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // Update stok manual (restock / koreksi) + catat ke stok_log
  Future<void> updateStok({
    required int produkId,
    required int jumlahPerubahan, // positif = nambah, negatif = kurang
    required String jenis, // 'masuk', 'keluar', 'koreksi'
    String? keterangan,
  }) async {
    final db = await dbHelper.database;

    await db.transaction((txn) async {
      // Ambil stok saat ini
      final result = await txn.query(
        'produk',
        where: 'id = ?',
        whereArgs: [produkId],
      );
      final stokSaatIni = result.first['stok'] as int;
      final stokBaru = stokSaatIni + jumlahPerubahan;

      // Update stok produk
      await txn.update(
        'produk',
        {'stok': stokBaru},
        where: 'id = ?',
        whereArgs: [produkId],
      );

      // Catat ke stok_log
      final log = StokLog(
        produkId: produkId,
        jenis: jenis,
        jumlah: jumlahPerubahan.abs(),
        tanggal: DateTime.now().toIso8601String(),
        keterangan: keterangan,
      );
      await txn.insert('stok_log', log.toMap());
    });
  }
}