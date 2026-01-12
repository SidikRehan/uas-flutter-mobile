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
        title: const Text("Riwayat & Hasil Medis"),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 1,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('bookings')
            .where('id_pasien', isEqualTo: user!.uid)
            .orderBy('created_at', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) return const Center(child: Text("Error: Butuh Index (Cek Console)"));
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

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
              String status = data['status'] ?? 'Selesai';
              String tanggal = data['tanggal_booking'] != null 
                  ? data['tanggal_booking'].toString().substring(0, 10) : '-';
              bool isSelesai = status == 'Selesai';

              return Card(
                elevation: 3,
                margin: const EdgeInsets.only(bottom: 15),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                child: Theme(
                  data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                  child: ExpansionTile(
                    tilePadding: const EdgeInsets.symmetric(horizontal: 15, vertical: 8),
                    leading: CircleAvatar(
                      backgroundColor: isSelesai ? Colors.blue[50] : Colors.red[50],
                      child: Icon(isSelesai ? Icons.check : Icons.close, color: isSelesai ? Colors.blue : Colors.red),
                    ),
                    title: Text("Dr. ${data['nama_dokter']}", style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text("${data['poli']}\n$tanggal", style: const TextStyle(fontSize: 12, color: Colors.grey)),
                    trailing: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: isSelesai ? Colors.blue : Colors.red,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(isSelesai ? "SELESAI" : "DITOLAK", style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                    ),
                    
                    // --- BAGIAN DETAIL YANG BARU ---
                    children: [
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(15),
                        color: Colors.grey[50],
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Divider(),
                            if (isSelesai) ...[
                              _rowDetail("Diagnosa", data['diagnosa']),
                              _rowDetail("Tindakan", data['tindakan']),
                              _rowDetail("Resep Obat", data['resep_obat']),
                              const Divider(),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text("Total Biaya:", style: TextStyle(fontWeight: FontWeight.bold)),
                                  Text(
                                    "Rp ${data['biaya'] ?? '0'}", 
                                    style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green, fontSize: 16)
                                  ),
                                ],
                              ),
                            ] else ...[
                               const Text("Booking ditolak oleh admin.", style: TextStyle(color: Colors.red)),
                            ]
                          ],
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

  // Widget kecil buat nampilin baris data
  Widget _rowDetail(String label, String? value) {
    if (value == null || value.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 80, child: Text(label, style: const TextStyle(color: Colors.grey, fontSize: 12))),
          const Text(": "),
          Expanded(child: Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13))),
        ],
      ),
    );
  }
}