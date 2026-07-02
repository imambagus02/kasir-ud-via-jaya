import 'package:shared_preferences/shared_preferences.dart';

/// Menyimpan & memverifikasi password untuk aksi sensitif (mis. hapus riwayat).
/// Password disimpan secara lokal di HP menggunakan SharedPreferences,
/// sehingga tetap tersimpan meski aplikasi ditutup/dibuka lagi.
class PasswordService {
  PasswordService._();
  static final PasswordService instance = PasswordService._();

  static const String _kKeyPasswordHapusRiwayat = 'password_hapus_riwayat';
  static const String _defaultPassword = '1234';

  Future<String> getPasswordHapusRiwayat() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_kKeyPasswordHapusRiwayat) ?? _defaultPassword;
  }

  Future<bool> verifikasiPasswordHapusRiwayat(String input) async {
    final password = await getPasswordHapusRiwayat();
    return input == password;
  }

  /// Mengubah password. Mengembalikan true jika berhasil (password lama cocok).
  Future<bool> ubahPasswordHapusRiwayat({
    required String passwordLama,
    required String passwordBaru,
  }) async {
    final cocok = await verifikasiPasswordHapusRiwayat(passwordLama);
    if (!cocok) return false;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kKeyPasswordHapusRiwayat, passwordBaru);
    return true;
  }
}
