import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../auth/login_page.dart';
import 'dokter_pemeriksaan_page.dart'; // Halaman Periksa

class DokterDashboard extends StatefulWidget {
  const DokterDashboard({super.key});

  @override
  State<DokterDashboard> createState() => _DokterDashboardState();
}

class _DokterDashboardState extends State<DokterDashboard> {
  int _selectedIndex = 0;

  // Halaman Dokter hanya 2: Daftar Pasien & Profil(Logout)
  final List<Widget> _pages = [
    const DokterPemeriksaanPage(), // Halaman Periksa
    const Center(child: Text("Halaman Jadwal (Opsional)")), // Placeholder
  ];

  void _logout() async {
    await FirebaseAuth.instance.signOut();
    if (mounted) {
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (c) => const LoginPage()));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // AppBar dihandle oleh masing-masing page atau global disini
      body: _pages[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (index) {
          if (index == 2) { // Tombol Logout (Index dummy)
            _logout();
          } else {
            setState(() => _selectedIndex = index);
          }
        },
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.medical_services), label: "Pasien"),
          BottomNavigationBarItem(icon: Icon(Icons.calendar_month), label: "Jadwal"),
          BottomNavigationBarItem(icon: Icon(Icons.logout, color: Colors.red), label: "Keluar"),
        ],
      ),
    );
  }
}