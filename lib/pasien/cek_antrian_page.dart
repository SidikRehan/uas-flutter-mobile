import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class CekAntrianPage extends StatelessWidget {
  const CekAntrianPage({super.key});

  @override
  Widget build(BuildContext context) {
    User? user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      appBar: AppBar(title: const Text("Status Antrean Aktif")),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('bookings')
            .where('id_pasien', isEqualTo: user!.uid)
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

          // Filter: Hanya tampilkan yang sedang antre atau menunggu konfirmasi
          var docs = snapshot.data!.docs.where((doc) {
            String status = doc['status'];
            return status == 'Menunggu Konfirmasi' || status == 'Dalam Antrean';
          }).toList();

          if (docs.isEmpty) return const Center(child: Text("Tidak ada antrean berjalan."));

          return ListView.builder(
            itemCount: docs.length,
            itemBuilder: (context, index) {
              var data = docs[index].data() as Map<String, dynamic>;
              bool sudahDisetujui = data['status'] == 'Dalam Antrean';

              return Card(
                margin: const EdgeInsets.all(15),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      Text("Dr. ${data['nama_dokter']}", style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                      const Divider(),
                      if (sudahDisetujui) ...[
                        const Text("NOMOR ANTREAN"),
                        Text("${data['no_antrian']}", style: const TextStyle(fontSize: 70, color: Colors.green, fontWeight: FontWeight.bold)),
                        const Text("Status: Dalam Antrean", style: TextStyle(color: Colors.green)),
                      ] else ...[
                        const Icon(Icons.hourglass_empty, size: 50, color: Colors.orange),
                        const SizedBox(height: 10),
                        const Text("MENUNGGU PERSETUJUAN ADMIN", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.orange)),
                      ],
                    ],
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