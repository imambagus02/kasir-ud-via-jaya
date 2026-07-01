import 'dart:io';
import 'package:flutter/material.dart';

/// Menampilkan foto produk dari [fotoPath] kalau ada & filenya masih ada,
/// atau ikon default kalau tidak ada foto.
class FotoProduk extends StatelessWidget {
  final String? fotoPath;
  final double size;
  final double? width;
  final double? height;
  final double borderRadius;
  final IconData ikonFallback;

  const FotoProduk({
    super.key,
    required this.fotoPath,
    this.size = 56,
    this.width,
    this.height,
    this.borderRadius = 8,
    this.ikonFallback = Icons.shopping_bag,
  });

  @override
  Widget build(BuildContext context) {
    final path = fotoPath;
    final file = (path != null && path.isNotEmpty) ? File(path) : null;
    final adaFoto = file != null && file.existsSync();
    final lebar = width ?? size;
    final tinggi = height ?? size;

    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: adaFoto
          ? Image.file(
              file,
              width: lebar,
              height: tinggi,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => _fallback(lebar, tinggi),
            )
          : _fallback(lebar, tinggi),
    );
  }

  Widget _fallback(double lebar, double tinggi) {
    return Container(
      width: lebar,
      height: tinggi,
      color: Colors.blue[50],
      child: Icon(ikonFallback, color: Colors.blue,
          size: (lebar < tinggi ? lebar : tinggi) * 0.4),
    );
  }
}
