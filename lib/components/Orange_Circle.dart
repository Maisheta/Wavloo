// ✅ الدائرة البرتقالية في الخلفية
import 'package:flutter/material.dart';

class OrangeCircleDecoration extends StatelessWidget {
  const OrangeCircleDecoration({super.key});

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: -280,
      right: -280,
      child: Container(
        width: 550,
        height: 550,
        decoration: BoxDecoration(
          color: const Color(0xffF37C50).withOpacity(0.1),
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}
