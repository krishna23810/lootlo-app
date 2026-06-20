import 'package:flutter/material.dart';

/// Live session screen combining live video player and ticket marking.
class LiveSessionScreen extends StatelessWidget {
  final String gameId;

  const LiveSessionScreen({super.key, required this.gameId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Live Session')),
      body: Center(
        child: Text('Live Session Screen - $gameId - TODO'),
      ),
    );
  }
}
