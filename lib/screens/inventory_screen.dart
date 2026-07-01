import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../models/produk.dart';
import '../providers/produk_provider.dart';
import '../services/foto_produk_service.dart';
import '../widgets/foto_produk.dart';

class InventoryScreen extends StatefulWidget {
  const InventoryScreen({super.key});

  @override
  State<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends State<InventoryScreen> {
  final _searchController = TextEditingController();
  String _keyword = '';

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
              onChanged: (val) => setState(() => _keyword = val.toLowerCase()),
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
                  padding: const EdgeInsets.all(12),
                  itemCount: filtered.length,
                  itemBuilder: (context, index) {
                    final produk = filtered[index];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 10),
                      child: ListTile(
                        leading: FotoProduk(fotoPath: produk.fotoPath, size: 56),
                        title: Text(produk.nama,
                            style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Modal: Rp ${_formatAngka(produk.hargaBeli)}'),
                            Text('Jual: Rp ${_formatAngka(produk.hargaJual)}'),
                            Text(
                              'Stok: ${produk.stok}',
                              style: TextStyle(
                                color: produk.stok <= 3 ? Colors.red : Colors.black87,
                                fontWeight: produk.stok <= 3
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                              ),
                            ),
                          ],
                        ),
                        isThreeLine: true,
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.add_box, color: Colors.green),
                              tooltip: 'Tambah Stok',
                              onPressed: () =>
                                  _bukaDialogTambahStok(context, produk),
                            ),
                            IconButton(
                              icon: const Icon(Icons.edit, color: Colors.blue),
                              onPressed: () =>
                                  _bukaFormProduk(context, produk: produk),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete, color: Colors.red),
                              onPressed: () => _konfirmasiHapus(context, produk),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
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

  String _formatAngka(double angka) {
    return angka.toStringAsFixed(0).replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (m) => '${m[1]}.',
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
            const Icon(Icons.add_box, color: Colors.green),
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
      _hargaBeliController.text = widget.produk!.hargaBeli.toStringAsFixed(0);
      _hargaJualController.text = widget.produk!.hargaJual.toStringAsFixed(0);
      _stokController.text = widget.produk!.stok.toString();
      _fotoPath = widget.produk!.fotoPath;
      _fotoPathAwal = widget.produk!.fotoPath;
    }
  }

  @override
  void dispose() {
    _namaController.dispose();
    _hargaBeliController.dispose();
    _hargaJualController.dispose();
    _stokController.dispose();
    super.dispose();
  }

  Future<void> _pilihFoto() async {
    final sumber = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera),
              title: const Text('Ambil Foto dari Kamera'),
              onTap: () => Navigator.pop(sheetContext, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Pilih dari Galeri'),
              onTap: () => Navigator.pop(sheetContext, ImageSource.gallery),
            ),
          ],
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
      hargaBeli: double.parse(_hargaBeliController.text.trim()),
      hargaJual: double.parse(_hargaJualController.text.trim()),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(isEdit ? 'Edit Produk' : 'Tambah Produk'),
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: GestureDetector(
                  onTap: _sedangProsesFoto ? null : _pilihFoto,
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(14),
                        child: SizedBox(
                          width: 120,
                          height: 120,
                          child: _sedangProsesFoto
                              ? const Center(child: CircularProgressIndicator())
                              : (_fotoPath != null && File(_fotoPath!).existsSync())
                                  ? Image.file(File(_fotoPath!), fit: BoxFit.cover)
                                  : Container(
                                      color: Colors.grey[200],
                                      child: const Icon(Icons.add_a_photo,
                                          size: 32, color: Colors.grey),
                                    ),
                        ),
                      ),
                      if (_fotoPath != null && !_sedangProsesFoto)
                        Positioned(
                          right: -6,
                          top: -6,
                          child: GestureDetector(
                            onTap: _hapusFotoDipilih,
                            child: const CircleAvatar(
                              radius: 13,
                              backgroundColor: Colors.red,
                              child: Icon(Icons.close, size: 15, color: Colors.white),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Center(
                child: Text(
                  _fotoPath == null ? 'Tap untuk tambah foto (opsional)' : 'Tap untuk ganti foto',
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: _namaController,
                decoration: const InputDecoration(
                  labelText: 'Nama Barang',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.label),
                ),
                validator: (value) => value == null || value.trim().isEmpty
                    ? 'Nama tidak boleh kosong'
                    : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _hargaBeliController,
                decoration: const InputDecoration(
                  labelText: 'Harga Asli (Modal)',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.money),
                  prefixText: 'Rp ',
                ),
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value == null || value.trim().isEmpty)
                    return 'Harga asli tidak boleh kosong';
                  if (double.tryParse(value.trim()) == null)
                    return 'Masukkan angka yang valid';
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _hargaJualController,
                decoration: const InputDecoration(
                  labelText: 'Harga Jual',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.sell),
                  prefixText: 'Rp ',
                ),
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value == null || value.trim().isEmpty)
                    return 'Harga jual tidak boleh kosong';
                  if (double.tryParse(value.trim()) == null)
                    return 'Masukkan angka yang valid';
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _stokController,
                decoration: const InputDecoration(
                  labelText: 'Stok',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.inventory),
                ),
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value == null || value.trim().isEmpty)
                    return 'Stok tidak boleh kosong';
                  if (int.tryParse(value.trim()) == null)
                    return 'Masukkan angka yang valid';
                  return null;
                },
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: _simpan,
                icon: const Icon(Icons.save),
                label: Text(isEdit ? 'Update Produk' : 'Simpan Produk'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  backgroundColor: Theme.of(context).primaryColor,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}