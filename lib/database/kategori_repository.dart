import '../models/kategori.dart';
import 'db_helper.dart';

class KategoriRepository {
  final dbHelper = DBHelper();

  // Tambah kategori baru
  Future<int> tambah(Kategori kategori) async {
    final db = await dbHelper.database;
    return await db.insert('kategori', kategori.toMap());
  }

  // Ambil semua kategori
  Future<List<Kategori>> getAll() async {
    final db = await dbHelper.database;
    final result = await db.query('kategori', orderBy: 'nama ASC');
    return result.map((map) => Kategori.fromMap(map)).toList();
  }

  // Update kategori
  Future<int> update(Kategori kategori) async {
    final db = await dbHelper.database;
    return await db.update(
      'kategori',
      kategori.toMap(),
      where: 'id = ?',
      whereArgs: [kategori.id],
    );
  }

  // Hapus kategori
  Future<int> hapus(int id) async {
    final db = await dbHelper.database;
    return await db.delete(
      'kategori',
      where: 'id = ?',
      whereArgs: [id],
    );
  }
}