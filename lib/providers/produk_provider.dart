import 'package:flutter/material.dart';
import '../models/produk.dart';
import '../database/produk_repository.dart';
import '../services/impor_produk_service.dart';

// Ringkasan hasil setelah proses import Excel selesai
class HasilImporProduk {
  final int berhasil;
  final int duplikat;
  final int gagal;
  final List<String> pesanGagal;

  HasilImporProduk({
    required this.berhasil,
    required this.duplikat,
    required this.gagal,
    required this.pesanGagal,
  });
}

class ProdukProvider extends ChangeNotifier {
  final ProdukRepository _repository = ProdukRepository();
  List<Produk> _daftarProduk = [];

  List<Produk> get daftarProduk => _daftarProduk;

  Future<void> muatData() async {
    _daftarProduk = await _repository.getAll();
    notifyListeners();
  }

  // Cek apakah nama produk sudah ada (untuk validasi duplikat)
  bool cekNamaSudahAda(String nama, {int? kecualiId}) {
    return _daftarProduk.any((p) =>
        p.nama.toLowerCase() == nama.toLowerCase() &&
        p.id != kecualiId);
  }

  Future<void> tambah(Produk produk) async {
    await _repository.tambah(produk);
    await muatData();
  }

  Future<void> update(Produk produk) async {
    await _repository.update(produk);
    await muatData();
  }

  Future<void> hapus(int id) async {
    await _repository.hapus(id);
    await muatData();
  }

  // Tambah stok produk (restock) + otomatis tercatat di stok_log
  Future<void> tambahStok(int produkId, int jumlahTambah, {String? keterangan}) async {
    await _repository.updateStok(
      produkId: produkId,
      jumlahPerubahan: jumlahTambah,
      jenis: 'masuk',
      keterangan: keterangan,
    );
    await muatData();
  }

  // Import produk dari file Excel (.xlsx). Produk dengan nama yang sudah ada
  // (baik di database maupun duplikat di dalam file itu sendiri) akan dilewati.
  Future<HasilImporProduk> importDariExcel(String path) async {
    final hasilBaca = await ImporProdukService.bacaDariFile(path);

    final namaTerpakai = _daftarProduk.map((p) => p.nama.toLowerCase()).toSet();
    int berhasil = 0;
    int duplikat = 0;

    for (final produk in hasilBaca.produkValid) {
      final namaLower = produk.nama.toLowerCase();
      if (namaTerpakai.contains(namaLower)) {
        duplikat++;
        continue;
      }
      await _repository.tambah(produk);
      namaTerpakai.add(namaLower);
      berhasil++;
    }

    await muatData();

    return HasilImporProduk(
      berhasil: berhasil,
      duplikat: duplikat,
      gagal: hasilBaca.errors.length,
      pesanGagal: [
        for (var e in hasilBaca.errors) 'Baris ${e.baris}: ${e.pesan}',
      ],
    );
  }
}