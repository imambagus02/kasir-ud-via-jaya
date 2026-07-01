import 'package:flutter/material.dart';
import '../models/transaksi.dart';
import '../database/transaksi_repository.dart';

// Satu baris rekap (bisa mewakili 1 hari, 1 bulan, atau 1 tahun)
class RekapItem {
  final String label;
  final DateTime kunci; // dipakai untuk sorting
  double totalPenjualan;
  int jumlahTransaksi;
  int totalItem; // jumlah item/barang terjual
  double totalKeuntungan; // laba kotor (harga jual - harga beli) x qty

  RekapItem({
    required this.label,
    required this.kunci,
    this.totalPenjualan = 0,
    this.jumlahTransaksi = 0,
    this.totalItem = 0,
    this.totalKeuntungan = 0,
  });
}

// Satu baris rekap produk terlaris
class ProdukTerlarisItem {
  final String namaProduk;
  int totalQty;
  double totalPendapatan;

  ProdukTerlarisItem({
    required this.namaProduk,
    this.totalQty = 0,
    this.totalPendapatan = 0,
  });
}

class LaporanProvider extends ChangeNotifier {
  final TransaksiRepository _repository = TransaksiRepository();
  List<Transaksi> _semuaTransaksi = [];
  List<TransaksiItem> _semuaItem = [];
  Map<int, Transaksi> _transaksiMap = {}; // id transaksi -> Transaksi (untuk join cepat dengan item)
  bool _loading = false;

  bool get isLoading => _loading;
  List<Transaksi> get semuaTransaksi => _semuaTransaksi;
  List<TransaksiItem> get semuaItem => _semuaItem;

  Future<void> muatData() async {
    _loading = true;
    notifyListeners();
    _semuaTransaksi = await _repository.getAll();
    _semuaItem = await _repository.getAllItems();
    _transaksiMap = {
      for (var t in _semuaTransaksi)
        if (t.id != null) t.id!: t,
    };
    _loading = false;
    notifyListeners();
  }

  // Hapus satu transaksi dari riwayat
  Future<void> hapusSatu(int transaksiId) async {
    await _repository.hapusSatu(transaksiId);
    await muatData();
  }

  // Hapus SEMUA riwayat transaksi/laporan
  Future<void> hapusSemuaRiwayat() async {
    await _repository.hapusSemua();
    await muatData();
  }

  // Ambil item-item milik satu transaksi dari data yang sudah dimuat di memori
  // (tanpa query ulang ke database) — dipakai untuk dialog detail struk.
  List<TransaksiItem> itemUntukTransaksi(int transaksiId) {
    return _semuaItem.where((i) => i.transaksiId == transaksiId).toList();
  }

  // Keuntungan satu item = (harga jual - harga beli) x qty
  double _keuntunganItem(TransaksiItem item) {
    return (item.hargaJual - item.hargaBeli) * item.qty;
  }

  // ─── Ringkasan cepat (pendapatan) ─────────────────────────

  double get totalHariIni {
    final now = DateTime.now();
    return _semuaTransaksi
        .where((t) {
          final d = DateTime.parse(t.tanggal);
          return d.year == now.year && d.month == now.month && d.day == now.day;
        })
        .fold(0.0, (sum, t) => sum + t.totalBayar);
  }

  double get totalBulanIni {
    final now = DateTime.now();
    return _semuaTransaksi
        .where((t) {
          final d = DateTime.parse(t.tanggal);
          return d.year == now.year && d.month == now.month;
        })
        .fold(0.0, (sum, t) => sum + t.totalBayar);
  }

  double get totalTahunIni {
    final now = DateTime.now();
    return _semuaTransaksi
        .where((t) => DateTime.parse(t.tanggal).year == now.year)
        .fold(0.0, (sum, t) => sum + t.totalBayar);
  }

  // ─── Ringkasan total keseluruhan (all-time) ──────────────
  // Dipakai untuk kartu "Total Item Terjual", "Total Pendapatan",
  // dan "Total Keuntungan" di bagian atas layar Laporan.

  double get totalPendapatanSemua {
    return _semuaTransaksi.fold(0.0, (sum, t) => sum + t.totalBayar);
  }

  int get totalItemTerjualSemua {
    return _semuaItem.fold(0, (sum, i) => sum + i.qty);
  }

  double get totalKeuntunganSemua {
    return _semuaItem.fold(0.0, (sum, i) => sum + _keuntunganItem(i));
  }

  // ─── Total item terjual & keuntungan per periode cepat ───

  int get totalItemTerjualHariIni => _totalItemPeriode(
        (d, now) => d.year == now.year && d.month == now.month && d.day == now.day,
      );

  int get totalItemTerjualBulanIni => _totalItemPeriode(
        (d, now) => d.year == now.year && d.month == now.month,
      );

  int get totalItemTerjualTahunIni =>
      _totalItemPeriode((d, now) => d.year == now.year);

  double get totalKeuntunganHariIni => _totalKeuntunganPeriode(
        (d, now) => d.year == now.year && d.month == now.month && d.day == now.day,
      );

  double get totalKeuntunganBulanIni => _totalKeuntunganPeriode(
        (d, now) => d.year == now.year && d.month == now.month,
      );

  double get totalKeuntunganTahunIni =>
      _totalKeuntunganPeriode((d, now) => d.year == now.year);

  int _totalItemPeriode(bool Function(DateTime d, DateTime now) cocok) {
    final now = DateTime.now();
    int total = 0;
    for (var item in _semuaItem) {
      final t = _transaksiMap[item.transaksiId];
      if (t == null) continue;
      if (cocok(DateTime.parse(t.tanggal), now)) total += item.qty;
    }
    return total;
  }

  double _totalKeuntunganPeriode(bool Function(DateTime d, DateTime now) cocok) {
    final now = DateTime.now();
    double total = 0;
    for (var item in _semuaItem) {
      final t = _transaksiMap[item.transaksiId];
      if (t == null) continue;
      if (cocok(DateTime.parse(t.tanggal), now)) total += _keuntunganItem(item);
    }
    return total;
  }

  // ─── Produk paling laku terjual ───────────────────────────
  // Jika mulai/sampai diisi, hanya menghitung transaksi dalam rentang itu.
  // Jika kosong, menghitung dari SELURUH riwayat transaksi.

  List<ProdukTerlarisItem> produkTerlaris({
    DateTime? mulai,
    DateTime? sampai,
    int limit = 5,
  }) {
    final Map<String, ProdukTerlarisItem> map = {};
    for (var item in _semuaItem) {
      if (mulai != null || sampai != null) {
        final t = _transaksiMap[item.transaksiId];
        if (t == null) continue;
        final d = DateTime.parse(t.tanggal);
        if (mulai != null && d.isBefore(mulai)) continue;
        if (sampai != null && d.isAfter(sampai)) continue;
      }
      map.putIfAbsent(
        item.namaProduk,
        () => ProdukTerlarisItem(namaProduk: item.namaProduk),
      );
      map[item.namaProduk]!.totalQty += item.qty;
      map[item.namaProduk]!.totalPendapatan += item.subtotal;
    }
    final list = map.values.toList();
    list.sort((a, b) => b.totalQty.compareTo(a.totalQty));
    return list.take(limit).toList();
  }

  // ─── Riwayat transaksi (daftar transaksi individual) ─────
  // Berbeda dengan rekap (yang menggabungkan per hari/bulan/tahun),
  // ini mengembalikan transaksi satu-satu untuk periode yang dipilih.

  List<Transaksi> riwayatHarian(DateTime tanggal) {
    return _semuaTransaksi.where((t) {
      final d = DateTime.parse(t.tanggal);
      return d.year == tanggal.year &&
          d.month == tanggal.month &&
          d.day == tanggal.day;
    }).toList();
  }

  List<Transaksi> riwayatBulanan(int tahun, int bulan) {
    return _semuaTransaksi.where((t) {
      final d = DateTime.parse(t.tanggal);
      return d.year == tahun && d.month == bulan;
    }).toList();
  }

  List<Transaksi> riwayatTahunan(int tahun) {
    return _semuaTransaksi.where((t) {
      final d = DateTime.parse(t.tanggal);
      return d.year == tahun;
    }).toList();
  }

  // Riwayat transaksi dalam rentang tanggal bebas (inklusif di kedua ujung).
  List<Transaksi> riwayatRentang(DateTime dari, DateTime sampai) {
    final awal = DateTime(dari.year, dari.month, dari.day);
    final akhir = DateTime(sampai.year, sampai.month, sampai.day, 23, 59, 59, 999);
    return _semuaTransaksi.where((t) {
      final d = DateTime.parse(t.tanggal);
      return !d.isBefore(awal) && !d.isAfter(akhir);
    }).toList();
  }

  // ─── Rekap Harian (untuk 1 bulan tertentu) ───────────────

  List<RekapItem> rekapHarian(int tahun, int bulan) {
    final Map<String, RekapItem> map = {};
    for (var t in _semuaTransaksi) {
      final d = DateTime.parse(t.tanggal);
      if (d.year != tahun || d.month != bulan) continue;
      final key =
          '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
      map.putIfAbsent(
        key,
        () => RekapItem(
          label: _formatTanggal(d),
          kunci: DateTime(d.year, d.month, d.day),
        ),
      );
      map[key]!.totalPenjualan += t.totalBayar;
      map[key]!.jumlahTransaksi += 1;
    }
    _tambahkanItemKeRekapHarian(map, tahun, bulan);
    final list = map.values.toList();
    list.sort((a, b) => b.kunci.compareTo(a.kunci));
    return list;
  }

  void _tambahkanItemKeRekapHarian(
      Map<String, RekapItem> map, int tahun, int bulan) {
    for (var item in _semuaItem) {
      final t = _transaksiMap[item.transaksiId];
      if (t == null) continue;
      final d = DateTime.parse(t.tanggal);
      if (d.year != tahun || d.month != bulan) continue;
      final key =
          '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
      final rekap = map[key];
      if (rekap == null) continue;
      rekap.totalItem += item.qty;
      rekap.totalKeuntungan += _keuntunganItem(item);
    }
  }

  // ─── Rekap Bulanan (untuk 1 tahun tertentu, Jan–Des) ─────

  static const List<String> namaBulan = [
    'Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni',
    'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember'
  ];

  List<RekapItem> rekapBulanan(int tahun) {
    final List<RekapItem> list = List.generate(
      12,
      (i) => RekapItem(
        label: namaBulan[i],
        kunci: DateTime(tahun, i + 1),
      ),
    );
    for (var t in _semuaTransaksi) {
      final d = DateTime.parse(t.tanggal);
      if (d.year != tahun) continue;
      list[d.month - 1].totalPenjualan += t.totalBayar;
      list[d.month - 1].jumlahTransaksi += 1;
    }
    for (var item in _semuaItem) {
      final t = _transaksiMap[item.transaksiId];
      if (t == null) continue;
      final d = DateTime.parse(t.tanggal);
      if (d.year != tahun) continue;
      list[d.month - 1].totalItem += item.qty;
      list[d.month - 1].totalKeuntungan += _keuntunganItem(item);
    }
    return list;
  }

  // ─── Rekap Tahunan (semua tahun yang ada transaksinya) ───

  List<RekapItem> rekapTahunan() {
    final Map<int, RekapItem> map = {};
    for (var t in _semuaTransaksi) {
      final d = DateTime.parse(t.tanggal);
      map.putIfAbsent(
        d.year,
        () => RekapItem(label: '${d.year}', kunci: DateTime(d.year)),
      );
      map[d.year]!.totalPenjualan += t.totalBayar;
      map[d.year]!.jumlahTransaksi += 1;
    }
    for (var item in _semuaItem) {
      final t = _transaksiMap[item.transaksiId];
      if (t == null) continue;
      final d = DateTime.parse(t.tanggal);
      final rekap = map[d.year];
      if (rekap == null) continue;
      rekap.totalItem += item.qty;
      rekap.totalKeuntungan += _keuntunganItem(item);
    }
    final list = map.values.toList();
    list.sort((a, b) => b.kunci.compareTo(a.kunci));
    return list;
  }

  // Daftar tahun yang punya data transaksi (untuk referensi/dropdown)
  List<int> get daftarTahun {
    final tahunSet =
        _semuaTransaksi.map((t) => DateTime.parse(t.tanggal).year).toSet();
    tahunSet.add(DateTime.now().year);
    final list = tahunSet.toList()..sort((a, b) => b.compareTo(a));
    return list;
  }

  String _formatTanggal(DateTime d) {
    const namaHari = ['Senin', 'Selasa', 'Rabu', 'Kamis', 'Jumat', 'Sabtu', 'Minggu'];
    const namaBulanSingkat = [
      'Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun',
      'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des'
    ];
    return '${namaHari[d.weekday - 1]}, ${d.day} ${namaBulanSingkat[d.month - 1]} ${d.year}';
  }
}