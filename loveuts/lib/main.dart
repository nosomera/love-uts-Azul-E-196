import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart'; 
import 'screens/splash_screen.dart';
import 'screens/login_screen.dart';
import 'screens/registro_screen.dart';
import 'screens/crear_perfil_pasos_screen.dart'; // Importante
import 'screens/home_screen.dart';              // Importante

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
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.green,
          primary: Colors.green,
        ),
        useMaterial3: true,
      ),
      home: const SplashScreen(),
      routes: {
        '/login': (context) => const LoginScreen(), 
        '/registro': (context) => const RegistroScreen(),
        '/crear_perfil': (context) => const CrearPerfilPasosScreen(), // Ruta agregada
        '/home': (context) => const HomeScreen(),                     // Ruta agregada
      },
    );
  }
}