import 'package:flutter/material.dart';

class MockBanner extends StatelessWidget {
  const MockBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
      decoration: const BoxDecoration(
        color: Color(0xFFFEF3C7),
        border: Border(bottom: BorderSide(color: Color(0xFFFDE68A), width: 1)),
      ),
      child: const Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.science_outlined,
            size: 14,
            color: Color(0xFFB45309),
          ),
          SizedBox(width: 6),
          Text(
            'DEMO / LAB SIMULATION MODE (Isolated Repository)',
            style: TextStyle(
              color: Color(0xFFB45309),
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
