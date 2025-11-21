import 'package:flutter/material.dart';
import '../models/rumor_model.dart';
import '../services/rumor_service.dart';
import 'rumor_discussion_page.dart';

class RumorDetailPage extends StatefulWidget {
  final String rumorId;

  const RumorDetailPage({super.key, required this.rumorId});

  @override
  State<RumorDetailPage> createState() => _RumorDetailPageState();
}

class _RumorDetailPageState extends State<RumorDetailPage> {
  final RumorService _rumorService = RumorService();
  late Future<RumorModel?> _rumorFuture;

  @override
  void initState() {
    super.initState();
    _rumorFuture = _rumorService.getRumor(widget.rumorId);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 10, 10, 10),
      appBar: AppBar(
        backgroundColor: const Color.fromARGB(255, 14, 14, 14),
        foregroundColor: Colors.white,
        title: const Text('Rumor'),
      ),
      body: FutureBuilder<RumorModel?>(
        future: _rumorFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: Colors.amber),
            );
          }

          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Error loading rumor: ${snapshot.error}',
                  style: const TextStyle(color: Colors.white70, fontSize: 14),
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          final rumor = snapshot.data;
          if (rumor == null) {
            return const Center(
              child: Text(
                'Rumor not found',
                style: TextStyle(color: Colors.white70, fontSize: 14),
              ),
            );
          }

          return RumorDiscussionPage(rumor: rumor);
        },
      ),
    );
  }
}
