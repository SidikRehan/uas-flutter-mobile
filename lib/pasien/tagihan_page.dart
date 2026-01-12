import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class TagihanPage extends StatelessWidget {
  const TagihanPage({super.key});

  @override
  Widget build(BuildContext context) {
    User? user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Info Tagihan & Biaya"),
        backgroundColor: Colors.green, // Warna uang/tagihan
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('bookings')
            .where('id_pasien', isEqualTo: user!.uid)
            .orderBy('created_at', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

          // Filter: Hanya tampilkan yang sudah ada BIAYA-nya
          var docs = snapshot.data!.docs.where((doc) {
            var data = doc.data() as Map<String, dynamic>;
            return data.containsKey('biaya') && data['biaya'] != null && data['biaya'].toString().isNotEmpty;
          }).toList();

          if (docs.isEmpty) {
            return const Center(child: Text("Belum ada tagihan pengobatan."));
          }

          return ListView.builder(
            padding: const EdgeInsets.all(15),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              var data = docs[index].data() as Map<String, dynamic>;
              String biaya = data['biaya'];
              String status = data['status'];
              
              // Cek Status Pembayaran (Simpelnya: Kalau status booking 'Selesai', kita anggap Lunas)
              bool isLunas = status == 'Selesai';

              return Card(
                elevation: 4,
                margin: const EdgeInsets.only(bottom: 15),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text("Dr. ${data['nama_dokter']}", style: const TextStyle(fontWeight: FontWeight.bold)),
                          Text(data['tanggal_booking'].toString().substring(0,10), style: const TextStyle(color: Colors.grey)),
                        ],
                      ),
                      const Divider(height: 30),
                      const Text("Total Tagihan", style: TextStyle(color: Colors.grey, fontSize: 14)),
                      const SizedBox(height: 5),
                      Text(
                        "Rp $biaya", 
                        style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.green),
                      ),
                      const SizedBox(height: 20),
                      Container(
                        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 20),
                        decoration: BoxDecoration(
                          color: isLunas ? Colors.green[100] : Colors.orange[100],
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          isLunas ? "LUNAS / SELESAI" : "MENUNGGU KASIR/ADMIN",
                          style: TextStyle(
                            color: isLunas ? Colors.green[800] : Colors.orange[800],
                            fontWeight: FontWeight.bold
                          ),
                        ),
                      )
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