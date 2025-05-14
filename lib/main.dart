import 'package:flutter/material.dart';
import 'package:chat/screens/Welcome_Screen.dart';
import 'package:chat/screens/Splash_Screen.dart'; // تأكد إن الملف اسمه كده بدون مسافة

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      initialRoute: '/',
      routes: {
        '/': (context) => const SplashScreen(),
        '/welcome': (context) => WelcomeScreen(),
      },
    );
  }
}
