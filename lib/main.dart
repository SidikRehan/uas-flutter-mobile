import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
// 1. TAMBAH IMPORT INI (WAJIB ADA)
import 'package:intl/date_symbol_data_local.dart'; 

import 'auth/login_page.dart'; 

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // --- BAGIAN KONEKSI FIREBASE (User Anda) ---
  if (kIsWeb) {
    await Firebase.initializeApp(
      options: const FirebaseOptions(
        apiKey: "AIzaSyCIASyD8HejXiBLEUQC2DMY2_Ux4xGke0o",
        authDomain: "rs-app-belajar.firebaseapp.com",
        projectId: "rs-app-belajar",
        storageBucket: "rs-app-belajar.firebasestorage.app",
        messagingSenderId: "824513239332",
        appId: "1:824513239332:web:b371353c76cd7fa914fbb1",
      ),
    );
  } else {
    // Untuk Android (otomatis baca google-services.json)
    await Firebase.initializeApp();
  }
  
  // 2. TAMBAHKAN KODE INI (SOLUSI ERROR MERAH)
  // Ini menyiapkan format tanggal Indonesia ('id_ID') sebelum aplikasi jalan
  await initializeDateFormatting('id_ID', null); 

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false, 
      title: 'Rumah Sakit App',
      theme: ThemeData(
        primarySwatch: Colors.blue, 
        useMaterial3: true,
      ),
      home: const LoginPage(),
    );
  }
}