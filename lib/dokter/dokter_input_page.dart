import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class DokterInputPage extends StatelessWidget {
  const DokterInputPage({super.key});

  void _submitHasilMedis(BuildContext context, String docId, String hasil) {
    if (hasil.isEmpty) return;
    FirebaseFirestore.instance.collection('bookings').doc(docId).update({
      'hasil_medis': hasil,
      'status': 'Menunggu Finalisasi Admin', // Status berubah agar admin tahu dokter sudah input
    });
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Input Hasil Medis (Dokter)")),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('bookings')
            .where('status', isEqualTo: 'Dalam Antrean')
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          var docs = snapshot.data!.docs;
          return ListView.builder(
            itemCount: docs.length,
            itemBuilder: (context, index) {
              var data = docs[index].data() as Map<String, dynamic>;
              TextEditingController hasilController = TextEditingController();

              return Card(
                margin: const EdgeInsets.all(10),
                child: ListTile(
                  title: Text(data['nama_pasien']),
                  subtitle: Text("Keluhan/Poli: ${data['poli']}"),
                  trailing: ElevatedButton(
                    onPressed: () {
                      showDialog(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: const Text("Input Diagnosa"),
                          content: TextField(controller: hasilController, maxLines: 3),
                          actions: [
                            TextButton(onPressed: () => Navigator.pop(context), child: const Text("Batal")),
                            ElevatedButton(onPressed: () => _submitHasilMedis(context, docs[index].id, hasilController.text), child: const Text("Kirim ke Admin")),
                          ],
                        ),
                      );
                    },
                    child: const Text("Input Hasil"),
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