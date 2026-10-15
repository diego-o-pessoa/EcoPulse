import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import 'package:uuid/uuid.dart';
import '../../../core/network/api_client.dart';
import '../../../core/theme/app_theme.dart';

// Modelo Completo de Ocorrência
class Occurrence {
  final String id;
  final double latitude;
  final double longitude;
  final String category;
  final String severity;
  final String? description;
  final String? status;
  final String? address;
  final DateTime? createdAt;
  final int confirmations;

  Occurrence({
    required this.id,
    required this.latitude,
    required this.longitude,
    required this.category,
    required this.severity,
    this.description,
    this.status,
    this.address,
    this.createdAt,
    this.confirmations = 3,
  });

  Occurrence copyWith({
    String? id,
    double? latitude,
    double? longitude,
    String? category,
    String? severity,
    String? description,
    String? status,
    String? address,
    DateTime? createdAt,
    int? confirmations,
  }) {
    return Occurrence(
      id: id ?? this.id,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      category: category ?? this.category,
      severity: severity ?? this.severity,
      description: description ?? this.description,
      status: status ?? this.status,
      address: address ?? this.address,
      createdAt: createdAt ?? this.createdAt,
      confirmations: confirmations ?? this.confirmations,
    );
  }

  factory Occurrence.fromJson(Map<String, dynamic> json) {
    return Occurrence(
      id: json['id']?.toString() ?? json['occurrence_id']?.toString() ?? const Uuid().v4(),
      latitude: double.tryParse(json['latitude']?.toString() ?? '') ?? -23.550520,
      longitude: double.tryParse(json['longitude']?.toString() ?? '') ?? -46.633308,
      category: json['category']?.toString() ?? 'pollution',
      severity: json['severity']?.toString() ?? 'Média',
      description: json['description']?.toString() ?? json['message']?.toString(),
      status: json['status']?.toString() ?? 'active',
      address: json['address']?.toString() ?? _defaultAddressFor(json['category']?.toString()),
      createdAt: json['created_at'] != null 
          ? DateTime.tryParse(json['created_at'].toString()) 
          : DateTime.now().subtract(const Duration(minutes: 25)),
      confirmations: (json['id']?.hashCode.abs() ?? 10) % 15 + 2,
    );
  }

  static String _defaultAddressFor(String? category) {
    switch (category?.toLowerCase()) {
      case 'flood':
        return 'Av. do Estado x 25 de Março';
      case 'fire':
        return 'Av. Pedro Álvares Cabral - Ibirapuera';
      case 'road_block':
        return 'Rua Domingos de Morais, Vila Mariana';
      case 'pollution':
        return 'Marginal Tietê, Próx. Ponte das Bandeiras';
      case 'extreme_heat':
        return 'Av. Paulista, Bela Vista';
      case 'water_leak':
        return 'Rua dos Pinheiros';
      case 'trash':
        return 'Rua Carnot, Pari';
      default:
        return 'São Paulo - SP';
    }
  }

  String get categoryLabel {
    switch (category.toLowerCase()) {
      case 'flood':
        return 'Alagamento';
      case 'fire':
        return 'Queimada / Incêndio';
      case 'road_block':
        return 'Via Bloqueada';
      case 'pollution':
        return 'Poluição Ambiental';
      case 'extreme_heat':
        return 'Calor Extremo';
      case 'water_leak':
        return 'Vazamento de Água';
      case 'trash':
        return 'Descarte de Lixo';
      default:
        return category;
    }
  }

  IconData get categoryIcon {
    switch (category.toLowerCase()) {
      case 'flood':
        return Icons.water_rounded;
      case 'fire':
        return Icons.local_fire_department_rounded;
      case 'road_block':
        return Icons.warning_amber_rounded;
      case 'pollution':
        return Icons.factory_rounded;
      case 'extreme_heat':
        return Icons.wb_sunny_rounded;
      case 'water_leak':
        return Icons.water_drop_rounded;
      case 'trash':
        return Icons.delete_outline_rounded;
      default:
        return Icons.eco_rounded;
    }
  }

  Color get categoryColor {
    switch (category.toLowerCase()) {
      case 'flood':
        return AppTheme.alertBlue;
      case 'fire':
        return AppTheme.alertRed;
      case 'road_block':
        return AppTheme.alertYellow;
      case 'pollution':
        return const Color(0xFF6B7280);
      case 'extreme_heat':
        return AppTheme.alertOrange;
      case 'water_leak':
        return const Color(0xFF0284C7);
      case 'trash':
        return const Color(0xFF854D0E);
      default:
        return AppTheme.primaryGreen;
    }
  }

  Color get severityColor {
    final s = severity.toLowerCase();
    if (s.contains('crítica') || s.contains('critica') || s.contains('critical')) {
      return const Color(0xFFDC2626);
    } else if (s.contains('alta') || s.contains('high')) {
      return const Color(0xFFEA580C);
    } else if (s.contains('média') || s.contains('media') || s.contains('medium')) {
      return const Color(0xFFD97706);
    } else {
      return const Color(0xFF16A34A);
    }
  }

  bool get isCritical => severity.toLowerCase().contains('crítica') || severity.toLowerCase().contains('critica');
  bool get isHighOrCritical => isCritical || severity.toLowerCase().contains('alta');

  String get timeAgo {
    if (createdAt == null) return 'Recentemente';
    final diff = DateTime.now().difference(createdAt!);
    if (diff.inMinutes < 1) return 'Agora mesmo';
    if (diff.inMinutes < 60) return 'Há ${diff.inMinutes} min';
    if (diff.inHours < 24) return 'Há ${diff.inHours}h';
    return 'Há ${diff.inDays} dias';
  }

  String formattedDistance(LatLng userLocation) {
    const distanceCalculator = Distance();
    final meters = distanceCalculator.as(
      LengthUnit.Meter,
      userLocation,
      LatLng(latitude, longitude),
    );
    if (meters < 1000) {
      return '${meters.toInt()}m';
    } else {
      final km = (meters / 1000).toStringAsFixed(1);
      return '$km km';
    }
  }
}

class OccurrenceNotifier extends Notifier<List<Occurrence>> {
  @override
  List<Occurrence> build() {
    // Busca inicial em background
    Future.microtask(() => fetchNearbyOccurrences());
    return [];
  }

  Future<void> fetchNearbyOccurrences({
    double lat = -23.550520,
    double lng = -46.633308,
    int radius = 25000,
  }) async {
    try {
      final dio = ref.read(apiClientProvider);
      final response = await dio.get(
        '/occurrences/nearby',
        queryParameters: {
          'lat': lat,
          'lng': lng,
          'radius': radius,
        },
      );
      
      final data = response.data as List;
      state = data.map((e) => Occurrence.fromJson(e)).toList();
    } catch (e) {
      print('Erro ao buscar ocorrências da API: $e');
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
        // Adiciona otimisticamente
        final newOcc = Occurrence(
          id: clientEventId,
          latitude: latitude,
          longitude: longitude,
          category: category,
          severity: severity,
          description: description,
          status: 'active',
          createdAt: DateTime.now(),
        );
        addOccurrence(newOcc);
        return true;
      }
      return false;
    } catch (e) {
      print('Erro ao criar ocorrência: $e');
      return false;
    }
  }
  
  void addOccurrence(Occurrence occurrence) {
    if (!state.any((e) => e.id == occurrence.id)) {
      state = [occurrence, ...state];
    }
  }

  void confirmOccurrence(String id) {
    state = state.map((occ) {
      if (occ.id == id) {
        return occ.copyWith(confirmations: occ.confirmations + 1);
      }
      return occ;
    }).toList();
  }

  void markResolved(String id) {
    state = state.map((occ) {
      if (occ.id == id) {
        return occ.copyWith(status: 'resolved');
      }
      return occ;
    }).toList();
  }
}

final occurrenceProvider = NotifierProvider<OccurrenceNotifier, List<Occurrence>>(() {
  return OccurrenceNotifier();
});

class SelectedOccurrenceNotifier extends Notifier<Occurrence?> {
  @override
  Occurrence? build() => null;
  void select(Occurrence? occ) => state = occ;
}

final selectedMapOccurrenceProvider = NotifierProvider<SelectedOccurrenceNotifier, Occurrence?>(() {
  return SelectedOccurrenceNotifier();
});

class NavigationIndexNotifier extends Notifier<int> {
  @override
  int build() => 0;
  void setIndex(int index) => state = index;
}

final navigationIndexProvider = NotifierProvider<NavigationIndexNotifier, int>(() {
  return NavigationIndexNotifier();
});
