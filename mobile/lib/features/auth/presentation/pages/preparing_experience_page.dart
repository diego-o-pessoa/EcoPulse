import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/main_navigation.dart';

class PreparingExperiencePage extends StatefulWidget {
  const PreparingExperiencePage({super.key});

  @override
  State<PreparingExperiencePage> createState() => _PreparingExperiencePageState();
}

class _PreparingExperiencePageState extends State<PreparingExperiencePage> with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late AnimationController _orbitController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();

    // Pulso (Respiração da folha principal)
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    _scaleAnimation = Tween<double>(begin: 0.9, end: 1.1).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    // Órbita (Folhas menores girando em volta)
    _orbitController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3000),
    )..repeat();

    // Redirecionamento após 4 segundos
    Future.delayed(const Duration(seconds: 4), () {
      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const MainNavigation()),
          (route) => false,
        );
      }
    });
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _orbitController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 24),
            // Logo Topo
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Image.asset('assets/images/ecopulse_logo.png', height: 32),
                const SizedBox(width: 8),
                Text(
                  'EcoPulse',
                  style: GoogleFonts.inter(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF0F172A),
                  ),
                ),
              ],
            ),
            
            Expanded(
              child: Center(
                child: SizedBox(
                  width: 250,
                  height: 250,
                  child: AnimatedBuilder(
                    animation: Listenable.merge([_pulseController, _orbitController]),
                    builder: (context, child) {
                      return Stack(
                        alignment: Alignment.center,
                        children: [
                          // Folha Principal (Pulsando)
                          Transform.scale(
                            scale: _scaleAnimation.value,
                            child: Image.asset(
                              'assets/images/happy_leaf.png',
                              width: 140,
                              height: 140,
                            ),
                          ),
                          
                          // Folha Menor 1 Orbitando
                          _buildOrbitingLeaf(0),
                          // Folha Menor 2 Orbitando (Defasada 120 graus)
                          _buildOrbitingLeaf(2 * pi / 3),
                          // Folha Menor 3 Orbitando (Defasada 240 graus)
                          _buildOrbitingLeaf(4 * pi / 3),
                        ],
                      );
                    },
                  ),
                ),
              ),
            ),
            
            // Textos Inferiores
            Text(
              'Preparando sua experiência',
              style: GoogleFonts.inter(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: const Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Conectando você a uma cidade\nmais sustentável...',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 15,
                color: const Color(0xFF475569),
                height: 1.4,
              ),
            ),
            const SizedBox(height: 32),
            
            // 3 Pontinhos Animados Simples (Loading)
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(3, (index) {
                return AnimatedBuilder(
                  animation: _pulseController,
                  builder: (context, child) {
                    // Causa um pequeno atraso (delay) entre os pontos usando o valor do pulso
                    final delay = index * 0.2;
                    final value = sin((_pulseController.value * pi) - delay);
                    final opacity = (value + 1) / 2; // Normaliza entre 0 e 1
                    
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4.0),
                      child: Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: AppTheme.primaryGreen.withOpacity(opacity.clamp(0.2, 1.0)),
                          shape: BoxShape.circle,
                        ),
                      ),
                    );
                  },
                );
              }),
            ),
            const SizedBox(height: 48),
          ],
        ),
      ),
    );
  }

  Widget _buildOrbitingLeaf(double offsetAngle) {
    // Calcula a posição na órbita com base no tempo e no offset
    final angle = (_orbitController.value * 2 * pi) + offsetAngle;
    final radius = 100.0;
    
    // As folhas também podem girar em torno do próprio eixo
    final selfRotation = _orbitController.value * 4 * pi;

    return Transform.translate(
      offset: Offset(cos(angle) * radius, sin(angle) * radius),
      child: Transform.rotate(
        angle: selfRotation,
        child: Image.asset(
          'assets/images/small_leaf.png',
          width: 32,
          height: 32,
        ),
      ),
    );
  }
}
