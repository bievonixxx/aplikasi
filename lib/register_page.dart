import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final TextEditingController _namaController = TextEditingController();
  final TextEditingController _nimController = TextEditingController();
  final List<String> _jurusanList = [
    'Sistem Informasi',
    'Teknik Informatika',
    'Teknik Sipil',
    'Manajemen Informatika',
    'Manajemen',
    'Psikologi',
  ];
  String? _selectedJurusan;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Registrasi Mahasiswa')),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            child: Card(
              margin: const EdgeInsets.symmetric(horizontal: 24),
              elevation: 4,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('Buat Akun Mahasiswa', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 24),
                    TextField(
                      controller: _namaController,
                      decoration: const InputDecoration(
                        labelText: 'Nama',
                        prefixIcon: Icon(Icons.person),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _nimController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'NIM',
                        prefixIcon: Icon(Icons.badge),
                      ),
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      value: _selectedJurusan,
                      items: _jurusanList.map((jurusan) {
                        return DropdownMenuItem(
                          value: jurusan,
                          child: Text(jurusan),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setState(() {
                          _selectedJurusan = value;
                        });
                      },
                      decoration: const InputDecoration(
                        labelText: 'Jurusan',
                        prefixIcon: Icon(Icons.school),
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (_errorMessage != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8.0),
                        child: Text(_errorMessage!, style: const TextStyle(color: Colors.red)),
                      ),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _register,
                        child: _isLoading
                            ? const CircularProgressIndicator(color: Colors.white)
                            : const Text('Registrasi'),
                      ),
                    ),
                    TextButton(
                      onPressed: () {
                        Navigator.pop(context);
                      },
                      child: const Text('Sudah punya akun? Login'),
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

  void _register() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    final nama = _namaController.text.trim();
    final nim = _nimController.text.trim();
    final jurusan = _selectedJurusan;
    if (nama.isEmpty || nim.isEmpty || jurusan == null || jurusan.isEmpty) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Semua field harus diisi';
      });
      return;
    }
    try {
      final doc = await FirebaseFirestore.instance.collection('mahasiswa').doc(nim).get();
      if (doc.exists) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'NIM sudah terdaftar';
        });
        return;
      }
      await FirebaseFirestore.instance.collection('mahasiswa').doc(nim).set({
        'nama': nama,
        'nim': nim,
        'jurusan': jurusan,
        'createdAt': FieldValue.serverTimestamp(),
      });
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Registrasi berhasil, silakan login!')),
        );
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Terjadi kesalahan. Coba lagi.';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }
} 