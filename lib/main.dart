import 'package:flutter/material.dart';
// 나중에 여기다 화면들 추가 할듯

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '줍다행',
      theme: ThemeData(useMaterial3: true),
      home: const Scaffold(
        body: Center(
          child: Text('ddd'),
        ),
      ),
    );
  }
}
