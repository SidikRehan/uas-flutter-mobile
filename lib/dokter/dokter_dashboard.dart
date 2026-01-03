import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../auth/login_page.dart';

class DokterDashboard extends StatefulWidget {
  const DokterDashboard({super.key});

  @override
  State<DokterDashboard> createState() => _DokterDashboardState();
}

class _DokterDashboardState extends State<DokterDashboard> {
  User? currentUser = FirebaseAuth.instance.currentUser;
  String? namaDokterSaatIni; // Variabel untuk menyimpan nama dokter yang login

  @override
  void initState() {
    super.initState();
    _getDataDokter();
  }

  // 1. Ambil Nama Dokter dari Database Users berdasarkan UID Login
  void _getDataDokter() async {
    if (currentUser != null) {
      try {
        var doc = await FirebaseFirestore.instance
            .collection('users')
            .doc(currentUser!.uid)
            .get();
        
        if (doc.exists && mounted) {
          setState(() {
            // Pastikan field 'nama' di user SAMA PERSIS dengan field 'nama_dokter' di booking
            namaDokterSaatIni = doc.data()?['nama'];
          });
        }
      } catch (e) {
        // Handle error
        print("Error ambil data dokter: $e");
      }
    }
  }

  void _inputMedis(String docId) {
    TextEditingController medisController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Input Rekam Medis"),
        content: TextField(
          controller: medisController,
          maxLines: 4,
          decoration: const InputDecoration(
            hintText: "Diagnosa & Resep Obat...",
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Batal")),
          ElevatedButton(
            onPressed: () {
              if (medisController.text.isNotEmpty) {
                FirebaseFirestore.instance.collection('bookings').doc(docId).update({
                  'hasil_medis': medisController.text,
                  'status': 'Menunggu Finalisasi Admin',
                });
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Terkirim ke Admin")));
              }
            },
            child: const Text("Kirim"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Jika nama dokter belum ke-load, tampilkan loading dulu
    if (namaDokterSaatIni == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Dashboard Dokter", style: TextStyle(fontSize: 16)),
            Text("dr. $namaDokterSaatIni", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          ],
        ),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await FirebaseAuth.instance.signOut();
              if (mounted) {
                Navigator.pushReplacement(context, MaterialPageRoute(builder: (c) => const LoginPage()));
              }
            },
          )
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        // --- INI BAGIAN PENTINGNYA ---
        // Kita filter 2 hal: 
        // 1. Status harus 'Dalam Antrean'
        // 2. Nama Dokter harus SAMA dengan dokter yang login
        stream: FirebaseFirestore.instance
            .collection('bookings')
            .where('status', isEqualTo: 'Dalam Antrean')
            .where('nama_dokter', isEqualTo: namaDokterSaatIni) // <-- FILTER INI YANG BIKIN SPESIFIK
            .snapshots(),
        builder: (context, snapshot) {
          // Cek Error Index (Biasanya muncul kalau pake 2 filter where)
          if (snapshot.hasError) {
             return Center(
               child: Padding(
                 padding: const EdgeInsets.all(20.0),
                 child: Text(
                   "Error Index: ${snapshot.error}\n\n(Buka terminal/debug console, klik link untuk buat Index)",
                   style: const TextStyle(color: Colors.red),
                   textAlign: TextAlign.center,
                 ),
               ),
             );
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          var docs = snapshot.data!.docs;

          if (docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.check_circle_outline, size: 80, color: Colors.teal),
                  const SizedBox(height: 10),
                  Text("Tidak ada pasien untuk dr. $namaDokterSaatIni saat ini."),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(10),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              var data = docs[index].data() as Map<String, dynamic>;
              
              return Card(
                elevation: 3,
                margin: const EdgeInsets.only(bottom: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                child: ListTile(
                  contentPadding: const EdgeInsets.all(15),
                  leading: CircleAvatar(
                    backgroundColor: Colors.teal.shade100,
                    radius: 25,
                    child: Text(
                      "${data['no_antrian'] ?? '?'}", 
                      style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.teal, fontSize: 18)
                    ),
                  ),
                  title: Text(data['nama_pasien'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 5),
                      Text("Poli: ${data['poli']}"),
                      Text("Jadwal: ${data['hari'] ?? '-'}"),
                    ],
                  ),
                  trailing: ElevatedButton(
                    onPressed: () => _inputMedis(docs[index].id),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.teal, 
                      foregroundColor: Colors.white
                    ),
                    child: const Text("Periksa"),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}