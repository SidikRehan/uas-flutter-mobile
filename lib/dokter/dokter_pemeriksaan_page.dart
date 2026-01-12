import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class DokterPemeriksaanPage extends StatefulWidget {
  const DokterPemeriksaanPage({super.key});

  @override
  State<DokterPemeriksaanPage> createState() => _DokterPemeriksaanPageState();
}

class _DokterPemeriksaanPageState extends State<DokterPemeriksaanPage> {
  User? currentUser = FirebaseAuth.instance.currentUser;

  void _inputMedisLengkap(String docId, Map<String, dynamic> dataBooking) {
    bool isBpjs = (dataBooking['jenis_pasien'] == 'BPJS');

    final diagnosaCtrl = TextEditingController(text: dataBooking['diagnosa'] ?? '');
    final tindakanCtrl = TextEditingController(text: dataBooking['tindakan'] ?? '');
    final resepCtrl = TextEditingController(text: dataBooking['resep_obat'] ?? '');
    final biayaObatCtrl = TextEditingController(text: '0');

    // Tarif Dasar
    int biayaAdmin = isBpjs ? 0 : 10000;
    int biayaDokter = isBpjs ? 0 : 50000;
    int biayaOps = isBpjs ? 0 : 10000;
    
    bool tebusDiRS = false; 
    int totalBiaya = biayaAdmin + biayaDokter + biayaOps;

    showDialog(
      context: context,
      barrierDismissible: false, // Biar gak ketutup kalau kepencet luar
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            
            void hitungTotal() {
              int hargaObat = int.tryParse(biayaObatCtrl.text) ?? 0;
              setStateDialog(() {
                if (isBpjs) {
                  totalBiaya = 0; 
                } else {
                  totalBiaya = biayaAdmin + biayaDokter + biayaOps + (tebusDiRS ? hargaObat : 0);
                }
              });
            }

            return AlertDialog(
              title: Row(
                children: [
                  const Icon(Icons.assignment, color: Colors.teal),
                  const SizedBox(width: 10),
                  Expanded(child: Text("Periksa: ${dataBooking['nama_pasien']}", style: const TextStyle(fontSize: 16))),
                ],
              ),
              content: SizedBox(
                width: double.maxFinite,
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: isBpjs ? Colors.green : Colors.blue,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          isBpjs ? "PASIEN BPJS (GRATIS)" : "PASIEN REGULAR (BAYAR)",
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                        ),
                      ),
                      const SizedBox(height: 15),

                      _buildHeader("Data Medis"),
                      _buildInput(diagnosaCtrl, "Diagnosa", maxLines: 2),
                      _buildInput(tindakanCtrl, "Tindakan Medis"),
                      _buildInput(resepCtrl, "Resep Obat", maxLines: 3),

                      const SizedBox(height: 20),
                      _buildHeader("Rincian Biaya"),

                      _buildBiayaRow("Biaya Admin", biayaAdmin, isBpjs),
                      _buildBiayaRow("Jasa Dokter", biayaDokter, isBpjs),
                      _buildBiayaRow("Operasional", biayaOps, isBpjs),
                      const Divider(),

                      if (isBpjs) 
                        const ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text("Obat-obatan", style: TextStyle(fontSize: 14)),
                          trailing: Text("DITANGGUNG BPJS", style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
                        )
                      else 
                        Column(
                          children: [
                            SwitchListTile(
                              contentPadding: EdgeInsets.zero,
                              title: const Text("Tebus Obat di Apotek RS?", style: TextStyle(fontSize: 14)),
                              subtitle: Text(tebusDiRS ? "Masuk tagihan" : "Beli sendiri di luar"),
                              value: tebusDiRS,
                              onChanged: (val) {
                                setStateDialog(() {
                                  tebusDiRS = val;
                                  hitungTotal(); 
                                });
                              },
                            ),
                            if (tebusDiRS)
                              TextField(
                                controller: biayaObatCtrl,
                                keyboardType: TextInputType.number,
                                onChanged: (val) => hitungTotal(),
                                decoration: const InputDecoration(labelText: "Harga Obat (Rp)", prefixText: "Rp ", border: OutlineInputBorder(), isDense: true),
                              ),
                          ],
                        ),

                      const SizedBox(height: 15),
                      Container(
                        padding: const EdgeInsets.all(15),
                        decoration: BoxDecoration(color: isBpjs ? Colors.green[50] : Colors.grey[200], borderRadius: BorderRadius.circular(10)),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text("TOTAL TAGIHAN:", style: TextStyle(fontWeight: FontWeight.bold)),
                            Text(isBpjs ? "GRATIS" : "Rp $totalBiaya", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: isBpjs ? Colors.green : Colors.blue[900])),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context), child: const Text("Batal")),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.teal, foregroundColor: Colors.white),
                  onPressed: () {
                    // --- LOGIKA PENENTUAN STATUS AKHIR (PERUBAHAN UTAMA DISINI) ---
                    String statusAkhir;
                    
                    if (isBpjs) {
                      // Jika BPJS, langsung selesai (karena gratis)
                      statusAkhir = 'Selesai';
                    } else {
                      // Jika Regular, harus bayar dulu
                      statusAkhir = 'Menunggu Pembayaran';
                    }

                    FirebaseFirestore.instance.collection('bookings').doc(docId).update({
                      'diagnosa': diagnosaCtrl.text,
                      'tindakan': tindakanCtrl.text,
                      'resep_obat': resepCtrl.text,
                      'status_tebus_obat': isBpjs ? 'Ditanggung BPJS' : (tebusDiRS ? 'Apotek RS' : 'Beli Luar'),
                      'biaya_admin': biayaAdmin,
                      'biaya_dokter': biayaDokter,
                      'biaya_ops': biayaOps,
                      'biaya_obat': isBpjs ? 0 : (tebusDiRS ? int.tryParse(biayaObatCtrl.text) ?? 0 : 0),
                      'biaya': totalBiaya.toString(), 
                      'hasil_medis': "Diagnosa: ${diagnosaCtrl.text}\nObat: ${resepCtrl.text}",
                      
                      // UPDATE STATUS SESUAI LOGIKA DI ATAS
                      'status': statusAkhir, 
                    });

                    Navigator.pop(context);
                    
                    // Pesan Feedback yang berbeda
                    if (isBpjs) {
                       ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Pemeriksaan BPJS Selesai.")));
                    } else {
                       ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Data terkirim. Menunggu pembayaran pasien.")));
                    }
                  },
                  child: const Text("Simpan Data"),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildHeader(String title) {
    return Padding(padding: const EdgeInsets.only(bottom: 10), child: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.teal)));
  }

  Widget _buildInput(TextEditingController controller, String hint, {int maxLines = 1}) {
    return Padding(padding: const EdgeInsets.only(bottom: 10), child: TextField(controller: controller, maxLines: maxLines, decoration: InputDecoration(labelText: hint, border: const OutlineInputBorder(), isDense: true)));
  }

  Widget _buildBiayaRow(String label, int value, bool isBpjs) {
    return Padding(padding: const EdgeInsets.symmetric(vertical: 2), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(label, style: const TextStyle(color: Colors.grey)), Text(isBpjs ? "GRATIS" : "Rp $value", style: TextStyle(fontWeight: FontWeight.bold, color: isBpjs ? Colors.green : Colors.black))]));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Pasien Saya"), backgroundColor: Colors.teal, foregroundColor: Colors.white),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('bookings')
            .where('dokter_uid', isEqualTo: currentUser?.uid)
            .where('status', isEqualTo: 'Disetujui') 
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          var docs = snapshot.data!.docs;
          if (docs.isEmpty) return const Center(child: Text("Tidak ada pasien antri."));

          return ListView.builder(
            padding: const EdgeInsets.all(10),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              var data = docs[index].data() as Map<String, dynamic>;
              bool isBpjs = data['jenis_pasien'] == 'BPJS';

              return Card(
                margin: const EdgeInsets.only(bottom: 10),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: isBpjs ? Colors.green : Colors.blue,
                    child: Text(isBpjs ? 'BPJS' : 'REG', style: const TextStyle(color: Colors.white, fontSize: 10)),
                  ),
                  title: Text(data['nama_pasien'] ?? 'Pasien', style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text("Tgl: ${data['tanggal_booking'].toString().split(' ')[0]}"),
                  trailing: ElevatedButton(
                    onPressed: () => _inputMedisLengkap(docs[index].id, data),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.teal, foregroundColor: Colors.white),
                    child: const Text("Periksa"),
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