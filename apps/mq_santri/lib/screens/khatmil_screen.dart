import 'package:flutter/material.dart';

class KhatmilScreen extends StatelessWidget {
  const KhatmilScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Khatmil')),
      body: const Center(child: Text('Halaman khatmil — menyusul', style: TextStyle(color: Colors.grey))),
    );
  }
}
