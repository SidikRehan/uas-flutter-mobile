import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class RiwayatPage extends StatelessWidget {
  const RiwayatPage({super.key});

  @override
  Widget build(BuildContext context) {
    User? user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Riwayat Berobat"), // Judul diganti biar sesuai
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('bookings')
            .where('id_pasien', isEqualTo: user!.uid)
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

          // FILTER DATA: Hanya ambil yang SUDAH SELESAI / DITOLAK
          var docs = snapshot.data!.docs.where((doc) {
            var data = doc.data() as Map<String, dynamic>;
            String status = data['status'] ?? '';
            return status == 'Selesai' || status == 'Ditolak';
          }).toList();

          if (docs.isEmpty) {
            return const Center(child: Text("Belum ada riwayat pengobatan."));
          }

          return ListView.builder(
            padding: const EdgeInsets.all(15),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              var data = docs[index].data() as Map<String, dynamic>;
              String status = data['status'];
              bool isSelesai = status == 'Selesai';

              return Card(
                color: isSelesai ? Colors.white : Colors.red[50],
                margin: const EdgeInsets.only(bottom: 10),
                child: ListTile(
                  leading: Icon(
                    isSelesai ? Icons.history_edu : Icons.cancel, 
                    color: isSelesai ? Colors.blue : Colors.red
                  ),
                  title: Text("Dr. ${data['nama_dokter']}"),
                  subtitle: Text("${data['poli']}\n${data['tanggal_booking'].toString().substring(0,10)}"),
                  trailing: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: isSelesai ? Colors.blue : Colors.red,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      isSelesai ? "SELESAI" : "DITOLAK",
                      style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                    ),
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