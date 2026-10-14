import 'package:flutter/material.dart';
import 'screens/home_screen.dart';

void main() {
  runApp(const EmoViApp());
}

class EmoViApp extends StatelessWidget {
  const EmoViApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,

      title: 'EmoVi',

      theme: ThemeData(
        fontFamily: 'Roboto',
        useMaterial3: true,
      ),

      home: const HomeScreen(),
    );
  }
}