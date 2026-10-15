import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../features/home/home_screen.dart';
import '../../features/map/map_screen.dart';
import '../../features/alerts/alerts_screen.dart';
import '../../features/profile/profile_screen.dart';
import '../../features/occurrences/providers/occurrence_provider.dart';

class MainNavigation extends ConsumerWidget {
  const MainNavigation({super.key});

  final List<Widget> _screens = const [
    HomeScreen(),
    MapScreen(),
    AlertsScreen(),
    ProfileScreen(),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentIndex = ref.watch(navigationIndexProvider);
    final occurrences = ref.watch(occurrenceProvider);
    final criticalCount = occurrences.where((o) => o.isHighOrCritical && o.status == 'active').length;

    return Scaffold(
      body: IndexedStack(
        index: currentIndex,
        children: [
          TickerMode(enabled: currentIndex == 0, child: const HomeScreen()),
          TickerMode(enabled: currentIndex == 1, child: const MapScreen()),
          TickerMode(enabled: currentIndex == 2, child: const AlertsScreen()),
          TickerMode(enabled: currentIndex == 3, child: const ProfileScreen()),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: currentIndex,
        onTap: (index) {
          ref.read(navigationIndexProvider.notifier).setIndex(index);
        },
        items: [
          const BottomNavigationBarItem(
            icon: Icon(Icons.home_outlined),
            activeIcon: Icon(Icons.home),
            label: 'Início',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.map_outlined),
            activeIcon: Icon(Icons.map),
            label: 'Mapa',
          ),
          BottomNavigationBarItem(
            icon: Badge(
              isLabelVisible: criticalCount > 0,
              label: Text('$criticalCount'),
              backgroundColor: const Color(0xFFDC2626),
              child: const Icon(Icons.notifications_outlined),
            ),
            activeIcon: Badge(
              isLabelVisible: criticalCount > 0,
              label: Text('$criticalCount'),
              backgroundColor: const Color(0xFFDC2626),
              child: const Icon(Icons.notifications),
            ),
            label: 'Alertas',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.person_outline),
            activeIcon: Icon(Icons.person),
            label: 'Perfil',
          ),
        ],
      ),
    );
  }
}
