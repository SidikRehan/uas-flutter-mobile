import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'auth/login_page.dart';
import 'pasien/riwayat_page.dart';
import 'admin/poli_page.dart';
import 'profile_page.dart';          // Pastikan file ini ada
import 'pasien/cek_antrian_page.dart';
import 'pasien/tagihan_page.dart';   // Pastikan file ini ada

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final User? user = FirebaseAuth.instance.currentUser;
  String _namaUser = "Pasien";

  @override
  void initState() {
    super.initState();
    _ambilDataUser();
  }

  void _ambilDataUser() async {
    if (user != null) {
      // Coba ambil nama dari users collection
      var snapshot = await FirebaseFirestore.instance.collection('users').doc(user!.uid).get();
      if (snapshot.exists && mounted) {
        setState(() {
          _namaUser = snapshot.data()?['nama'] ?? "Pasien";
        });
      }
    }
  }

  void _logout() async {
    await FirebaseAuth.instance.signOut();
    if (mounted) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const LoginPage()),
        (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text("RS Sehat Sentosa"),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        automaticallyImplyLeading: false, // Hilangkan tombol back
        actions: [
          IconButton(onPressed: _logout, icon: const Icon(Icons.logout)),
        ],
      ),
      body: Column(
        children: [
          // HEADER (Sapaan Nama)
          Container(
            padding: const EdgeInsets.all(20),
            width: double.infinity,
            decoration: const BoxDecoration(
              color: Colors.blue,
              borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(30), bottomRight: Radius.circular(30)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("Selamat Datang,", style: TextStyle(color: Colors.white70, fontSize: 16)),
                Text(_namaUser, style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
          const SizedBox(height: 10),
          
          // GRID MENU
          Expanded(
            child: GridView.count(
              padding: const EdgeInsets.all(20),
              crossAxisCount: 2, // 2 Kotak per baris
              crossAxisSpacing: 15,
              mainAxisSpacing: 15,
              children: [
                // 1. POLI
                _buildMenuCard(
                  icon: Icons.local_hospital,
                  color: Colors.orange,
                  label: "Pilih Poli",
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const PoliPage())),
                ),

                // 2. ANTRIAN
                _buildMenuCard(
                  icon: Icons.people_alt,
                  color: Colors.green,
                  label: "Cek Antrian",
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const CekAntrianPage())),
                ),

                // 3. TAGIHAN (Baru)
                _buildMenuCard(
                  icon: Icons.receipt_long,
                  color: Colors.teal,
                  label: "Tagihan",
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const TagihanPage())),
                ),

                // 4. RIWAYAT
                _buildMenuCard(
                  icon: Icons.history_edu,
                  color: Colors.purple,
                  label: "Riwayat",
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const RiwayatPage())),
                ),

                // 5. PROFIL SAYA (Ini yang tadi hilang)
                _buildMenuCard(
                  icon: Icons.person, 
                  color: Colors.blue, 
                  label: "Profil Saya",
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const ProfilePage())),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Widget Kotak Menu
  Widget _buildMenuCard({required IconData icon, required Color color, required String label, required VoidCallback onTap}) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(15),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircleAvatar(
              radius: 30,
              backgroundColor: color.withOpacity(0.2),
              child: Icon(icon, size: 30, color: color),
            ),
            const SizedBox(height: 15),
            Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          ],
        ),
      ),
    );
  }
}