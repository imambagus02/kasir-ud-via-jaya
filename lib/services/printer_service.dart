import 'package:esc_pos_utils_plus/esc_pos_utils_plus.dart';
import 'package:print_bluetooth_thermal/print_bluetooth_thermal.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/transaksi.dart';

/// Ukuran kertas printer thermal yang didukung.
enum UkuranKertas { mm58, mm80 }

/// Service untuk mencetak struk ke printer thermal Bluetooth (ESC/POS).
///
/// Cara pakai singkat:
/// 1. `PrinterService.instance.ambilDaftarPrinter()` -> list printer yang
///    sudah di-pairing lewat pengaturan Bluetooth Android.
/// 2. `PrinterService.instance.sambungkan(alamatMac)` -> connect & simpan
///    sebagai printer default.
/// 3. `PrinterService.instance.cetakStruk(...)` -> cetak struk.
class PrinterService {
  PrinterService._();
  static final PrinterService instance = PrinterService._();

  static const _kKeyAlamatPrinter = 'printer_mac_address';
  static const _kKeyNamaPrinter = 'printer_nama';
  static const _kKeyUkuranKertas = 'printer_ukuran_kertas';

  /// Mengecek apakah Bluetooth perangkat sedang aktif.
  Future<bool> bluetoothAktif() => PrintBluetoothThermal.bluetoothEnabled;

  /// Mengambil daftar printer Bluetooth yang sudah pernah di-pairing
  /// lewat Pengaturan > Bluetooth di Android (bukan scan baru).
  Future<List<BluetoothInfo>> ambilDaftarPrinter() {
    return PrintBluetoothThermal.pairedBluetooths;
  }

  /// Menyambungkan ke printer berdasarkan alamat MAC, lalu menyimpannya
  /// sebagai printer default untuk transaksi berikutnya.
  Future<bool> sambungkan(String macAddress, {String? nama}) async {
    final berhasil =
        await PrintBluetoothThermal.connect(macPrinterAddress: macAddress);
    if (berhasil) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kKeyAlamatPrinter, macAddress);
      if (nama != null) await prefs.setString(_kKeyNamaPrinter, nama);
    }
    return berhasil;
  }

  Future<void> putuskan() => PrintBluetoothThermal.disconnect;

  Future<bool> get sedangTersambung => PrintBluetoothThermal.connectionStatus;

  /// Alamat MAC printer default yang tersimpan (jika pernah dipilih).
  Future<String?> ambilAlamatTersimpan() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_kKeyAlamatPrinter);
  }

  Future<String?> ambilNamaTersimpan() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_kKeyNamaPrinter);
  }

  Future<UkuranKertas> ambilUkuranKertas() async {
    final prefs = await SharedPreferences.getInstance();
    final val = prefs.getString(_kKeyUkuranKertas);
    return val == 'mm80' ? UkuranKertas.mm80 : UkuranKertas.mm58;
  }

  Future<void> simpanUkuranKertas(UkuranKertas ukuran) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        _kKeyUkuranKertas, ukuran == UkuranKertas.mm80 ? 'mm80' : 'mm58');
  }

  /// Mencoba menyambung otomatis ke printer default yang tersimpan.
  /// Mengembalikan true jika berhasil tersambung.
  Future<bool> sambungkanOtomatis() async {
    final sudahTersambung = await sedangTersambung;
    if (sudahTersambung) return true;

    final alamat = await ambilAlamatTersimpan();
    if (alamat == null) return false;
    return sambungkan(alamat);
  }

  /// Membangun & mengirim isi struk ke printer yang sedang tersambung.
  /// Melempar Exception dengan pesan yang jelas kalau gagal.
  Future<void> cetakStruk({
    required int transaksiId,
    required List<TransaksiItem> items,
    required double total,
    required double diterima,
    required double kembalian,
    required String tanggal,
    String namaToko = 'UD. VIA JAYA',
    String? alamatToko,
  }) async {
    final tersambung = await sedangTersambung;
    if (!tersambung) {
      throw Exception(
          'Printer belum tersambung. Silakan pilih printer terlebih dahulu.');
    }

    final ukuran = await ambilUkuranKertas();
    final profile = await CapabilityProfile.load();
    final generator = Generator(
      ukuran == UkuranKertas.mm80 ? PaperSize.mm80 : PaperSize.mm58,
      profile,
    );

    final List<int> bytes = [];

    bytes.addAll(generator.text(
      namaToko,
      styles: const PosStyles(
        align: PosAlign.center,
        bold: true,
        height: PosTextSize.size2,
        width: PosTextSize.size2,
      ),
    ));
    if (alamatToko != null && alamatToko.isNotEmpty) {
      bytes.addAll(generator.text(
        alamatToko,
        styles: const PosStyles(align: PosAlign.center),
      ));
    }
    bytes.addAll(generator.hr());

    bytes.addAll(generator.text('No. Transaksi : $transaksiId'));
    bytes.addAll(generator.text('Tanggal       : ${_formatTanggal(tanggal)}'));
    bytes.addAll(generator.hr());

    for (final item in items) {
      bytes.addAll(generator.text(item.namaProduk));
      bytes.addAll(generator.row([
        PosColumn(
          text: '${item.qty} x ${_formatAngka(item.hargaJual)}',
          width: 7,
        ),
        PosColumn(
          text: _formatAngka(item.subtotal),
          width: 5,
          styles: const PosStyles(align: PosAlign.right),
        ),
      ]));
    }

    bytes.addAll(generator.hr());
    bytes.addAll(generator.row([
      PosColumn(
          text: 'Total',
          width: 6,
          styles: const PosStyles(bold: true)),
      PosColumn(
        text: _formatAngka(total),
        width: 6,
        styles: const PosStyles(align: PosAlign.right, bold: true),
      ),
    ]));
    bytes.addAll(generator.row([
      PosColumn(text: 'Dibayar', width: 6),
      PosColumn(
        text: _formatAngka(diterima),
        width: 6,
        styles: const PosStyles(align: PosAlign.right),
      ),
    ]));
    bytes.addAll(generator.row([
      PosColumn(text: 'Kembalian', width: 6),
      PosColumn(
        text: _formatAngka(kembalian),
        width: 6,
        styles: const PosStyles(align: PosAlign.right),
      ),
    ]));

    bytes.addAll(generator.hr());
    bytes.addAll(generator.text(
      'Terima kasih!',
      styles: const PosStyles(align: PosAlign.center),
    ));
    bytes.addAll(generator.feed(2));
    bytes.addAll(generator.cut());

    final berhasil = await PrintBluetoothThermal.writeBytes(bytes);
    if (!berhasil) {
      throw Exception('Gagal mengirim data ke printer.');
    }
  }

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
}
