import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../providers/laporan_provider.dart';
import '../models/transaksi.dart';

class LaporanScreen extends StatefulWidget {
  const LaporanScreen({super.key});

  @override
  State<LaporanScreen> createState() => _LaporanScreenState();
}

class _LaporanScreenState extends State<LaporanScreen> {
  // ─── State untuk tab Riwayat: rentang tanggal bebas ──────
  DateTime _rentangDari = DateTime.now();
  DateTime _rentangSampai = DateTime.now();

  bool _sedangCetak = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<LaporanProvider>().muatData();
    });
  }

  String _formatRupiah(double angka) {
    final negatif = angka < 0;
    final absStr = angka.abs().toStringAsFixed(0).replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (m) => '${m[1]}.',
        );
    return negatif ? '-$absStr' : absStr;
  }

  String _formatTanggalPanjang(DateTime d) {
    const namaHari = ['Senin', 'Selasa', 'Rabu', 'Kamis', 'Jumat', 'Sabtu', 'Minggu'];
    return '${namaHari[d.weekday - 1]}, ${d.day} ${LaporanProvider.namaBulan[d.month - 1]} ${d.year}';
  }

  String _formatWaktu(DateTime d) {
    return '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<LaporanProvider>(
      builder: (context, provider, child) {
        if (provider.isLoading && provider.semuaTransaksi.isEmpty) {
          return const Center(child: CircularProgressIndicator());
        }

        final data = _riwayatTerfilter(provider);

        return Column(
          children: [
            _buildHeaderAksi(context, provider),
            _buildRingkasanTotal(provider, data),
            _buildProdukTerlarisRingkas(provider),
            const Divider(height: 1),
            Expanded(child: _buildTabRiwayat(provider, data)),
          ],
        );
      },
    );
  }

  // Ambil daftar transaksi sesuai rentang tanggal yang dipilih.
  List<Transaksi> _riwayatTerfilter(LaporanProvider provider) {
    final data = provider.riwayatRentang(_rentangDari, _rentangSampai);
    return [...data]..sort((a, b) => b.tanggal.compareTo(a.tanggal));
  }

  void _setRentang(DateTime dari, DateTime sampai) {
    setState(() {
      _rentangDari = dari;
      _rentangSampai = sampai;
    });
  }

  Future<void> _pilihRentangTanggal() async {
    final now = DateTime.now();
    final hasil = await showDateRangePicker(
      context: context,
      initialDateRange: DateTimeRange(start: _rentangDari, end: _rentangSampai),
      firstDate: DateTime(2020, 1, 1),
      lastDate: now,
      helpText: 'Pilih Rentang Tanggal',
      saveText: 'Pilih',
    );
    if (hasil != null) {
      _setRentang(hasil.start, hasil.end);
    }
  }

  // ─── Header: judul + tombol hapus riwayat ────────────────

  Widget _buildHeaderAksi(BuildContext context, LaporanProvider provider) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 4, 0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text(
            'Ringkasan Penjualan',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.grey),
          ),
          TextButton.icon(
            onPressed: provider.semuaTransaksi.isEmpty
                ? null
                : () => _konfirmasiHapusSemua(context),
            icon: const Icon(Icons.delete_sweep, size: 18, color: Colors.red),
            label: const Text('Hapus Riwayat', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _konfirmasiHapusSemua(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning_amber, color: Colors.red),
            SizedBox(width: 8),
            Text('Hapus Semua Riwayat'),
          ],
        ),
        content: const Text(
          'Semua data riwayat transaksi dan laporan (harian, bulanan, tahunan) akan dihapus permanen.\n\n'
          'Catatan: stok produk yang sudah terjual TIDAK akan dikembalikan otomatis.\n\n'
          'Tindakan ini tidak bisa dibatalkan. Lanjutkan?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              await context.read<LaporanProvider>().hapusSemuaRiwayat();
              if (dialogContext.mounted) {
                Navigator.pop(dialogContext);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Semua riwayat laporan berhasil dihapus')),
                );
              }
            },
            child: const Text('Hapus', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

 

  // ─── Kartu ringkasan total keseluruhan (item terjual, pendapatan, keuntungan) ────

  Widget _buildRingkasanTotal(LaporanProvider provider, List<Transaksi> data) {
    final itemsFiltered = data.expand((t) => provider.itemUntukTransaksi(t.id!));
    final totalItem = itemsFiltered.fold<int>(0, (sum, it) => sum + it.qty);
    final totalPendapatan = data.fold<double>(0, (sum, t) => sum + t.totalBayar);
    final totalKeuntungan = itemsFiltered.fold<double>(
        0, (sum, it) => sum + (it.hargaJual - it.hargaBeli) * it.qty);

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      child: Card(
        elevation: 0,
        color: Colors.grey[50],
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: BorderSide(color: Colors.grey[300]!),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
          child: Column(
            children: [
              Text(
                'Periode: ${_labelPeriodeRiwayat()}',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[600],
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: _statTotal(
                      icon: Icons.shopping_bag_outlined,
                      iconColor: Colors.indigo,
                      label: 'Item Terjual',
                      value: '$totalItem',
                    ),
                  ),
                  _pemisahVertikal(),
                  Expanded(
                    child: _statTotal(
                      icon: Icons.payments_outlined,
                      iconColor: Colors.blue,
                      label: 'Total Pendapatan',
                      value: 'Rp ${_formatRupiah(totalPendapatan)}',
                    ),
                  ),
                  _pemisahVertikal(),
                  Expanded(
                    child: _statTotal(
                      icon: Icons.trending_up,
                      iconColor: Colors.green,
                      label: 'Total Keuntungan',
                      value: 'Rp ${_formatRupiah(totalKeuntungan)}',
                      valueColor: Colors.green[700],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _pemisahVertikal() {
    return Container(width: 1, height: 44, color: Colors.grey[300]);
  }

  Widget _statTotal({
    required IconData icon,
    required Color iconColor,
    required String label,
    required String value,
    Color? valueColor,
  }) {
    return Column(
      children: [
        Icon(icon, color: iconColor, size: 20),
        const SizedBox(height: 4),
        Text(
          value,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 13,
            color: valueColor,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 11, color: Colors.grey),
        ),
      ],
    );
  }

  // ─── Ringkasan produk paling laku (all-time, top 3) ──────

  Widget _buildProdukTerlarisRingkas(LaporanProvider provider) {
    final data = provider.produkTerlaris(limit: 3);
    if (data.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
      child: Card(
        elevation: 0,
        color: Colors.amber[50],
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: BorderSide(color: Colors.amber[100]!),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.emoji_events, color: Colors.amber[800], size: 18),
                  const SizedBox(width: 6),
                  const Text(
                    'Produk Paling Laku',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ...List.generate(data.length, (i) {
                final item = data[i];
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: Row(
                    children: [
                      _medali(i),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          item.namaProduk,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 13),
                        ),
                      ),
                      Text(
                        '${item.totalQty} terjual',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[700],
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ],
          ),
        ),
      ),
    );
  }

  Widget _medali(int index) {
    const warna = [Color(0xFFFFD700), Color(0xFFC0C0C0), Color(0xFFCD7F32)];
    return CircleAvatar(
      radius: 10,
      backgroundColor: index < 3 ? warna[index] : Colors.grey[300],
      child: Text(
        '${index + 1}',
        style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.black87),
      ),
    );
  }

  // ─── Tab Riwayat (daftar transaksi individual + filter) ──

  Widget _buildTabRiwayat(LaporanProvider provider, List<Transaksi> data) {
    final totalPendapatan = data.fold(0.0, (sum, t) => sum + t.totalBayar);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
          child: InkWell(
            onTap: _pilihRentangTanggal,
            borderRadius: BorderRadius.circular(10),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey[300]!),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        const Icon(Icons.date_range, size: 18, color: Colors.blueGrey),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _labelPeriodeRiwayat(),
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.edit_calendar, size: 18, color: Colors.grey),
                ],
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 4, 12, 4),
          child: Wrap(
            spacing: 6,
            runSpacing: 4,
            children: [
              _chipPreset('Hari Ini', () {
                final now = DateTime.now();
                _setRentang(now, now);
              }),
              _chipPreset('7 Hari', () {
                final now = DateTime.now();
                _setRentang(now.subtract(const Duration(days: 6)), now);
              }),
              _chipPreset('Bulan Ini', () {
                final now = DateTime.now();
                _setRentang(DateTime(now.year, now.month, 1), now);
              }),
              _chipPreset('Tahun Ini', () {
                final now = DateTime.now();
                _setRentang(DateTime(now.year, 1, 1), now);
              }),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  data.isEmpty
                      ? 'Belum ada transaksi'
                      : '${data.length} transaksi  •  Rp ${_formatRupiah(totalPendapatan)}',
                  style: TextStyle(color: Colors.grey[700], fontWeight: FontWeight.w600, fontSize: 12.5),
                ),
              ),
              TextButton.icon(
                onPressed: (data.isEmpty || _sedangCetak)
                    ? null
                    : () => _cetakRiwayatPdf(provider, data),
                icon: _sedangCetak
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.picture_as_pdf_outlined, size: 18),
                label: const Text('Cetak / PDF'),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: data.isEmpty
              ? _kosong('Belum ada transaksi pada periode ini')
              : ListView.separated(
                  padding: const EdgeInsets.all(12),
                  itemCount: data.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, i) {
                    final t = data[i];
                    final itemsTransaksi = provider.itemUntukTransaksi(t.id!);
                    final jumlahItem = itemsTransaksi.fold<int>(0, (sum, it) => sum + it.qty);
                    final tanggal = DateTime.parse(t.tanggal);
                    final namaBarang = itemsTransaksi
                        .map((it) => '${it.namaProduk} x${it.qty}')
                        .join(', ');

                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const CircleAvatar(
                            backgroundColor: Colors.blueGrey,
                            child: Icon(Icons.receipt, color: Colors.white, size: 18),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${_formatTanggalPanjang(tanggal)}, ${_formatWaktu(tanggal)}',
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  namaBarang.isEmpty ? '-' : namaBarang,
                                  style: TextStyle(fontSize: 12.5, color: Colors.grey[700]),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '$jumlahItem item terjual',
                                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Rp ${_formatRupiah(t.totalBayar)}',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  // ─── Cetak / Simpan PDF Riwayat Penjualan ────────────────

  String _labelPeriodeRiwayat() {
    final sama = _rentangDari.year == _rentangSampai.year &&
        _rentangDari.month == _rentangSampai.month &&
        _rentangDari.day == _rentangSampai.day;
    if (sama) return _formatTanggalPanjang(_rentangDari);
    return '${_formatTanggalSingkat(_rentangDari)}  —  ${_formatTanggalSingkat(_rentangSampai)}';
  }

  String _formatTanggalSingkat(DateTime d) {
    return '${d.day} ${LaporanProvider.namaBulan[d.month - 1]} ${d.year}';
  }

  Future<void> _cetakRiwayatPdf(
      LaporanProvider provider, List<Transaksi> data) async {
    setState(() => _sedangCetak = true);
    try {
      final pdf = pw.Document();
      final totalPendapatan = data.fold(0.0, (sum, t) => sum + t.totalBayar);
      final periode = _labelPeriodeRiwayat();
      final dicetakPada = DateTime.now();

      final rows = data.map((t) {
        final items = provider.itemUntukTransaksi(t.id!);
        final namaBarang =
            items.map((it) => '${it.namaProduk} x${it.qty}').join(', ');
        final jumlahItem = items.fold<int>(0, (sum, it) => sum + it.qty);
        final tanggal = DateTime.parse(t.tanggal);
        return [
          '${_formatTanggalPanjang(tanggal)}\n${_formatWaktu(tanggal)}',
          namaBarang.isEmpty ? '-' : namaBarang,
          '$jumlahItem',
          'Rp ${_formatRupiah(t.totalBayar)}',
        ];
      }).toList();

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(28),
          header: (context) => pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text('Riwayat Penjualan',
                  style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 2),
              pw.Text('Periode: $periode',
                  style: const pw.TextStyle(fontSize: 11)),
              pw.Text(
                'Dicetak: ${_formatTanggalPanjang(dicetakPada)}, ${_formatWaktu(dicetakPada)}',
                style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700),
              ),
              pw.SizedBox(height: 10),
            ],
          ),
          build: (context) => [
            pw.Text(
              '${data.length} transaksi  •  Total Rp ${_formatRupiah(totalPendapatan)}',
              style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 10),
            pw.Table.fromTextArray(
              headers: const ['Tanggal', 'Barang Terjual', 'Jml', 'Total Bayar'],
              data: rows,
              headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9.5),
              cellStyle: const pw.TextStyle(fontSize: 9),
              headerDecoration: const pw.BoxDecoration(color: PdfColors.grey300),
              cellAlignment: pw.Alignment.centerLeft,
              cellAlignments: {2: pw.Alignment.center, 3: pw.Alignment.centerRight},
              columnWidths: {
                0: const pw.FlexColumnWidth(2),
                1: const pw.FlexColumnWidth(3.6),
                2: const pw.FlexColumnWidth(0.8),
                3: const pw.FlexColumnWidth(1.8),
              },
              border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.5),
            ),
          ],
        ),
      );

      if (!mounted) return;
      await Printing.layoutPdf(
        onLayout: (format) async => pdf.save(),
        name: 'riwayat_penjualan.pdf',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal membuat PDF: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _sedangCetak = false);
    }
  }

  Widget _chipPreset(String label, VoidCallback onTap) {
    return ActionChip(
      label: Text(label, style: const TextStyle(fontSize: 12)),
      onPressed: onTap,
      visualDensity: VisualDensity.compact,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
  }

  Widget _kosong(String pesan) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 48),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.bar_chart, size: 64, color: Colors.grey),
          const SizedBox(height: 16),
          Text(pesan, style: const TextStyle(color: Colors.grey)),
        ],
      ),
    );
  }
}