import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/services/launch_service.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:katonagari/core/services/notification_service.dart';
import 'app.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();       // ← must be first
  await NotificationService.instance.init();
    GoogleFonts.config.allowRuntimeFetching = false;  
  WidgetsFlutterBinding.ensureInitialized();

  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
  ]);

  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    systemNavigationBarColor: Colors.transparent,
  ));

  // Check first launch BEFORE runApp
  final isFirstLaunch = await LaunchService.isFirstLaunch();
  runApp(ProviderScope(
    child: KatonagariApp(isFirstLaunch: isFirstLaunch),
  ));
}