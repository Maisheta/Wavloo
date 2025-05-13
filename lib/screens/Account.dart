import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:chat/screens/Welcome_Screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AccountPage extends StatelessWidget {
  const AccountPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: const Color(0xFFF37C50),
        elevation: 0,
        title: const Text('Account'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: ListView(
        children: [
          _buildSettingsTile(context, Icons.email, 'Email Address'),
          _buildSettingsTile(
            context,
            Icons.verified_user_sharp,
            'Two-step Verification',
          ),
          _buildSettingsTile(
            context,
            Icons.request_quote_outlined,
            'Request account info',
          ),
          _buildSettingsTile(context, Icons.person_add_alt_1, 'Add Account'),
          _buildSettingsTile(context, Icons.delete_rounded, 'Delete Account'),
          _buildSettingsTile(context, Icons.logout, 'Logout', isLogout: true),
        ],
      ),
    );
  }

  Widget _buildSettingsTile(
    BuildContext context,
    IconData icon,
    String title, {
    bool isLogout = false,
  }) {
    return Column(
      children: [
        ListTile(
          leading: Icon(icon, color: const Color(0xFFF37C50)),
          title: Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.w400),
          ),
          onTap: () {
            if (isLogout) {
              _showLogoutDialog(context);
            }
          },
        ),
        const Divider(),
      ],
    );
  }

  void _showLogoutDialog(BuildContext context) {
    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.2),
      builder: (_) {
        return Dialog(
          backgroundColor: Colors.transparent,
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 4, sigmaY: 4),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 24),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.85),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Are you sure you want to logout',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Color(0xFFF37C50),
                      fontSize: 18,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      TextButton(
                        onPressed: () async {
                          final prefs = await SharedPreferences.getInstance();
                          await prefs.clear(); // 🧹 مسح كل البيانات المحفوظة

                          if (context.mounted) {
                            Navigator.of(context).pop(); // يقفل الديالوج
                            Navigator.of(context).pushReplacement(
                              MaterialPageRoute(
                                builder: (_) => WelcomeScreen(),
                              ),
                            );
                          }
                        },
                        child: const Text(
                          'Yes',
                          style: TextStyle(
                            color: Color(0xFFF37C50),
                            fontSize: 16,
                          ),
                        ),
                      ),

                      TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text(
                          'No',
                          style: TextStyle(
                            color: Color(0xFFF37C50),
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
