class Produk {
  int? id;
  String nama;
  String? fotoPath;
  int? kategoriId;
  double hargaBeli;
  double hargaJual;
  int stok;

  Produk({
    this.id,
    required this.nama,
    this.fotoPath,
    this.kategoriId,
    required this.hargaBeli,
    required this.hargaJual,
    this.stok = 0,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'nama': nama,
      'foto_path': fotoPath,
      'kategori_id': kategoriId,
      'harga_beli': hargaBeli,
      'harga_jual': hargaJual,
      'stok': stok,
    };
  }

  factory Produk.fromMap(Map<String, dynamic> map) {
    return Produk(
      id: map['id'],
      nama: map['nama'],
      fotoPath: map['foto_path'],
      kategoriId: map['kategori_id'],
      hargaBeli: map['harga_beli'],
      hargaJual: map['harga_jual'],
      stok: map['stok'],
    );
  }
}