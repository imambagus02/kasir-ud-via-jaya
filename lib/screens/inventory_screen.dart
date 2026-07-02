import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../models/produk.dart';
import '../providers/produk_provider.dart';
import '../services/foto_produk_service.dart';
import '../widgets/foto_produk.dart';

// ─── Formatter angka ribuan (dipakai di list & form) ─────────────────────────

String formatRibuan(num angka) {
  return angka.toStringAsFixed(0).replaceAllMapped(
        RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
        (m) => '${m[1]}.',
      );
}

// Menambahkan titik pemisah ribuan secara otomatis saat mengetik
class RupiahInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    final digitsOnly = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');
    if (digitsOnly.isEmpty) {
      return const TextEditingValue(text: '');
    }
    final formatted = formatRibuan(int.parse(digitsOnly));
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}

// Membuat huruf pertama tiap kata otomatis kapital saat mengetik
class KapitalSetiapKataFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    if (newValue.text.isEmpty) return newValue;

    final teks = newValue.text;
    final buffer = StringBuffer();
    bool awalKata = true;

    for (int i = 0; i < teks.length; i++) {
      final huruf = teks[i];
      if (huruf == ' ') {
        buffer.write(huruf);
        awalKata = true;
      } else if (awalKata) {
        buffer.write(huruf.toUpperCase());
        awalKata = false;
      } else {
        buffer.write(huruf);
      }
    }

    return newValue.copyWith(
      text: buffer.toString(),
      selection: newValue.selection,
    );
  }
}

class InventoryScreen extends StatefulWidget {
  const InventoryScreen({super.key});

  @override
  State<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends State<InventoryScreen> {
  final _searchController = TextEditingController();
  String _keyword = '';
  bool _sedangImpor = false;

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
      backgroundColor: Colors.grey[100],
      body: Column(
        children: [
          // Search bar + tombol import Excel
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 6),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Cari produk...',
                      filled: true,
                      fillColor: Colors.white,
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
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(vertical: 0),
                    ),
                    onChanged: (val) =>
                        setState(() => _keyword = val.toLowerCase()),
                  ),
                ),
                const SizedBox(width: 8),
                Material(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  child: IconButton(
                    tooltip: 'Import dari Excel',
                    onPressed: _sedangImpor ? null : () => _importExcel(context),
                    icon: _sedangImpor
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Icon(Icons.upload_file,
                            color: Theme.of(context).primaryColor),
                  ),
                ),
              ],
            ),
          ),

          // Daftar produk
          Expanded(
            child: Consumer<ProdukProvider>(
              builder: (context, provider, child) {
                final filtered = provider.daftarProduk
                    .where((p) => p.nama.toLowerCase().contains(_keyword))
                    .toList();

                if (filtered.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.inventory_2_outlined,
                            size: 64, color: Colors.grey),
                        const SizedBox(height: 16),
                        Text(
                          _keyword.isEmpty
                              ? 'Belum ada produk'
                              : 'Produk "$_keyword" tidak ditemukan',
                          style: const TextStyle(color: Colors.grey),
                        ),
                        if (_keyword.isEmpty) ...[
                          const SizedBox(height: 8),
                          const Text('Tap + untuk tambah produk',
                              style: TextStyle(color: Colors.grey)),
                        ],
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.fromLTRB(14, 4, 14, 90),
                  itemCount: filtered.length,
                  itemBuilder: (context, index) =>
                      _kartuProduk(context, filtered[index]),
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _bukaFormProduk(context),
        child: const Icon(Icons.add),
      ),
    );
  }

  // ─── Import produk dari Excel ─────────────────────────────────────────────

  Future<void> _importExcel(BuildContext context) async {
    final hasilPilih = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['xlsx'],
    );
    if (hasilPilih == null || hasilPilih.files.single.path == null) return;

    final path = hasilPilih.files.single.path!;
    setState(() => _sedangImpor = true);

    try {
      final hasil = await context.read<ProdukProvider>().importDariExcel(path);
      if (context.mounted) _tampilkanHasilImpor(context, hasil);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal membaca file Excel: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _sedangImpor = false);
    }
  }

  void _tampilkanHasilImpor(BuildContext context, HasilImporProduk hasil) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.upload_file, color: Colors.green),
            SizedBox(width: 8),
            Text('Hasil Import'),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _barisHasil(Icons.check_circle, Colors.green,
                    'Berhasil ditambahkan: ${hasil.berhasil} produk'),
                const SizedBox(height: 6),
                _barisHasil(Icons.info, Colors.orange,
                    'Dilewati (nama sudah ada): ${hasil.duplikat} produk'),
                const SizedBox(height: 6),
                _barisHasil(Icons.error, Colors.red,
                    'Gagal dibaca: ${hasil.gagal} baris'),
                if (hasil.pesanGagal.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  const Text('Detail baris gagal:',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  const SizedBox(height: 6),
                  ...hasil.pesanGagal.map(
                    (p) => Padding(
                      padding: const EdgeInsets.only(bottom: 2),
                      child: Text('• $p',
                          style: TextStyle(fontSize: 12, color: Colors.grey[700])),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Widget _barisHasil(IconData icon, Color warna, String teks) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: warna),
        const SizedBox(width: 8),
        Expanded(child: Text(teks, style: const TextStyle(fontSize: 13.5))),
      ],
    );
  }

  // ─── Kartu produk (didesain ulang lebih rapi) ────────────────────────────

  Widget _kartuProduk(BuildContext context, Produk produk) {
    final stokMenipis = produk.stok <= 3;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
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
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Foto produk (pakai widget FotoProduk yang sudah ada) — diperbesar
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: FotoProduk(fotoPath: produk.fotoPath, size: 84),
          ),
          const SizedBox(width: 14),

          // Info produk
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  produk.nama,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: [
                    _tagInfo(
                      icon: Icons.money,
                      label: 'Modal Rp ${formatRibuan(produk.hargaBeli)}',
                      warna: Colors.grey[700]!,
                      bg: Colors.grey[100]!,
                    ),
                    _tagInfo(
                      icon: Icons.sell,
                      label: 'Jual Rp ${formatRibuan(produk.hargaJual)}',
                      warna: Colors.green[800]!,
                      bg: Colors.green[50]!,
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                _tagInfo(
                  icon: stokMenipis ? Icons.warning_amber : Icons.inventory_2,
                  label: 'Stok: ${produk.stok}',
                  warna: stokMenipis ? Colors.red[800]! : Colors.blue[800]!,
                  bg: stokMenipis ? Colors.red[50]! : Colors.blue[50]!,
                ),
              ],
            ),
          ),

          // Menu aksi (titik tiga, biar tidak penuh)
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, color: Colors.grey),
            onSelected: (value) {
              switch (value) {
                case 'stok':
                  _bukaDialogTambahStok(context, produk);
                  break;
                case 'edit':
                  _bukaFormProduk(context, produk: produk);
                  break;
                case 'hapus':
                  _konfirmasiHapus(context, produk);
                  break;
              }
            },
            itemBuilder: (context) => const [
              PopupMenuItem(
                value: 'stok',
                child: Row(
                  children: [
                    Icon(Icons.add_box, color: Colors.green, size: 20),
                    SizedBox(width: 10),
                    Text('Tambah Stok'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'edit',
                child: Row(
                  children: [
                    Icon(Icons.edit, color: Colors.blue, size: 20),
                    SizedBox(width: 10),
                    Text('Edit Produk'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'hapus',
                child: Row(
                  children: [
                    Icon(Icons.delete, color: Colors.red, size: 20),
                    SizedBox(width: 10),
                    Text('Hapus'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _tagInfo({
    required IconData icon,
    required String label,
    required Color warna,
    required Color bg,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: warna),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(fontSize: 11.5, color: warna, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  void _bukaFormProduk(BuildContext context, {Produk? produk}) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChangeNotifierProvider.value(
          value: context.read<ProdukProvider>(),
          child: FormProdukScreen(produk: produk),
        ),
      ),
    );
  }

  void _bukaDialogTambahStok(BuildContext context, Produk produk) {
    final jumlahController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.add_box, color: Color.fromARGB(255, 159, 223, 12)),
            const SizedBox(width: 8),
            Expanded(
              child: Text('Tambah Stok "${produk.nama}"',
                  overflow: TextOverflow.ellipsis),
            ),
          ],
        ),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Stok saat ini: ${produk.stok}',
                  style: const TextStyle(color: Colors.grey)),
              const SizedBox(height: 12),
              TextFormField(
                controller: jumlahController,
                autofocus: true,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Jumlah Tambahan',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.add),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Jumlah tidak boleh kosong';
                  }
                  final n = int.tryParse(value.trim());
                  if (n == null) return 'Masukkan angka yang valid';
                  if (n <= 0) return 'Jumlah harus lebih dari 0';
                  return null;
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            onPressed: () async {
              if (!formKey.currentState!.validate()) return;
              final tambahan = int.parse(jumlahController.text.trim());

              await context
                  .read<ProdukProvider>()
                  .tambahStok(produk.id!, tambahan);

              if (dialogContext.mounted) Navigator.pop(dialogContext);
            },
            child: const Text('Tambah', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _konfirmasiHapus(BuildContext context, Produk produk) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Hapus Produk'),
        content: Text('Yakin ingin menghapus "${produk.nama}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              await context.read<ProdukProvider>().hapus(produk.id!);
              await FotoProdukService.hapusFoto(produk.fotoPath);
              if (context.mounted) Navigator.pop(context);
            },
            child: const Text('Hapus', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}

// ─── Form Tambah / Edit Produk ───────────────────────────────────────────────

class FormProdukScreen extends StatefulWidget {
  final Produk? produk;
  const FormProdukScreen({super.key, this.produk});

  @override
  State<FormProdukScreen> createState() => _FormProdukScreenState();
}

class _FormProdukScreenState extends State<FormProdukScreen> {
  final _formKey = GlobalKey<FormState>();
  final _namaController = TextEditingController();
  final _hargaBeliController = TextEditingController();
  final _hargaJualController = TextEditingController();
  final _stokController = TextEditingController();

  String? _fotoPath;
  String? _fotoPathAwal; // untuk hapus file lama kalau diganti
  bool _sedangProsesFoto = false;

  bool get isEdit => widget.produk != null;

  @override
  void initState() {
    super.initState();
    if (isEdit) {
      _namaController.text = widget.produk!.nama;
      _hargaBeliController.text = formatRibuan(widget.produk!.hargaBeli);
      _hargaJualController.text = formatRibuan(widget.produk!.hargaJual);
      _stokController.text = widget.produk!.stok.toString();
      _fotoPath = widget.produk!.fotoPath;
      _fotoPathAwal = widget.produk!.fotoPath;
    }
    // Perbarui pratinjau keuntungan secara live saat harga diketik.
    _hargaBeliController.addListener(_refreshPratinjau);
    _hargaJualController.addListener(_refreshPratinjau);
  }

  void _refreshPratinjau() => setState(() {});

  @override
  void dispose() {
    _hargaBeliController.removeListener(_refreshPratinjau);
    _hargaJualController.removeListener(_refreshPratinjau);
    _namaController.dispose();
    _hargaBeliController.dispose();
    _hargaJualController.dispose();
    _stokController.dispose();
    super.dispose();
  }

  // Ambil angka murni dari teks berformat "60.000" -> 60000
  double _angkaMurni(String teks) {
    return double.parse(teks.replaceAll('.', '').trim());
  }

  double? _coba(String teks) {
    final bersih = teks.replaceAll('.', '').trim();
    if (bersih.isEmpty) return null;
    return double.tryParse(bersih);
  }

  Future<void> _pilihFoto() async {
    final sumber = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => SafeArea(
        child: Container(
          margin: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 10),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const SizedBox(height: 8),
              ListTile(
                leading: CircleAvatar(
                  backgroundColor: Theme.of(context).primaryColor.withOpacity(0.1),
                  child: Icon(Icons.photo_camera, color: Theme.of(context).primaryColor),
                ),
                title: const Text('Ambil Foto dari Kamera'),
                onTap: () => Navigator.pop(sheetContext, ImageSource.camera),
              ),
              ListTile(
                leading: CircleAvatar(
                  backgroundColor: Theme.of(context).primaryColor.withOpacity(0.1),
                  child: Icon(Icons.photo_library, color: Theme.of(context).primaryColor),
                ),
                title: const Text('Pilih dari Galeri'),
                onTap: () => Navigator.pop(sheetContext, ImageSource.gallery),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
    if (sumber == null) return;

    setState(() => _sedangProsesFoto = true);
    try {
      final dipilih = sumber == ImageSource.camera
          ? await FotoProdukService.pilihDariKamera()
          : await FotoProdukService.pilihDariGaleri();
      if (dipilih == null) return;

      final pathBaru = await FotoProdukService.simpanPermanen(dipilih);
      setState(() => _fotoPath = pathBaru);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal mengambil foto: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _sedangProsesFoto = false);
    }
  }

  void _hapusFotoDipilih() {
    setState(() => _fotoPath = null);
  }

  Future<void> _simpan() async {
    if (!_formKey.currentState!.validate()) return;

    final provider = context.read<ProdukProvider>();
    final nama = _namaController.text.trim();

    // Cek duplikat nama
    if (provider.cekNamaSudahAda(nama, kecualiId: widget.produk?.id)) {
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.warning_amber, color: Colors.orange),
              SizedBox(width: 8),
              Text('Produk Sudah Ada'),
            ],
          ),
          content: Text(
              '"$nama" sudah ada di daftar produk. Gunakan nama yang berbeda.'),
          actions: [
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK'),
            ),
          ],
        ),
      );
      return;
    }

    final produk = Produk(
      id: widget.produk?.id,
      nama: nama,
      fotoPath: _fotoPath,
      hargaBeli: _angkaMurni(_hargaBeliController.text),
      hargaJual: _angkaMurni(_hargaJualController.text),
      stok: int.parse(_stokController.text.trim()),
    );

    if (isEdit) {
      await provider.update(produk);
    } else {
      await provider.tambah(produk);
    }

    // Kalau foto diganti/dihapus, bersihkan file lama supaya tidak menumpuk.
    if (_fotoPathAwal != null && _fotoPathAwal != _fotoPath) {
      await FotoProdukService.hapusFoto(_fotoPathAwal);
    }

    if (context.mounted) Navigator.pop(context);
  }

  InputDecoration _dekorasiField({
    required String label,
    required IconData icon,
    String? prefixText,
  }) {
    return InputDecoration(
      labelText: label,
      prefixText: prefixText,
      filled: true,
      fillColor: Colors.grey[50],
      prefixIcon: Icon(icon, size: 20),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey[300]!),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey[300]!),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Theme.of(context).primaryColor, width: 1.6),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.red),
      ),
      contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
    );
  }

  Widget _kartuBagian({required String judul, required IconData ikon, required List<Widget> anak}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(ikon, size: 18, color: Theme.of(context).primaryColor),
              const SizedBox(width: 8),
              Text(
                judul,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13.5,
                  color: Colors.grey[800],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ...anak,
        ],
      ),
    );
  }

  Widget _pratinjauKeuntungan() {
    final beli = _coba(_hargaBeliController.text);
    final jual = _coba(_hargaJualController.text);

    if (beli == null || jual == null) return const SizedBox.shrink();

    final untung = jual - beli;
    final margin = beli > 0 ? (untung / beli * 100) : 0.0;
    final positif = untung >= 0;
    final warnaUtama = positif ? Colors.green[700]! : Colors.red[700]!;
    final warnaBg = positif ? Colors.green[50]! : Colors.red[50]!;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      margin: const EdgeInsets.only(top: 16),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: warnaBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: warnaUtama.withOpacity(0.25)),
      ),
      child: Row(
        children: [
          Icon(
            positif ? Icons.trending_up : Icons.trending_down,
            color: warnaUtama,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Keuntungan per item',
                  style: TextStyle(fontSize: 11.5, color: Colors.grey[700]),
                ),
                const SizedBox(height: 2),
                Text(
                  'Rp ${formatRibuan(untung.abs())}${positif ? '' : ' (rugi)'}',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    color: warnaUtama,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              '${margin.toStringAsFixed(0)}%',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5, color: warnaUtama),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final primary = const Color.fromARGB(255, 146, 189, 46); // ← ganti warna menu tambah produk

    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: Text(isEdit ? 'Edit Produk' : 'Tambah Produk'),
        backgroundColor: primary,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── Foto produk ───────────────────────────────
              Center(
                child: GestureDetector(
                  onTap: _sedangProsesFoto ? null : _pilihFoto,
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(3),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            colors: [primary, primary.withOpacity(0.4)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                        ),
                        child: ClipOval(
                          child: SizedBox(
                            width: 128,
                            height: 128,
                            child: _sedangProsesFoto
                                ? Container(
                                    color: Colors.white,
                                    child: const Center(
                                        child: CircularProgressIndicator()),
                                  )
                                : (_fotoPath != null &&
                                        File(_fotoPath!).existsSync())
                                    ? Image.file(File(_fotoPath!), fit: BoxFit.cover)
                                    : Container(
                                        color: Colors.grey[100],
                                        child: Icon(Icons.inventory_2_outlined,
                                            size: 40, color: Colors.grey[400]),
                                      ),
                          ),
                        ),
                      ),
                      Positioned(
                        right: 0,
                        bottom: 2,
                        child: Container(
                          padding: const EdgeInsets.all(7),
                          decoration: BoxDecoration(
                            color: primary,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2.5),
                          ),
                          child: const Icon(Icons.camera_alt,
                              size: 15, color: Colors.white),
                        ),
                      ),
                      if (_fotoPath != null && !_sedangProsesFoto)
                        Positioned(
                          left: -4,
                          top: -4,
                          child: GestureDetector(
                            onTap: _hapusFotoDipilih,
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: const BoxDecoration(
                                color: Colors.red,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.close,
                                  size: 13, color: Colors.white),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Center(
                child: Text(
                  _fotoPath == null
                      ? 'Tap untuk tambah foto (opsional)'
                      : 'Tap untuk ganti foto',
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
              ),
              const SizedBox(height: 22),

              // ── Informasi dasar ───────────────────────────
              _kartuBagian(
                judul: 'Informasi Produk',
                ikon: Icons.info_outline,
                anak: [
                  TextFormField(
                    controller: _namaController,
                    autocorrect: false,
                    enableSuggestions: false,
                    inputFormatters: [KapitalSetiapKataFormatter()],
                    decoration: _dekorasiField(label: 'Nama Barang', icon: Icons.label_outline),
                    validator: (value) => value == null || value.trim().isEmpty
                        ? 'Nama tidak boleh kosong'
                        : null,
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _stokController,
                    decoration: _dekorasiField(label: 'Stok', icon: Icons.inventory),
                    keyboardType: TextInputType.number,
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Stok tidak boleh kosong';
                      }
                      if (int.tryParse(value.trim()) == null) {
                        return 'Masukkan angka yang valid';
                      }
                      return null;
                    },
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // ── Harga ──────────────────────────────────────
              _kartuBagian(
                judul: 'Harga',
                ikon: Icons.payments_outlined,
                anak: [
                  TextFormField(
                    controller: _hargaBeliController,
                    decoration: _dekorasiField(
                      label: 'Harga Asli (Modal)',
                      icon: Icons.money,
                      prefixText: 'Rp ',
                    ),
                    keyboardType: TextInputType.number,
                    inputFormatters: [RupiahInputFormatter()],
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Harga asli tidak boleh kosong';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _hargaJualController,
                    decoration: _dekorasiField(
                      label: 'Harga Jual',
                      icon: Icons.sell_outlined,
                      prefixText: 'Rp ',
                    ),
                    keyboardType: TextInputType.number,
                    inputFormatters: [RupiahInputFormatter()],
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Harga jual tidak boleh kosong';
                      }
                      return null;
                    },
                  ),
                  _pratinjauKeuntungan(),
                ],
              ),
              const SizedBox(height: 26),

              // ── Tombol simpan ─────────────────────────────
              SizedBox(
                height: 52,
                child: ElevatedButton.icon(
                  onPressed: _simpan,
                  icon: Icon(isEdit ? Icons.update : Icons.save, size: 20),
                  label: Text(
                    isEdit ? 'Update Produk' : 'Simpan Produk',
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primary,
                    foregroundColor: Colors.white,
                    elevation: 2,
                    shadowColor: primary.withOpacity(0.4),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}