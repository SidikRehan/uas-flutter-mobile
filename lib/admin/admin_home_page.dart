import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../auth/login_page.dart';
// import '../dokter/add_doctor_page.dart'; // <--- INI DIHAPUS SAJA (Sudah pindah ke Kelola User)
import 'admin_booking_page.dart';
import 'admin_users_page.dart'; 
import 'admin_laporan_page.dart'; // <--- JANGAN LUPA IMPORT INI (File Laporan)

class AdminHomePage extends StatelessWidget {
  const AdminHomePage({super.key});

  // Widget untuk membuat Tombol Menu Kotak
  Widget _buildMenuCard(BuildContext context, {
    required String title,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Card(
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircleAvatar(
              radius: 35,
              backgroundColor: color.withOpacity(0.2),
              child: Icon(icon, size: 35, color: color),
            ),
            const SizedBox(height: 15),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text("Dashboard Admin"),
        backgroundColor: Colors.redAccent, 
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: "Keluar",
            onPressed: () async {
              await FirebaseAuth.instance.signOut();
              if (context.mounted) {
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (context) => const LoginPage()),
                  (route) => false,
                );
              }
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Header Selamat Datang
          Container(
            padding: const EdgeInsets.all(25),
            width: double.infinity,
            decoration: const BoxDecoration(
              color: Colors.redAccent,
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(30),
                bottomRight: Radius.circular(30),
              ),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("Halo, Admin", style: TextStyle(color: Colors.white70, fontSize: 16)),
                SizedBox(height: 5),
                Text("Panel Kontrol", style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
              ],
            ),
          ),

          // Grid Menu
          Expanded(
            child: GridView.count(
              padding: const EdgeInsets.all(25),
              crossAxisCount: 2, // 2 Kolom
              crossAxisSpacing: 20,
              mainAxisSpacing: 20,
              children: [
                // 1. MENU KELOLA BOOKING
                _buildMenuCard(
                  context,
                  title: "Booking Masuk",
                  icon: Icons.assignment_turned_in,
                  color: Colors.blue,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const AdminBookingPage()),
                    );
                  },
                ),

                // 2. MENU KELOLA PENGGUNA (User, Dokter, Admin)
                // Fitur Tambah Dokter sudah ada di dalam sini (Tab Dokter -> Tombol +)
                _buildMenuCard(
                  context,
                  title: "Kelola User",
                  icon: Icons.manage_accounts,
                  color: Colors.purple,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const AdminUsersPage()),
                    );
                  },
                ),

                // 3. MENU LAPORAN (Sudah Disambungkan)
                _buildMenuCard(
                  context,
                  title: "Laporan",
                  icon: Icons.analytics,
                  color: Colors.orange,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const AdminLaporanPage()),
                    );
                  },
                ),
                
                // Jika ingin menu terlihat penuh (genap), bisa tambah 1 menu info atau biarkan kosong
              ],
            ),
          ),
        ],
      ),
    );
  }
}