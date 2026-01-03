import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class BookingPage extends StatefulWidget {
  // --- INI BAGIAN YANG KURANG SEBELUMNYA ---
  final String? poliPilihan; 

  const BookingPage({super.key, this.poliPilihan});
  // -----------------------------------------

  @override
  State<BookingPage> createState() => _BookingPageState();
}

class _BookingPageState extends State<BookingPage> {
  
  // --- FUNGSI SIMPAN ---
  void _simpanBooking(Map<String, dynamic> dokterData) async {
    User? user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Anda harus login terlebih dahulu")),
      );
      return;
    }

    // Ambil data dokter (Cek huruf kecil/besar biar aman)
    String namaDokter = dokterData['nama'] ?? dokterData['Nama'] ?? 'Dokter Tanpa Nama';
    String poliDokter = dokterData['poli'] ?? dokterData['Poli'] ?? '-';

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      // Ambil Nama Pasien dari tabel users
      DocumentSnapshot userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      
      // Handle jika field nama pasien huruf kecil/besar
      var userData = userDoc.data() as Map<String, dynamic>?;
      String namaPasien = userData?['nama'] ?? userData?['Nama'] ?? 'Pasien';

      await FirebaseFirestore.instance.collection('bookings').add({
        'id_pasien': user.uid,
        'nama_pasien': namaPasien,
        'nama_dokter': namaDokter,
        'poli': poliDokter,
        'status': 'Menunggu Konfirmasi',
        'tanggal_booking': DateTime.now().toString(),
        'created_at': FieldValue.serverTimestamp(),
      });

      if (mounted) Navigator.pop(context); // Tutup Loading

      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text("Berhasil!"),
            content: const Text("Booking tersimpan. Silakan cek menu Riwayat/Dashboard."),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(context); // Tutup dialog
                  Navigator.pop(context); // Tutup BookingPage
                  Navigator.pop(context); // Tutup PoliPage (Balik ke Home)
                },
                child: const Text("OK"),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Gagal booking: $e")),
      );
    }
  }

  // --- FUNGSI KONFIRMASI ---
  void _konfirmasiBooking(Map<String, dynamic> dokterData) {
    String namaDokter = dokterData['nama'] ?? dokterData['Nama'] ?? 'Dokter Tanpa Nama';
    String poliDokter = dokterData['poli'] ?? dokterData['Poli'] ?? '-';
    String jadwal = "${dokterData['hari'] ?? dokterData['Hari'] ?? '-'} (${dokterData['jam'] ?? dokterData['Jam'] ?? '-'})";

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Konfirmasi Booking"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Anda akan melakukan booking ke:"),
            const SizedBox(height: 10),
            Text("Dr. $namaDokter", style: const TextStyle(fontWeight: FontWeight.bold)),
            Text("Poli: $poliDokter"),
            Text("Jadwal: $jadwal"),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Batal", style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _simpanBooking(dokterData);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.blue, foregroundColor: Colors.white),
            child: const Text("Ya, Booking"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    Query query = FirebaseFirestore.instance.collection('doctors');

    // MENGGUNAKAN DATA YANG DIKIRIM DARI POLI PAGE
    if (widget.poliPilihan != null) {
      // Pastikan field di database 'Poli' (Huruf Besar) atau sesuaikan
      query = query.where('Poli', isEqualTo: widget.poliPilihan);
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.poliPilihan ?? "Pilih Dokter"),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: query.snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text("Error: ${snapshot.error}"));
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.person_off, size: 60, color: Colors.grey),
                  const SizedBox(height: 10),
                  Text(
                    widget.poliPilihan != null 
                    ? "Tidak ada dokter di ${widget.poliPilihan}" 
                    : "Belum ada data dokter.",
                    style: const TextStyle(color: Colors.grey),
                  ),
                ],
              ),
            );
          }

          var documents = snapshot.data!.docs;

          return ListView.builder(
            padding: const EdgeInsets.all(10),
            itemCount: documents.length,
            itemBuilder: (context, index) {
              var data = documents[index].data() as Map<String, dynamic>;

              String namaTampil = data['nama'] ?? data['Nama'] ?? "Tanpa Nama";
              String poliTampil = data['poli'] ?? data['Poli'] ?? "-";
              String hariTampil = data['hari'] ?? data['Hari'] ?? "-";
              String jamTampil = data['jam'] ?? data['Jam'] ?? "-";

              return Card(
                elevation: 3,
                margin: const EdgeInsets.only(bottom: 15),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                child: ListTile(
                  contentPadding: const EdgeInsets.all(15),
                  leading: CircleAvatar(
                    radius: 30,
                    backgroundColor: Colors.blue[100],
                    child: const Icon(Icons.person, color: Colors.blue, size: 30),
                  ),
                  title: Text(
                    namaTampil,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 5),
                      Text("Poli: $poliTampil"),
                      Text("Jadwal: $hariTampil ($jamTampil)", style: const TextStyle(color: Colors.green)),
                    ],
                  ),
                  trailing: ElevatedButton(
                    onPressed: () => _konfirmasiBooking(data),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    ),
                    child: const Text("Pilih"),
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