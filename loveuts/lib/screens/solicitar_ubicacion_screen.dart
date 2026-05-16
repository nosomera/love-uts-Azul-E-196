import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class SolicitarUbicacionScreen extends StatefulWidget {
  const SolicitarUbicacionScreen({super.key});

  @override
  State<SolicitarUbicacionScreen> createState() => _SolicitarUbicacionScreenState();
}

class _SolicitarUbicacionScreenState extends State<SolicitarUbicacionScreen> {
  bool _cargandoUbicacion = false;

  Future<void> _obtenerYGuardarUbicacion() async {
    setState(() => _cargandoUbicacion = true);

    try {
      bool servicioHabilitado;
      LocationPermission permiso;

      // Verificar si el GPS está encendido en el celular
      servicioHabilitado = await Geolocator.isLocationServiceEnabled();
      if (!servicioHabilitado) {
        throw 'El servicio de ubicación está desactivado en el dispositivo.';
      }

      // Verificar los permisos de la app
      permiso = await Geolocator.checkPermission();
      if (permiso == LocationPermission.denied) {
        permiso = await Geolocator.requestPermission();
        if (permiso == LocationPermission.denied) {
          throw 'Permiso de ubicación denegado.';
        }
      }

      if (permiso == LocationPermission.deniedForever) {
        throw 'Los permisos de ubicación están denegados permanentemente. Habilítalos en ajustes.';
      }

      // Obtener posición actual del GPS
      Position posicion = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        // Guardar las coordenadas en el perfil del usuario de Firestore
        await FirebaseFirestore.instance.collection('usuarios').doc(user.uid).update({
          'latitud': posicion.latitude,
          'longitud': posicion.longitude,
          'ubicacion_lista': true,
        });

        if (mounted) {
          Navigator.pushReplacementNamed(context, '/home');
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error de ubicación: $e'), backgroundColor: Colors.redAccent),
        );
      }
    } finally {
      if (mounted) setState(() => _cargandoUbicacion = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFECEF),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 30),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Spacer(),
              // Icono de Pin Verde del Mockup
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(color: Colors.black, blurRadius: 10, offset: const Offset(0, 5))
                  ],
                ),
                child: const Icon(Icons.location_on, size: 100, color: Colors.green),
              ),
              const SizedBox(height: 40),
              const Text(
                'Habilita Tu Ubicación',
                style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: Colors.black),
              ),
              const SizedBox(height: 15),
              const Text(
                'Elige tu ubicación para empezar a encontrar gente a tu alrededor en Love UTS.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 15, color: Colors.grey, height: 1.4),
              ),
              const Spacer(),
              
              _cargandoUbicacion
                  ? const CircularProgressIndicator(color: Colors.green)
                  : Column(
                      children: [
                        SizedBox(
                          width: double.infinity,
                          height: 55,
                          child: ElevatedButton(
                            onPressed: _obtenerYGuardarUbicacion,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green[700],
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
                            ),
                            child: const Text(
                              'Permitir acceso a la ubicación',
                              style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                        TextButton(
                          onPressed: () {
                            // Enrutamiento directo al Home si prefiere no dar permisos ahora
                            Navigator.pushReplacementNamed(context, '/home');
                          },
                          child: const Text(
                            'O active su ubicación manualmente',
                            style: TextStyle(color: Colors.redAccent, fontSize: 14, fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],
                    ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}