import 'package:flutter/material.dart';

class MapScreen extends StatelessWidget {
  const MapScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mapa Completo'),
      ),
      body: const Center(
        child: Text('Exibição do mapa em tela cheia'),
      ),
    );
  }
}
