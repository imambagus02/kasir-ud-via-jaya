import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/kategori_provider.dart';
import 'providers/produk_provider.dart';
import 'screens/home_screen.dart';
import 'providers/laporan_provider.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => KategoriProvider()),
        ChangeNotifierProvider(create: (_) => ProdukProvider()),
        ChangeNotifierProvider(create: (_) => LaporanProvider()),
      ],
      child: MaterialApp(
        title: 'Kasir Offline',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          primarySwatch: Colors.blue,
          useMaterial3: true,
        ),
        home: const HomeScreen(),
      ),
    );
  }
}