import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:sqflite/sqflite.dart';

import '../database/db_helper.dart';

/// Urutan tabel harus mengikuti relasi foreign key:
/// - kategori & transaksi tidak bergantung pada tabel lain
/// - produk bergantung pada kategori
/// - transaksi_item bergantung pada transaksi & produk
/// - stok_log bergantung pada produk
const _urutanInsert = [
  'kategori',
  'produk',
  'transaksi',
  'transaksi_item',
  'stok_log',
];

// Urutan hapus dibalik supaya tidak menabrak foreign key.
const _urutanHapus = [
  'transaksi_item',
  'stok_log',
  'transaksi',
  'produk',
  'kategori',
];

class HasilRestore {
  final int totalBaris;
  HasilRestore(this.totalBaris);
}

/// Service untuk membackup & merestore seluruh data aplikasi
/// (kategori, produk, transaksi, item transaksi, dan log stok)
/// dalam bentuk satu file JSON.
class BackupService {
  BackupService._();
  static final BackupService instance = BackupService._();

  /// Membuat file backup berisi seluruh data, lalu membuka menu "Bagikan"
  /// Android supaya pengguna bisa menyimpannya ke Google Drive, kirim ke
  /// WhatsApp/Email, atau simpan ke penyimpanan HP.
  Future<void> backupDanBagikan() async {
    final db = await DBHelper().database;

    final data = <String, dynamic>{};
    for (final tabel in _urutanInsert) {
      data[tabel] = await db.query(tabel);
    }

    final isi = {
      'app': 'kasir_offline',
      'versi_backup': 1,
      'dibuat_pada': DateTime.now().toIso8601String(),
      'data': data,
    };

    final jsonStr = const JsonEncoder.withIndent('  ').convert(isi);

    final dir = await getTemporaryDirectory();
    final namaFile =
        'backup_kasir_${_stampWaktu(DateTime.now())}.json';
    final file = File('${dir.path}/$namaFile');
    await file.writeAsString(jsonStr);

    await Share.shareXFiles(
      [XFile(file.path)],
      text: 'Backup data Kasir Offline ($namaFile)',
    );
  }

  /// Membuka pemilih file, membaca file backup JSON yang dipilih,
  /// lalu mengembalikan Map data mentahnya (belum ditulis ke database).
  /// Berguna untuk menampilkan ringkasan sebelum konfirmasi restore.
  Future<Map<String, dynamic>?> bacaFileBackup() async {
    final hasil = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['json'],
    );
    if (hasil == null || hasil.files.single.path == null) return null;

    final file = File(hasil.files.single.path!);
    final isi = await file.readAsString();
    final parsed = jsonDecode(isi);

    if (parsed is! Map<String, dynamic> || parsed['data'] is! Map) {
      throw const FormatException(
          'File ini bukan file backup Kasir Offline yang valid.');
    }
    return parsed;
  }

  /// Menghapus SEMUA data yang ada saat ini, lalu menulis ulang dari
  /// data backup yang sudah dibaca lewat [bacaFileBackup]. ID asli tetap
  /// dipertahankan supaya relasi antar tabel tetap konsisten.
  Future<HasilRestore> pulihkanDariBackup(Map<String, dynamic> backup) async {
    final db = await DBHelper().database;
    final data = backup['data'] as Map<String, dynamic>;

    int totalBaris = 0;

    await db.transaction((txn) async {
      // Hapus data lama dulu (urutan aman terhadap foreign key).
      for (final tabel in _urutanHapus) {
        await txn.delete(tabel);
      }

      // Tulis ulang data dari backup (urutan aman terhadap foreign key).
      for (final tabel in _urutanInsert) {
        final baris = data[tabel];
        if (baris is! List) continue;
        for (final row in baris) {
          if (row is! Map) continue;
          await txn.insert(
            tabel,
            Map<String, dynamic>.from(row),
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
          totalBaris++;
        }
      }
    });

    return HasilRestore(totalBaris);
  }

  String _stampWaktu(DateTime d) {
    String dua(int n) => n.toString().padLeft(2, '0');
    return '${d.year}${dua(d.month)}${dua(d.day)}_${dua(d.hour)}${dua(d.minute)}';
  }
}
