import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../models/produk.dart';
import '../providers/produk_provider.dart';
import '../providers/laporan_provider.dart';
import '../models/transaksi.dart';
import '../database/transaksi_repository.dart';
import '../services/printer_service.dart';
import '../widgets/pilih_printer_dialog.dart';
import '../widgets/foto_produk.dart';


class KasirScreen extends StatefulWidget {
  const KasirScreen({super.key});

  @override
  State<KasirScreen> createState() => _KasirScreenState();
}

class _KasirScreenState extends State<KasirScreen> {
  final Map<Produk, int> _keranjang = {};
  final _searchController = TextEditingController();
  String _keyword = '';

  double get _total => _keranjang.entries
      .fold(0, (sum, e) => sum + (e.key.hargaJual * e.value));

  int _qtyDiKeranjang(Produk produk) => _keranjang[produk] ?? 0;

  void _tambahKeKeranjang(Produk produk) {
    final qtySekarang = _qtyDiKeranjang(produk);
    if (qtySekarang >= produk.stok) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Stok ${produk.nama} tidak mencukupi')),
      );
      return;
    }
    setState(() {
      _keranjang[produk] = qtySekarang + 1;
    });
  }

  void _kurangiDariKeranjang(Produk produk) {
    final qtySekarang = _qtyDiKeranjang(produk);
    if (qtySekarang <= 0) return;
    setState(() {
      if (qtySekarang == 1) {
        _keranjang.remove(produk);
      } else {
        _keranjang[produk] = qtySekarang - 1;
      }
    });
  }

  void _resetKeranjang() {
    setState(() => _keranjang.clear());
  }

  void _prosesPayment() {
    if (_keranjang.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Keranjang masih kosong')),
      );
      return;
    }
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => _PaymentSheet(
        total: _total,
        keranjang: _keranjang,
        onBerhasil: _resetKeranjang,
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ProdukProvider>().muatData();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          // Daftar produk
          Expanded(
            child: Consumer<ProdukProvider>(
              builder: (context, provider, child) {
                if (provider.daftarProduk.isEmpty) {
                  return const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.shopping_bag_outlined, size: 64, color: Colors.grey),
                        SizedBox(height: 16),
                        Text('Belum ada produk di inventory',
                            style: TextStyle(color: Colors.grey)),
                      ],
                    ),
                  );
                }

                final filtered = provider.daftarProduk
                    .where((p) => p.nama.toLowerCase().contains(_keyword))
                    .toList();

                return Column(
                  children: [
                    // Search bar
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
                      child: TextField(
                        controller: _searchController,
                        decoration: InputDecoration(
                          hintText: 'Cari produk...',
                          prefixIcon: const Icon(Icons.search),
                          suffixIcon: _keyword.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear),
                                  onPressed: () {
                                    _searchController.clear();
                                    setState(() => _keyword = '');
                                  },
                                )
                              : null,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          contentPadding: const EdgeInsets.symmetric(vertical: 0),
                        ),
                        onChanged: (val) =>
                            setState(() => _keyword = val.toLowerCase()),
                      ),
                    ),

                    // Grid produk
                    Expanded(
                      child: filtered.isEmpty
                          ? Center(
                              child: Text(
                                'Produk "$_keyword" tidak ditemukan',
                                style: const TextStyle(color: Colors.grey),
                              ),
                            )
                          : GridView.builder(
                              padding: const EdgeInsets.all(12),
                              gridDelegate:
                                  const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 2,
                                crossAxisSpacing: 10,
                                mainAxisSpacing: 10,
                                childAspectRatio: 0.68,
                              ),
                              itemCount: filtered.length,
                              itemBuilder: (context, index) {
                                final produk = filtered[index];
                                final qty = _qtyDiKeranjang(produk);
                                final habis = produk.stok == 0;

                                return Card(
                                  clipBehavior: Clip.antiAlias,
                                  elevation: 2,
                                  color: habis ? Colors.grey[100] : Colors.white,
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.stretch,
                                    children: [
                                      // Foto produk besar di atas
                                      Stack(
                                        children: [
                                          FotoProduk(
                                            fotoPath: produk.fotoPath,
                                            width: double.infinity,
                                            height: 110,
                                            borderRadius: 0,
                                          ),
                                          if (habis)
                                            Positioned.fill(
                                              child: Container(
                                                color: Colors.black.withOpacity(0.35),
                                                alignment: Alignment.center,
                                                child: Container(
                                                  padding: const EdgeInsets.symmetric(
                                                      horizontal: 10, vertical: 4),
                                                  decoration: BoxDecoration(
                                                    color: Colors.grey[300],
                                                    borderRadius:
                                                        BorderRadius.circular(6),
                                                  ),
                                                  child: const Text('Habis',
                                                      style: TextStyle(fontSize: 12)),
                                                ),
                                              ),
                                            ),
                                        ],
                                      ),

                                      // Info produk & kontrol keranjang
                                      Expanded(
                                        child: Padding(
                                          padding: const EdgeInsets.fromLTRB(
                                              10, 8, 10, 10),
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            mainAxisAlignment:
                                                MainAxisAlignment.spaceBetween,
                                            children: [
                                              Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    produk.nama,
                                                    style: const TextStyle(
                                                        fontWeight: FontWeight.bold,
                                                        fontSize: 14.5),
                                                    maxLines: 2,
                                                    overflow: TextOverflow.ellipsis,
                                                  ),
                                                  const SizedBox(height: 3),
                                                  Text(
                                                    'Rp ${_formatAngka(produk.hargaJual)}',
                                                    style: TextStyle(
                                                      color: Theme.of(context)
                                                          .primaryColor,
                                                      fontWeight: FontWeight.bold,
                                                      fontSize: 15,
                                                    ),
                                                  ),
                                                  const SizedBox(height: 2),
                                                  Text(
                                                    'Stok: ${produk.stok}',
                                                    style: TextStyle(
                                                      fontSize: 11.5,
                                                      color: produk.stok <= 3
                                                          ? Colors.red
                                                          : Colors.grey,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              const SizedBox(height: 8),
                                              habis
                                                  ? const SizedBox(height: 32)
                                                  : qty == 0
                                                      ? SizedBox(
                                                          width: double.infinity,
                                                          height: 32,
                                                          child: ElevatedButton(
                                                            onPressed: () =>
                                                                _tambahKeKeranjang(
                                                                    produk),
                                                            style: ElevatedButton
                                                                .styleFrom(
                                                              padding:
                                                                  EdgeInsets.zero,
                                                              backgroundColor:
                                                                  Theme.of(context)
                                                                      .primaryColor,
                                                            ),
                                                            child: const Text('+ Tambah',
                                                                style: TextStyle(
                                                                    color: Colors
                                                                        .white,
                                                                    fontSize: 13)),
                                                          ),
                                                        )
                                                      : Row(
                                                          mainAxisAlignment:
                                                              MainAxisAlignment
                                                                  .spaceBetween,
                                                          children: [
                                                            _tombolBulat(
                                                              icon: Icons.remove,
                                                              onTap: () =>
                                                                  _kurangiDariKeranjang(
                                                                      produk),
                                                            ),
                                                            Text('$qty',
                                                                style: const TextStyle(
                                                                    fontWeight:
                                                                        FontWeight
                                                                            .bold,
                                                                    fontSize: 16)),
                                                            _tombolBulat(
                                                              icon: Icons.add,
                                                              onTap: () =>
                                                                  _tambahKeKeranjang(
                                                                      produk),
                                                            ),
                                                          ],
                                                        ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                    ),
                  ],
                );
              },
            ),
          ),

          // Ringkasan total + tombol bayar
          if (_keranjang.isNotEmpty)
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 8,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${_keranjang.values.fold(0, (a, b) => a + b)} item',
                          style: const TextStyle(
                              color: Colors.grey, fontSize: 12),
                        ),
                        Text(
                          'Total: Rp ${_formatAngka(_total)}',
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                      ],
                    ),
                  ),
                  ElevatedButton.icon(
                    onPressed: _prosesPayment,
                    icon: const Icon(Icons.payment, color: Colors.white),
                    label: const Text('Bayar',
                        style:
                            TextStyle(color: Colors.white, fontSize: 16)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 24, vertical: 12),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _tombolBulat(
      {required IconData icon, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: Theme.of(context).primaryColor,
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: Colors.white, size: 16),
      ),
    );
  }

  String _formatAngka(double angka) {
    return angka.toStringAsFixed(0).replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (m) => '${m[1]}.',
        );
  }
}

// ─── Bottom Sheet Pembayaran ─────────────────────────────────────────────────

// Formatter: otomatis menambahkan pemisah titik ribuan saat mengetik angka
class _RupiahInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    // Ambil digit saja (buang titik/karakter lain)
    String digitsOnly = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');

    if (digitsOnly.isEmpty) {
      return const TextEditingValue(text: '');
    }

    // Buang angka nol berlebih di depan
    digitsOnly = digitsOnly.replaceFirst(RegExp(r'^0+(?=\d)'), '');

    // Tambahkan titik sebagai pemisah ribuan
    final formatted = digitsOnly.replaceAllMapped(
      RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
      (m) => '${m[1]}.',
    );

    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}

class _PaymentSheet extends StatefulWidget {
  final double total;
  final Map<Produk, int> keranjang;
  final VoidCallback onBerhasil;

  const _PaymentSheet({
    required this.total,
    required this.keranjang,
    required this.onBerhasil,
  });

  @override
  State<_PaymentSheet> createState() => _PaymentSheetState();
}

class _PaymentSheetState extends State<_PaymentSheet> {
  final _bayarController = TextEditingController();
  double _kembalian = 0;
  bool _sudahHitung = false;
  bool _loading = false;

  String _formatAngka(double angka) {
    return angka.toStringAsFixed(0).replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (m) => '${m[1]}.',
        );
  }

  // Ambil nilai numerik bersih dari input (buang titik pemisah ribuan)
  double? _ambilNilaiBayar() {
    final raw = _bayarController.text.replaceAll('.', '').trim();
    if (raw.isEmpty) return null;
    return double.tryParse(raw);
  }

  void _hitung() {
    final diterima = _ambilNilaiBayar();
    if (diterima == null || diterima < widget.total) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Uang tidak cukup')),
      );
      return;
    }
    setState(() {
      _kembalian = diterima - widget.total;
      _sudahHitung = true;
    });
  }

  Future<void> _selesaikan() async {
    if (!_sudahHitung) {
      _hitung();
      return;
    }

    setState(() => _loading = true);

    final diterima = _ambilNilaiBayar() ?? 0;

    try {
      final repo = TransaksiRepository();
      final transaksi = Transaksi(
        tanggal: DateTime.now().toIso8601String(),
        totalBayar: widget.total,
        totalDiterima: diterima,
        kembalian: _kembalian,
      );

      final items = widget.keranjang.entries.map((e) {
        return TransaksiItem(
          transaksiId: 0,
          produkId: e.key.id!,
          namaProduk: e.key.nama,
          hargaJual: e.key.hargaJual,
          hargaBeli: e.key.hargaBeli,
          qty: e.value,
          subtotal: e.key.hargaJual * e.value,
        );
      }).toList();

      final transaksiId = await repo.simpanTransaksi(
        transaksi: transaksi,
        items: items,
      );

      if (mounted) {
  context.read<ProdukProvider>().muatData();
  context.read<LaporanProvider>().muatData();
  Navigator.pop(context);
        widget.onBerhasil();

        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => StrukScreen(
              transaksiId: transaksiId,
              items: items,
              total: widget.total,
              diterima: diterima,
              kembalian: _kembalian,
              tanggal: transaksi.tanggal,
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('Pembayaran',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          ...widget.keranjang.entries.map((e) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('${e.key.nama} x${e.value}'),
                    Text('Rp ${_formatAngka(e.key.hargaJual * e.value)}'),
                  ],
                ),
              )),
          const Divider(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Total',
                  style:
                      TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              Text('Rp ${_formatAngka(widget.total)}',
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 16)),
            ],
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _bayarController,
            keyboardType: TextInputType.number,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              _RupiahInputFormatter(),
            ],
            decoration: const InputDecoration(
              labelText: 'Uang Diterima',
              border: OutlineInputBorder(),
              prefixText: 'Rp ',
              prefixIcon: Icon(Icons.payments),
            ),
            onChanged: (_) => setState(() => _sudahHitung = false),
          ),
          const SizedBox(height: 12),
          if (_sudahHitung)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.green[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.green),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Kembalian',
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.green)),
                  Text('Rp ${_formatAngka(_kembalian)}',
                      style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.green,
                          fontSize: 18)),
                ],
              ),
            ),
          const SizedBox(height: 12),
          ElevatedButton.icon(
            onPressed: _loading ? null : _selesaikan,
            icon: _loading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 2))
                : const Icon(Icons.check_circle, color: Colors.white),
            label: Text(
              _sudahHitung ? 'Selesaikan Transaksi' : 'Hitung Kembalian',
              style: const TextStyle(color: Colors.white, fontSize: 16),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor:
                  _sudahHitung ? Colors.green : Colors.blue,
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Halaman Struk ───────────────────────────────────────────────────────────

class StrukScreen extends StatefulWidget {
  final int transaksiId;
  final List<TransaksiItem> items;
  final double total;
  final double diterima;
  final double kembalian;
  final String tanggal;

  const StrukScreen({
    super.key,
    required this.transaksiId,
    required this.items,
    required this.total,
    required this.diterima,
    required this.kembalian,
    required this.tanggal,
  });

  @override
  State<StrukScreen> createState() => _StrukScreenState();
}

class _StrukScreenState extends State<StrukScreen> {
  bool _mencetak = false;

  String _formatAngka(double angka) {
    return angka.toStringAsFixed(0).replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (m) => '${m[1]}.',
        );
  }

  String _formatTanggal(String iso) {
    final dt = DateTime.parse(iso);
    return '${dt.day.toString().padLeft(2, '0')}/'
        '${dt.month.toString().padLeft(2, '0')}/'
        '${dt.year} '
        '${dt.hour.toString().padLeft(2, '0')}:'
        '${dt.minute.toString().padLeft(2, '0')}';
  }

  Future<void> _cetak() async {
    setState(() => _mencetak = true);
    try {
      // Coba sambung otomatis ke printer yang terakhir dipakai.
      var tersambung = await PrinterService.instance.sambungkanOtomatis();

      // Kalau belum ada printer tersimpan / gagal, minta pilih dulu.
      if (!tersambung) {
        if (!mounted) return;
        tersambung = await tampilkanDialogPilihPrinter(context);
      }

      if (!tersambung) return;

      await PrinterService.instance.cetakStruk(
        transaksiId: widget.transaksiId,
        items: widget.items,
        total: widget.total,
        diterima: widget.diterima,
        kembalian: widget.kembalian,
        tanggal: widget.tanggal,
        namaToko: 'UD. VIA JAYA',
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Struk berhasil dicetak')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal mencetak: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _mencetak = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final transaksiId = widget.transaksiId;
    final items = widget.items;
    final total = widget.total;
    final diterima = widget.diterima;
    final kembalian = widget.kembalian;
    final tanggal = widget.tanggal;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Struk Pembayaran'),
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            tooltip: 'Pilih printer',
            icon: const Icon(Icons.bluetooth),
            onPressed: () => tampilkanDialogPilihPrinter(context),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const Text(
              'UD. VIA JAYA',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 2),
            const Text(
              'Terima kasih telah berbelanja',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 20),
            const Icon(Icons.check_circle, color: Colors.green, size: 64),
            const SizedBox(height: 8),
            const Text('Transaksi Berhasil',
                style: TextStyle(
                    fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text(_formatTanggal(tanggal),
                style: const TextStyle(color: Colors.grey)),
            Text('No. #$transaksiId',
                style: const TextStyle(color: Colors.grey)),
            const SizedBox(height: 24),
            const Divider(),
            ...items.map((item) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                          child: Text('${item.namaProduk} x${item.qty}')),
                      Text('Rp ${_formatAngka(item.subtotal)}'),
                    ],
                  ),
                )),
            const Divider(),
            const SizedBox(height: 8),
            _barisStruk('Total', 'Rp ${_formatAngka(total)}', bold: true),
            const SizedBox(height: 4),
            _barisStruk('Dibayar', 'Rp ${_formatAngka(diterima)}'),
            const SizedBox(height: 4),
            _barisStruk('Kembalian', 'Rp ${_formatAngka(kembalian)}',
                color: Colors.green),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _mencetak ? null : _cetak,
                icon: _mencetak
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.print),
                label: Text(_mencetak ? 'Mencetak...' : 'Cetak Struk'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () =>
                    Navigator.popUntil(context, (route) => route.isFirst),
                icon: const Icon(Icons.home, color: Colors.white),
                label: const Text('Kembali ke Kasir',
                    style: TextStyle(color: Colors.white)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).primaryColor,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _barisStruk(String label, String nilai,
      {bool bold = false, Color? color}) {
    final style = TextStyle(
      fontWeight: bold ? FontWeight.bold : FontWeight.normal,
      fontSize: bold ? 16 : 14,
      color: color,
    );
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: style),
        Text(nilai, style: style),
      ],
    );
  }
}