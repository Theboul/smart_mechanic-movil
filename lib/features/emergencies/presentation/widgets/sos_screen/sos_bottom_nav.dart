import 'package:flutter/material.dart';

class SosBottomNav extends StatelessWidget {
  final int currentIndex;
  final Function(int) onTap;

  const SosBottomNav({
    super.key, 
    this.currentIndex = 0,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Row(
        children: [
          _buildNavItem(0, Icons.home_outlined, 'Inicio'),
          _buildNavItem(1, Icons.directions_car_outlined, 'Vehículos'),
          _buildNavItem(2, Icons.calendar_month_outlined, 'Mis Citas'),
          _buildNavItem(3, Icons.history_outlined, 'Historial'),
        ],
      ),
    );
  }

  Widget _buildNavItem(int index, IconData icon, String label) {
    final bool isActive = currentIndex == index;
    return Expanded(
      child: InkWell(
        onTap: () => onTap(index),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isActive ? Colors.white.withValues(alpha: 0.05) : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: isActive ? Colors.orange : Colors.grey, size: 22),
              const SizedBox(height: 2),
              Text(label, style: TextStyle(color: isActive ? Colors.white : Colors.grey, fontSize: 9)),
            ],
          ),
        ),
      ),
    );
  }
}
