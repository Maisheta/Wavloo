import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../components/Orange_Circle.dart';
import '../components/TextField.dart';

class ResetPasswordScreen extends StatefulWidget {
  final String email;

  const ResetPasswordScreen({super.key, required this.email});

  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  final TextEditingController codeController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final TextEditingController confirmPasswordController =
      TextEditingController();

  // Function to validate OTP
  Future<bool> validateOtp(String code) async {
    try {
      final response = await http.post(
        Uri.parse(
          'https://45ff-45-244-177-153.ngrok-free.app/api/Auth/validate-otp',
        ),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"email": widget.email, "otp": code}),
      );

      debugPrint("Validate OTP response: ${response.statusCode}");
      debugPrint("Validate OTP body: ${response.body}");

      if (response.statusCode == 200) {
        return true;
      } else {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("❌ ${response.body}")));
        return false;
      }
    } catch (e) {
      debugPrint("OTP validation error: $e");
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("⚠️ Error validating OTP")));
      return false;
    }
  }

  // Function to reset the password
  Future<void> resetPassword() async {
    final code = codeController.text.trim();
    final password = passwordController.text.trim();
    final confirmPassword = confirmPasswordController.text.trim();

    if (code.isEmpty || password.isEmpty || confirmPassword.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("❗ Please fill all fields")));
      return;
    }

    if (password != confirmPassword) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("❗ Passwords do not match")));
      return;
    }

    // ✅ تحقق من صحة الـ OTP
    final isValidOtp = await validateOtp(code);
    if (!isValidOtp) return;

    try {
      final response = await http.post(
        Uri.parse(
          'https://45ff-45-244-177-153.ngrok-free.app/api/Auth/reset-Password',
        ),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "email": widget.email,
          "otp": code,
          "password": password,
          "confirmPassword": confirmPassword,
        }),
      );

      debugPrint("Reset Password response: ${response.statusCode}");
      debugPrint("Reset Password body: ${response.body}");

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("✅ Password reset successful!")),
        );
        Navigator.popUntil(context, (route) => route.isFirst);
      } else {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("❌ ${response.body}")));
      }
    } catch (e) {
      debugPrint("Reset password error: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("⚠️ Error connecting to server")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          const OrangeCircleDecoration(),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: ListView(
              children: [
                const SizedBox(height: 80),
                const Align(
                  alignment: Alignment.center,
                  child: Text(
                    "Reset Password",
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Color(0xffF37C50),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Align(
                  alignment: Alignment.center,
                  child: Text(
                    "Enter the code sent to\n${widget.email} and your new password",
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: Colors.black87,
                    ),
                  ),
                ),
                const SizedBox(height: 50),

                // Code
                CustomTextField(
                  label: "Reset Code (OTP)",
                  onChanged: (value) {
                    codeController.text = value;
                  },
                ),
                const SizedBox(height: 15),

                // New Password
                CustomTextField(
                  label: "New Password",
                  isPassword: true,
                  onChanged: (value) {
                    passwordController.text = value;
                  },
                ),
                const SizedBox(height: 15),

                // Confirm Password
                CustomTextField(
                  label: "Confirm Password",
                  isPassword: true,
                  onChanged: (value) {
                    confirmPasswordController.text = value;
                  },
                ),

                const SizedBox(height: 30),

                ElevatedButton(
                  onPressed: resetPassword,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xffF37C50),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    minimumSize: const Size(double.infinity, 50),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: const Text(
                    "Reset Password",
                    style: TextStyle(fontSize: 18, color: Colors.white),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
