import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

class PasienNotifikasiPage extends StatefulWidget {
  const PasienNotifikasiPage({super.key});

  @override
  State<PasienNotifikasiPage> createState() => _PasienNotifikasiPageState();
}

class _PasienNotifikasiPageState extends State<PasienNotifikasiPage> {
  final User? user = FirebaseAuth.instance.currentUser;

  String _formatTanggal(Timestamp? timestamp) {
    if (timestamp == null) return "-";
    DateTime date = timestamp.toDate();
    return DateFormat('d MMM yyyy, HH:mm').format(date);
  }

  void _markAsRead() {
    if (user == null) return;
    FirebaseFirestore.instance
        .collection('notifications')
        .where('user_id', isEqualTo: user!.uid)
        .where('is_read', isEqualTo: false)
        .get()
        .then((snapshot) {
      for (var doc in snapshot.docs) {
        doc.reference.update({'is_read': true});
      }
    });
  }

  @override
  void initState() {
    super.initState();
    _markAsRead();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Notifikasi"),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 1,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('notifications')
            .where('user_id', isEqualTo: user?.uid)
            // .orderBy('created_at', descending: true) <--- PENYEBAB LOADING (DIHAPUS)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
             // Tampilkan Error jika ada masalah lain
             return Center(child: Text("Error: ${snapshot.error}")); 
          }
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          
          var docs = snapshot.data!.docs;

          if (docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.notifications_off_outlined, size: 80, color: Colors.grey[300]),
                  const SizedBox(height: 10),
                  const Text("Belum ada notifikasi", style: TextStyle(color: Colors.grey)),
                ],
              ),
            );
          }

          // --- SOLUSI: URUTKAN MANUAL DI SINI (Client Side Sorting) ---
          docs.sort((a, b) {
             Timestamp t1 = (a.data() as Map<String, dynamic>)['created_at'] ?? Timestamp.now();
             Timestamp t2 = (b.data() as Map<String, dynamic>)['created_at'] ?? Timestamp.now();
             return t2.compareTo(t1); // Descending (Terbaru di atas)
          });
          // ------------------------------------------------------------

          return ListView.builder(
            itemCount: docs.length,
            itemBuilder: (context, index) {
              var data = docs[index].data() as Map<String, dynamic>;
              String tipe = data['type'] ?? 'info'; 
              bool isRead = data['is_read'] ?? true;

              IconData icon = Icons.info;
              Color color = Colors.blue;

              if (tipe == 'booking') { icon = Icons.calendar_month; color = Colors.orange; } 
              else if (tipe == 'payment') { icon = Icons.payment; color = Colors.green; } 
              else if (tipe == 'medical') { icon = Icons.medical_services; color = Colors.red; }

              return Container(
                color: isRead ? Colors.transparent : Colors.blue[50], 
                child: ListTile(
                  leading: CircleAvatar(backgroundColor: color.withOpacity(0.1), child: Icon(icon, color: color, size: 20)),
                  title: Text(data['title'] ?? 'Info', style: TextStyle(fontWeight: isRead ? FontWeight.normal : FontWeight.bold)),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 4),
                      Text(data['body'] ?? '-'),
                      const SizedBox(height: 4),
                      Text(_formatTanggal(data['created_at']), style: const TextStyle(fontSize: 10, color: Colors.grey)),
                    ],
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