import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dokter_jadwal_page.dart';
import 'dokter_profile_page.dart';
import 'dokter_pemeriksaan_page.dart';

class DokterDashboard extends StatefulWidget {
  const DokterDashboard({super.key});

  @override
  State<DokterDashboard> createState() => _DokterDashboardState();
}

class _DokterDashboardState extends State<DokterDashboard> {
  int _selectedIndex = 0;
  final User? currentUser = FirebaseAuth.instance.currentUser;

  Widget _buildDaftarPasien() {
    return Scaffold(
      appBar: AppBar(title: const Text("Daftar Antrian Pasien"), automaticallyImplyLeading: false),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('bookings')
            .where('dokter_uid', isEqualTo: currentUser?.uid) 
            .where('status', isEqualTo: 'Disetujui') 
            // .orderBy(...) <--- SAYA HAPUS INI AGAR TIDAK LOADING TERUS
            .snapshots(),
        builder: (context, snapshot) {
          // Tambahkan Cek Error agar ketahuan kalau ada masalah lain
          if (snapshot.hasError) {
            return Center(child: Text("Error: ${snapshot.error}"));
          }

          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          
          var docs = snapshot.data!.docs;

          if (docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.people_outline, size: 80, color: Colors.grey[300]),
                  const SizedBox(height: 10),
                  const Text("Belum ada pasien antri saat ini.", style: TextStyle(color: Colors.grey)),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(10),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              var data = docs[index].data() as Map<String, dynamic>;
              String docId = docs[index].id;

              return Card(
                color: Colors.blue[50],
                margin: const EdgeInsets.only(bottom: 10),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Colors.blue,
                    child: Text(
                      data['nomor_antrian'] != null ? data['nomor_antrian'].toString().split('-').last : "${index + 1}",
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                  ),
                  title: Text(data['nama_pasien'] ?? 'Pasien', style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text("Keluhan: ${data['keluhan'] ?? '-'}\nJenis: ${data['jenis_pasien']}"),
                  trailing: const Icon(Icons.arrow_forward_ios, color: Colors.blue),
                  isThreeLine: true,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => DokterPemeriksaanPage(
                          bookingId: docId,       
                          dataPasien: data,       
                        ),
                      ),
                    );
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final List<Widget> pages = [
      _buildDaftarPasien(),     
      const DokterJadwalPage(), 
      const DokterProfilePage(),
    ];

    return Scaffold(
      body: pages[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (index) => setState(() => _selectedIndex = index),
        selectedItemColor: Colors.blue[800],
        unselectedItemColor: Colors.grey,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.people), label: "Pasien"),
          BottomNavigationBarItem(icon: Icon(Icons.calendar_today), label: "Jadwal"),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: "Profil"),
        ],
      ),
    );
  }
}