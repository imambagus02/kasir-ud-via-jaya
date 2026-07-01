import 'package:flutter/material.dart';
import '../models/produk.dart';
import '../database/produk_repository.dart';

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
}