import 'dart:io';
import 'package:excel/excel.dart';
import '../models/produk.dart';

// Format kolom yang diharapkan di file Excel (baris 1 = header, diabaikan):
// Kolom A: Nama Barang | Kolom B: Harga Beli (Modal) | Kolom C: Harga Jual | Kolom D: Stok

class BarisImporError {
  final int baris; // nomor baris di file Excel (baris 1 = header)
  final String pesan;
  BarisImporError({required this.baris, required this.pesan});
}

class HasilParsingExcel {
  final List<Produk> produkValid;
  final List<BarisImporError> errors;
  HasilParsingExcel({required this.produkValid, required this.errors});
}

class ImporProdukService {
  static Future<HasilParsingExcel> bacaDariFile(String path) async {
    final bytes = await File(path).readAsBytes();
    final excel = Excel.decodeBytes(bytes);

    if (excel.tables.isEmpty) {
      return HasilParsingExcel(produkValid: [], errors: [
        BarisImporError(baris: 0, pesan: 'File Excel kosong atau tidak terbaca'),
      ]);
    }

    final sheet = excel.tables[excel.tables.keys.first]!;
    final produkValid = <Produk>[];
    final errors = <BarisImporError>[];

    // Mulai dari baris ke-2 (index 1), baris pertama dianggap header
    for (int i = 1; i < sheet.maxRows; i++) {
      final row = sheet.row(i);
      final nomorBaris = i + 1;

      final semuaKosong = row.every(
          (cell) => cell?.value == null || cell!.value.toString().trim().isEmpty);
      if (semuaKosong) continue;

      final nama = row.isNotEmpty ? (row[0]?.value?.toString().trim() ?? '') : '';
      if (nama.isEmpty) {
        errors.add(BarisImporError(baris: nomorBaris, pesan: 'Nama barang kosong'));
        continue;
      }

      final hargaBeli = _ambilAngka(row.length > 1 ? row[1]?.value : null);
      if (hargaBeli == null) {
        errors.add(BarisImporError(baris: nomorBaris, pesan: 'Harga Beli tidak valid'));
        continue;
      }

      final hargaJual = _ambilAngka(row.length > 2 ? row[2]?.value : null);
      if (hargaJual == null) {
        errors.add(BarisImporError(baris: nomorBaris, pesan: 'Harga Jual tidak valid'));
        continue;
      }

      final stokAngka = _ambilAngka(row.length > 3 ? row[3]?.value : null);
      if (stokAngka == null) {
        errors.add(BarisImporError(baris: nomorBaris, pesan: 'Stok tidak valid'));
        continue;
      }

      produkValid.add(Produk(
        nama: nama,
        hargaBeli: hargaBeli,
        hargaJual: hargaJual,
        stok: stokAngka.toInt(),
      ));
    }

    return HasilParsingExcel(produkValid: produkValid, errors: errors);
  }

  static double? _ambilAngka(dynamic nilai) {
    if (nilai == null) return null;
    if (nilai is num) return nilai.toDouble();
    final teks = nilai.toString().trim().replaceAll('.', '').replaceAll(',', '.');
    return double.tryParse(teks) ?? double.tryParse(nilai.toString().trim());
  }
}