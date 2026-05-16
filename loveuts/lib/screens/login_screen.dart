import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  // Controladores para capturar lo que el usuario escribe
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _isLoading = false;

  // Función para iniciar sesión
  Future<void> _login() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Por favor llena todos los campos')),
      );
      return;
    }
/*
    // Validación de correo institucional según tu Backlog
    if (!email.endsWith('@correo.uts.edu.co')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Usa tu correo @correo.uts.edu.co')),
      );
      return;
    }
*/
    setState(() => _isLoading = true);

    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      // Si entra con éxito, aquí lo mandas a la pantalla de Matches o Perfil
      print("Sesión iniciada");
    } on FirebaseAuthException catch (e) {
      String mensaje = 'Error al iniciar sesión';
      if (e.code == 'user-not-found') mensaje = 'Usuario no registrado';
      if (e.code == 'wrong-password') mensaje = 'Contraseña incorrecta';
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(mensaje)),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SingleChildScrollView( // Para que no tape el teclado los campos
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 60),
          child: Column(
            children: [
              Image.asset('assets/LogoLoveUTS.png', height: 120),
              const SizedBox(height: 20),
              const Text(
                'LOVE UTS',
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.green),
              ),
              const SizedBox(height: 40),
              // Campo de Correo
              TextField(
                controller: _emailController,
                decoration: const InputDecoration(
                  labelText: 'Correo Institucional',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(IconData(0xe22a, fontFamily: 'MaterialIcons')), // Icono de correo
                ),
              ),
              const SizedBox(height: 20),
              // Campo de Contraseña
              TextField(
                controller: _passwordController,
                obscureText: true, // Para ocultar la clave (Seguridad CRC-010)
                decoration: const InputDecoration(
                  labelText: 'Contraseña',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(IconData(0xe3ae, fontFamily: 'MaterialIcons')), // Icono de llave
                ),
              ),
              const SizedBox(height: 30),
              // Botón Continuar (Mockup pág 1)
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _login,
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                  child: _isLoading 
                    ? const CircularProgressIndicator(color: Colors.white) 
                    : const Text('Continuar', style: TextStyle(color: Colors.white, fontSize: 18)),
                ),
              ),
              TextButton(
                onPressed: () {
                  Navigator.pushNamed(context, '/registro');
                },
                child: const Text('¿No tienes cuenta? Regístrate aquí'),
              )
            ],
          ),
        ),
      ),
    );
  }
}