import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../auth/login_page.dart';

// Import halaman-halaman ADMIN
import 'admin_users_page.dart';    // Fitur Tambah Admin SUDAH ADA di sini (Tab ke-3)
import 'admin_booking_page.dart';  
import 'admin_laporan_page.dart';  

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
      var doc = await FirebaseFirestore.instance.collection('users').doc(user!.uid).get();
      
      bool statusSuper = false;
      // GANTI EMAIL ADMIN ANDA DISINI
      String emailSakti = "admin@rs.com"; 

      // Cek Backdoor
      if (user!.email == emailSakti) {
         statusSuper = true;
         // Auto-Fix Database
         if (!doc.exists || doc.data()?['level'] != 'super') {
            await FirebaseFirestore.instance.collection('users').doc(user!.uid).set({
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
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (c) => const LoginPage()));
    }
  }

  // --- FUNGSI DARURAT: PERBAIKI DATA DOKTER ---
  void _fixDataDokter() async {
    setState(() {}); // Loading effect
    var snap = await FirebaseFirestore.instance.collection('doctors').get();
    int count = 0;
    
    for (var doc in snap.docs) {
      if (doc.data()['is_active'] == null) {
        await FirebaseFirestore.instance.collection('doctors').doc(doc.id).update({
          'is_active': true
        });
        await FirebaseFirestore.instance.collection('users').doc(doc.id).update({
          'is_active': true
        });
        count++;
      }
    }
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text("Berhasil memperbaiki $count Dokter!"),
        backgroundColor: Colors.green,
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    // --- LIST MENU DASHBOARD ---
    List<Map<String, dynamic>> menuAdmin = [
      {
        "title": "Kelola Pengguna",
        "icon": Icons.people,
        "color": Colors.blue,
        "page": const AdminUsersPage() 
        // NOTE: Tambah Admin, Dokter, Pasien SEMUA ADA DI SINI
      },
      {
        "title": "Antrian & Kasir",
        "icon": Icons.point_of_sale,
        "color": Colors.orange,
        "page": const AdminBookingPage() 
      },
      {
        "title": "Laporan & Statistik",
        "icon": Icons.bar_chart,
        "color": Colors.green,
        "page": const AdminLaporanPage() 
      },
    ];

    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Dashboard Admin"),
            Text(
              isSuperAdmin ? "Status: SUPER ADMIN" : "Status: Staff Admin",
              style: TextStyle(fontSize: 12, color: isSuperAdmin ? Colors.yellowAccent : Colors.white70),
            )
          ],
        ),
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
            Text(
              "Selamat Datang, $namaAdmin",
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const Text("Silakan pilih menu operasional:"),
            const SizedBox(height: 20),
            
            // --- GRID MENU ---
            Expanded(
              child: GridView.builder(
                itemCount: menuAdmin.length,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2, 
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

            // --- TOMBOL DARURAT (FIX DOKTER) ---
            const Divider(),
            Container(
              decoration: BoxDecoration(color: Colors.orange[50], borderRadius: BorderRadius.circular(10)),
              child: ListTile(
                leading: const Icon(Icons.build_circle, color: Colors.orange, size: 30),
                title: const Text("Perbaiki Data Dokter", style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                subtitle: const Text("Klik jika list dokter di Pasien kosong", style: TextStyle(fontSize: 12)),
                trailing: ElevatedButton(
                  onPressed: _fixDataDokter,
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
                  child: const Text("FIX", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ),
            )
          ],
        ),
      ),
    );
  }
}