import 'dart:io';

import 'package:flutter/material.dart';

import 'features/connection/connection_screen.dart';
import 'features/host/host_screen.dart';
import 'shared/theme.dart';

class GamepadApp extends StatelessWidget {
  const GamepadApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Mobile Gamepad',
      theme: AppTheme.dark,
      debugShowCheckedModeBanner: false,
      // Android → controller side,  Windows → host side
      home: Platform.isWindows
          ? const HostScreen()
          : const ConnectionScreen(),
    );
  }
}
