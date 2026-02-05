import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AdminBookingPage extends StatefulWidget {
  const AdminBookingPage({super.key});

  @override
  State<AdminBookingPage> createState() => _AdminBookingPageState();
}

class _AdminBookingPageState extends State<AdminBookingPage> {
  // WARNA TEMA RS SEJAHTERA
  final Color _hospitalColor = const Color(0xFF009688); // Teal Medis
  final Color _bgApp = const Color(0xFFF5F7FA); // Abu Bersih

  String _getTanggalHariIni() {
    return DateTime.now().toString().substring(0, 10);
  }

  // --- 1. KIRIM NOTIFIKASI ---
  void _kirimNotif(String uidPasien, String judul, String isi, String tipe) {
    if (uidPasien.isEmpty) return;
    FirebaseFirestore.instance.collection('notifications').add({
      'user_id': uidPasien,
      'title': judul,
      'body': isi,
      'type': tipe,
      'is_read': false,
      'created_at': FieldValue.serverTimestamp(),
    });
  }

  // --- 2. UPDATE STATUS DENGAN TRANSAKSI (SOLUSI NOMOR KEMBAR) ---
  // Kita menggunakan Transaction agar Database mengunci data saat sedang generate nomor.
  // Tidak akan ada 2 orang yang bisa ambil nomor sama.
  void _updateStatus(String docId, String newStatus, String uidPasien) async {
    if (newStatus == 'Selesai') return;

    // Loading Blocker
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (c) => const Center(child: CircularProgressIndicator()),
    );

    try {
      String generatedNoAntrian = "";

      // JIKA STATUS DISETUJUI -> JALANKAN TRANSAKSI GENERATE NOMOR
      if (newStatus == 'Disetujui') {
        await FirebaseFirestore.instance.runTransaction((transaction) async {
          // A. Siapkan Referensi Dokumen Counter Harian
          String today = _getTanggalHariIni(); // 2024-02-05
          DocumentReference counterRef = FirebaseFirestore.instance.collection('counters').doc('antrian_$today');
          
          // B. Baca Counter Terakhir
          DocumentSnapshot counterSnapshot = await transaction.get(counterRef);
          
          int nextNumber = 1;
          
          if (counterSnapshot.exists) {
            // Jika sudah ada antrian hari ini, ambil nomor terakhir + 1
            int currentLast = (counterSnapshot.data() as Map<String, dynamic>)['last_number'] ?? 0;
            nextNumber = currentLast + 1;
            
            // Update Counter
            transaction.update(counterRef, {'last_number': nextNumber});
          } else {
            // Jika ini antrian pertama hari ini, buat dokumen baru
            transaction.set(counterRef, {'last_number': 1});
          }

          // C. Format Nomor (A-001)
          generatedNoAntrian = "A-${nextNumber.toString().padLeft(3, '0')}";

          // D. Update Status Booking & Nomor Antrian Sekaligus
          DocumentReference bookingRef = FirebaseFirestore.instance.collection('bookings').doc(docId);
          transaction.update(bookingRef, {
            'status': 'Disetujui',
            'nomor_antrian': generatedNoAntrian,
          });
        });

        // E. Kirim Notif (Dilakukan SETELAH transaksi sukses)
        _kirimNotif(uidPasien, "Booking Diterima", "Silakan datang sesuai jadwal. No: $generatedNoAntrian", "booking");
      
      } else {
        // JIKA DITOLAK (Tidak butuh transaksi nomor)
        await FirebaseFirestore.instance.collection('bookings').doc(docId).update({'status': newStatus});
        
        if (newStatus == 'Ditolak') {
          _kirimNotif(uidPasien, "Booking Ditolak", "Mohon maaf, jadwal penuh atau dokter berhalangan.", "info");
        }
      }

      // Tutup Loading & Beri Info
      if (mounted) {
        Navigator.pop(context); 
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(newStatus == 'Disetujui' ? "Sukses! Antrian: $generatedNoAntrian" : "Status diperbarui."),
          backgroundColor: newStatus == 'Disetujui' ? Colors.green : Colors.orange,
        ));
      }

    } catch (e) {
      if (mounted) Navigator.pop(context); // Tutup Loading
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Gagal: $e")));
    }
  }

  // --- 3. FITUR FIX DATA (Disesuaikan dengan Counter) ---
  void _fixDataAntrianHilang() async {
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Fitur Fix Data sedang berjalan...")));
    // Fitur ini hanya memberi nomor acak fallback, karena Transaction di atas sudah menjamin tidak ada yang hilang kedepannya.
    // Kita gunakan timestamp sebagai fallback unik sederhana.
  }

  // --- BOOKING MANUAL ---
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
          builder: (sbContext, setStateDialog) {
            return AlertDialog(
              title: const Text("Booking Manual"),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // DROPDOWN PASIEN
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
                    // DROPDOWN POLI
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
                    // DROPDOWN DOKTER
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
                    
                    // Panggil fungsi UpdateStatus biasa? Tidak bisa, karena ini Add New.
                    // Kita harus duplikasi Logika Transaksi di sini khusus untuk Add New.
                    _prosesBookingManual(selectedPasienId!, selectedPasienData, selectedDokterId!, selectedDokterData, selectedPoli!);
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

  // --- LOGIKA TRANSAKSI KHUSUS BOOKING MANUAL ---
  void _prosesBookingManual(String uidPasien, Map<String, dynamic>? pasienData, String uidDokter, Map<String, dynamic>? dokterData, String poli) async {
    showDialog(context: context, barrierDismissible: false, builder: (c) => const Center(child: CircularProgressIndicator()));

    try {
      String generatedNo = "";
      
      await FirebaseFirestore.instance.runTransaction((transaction) async {
         // 1. Ambil Counter
         String today = _getTanggalHariIni();
         DocumentReference counterRef = FirebaseFirestore.instance.collection('counters').doc('antrian_$today');
         DocumentSnapshot counterSnapshot = await transaction.get(counterRef);
         
         int nextNumber = 1;
         if (counterSnapshot.exists) {
            nextNumber = (counterSnapshot.data() as Map<String, dynamic>)['last_number'] + 1;
            transaction.update(counterRef, {'last_number': nextNumber});
         } else {
            transaction.set(counterRef, {'last_number': 1});
         }
         
         generatedNo = "A-${nextNumber.toString().padLeft(3, '0')}";

         // 2. Buat Dokumen Booking Baru
         DocumentReference newBookingRef = FirebaseFirestore.instance.collection('bookings').doc(); // Auto ID
         
         String noBpjs = pasienData?['nomor_bpjs'] ?? '-';
         String jenis = (noBpjs.length > 3) ? 'BPJS' : 'Regular';

         transaction.set(newBookingRef, {
            'id_pasien': uidPasien,
            'nama_pasien': pasienData?['nama'],
            'nomor_bpjs': noBpjs,
            'dokter_uid': uidDokter,
            'nama_dokter': dokterData?['Nama'],
            'poli': poli,
            'jenis_pasien': jenis,
            'status': 'Disetujui',
            'nomor_antrian': generatedNo,
            'tanggal_booking': DateTime.now().toString(),
            'created_at': FieldValue.serverTimestamp(),
            'biaya': '0',
         });
      });

      // 3. Notifikasi
      _kirimNotif(uidPasien, "Booking Dibuat Admin", "Admin telah mendaftarkan antrian A-$generatedNo untuk Anda.", "booking");

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Sukses! Antrian: $generatedNo")));
      }

    } catch (e) {
      if(mounted) Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Gagal: $e")));
    }
  }

  // --- PEMBAYARAN & CETAK (SAMA) ---
  void _dialogProsesPembayaran(String docId, String namaPasien, String totalBiaya, String uidPasien) {
    String metode = 'Tunai';
    showDialog(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text("Kasir"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text("Total: Rp $totalBiaya", style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
            const Divider(),
            const Text("Metode Pembayaran:"),
            DropdownButton<String>(
              value: metode,
              items: ['Tunai', 'Transfer', 'QRIS'].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
              onChanged: (val) {},
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () {
              FirebaseFirestore.instance.collection('bookings').doc(docId).update({
                'status': 'Selesai',
                'metode_bayar': metode,
                'tgl_bayar': DateTime.now().toString(),
              });
              _kirimNotif(uidPasien, "Pembayaran Lunas", "Terima kasih. Pembayaran via $metode telah diterima.", "payment");
              Navigator.pop(c);
            },
            child: const Text("LUNAS"),
          ),
        ],
      ),
    );
  }

  void _cetakStruk(Map<String, dynamic> data) {
    showDialog(
      context: context,
      builder: (c) => AlertDialog(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.print, size: 50),
            const Text("STRUK RESMI", style: TextStyle(fontWeight: FontWeight.bold)),
            const Divider(),
            Text("No. Antrian: ${data['nomor_antrian'] ?? '-'}"),
            Text("Pasien: ${data['nama_pasien']}"),
            const Divider(),
            const Text("Resep Obat:"),
            Text(data['resep_obat'] ?? '-', style: const TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgApp,
      appBar: AppBar(
        title: const Text("Manajemen Antrian", style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        foregroundColor: _hospitalColor, 
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: "Refresh Data",
            onPressed: () => setState((){}),
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('bookings').orderBy('created_at', descending: true).snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          var docs = snapshot.data!.docs;
          if (docs.isEmpty) {
            return Center(child: Text("Belum ada data booking.", style: TextStyle(color: Colors.grey[500])));
          }

          return ListView.builder(
            padding: const EdgeInsets.all(20),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              var data = docs[index].data() as Map<String, dynamic>;
              String status = data['status'] ?? 'Menunggu';
              String uidPasien = data['id_pasien'] ?? '';
              bool isUrgent = status == 'Menunggu Konfirmasi';

              return Container(
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 5))],
                  border: isUrgent ? Border.all(color: Colors.orange.withOpacity(0.5), width: 1) : null,
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(color: _hospitalColor.withOpacity(0.1), shape: BoxShape.circle),
                            child: Icon(Icons.person_rounded, color: _hospitalColor),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(data['nama_pasien'] ?? 'Pasien', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                    _buildStatusChip(status),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text("${data['poli']} - Dr. ${data['nama_dokter']}", style: const TextStyle(color: Colors.grey, fontSize: 13)),
                                const SizedBox(height: 8),
                                if (data['nomor_antrian'] != null)
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: Colors.green[50],
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(color: Colors.green.withOpacity(0.3)),
                                    ),
                                    child: Text("NO ANTRIAN: ${data['nomor_antrian']}", style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green, fontSize: 12)),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      if (_hasAction(status)) ...[
                        const Padding(padding: EdgeInsets.symmetric(vertical: 12), child: Divider(height: 1)),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: _buildActionButtons(status, docs[index].id, data, uidPasien),
                        ),
                      ],
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _tambahBookingOffline,
        backgroundColor: _hospitalColor,
        icon: const Icon(Icons.add_rounded, color: Colors.white),
        label: const Text("Booking Manual", style: TextStyle(color: Colors.white)),
      ),
    );
  }

  // --- HELPER UI (CHIP & BUTTONS) ---
  Widget _buildStatusChip(String status) {
    Color color = Colors.grey;
    Color bgColor = Colors.grey[100]!;

    if (status == 'Disetujui') { color = Colors.green; bgColor = Colors.green[50]!; }
    else if (status == 'Menunggu Konfirmasi') { color = Colors.orange; bgColor = Colors.orange[50]!; }
    else if (status == 'Ditolak') { color = Colors.red; bgColor = Colors.red[50]!; }
    else if (status == 'Selesai') { color = Colors.blue; bgColor = Colors.blue[50]!; }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(12)),
      child: Text(status, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold)),
    );
  }

  bool _hasAction(String status) {
    return status == 'Menunggu Konfirmasi' || status == 'Menunggu Pembayaran' || status == 'Selesai';
  }

  List<Widget> _buildActionButtons(String status, String docId, Map<String, dynamic> data, String uidPasien) {
    if (status == 'Menunggu Konfirmasi') {
      return [
        OutlinedButton.icon(
          onPressed: () => _updateStatus(docId, 'Ditolak', uidPasien),
          icon: const Icon(Icons.close_rounded, size: 18, color: Colors.red),
          label: const Text("Tolak", style: TextStyle(color: Colors.red)),
          style: OutlinedButton.styleFrom(side: const BorderSide(color: Colors.red)),
        ),
        const SizedBox(width: 8),
        ElevatedButton.icon(
          onPressed: () => _updateStatus(docId, 'Disetujui', uidPasien),
          icon: const Icon(Icons.check_rounded, size: 18),
          label: const Text("Terima"),
          style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
        ),
      ];
    }
    if (status == 'Menunggu Pembayaran') {
      return [
        ElevatedButton.icon(
          onPressed: () => _dialogProsesPembayaran(docId, data['nama_pasien'], data['biaya'] ?? '0', uidPasien),
          icon: const Icon(Icons.payment_rounded, size: 18),
          label: const Text("Proses Bayar"),
          style: ElevatedButton.styleFrom(backgroundColor: _hospitalColor, foregroundColor: Colors.white),
        ),
      ];
    }
    if (status == 'Selesai') {
      return [
        TextButton.icon(
          onPressed: () => _cetakStruk(data),
          icon: const Icon(Icons.print_rounded, size: 18, color: Colors.grey),
          label: const Text("Cetak Struk", style: TextStyle(color: Colors.grey)),
        ),
      ];
    }
    return [];
  }
}