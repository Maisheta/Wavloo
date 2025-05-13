import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:chat/screens/Account_Screen.dart';
import 'package:chat/screens/Home_screen.dart';
import '../components/Orange_Circle.dart';
import '../components/TextField.dart';
import 'package:http/http.dart' as http;
import 'package:chat/screens/ForgotPasswordScreen.dart';
import 'ChatsListScreen.dart';
import 'package:shared_preferences/shared_preferences.dart';

class Login_Screen extends StatefulWidget {
  const Login_Screen({super.key});

  @override
  State<Login_Screen> createState() => _Login_ScreenState();
}

class _Login_ScreenState extends State<Login_Screen> {
  String email = '';
  String password = '';

  Future<void> login(
    BuildContext context,
    String email,
    String password,
  ) async {
    try {
      final response = await http.post(
        Uri.parse('https://6589-45-244-213-140.ngrok-free.app/api/auth/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': email, 'password': password}),
      );

      print("📡 Login Status Code: ${response.statusCode}");
      print("📥 Login Response: ${response.body}");

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        print("🔍 Parsed Login Response: $data");

        final accessToken = data['token'];
        final refreshToken = data['refreshToken'];
        final firstName = data['firstName'] ?? 'unknown';
        final lastName = data['lastName'] ?? 'user';
        final userId =
            data['userId'] ??
            'unknown'; // تأكد انك بتجيب الـ userId من response الـ login

        if (accessToken == null || refreshToken == null) {
          print("❗ Access or refresh token not found in response");
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Token not found in login response")),
          );
          return;
        }

        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('token', accessToken);
        await prefs.setString('refresh_token', refreshToken);
        await prefs.setString('email', email); // تخزين الـ email
        await prefs.setString('firstName', firstName);
        await prefs.setString('lastName', lastName);
        await prefs.setString('userId', userId); // تخزين الـ userId
        print(
          "✅ Login successful, tokens and email saved: $accessToken, $refreshToken, $email ,$userId",
        );

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const ChatsListScreen()),
        );
      } else {
        print("❌ Login failed: ${response.statusCode}");
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Login failed: ${response.statusCode}")),
        );
      }
    } catch (e) {
      print("❗ Login exception: $e");
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Login error occurred")));
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
                    "Login here",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Color(0xffF37C50),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                const Align(
                  alignment: Alignment.center,
                  child: Text(
                    "Good to see you again!\nLog in and start chatting",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                ),
                const SizedBox(height: 60),
                CustomTextField(
                  label: "Email",
                  onChanged: (value) {
                    setState(() {
                      email = value;
                    });
                  },
                ),
                const SizedBox(height: 15),
                CustomTextField(
                  label: "Password",
                  isPassword: true,
                  onChanged: (value) {
                    setState(() {
                      password = value;
                    });
                  },
                ),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const ForgotPasswordScreen(),
                        ),
                      );
                    },
                    child: const Text(
                      "Forgot your password?",
                      style: TextStyle(
                        color: Color(0xffF37C50),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: () {
                    login(context, email, password);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xffF37C50),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    minimumSize: const Size(double.infinity, 50),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: const Text(
                    "Sign in",
                    style: TextStyle(fontSize: 18, color: Colors.white),
                  ),
                ),
                const SizedBox(height: 20),
                Center(
                  child: TextButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => RegisterScreen(),
                        ),
                      );
                    },
                    child: const Text(
                      "Create new account",
                      style: TextStyle(color: Colors.black87, fontSize: 16),
                    ),
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
