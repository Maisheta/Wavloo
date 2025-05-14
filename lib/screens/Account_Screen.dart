import 'dart:convert'; // For JSON parsing
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart';
import 'package:shared_preferences/shared_preferences.dart'; // Add this
import 'package:chat/screens/verify_screen.dart';
import '../components/Orange_Circle.dart';
import '../components/TextField.dart';
import 'package:chat/screens/Login_Screen.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final TextEditingController firstNameController = TextEditingController();
  final TextEditingController lastNameController = TextEditingController();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final TextEditingController confirmPasswordController =
      TextEditingController();

  File? selectedImage;

  Future<void> pickImage() async {
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (picked != null) {
      setState(() {
        selectedImage = File(picked.path);
      });
    }
  }

  Future<void> register(BuildContext context) async {
    final url = Uri.parse(
      'https://45ff-45-244-177-153.ngrok-free.app/api/Auth/register',
    );
    final request = http.MultipartRequest('POST', url);

    request.fields['FirstName'] = firstNameController.text.trim();
    request.fields['LastName'] = lastNameController.text.trim();
    request.fields['Email'] = emailController.text.trim();
    request.fields['Password'] = passwordController.text;
    request.fields['ConfirmPassword'] = confirmPasswordController.text;

    if (selectedImage != null) {
      request.files.add(
        await http.MultipartFile.fromPath(
          'ProfileImage',
          selectedImage!.path,
          filename: basename(selectedImage!.path),
        ),
      );
    } else {
      request.fields['ProfileImage'] = 'Hey';
    }

    try {
      final response = await request.send();
      final respStr = await response.stream.bytesToString();

      print("📡 Register Response Code: ${response.statusCode}");
      print("📨 Register Response Body: $respStr");

      if (response.statusCode == 200) {
        final responseData = jsonDecode(respStr);
        // Try multiple token keys or nested structures
        String? token =
            responseData['token'] ??
            responseData['accessToken'] ??
            responseData['jwt'] ??
            responseData['authToken'] ??
            responseData['data']?['token'] ??
            responseData['data']?['accessToken'];

        if (token == null) {
          print("❌ No token found in response. Full response: $responseData");
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Error: No token in response')),
            );
          }
          return;
        }

        // Save token under 'token' to match ChatsListScreen
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('token', token);
        // Verify token is saved
        final savedToken = prefs.getString('token');
        print("✅ Token saved: $savedToken");

        if (mounted) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder:
                  (context) => VerifyScreen(email: emailController.text.trim()),
            ),
          );
        }
      } else {
        print(
          "❌ Registration failed. Status: ${response.statusCode}, Body: $respStr",
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Registration failed: $respStr')),
          );
        }
      }
    } catch (e) {
      print("❌ Register Exception: $e");
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Something went wrong!')));
      }
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
                    "Create Account",
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
                    "Create your account and stay connected with\nwho matters",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                ),
                const SizedBox(height: 45),
                CustomTextField(
                  controller: firstNameController,
                  label: "First Name",
                  onChanged: (value) {
                    print("First name is: $value");
                  },
                ),
                const SizedBox(height: 20),
                CustomTextField(
                  controller: lastNameController,
                  label: "Last Name",
                  onChanged: (value) {
                    print("Last name is: $value");
                  },
                ),
                const SizedBox(height: 20),
                CustomTextField(
                  controller: emailController,
                  label: "Email",
                  onChanged: (value) {
                    print("Email is: $value");
                  },
                ),
                const SizedBox(height: 20),
                CustomTextField(
                  controller: passwordController,
                  label: "Password",
                  isPassword: true,
                  onChanged: (value) {
                    print("Password is: $value");
                  },
                ),
                const SizedBox(height: 20),
                CustomTextField(
                  controller: confirmPasswordController,
                  label: "Confirm Password",
                  isPassword: true,
                  onChanged: (value) {
                    print("Confirm password is: $value");
                  },
                ),
                const SizedBox(height: 50),
                ElevatedButton(
                  onPressed: () {
                    register(context);
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
                    "Sign Up",
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
                          builder: (context) => const Login_Screen(),
                        ),
                      );
                    },
                    child: const Text(
                      "Already have an account",
                      style: TextStyle(color: Colors.black87, fontSize: 16),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
