import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../providers/laporan_provider.dart';
import '../models/transaksi.dart';
import '../services/password_service.dart';



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

        return Container(
          color: Colors.grey[100],
          child: Column(
            children: [
              _buildHeaderAksi(context, provider),
              _buildRingkasanTotal(provider, data),
              _buildProdukTerlarisRingkas(provider),
              Expanded(child: _buildTabRiwayat(provider, data)),
            ],
          ),
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
      padding: const EdgeInsets.fromLTRB(16, 14, 10, 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(Icons.bar_chart_rounded, color: Colors.grey[800], size: 20),
              const SizedBox(width: 6),
              const Text(
                'Ringkasan Penjualan',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.black87),
              ),
            ],
          ),
          TextButton.icon(
            onPressed: provider.semuaTransaksi.isEmpty
                ? null
                : () => _konfirmasiHapusSemua(context),
            style: TextButton.styleFrom(
              foregroundColor: Colors.red,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            icon: const Icon(Icons.delete_sweep_outlined, size: 18),
            label: const Text('Hapus Riwayat', style: TextStyle(fontSize: 12.5)),
          ),
        ],
      ),
    );
  }

  void _konfirmasiHapusSemua(BuildContext context) {
    final passwordController = TextEditingController();
    bool obscure = true;
    String? errorText;

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) {
          Future<void> prosesHapus() async {
            final passwordBenar = await PasswordService.instance
                .verifikasiPasswordHapusRiwayat(passwordController.text);
            if (!passwordBenar) {
              setDialogState(() => errorText = 'Password salah');
              return;
            }
            await context.read<LaporanProvider>().hapusSemuaRiwayat();
            if (dialogContext.mounted) {
              Navigator.pop(dialogContext);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Semua riwayat laporan berhasil dihapus')),
              );
            }
          }

          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.red[50],
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.warning_amber_rounded, color: Colors.red),
                ),
                const SizedBox(width: 10),
                const Expanded(child: Text('Hapus Semua Riwayat', style: TextStyle(fontSize: 16.5))),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Semua data riwayat transaksi dan laporan (harian, bulanan, tahunan) akan dihapus permanen.\n\n'
                  'Catatan: stok produk yang sudah terjual TIDAK akan dikembalikan otomatis.\n\n'
                  'Tindakan ini tidak bisa dibatalkan. Masukkan password untuk melanjutkan.',
                  style: TextStyle(fontSize: 13, color: Colors.grey[700], height: 1.4),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: passwordController,
                  obscureText: obscure,
                  autofocus: true,
                  keyboardType: TextInputType.number,
                  onSubmitted: (_) => prosesHapus(),
                  onChanged: (_) {
                    if (errorText != null) {
                      setDialogState(() => errorText = null);
                    }
                  },
                  decoration: InputDecoration(
                    labelText: 'Password',
                    errorText: errorText,
                    filled: true,
                    fillColor: Colors.grey[50],
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey[300]!),
                    ),
                    isDense: true,
                    suffixIcon: IconButton(
                      icon: Icon(obscure ? Icons.visibility_off : Icons.visibility, size: 20),
                      onPressed: () => setDialogState(() => obscure = !obscure),
                    ),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Batal'),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: prosesHapus,
                child: const Text('Hapus', style: TextStyle(color: Colors.white)),
              ),
            ],
          );
        },
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
      padding: const EdgeInsets.fromLTRB(14, 6, 14, 0),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.event_note, size: 13, color: Colors.grey[500]),
                  const SizedBox(width: 4),
                  Text(
                    'Periode: ${_labelPeriodeRiwayat()}',
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _statTotal(
                      icon: Icons.shopping_bag_rounded,
                      iconColor: Colors.indigo,
                      iconBg: Colors.indigo[50]!,
                      label: 'Item Terjual',
                      value: '$totalItem',
                    ),
                  ),
                  _pemisahVertikal(),
                  Expanded(
                    child: _statTotal(
                      icon: Icons.payments_rounded,
                      iconColor: Colors.blue[700]!,
                      iconBg: Colors.blue[50]!,
                      label: 'Pendapatan',
                      value: 'Rp ${_formatRupiah(totalPendapatan)}',
                    ),
                  ),
                  _pemisahVertikal(),
                  Expanded(
                    child: _statTotal(
                      icon: Icons.trending_up_rounded,
                      iconColor: Colors.green[700]!,
                      iconBg: Colors.green[50]!,
                      label: 'Keuntungan',
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
    return Container(width: 1, height: 46, color: Colors.grey[200]);
  }

  Widget _statTotal({
    required IconData icon,
    required Color iconColor,
    required Color iconBg,
    required String label,
    required String value,
    Color? valueColor,
  }) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(color: iconBg, shape: BoxShape.circle),
          child: Icon(icon, color: iconColor, size: 18),
        ),
        const SizedBox(height: 6),
        Text(
          value,
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 12.5,
            color: valueColor ?? Colors.black87,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 10.5, color: Colors.grey[500]),
        ),
      ],
    );
  }

  // ─── Ringkasan produk paling laku (all-time, top 3) ──────

  Widget _buildProdukTerlarisRingkas(LaporanProvider provider) {
    final data = provider.produkTerlaris(limit: 3);
    if (data.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 4),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.amber[50]!, Colors.orange[50]!],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.amber[100]!),
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.emoji_events_rounded, color: Colors.amber[800], size: 19),
                  const SizedBox(width: 6),
                  Text(
                    'Produk Paling Laku',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5, color: Colors.grey[800]),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              ...List.generate(data.length, (i) {
                final item = data[i];
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      _medali(i),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          item.namaProduk,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          '${item.totalQty} terjual',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey[700],
                            fontWeight: FontWeight.w600,
                          ),
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
    return Container(
      width: 26,
      height: 26,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: index < 3 ? warna[index] : Colors.grey[300],
        boxShadow: [
          BoxShadow(
            color: (index < 3 ? warna[index] : Colors.grey).withOpacity(0.4),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Center(
        child: Text(
          '${index + 1}',
          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.black87),
        ),
      ),
    );
  }

  // ─── Tab Riwayat (daftar transaksi individual + filter) ──

  Widget _buildTabRiwayat(LaporanProvider provider, List<Transaksi> data) {
    final totalPendapatan = data.fold(0.0, (sum, t) => sum + t.totalBayar);

    return Column(
      children: [
        const SizedBox(height: 4),
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 6, 14, 4),
          child: InkWell(
            onTap: _pilihRentangTanggal,
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: Colors.blueGrey[50],
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.date_range, size: 16, color: Colors.blueGrey),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            _labelPeriodeRiwayat(),
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(Icons.edit_calendar, size: 17, color: Colors.grey[400]),
                ],
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 4, 14, 4),
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
          padding: const EdgeInsets.fromLTRB(16, 10, 8, 6),
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
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                icon: _sedangCetak
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.picture_as_pdf_outlined, size: 18),
                label: const Text('Cetak / PDF', style: TextStyle(fontSize: 12.5)),
              ),
            ],
          ),
        ),
        Expanded(
          child: data.isEmpty
              ? _kosong('Belum ada transaksi pada periode ini')
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(14, 0, 14, 16),
                  itemCount: data.length,
                  itemBuilder: (context, i) {
                    final t = data[i];
                    final itemsTransaksi = provider.itemUntukTransaksi(t.id!);
                    final jumlahItem = itemsTransaksi.fold<int>(0, (sum, it) => sum + it.qty);
                    final tanggal = DateTime.parse(t.tanggal);
                    final namaBarang = itemsTransaksi
                        .map((it) => '${it.namaProduk} x${it.qty}')
                        .join(', ');

                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.04),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(9),
                            decoration: BoxDecoration(
                              color: Colors.blueGrey[50],
                              shape: BoxShape.circle,
                            ),
                            child: Icon(Icons.receipt_long, color: Colors.blueGrey[600], size: 18),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${_formatTanggalPanjang(tanggal)}, ${_formatWaktu(tanggal)}',
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  namaBarang.isEmpty ? '-' : namaBarang,
                                  style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                                ),
                                const SizedBox(height: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: Colors.grey[100],
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    '$jumlahItem item terjual',
                                    style: TextStyle(fontSize: 11, color: Colors.grey[600], fontWeight: FontWeight.w600),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Rp ${_formatRupiah(t.totalBayar)}',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5),
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
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: Colors.grey[300]!),
      ),
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
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(color: Colors.grey[200], shape: BoxShape.circle),
            child: Icon(Icons.receipt_long_outlined, size: 42, color: Colors.grey[500]),
          ),
          const SizedBox(height: 16),
          Text(pesan, style: TextStyle(color: Colors.grey[600], fontSize: 13)),
        ],
      ),
    );
  }
}
