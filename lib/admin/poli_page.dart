import 'package:flutter/material.dart';
import '../pasien/booking_page.dart'; 

class PoliPage extends StatelessWidget {
  const PoliPage({super.key});

  @override
  Widget build(BuildContext context) {
    // DATA POLI
    // Pastikan 'nama' di sini SAMA PERSIS dengan isi field 'Poli' di collection 'doctors' database kamu.
    final List<Map<String, dynamic>> daftarPoli = [
      {'nama': 'Poli Umum', 'icon': Icons.medical_services, 'color': Colors.blue},
      {'nama': 'Poli Gigi', 'icon': Icons.mood, 'color': Colors.orange},
      {'nama': 'Poli Anak', 'icon': Icons.child_care, 'color': Colors.pink},
      {'nama': 'Poli Penyakit Dalam', 'icon': Icons.monitor_heart, 'color': Colors.red},
      {'nama': 'Poli Mata', 'icon': Icons.visibility, 'color': Colors.green},
      {'nama': 'Poli Syaraf', 'icon': Icons.psychology, 'color': Colors.purple},
      // Tambahkan poli lain jika perlu
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text("Pilih Poliklinik"),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(15.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Mau berobat ke mana hari ini?",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 15),
            
            // GRID MENU
            Expanded(
              child: GridView.builder(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2, // 2 kotak ke samping
                  crossAxisSpacing: 15,
                  mainAxisSpacing: 15,
                  childAspectRatio: 1.1, // Mengatur tinggi kotak
                ),
                itemCount: daftarPoli.length,
                itemBuilder: (context, index) {
                  return Card(
                    elevation: 4,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                    // Gunakan InkWell di dalam Card agar ada efek klik
                    child: InkWell(
                      borderRadius: BorderRadius.circular(15),
                      onTap: () {
                        // Navigasi ke BookingPage membawa nama Poli
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => BookingPage(
                              poliPilihan: daftarPoli[index]['nama'],
                            ),
                          ),
                        );
                      },
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(15),
                            decoration: BoxDecoration(
                              color: daftarPoli[index]['color'].withOpacity(0.1),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              daftarPoli[index]['icon'],
                              size: 40,
                              color: daftarPoli[index]['color'],
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            daftarPoli[index]['nama'],
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold, 
                              fontSize: 16
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}