import 'package:flutter/material.dart';

import 'features/sessions/session_screen.dart';

void main() {
  runApp(const AthlunkardBoatClubApp());
}

class AthlunkardBoatClubApp extends StatelessWidget {
  const AthlunkardBoatClubApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Athlunkard Boat Club',
      theme: ThemeData(
        colorSchemeSeed: Colors.blue,
        useMaterial3: true,
      ),
      home: const SessionScreen(),
    );
  }
}
