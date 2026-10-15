import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../../core/network/api_client.dart';

// Modelo Base
class Occurrence {
  final String id;
  final double latitude;
  final double longitude;
  final String category;
  final String severity;

  Occurrence({
    required this.id,
    required this.latitude,
    required this.longitude,
    required this.category,
    required this.severity,
  });

  factory Occurrence.fromJson(Map<String, dynamic> json) {
    return Occurrence(
      id: json['id'],
      latitude: double.parse(json['latitude'].toString()),
      longitude: double.parse(json['longitude'].toString()),
      category: json['category'],
      severity: json['severity'],
    );
  }
}

class OccurrenceNotifier extends Notifier<List<Occurrence>> {
  @override
  List<Occurrence> build() {
    // Busca inicial em background
    Future.microtask(() => fetchNearbyOccurrences());
    return [];
  }

  Future<void> fetchNearbyOccurrences() async {
    try {
      final dio = ref.read(apiClientProvider);
      final response = await dio.get(
        '/occurrences/nearby',
        queryParameters: {
          'lat': -23.550520,
          'lng': -46.633308,
          'radius': 5000, // 5km
        },
      );
      
      final data = response.data as List;
      state = data.map((e) => Occurrence.fromJson(e)).toList();
    } catch (e) {
      print('Erro ao buscar ocorrencias: $e');
    }
  }

  Future<bool> createOccurrence({
    required String category,
    required String severity,
    required String description,
    required double latitude,
    required double longitude,
  }) async {
    try {
      final clientEventId = const Uuid().v4();
      final dio = ref.read(apiClientProvider);
      
      final response = await dio.post(
        '/occurrences',
        data: {
          'client_event_id': clientEventId,
          'category': category,
          'severity': severity,
          'description': description,
          'latitude': latitude,
          'longitude': longitude,
        },
      );
      
      if (response.statusCode == 202 || response.statusCode == 201) {
        return true;
      }
      return false;
    } catch (e) {
      print('Erro ao criar ocorrencia: $e');
      return false;
    }
  }
  
  void addOccurrence(Occurrence occurrence) {
    if (!state.any((e) => e.id == occurrence.id)) {
      state = [...state, occurrence];
    }
  }
}

final occurrenceProvider = NotifierProvider<OccurrenceNotifier, List<Occurrence>>(() {
  return OccurrenceNotifier();
});
