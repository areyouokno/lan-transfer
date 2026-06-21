import 'package:flutter/material.dart';
import 'features/home/home_page.dart';

void main() {
  runApp(const LanTransferApp());
}

class LanTransferApp extends StatelessWidget {
  const LanTransferApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '局域网文件传输',
      theme: ThemeData(
        colorSchemeSeed: Colors.indigo,
        useMaterial3: true,
      ),
      home: const HomePage(),
    );
  }
}
