import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AdminBookingPage extends StatefulWidget {
  const AdminBookingPage({super.key});

  @override
  State<AdminBookingPage> createState() => _AdminBookingPageState();
}

class _AdminBookingPageState extends State<AdminBookingPage> {
  // HAPUS LIST MANUAL INI:
  // final List<String> daftarPoli = ["Poli Umum", ...]; 

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
    String hariIni = _getNamaHariIni();
    bool hariSesuai = jadwalHari.toLowerCase().contains(hariIni.toLowerCase());
    bool jamSesuai = false;
    if (hariSesuai) {
      try {
        List<String> splitJam = jadwalJam.split('-'); 
        if (splitJam.length > 1) {
          String jamTutupStr = splitJam[1].trim(); 
          int jamTutup = int.parse(jamTutupStr.split(':')[0]);
          int menitTutup = int.parse(jamTutupStr.split(':')[1]);
          DateTime now = DateTime.now();
          DateTime waktuTutup = DateTime(now.year, now.month, now.day, jamTutup, menitTutup);
          if (now.isBefore(waktuTutup)) jamSesuai = true;
        } else {
          jamSesuai = true; 
        }
      } catch (e) {
        jamSesuai = true;
      }
    }
    return hariSesuai && jamSesuai;
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
      builder: (context) {
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
                    
                    // --- GANTI LIST MANUAL DENGAN STREAM BUILDER ---
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
                    // ------------------------------------------------

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
                TextButton(onPressed: () => Navigator.pop(context), child: const Text("Batal")),
                ElevatedButton(
                  onPressed: () async {
                    if (selectedPasienId == null || selectedDokterId == null) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Lengkapi semua data!")));
                      return;
                    }
                    String hariDr = selectedDokterData?['Hari'] ?? '';
                    String jamDr = selectedDokterData?['Jam'] ?? '';
                    
                    // Cek Apakah Dokter Tutup
                    if (!_isDokterBuka(hariDr, jamDr)) {
                      showDialog(context: context, builder: (c) => AlertDialog(title: const Text("⚠️ Dokter Sedang Tutup"), content: const Text("Tetap lanjutkan booking (Darurat)?"), actions: [TextButton(onPressed: () => Navigator.pop(c), child: const Text("Batal")), ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white), onPressed: () { Navigator.pop(c); _prosesSimpanBooking(selectedPasienId, selectedPasienData, selectedDokterId, selectedDokterData); }, child: const Text("Ya, Tetap Booking"))]));
                      return; 
                    }
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
          Navigator.pop(context); 
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Booking Berhasil!")));
        }
      } catch (e) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Gagal: $e")));
      }
  }

  // --- FUNGSI UPDATE STATUS ---
  void _updateStatus(String docId, String newStatus) {
    if (newStatus == 'Selesai') {
      // Cegah Admin langsung klik selesai manual tanpa bayar (lewat menu dropdown)
      return; 
    }
    FirebaseFirestore.instance.collection('bookings').doc(docId).update({'status': newStatus});
  }

  // --- FUNGSI KASIR: PROSES PEMBAYARAN (FIXED: BISA DIKLIK) ---
  void _dialogProsesPembayaran(String docId, String namaPasien, String totalBiaya) {
    String selectedMetode = 'Tunai'; 
    final List<String> metodeList = ['Tunai', 'Transfer', 'QRIS'];

    showDialog(
      context: context,
      builder: (context) {
        // StatefulBuilder agar dialog bisa refresh tampilan saat chip diklik
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              title: const Text("Konfirmasi Pembayaran (Kasir)"),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("Pasien: $namaPasien"),
                  const SizedBox(height: 10),
                  const Text("Total Tagihan:", style: TextStyle(color: Colors.grey)),
                  Text("Rp $totalBiaya", style: const TextStyle(fontSize: 30, fontWeight: FontWeight.bold, color: Colors.green)),
                  const SizedBox(height: 20),
                  const Text("Pilih Metode Pembayaran:", style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 5),
                  
                  // PILIHAN METODE BAYAR (CHOICE CHIP)
                  Wrap(
                    spacing: 10,
                    children: metodeList.map((metode) {
                      bool isSelected = selectedMetode == metode;
                      return ChoiceChip(
                        label: Text(
                          metode,
                          style: TextStyle(
                            color: isSelected ? Colors.white : Colors.black,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal
                          ),
                        ),
                        selected: isSelected,
                        selectedColor: Colors.blue, 
                        backgroundColor: Colors.grey[200],
                        onSelected: (bool selected) {
                          if (selected) {
                            setStateDialog(() {
                              selectedMetode = metode;
                            });
                          }
                        },
                      );
                    }).toList(),
                  ),
                  
                  const SizedBox(height: 10),
                  const Text("*Pastikan uang sudah diterima sebelum klik Lunas.", style: TextStyle(fontSize: 12, color: Colors.red, fontStyle: FontStyle.italic)),
                ],
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context), child: const Text("Batal")),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
                  icon: const Icon(Icons.print),
                  label: const Text("TERIMA & LUNAS"),
                  onPressed: () async {
                    // Update Status jadi Selesai & Simpan Metode Bayar
                    await FirebaseFirestore.instance.collection('bookings').doc(docId).update({
                      'status': 'Selesai',
                      'metode_bayar': selectedMetode,
                      'tgl_bayar': DateTime.now().toString(),
                    });
                    
                    if (mounted) {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Pembayaran ($selectedMetode) Berhasil!")));
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Daftar Antrian & Kasir"), backgroundColor: Colors.blue, foregroundColor: Colors.white),
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

              // LOGIKA WARNA STATUS
              Color statusColor = Colors.grey;
              if (status == 'Disetujui') statusColor = Colors.blue;
              if (status == 'Selesai') statusColor = Colors.green;
              if (status == 'Menunggu Pembayaran') statusColor = Colors.orange; 
              if (status == 'Ditolak' || status == 'Dibatalkan') statusColor = Colors.red;

              return Card(
                margin: const EdgeInsets.only(bottom: 10),
                shape: status == 'Menunggu Pembayaran' 
                    ? RoundedRectangleBorder(side: const BorderSide(color: Colors.orange, width: 2), borderRadius: BorderRadius.circular(10)) 
                    : null,
                child: ListTile(
                  title: Text(data['nama_pasien'] ?? 'Pasien', style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text("Dr. ${data['nama_dokter']} (${data['poli']})"),
                      Text("Jenis: ${data['jenis_pasien']}"),
                      const SizedBox(height: 5),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2), 
                        decoration: BoxDecoration(color: statusColor, borderRadius: BorderRadius.circular(5)), 
                        child: Text(status, style: const TextStyle(color: Colors.white, fontSize: 10))
                      ),
                      if (status == 'Menunggu Pembayaran')
                         Text("Tagihan: Rp $totalTagihan", style: const TextStyle(color: Colors.orange, fontWeight: FontWeight.bold)),
                  ]),
                  isThreeLine: true,
                  
                  // --- TOMBOL AKSI BERDASARKAN STATUS ---
                  trailing: _buildTrailingButton(status, docId, data['nama_pasien'], totalTagihan),
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

  // --- LOGIKA TOMBOL KANAN (TRAILING) ---
  Widget? _buildTrailingButton(String status, String docId, String nama, String tagihan) {
    // 1. Menunggu Konfirmasi -> Menu Terima/Tolak
    if (status == 'Menunggu Konfirmasi') {
      return PopupMenuButton<String>(
        onSelected: (val) => _updateStatus(docId, val),
        itemBuilder: (context) => [
          const PopupMenuItem(value: 'Disetujui', child: Text("Terima Booking")),
          const PopupMenuItem(value: 'Ditolak', child: Text("Tolak")),
        ]
      );
    }
    
    // 2. Disetujui -> Ikon Jam (Menunggu Dokter)
    if (status == 'Disetujui') {
       return IconButton(
         icon: const Icon(Icons.access_time_filled, color: Colors.grey),
         tooltip: "Menunggu Pemeriksaan Dokter",
         onPressed: () {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Menunggu Dokter memeriksa pasien ini...")));
         },
       );
    }

    // 3. Menunggu Pembayaran -> TOMBOL BAYAR (KASIR)
    if (status == 'Menunggu Pembayaran') {
      return ElevatedButton.icon(
        style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
        icon: const Icon(Icons.payments, size: 16),
        label: const Text("Bayar"),
        onPressed: () => _dialogProsesPembayaran(docId, nama, tagihan),
      );
    }

    // 4. Selesai -> Ceklis Hijau
    if (status == 'Selesai') {
      return const Icon(Icons.check_circle, color: Colors.green, size: 30);
    }

    return null;
  }
}