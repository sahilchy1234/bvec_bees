import 'package:flutter/material.dart';

class DatingPage extends StatelessWidget {
  const DatingPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Dating'),
      ),
      body: const Center(
        child: Text('Dating Page'),
      ),
    );
  }
}
