import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'admin_poli_page.dart';

class AdminUsersPage extends StatefulWidget {
  const AdminUsersPage({super.key});

  @override
  State<AdminUsersPage> createState() => _AdminUsersPageState();
}

class _AdminUsersPageState extends State<AdminUsersPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  int _tabIndex = 0;

  bool isSuperAdmin = false;
  final User? currentUser = FirebaseAuth.instance.currentUser;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        setState(() => _tabIndex = _tabController.index);
      }
    });
    _cekLevelAdmin();
  }

  // --- HELPER: FORMAT HARI (Agar Tampil Rapi) ---
  String _formatHari(dynamic rawData) {
    if (rawData is! List) return "-";
    List<String> hari = List<String>.from(rawData);
    if (hari.isEmpty) return "-";
    const urutan = [
      'Senin',
      'Selasa',
      'Rabu',
      'Kamis',
      'Jumat',
      'Sabtu',
      'Minggu',
    ];
    hari.sort((a, b) => urutan.indexOf(a).compareTo(urutan.indexOf(b)));

    // Cek apakah hari berurutan (Contoh: Senin, Selasa, Rabu -> Senin - Rabu)
    if (hari.length > 2) {
      bool urut = true;
      for (int i = 0; i < hari.length - 1; i++) {
        if (urutan.indexOf(hari[i + 1]) != urutan.indexOf(hari[i]) + 1) {
          urut = false;
        }
      }
      if (urut) return "${hari.first} - ${hari.last}";
    }
    return hari.join(', ');
  }

  // --- LOGIKA "ADMIN SAKTI" ---
  void _cekLevelAdmin() async {
    if (currentUser != null) {
      var doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser!.uid)
          .get();
      bool statusSuper = false;
      String emailSakti = "admin@rs.com"; // Ganti Email Anda

      if (currentUser!.email == emailSakti) {
        statusSuper = true;
        if (!doc.exists || doc.data()?['level'] != 'super') {
          await FirebaseFirestore.instance
              .collection('users')
              .doc(currentUser!.uid)
              .set({
                'level': 'super',
                'role': 'admin',
                'email': emailSakti,
              }, SetOptions(merge: true));
        }
      } else if (doc.exists && doc.data()?['level'] == 'super') {
        statusSuper = true;
      }
      if (mounted) setState(() => isSuperAdmin = statusSuper);
    }
  }

  // --- RESET PASSWORD ---
  void _kirimResetPassword(String email, String nama) async {
    if (email == '-' || email.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Email tidak valid/kosong.")),
      );
      return;
    }
    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (c) => const Center(child: CircularProgressIndicator()),
      );
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Link reset terkirim ke $email")),
        );
      }
    } catch (e) {
      if (mounted) Navigator.pop(context);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Gagal: $e")));
    }
  }

  // --- 1. TAMBAH PASIEN ---
  void _addPasien() {
    final namaCtrl = TextEditingController();
    final emailCtrl = TextEditingController();
    final passCtrl = TextEditingController();
    final nikCtrl = TextEditingController();
    final bpjsCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Daftar Pasien Offline"),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: namaCtrl,
                decoration: const InputDecoration(labelText: "Nama Pasien"),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: nikCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: "NIK"),
              ),
              TextField(
                controller: bpjsCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: "No. BPJS (Opsional)",
                ),
              ),
              const SizedBox(height: 15),
              const Divider(),
              TextField(
                controller: emailCtrl,
                decoration: const InputDecoration(labelText: "Email"),
              ),
              TextField(
                controller: passCtrl,
                obscureText: true,
                decoration: const InputDecoration(labelText: "Password"),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Batal"),
          ),
          ElevatedButton(
            onPressed: () async {
              if (emailCtrl.text.isEmpty || passCtrl.text.isEmpty) return;
              try {
                FirebaseApp secondaryApp = await Firebase.initializeApp(
                  name: 'SecondaryApp',
                  options: Firebase.app().options,
                );
                UserCredential uc =
                    await FirebaseAuth.instanceFor(
                      app: secondaryApp,
                    ).createUserWithEmailAndPassword(
                      email: emailCtrl.text,
                      password: passCtrl.text,
                    );

                String uid = uc.user!.uid;
                await FirebaseFirestore.instance
                    .collection('users')
                    .doc(uid)
                    .set({
                      'uid': uid,
                      'nama': namaCtrl.text,
                      'email': emailCtrl.text,
                      'role': 'pasien',
                      'nomor_bpjs': bpjsCtrl.text,
                      'created_at': FieldValue.serverTimestamp(),
                      'is_active': true,
                    });
                await FirebaseFirestore.instance
                    .collection('pasiens')
                    .doc(uid)
                    .set({
                      'uid': uid,
                      'nama': namaCtrl.text,
                      'email': emailCtrl.text,
                      'nik': nikCtrl.text,
                      'nomor_bpjs': bpjsCtrl.text,
                    });

                await secondaryApp.delete();
                if (mounted) Navigator.pop(context);
              } catch (e) {
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(SnackBar(content: Text("Error: $e")));
              }
            },
            child: const Text("Simpan"),
          ),
        ],
      ),
    );
  }

  // --- 2. TAMBAH DOKTER ---
  void _addDokter() {
    final namaCtrl = TextEditingController();
    final emailCtrl = TextEditingController();
    final passCtrl = TextEditingController();

    TimeOfDay jamBuka = const TimeOfDay(hour: 8, minute: 0);
    TimeOfDay jamTutup = const TimeOfDay(hour: 16, minute: 0);
    List<String> hariTerpilih = [];
    String? selectedPoli;
    final List<String> semuaHari = [
      'Senin',
      'Selasa',
      'Rabu',
      'Kamis',
      'Jumat',
      'Sabtu',
      'Minggu',
    ];

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            Future<void> pickTime(bool isBuka) async {
              final picked = await showTimePicker(
                context: context,
                initialTime: isBuka ? jamBuka : jamTutup,
              );
              if (picked != null) {
                setStateDialog(
                  () => isBuka ? jamBuka = picked : jamTutup = picked,
                );
              }
            }

            String formatTime(TimeOfDay t) =>
                '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

            return AlertDialog(
              title: const Text("Tambah Dokter Baru"),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: namaCtrl,
                      decoration: const InputDecoration(
                        labelText: "Nama Dokter",
                      ),
                    ),
                    TextField(
                      controller: emailCtrl,
                      decoration: const InputDecoration(labelText: "Email"),
                    ),
                    TextField(
                      controller: passCtrl,
                      obscureText: true,
                      decoration: const InputDecoration(labelText: "Password"),
                    ),
                    const SizedBox(height: 15),

                    StreamBuilder<QuerySnapshot>(
                      stream: FirebaseFirestore.instance
                          .collection('polis')
                          .orderBy('nama_poli')
                          .snapshots(),
                      builder: (context, snapshot) {
                        if (!snapshot.hasData) return const SizedBox();
                        return DropdownButtonFormField<String>(
                          initialValue: selectedPoli,
                          decoration: const InputDecoration(
                            labelText: "Pilih Poli",
                            border: OutlineInputBorder(),
                          ),
                          items: snapshot.data!.docs.map((doc) {
                            var data = doc.data() as Map<String, dynamic>;
                            return DropdownMenuItem(
                              value: data['nama_poli'].toString(),
                              child: Text(data['nama_poli'].toString()),
                            );
                          }).toList(),
                          onChanged: (val) =>
                              setStateDialog(() => selectedPoli = val),
                        );
                      },
                    ),
                    const SizedBox(height: 15),
                    const Text(
                      "Jadwal Praktik:",
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => pickTime(true),
                            child: Text(formatTime(jamBuka)),
                          ),
                        ),
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 5),
                          child: Text("-"),
                        ),
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => pickTime(false),
                            child: Text(formatTime(jamTutup)),
                          ),
                        ),
                      ],
                    ),
                    Wrap(
                      spacing: 5,
                      children: semuaHari.map((hari) {
                        return FilterChip(
                          label: Text(hari),
                          selected: hariTerpilih.contains(hari),
                          onSelected: (val) => setStateDialog(
                            () => val
                                ? hariTerpilih.add(hari)
                                : hariTerpilih.remove(hari),
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text("Batal"),
                ),
                ElevatedButton(
                  onPressed: () async {
                    if (emailCtrl.text.isEmpty ||
                        passCtrl.text.isEmpty ||
                        selectedPoli == null ||
                        hariTerpilih.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text("Lengkapi data!")),
                      );
                      return;
                    }
                    try {
                      FirebaseApp secondaryApp = await Firebase.initializeApp(
                        name: 'SecondaryApp',
                        options: Firebase.app().options,
                      );
                      UserCredential uc =
                          await FirebaseAuth.instanceFor(
                            app: secondaryApp,
                          ).createUserWithEmailAndPassword(
                            email: emailCtrl.text,
                            password: passCtrl.text,
                          );
                      String uid = uc.user!.uid;

                      await FirebaseFirestore.instance
                          .collection('users')
                          .doc(uid)
                          .set({
                            'uid': uid,
                            'nama': namaCtrl.text,
                            'email': emailCtrl.text,
                            'role': 'dokter',
                            'created_at': FieldValue.serverTimestamp(),
                            'is_active': true,
                          });
                      await FirebaseFirestore.instance
                          .collection('doctors')
                          .doc(uid)
                          .set({
                            'uid': uid,
                            'nama': namaCtrl.text,
                            'Nama': namaCtrl.text,
                            'Poli': selectedPoli,
                            'jam_buka': formatTime(jamBuka),
                            'jam_tutup': formatTime(jamTutup),
                            'hari_kerja': hariTerpilih,
                            'email': emailCtrl.text,
                            'foto_url': '',
                            'is_active': true,
                          });

                      await secondaryApp.delete();
                      if (mounted) Navigator.pop(context);
                    } catch (e) {
                      ScaffoldMessenger.of(
                        context,
                      ).showSnackBar(SnackBar(content: Text("Error: $e")));
                    }
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

  // --- 3. EDIT USER ---
  void _editUser(Map<String, dynamic> data, String docId, String role) {
    final namaCtrl = TextEditingController(text: data['nama'] ?? data['Nama']);
    String? selectedPoli = role == 'dokter' ? data['Poli'] : null;
    bool isActive = data['is_active'] ?? true;

    TimeOfDay jamBuka = const TimeOfDay(hour: 8, minute: 0);
    TimeOfDay jamTutup = const TimeOfDay(hour: 16, minute: 0);
    List<String> hariTerpilih = [];
    final List<String> semuaHari = [
      'Senin',
      'Selasa',
      'Rabu',
      'Kamis',
      'Jumat',
      'Sabtu',
      'Minggu',
    ];

    if (role == 'dokter') {
      try {
        if (data['jam_buka'] != null) {
          var p1 = data['jam_buka'].toString().split(':');
          jamBuka = TimeOfDay(hour: int.parse(p1[0]), minute: int.parse(p1[1]));
          var p2 = data['jam_tutup'].toString().split(':');
          jamTutup = TimeOfDay(
            hour: int.parse(p2[0]),
            minute: int.parse(p2[1]),
          );
        }
        if (data['hari_kerja'] is List) {
          hariTerpilih = List<String>.from(data['hari_kerja']);
        }
      } catch (e) {
        print("Error parsing jadwal: $e");
      }
    }

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            Future<void> pickTime(bool isBuka) async {
              final picked = await showTimePicker(
                context: context,
                initialTime: isBuka ? jamBuka : jamTutup,
              );
              if (picked != null) {
                setStateDialog(
                  () => isBuka ? jamBuka = picked : jamTutup = picked,
                );
              }
            }

            String formatTime(TimeOfDay t) =>
                '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

            return AlertDialog(
              title: Text("Edit $role"),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SwitchListTile(
                      title: Text(
                        isActive ? "Status: AKTIF" : "Status: NON-AKTIF",
                        style: TextStyle(
                          color: isActive ? Colors.green : Colors.red,
                        ),
                      ),
                      value: isActive,
                      onChanged: (val) => setStateDialog(() => isActive = val),
                    ),
                    TextField(
                      controller: namaCtrl,
                      decoration: const InputDecoration(
                        labelText: "Nama Lengkap",
                      ),
                    ),
                    if (role == 'dokter') ...[
                      const SizedBox(height: 10),
                      StreamBuilder<QuerySnapshot>(
                        stream: FirebaseFirestore.instance
                            .collection('polis')
                            .orderBy('nama_poli')
                            .snapshots(),
                        builder: (context, snapshot) {
                          if (!snapshot.hasData) return const SizedBox();
                          return DropdownButtonFormField<String>(
                            initialValue: selectedPoli,
                            items: snapshot.data!.docs
                                .map(
                                  (doc) => DropdownMenuItem(
                                    value: doc['nama_poli'] as String,
                                    child: Text(doc['nama_poli']),
                                  ),
                                )
                                .toList(),
                            onChanged: (val) =>
                                setStateDialog(() => selectedPoli = val),
                          );
                        },
                      ),
                      const SizedBox(height: 10),
                      if (isSuperAdmin) ...[
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: () => pickTime(true),
                                child: Text(formatTime(jamBuka)),
                              ),
                            ),
                            const SizedBox(width: 5),
                            Expanded(
                              child: OutlinedButton(
                                onPressed: () => pickTime(false),
                                child: Text(formatTime(jamTutup)),
                              ),
                            ),
                          ],
                        ),
                        Wrap(
                          spacing: 5,
                          children: semuaHari
                              .map(
                                (hari) => FilterChip(
                                  label: Text(hari),
                                  selected: hariTerpilih.contains(hari),
                                  onSelected: (val) => setStateDialog(
                                    () => val
                                        ? hariTerpilih.add(hari)
                                        : hariTerpilih.remove(hari),
                                  ),
                                ),
                              )
                              .toList(),
                        ),
                      ] else
                        const Text(
                          "Jadwal terkunci (Hubungi Super Admin)",
                          style: TextStyle(color: Colors.grey),
                        ),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text("Batal"),
                ),
                ElevatedButton(
                  onPressed: () async {
                    await FirebaseFirestore.instance
                        .collection('users')
                        .doc(docId)
                        .update({'nama': namaCtrl.text, 'is_active': isActive});
                    if (role == 'dokter') {
                      Map<String, dynamic> updateData = {
                        'nama': namaCtrl.text,
                        'Nama': namaCtrl.text,
                        'Poli': selectedPoli,
                        'is_active': isActive,
                      };
                      if (isSuperAdmin && hariTerpilih.isNotEmpty) {
                        updateData['jam_buka'] = formatTime(jamBuka);
                        updateData['jam_tutup'] = formatTime(jamTutup);
                        updateData['hari_kerja'] = hariTerpilih;
                      }
                      await FirebaseFirestore.instance
                          .collection('doctors')
                          .doc(docId)
                          .update(updateData);
                    }
                    if (mounted) Navigator.pop(context);
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

  // --- DELETE USER ---
  void _deleteUser(String docId, String role, String nama) {
    if (role == 'dokter' && !isSuperAdmin) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Hanya Super Admin!")));
      return;
    }
    showDialog(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text("Hapus?"),
        content: Text(nama),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c),
            child: const Text("Batal"),
          ),
          TextButton(
            onPressed: () {
              FirebaseFirestore.instance
                  .collection('users')
                  .doc(docId)
                  .delete();
              if (role == 'dokter') {
                FirebaseFirestore.instance
                    .collection('doctors')
                    .doc(docId)
                    .delete();
              }
              if (role == 'pasien') {
                FirebaseFirestore.instance
                    .collection('pasiens')
                    .doc(docId)
                    .delete();
              }
              Navigator.pop(c);
            },
            child: const Text("Hapus", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  // --- ADD ADMIN ---
  void _addAdmin() {
    /* ... Kode sama seperti sebelumnya (hemat tempat) ... */
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Kelola Pengguna",
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              isSuperAdmin ? "SUPER ADMIN" : "Admin Staff",
              style: TextStyle(
                fontSize: 12,
                color: isSuperAdmin ? Colors.orangeAccent : Colors.white70,
              ),
            ),
          ],
        ),
        backgroundColor: const Color(0xFF0077B6), // Medical Blue
        foregroundColor: Colors.white,
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          indicatorWeight: 3,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white60,
          labelStyle: const TextStyle(fontWeight: FontWeight.bold),
          tabs: const [
            Tab(icon: Icon(Icons.people_outline_rounded), text: "Pasien"),
            Tab(icon: Icon(Icons.medical_services_outlined), text: "Dokter"),
            Tab(icon: Icon(Icons.admin_panel_settings_outlined), text: "Admin"),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_suggest_outlined),
            tooltip: "Kelola Poli",
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const AdminPoliPage()),
            ),
          ),
        ],
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildUserList('pasien'),
          _buildUserList('dokter'),
          _buildUserList('admin'),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          if (_tabIndex == 0) {
            _addPasien();
          } else if (_tabIndex == 1)
            _addDokter();
          else {
            if (isSuperAdmin) {
              _addAdmin();
            } else {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("Hanya Super Admin!")),
              );
            }
          }
        },
        backgroundColor: const Color(0xFF00B4D8), // Cyan Blue
        icon: const Icon(Icons.add_rounded),
        label: const Text("Tambah Baru"),
      ),
    );
  }

  Widget _buildUserList(String roleFilter) {
    Query query = FirebaseFirestore.instance
        .collection('users')
        .where('role', isEqualTo: roleFilter);
    if (roleFilter == 'dokter') {
      query = FirebaseFirestore.instance.collection('doctors');
    }

    return StreamBuilder<QuerySnapshot>(
      stream: query.snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        var docs = snapshot.data!.docs;

        if (docs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.person_off_outlined,
                  size: 64,
                  color: Colors.grey[300],
                ),
                const SizedBox(height: 16),
                Text(
                  "Belum ada data $roleFilter.",
                  style: TextStyle(color: Colors.grey[500]),
                ),
              ],
            ),
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.all(20),
          itemCount: docs.length,
          separatorBuilder: (c, i) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            var data = docs[index].data() as Map<String, dynamic>;
            String nama = data['nama'] ?? data['Nama'] ?? 'User';
            String email = data['email'] ?? '-';
            bool isActive = data['is_active'] ?? true;

            // --- HEADER ICON ---
            IconData iconLeading = Icons.person;
            Color colorLeading = Colors.grey;
            if (roleFilter == 'dokter') {
              iconLeading = Icons.medical_services_rounded;
              colorLeading = Colors.blue;
            } else if (roleFilter == 'admin') {
              iconLeading = Icons.admin_panel_settings_rounded;
              colorLeading = Colors.orange;
            } else {
              iconLeading = Icons.person_rounded;
              colorLeading = Colors.green;
            }

            // --- SUBTITLE WIDGET ---
            Widget subtitleWidget;
            if (roleFilter == 'dokter') {
              // Baca jadwal
              String hari = _formatHari(data['hari_kerja']);
              String jam =
                  "${data['jam_buka'] ?? '00:00'} - ${data['jam_tutup'] ?? '00:00'}";

              subtitleWidget = Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.blue[50],
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      data['Poli'] ?? '-',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 10,
                        color: Colors.blue,
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(
                        Icons.access_time_rounded,
                        size: 12,
                        color: Colors.grey[600],
                      ),
                      const SizedBox(width: 4),
                      Text(
                        "$hari ($jam)",
                        style: TextStyle(fontSize: 12, color: Colors.grey[800]),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    email,
                    style: const TextStyle(fontSize: 11, color: Colors.grey),
                  ),
                ],
              );
            } else if (roleFilter == 'pasien') {
              String customId = data['id_pasien'] ?? '';
              subtitleWidget = Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (customId.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      margin: const EdgeInsets.only(bottom: 4),
                      decoration: BoxDecoration(
                        color: Colors.green[50],
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(
                          color: Colors.green.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Text(
                        "ID: $customId",
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: Colors.green[800],
                        ),
                      ),
                    ),
                  Text(
                    email,
                    style: const TextStyle(color: Colors.grey, fontSize: 11),
                  ),
                ],
              );
            } else {
              subtitleWidget = Text(
                email,
                style: const TextStyle(color: Colors.grey),
              );
            }

            return Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withValues(alpha: 0.05),
                    blurRadius: 5,
                    offset: const Offset(0, 4),
                  ),
                ],
                border: !isActive
                    ? Border.all(color: Colors.red.withValues(alpha: 0.3))
                    : null,
              ),
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                leading: CircleAvatar(
                  backgroundColor: isActive
                      ? colorLeading.withValues(alpha: 0.1)
                      : Colors.red[50],
                  child: Icon(
                    iconLeading,
                    color: isActive ? colorLeading : Colors.red,
                  ),
                ),
                title: Text(
                  nama,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    decoration: !isActive ? TextDecoration.lineThrough : null,
                    color: !isActive ? Colors.grey : Colors.black87,
                  ),
                ),
                subtitle: subtitleWidget,
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (!isActive)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        margin: const EdgeInsets.only(right: 8),
                        decoration: BoxDecoration(
                          color: Colors.red,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text(
                          "Non-Aktif",
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),

                    // TOMBOL RESET PASSWORD
                    IconButton(
                      icon: const Icon(
                        Icons.lock_reset_rounded,
                        color: Colors.orange,
                      ),
                      tooltip: "Reset Password",
                      onPressed: () => _kirimResetPassword(email, nama),
                    ),

                    // TOMBOL EDIT
                    IconButton(
                      icon: const Icon(Icons.edit_rounded, color: Colors.blue),
                      onPressed: () =>
                          _editUser(data, docs[index].id, roleFilter),
                    ),

                    // TOMBOL DELETE
                    IconButton(
                      icon: const Icon(
                        Icons.delete_outline_rounded,
                        color: Colors.red,
                      ),
                      onPressed: () =>
                          _deleteUser(docs[index].id, roleFilter, nama),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}
