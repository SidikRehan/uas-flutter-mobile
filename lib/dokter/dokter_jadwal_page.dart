import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class DokterJadwalPage extends StatelessWidget {
  const DokterJadwalPage({super.key});

  @override
  Widget build(BuildContext context) {
    User? currentUser = FirebaseAuth.instance.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Jadwal Praktik"),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      body: FutureBuilder<QuerySnapshot>(
        // Kita cari data dokter di collection 'doctors' yang uid-nya sama dengan yang login
        future: FirebaseFirestore.instance
            .collection('doctors')
            .where('uid', isEqualTo: currentUser?.uid)
            .get(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text("Data jadwal tidak ditemukan."));
          }

          // Ambil data pertama (karena 1 dokter = 1 profil)
          var data = snapshot.data!.docs.first.data() as Map<String, dynamic>;

          return Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              children: [
                Card(
                  elevation: 5,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                  color: Colors.blue,
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      children: [
                        const Icon(Icons.access_alarm, size: 60, color: Colors.white),
                        const SizedBox(height: 15),
                        Text(
                          data['Nama'] ?? "Dokter", 
                          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white),
                          textAlign: TextAlign.center,
                        ),
                        Text(
                          data['Poli'] ?? "-",
                          style: const TextStyle(fontSize: 18, color: Colors.white70),
                        ),
                        const Divider(color: Colors.white54, height: 30),
                        
                        // Detail Jadwal
                        _buildInfoRow("Hari", data['Hari'] ?? "-"),
                        const SizedBox(height: 10),
                        _buildInfoRow("Jam", data['Jam'] ?? "-"),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(color: Colors.white70, fontSize: 18)),
        Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
      ],
    );
  }
}