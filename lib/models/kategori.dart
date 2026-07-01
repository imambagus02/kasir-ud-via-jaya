class Kategori {
  int? id;
  String nama;

  Kategori({this.id, required this.nama});

  // Mengubah objek Kategori jadi Map (untuk disimpan ke SQLite)
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'nama': nama,
    };
  }

  // Mengubah Map dari SQLite jadi objek Kategori
  factory Kategori.fromMap(Map<String, dynamic> map) {
    return Kategori(
      id: map['id'],
      nama: map['nama'],
    );
  }
}