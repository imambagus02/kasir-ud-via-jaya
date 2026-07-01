import 'dart:io';

import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Helper untuk memilih foto produk (kamera/galeri) dan menyimpannya
/// secara permanen di folder aplikasi, supaya tidak hilang walau file
/// asal di galeri/cache dihapus.
class FotoProdukService {
  static final ImagePicker _picker = ImagePicker();

  static Future<XFile?> pilihDariGaleri() {
    return _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1024,
      imageQuality: 80,
    );
  }

  static Future<XFile?> pilihDariKamera() {
    return _picker.pickImage(
      source: ImageSource.camera,
      maxWidth: 1024,
      imageQuality: 80,
    );
  }

  /// Menyalin file foto yang dipilih ke folder permanen aplikasi
  /// (`app_documents/produk_photos/`) dan mengembalikan path barunya.
  static Future<String> simpanPermanen(XFile file) async {
    final dir = await getApplicationDocumentsDirectory();
    final folder = Directory(p.join(dir.path, 'produk_photos'));
    if (!await folder.exists()) {
      await folder.create(recursive: true);
    }

    final ext = p.extension(file.path).isNotEmpty ? p.extension(file.path) : '.jpg';
    final namaBaru = 'produk_${DateTime.now().millisecondsSinceEpoch}$ext';
    final tujuan = File(p.join(folder.path, namaBaru));

    await tujuan.writeAsBytes(await file.readAsBytes());
    return tujuan.path;
  }

  /// Menghapus file foto lama (dipanggil saat foto diganti/produk dihapus).
  /// Aman dipanggil walau file tidak ada.
  static Future<void> hapusFoto(String? path) async {
    if (path == null || path.isEmpty) return;
    try {
      final file = File(path);
      if (await file.exists()) await file.delete();
    } catch (_) {
      // Abaikan kalau gagal hapus, bukan hal fatal.
    }
  }
}
