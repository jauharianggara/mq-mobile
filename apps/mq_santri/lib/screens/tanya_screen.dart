import 'package:flutter/material.dart';

class TanyaScreen extends StatelessWidget {
  const TanyaScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Tanya')),
      body: const Center(child: Text('Halaman tanya — menyusul', style: TextStyle(color: Colors.grey))),
    );
  }
}
