import 'package:flutter/material.dart';
import '../models/kategori.dart';
import '../database/kategori_repository.dart';

class KategoriProvider extends ChangeNotifier {
  final KategoriRepository _repository = KategoriRepository();
  List<Kategori> _daftarKategori = [];

  List<Kategori> get daftarKategori => _daftarKategori;

  // Ambil semua kategori dari database, simpan ke memori, lalu refresh UI
  Future<void> muatData() async {
    _daftarKategori = await _repository.getAll();
    notifyListeners();
  }

  Future<void> tambah(String nama) async {
    await _repository.tambah(Kategori(nama: nama));
    await muatData(); // refresh list setelah tambah
  }

  Future<void> update(Kategori kategori) async {
    await _repository.update(kategori);
    await muatData();
  }

  Future<void> hapus(int id) async {
    await _repository.hapus(id);
    await muatData();
  }
}