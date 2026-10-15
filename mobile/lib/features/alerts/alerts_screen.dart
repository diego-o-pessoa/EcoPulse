import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:latlong2/latlong.dart';
import '../../core/theme/app_theme.dart';
import '../occurrences/providers/occurrence_provider.dart';

class AlertsScreen extends ConsumerStatefulWidget {
  const AlertsScreen({super.key});

  @override
  ConsumerState<AlertsScreen> createState() => _AlertsScreenState();
}

class _AlertsScreenState extends ConsumerState<AlertsScreen> {
  final LatLng _userLocation = const LatLng(-23.550520, -46.633308); // São Paulo
  String _activeTab = 'all'; // 'all', 'critical', 'nearby', 'flood', 'fire'
  double _radiusKm = 20.0;
  bool _soundAlertsEnabled = true;

  @override
  Widget build(BuildContext context) {
    final occurrences = ref.watch(occurrenceProvider);

    // Filtrar ocorrências conforme a aba ativa
    final filtered = occurrences.where((occ) {
      if (_activeTab == 'critical') {
        return occ.isHighOrCritical;
      } else if (_activeTab == 'nearby') {
        const dist = Distance();
        final meters = dist.as(LengthUnit.Meter, _userLocation, LatLng(occ.latitude, occ.longitude));
        return meters <= 4000; // Menos de 4 km
      } else if (_activeTab == 'flood') {
        return occ.category == 'flood';
      } else if (_activeTab == 'fire') {
        return occ.category == 'fire';
      }
      return true;
    }).toList();

    // Contadores
    final criticalCount = occurrences.where((o) => o.isHighOrCritical && o.status == 'active').length;
    final totalCount = occurrences.where((o) => o.status == 'active').length;

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: Column(
          children: [
            Text(
              'Central de Alertas',
              style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            Text(
              'Monitoramento em tempo real • Raio ${_radiusKm.toInt()} km',
              style: GoogleFonts.inter(fontSize: 11, color: AppTheme.textSecondary),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.tune_rounded),
            tooltip: 'Configurar Alertas',
            onPressed: () => _showFilterConfigSheet(context),
          ),
        ],
      ),
      body: RefreshIndicator(
        color: AppTheme.primaryGreen,
        onRefresh: () async {
          await ref.read(occurrenceProvider.notifier).fetchNearbyOccurrences(radius: (_radiusKm * 1000).toInt());
        },
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
          physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
          children: [
            // 1. BANNER REGIONAL DE RISCO ATIVO
            _buildRiskOverviewBanner(criticalCount, totalCount),

            const SizedBox(height: 16),

            // 2. ABAS DE FILTRO RÁPIDO
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              child: Row(
                children: [
                  _buildTabChip('all', 'Todos ($totalCount)'),
                  _buildTabChip('critical', '🚨 Críticos ($criticalCount)', isAlert: criticalCount > 0),
                  _buildTabChip('nearby', '📍 Próximos (< 4 km)'),
                  _buildTabChip('flood', '🌊 Alagamentos'),
                  _buildTabChip('fire', '🔥 Queimadas'),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // 3. LISTA DE ALERTAS OU EMPTY STATE
            if (filtered.isEmpty)
              _buildEmptyState()
            else
              ...filtered.map((occ) => _buildAlertCard(occ)),

            const SizedBox(height: 24),

            // 4. CANAIS DE EMERGÊNCIA & UTILIDADE PÚBLICA
            _buildEmergencyContactsSection(),

            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildRiskOverviewBanner(int criticalCount, int totalCount) {
    final hasHighRisk = criticalCount > 0;
    final bannerBg = hasHighRisk ? const Color(0xFFFEF2F2) : const Color(0xFFF0FDF4);
    final borderColor = hasHighRisk ? const Color(0xFFFCA5A5) : const Color(0xFF86EFAC);
    final titleColor = hasHighRisk ? const Color(0xFFDC2626) : const Color(0xFF16A34A);
    final icon = hasHighRisk ? Icons.warning_rounded : Icons.shield_rounded;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: bannerBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor, width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: titleColor.withOpacity(0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: titleColor, size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  hasHighRisk ? 'Alerta Regional Ativo' : 'Situação Estável no Momento',
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    color: titleColor,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  hasHighRisk
                      ? '$criticalCount incidentes de risco severo ou crítico requerem atenção especial na sua região.'
                      : 'Nenhum evento climático extremo em curso no seu perímetro imediato.',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    height: 1.35,
                    color: AppTheme.textPrimary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabChip(String id, String label, {bool isAlert = false}) {
    final isSelected = _activeTab == id;
    return Padding(
      padding: const EdgeInsets.only(right: 8.0),
      child: ChoiceChip(
        label: Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            color: isSelected
                ? Colors.white
                : (isAlert ? AppTheme.alertRed : AppTheme.textPrimary),
          ),
        ),
        selected: isSelected,
        selectedColor: isAlert ? AppTheme.alertRed : AppTheme.primaryGreen,
        backgroundColor: Colors.white,
        side: BorderSide(
          color: isSelected
              ? Colors.transparent
              : (isAlert ? AppTheme.alertRed.withOpacity(0.4) : Colors.grey.shade300),
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        onSelected: (_) {
          setState(() => _activeTab = id);
        },
      ),
    );
  }

  Widget _buildAlertCard(Occurrence occ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: occ.isCritical ? AppTheme.alertRed.withOpacity(0.4) : Colors.grey.shade200,
          width: occ.isCritical ? 1.5 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Linha Superior: Ícone, Título, Badge de Severidade e Horário
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: occ.severityColor.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(occ.categoryIcon, color: occ.severityColor, size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              occ.categoryLabel,
                              style: GoogleFonts.inter(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.textPrimary,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: occ.severityColor.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              occ.severity,
                              style: GoogleFonts.inter(
                                color: occ.severityColor,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(Icons.access_time_rounded, size: 12, color: AppTheme.textSecondary),
                          const SizedBox(width: 4),
                          Text(
                            occ.timeAgo,
                            style: GoogleFonts.inter(fontSize: 11, color: AppTheme.textSecondary),
                          ),
                          const SizedBox(width: 8),
                          Text('•', style: TextStyle(color: Colors.grey.shade400)),
                          const SizedBox(width: 8),
                          Icon(Icons.near_me_rounded, size: 12, color: AppTheme.primaryGreen),
                          const SizedBox(width: 4),
                          Text(
                            occ.formattedDistance(_userLocation),
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.primaryGreen,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Endereço / Ponto de Referência
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: AppTheme.background,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.location_on_outlined, size: 14, color: AppTheme.textSecondary),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      occ.address ?? 'São Paulo - SP',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: AppTheme.textPrimary,
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Descrição do Alerta
          if (occ.description != null && occ.description!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
              child: Text(
                occ.description!,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  height: 1.4,
                  color: AppTheme.textPrimary,
                ),
              ),
            ),

          // Apoios / Confirmações da Comunidade
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: Row(
              children: [
                Icon(Icons.people_alt_outlined, size: 14, color: AppTheme.textSecondary),
                const SizedBox(width: 6),
                Text(
                  '${occ.confirmations} pessoas confirmaram este evento no local',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    color: AppTheme.textSecondary,
                  ),
                ),
              ],
            ),
          ),

          Divider(height: 1, color: Colors.grey.shade100),

          // Ações do Card: Ver no Mapa | Confirmar | Dicas de Segurança
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: [
                // Botão "Ver no Mapa"
                Expanded(
                  child: TextButton.icon(
                    onPressed: () {
                      // Configura a ocorrência selecionada e muda para a aba do mapa (índice 1)
                      ref.read(selectedMapOccurrenceProvider.notifier).select(occ);
                      ref.read(navigationIndexProvider.notifier).setIndex(1);
                    },
                    icon: const Icon(Icons.map_outlined, size: 16),
                    label: Text(
                      'Ver no Mapa',
                      style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                    style: TextButton.styleFrom(
                      foregroundColor: AppTheme.primaryGreen,
                      padding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                  ),
                ),

                // Botão "Confirmar (+1)"
                Expanded(
                  child: TextButton.icon(
                    onPressed: () {
                      ref.read(occurrenceProvider.notifier).confirmOccurrence(occ.id);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Você confirmou o alerta em ${occ.address}!'),
                          backgroundColor: AppTheme.primaryGreen,
                          duration: const Duration(seconds: 2),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    },
                    icon: const Icon(Icons.thumb_up_alt_outlined, size: 16),
                    label: Text(
                      'Confirmar',
                      style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                    style: TextButton.styleFrom(
                      foregroundColor: AppTheme.textPrimary,
                      padding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                  ),
                ),

                // Botão "Segurança / O que fazer"
                IconButton(
                  icon: const Icon(Icons.shield_outlined, color: AppTheme.alertOrange, size: 20),
                  tooltip: 'Orientações de Segurança',
                  onPressed: () => _showSafetyTips(context, occ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      padding: const EdgeInsets.all(32),
      margin: const EdgeInsets.symmetric(vertical: 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        children: [
          Icon(Icons.check_circle_outline_rounded, size: 54, color: AppTheme.primaryGreen),
          const SizedBox(height: 16),
          Text(
            'Nenhum alerta nesta categoria',
            style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            'Tudo tranquilo por enquanto no seu raio configurado. Você receberá avisos automáticos em caso de novos registros.',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(fontSize: 13, color: AppTheme.textSecondary, height: 1.4),
          ),
          const SizedBox(height: 16),
          OutlinedButton(
            onPressed: () => setState(() => _activeTab = 'all'),
            child: const Text('Exibir Todos os Alertas'),
          ),
        ],
      ),
    );
  }

  Widget _buildEmergencyContactsSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.phone_in_talk_rounded, color: AppTheme.alertRed, size: 20),
              const SizedBox(width: 8),
              Text(
                'Telefones Úteis e Emergências',
                style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Em caso de perigo imediato à vida ou residência, contate as autoridades competentes:',
            style: GoogleFonts.inter(fontSize: 12, color: AppTheme.textSecondary),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _buildContactItem('Defesa Civil', '199', Icons.health_and_safety_rounded, AppTheme.alertOrange),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildContactItem('Bombeiros', '193', Icons.fire_truck_rounded, AppTheme.alertRed),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildContactItem('Polícia Amb.', '190', Icons.local_police_rounded, AppTheme.alertBlue),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildContactItem(String label, String phone, IconData icon, Color color) {
    return InkWell(
      onTap: () {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Discando $label ($phone)...'),
            duration: const Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
          ),
        );
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.25)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(height: 4),
            Text(
              label,
              style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: AppTheme.textPrimary),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            Text(
              phone,
              style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold, color: color),
            ),
          ],
        ),
      ),
    );
  }

  void _showSafetyTips(BuildContext context, Occurrence occ) {
    List<String> tips = [];
    switch (occ.category.toLowerCase()) {
      case 'flood':
        tips = [
          'Nunca tente atravessar ruas alagadas ou enxurradas a pé ou de carro.',
          'Se estiver em casa e a água começar a subir, desligue a chave geral de energia.',
          'Coloque documentos e medicamentos em locais altos.',
          'Fique atento a postes, fiações caídas e bueiros abertos.',
        ];
        break;
      case 'fire':
        tips = [
          'Evite a proximidade da fumaça para proteger as vias respiratórias.',
          'Mantenha portas e janelas de residências fechadas se houver fumaça no ar.',
          'Beba bastante líquido para manter a hidratação.',
          'Se notar propagação, ligue imediatamente para os Bombeiros (193).',
        ];
        break;
      case 'road_block':
        tips = [
          'Procure rotas alternativas com antecedência pelo aplicativo.',
          'Reduza a velocidade ao se aproximar de desvios e sinalizações.',
          'Evite passar por baixo de árvores com risco de queda ou fiações expostas.',
        ];
        break;
      default:
        tips = [
          'Mantenha-se informado através de comunicados oficiais da Defesa Civil.',
          'Ajude pessoas idosas, crianças ou com mobilidade reduzida na vizinhança.',
          'Reporte alterações na gravidade do incidente pelo EcoPulse.',
        ];
    }

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(22.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppTheme.alertOrange.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.health_and_safety_rounded, color: AppTheme.alertOrange),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Recomendações: ${occ.categoryLabel}',
                      style: GoogleFonts.inter(fontSize: 17, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              ...tips.map(
                (tip) => Padding(
                  padding: const EdgeInsets.only(bottom: 10.0),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.check_circle_rounded, color: AppTheme.primaryGreen, size: 18),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          tip,
                          style: GoogleFonts.inter(fontSize: 13, height: 1.35, color: AppTheme.textPrimary),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Compreendido'),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showFilterConfigSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Padding(
              padding: const EdgeInsets.all(22.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Preferências de Monitoramento',
                    style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 20),

                  // Slider de Raio
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Raio de Alerta:', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
                      Text('${_radiusKm.toInt()} km', style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: AppTheme.primaryGreen)),
                    ],
                  ),
                  Slider(
                    value: _radiusKm,
                    min: 5.0,
                    max: 50.0,
                    divisions: 9,
                    activeColor: AppTheme.primaryGreen,
                    onChanged: (val) {
                      setSheetState(() => _radiusKm = val);
                      setState(() => _radiusKm = val);
                    },
                  ),

                  const SizedBox(height: 12),

                  // Switch de Notificações Sonoras
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text('Alertas Sonoros de Emergência', style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 14)),
                    subtitle: Text('Emitir sinal acústico em caso de riscos críticos na região.', style: GoogleFonts.inter(fontSize: 12, color: AppTheme.textSecondary)),
                    value: _soundAlertsEnabled,
                    activeColor: AppTheme.primaryGreen,
                    onChanged: (val) {
                      setSheetState(() => _soundAlertsEnabled = val);
                      setState(() => _soundAlertsEnabled = val);
                    },
                  ),

                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(context);
                        ref.read(occurrenceProvider.notifier).fetchNearbyOccurrences(radius: (_radiusKm * 1000).toInt());
                      },
                      child: const Text('Aplicar e Atualizar'),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
