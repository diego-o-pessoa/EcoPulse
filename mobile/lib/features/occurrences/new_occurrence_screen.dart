import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_theme.dart';
import 'providers/occurrence_provider.dart';

class NewOccurrenceScreen extends ConsumerStatefulWidget {
  const NewOccurrenceScreen({super.key});

  @override
  ConsumerState<NewOccurrenceScreen> createState() => _NewOccurrenceScreenState();
}

class _NewOccurrenceScreenState extends ConsumerState<NewOccurrenceScreen> {
  String? _selectedCategory;
  final TextEditingController _descriptionController = TextEditingController();

  final List<Map<String, dynamic>> _categories = [
    {'id': 'flood', 'label': 'Alagamento', 'icon': Icons.water, 'color': AppTheme.alertBlue},
    {'id': 'pollution', 'label': 'Poluição', 'icon': Icons.factory, 'color': Colors.grey},
    {'id': 'fire', 'label': 'Queimada', 'icon': Icons.local_fire_department, 'color': AppTheme.alertRed},
    {'id': 'road_block', 'label': 'Via bloqueada', 'icon': Icons.warning, 'color': AppTheme.alertYellow},
    {'id': 'extreme_heat', 'label': 'Calor extremo', 'icon': Icons.wb_sunny, 'color': AppTheme.alertOrange},
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Nova ocorrência'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Ajude a tornar sua cidade mais segura.\nReporte o que você viu!',
              style: TextStyle(fontSize: 14, color: AppTheme.textSecondary),
            ),
            const SizedBox(height: 24),
            
            // Grid de Categorias
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 2.5,
              ),
              itemCount: _categories.length,
              itemBuilder: (context, index) {
                final cat = _categories[index];
                final isSelected = _selectedCategory == cat['id'];
                return InkWell(
                  onTap: () => setState(() => _selectedCategory = cat['id']),
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    decoration: BoxDecoration(
                      color: isSelected ? cat['color'].withOpacity(0.1) : Colors.white,
                      border: Border.all(
                        color: isSelected ? cat['color'] : Colors.grey.shade300,
                        width: isSelected ? 2 : 1,
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(cat['icon'], color: cat['color']),
                        const SizedBox(width: 8),
                        Text(
                          cat['label'],
                          style: TextStyle(
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 24),

            // Descrição
            const Text('Descreva o que aconteceu', style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
            const SizedBox(height: 8),
            TextField(
              controller: _descriptionController,
              maxLines: 4,
              maxLength: 500,
              decoration: const InputDecoration(
                hintText: 'Conte mais detalhes (opcional)...',
              ),
            ),
            const SizedBox(height: 16),

            // Localização
            const Text('Localização atual', style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: Row(
                children: [
                  const Icon(Icons.location_on, color: AppTheme.primaryGreen),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        Text('São Paulo - SP', style: TextStyle(fontWeight: FontWeight.bold)),
                        Text('Obtendo localização...', style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                      ],
                    ),
                  ),
                  const Icon(Icons.my_location, color: AppTheme.textSecondary),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Botão Enviar
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _selectedCategory == null ? null : () async {
                  final success = await ref.read(occurrenceProvider.notifier).createOccurrence(
                    category: _selectedCategory!,
                    severity: 'Alta', // Valor em português para bater com o SeverityEnum do backend
                    description: _descriptionController.text,
                    latitude: -23.550520, // Fixado para simular GPS
                    longitude: -46.633308,
                  );
                  
                  if (success && mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Relato enviado e será processado!')),
                    );
                    Navigator.pop(context);
                  } else if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Erro ao enviar relato')),
                    );
                  }
                },
                icon: const Icon(Icons.send),
                label: const Text('Enviar relato', style: TextStyle(fontSize: 18)),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
