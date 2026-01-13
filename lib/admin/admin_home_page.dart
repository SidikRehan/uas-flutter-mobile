import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../auth/login_page.dart';

// Import halaman-halaman ADMIN yang BENAR (Valid)
import 'admin_users_page.dart';    // Kelola Dokter, Pasien, Admin & Poli
import 'admin_booking_page.dart';  // Antrian & Kasir
import 'admin_laporan_page.dart';  // Laporan Keuangan

class AdminHomePage extends StatefulWidget {
  const AdminHomePage({super.key});

  @override
  State<AdminHomePage> createState() => _AdminHomePageState();
}

class _AdminHomePageState extends State<AdminHomePage> {
  // --- MENU DASHBOARD ---
  final List<Map<String, dynamic>> menuAdmin = [
    {
      "title": "Kelola Pengguna",
      "icon": Icons.people,
      "color": Colors.blue,
      "page": const AdminUsersPage() // Halaman Tab (Dokter/Pasien/Admin) + Gear Poli
    },
    {
      "title": "Antrian & Kasir",
      "icon": Icons.point_of_sale,
      "color": Colors.orange,
      "page": const AdminBookingPage() // Halaman Kasir & Approval
    },
    {
      "title": "Laporan & Statistik",
      "icon": Icons.bar_chart,
      "color": Colors.green,
      "page": const AdminLaporanPage() // Halaman Duit
    },
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
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text("Dashboard Admin"),
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
        actions: [
          IconButton(onPressed: _logout, icon: const Icon(Icons.logout), tooltip: "Keluar"),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Selamat Datang, Admin",
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const Text("Silakan pilih menu operasional:"),
            const SizedBox(height: 20),
            
            // --- GRID MENU ---
            Expanded(
              child: GridView.builder(
                itemCount: menuAdmin.length,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2, // 2 Kolom
                  crossAxisSpacing: 15,
                  mainAxisSpacing: 15,
                  childAspectRatio: 1.0,
                ),
                itemBuilder: (context, index) {
                  return InkWell(
                    onTap: () {
                      Navigator.push(
                        context, 
                        MaterialPageRoute(builder: (context) => menuAdmin[index]['page'])
                      );
                    },
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(15),
                        boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.1), blurRadius: 5)],
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(15),
                            decoration: BoxDecoration(
                              color: menuAdmin[index]['color'].withOpacity(0.1),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(menuAdmin[index]['icon'], size: 40, color: menuAdmin[index]['color']),
                          ),
                          const SizedBox(height: 15),
                          Text(
                            menuAdmin[index]['title'],
                            textAlign: TextAlign.center,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}