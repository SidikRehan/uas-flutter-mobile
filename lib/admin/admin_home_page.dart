import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../auth/login_page.dart';
import '../dokter/add_doctor_page.dart'; 
import 'add_admin_page.dart'; // 1. JANGAN LUPA IMPORT INI
import 'admin_booking_page.dart'; // Import halaman baru

class AdminHomePage extends StatelessWidget {
  const AdminHomePage({super.key});

  // Fungsi Hapus Dokter
  void _hapusDokter(String idDokter) {
    FirebaseFirestore.instance.collection('doctors').doc(idDokter).delete();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Dashboard Admin"),
        backgroundColor: Colors.redAccent,
        foregroundColor: Colors.white,
        actions: [
          // 1. TOMBOL LIHAT BOOKING (BARU)
          IconButton(
            icon: const Icon(Icons.assignment), // Ikon kertas daftar
            tooltip: "Lihat Booking Masuk",
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const AdminBookingPage()),
              );
            },
          ),

          // 2. TOMBOL TAMBAH ADMIN (YANG KEMARIN)
          IconButton(
            icon: const Icon(Icons.person_add),
            tooltip: "Tambah Admin Baru",
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const AddAdminPage()),
              );
            },
          ),

          // 3. TOMBOL LOGOUT (YANG LAMA)
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await FirebaseAuth.instance.signOut();
              if (context.mounted) {
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (context) => const LoginPage()),
                  (route) => false,
                );
              }
            },
          ),
        ],
      ),
      
      // Tombol Tambah DOKTER (Tetap di bawah)
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const AddDoctorPage()),
          );
        },
        label: const Text("Tambah Dokter"),
        icon: const Icon(Icons.add),
        backgroundColor: Colors.redAccent,
      ),
      
      body: Column(
        children: [
          const Padding(
            padding: EdgeInsets.all(15.0),
            child: Text(
              "Daftar Dokter Tersedia",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
          
          // List Dokter dari Database
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance.collection('doctors').snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

                var docs = snapshot.data!.docs;

                return ListView.builder(
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    var data = docs[index].data() as Map<String, dynamic>;
                    String idDokter = docs[index].id; 

                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 15, vertical: 5),
                      child: ListTile(
                        leading: const CircleAvatar(
                          backgroundColor: Colors.redAccent,
                          child: Icon(Icons.medical_services, color: Colors.white),
                        ),
                        // Pastikan kunci (Nama/nama) sesuai dengan yang ada di Database kamu
                        title: Text(data['Nama'] ?? data['nama'] ?? "Tanpa Nama"),
                        subtitle: Text("${data['Poli'] ?? data['poli']} \n${data['Hari'] ?? data['hari']} (${data['Jam'] ?? data['jam']})"),
                        isThreeLine: true,
                        trailing: IconButton(
                          icon: const Icon(Icons.delete, color: Colors.red),
                          onPressed: () {
                            _hapusDokter(idDokter);
                          },
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}