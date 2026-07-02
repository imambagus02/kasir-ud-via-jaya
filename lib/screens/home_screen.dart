import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/kategori_provider.dart';
import '../providers/produk_provider.dart';
import 'kasir_screen.dart';
import 'inventory_screen.dart';
import 'laporan_screen.dart';
import 'pengaturan_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;

  final List<String> _titles = [
    'Kasir',
    'Inventory',
    'Laporan Penjualan',
    'Pengaturan',
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<KategoriProvider>().muatData();
      context.read<ProdukProvider>().muatData();
    });
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      const KasirScreen(),
      const InventoryScreen(),
      const LaporanScreen(),
      const PengaturanScreen(),
    ];

    return Scaffold(
      appBar: AppBar(
        title: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'UD. VIA JAYA',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
            ),
            Text(
              _titles[_selectedIndex],
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.normal),
            ),
          ],
        ),
        centerTitle: true,
        foregroundColor: Colors.white,
        elevation: 0,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color.fromARGB(255, 216, 168, 12), Color.fromARGB(255, 59, 201, 219)],
            ),
          ),
        ),
      ),
      body: IndexedStack(
        index: _selectedIndex,
        children: pages,
      ),
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  // ─── Bottom navigation modern dengan pill highlight ──────────────────────

  Widget _buildBottomNav() {
    final items = [
      (Icons.point_of_sale_rounded, 'Kasir'),
      (Icons.inventory_2_rounded, 'Inventory'),
      (Icons.bar_chart_rounded, 'Laporan'),
      (Icons.settings_rounded, 'Pengaturan'),
    ];

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 12,
            offset: const Offset(0, -3),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: List.generate(items.length, (index) {
              final aktif = _selectedIndex == index;
              final (icon, label) = items[index];

              return GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => setState(() => _selectedIndex = index),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: aktif ? const Color(0xFFE6F4F1) : Colors.transparent,
                    borderRadius: BorderRadius.circular(30),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        icon,
                        size: 21,
                        color: aktif ? const Color.fromARGB(255, 207, 139, 12) : Colors.grey,
                      ),
                      if (aktif) ...[
                        const SizedBox(width: 5),
                        Text(
                          label,
                          style: const TextStyle(
                            color: Color.fromARGB(255, 79, 118, 15),
                            fontWeight: FontWeight.bold,
                            fontSize: 12.5,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}