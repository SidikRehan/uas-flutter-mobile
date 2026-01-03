import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart'; 
// 👇 INI PENTING: Import halaman login yang sudah kamu buat
import 'auth/login_page.dart'; 

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // --- BAGIAN KONEKSI FIREBASE (JANGAN DIUBAH) ---
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
  // -----------------------------------------------

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false, // Hilangkan pita "Debug" di pojok
      title: 'Rumah Sakit App',
      theme: ThemeData(
        primarySwatch: Colors.blue, // Tema warna biru
        useMaterial3: true,
      ),
      // 👇 DISINI KITA GANTI TAMPILANNYA
      // Tadinya "Scaffold(body: Center...)" sekarang jadi "LoginPage()"
      home: const LoginPage(),
    );
  }
}