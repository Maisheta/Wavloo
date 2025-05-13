import 'package:flutter/material.dart';
import 'package:chat/screens/Welcome_Screen.dart';
import 'package:chat/screens/Splash Screen.dart';

void main() async {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(debugShowCheckedModeBanner: false, home: SplashScreen());
  }
}
