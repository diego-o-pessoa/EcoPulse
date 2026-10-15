import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'api_client.dart';
import '../../features/occurrences/providers/occurrence_provider.dart';

class WebSocketService {
  late final WebSocketChannel channel;
  final OccurrenceNotifier occurrenceNotifier;

  WebSocketService({required String url, required this.occurrenceNotifier}) {
    try {
      channel = WebSocketChannel.connect(Uri.parse(url));
      channel.stream.listen(
        (message) {
          print('Nova mensagem WS recebida: $message');
          try {
            final data = jsonDecode(message);
            
            // Assume que o payload vem como dict puro da ocorrência ou { "event": ..., "data": {...} }
            final occurrenceData = data.containsKey('data') ? data['data'] : data;
            
            final occ = Occurrence.fromJson(occurrenceData);
            occurrenceNotifier.addOccurrence(occ);
          } catch (e) {
            print('Erro ao parsear mensagem WS: $e');
          }
        },
        onError: (e) {
          print('Erro no WS: $e');
        },
        onDone: () {
          print('WS Desconectado.');
        },
      );
    } catch (e) {
      print('Erro ao conectar WS: $e');
    }
  }

  void dispose() {
    channel.sink.close();
  }
}

// Inicializa WebSocket
final webSocketProvider = Provider<WebSocketService>((ref) {
  final baseUrl = getBaseUrl().replaceFirst('http', 'ws');
  final url = '$baseUrl/ws';
  
  final notifier = ref.watch(occurrenceProvider.notifier);
  final service = WebSocketService(url: url, occurrenceNotifier: notifier);
  
  ref.onDispose(() {
    service.dispose();
  });
  
  return service;
});
