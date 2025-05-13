import 'package:flutter/material.dart';

class TextFieldDecoration {
  static InputDecoration getDecoration(String label) {
    return InputDecoration(
      labelText: label,
      filled: true,
      fillColor: const Color(0xffF37C50).withOpacity(0.08), // لون الخلفية ثابت
      border: _borderStyle(),
      focusedBorder: _borderStyle(width: 2.5),
    );
  }

  static OutlineInputBorder _borderStyle({double width = 2}) {
    return OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: BorderSide(color: const Color(0xffF37C50), width: width),
    );
  }
}

class CustomTextField extends StatelessWidget {
  final String label;
  final bool isPassword;
  final TextEditingController? controller;
  final Function(String)? onChanged;

  const CustomTextField({
    super.key,
    required this.label,
    this.isPassword = false,
    this.controller,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      obscureText: isPassword, // لو هو password هيكون مخفي
      decoration: TextFieldDecoration.getDecoration(
        label,
      ), // استخدام الديكوريشن من الموديل
      onChanged: onChanged,
    );
  }
}
