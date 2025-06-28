import 'package:flutter/material.dart';
import 'login_page.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'task_detail_page.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'main.dart';
import 'package:timezone/timezone.dart' as tz;

class HomePage extends StatefulWidget {
  final String nama;
  final String nim;
  final String jurusan;

  const HomePage({
    super.key,
    required this.nama,
    required this.nim,
    required this.jurusan,
  });

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final List<String> _kategoriList = [
    'Semua Kategori', 'Tugas', 'Quiz', 'UTS', 'UAS', 'Lainnya'
  ];
  final List<String> _statusList = [
    'Semua Status', 'belum', 'selesai'
  ];
  String _selectedKategori = 'Semua Kategori';
  String _selectedStatus = 'Semua Status';

  @override
  void initState() {
    super.initState();
    _jadwalkanReminderTugas();
  }

  Future<void> _jadwalkanReminderTugas() async {
    final snapshot = await FirebaseFirestore.instance.collection('tugas').get();
    int notifId = 0;
    for (final doc in snapshot.docs) {
      final tugas = doc.data();
      final status = tugas['status'] ?? 'belum';
      final deadline = tugas['deadline'] != null ? (tugas['deadline'] as Timestamp).toDate() : null;
      if (status == 'belum' && deadline != null) {
        final now = DateTime.now();
        final reminderTime = deadline.subtract(const Duration(hours: 1));
        if (reminderTime.isAfter(now)) {
          await flutterLocalNotificationsPlugin.zonedSchedule(
            notifId++,
            'Reminder Tugas: ${tugas['judul'] ?? '-'}',
            'Deadline jam ${deadline.hour.toString().padLeft(2, '0')}:${deadline.minute.toString().padLeft(2, '0')} - Jangan lupa dikumpulkan!',
            tz.TZDateTime.from(reminderTime, tz.local),
            const NotificationDetails(
              android: AndroidNotificationDetails(
                'tugas_channel',
                'Reminder Tugas',
                channelDescription: 'Notifikasi pengingat tugas',
                importance: Importance.max,
                priority: Priority.high,
              ),
            ),
            androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard Mahasiswa'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () {
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (context) => const LoginPage()),
                (route) => false,
              );
            },
            tooltip: 'Logout',
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Selamat datang, ${widget.nama}!', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Row(
                children: [
                  Chip(label: Text('NIM: ${widget.nim}')),
                  const SizedBox(width: 8),
                  Chip(label: Text('Jurusan: ${widget.jurusan}')),
                ],
              ),
              const SizedBox(height: 24),
              // Statistik tugas
              StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance.collection('tugas').snapshots(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) return const SizedBox();
                  final allTugas = snapshot.data!.docs;
                  final selesai = allTugas.where((doc) => (doc['status'] ?? 'belum') == 'selesai').length;
                  return Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _StatCard(
                        icon: Icons.assignment,
                        label: 'Total Tugas',
                        value: allTugas.length.toString(),
                        color: Colors.deepPurple,
                      ),
                      _StatCard(
                        icon: Icons.check_circle,
                        label: 'Selesai',
                        value: selesai.toString(),
                        color: Colors.green,
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 20),
              Card(
                elevation: 0,
                color: Theme.of(context).colorScheme.surfaceVariant,
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: _selectedKategori,
                          items: _kategoriList.map((kat) => DropdownMenuItem(value: kat, child: Text(kat))).toList(),
                          onChanged: (val) {
                            setState(() { _selectedKategori = val!; });
                          },
                          decoration: const InputDecoration(labelText: 'Kategori'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: _selectedStatus,
                          items: _statusList.map((stat) => DropdownMenuItem(value: stat, child: Text(stat == 'belum' ? 'Belum Selesai' : stat == 'selesai' ? 'Selesai' : 'Semua Status'))).toList(),
                          onChanged: (val) {
                            setState(() { _selectedStatus = val!; });
                          },
                          decoration: const InputDecoration(labelText: 'Status'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance.collection('tugas').orderBy('deadline').snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                    return Padding(
                      padding: const EdgeInsets.only(top: 32.0),
                      child: Center(
                        child: Column(
                          children: [
                            Icon(Icons.inbox, size: 64, color: Colors.grey[400]),
                            const SizedBox(height: 8),
                            Text('Belum ada tugas.', style: TextStyle(color: Colors.grey[600]))
                          ],
                        ),
                      ),
                    );
                  }
                  final filteredDocs = snapshot.data!.docs.where((doc) {
                    final tugas = doc.data() as Map<String, dynamic>;
                    final kategori = tugas['kategori'] ?? '';
                    final status = tugas['status'] ?? 'belum';
                    final kategoriMatch = _selectedKategori == 'Semua Kategori' || kategori == _selectedKategori;
                    final statusMatch = _selectedStatus == 'Semua Status' || status == _selectedStatus;
                    return kategoriMatch && statusMatch;
                  }).toList();
                  if (filteredDocs.isEmpty) {
                    return Padding(
                      padding: const EdgeInsets.only(top: 32.0),
                      child: Center(
                        child: Column(
                          children: [
                            Icon(Icons.filter_alt_off, size: 64, color: Colors.grey[400]),
                            const SizedBox(height: 8),
                            Text('Tidak ada tugas sesuai filter.', style: TextStyle(color: Colors.grey[600]))
                          ],
                        ),
                      ),
                    );
                  }
                  return ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: filteredDocs.length,
                    itemBuilder: (context, i) {
                      final doc = filteredDocs[i];
                      final tugas = doc.data() as Map<String, dynamic>;
                      final deadline = tugas['deadline'] != null ? (tugas['deadline'] as Timestamp).toDate() : null;
                      return FutureBuilder<DocumentSnapshot>(
                        future: FirebaseFirestore.instance
                            .collection('tugas')
                            .doc(doc.id)
                            .collection('pengumpulan')
                            .doc(widget.nim)
                            .get(),
                        builder: (context, snapshot) {
                          final sudahKumpul = snapshot.hasData && snapshot.data!.exists;
                          return Card(
                            color: sudahKumpul ? Colors.green[50] : null,
                            child: ListTile(
                              contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                              title: Text(
                                tugas['judul'] ?? '-',
                                style: TextStyle(fontWeight: FontWeight.bold, color: sudahKumpul ? Colors.green[800] : null),
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Deadline: ' + (deadline != null ? '${deadline.day}/${deadline.month}/${deadline.year} ${deadline.hour.toString().padLeft(2, '0')}:${deadline.minute.toString().padLeft(2, '0')}' : '-')),
                                  Text('Kategori: ${tugas['kategori'] ?? '-'}'),
                                ],
                              ),
                              trailing: sudahKumpul
                                  ? const Icon(Icons.check_circle, color: Colors.green)
                                  : null,
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => TaskDetailPage(
                                      tugasId: doc.id,
                                      tugas: tugas,
                                      nama: widget.nama,
                                      nim: widget.nim,
                                    ),
                                  ),
                                );
                              },
                            ),
                          );
                        },
                      );
                    },
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _StatCard({
    Key? key,
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, size: 48, color: color),
        const SizedBox(height: 8),
        Text(label, style: Theme.of(context).textTheme.bodySmall),
        Text(value, style: Theme.of(context).textTheme.headlineSmall),
      ],
    );
  }
} 