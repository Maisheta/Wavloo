import 'package:flutter/material.dart';
import 'package:chat/screens/Home_screen.dart';
import 'package:pin_code_fields/pin_code_fields.dart';
import 'package:http/http.dart' as http;
import '../components/Orange_Circle.dart';

class VerifyScreen extends StatefulWidget {
  final String email;
  final http.Client? client;

  const VerifyScreen({super.key, required this.email, this.client});

  @override
  State<VerifyScreen> createState() => VerifyScreenState();
}

class VerifyScreenState extends State<VerifyScreen> {
  String otp = '';
  TextEditingController? otpController;

  @override
  void initState() {
    super.initState();
    otpController = TextEditingController();
  }

  Future<void> verifyOtp() async {
    if (otp.length != 6) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please enter a valid 6-digit OTP")),
      );
      return;
    }

    final url = Uri.parse(
      "https://6589-45-244-213-140.ngrok-free.app/api/Auth/validate-otp",
    );

    final client = widget.client ?? http.Client();
    try {
      final response = await client.post(
        url,
        headers: {"Content-Type": "application/json"},
        body: '{"email": "${widget.email}", "otp": "$otp"}',
      );

      if (!mounted) return;

      if (response.statusCode == 200) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const HomeScreen()),
        );
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text("❌ Invalid OTP")));
      }
    } catch (e) {
      print("OTP verification error: $e");
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Something went wrong")));
    }
  }

  Future<void> resendOtp() async {
    final url = Uri.parse(
      "https://6589-45-244-213-140.ngrok-free.app/api/Auth/resend-otp",
    );

    try {
      final response = await http.post(
        url,
        headers: {"Content-Type": "application/json"},
        body: '{"email": "${widget.email}"}',
      );

      if (!mounted) return;

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("✅ OTP re-sent successfully")),
        );
      } else {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text("❌ Failed to resend OTP")));
      }
    } catch (e) {
      print("Resend error: $e");
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("⚠️ Error resending OTP")));
    }
  }

  @override
  void dispose() {
    otpController?.dispose();
    otpController = null;
    super.dispose();
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
                    "Verification Code",
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
                    "We have sent the verification code to your email address",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                ),
                const SizedBox(height: 50),
                PinCodeTextField(
                  appContext: context,
                  controller: otpController,
                  length: 6,
                  obscureText: true,
                  animationType: AnimationType.fade,
                  keyboardType: TextInputType.number,
                  cursorColor: const Color(0xffF37C50),
                  textStyle: const TextStyle(fontSize: 20),
                  pinTheme: PinTheme(
                    shape: PinCodeFieldShape.box,
                    borderRadius: BorderRadius.circular(20),
                    fieldHeight: 65,
                    fieldWidth: 45,
                    inactiveColor: Colors.grey,
                    inactiveFillColor: const Color(
                      0xffF37C50,
                    ).withOpacity(0.08),
                    selectedColor: const Color(0xffF37C50),
                    selectedFillColor: Colors.white,
                    activeFillColor: Colors.white,
                  ),
                  onChanged: (value) {
                    if (!mounted) return;
                    setState(() {
                      otp = value;
                    });
                  },
                  onCompleted: (value) {
                    if (mounted) {
                      otp = value;
                    }
                  },
                ),
                const SizedBox(height: 40),
                ElevatedButton(
                  onPressed: verifyOtp,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xffF37C50),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    minimumSize: const Size(double.infinity, 50),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: const Text(
                    "Confirm",
                    style: TextStyle(fontSize: 18, color: Colors.white),
                  ),
                ),
                const SizedBox(height: 20),
                Center(
                  child: TextButton(
                    onPressed: resendOtp,
                    child: RichText(
                      text: const TextSpan(
                        children: [
                          TextSpan(
                            text: "Didn't receive code? ",
                            style: TextStyle(
                              color: Colors.black87,
                              fontSize: 16,
                            ),
                          ),
                          TextSpan(
                            text: "Resend",
                            style: TextStyle(
                              color: Color(0xffF37C50),
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
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
