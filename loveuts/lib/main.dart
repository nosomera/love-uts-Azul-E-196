import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart'; // Importante: Ya no debería marcar error
import 'screens/splash_screen.dart';
import 'screens/login_screen.dart';
import 'screens/registro_screen.dart';

void main() async {
  // 1. Vinculación obligatoria de widgets para procesos asíncronos
  WidgetsFlutterBinding.ensureInitialized();

  // 2. Inicialización de Firebase con las opciones generadas por la CLI
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
      
      // Configuración del tema con los colores institucionales (Verde)
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.green,
          primary: Colors.green,
        ),
        useMaterial3: true,
      ),

      // 3. Definición de la pantalla inicial
      home: const SplashScreen(),

      // 4. Mapa de rutas para navegar fácilmente entre pantallas
      routes: {
  '/login': (context) => const LoginScreen(), 
  
  '/registro': (context) => const RegistroScreen(),
},
    );
  }
}