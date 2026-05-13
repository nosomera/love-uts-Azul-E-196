import 'package:flutter/material.dart';
import 'dart:async';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    // Temporizador de 3 segundos antes de saltar al Login
    Timer(const Duration(seconds: 3), () {
      // pushReplacementNamed evita que el usuario pueda volver atrás a la Splash
      Navigator.pushReplacementNamed(context, '/login');
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Usamos un fondo blanco limpio o podrías usar un degradado verde
      backgroundColor: Colors.white,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // 1. El Logo de las UTS (Asegúrate de tenerlo en la carpeta assets)
            Image.asset(
              'assets/logo_uts.png',
              width: 180,
              errorBuilder: (context, error, stackTrace) {
                // Si la imagen falla o no está, muestra un icono temporal
                return const Icon(Icons.favorite, size: 100, color: Colors.green);
              },
            ),
            const SizedBox(height: 30),
            
            // 2. Título de la App
            const Text(
              'LOVE UTS',
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: Colors.green,
                letterSpacing: 2,
              ),
            ),
            
            // 3. Eslogan o indicador de carga
            const SizedBox(height: 10),
            const Text(
              'Encuentra tu pareja ideal en la U',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey,
                fontStyle: FontStyle.italic,
              ),
            ),
            
            const SizedBox(height: 50),
            // Indicador de carga sutil
            const CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Colors.green),
            ),
          ],
        ),
      ),
    );
  }
}