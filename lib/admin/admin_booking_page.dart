import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AdminBookingPage extends StatefulWidget {
  const AdminBookingPage({super.key});

  @override
  State<AdminBookingPage> createState() => _AdminBookingPageState();
}

class _AdminBookingPageState extends State<AdminBookingPage> {
  // --- HELPER DATE & TIME ---
  String _getNamaHariIni() {
    int weekday = DateTime.now().weekday;
    switch (weekday) {
      case 1: return "Senin";
      case 2: return "Selasa";
      case 3: return "Rabu";
      case 4: return "Kamis";
      case 5: return "Jumat";
      case 6: return "Sabtu";
      case 7: return "Minggu";
      default: return "";
    }
  }

  // --- VALIDASI JADWAL DOKTER ---
  bool _isDokterBuka(String jadwalHari, String jadwalJam) {
    // Logic sederhana: dianggap buka untuk memudahkan testing
    return true; 
  }

  // --- FUNGSI BOOKING MANUAL (OFFLINE) ---
  void _tambahBookingOffline() {
    String? selectedPasienId;
    Map<String, dynamic>? selectedPasienData;
    String? selectedPoli;
    String? selectedDokterId; 
    Map<String, dynamic>? selectedDokterData;

    showDialog(
      context: context,
      builder: (dialogContext) { // Pakai nama dialogContext biar aman
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              title: const Text("Booking Manual (Offline)"),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text("1. Pilih Pasien:", style: TextStyle(fontWeight: FontWeight.bold)),
                    StreamBuilder<QuerySnapshot>(
                      stream: FirebaseFirestore.instance.collection('users').where('role', isEqualTo: 'pasien').snapshots(),
                      builder: (context, snapshot) {
                        if (!snapshot.hasData) return const Text("Loading...");
                        var listPasien = snapshot.data!.docs;
                        return DropdownButtonFormField<String>(
                          isExpanded: true,
                          hint: const Text("Cari Nama Pasien"),
                          value: selectedPasienId,
                          items: listPasien.map((doc) {
                             var data = doc.data() as Map<String, dynamic>;
                             return DropdownMenuItem<String>(
                               value: doc.id,
                               onTap: () => selectedPasienData = data,
                               child: Text("${data['nama']} (${data['nomor_bpjs'] ?? '-'})"),
                             );
                          }).toList(),
                          onChanged: (val) => setStateDialog(() => selectedPasienId = val),
                        );
                      },
                    ),
                    const SizedBox(height: 20), const Divider(), const SizedBox(height: 10),
                    
                    const Text("2. Pilih Poli Tujuan:", style: TextStyle(fontWeight: FontWeight.bold)),
                    StreamBuilder<QuerySnapshot>(
                      stream: FirebaseFirestore.instance.collection('polis').orderBy('nama_poli').snapshots(),
                      builder: (context, snapshot) {
                        if (!snapshot.hasData) return const Text("Loading Poli...");
                        var listPoli = snapshot.data!.docs;
                        
                        return DropdownButtonFormField<String>(
                          isExpanded: true,
                          hint: const Text("Pilih Poli Dahulu"),
                          value: selectedPoli,
                          items: listPoli.map((doc) {
                            var data = doc.data() as Map<String, dynamic>;
                            return DropdownMenuItem<String>(
                              value: data['nama_poli'],
                              child: Text(data['nama_poli']),
                            );
                          }).toList(),
                          onChanged: (val) {
                            setStateDialog(() {
                              selectedPoli = val;
                              selectedDokterId = null; 
                              selectedDokterData = null;
                            });
                          },
                        );
                      },
                    ),

                    const SizedBox(height: 15),
                    
                    const Text("3. Pilih Dokter:", style: TextStyle(fontWeight: FontWeight.bold)),
                    if (selectedPoli == null)
                      const Padding(padding: EdgeInsets.only(top: 8.0), child: Text(" (Silakan pilih Poli di atas terlebih dahulu)", style: TextStyle(color: Colors.grey, fontSize: 12)))
                    else
                      StreamBuilder<QuerySnapshot>(
                        stream: FirebaseFirestore.instance.collection('doctors').where('Poli', isEqualTo: selectedPoli).snapshots(),
                        builder: (context, snapshot) {
                          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                            return const Padding(padding: EdgeInsets.only(top: 8.0), child: Text("Tidak ada dokter.", style: TextStyle(color: Colors.red)));
                          }
                          var listDokter = snapshot.data!.docs;
                          return DropdownButtonFormField<String>(
                            isExpanded: true,
                            hint: const Text("Pilih Dokter"),
                            value: selectedDokterId,
                            items: listDokter.map((doc) {
                               var data = doc.data() as Map<String, dynamic>;
                               String hari = data['Hari'] ?? '';
                               String jam = data['Jam'] ?? '';
                               bool isOpen = _isDokterBuka(hari, jam);
                               return DropdownMenuItem<String>(
                                 value: doc.id,
                                 onTap: () => selectedDokterData = data,
                                 child: Text("${data['Nama']} ${isOpen ? '' : '(TUTUP)'}", style: TextStyle(color: isOpen ? Colors.black : Colors.red, fontWeight: isOpen ? FontWeight.normal : FontWeight.bold)),
                               );
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
                    if (selectedPasienId == null || selectedDokterId == null) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Lengkapi semua data!")));
                      return;
                    }
                    // Tutup dialog dulu
                    Navigator.pop(dialogContext);
                    // Baru proses
                    _prosesSimpanBooking(selectedPasienId, selectedPasienData, selectedDokterId, selectedDokterData);
                  },
                  child: const Text("Buat Booking"),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // --- SIMPAN BOOKING KE FIREBASE ---
  void _prosesSimpanBooking(String? pid, Map<String, dynamic>? pData, String? did, Map<String, dynamic>? dData) async {
      try {
        String noBpjs = pData?['nomor_bpjs'] ?? '-';
        String jenisPasien = (noBpjs != '-' && noBpjs.isNotEmpty) ? 'BPJS' : 'Regular';
        await FirebaseFirestore.instance.collection('bookings').add({
          'id_pasien': pid,
          'nama_pasien': pData?['nama'] ?? 'Pasien Offline',
          'nomor_bpjs': noBpjs,
          'dokter_uid': did,
          'nama_dokter': dData?['Nama'] ?? 'Dokter',
          'poli': dData?['Poli'] ?? 'Umum',
          'jenis_pasien': jenisPasien,
          'status': 'Disetujui', 
          'tanggal_booking': DateTime.now().toString(),
          'created_at': FieldValue.serverTimestamp(),
          'hasil_medis': '',
          'biaya': '0',
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Booking Berhasil!")));
        }
      } catch (e) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Gagal: $e")));
      }
  }

  // --- FUNGSI UPDATE STATUS ---
  void _updateStatus(String docId, String newStatus) {
    if (newStatus == 'Selesai') return; // Selesai harus lewat proses bayar
    FirebaseFirestore.instance.collection('bookings').doc(docId).update({'status': newStatus});
  }

  // --- FUNGSI KASIR: PROSES PEMBAYARAN ---
  void _dialogProsesPembayaran(String docId, String namaPasien, String totalBiaya) {
    String selectedMetode = 'Tunai'; 
    final List<String> metodeList = ['Tunai', 'Transfer', 'QRIS'];

    showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              title: const Text("Konfirmasi Pembayaran"),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("Pasien: $namaPasien"),
                  const SizedBox(height: 10),
                  Text("Rp $totalBiaya", style: const TextStyle(fontSize: 30, fontWeight: FontWeight.bold, color: Colors.green)),
                  const SizedBox(height: 20),
                  const Text("Metode Bayar:", style: TextStyle(fontWeight: FontWeight.bold)),
                  Wrap(
                    spacing: 10,
                    children: metodeList.map((metode) {
                      bool isSelected = selectedMetode == metode;
                      return ChoiceChip(
                        label: Text(metode),
                        selected: isSelected,
                        onSelected: (val) => setStateDialog(() => selectedMetode = metode),
                      );
                    }).toList(),
                  ),
                ],
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text("Batal")),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
                  icon: const Icon(Icons.print),
                  label: const Text("TERIMA & LUNAS"),
                  onPressed: () async {
                    await FirebaseFirestore.instance.collection('bookings').doc(docId).update({
                      'status': 'Selesai',
                      'metode_bayar': selectedMetode,
                      'tgl_bayar': DateTime.now().toString(),
                    });
                    
                    if (mounted) {
                      Navigator.pop(dialogContext);
                      ScaffoldMessenger.of(this.context).showSnackBar(SnackBar(content: Text("Pembayaran ($selectedMetode) Berhasil!")));
                    }
                  },
                )
              ],
            );
          },
        );
      },
    );
  }

  // --- FITUR BARU: CETAK STRUK & RESEP (FIXED DIVIDER) ---
  void _cetakStruk(Map<String, dynamic> data) {
    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          child: Container(
            padding: const EdgeInsets.all(20),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.local_hospital, size: 50, color: Colors.blue),
                  const Text("RUMAH SAKIT SEHAT", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                  const Divider(thickness: 2), // Divider Biasa
                  
                  _rowStruk("Pasien", data['nama_pasien']),
                  _rowStruk("Dokter", data['nama_dokter']),
                  _rowStruk("Poli", data['poli']),
                  
                  // Divider putus-putus manual (diganti Divider biasa tapi tipis)
                  const Divider(thickness: 0.5, color: Colors.grey), 
                  
                  // RESEP OBAT
                  const Align(alignment: Alignment.centerLeft, child: Text("RESEP OBAT:", style: TextStyle(fontWeight: FontWeight.bold))),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(10),
                    color: Colors.grey[100],
                    child: Text(data['resep_obat'] ?? "- Tidak ada resep -", style: const TextStyle(fontFamily: 'Monospace')),
                  ),
                  const SizedBox(height: 10),
                  const Divider(thickness: 0.5, color: Colors.grey),

                  // TOTAL
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text("TOTAL BAYAR", style: TextStyle(fontWeight: FontWeight.bold)),
                      Text("Rp ${data['biaya']}", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                    ],
                  ),
                  
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.print),
                      label: const Text("PRINT SEKARANG"),
                    ),
                  )
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _rowStruk(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.grey)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Kasir & Antrian"), backgroundColor: Colors.blue, foregroundColor: Colors.white),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('bookings').orderBy('created_at', descending: true).snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          var docs = snapshot.data!.docs;
          if (docs.isEmpty) return const Center(child: Text("Belum ada booking masuk."));

          return ListView.builder(
            padding: const EdgeInsets.all(10),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              var data = docs[index].data() as Map<String, dynamic>;
              String docId = docs[index].id;
              String status = data['status'] ?? 'Menunggu';
              String totalTagihan = data['biaya'] ?? '0';

              Color statusColor = Colors.grey;
              if (status == 'Disetujui') statusColor = Colors.blue;
              if (status == 'Selesai') statusColor = Colors.green;
              if (status == 'Menunggu Pembayaran') statusColor = Colors.orange; 
              if (status == 'Ditolak' || status == 'Dibatalkan') statusColor = Colors.red;

              return Card(
                margin: const EdgeInsets.only(bottom: 10),
                child: ListTile(
                  title: Text(data['nama_pasien'] ?? 'Pasien', style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text("Dr. ${data['nama_dokter']} (${data['poli']})"),
                      const SizedBox(height: 5),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2), 
                        decoration: BoxDecoration(color: statusColor, borderRadius: BorderRadius.circular(5)), 
                        child: Text(status, style: const TextStyle(color: Colors.white, fontSize: 10))
                      ),
                  ]),
                  isThreeLine: true,
                  // Mengirimkan DATA lengkap ke fungsi tombol
                  trailing: _buildTrailingButton(status, docId, data['nama_pasien'], totalTagihan, data),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _tambahBookingOffline,
        icon: const Icon(Icons.add_task),
        label: const Text("Booking Manual"),
        backgroundColor: Colors.indigo,
      ),
    );
  }

  // --- LOGIKA TOMBOL BERDASARKAN STATUS ---
  Widget? _buildTrailingButton(String status, String docId, String nama, String tagihan, Map<String, dynamic> data) {
    if (status == 'Menunggu Konfirmasi') {
      return PopupMenuButton<String>(
        onSelected: (val) => _updateStatus(docId, val),
        itemBuilder: (context) => [
          const PopupMenuItem(value: 'Disetujui', child: Text("Terima Booking")),
          const PopupMenuItem(value: 'Ditolak', child: Text("Tolak")),
        ]
      );
    }
    
    if (status == 'Menunggu Pembayaran') {
      return ElevatedButton.icon(
        style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
        icon: const Icon(Icons.payments, size: 16),
        label: const Text("Bayar"),
        onPressed: () => _dialogProsesPembayaran(docId, nama, tagihan),
      );
    }

    // JIKA SELESAI -> TAMPILKAN TOMBOL PRINT
    if (status == 'Selesai') {
      return IconButton(
        icon: const Icon(Icons.print, color: Colors.blue),
        tooltip: "Cetak Struk & Resep",
        onPressed: () => _cetakStruk(data),
      );
    }

    return null;
  }
}