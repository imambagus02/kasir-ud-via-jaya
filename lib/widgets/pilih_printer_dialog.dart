import 'package:flutter/material.dart';
import 'package:print_bluetooth_thermal/print_bluetooth_thermal.dart';

import '../services/printer_service.dart';

/// Menampilkan dialog daftar printer Bluetooth yang sudah di-pairing,
/// lalu menyambungkannya kalau dipilih.
///
/// Mengembalikan `true` kalau berhasil tersambung ke sebuah printer.
Future<bool> tampilkanDialogPilihPrinter(BuildContext context) async {
  final aktif = await PrinterService.instance.bluetoothAktif();
  if (!aktif) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Aktifkan Bluetooth di perangkat terlebih dahulu')),
      );
    }
    return false;
  }

  final daftar = await PrinterService.instance.ambilDaftarPrinter();

  if (!context.mounted) return false;

  if (daftar.isEmpty) {
    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Belum ada printer'),
        content: const Text(
          'Tidak ada printer yang terpasang (paired). '
          'Pasangkan dulu printer Bluetooth kamu lewat '
          'Pengaturan > Bluetooth di HP, baru pilih lagi di sini.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Oke'),
          ),
        ],
      ),
    );
    return false;
  }

  final terpilih = await showDialog<BluetoothInfo>(
    context: context,
    builder: (_) => AlertDialog(
      title: const Text('Pilih Printer'),
      content: SizedBox(
        width: double.maxFinite,
        child: ListView.builder(
          shrinkWrap: true,
          itemCount: daftar.length,
          itemBuilder: (context, index) {
            final device = daftar[index];
            return ListTile(
              leading: const Icon(Icons.print),
              title: Text(device.name.isEmpty ? '(Tanpa nama)' : device.name),
              subtitle: Text(device.macAdress),
              onTap: () => Navigator.pop(context, device),
            );
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Batal'),
        ),
      ],
    ),
  );

  if (terpilih == null) return false;
  if (!context.mounted) return false;

  // Tampilkan indikator loading singkat saat menyambungkan.
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (_) => const AlertDialog(
      content: Row(
        children: [
          CircularProgressIndicator(),
          SizedBox(width: 16),
          Text('Menyambungkan...'),
        ],
      ),
    ),
  );

  final berhasil = await PrinterService.instance
      .sambungkan(terpilih.macAdress, nama: terpilih.name);

  if (context.mounted) Navigator.pop(context); // tutup dialog loading

  if (context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(berhasil
            ? 'Tersambung ke ${terpilih.name}'
            : 'Gagal menyambung ke ${terpilih.name}'),
      ),
    );
  }

  return berhasil;
}
