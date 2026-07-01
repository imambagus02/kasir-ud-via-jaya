import '../models/transaksi.dart';
import '../models/stok_log.dart';
import 'db_helper.dart';

class TransaksiRepository {
  final dbHelper = DBHelper();

  // Simpan transaksi baru beserta item-itemnya, dan kurangi stok produk
  Future<int> simpanTransaksi({
    required Transaksi transaksi,
    required List<TransaksiItem> items,
  }) async {
    final db = await dbHelper.database;
    late int transaksiId;

    await db.transaction((txn) async {
      // 1. Simpan data transaksi utama
      transaksiId = await txn.insert('transaksi', transaksi.toMap());

      // 2. Simpan tiap item, dan kurangi stok produk terkait
      for (var item in items) {
        item.transaksiId = transaksiId;
        await txn.insert('transaksi_item', item.toMap());

        // Kurangi stok produk
        final result = await txn.query(
          'produk',
          where: 'id = ?',
          whereArgs: [item.produkId],
        );
        final stokSaatIni = result.first['stok'] as int;
        final stokBaru = stokSaatIni - item.qty;

        await txn.update(
          'produk',
          {'stok': stokBaru},
          where: 'id = ?',
          whereArgs: [item.produkId],
        );

        // Catat ke stok_log sebagai 'keluar'
        final log = StokLog(
          produkId: item.produkId,
          jenis: 'keluar',
          jumlah: item.qty,
          tanggal: transaksi.tanggal,
          keterangan: 'Penjualan transaksi #$transaksiId',
        );
        await txn.insert('stok_log', log.toMap());
      }
    });

    return transaksiId;
  }

  // Ambil semua transaksi (untuk riwayat)
  Future<List<Transaksi>> getAll() async {
    final db = await dbHelper.database;
    final result = await db.query('transaksi', orderBy: 'tanggal DESC');
    return result.map((map) => Transaksi.fromMap(map)).toList();
  }

  // Ambil item-item dari satu transaksi (untuk lihat detail/struk)
  Future<List<TransaksiItem>> getItemsByTransaksiId(int transaksiId) async {
    final db = await dbHelper.database;
    final result = await db.query(
      'transaksi_item',
      where: 'transaksi_id = ?',
      whereArgs: [transaksiId],
    );
    return result.map((map) => TransaksiItem.fromMap(map)).toList();
  }
  // ⬇️ TAMBAHKAN INI (method baru)
  Future<List<TransaksiItem>> getAllItems() async {
    final db = await dbHelper.database;
    final result = await db.query('transaksi_item');
    return result.map((map) => TransaksiItem.fromMap(map)).toList();
  }

  // Ambil transaksi dalam rentang tanggal (untuk laporan)
  Future<List<Transaksi>> getByRentangTanggal(String mulai, String sampai) async {
    final db = await dbHelper.database;
    final result = await db.query(
      'transaksi',
      where: 'tanggal BETWEEN ? AND ?',
      whereArgs: [mulai, sampai],
      orderBy: 'tanggal DESC',
    );
    return result.map((map) => Transaksi.fromMap(map)).toList();
  }

  // Hapus SATU transaksi beserta item-itemnya (stok TIDAK dikembalikan)
  Future<void> hapusSatu(int transaksiId) async {
    final db = await dbHelper.database;
    await db.transaction((txn) async {
      await txn.delete(
        'transaksi_item',
        where: 'transaksi_id = ?',
        whereArgs: [transaksiId],
      );
      await txn.delete(
        'transaksi',
        where: 'id = ?',
        whereArgs: [transaksiId],
      );
    });
  }

  // Hapus SEMUA riwayat transaksi (stok TIDAK dikembalikan)
  Future<void> hapusSemua() async {
    final db = await dbHelper.database;
    await db.transaction((txn) async {
      await txn.delete('transaksi_item');
      await txn.delete('transaksi');
    });
  }
}