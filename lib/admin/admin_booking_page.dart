import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AdminBookingPage extends StatefulWidget {
  const AdminBookingPage({super.key});

  @override
  State<AdminBookingPage> createState() => _AdminBookingPageState();
}

class _AdminBookingPageState extends State<AdminBookingPage> {
  // --- HELPER DATE ---
  String _getTanggalHariIni() {
    return DateTime.now().toString().substring(0, 10); 
  }

  // --- 1. FUNGSI KIRIM NOTIFIKASI (WAJIB ADA) ---
  void _kirimNotif(String uidPasien, String judul, String isi, String tipe) {
    if (uidPasien.isEmpty) return; // Jaga-jaga kalau pasien offline tanpa UID
    FirebaseFirestore.instance.collection('notifications').add({
      'user_id': uidPasien,
      'title': judul,
      'body': isi,
      'type': tipe, // 'booking', 'payment', 'medical'
      'is_read': false,
      'created_at': FieldValue.serverTimestamp(),
    });
  }

  // --- GENERATE NOMOR ANTRIAN ---
  Future<String> _generateNoAntrian() async {
    try {
      String today = _getTanggalHariIni();
      QuerySnapshot snapshot = await FirebaseFirestore.instance
          .collection('bookings')
          .where('status', isEqualTo: 'Disetujui')
          .get();
      
      int countHariIni = 0;
      for (var doc in snapshot.docs) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        String tglBooking = data['tanggal_booking'].toString();
        if (tglBooking.contains(today)) countHariIni++;
      }
      int urutan = countHariIni + 1; 
      return "A-${urutan.toString().padLeft(3, '0')}"; 
    } catch (e) {
      return "A-001"; 
    }
  }

  // --- FITUR FIX DATA ---
  void _fixDataAntrianHilang() async {
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Sedang memperbaiki data...")));
    try {
      var snapshot = await FirebaseFirestore.instance.collection('bookings').where('status', isEqualTo: 'Disetujui').get();
      int fixedCount = 0;
      for (var doc in snapshot.docs) {
        var data = doc.data();
        if (data['nomor_antrian'] == null || data['nomor_antrian'] == '') {
          String noBaru = await _generateNoAntrian();
          await FirebaseFirestore.instance.collection('bookings').doc(doc.id).update({'nomor_antrian': noBaru});
          fixedCount++;
        }
      }
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Selesai! $fixedCount data diperbaiki."), backgroundColor: Colors.green));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
    }
  }

  // --- FUNGSI UPDATE STATUS (DENGAN NOTIFIKASI) ---
  void _updateStatus(String docId, String newStatus, String uidPasien) async {
    if (newStatus == 'Selesai') return; 

    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Memproses..."), duration: Duration(milliseconds: 500)));
    Map<String, dynamic> dataUpdate = {'status': newStatus};
    String pesanNotif = "";

    // Jika Disetujui, Generate Nomor
    if (newStatus == 'Disetujui') {
      String noAntrian = await _generateNoAntrian();
      dataUpdate['nomor_antrian'] = noAntrian;
      pesanNotif = "Booking Dikonfirmasi! No Antrian: $noAntrian";
      
      // Kirim Notif Terima
      _kirimNotif(uidPasien, "Booking Diterima", "Silakan datang sesuai jadwal. No: $noAntrian", "booking");
    } 
    else if (newStatus == 'Ditolak') {
      // Kirim Notif Tolak
      _kirimNotif(uidPasien, "Booking Ditolak", "Mohon maaf, jadwal penuh atau dokter berhalangan.", "info");
    }

    await FirebaseFirestore.instance.collection('bookings').doc(docId).update(dataUpdate);
  }

  // --- FUNGSI BOOKING MANUAL (Offline) ---
  void _tambahBookingOffline() {
    String? selectedPasienId;
    Map<String, dynamic>? selectedPasienData;
    String? selectedPoli;
    String? selectedDokterId; 
    Map<String, dynamic>? selectedDokterData;

    showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              title: const Text("Booking Manual"),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                      StreamBuilder<QuerySnapshot>(
                      stream: FirebaseFirestore.instance.collection('users').where('role', isEqualTo: 'pasien').snapshots(),
                      builder: (context, snapshot) {
                        if (!snapshot.hasData) return const LinearProgressIndicator();
                        return DropdownButtonFormField<String>(
                          isExpanded: true, hint: const Text("Pilih Pasien"),
                          items: snapshot.data!.docs.map((doc) {
                             var data = doc.data() as Map<String, dynamic>;
                             return DropdownMenuItem(value: doc.id, onTap: () => selectedPasienData = data, child: Text(data['nama'] ?? '-'));
                          }).toList(),
                          onChanged: (val) => setStateDialog(() => selectedPasienId = val),
                        );
                      },
                    ),
                    const SizedBox(height: 10),
                    StreamBuilder<QuerySnapshot>(
                      stream: FirebaseFirestore.instance.collection('polis').orderBy('nama_poli').snapshots(),
                      builder: (context, snapshot) {
                        if (!snapshot.hasData) return const SizedBox();
                        return DropdownButtonFormField<String>(
                          isExpanded: true, hint: const Text("Pilih Poli"),
                          items: snapshot.data!.docs.map((doc) => DropdownMenuItem(value: doc['nama_poli'] as String, child: Text(doc['nama_poli']))).toList(),
                          onChanged: (val) => setStateDialog(() { selectedPoli = val; selectedDokterId = null; }),
                        );
                      },
                    ),
                    const SizedBox(height: 10),
                    if (selectedPoli != null)
                      StreamBuilder<QuerySnapshot>(
                        stream: FirebaseFirestore.instance.collection('doctors').where('Poli', isEqualTo: selectedPoli).snapshots(),
                        builder: (context, snapshot) {
                          if (!snapshot.hasData) return const SizedBox();
                          return DropdownButtonFormField<String>(
                            isExpanded: true, hint: const Text("Pilih Dokter"),
                            items: snapshot.data!.docs.map((doc) {
                               var data = doc.data() as Map<String, dynamic>;
                               return DropdownMenuItem(value: doc.id, onTap: () => selectedDokterData = data, child: Text(data['Nama'] ?? '-'));
                            }).toList(),
                            onChanged: (val) => setStateDialog(() => selectedDokterId = val),
                          );
                        },
                      ),
                  ],
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text("Batal")),
                ElevatedButton(
                  onPressed: () async {
                    if (selectedPasienId == null || selectedDokterId == null) return;
                    Navigator.pop(dialogContext);
                    
                    String noAntrian = await _generateNoAntrian();
                    String noBpjs = selectedPasienData?['nomor_bpjs'] ?? '-';
                    String jenis = (noBpjs.length > 3) ? 'BPJS' : 'Regular';

                    await FirebaseFirestore.instance.collection('bookings').add({
                      'id_pasien': selectedPasienId,
                      'nama_pasien': selectedPasienData?['nama'],
                      'nomor_bpjs': noBpjs,
                      'dokter_uid': selectedDokterId,
                      'nama_dokter': selectedDokterData?['Nama'],
                      'poli': selectedDokterData?['Poli'],
                      'jenis_pasien': jenis,
                      'status': 'Disetujui',
                      'nomor_antrian': noAntrian,
                      'tanggal_booking': DateTime.now().toString(),
                      'created_at': FieldValue.serverTimestamp(),
                      'biaya': '0',
                    });
                    
                    // KIRIM NOTIFIKASI JUGA UTK BOOKING MANUAL
                    _kirimNotif(selectedPasienId!, "Booking Dibuat Admin", "Admin telah mendaftarkan antrian A-$noAntrian untuk Anda.", "booking");

                    if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Sukses! Antrian: $noAntrian")));
                  },
                  child: const Text("Simpan"),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // --- DIALOG PEMBAYARAN (DENGAN NOTIFIKASI) ---
  void _dialogProsesPembayaran(String docId, String namaPasien, String totalBiaya, String uidPasien) {
    String metode = 'Tunai';
    showDialog(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text("Kasir"),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          Text("Total: Rp $totalBiaya", style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
          const Divider(),
          const Text("Metode Pembayaran:"),
          DropdownButton<String>(
            value: metode,
            items: ['Tunai', 'Transfer', 'QRIS'].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
            onChanged: (val) {}, 
          )
        ]),
        actions: [
          ElevatedButton(
            onPressed: () {
               // Update Lunas
               FirebaseFirestore.instance.collection('bookings').doc(docId).update({'status': 'Selesai', 'metode_bayar': metode, 'tgl_bayar': DateTime.now().toString()});
               
               // KIRIM NOTIFIKASI LUNAS
               _kirimNotif(uidPasien, "Pembayaran Lunas", "Terima kasih. Pembayaran via $metode telah diterima.", "payment");

               Navigator.pop(c);
            },
            child: const Text("LUNAS"),
          )
        ],
      )
    );
  }

  // --- CETAK STRUK ---
  void _cetakStruk(Map<String, dynamic> data) {
    showDialog(context: context, builder: (c) => AlertDialog(
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        const Icon(Icons.print, size: 50),
        const Text("STRUK RESMI", style: TextStyle(fontWeight: FontWeight.bold)),
        const Divider(),
        Text("No. Antrian: ${data['nomor_antrian'] ?? '-'}"), 
        Text("Pasien: ${data['nama_pasien']}"),
        const Divider(),
        const Text("Resep Obat:"),
        Text(data['resep_obat'] ?? '-', style: const TextStyle(fontWeight: FontWeight.bold)),
      ]),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Kasir & Antrian"), 
        backgroundColor: Colors.blue[900], 
        foregroundColor: Colors.white,
        actions: [
          IconButton(icon: const Icon(Icons.build), tooltip: "Perbaiki Nomor Antrian Hilang", onPressed: _fixDataAntrianHilang)
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('bookings').orderBy('created_at', descending: true).snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          var docs = snapshot.data!.docs;

          return ListView.builder(
            padding: const EdgeInsets.all(10),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              var data = docs[index].data() as Map<String, dynamic>;
              String status = data['status'] ?? 'Menunggu';
              String uidPasien = data['id_pasien'] ?? ''; // PENTING: Ambil UID Pasien

              return Card(
                child: ListTile(
                  title: Text(data['nama_pasien'] ?? 'Pasien'),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("${data['poli']} - Dr. ${data['nama_dokter']}"),
                      Text("Status: $status", style: TextStyle(color: status == 'Disetujui' ? Colors.blue : Colors.grey)),
                      if (data['nomor_antrian'] != null)
                          Text("NO ANTRIAN: ${data['nomor_antrian']}", style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green))
                    ],
                  ),
                  isThreeLine: true,
                  // PENTING: Pass uidPasien ke _buildAction
                  trailing: _buildAction(status, docs[index].id, data, uidPasien),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(onPressed: _tambahBookingOffline, child: const Icon(Icons.add)),
    );
  }

  // --- BUILD ACTION (DENGAN UID PASIEN) ---
  Widget? _buildAction(String status, String docId, Map<String, dynamic> data, String uidPasien) {
    if (status == 'Menunggu Konfirmasi') {
      return PopupMenuButton<String>(
        onSelected: (val) => _updateStatus(docId, val, uidPasien), // Pass uidPasien
        itemBuilder: (context) => [
          const PopupMenuItem(value: 'Disetujui', child: Text("Terima Booking")),
          const PopupMenuItem(value: 'Ditolak', child: Text("Tolak")),
        ]
      );
    }
    if (status == 'Menunggu Pembayaran') {
      return IconButton(icon: const Icon(Icons.payment, color: Colors.green), onPressed: () => _dialogProsesPembayaran(docId, data['nama_pasien'], data['biaya'] ?? '0', uidPasien)); // Pass uidPasien
    }
    if (status == 'Selesai') {
      return IconButton(icon: const Icon(Icons.print), onPressed: () => _cetakStruk(data));
    }
    return null;
  }
}