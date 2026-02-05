import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../auth/login_page.dart';

// Import halaman-halaman ADMIN
import 'admin_users_page.dart'; // Fitur Tambah Admin SUDAH ADA di sini (Tab ke-3)
import 'admin_booking_page.dart';
import 'admin_laporan_page.dart';
import 'admin_medical_history.dart';

class AdminHomePage extends StatefulWidget {
  const AdminHomePage({super.key});

  @override
  State<AdminHomePage> createState() => _AdminHomePageState();
}

class _AdminHomePageState extends State<AdminHomePage> {
  User? user = FirebaseAuth.instance.currentUser;
  String namaAdmin = "Admin";
  bool isSuperAdmin = false;

  @override
  void initState() {
    super.initState();
    _cekLevelAdmin();
  }

  // --- LOGIKA CEK ADMIN + BACKDOOR (ADMIN SAKTI) ---
  void _cekLevelAdmin() async {
    if (user != null) {
      var doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user!.uid)
          .get();

      bool statusSuper = false;
      // GANTI EMAIL ADMIN ANDA DISINI
      String emailSakti = "admin@rs.com";

      // Cek Backdoor
      if (user!.email == emailSakti) {
        statusSuper = true;
        // Auto-Fix Database
        if (!doc.exists || doc.data()?['level'] != 'super') {
          await FirebaseFirestore.instance
              .collection('users')
              .doc(user!.uid)
              .set({
                'level': 'super',
                'role': 'admin',
                'email': emailSakti,
              }, SetOptions(merge: true));
        }
      }
      // Cek Database Normal
      else if (doc.exists && doc.data()?['level'] == 'super') {
        statusSuper = true;
      }

      if (mounted) {
        setState(() {
          namaAdmin = doc.data()?['nama'] ?? "Admin";
          isSuperAdmin = statusSuper;
        });
      }
    }
  }

  void _logout() async {
    await FirebaseAuth.instance.signOut();
    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (c) => const LoginPage()),
      );
    }
  }

  // --- FUNGSI DARURAT: PERBAIKI DATA DOKTER ---
  void _fixDataDokter() async {
    setState(() {}); // Loading effect
    var snap = await FirebaseFirestore.instance.collection('doctors').get();
    int count = 0;

    for (var doc in snap.docs) {
      if (doc.data()['is_active'] == null) {
        await FirebaseFirestore.instance
            .collection('doctors')
            .doc(doc.id)
            .update({'is_active': true});
        await FirebaseFirestore.instance.collection('users').doc(doc.id).update(
          {'is_active': true},
        );
        count++;
      }
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Berhasil memperbaiki $count Dokter!"),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // --- LIST MENU DASHBOARD MODERN ---
    List<Map<String, dynamic>> menuAdmin = [
      {
        "title": "Kelola Pengguna",
        "subtitle": "Dokter, Pasien, Admin",
        "icon": Icons.people_alt_rounded,
        "color": const Color(0xFF0077B6), // Medical Blue
        "page": const AdminUsersPage(),
      },
      {
        "title": "Antrian & Kasir",
        "subtitle": "Cek Booking & Pembayaran",
        "icon": Icons.point_of_sale_rounded,
        "color": const Color(0xFF0096C7), // Lighter Blue
        "page": const AdminBookingPage(),
      },
      {
        "title": "Laporan & Statistik",
        "subtitle": "Data Pasien & Keuangan",
        "icon": Icons.insert_chart_rounded,
        "color": const Color(0xFF48CAE4), // Cyan
        "page": const AdminLaporanPage(),
      },
      {
        "title": "Rekam Medis",
        "subtitle": "Riwayat Periksa Pasien",
        "icon": Icons.assignment_turned_in_rounded,
        "color": const Color(0xFF20B2AA), // Light Sea Green
        "page": const AdminMedicalHistory(),
      },
    ];

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA), // Clean Background
      // Modern App Bar
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        centerTitle: false,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Admin Dashboard",
              style: TextStyle(
                color: Color(0xFF023E8A),
                fontWeight: FontWeight.bold,
                fontSize: 20,
              ),
            ),
            Text(
              isSuperAdmin ? "Role: SUPER ADMIN" : "Role: Staff Admin",
              style: TextStyle(
                fontSize: 12,
                color: isSuperAdmin ? Colors.orange : Colors.grey,
              ),
            ),
          ],
        ),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 16),
            child: IconButton(
              onPressed: _logout,
              icon: const Icon(Icons.logout_rounded, color: Colors.red),
              tooltip: "Keluar",
            ),
          ),
        ],
      ),

      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. WELCOME CARD
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF0077B6), Color(0xFF00B4D8)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF0077B6).withValues(alpha: 0.3),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "Selamat Datang kembali,",
                          style: TextStyle(color: Colors.white70, fontSize: 14),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          namaAdmin,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Text(
                            "Have a nice work day! 👨‍⚕️",
                            style: TextStyle(color: Colors.white, fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      shape: BoxShape.circle,
                    ),
                    child: const CircleAvatar(
                      radius: 40,
                      backgroundColor: Colors.white,
                      child: Icon(
                        Icons.admin_panel_settings_rounded,
                        size: 40,
                        color: Color(0xFF0077B6),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 32),
            const Text(
              "Menu Operasional",
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF03045E),
              ),
            ),
            const SizedBox(height: 16),

            // 2. GRID MENU MODERN
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: menuAdmin.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 1, // List vertical biar lebih jelas infonya
                mainAxisSpacing: 16,
                childAspectRatio: 2.5, // Lebar
              ),
              itemBuilder: (context, index) {
                return Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.grey.withValues(alpha: 0.05),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(20),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => menuAdmin[index]['page'],
                          ),
                        );
                      },
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: (menuAdmin[index]['color'] as Color)
                                    .withValues(alpha: 0.1),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                menuAdmin[index]['icon'],
                                size: 32,
                                color: menuAdmin[index]['color'],
                              ),
                            ),
                            const SizedBox(width: 20),
                            Expanded(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    menuAdmin[index]['title'],
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 18,
                                      color: Color(0xFF03045E),
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    menuAdmin[index]['subtitle'],
                                    style: const TextStyle(
                                      color: Colors.grey,
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const Icon(
                              Icons.chevron_right_rounded,
                              color: Colors.grey,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),

            const SizedBox(height: 32),

            // 3. TOMBOL DARURAT (FIX DOKTER)
            if (isSuperAdmin) ...[
              const Divider(),
              const SizedBox(height: 16),
              Container(
                decoration: BoxDecoration(
                  color: Colors.orange[50],
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: Colors.orange.withValues(alpha: 0.3),
                  ),
                ),
                child: ListTile(
                  leading: const Icon(
                    Icons.build_circle_rounded,
                    color: Colors.orange,
                    size: 30,
                  ),
                  title: const Text(
                    "Maintenance Tools",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.deepOrange,
                    ),
                  ),
                  subtitle: const Text(
                    "Perbaiki data dokter yang hilang dari list pasien.",
                    style: TextStyle(fontSize: 12),
                  ),
                  trailing: ElevatedButton(
                    onPressed: _fixDataDokter,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text("FIX DATA"),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
