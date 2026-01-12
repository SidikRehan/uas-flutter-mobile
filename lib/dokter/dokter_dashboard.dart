import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../auth/login_page.dart';
import 'dokter_pemeriksaan_page.dart'; 
import 'dokter_jadwal_page.dart';
import 'dokter_profile_page.dart'; // <--- FILE BARU YANG KAMU BUAT

class DokterDashboard extends StatefulWidget {
  const DokterDashboard({super.key});

  @override
  State<DokterDashboard> createState() => _DokterDashboardState();
}

class _DokterDashboardState extends State<DokterDashboard> {
  User? currentUser = FirebaseAuth.instance.currentUser;
  String namaDokter = "Dokter";

  @override
  void initState() {
    super.initState();
    _getNamaDokter();
  }

  void _getNamaDokter() async {
    if (currentUser != null) {
      // Ambil nama terbaru (siapa tahu baru diedit)
      var doc = await FirebaseFirestore.instance.collection('users').doc(currentUser!.uid).get();
      if (mounted) {
        setState(() {
          namaDokter = doc.data()?['nama'] ?? "Dokter";
        });
      }
    }
  }

  // Widget Tombol Menu
  Widget _buildMenuCard(String title, IconData icon, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Card(
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircleAvatar(
              radius: 35,
              backgroundColor: color.withOpacity(0.2),
              child: Icon(icon, size: 35, color: color),
            ),
            const SizedBox(height: 15),
            Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
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
        title: const Text("Portal Dokter"),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await FirebaseAuth.instance.signOut();
              if (mounted) {
                Navigator.pushAndRemoveUntil(
                  context, 
                  MaterialPageRoute(builder: (c) => const LoginPage()), 
                  (route) => false
                );
              }
            },
          )
        ],
      ),
      body: Column(
        children: [
          // Header Nama Dokter
          Container(
            padding: const EdgeInsets.all(25),
            width: double.infinity,
            decoration: const BoxDecoration(
              color: Colors.teal,
              borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(30), bottomRight: Radius.circular(30)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("Selamat Bertugas,", style: TextStyle(color: Colors.white70)),
                Text(namaDokter, style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
          
          // Grid Menu
          Expanded(
            child: GridView.count(
              padding: const EdgeInsets.all(25),
              crossAxisCount: 2, 
              crossAxisSpacing: 15,
              mainAxisSpacing: 15,
              children: [
                // MENU 1: PERIKSA PASIEN
                _buildMenuCard("Periksa Pasien", Icons.medical_services, Colors.orange, () {
                  Navigator.push(context, MaterialPageRoute(builder: (c) => const DokterPemeriksaanPage()));
                }),

                // MENU 2: JADWAL SAYA
                _buildMenuCard("Jadwal Saya", Icons.calendar_today, Colors.blue, () {
                  Navigator.push(context, MaterialPageRoute(builder: (c) => const DokterJadwalPage()));
                }),

               // MENU 3: EDIT PROFIL (INI YANG BARU)
                // Ganti Icons.person_edit MENJADI Icons.manage_accounts
                _buildMenuCard("Edit Profil", Icons.manage_accounts, Colors.purple, () {
                  Navigator.push(context, MaterialPageRoute(builder: (c) => const DokterProfilePage()))
                      .then((_) => _getNamaDokter()); 
                }),
              ],
            ),
          ),
        ],
      ),
    );
  }
}