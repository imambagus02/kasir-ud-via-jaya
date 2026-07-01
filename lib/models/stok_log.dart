class StokLog {
  int? id;
  int produkId;
  String jenis; // 'masuk', 'keluar', atau 'koreksi'
  int jumlah;
  String tanggal;
  String? keterangan;

  StokLog({
    this.id,
    required this.produkId,
    required this.jenis,
    required this.jumlah,
    required this.tanggal,
    this.keterangan,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'produk_id': produkId,
      'jenis': jenis,
      'jumlah': jumlah,
      'tanggal': tanggal,
      'keterangan': keterangan,
    };
  }

  factory StokLog.fromMap(Map<String, dynamic> map) {
    return StokLog(
      id: map['id'],
      produkId: map['produk_id'],
      jenis: map['jenis'],
      jumlah: map['jumlah'],
      tanggal: map['tanggal'],
      keterangan: map['keterangan'],
    );
  }
}