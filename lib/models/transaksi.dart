class Transaksi {
  int? id;
  String tanggal; // disimpan format ISO8601 string
  double totalBayar;
  double totalDiterima;
  double kembalian;

  Transaksi({
    this.id,
    required this.tanggal,
    required this.totalBayar,
    required this.totalDiterima,
    required this.kembalian,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'tanggal': tanggal,
      'total_bayar': totalBayar,
      'total_diterima': totalDiterima,
      'kembalian': kembalian,
    };
  }

  factory Transaksi.fromMap(Map<String, dynamic> map) {
    return Transaksi(
      id: map['id'],
      tanggal: map['tanggal'],
      totalBayar: map['total_bayar'],
      totalDiterima: map['total_diterima'],
      kembalian: map['kembalian'],
    );
  }
}

class TransaksiItem {
  int? id;
  int transaksiId;
  int produkId;
  String namaProduk; // snapshot nama saat transaksi
  double hargaJual;  // snapshot harga jual saat transaksi
  double hargaBeli;  // snapshot harga beli saat transaksi
  int qty;
  double subtotal;

  TransaksiItem({
    this.id,
    required this.transaksiId,
    required this.produkId,
    required this.namaProduk,
    required this.hargaJual,
    required this.hargaBeli,
    required this.qty,
    required this.subtotal,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'transaksi_id': transaksiId,
      'produk_id': produkId,
      'nama_produk': namaProduk,
      'harga_jual': hargaJual,
      'harga_beli': hargaBeli,
      'qty': qty,
      'subtotal': subtotal,
    };
  }

  factory TransaksiItem.fromMap(Map<String, dynamic> map) {
    return TransaksiItem(
      id: map['id'],
      transaksiId: map['transaksi_id'],
      produkId: map['produk_id'],
      namaProduk: map['nama_produk'],
      hargaJual: map['harga_jual'],
      hargaBeli: map['harga_beli'],
      qty: map['qty'],
      subtotal: map['subtotal'],
    );
  }
}