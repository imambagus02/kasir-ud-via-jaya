import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/kategori.dart';
import '../providers/kategori_provider.dart';

class KategoriScreen extends StatefulWidget {
  const KategoriScreen({super.key});

  @override
  State<KategoriScreen> createState() => _KategoriScreenState();
}

class _KategoriScreenState extends State<KategoriScreen> {
  @override
  void initState() {
    super.initState();
    // Muat data kategori saat halaman pertama kali dibuka
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<KategoriProvider>().muatData();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Kategori Produk')),
      body: Consumer<KategoriProvider>(
        builder: (context, provider, child) {
          if (provider.daftarKategori.isEmpty) {
            return const Center(
              child: Text('Belum ada kategori. Tambah dulu yuk!'),
            );
          }
          return ListView.builder(
            itemCount: provider.daftarKategori.length,
            itemBuilder: (context, index) {
              final kategori = provider.daftarKategori[index];
              return ListTile(
                title: Text(kategori.nama),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit, color: Colors.blue),
                      onPressed: () => _showFormDialog(context, kategori: kategori),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete, color: Colors.red),
                      onPressed: () => _konfirmasiHapus(context, kategori),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showFormDialog(context),
        child: const Icon(Icons.add),
      ),
    );
  }

  // Dialog form tambah/edit kategori
  void _showFormDialog(BuildContext context, {Kategori? kategori}) {
    final isEdit = kategori != null;
    final controller = TextEditingController(text: kategori?.nama ?? '');

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(isEdit ? 'Edit Kategori' : 'Tambah Kategori'),
          content: TextField(
            controller: controller,
            decoration: const InputDecoration(
              labelText: 'Nama Kategori',
              hintText: 'Contoh: Makanan, Minuman',
            ),
            autofocus: true,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Batal'),
            ),
            ElevatedButton(
              onPressed: () async {
                final nama = controller.text.trim();
                if (nama.isEmpty) return;

                final provider = context.read<KategoriProvider>();
                if (isEdit) {
                  kategori.nama = nama;
                  await provider.update(kategori);
                } else {
                  await provider.tambah(nama);
                }

                if (context.mounted) Navigator.pop(context);
              },
              child: const Text('Simpan'),
            ),
          ],
        );
      },
    );
  }

  // Konfirmasi sebelum hapus
  void _konfirmasiHapus(BuildContext context, Kategori kategori) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Hapus Kategori'),
          content: Text('Yakin ingin menghapus "${kategori.nama}"?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Batal'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () async {
                await context.read<KategoriProvider>().hapus(kategori.id!);
                if (context.mounted) Navigator.pop(context);
              },
              child: const Text('Hapus'),
            ),
          ],
        );
      },
    );
  }
}