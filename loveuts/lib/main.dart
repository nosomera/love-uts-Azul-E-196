import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'theme/app_theme.dart';
import 'screens/splash_screen.dart';
import 'screens/login_screen.dart';
import 'screens/registro_screen.dart';
import 'screens/crear_perfil_pasos_screen.dart';
import 'screens/solicitar_ubicacion_screen.dart';
import 'screens/main_navigation_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const LoveUTS());
}

class LoveUTS extends StatelessWidget {
  const LoveUTS({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Love UTS',
      theme: AppTheme.light,
      home: const SplashScreen(),
      routes: {
        '/login': (context) => const LoginScreen(), 
        '/registro': (context) => const RegistroScreen(),
        '/crear_perfil': (context) => const CrearPerfilPasosScreen(),
        '/solicitar_ubicacion': (context) => const SolicitarUbicacionScreen(),
        '/home': (context) => const MainNavigationScreen(),
      },
    );
  }
}