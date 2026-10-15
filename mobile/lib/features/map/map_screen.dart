import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/app_theme.dart';
import '../occurrences/new_occurrence_screen.dart';
import '../occurrences/providers/occurrence_provider.dart';

class MapScreen extends ConsumerStatefulWidget {
  const MapScreen({super.key});

  @override
  ConsumerState<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends ConsumerState<MapScreen> with SingleTickerProviderStateMixin {
  final MapController _mapController = MapController();
  final LatLng _userLocation = const LatLng(-23.550520, -46.633308); // São Paulo - Centro
  
  String _selectedCategoryFilter = 'all';
  String _searchQuery = '';
  bool _showRiskZones = true;
  int _tileLayerIndex = 0;
  Occurrence? _selectedOccurrence;

  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  final List<Map<String, String>> _tileProviders = [
    {
      'name': 'Padrão',
      'url': 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
    },
    {
      'name': 'Suave',
      'url': 'https://a.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}.png',
    },
  ];

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.9, end: 1.25).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  void _centerOnLocation(LatLng location, {double zoom = 14.5}) {
    _mapController.move(location, zoom);
  }

  @override
  Widget build(BuildContext context) {
    final occurrences = ref.watch(occurrenceProvider);
    final externalSelection = ref.watch(selectedMapOccurrenceProvider);

    // Se houver seleção externa (ex: veio da aba Alertas), foca nela
    if (externalSelection != null && externalSelection != _selectedOccurrence) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        setState(() {
          _selectedOccurrence = externalSelection;
        });
        _centerOnLocation(LatLng(externalSelection.latitude, externalSelection.longitude), zoom: 15.0);
        // Limpa o provider para não re-acionar
        ref.read(selectedMapOccurrenceProvider.notifier).select(null);
      });
    }

    // Filtrar ocorrências
    final filteredOccurrences = occurrences.where((occ) {
      final matchesCategory = _selectedCategoryFilter == 'all' || 
          occ.category.toLowerCase() == _selectedCategoryFilter.toLowerCase();
      final matchesSearch = _searchQuery.isEmpty ||
          occ.categoryLabel.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          (occ.description ?? '').toLowerCase().contains(_searchQuery.toLowerCase()) ||
          (occ.address ?? '').toLowerCase().contains(_searchQuery.toLowerCase());
      return matchesCategory && matchesSearch;
    }).toList();

    return Scaffold(
      body: Stack(
        children: [
          // 1. MAPA INTERATIVO FLUTTERMAP
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _userLocation,
              initialZoom: 13.5,
              minZoom: 4,
              maxZoom: 18,
              interactionOptions: const InteractionOptions(
                flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
              ),
              onTap: (_, __) {
                if (_selectedOccurrence != null) {
                  setState(() => _selectedOccurrence = null);
                }
              },
            ),
            children: [
              // Camada de Tiles
              TileLayer(
                urlTemplate: _tileProviders[_tileLayerIndex]['url']!,
                userAgentPackageName: 'com.example.ecopulse',
                keepBuffer: 3,
                panBuffer: 1,
              ),

              // Círculos de Zona de Risco (Radar de Perigo)
              if (_showRiskZones)
                CircleLayer(
                  circles: filteredOccurrences.where((o) => o.isHighOrCritical).map((occ) {
                    final isCritical = occ.isCritical;
                    return CircleMarker(
                      point: LatLng(occ.latitude, occ.longitude),
                      radius: isCritical ? 65.0 : 45.0,
                      useRadiusInMeter: false,
                      color: (isCritical ? AppTheme.alertRed : AppTheme.alertOrange).withOpacity(0.18),
                      borderColor: (isCritical ? AppTheme.alertRed : AppTheme.alertOrange).withOpacity(0.5),
                      borderStrokeWidth: 1.5,
                    );
                  }).toList(),
                ),

              // Marcadores
              MarkerLayer(
                markers: [
                  // Marcador de Posição do Usuário
                  Marker(
                    point: _userLocation,
                    width: 50,
                    height: 50,
                    child: AnimatedBuilder(
                      animation: _pulseAnimation,
                      builder: (context, child) {
                        return Center(
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              Container(
                                width: 36 * _pulseAnimation.value,
                                height: 36 * _pulseAnimation.value,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: AppTheme.primaryGreen.withOpacity(0.25),
                                ),
                              ),
                              Container(
                                width: 18,
                                height: 18,
                                decoration: BoxDecoration(
                                  color: AppTheme.primaryGreen,
                                  shape: BoxShape.circle,
                                  border: Border.all(color: Colors.white, width: 3),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.2),
                                      blurRadius: 6,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),

                  // Marcadores de Ocorrências
                  ...filteredOccurrences.map((occ) {
                    final isSelected = _selectedOccurrence?.id == occ.id;
                    return Marker(
                      point: LatLng(occ.latitude, occ.longitude),
                      width: isSelected ? 56 : 46,
                      height: isSelected ? 56 : 46,
                      child: GestureDetector(
                        onTap: () {
                          setState(() {
                            _selectedOccurrence = occ;
                          });
                          _centerOnLocation(LatLng(occ.latitude, occ.longitude));
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 250),
                          curve: Curves.easeOutBack,
                          decoration: BoxDecoration(
                            color: occ.severityColor,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: isSelected ? Colors.yellowAccent : Colors.white,
                              width: isSelected ? 3.5 : 2.5,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: occ.severityColor.withOpacity(0.4),
                                blurRadius: isSelected ? 12 : 6,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          child: Icon(
                            occ.categoryIcon,
                            color: Colors.white,
                            size: isSelected ? 28 : 22,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ],
              ),
            ],
          ),

          // 2. BARRA DE BUSCA E FILTROS RÁPIDOS NO TOPO
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Caixa de Pesquisa com Card translúcido moderno
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.12),
                          blurRadius: 16,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: TextField(
                      onChanged: (val) => setState(() => _searchQuery = val),
                      decoration: InputDecoration(
                        hintText: 'Buscar incidentes, bairros ou ruas...',
                        hintStyle: GoogleFonts.inter(fontSize: 14, color: AppTheme.textSecondary),
                        prefixIcon: const Icon(Icons.search_rounded, color: AppTheme.primaryGreen),
                        suffixIcon: _searchQuery.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.close_rounded, size: 20),
                                onPressed: () => setState(() => _searchQuery = ''),
                              )
                            : Container(
                                margin: const EdgeInsets.all(8),
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: AppTheme.primaryGreen.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  '${filteredOccurrences.length}',
                                  style: GoogleFonts.inter(
                                    fontWeight: FontWeight.bold,
                                    color: AppTheme.primaryGreen,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      ),
                    ),
                  ),

                  const SizedBox(height: 10),

                  // Chips Horizontais de Filtro por Categoria
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    physics: const BouncingScrollPhysics(),
                    child: Row(
                      children: [
                        _buildCategoryChip('all', 'Todos', Icons.grid_view_rounded, occurrences.length),
                        _buildCategoryChip('flood', 'Alagamentos', Icons.water_rounded, occurrences.where((o) => o.category == 'flood').length),
                        _buildCategoryChip('fire', 'Queimadas', Icons.local_fire_department_rounded, occurrences.where((o) => o.category == 'fire').length),
                        _buildCategoryChip('road_block', 'Vias', Icons.warning_amber_rounded, occurrences.where((o) => o.category == 'road_block').length),
                        _buildCategoryChip('pollution', 'Poluição', Icons.factory_rounded, occurrences.where((o) => o.category == 'pollution').length),
                        _buildCategoryChip('water_leak', 'Vazamentos', Icons.water_drop_rounded, occurrences.where((o) => o.category == 'water_leak').length),
                        _buildCategoryChip('trash', 'Lixo', Icons.delete_outline_rounded, occurrences.where((o) => o.category == 'trash').length),
                        _buildCategoryChip('extreme_heat', 'Calor', Icons.wb_sunny_rounded, occurrences.where((o) => o.category == 'extreme_heat').length),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // 3. CONTROLES FLUTUANTES DO MAPA (LATERAL DIREITA)
          PositionBarControls(
            onCenterLocation: () => _centerOnLocation(_userLocation),
            onZoomIn: () {
              final zoom = _mapController.camera.zoom + 1;
              _mapController.move(_mapController.camera.center, min(zoom, 18));
            },
            onZoomOut: () {
              final zoom = _mapController.camera.zoom - 1;
              _mapController.move(_mapController.camera.center, max(zoom, 4));
            },
            showRiskZones: _showRiskZones,
            onToggleRiskZones: () => setState(() => _showRiskZones = !_showRiskZones),
            onToggleMapStyle: () {
              setState(() {
                _tileLayerIndex = (_tileLayerIndex + 1) % _tileProviders.length;
              });
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Estilo do mapa: ${_tileProviders[_tileLayerIndex]['name']}'),
                  duration: const Duration(seconds: 1),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
          ),

          // 4. BOTÃO DE REPORTAR RÁPIDO (CANTO INFERIOR ESQUERDO)
          if (_selectedOccurrence == null)
            Positioned(
              left: 16,
              bottom: 20,
              child: FloatingActionButton.extended(
                heroTag: 'map_report_fab',
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const NewOccurrenceScreen()),
                  );
                },
                backgroundColor: AppTheme.primaryGreen,
                icon: const Icon(Icons.add_location_alt_rounded, color: Colors.white),
                label: Text(
                  'Reportar Risco',
                  style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: Colors.white),
                ),
                elevation: 4,
              ),
            ),

          // 5. CARD INFERIOR DETALHADO DA OCORRÊNCIA SELECIONADA
          if (_selectedOccurrence != null)
            Align(
              alignment: Alignment.bottomCenter,
              child: _buildOccurrenceDetailCard(_selectedOccurrence!),
            ),
        ],
      ),
    );
  }

  Widget _buildCategoryChip(String id, String label, IconData icon, int count) {
    final isSelected = _selectedCategoryFilter == id;
    return Padding(
      padding: const EdgeInsets.only(right: 8.0),
      child: FilterChip(
        avatar: Icon(
          icon,
          size: 16,
          color: isSelected ? Colors.white : AppTheme.textPrimary,
        ),
        label: Text(
          count > 0 ? '$label ($count)' : label,
          style: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            color: isSelected ? Colors.white : AppTheme.textPrimary,
          ),
        ),
        selected: isSelected,
        selectedColor: AppTheme.primaryGreen,
        backgroundColor: Colors.white,
        checkmarkColor: Colors.white,
        showCheckmark: false,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(
            color: isSelected ? AppTheme.primaryGreen : Colors.grey.shade200,
            width: 1,
          ),
        ),
        elevation: 3,
        shadowColor: Colors.black.withOpacity(0.08),
        onSelected: (_) {
          setState(() {
            _selectedCategoryFilter = id;
          });
        },
      ),
    );
  }

  Widget _buildOccurrenceDetailCard(Occurrence occ) {
    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.18),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Puxador Superior
          Container(
            margin: const EdgeInsets.only(top: 10, bottom: 4),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          Padding(
            padding: const EdgeInsets.fromLTRB(18, 8, 18, 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Linha de Cabeçalho com Categoria e Botão Fechar
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: occ.severityColor.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(occ.categoryIcon, color: occ.severityColor, size: 26),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            occ.categoryLabel,
                            style: GoogleFonts.inter(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: occ.severityColor,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  'Severidade ${occ.severity}',
                                  style: GoogleFonts.inter(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                occ.timeAgo,
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  color: AppTheme.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, color: AppTheme.textSecondary),
                      onPressed: () => setState(() => _selectedOccurrence = null),
                    ),
                  ],
                ),

                const SizedBox(height: 14),

                // Endereço e Distância
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.background,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.location_on_outlined, size: 18, color: AppTheme.primaryGreen),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          occ.address ?? 'Localização aproximada em São Paulo',
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.textPrimary,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        occ.formattedDistance(_userLocation),
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.primaryGreen,
                        ),
                      ),
                    ],
                  ),
                ),

                if (occ.description != null && occ.description!.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text(
                    occ.description!,
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      height: 1.4,
                      color: AppTheme.textPrimary,
                    ),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],

                const SizedBox(height: 16),

                // Linha de Ações: Confirmar Risco & Compartilhar
                Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: OutlinedButton.icon(
                        onPressed: () {
                          ref.read(occurrenceProvider.notifier).confirmOccurrence(occ.id);
                          setState(() {
                            _selectedOccurrence = _selectedOccurrence?.copyWith(
                              confirmations: (_selectedOccurrence?.confirmations ?? 0) + 1,
                            );
                          });
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Obrigado! Risco confirmado por você (${_selectedOccurrence?.confirmations} apoios).'),
                              backgroundColor: AppTheme.primaryGreen,
                              duration: const Duration(seconds: 2),
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        },
                        icon: const Icon(Icons.thumb_up_alt_outlined, size: 18),
                        label: Text(
                          'Confirmar (${occ.confirmations})',
                          style: GoogleFonts.inter(fontWeight: FontWeight.bold),
                        ),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppTheme.primaryGreen,
                          side: const BorderSide(color: AppTheme.primaryGreen, width: 1.5),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      flex: 2,
                      child: ElevatedButton.icon(
                        onPressed: () {
                          _showNavigationDialog(occ);
                        },
                        icon: const Icon(Icons.navigation_outlined, size: 18),
                        label: Text(
                          'Como ir',
                          style: GoogleFonts.inter(fontWeight: FontWeight.bold),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primaryGreen,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showNavigationDialog(Occurrence occ) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.directions_outlined, color: AppTheme.primaryGreen, size: 28),
                  const SizedBox(width: 12),
                  Text(
                    'Rotas e Prevenção',
                    style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                'Coordenadas do incidente:\nLatitude: ${occ.latitude}\nLongitude: ${occ.longitude}',
                style: GoogleFonts.inter(fontSize: 13, color: AppTheme.textSecondary),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.alertOrange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppTheme.alertOrange.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline, color: AppTheme.alertOrange),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Atenção: Ao se deslocar, evite rotas que cruzem este ponto de perigo (${occ.categoryLabel}).',
                        style: GoogleFonts.inter(fontSize: 12, color: AppTheme.textPrimary),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Entendido'),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// Widget auxiliar de botões na lateral direita
class PositionBarControls extends StatelessWidget {
  final VoidCallback onCenterLocation;
  final VoidCallback onZoomIn;
  final VoidCallback onZoomOut;
  final VoidCallback onToggleRiskZones;
  final VoidCallback onToggleMapStyle;
  final bool showRiskZones;

  const PositionBarControls({
    super.key,
    required this.onCenterLocation,
    required this.onZoomIn,
    required this.onZoomOut,
    required this.onToggleRiskZones,
    required this.onToggleMapStyle,
    required this.showRiskZones,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned(
      right: 16,
      bottom: 110,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Alternar Estilo do Mapa
          _buildMapButton(
            icon: Icons.layers_outlined,
            tooltip: 'Estilo do mapa',
            onTap: onToggleMapStyle,
          ),
          const SizedBox(height: 8),

          // Alternar Círculos de Perigo
          _buildMapButton(
            icon: showRiskZones ? Icons.radar_rounded : Icons.radio_button_unchecked,
            iconColor: showRiskZones ? AppTheme.alertRed : AppTheme.textSecondary,
            tooltip: 'Zonas de Perigo',
            onTap: onToggleRiskZones,
          ),
          const SizedBox(height: 8),

          // Centralizar GPS
          _buildMapButton(
            icon: Icons.my_location_rounded,
            iconColor: AppTheme.primaryGreen,
            tooltip: 'Minha localização',
            onTap: onCenterLocation,
          ),
          const SizedBox(height: 8),

          // Zoom Container (In / Out)
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.12),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Column(
              children: [
                IconButton(
                  icon: const Icon(Icons.add_rounded, color: AppTheme.textPrimary),
                  tooltip: 'Aproximar',
                  onPressed: onZoomIn,
                ),
                Divider(height: 1, color: Colors.grey.shade200),
                IconButton(
                  icon: const Icon(Icons.remove_rounded, color: AppTheme.textPrimary),
                  tooltip: 'Afastar',
                  onPressed: onZoomOut,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMapButton({
    required IconData icon,
    required VoidCallback onTap,
    required String tooltip,
    Color? iconColor,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.12),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: IconButton(
        icon: Icon(icon, color: iconColor ?? AppTheme.textPrimary, size: 22),
        tooltip: tooltip,
        onPressed: onTap,
      ),
    );
  }
}
