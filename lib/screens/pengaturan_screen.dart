import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/kategori_provider.dart';
import '../providers/produk_provider.dart';
import '../providers/laporan_provider.dart';
import '../services/backup_service.dart';

class PengaturanScreen extends StatefulWidget {
  const PengaturanScreen({super.key});

  @override
  State<PengaturanScreen> createState() => _PengaturanScreenState();
}

class _PengaturanScreenState extends State<PengaturanScreen> {
  bool _sedangBackup = false;
  bool _sedangRestore = false;

  Future<void> _backup() async {
    setState(() => _sedangBackup = true);
    try {
      await BackupService.instance.backupDanBagikan();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal membuat backup: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _sedangBackup = false);
    }
  }

  Future<void> _restore() async {
    setState(() => _sedangRestore = true);
    try {
      final backup = await BackupService.instance.bacaFileBackup();
      if (backup == null) return; // dibatalkan user

      final data = backup['data'] as Map<String, dynamic>;
      final jumlahProduk = (data['produk'] as List?)?.length ?? 0;
      final jumlahTransaksi = (data['transaksi'] as List?)?.length ?? 0;
      final dibuatPada = backup['dibuat_pada'] as String?;

      if (!mounted) return;
      final konfirmasi = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.warning_amber, color: Colors.red),
              SizedBox(width: 8),
              Text('Pulihkan Data?'),
            ],
          ),
          content: Text(
            'File backup ini berisi $jumlahProduk produk dan '
            '$jumlahTransaksi transaksi'
            '${dibuatPada != null ? ' (dibuat: ${_formatTanggalBackup(dibuatPada)})' : ''}.\n\n'
            'SEMUA data yang ada saat ini di aplikasi (kategori, produk, '
            'transaksi, riwayat) akan DIHAPUS dan diganti dengan data dari '
            'file backup ini.\n\n'
            'Tindakan ini tidak bisa dibatalkan. Lanjutkan?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Batal'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Pulihkan', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      );

      if (konfirmasi != true) return;

      final hasil = await BackupService.instance.pulihkanDariBackup(backup);

      if (!mounted) return;
      await context.read<KategoriProvider>().muatData();
      await context.read<ProdukProvider>().muatData();
      await context.read<LaporanProvider>().muatData();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(
                  'Berhasil memulihkan ${hasil.totalBaris} baris data')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal memulihkan data: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _sedangRestore = false);
    }
  }

  String _formatTanggalBackup(String iso) {
    try {
      final d = DateTime.parse(iso);
      return '${d.day.toString().padLeft(2, '0')}/'
          '${d.month.toString().padLeft(2, '0')}/'
          '${d.year} ${d.hour.toString().padLeft(2, '0')}:'
          '${d.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return iso;
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          elevation: 0,
          color: Colors.blue[50],
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: Colors.blue[100]!),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.backup, color: Colors.blue[800]),
                    const SizedBox(width: 8),
                    const Text('Backup Data',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  ],
                ),
                const SizedBox(height: 8),
                const Text(
                  'Simpan semua data (kategori, produk, transaksi, riwayat) '
                  'ke satu file. Simpan file ini ke Google Drive, email ke diri '
                  'sendiri, atau simpan di HP lain sebagai cadangan.',
                  style: TextStyle(fontSize: 13, color: Colors.black87),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _sedangBackup ? null : _backup,
                    icon: _sedangBackup
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                                color: Colors.white, strokeWidth: 2),
                          )
                        : const Icon(Icons.save_alt, color: Colors.white),
                    label: Text(
                      _sedangBackup ? 'Menyiapkan...' : 'Backup Sekarang',
                      style: const TextStyle(color: Colors.white),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue[700],
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Card(
          elevation: 0,
          color: Colors.orange[50],
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: Colors.orange[100]!),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.restore, color: Colors.orange[800]),
                    const SizedBox(width: 8),
                    const Text('Pulihkan Data',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  ],
                ),
                const SizedBox(height: 8),
                const Text(
                  'Pilih file backup (.json) yang pernah kamu simpan untuk '
                  'mengembalikan semua data. Data yang ada sekarang akan '
                  'diganti dengan data dari file backup.',
                  style: TextStyle(fontSize: 13, color: Colors.black87),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _sedangRestore ? null : _restore,
                    icon: _sedangRestore
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.upload_file),
                    label: Text(_sedangRestore
                        ? 'Memulihkan...'
                        : 'Pilih File Backup'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.orange[800],
                      side: BorderSide(color: Colors.orange[300]!),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'Catatan: foto produk (jika ada) tidak ikut tersimpan di file backup, '
          'hanya lokasi filenya saja. Data lain seperti kategori, produk, harga, '
          'stok, dan seluruh riwayat transaksi tersimpan lengkap.',
          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
        ),
      ],
    );
  }
}
