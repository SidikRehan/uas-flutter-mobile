import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AdminLaporanPage extends StatefulWidget {
  const AdminLaporanPage({super.key});

  @override
  State<AdminLaporanPage> createState() => _AdminLaporanPageState();
}

class _AdminLaporanPageState extends State<AdminLaporanPage> {
  // --- STATE PILIHAN BULAN & TAHUN ---
  // Default: Pakai Bulan & Tahun Sekarang
  int _selectedBulan = DateTime.now().month;
  int _selectedTahun = DateTime.now().year;

  // Data untuk Dropdown
  final List<int> _listTahun = [2024, 2025, 2026, 2027, 2028]; // Tambah jika perlu
  final List<Map<String, dynamic>> _listBulan = [
    {'id': 1, 'nama': 'Januari'},
    {'id': 2, 'nama': 'Februari'},
    {'id': 3, 'nama': 'Maret'},
    {'id': 4, 'nama': 'April'},
    {'id': 5, 'nama': 'Mei'},
    {'id': 6, 'nama': 'Juni'},
    {'id': 7, 'nama': 'Juli'},
    {'id': 8, 'nama': 'Agustus'},
    {'id': 9, 'nama': 'September'},
    {'id': 10, 'nama': 'Oktober'},
    {'id': 11, 'nama': 'November'},
    {'id': 12, 'nama': 'Desember'},
  ];

  // Helper Format Rupiah Manual
  String formatRupiah(int number) {
    return "Rp ${number.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]}.')}";
  }

  // Helper Ambil Nama Bulan
  String getNamaBulan(int id) {
    return _listBulan.firstWhere((element) => element['id'] == id)['nama'];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Laporan & Statistik"),
        backgroundColor: Colors.orange,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // --- BAGIAN 1: TOTAL USER (PASIEN & DOKTER) ---
            const Text("Ringkasan Pengguna", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance.collection('users').where('role', isEqualTo: 'pasien').snapshots(),
                    builder: (context, snapshot) {
                      String total = snapshot.hasData ? snapshot.data!.docs.length.toString() : "-";
                      return _buildStatCard("Total Pasien", total, Icons.people, Colors.blue);
                    },
                  ),
                ),
                const SizedBox(width: 15),
                Expanded(
                  child: StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance.collection('doctors').snapshots(),
                    builder: (context, snapshot) {
                      String total = snapshot.hasData ? snapshot.data!.docs.length.toString() : "-";
                      return _buildStatCard("Total Dokter", total, Icons.medical_services, Colors.green);
                    },
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 25),
            
            // --- BAGIAN 2: FILTER BULAN & TAHUN ---
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text("Laporan Keuangan", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                
                // Area Dropdown Filter
                Row(
                  children: [
                    // DROPDOWN BULAN
                    DropdownButton<int>(
                      value: _selectedBulan,
                      items: _listBulan.map((bulan) {
                        return DropdownMenuItem<int>(
                          value: bulan['id'],
                          child: Text(bulan['nama'].toString().substring(0, 3)), // Singkat nama bulan (Jan, Feb)
                        );
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) setState(() => _selectedBulan = val);
                      },
                    ),
                    const SizedBox(width: 10),
                    // DROPDOWN TAHUN
                    DropdownButton<int>(
                      value: _selectedTahun,
                      items: _listTahun.map((tahun) {
                        return DropdownMenuItem<int>(
                          value: tahun,
                          child: Text(tahun.toString()),
                        );
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) setState(() => _selectedTahun = val);
                      },
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 10),

            // --- BAGIAN 3: LOGIKA HITUNG DUIT (DINAMIS) ---
            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance.collection('bookings').snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

                var docs = snapshot.data!.docs;
                
                // Variabel Penampung
                int omsetBulanTerpilih = 0; // Sesuai Dropdown
                int omsetTahunTerpilih = 0; // Sesuai Dropdown Tahun
                int trxSukses = 0;
                int trxBatal = 0;

                for (var doc in docs) {
                  var data = doc.data() as Map<String, dynamic>;
                  String status = data['status'] ?? '';
                  String tglString = data['tanggal_booking'] ?? DateTime.now().toString();
                  
                  // Parsing Tanggal
                  DateTime tglTransaksi;
                  try {
                    tglTransaksi = DateTime.parse(tglString);
                  } catch (e) {
                    tglTransaksi = DateTime.now(); 
                  }

                  // Ambil Biaya
                  int biaya = 0;
                  // Coba parse string ke int (aman dari error format)
                  if (data['biaya'] != null) {
                     biaya = int.tryParse(data['biaya'].toString()) ?? 0;
                  }

                  // LOGIKA HITUNG
                  // 1. Hitung Status Batal (Untuk Info Warning)
                  if (status == 'Ditolak' || status == 'Dibatalkan') {
                    // Cek apakah batalnya di bulan/tahun yang dipilih (opsional, biar relevan)
                    if (tglTransaksi.year == _selectedTahun && tglTransaksi.month == _selectedBulan) {
                       trxBatal++;
                    }
                  }

                  // 2. Hitung Uang Masuk (Hanya Status SELESAI)
                  // Note: Status 'Disetujui' belum bayar, 'Menunggu Pembayaran' belum bayar.
                  // Jadi uang hanya dihitung saat 'Selesai'.
                  if (status == 'Selesai') {
                    
                    // CEK TAHUN (Sesuai Pilihan Dropdown)
                    if (tglTransaksi.year == _selectedTahun) {
                      omsetTahunTerpilih += biaya;

                      // CEK BULAN (Sesuai Pilihan Dropdown)
                      if (tglTransaksi.month == _selectedBulan) {
                        omsetBulanTerpilih += biaya;
                        trxSukses++;
                      }
                    }
                  } 
                }

                return Column(
                  children: [
                    // KARTU 1: PENDAPATAN BULAN TERPILIH (Highlight Utama)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(colors: [Colors.green, Colors.teal]),
                        borderRadius: BorderRadius.circular(15),
                        boxShadow: [BoxShadow(color: Colors.green.withOpacity(0.4), blurRadius: 8, offset: const Offset(0, 4))]
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.calendar_month, color: Colors.white, size: 20),
                              const SizedBox(width: 8),
                              // JUDUL DINAMIS
                              Text("Pendapatan ${getNamaBulan(_selectedBulan)} $_selectedTahun", style: const TextStyle(color: Colors.white70, fontSize: 14)),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Text(
                            formatRupiah(omsetBulanTerpilih),
                            style: const TextStyle(color: Colors.white, fontSize: 30, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 5),
                          Text("Transaksi Sukses: $trxSukses Pasien", style: const TextStyle(color: Colors.white54, fontSize: 12)),
                        ],
                      ),
                    ),
                    
                    const SizedBox(height: 15),

                    // KARTU 2: PENDAPATAN TAHUNAN
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(15),
                      decoration: BoxDecoration(
                        color: Colors.blue[50],
                        borderRadius: BorderRadius.circular(15),
                        border: Border.all(color: Colors.blue.shade200)
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text("Total Tahun $_selectedTahun", style: const TextStyle(color: Colors.blue, fontWeight: FontWeight.bold)),
                              const SizedBox(height: 5),
                              Text(formatRupiah(omsetTahunTerpilih), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                            ],
                          ),
                          const Icon(Icons.bar_chart, color: Colors.blue, size: 30),
                        ],
                      ),
                    ),

                    const SizedBox(height: 15),
                    
                    // INDIKATOR BATAL (Bulan Terpilih)
                    if (trxBatal > 0)
                     Container(
                      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
                      decoration: BoxDecoration(
                        color: Colors.red[50],
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.warning_amber_rounded, color: Colors.red),
                          const SizedBox(width: 10),
                          Expanded(child: Text("Ada $trxBatal booking dibatalkan bulan ini.", style: const TextStyle(color: Colors.red, fontSize: 12))),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  // WIDGET KECIL STATISTIK
  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.1), blurRadius: 5, offset: const Offset(0, 2))]
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(height: 5),
          Text(value, style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: color)),
          Text(title, style: const TextStyle(fontSize: 12, color: Colors.grey), textAlign: TextAlign.center),
        ],
      ),
    );
  }
}