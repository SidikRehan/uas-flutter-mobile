import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AdminBookingPage extends StatefulWidget {
  const AdminBookingPage({super.key});

  @override
  State<AdminBookingPage> createState() => _AdminBookingPageState();
}

class _AdminBookingPageState extends State<AdminBookingPage> {
  
  // 1. Fungsi Terima (Beri Nomor Antrean)
  void _terimaBooking(String docId, String namaDokter) async {
    var snapshot = await FirebaseFirestore.instance
        .collection('bookings')
        .where('nama_dokter', isEqualTo: namaDokter)
        .where('status', isEqualTo: 'Dalam Antrean')
        .get();

    int antrianBaru = snapshot.docs.length + 1;

    await FirebaseFirestore.instance.collection('bookings').doc(docId).update({
      'status': 'Dalam Antrean',
      'no_antrian': antrianBaru,
    });
  }

  // 2. Fungsi Tolak Booking
  void _tolakBooking(String docId) {
    FirebaseFirestore.instance.collection('bookings').doc(docId).update({
      'status': 'Ditolak',
      'no_antrian': null,
    });
  }

  // 3. BARU: Fungsi Batalkan Konfirmasi (Reset ke Menunggu)
  void _batalkanKonfirmasi(String docId) {
    FirebaseFirestore.instance.collection('bookings').doc(docId).update({
      'status': 'Menunggu Konfirmasi',
      'no_antrian': null, // Nomor antrean dihapus lagi
    });
  }

  void _selesaiBerobat(String docId) {
    FirebaseFirestore.instance.collection('bookings').doc(docId).update({
      'status': 'Selesai',
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Kelola Booking & Antrean")),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('bookings')
            .orderBy('created_at', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          var docs = snapshot.data!.docs;

          return ListView.builder(
            padding: const EdgeInsets.all(10),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              var data = docs[index].data() as Map<String, dynamic>;
              String docId = docs[index].id;
              String status = data['status'] ?? 'Menunggu';

              return Card(
                elevation: 3,
                margin: const EdgeInsets.symmetric(vertical: 8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: ListTile(
                  title: Text(data['nama_pasien'] ?? 'Pasien', style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text("Dr. ${data['nama_dokter']}\nStatus: $status"),
                  trailing: _buildActionButtons(status, docId, data['nama_dokter']),
                ),
              );
            },
          );
        },
      ),
    );
  }

  // Widget tombol aksi dinamis
  Widget _buildActionButtons(String status, String docId, String namaDokter) {
    if (status == 'Menunggu Konfirmasi') {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(icon: const Icon(Icons.check_circle, color: Colors.green), onPressed: () => _terimaBooking(docId, namaDokter)),
          IconButton(icon: const Icon(Icons.cancel, color: Colors.red), onPressed: () => _tolakBooking(docId)),
        ],
      );
    } else if (status == 'Dalam Antrean') {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Tombol Batal Konfirmasi (Undo)
          TextButton(
            onPressed: () => _batalkanKonfirmasi(docId),
            child: const Text("Batal", style: TextStyle(color: Colors.orange)),
          ),
          ElevatedButton(onPressed: () => _selesaiBerobat(docId), child: const Text("Selesai")),
        ],
      );
    }
    return const Icon(Icons.done_all, color: Colors.blue); // Untuk status Selesai
  }
}