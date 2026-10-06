import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

class MockBanner extends StatelessWidget {
  const MockBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 12),
      decoration: const BoxDecoration(
        color: Color(0xFF3B2D00),
        border: Border(bottom: BorderSide(color: Color(0xFFCA8A04), width: 1)),
      ),
      child: const Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.science_outlined,
            size: 14,
            color: AppTheme.statusUnlocked,
          ),
          SizedBox(width: 6),
          Text(
            'DEMO / LAB SIMULATION MODE (Isolated Repository)',
            style: TextStyle(
              color: AppTheme.statusUnlocked,
              fontSize: 11,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }
}
