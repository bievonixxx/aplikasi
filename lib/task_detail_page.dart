import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';

class TaskDetailPage extends StatefulWidget {
  final String tugasId;
  final Map<String, dynamic> tugas;
  final String nama;
  final String nim;
  const TaskDetailPage({super.key, required this.tugasId, required this.tugas, required this.nama, required this.nim});

  @override
  State<TaskDetailPage> createState() => _TaskDetailPageState();
}

class _TaskDetailPageState extends State<TaskDetailPage> {
  bool _isUploading = false;
  String? _uploadError;
  String? _uploadedFileUrl;
  bool _sudahMengumpulkan = false;
  Timestamp? _waktuKumpul;
  final TextEditingController _linkController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _cekSudahKumpul();
  }

  Future<void> _cekSudahKumpul() async {
    final doc = await FirebaseFirestore.instance
        .collection('tugas')
        .doc(widget.tugasId)
        .collection('pengumpulan')
        .doc(widget.nim)
        .get();
    if (doc.exists) {
      setState(() {
        _sudahMengumpulkan = true;
        _uploadedFileUrl = doc['fileUrl'];
        _waktuKumpul = doc['waktuKumpul'];
      });
    }
  }

  Future<void> _kumpulLink() async {
    setState(() {
      _isUploading = true;
      _uploadError = null;
    });
    try {
      final link = _linkController.text.trim();
      if (link.isEmpty) {
        setState(() {
          _uploadError = 'Link file tidak boleh kosong!';
          _isUploading = false;
        });
        return;
      }
      await FirebaseFirestore.instance
          .collection('tugas')
          .doc(widget.tugasId)
          .collection('pengumpulan')
          .doc(widget.nim)
          .set({
        'nama': widget.nama,
        'nim': widget.nim,
        'fileUrl': link,
        'waktuKumpul': FieldValue.serverTimestamp(),
      });
      setState(() {
        _uploadedFileUrl = link;
        _sudahMengumpulkan = true;
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Link berhasil dikumpulkan!')));
    } catch (e) {
      setState(() { _uploadError = 'Gagal mengumpulkan link!'; });
    } finally {
      setState(() { _isUploading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final tugas = widget.tugas;
    final deadline = tugas['deadline'] != null ? (tugas['deadline'] as Timestamp).toDate() : null;
    final sekarang = DateTime.now();
    final sudahLewatDeadline = deadline != null && sekarang.isAfter(deadline);
    return Scaffold(
      appBar: AppBar(title: const Text('Detail Tugas')),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            child: Card(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
              elevation: 4,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('Detail Tugas', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 16),
                    Text('Judul:', style: TextStyle(fontWeight: FontWeight.bold)),
                    Text(tugas['judul'] ?? '-', style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 12),
                    Text('Deskripsi:', style: TextStyle(fontWeight: FontWeight.bold)),
                    Text(tugas['deskripsi'] ?? '-'),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Chip(label: Text('Deadline: ${deadline != null ? '${deadline.day}/${deadline.month}/${deadline.year} ${deadline.hour.toString().padLeft(2, '0')}:${deadline.minute.toString().padLeft(2, '0')}' : '-'}')),
                        const SizedBox(width: 8),
                        Chip(label: Text('Kategori: ${tugas['kategori'] ?? '-'}')),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Chip(
                          label: Text(
                            tugas['status'] == 'selesai' ? 'Selesai' : 'Belum Selesai',
                            style: TextStyle(color: tugas['status'] == 'selesai' ? Colors.green[800] : Colors.orange[800]),
                          ),
                          backgroundColor: tugas['status'] == 'selesai' ? Colors.green[50] : Colors.orange[50],
                        ),
                      ],
                    ),
                    const Divider(height: 32),
                    // File lampiran section
                    StreamBuilder<QuerySnapshot>(
                      stream: FirebaseFirestore.instance
                          .collection('tugas')
                          .doc(widget.tugasId)
                          .collection('attachments')
                          .snapshots(),
                      builder: (context, snapshot) {
                        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                          return const SizedBox();
                        }
                        
                        final attachmentDoc = snapshot.data!.docs.first;
                        final files = List<Map<String, dynamic>>.from(attachmentDoc['files'] ?? []);
                        
                        if (files.isEmpty) return const SizedBox();
                        
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('File Lampiran:', style: TextStyle(fontWeight: FontWeight.bold)),
                            const SizedBox(height: 8),
                            ...(files.map((file) {
                              final link = file['link'] ?? '';
                              final fileType = file['type'] ?? 'unknown';
                              final previewUrl = file['previewUrl'] ?? '';
                              final downloadUrl = file['downloadUrl'] ?? '';
                              
                              return Card(
                                margin: const EdgeInsets.symmetric(vertical: 8),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    ListTile(
                                      leading: Icon(_getFileIcon(fileType)),
                                      title: Text('File dari Google Drive'),
                                      subtitle: Text(link),
                                      trailing: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          if (downloadUrl.isNotEmpty)
                                            IconButton(
                                              icon: const Icon(Icons.download),
                                              onPressed: () async {
                                                if (await canLaunchUrl(Uri.parse(downloadUrl))) {
                                                  await launchUrl(Uri.parse(downloadUrl), mode: LaunchMode.externalApplication);
                                                }
                                              },
                                            ),
                                        ],
                                      ),
                                    ),
                                    if (fileType == 'pdf' && previewUrl.isNotEmpty)
                                      Container(
                                        margin: const EdgeInsets.all(8),
                                        child: ElevatedButton.icon(
                                          onPressed: () async {
                                            if (await canLaunchUrl(Uri.parse(downloadUrl))) {
                                              await launchUrl(Uri.parse(downloadUrl), mode: LaunchMode.externalApplication);
                                            }
                                          },
                                          icon: const Icon(Icons.download),
                                          label: const Text('Download PDF'),
                                        ),
                                      ),
                                  ],
                                ),
                              );
                            }).toList()),
                            const Divider(height: 32),
                          ],
                        );
                      },
                    ),
                    if (_sudahMengumpulkan)
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Kamu sudah mengumpulkan tugas ini.'),
                          if (_uploadedFileUrl != null)
                            TextButton(
                              onPressed: () {
                                // Buka file di browser
                                // ignore: deprecated_member_use
                                // launch(_uploadedFileUrl!);
                              },
                              child: const Text('Lihat File'),
                            ),
                          if (_waktuKumpul != null)
                            Text('Waktu Kumpul: ${_waktuKumpul!.toDate()}'),
                        ],
                      )
                    else if (sudahLewatDeadline)
                      const Text('Pengumpulan tugas sudah ditutup. Anda tidak bisa mengumpulkan tugas ini lagi.', style: TextStyle(color: Colors.red))
                    else
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          TextField(
                            controller: _linkController,
                            decoration: const InputDecoration(
                              labelText: 'Link File (Google Drive, dsb)',
                              border: OutlineInputBorder(),
                            ),
                          ),
                          const SizedBox(height: 8),
                          ElevatedButton(
                            onPressed: _isUploading ? null : _kumpulLink,
                            child: _isUploading ? const CircularProgressIndicator(color: Colors.white) : const Text('Kumpulkan Link'),
                          ),
                          if (_uploadError != null)
                            Text(_uploadError!, style: const TextStyle(color: Colors.red)),
                        ],
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  IconData _getFileIcon(String fileType) {
    switch (fileType) {
      case 'pdf':
        return Icons.picture_as_pdf;
      case 'document':
        return Icons.description;
      case 'presentation':
        return Icons.slideshow;
      case 'image':
        return Icons.image;
      default:
        return Icons.insert_drive_file;
    }
  }
} 