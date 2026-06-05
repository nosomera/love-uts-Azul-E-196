import 'package:flutter/material.dart';
import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../theme/app_colors.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late final AnimationController _entradaCtrl;
  late final AnimationController _latidoCtrl;
  late final Animation<double> _scaleAnim;
  late final Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();

    _entradaCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _scaleAnim = CurvedAnimation(
      parent: _entradaCtrl,
      curve: Curves.elasticOut,
    );
    _fadeAnim = CurvedAnimation(
      parent: _entradaCtrl,
      curve: const Interval(0.0, 0.5, curve: Curves.easeIn),
    );
    _entradaCtrl.forward();

    _latidoCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);

    Timer(const Duration(milliseconds: 2200), _decidirRuta);
  }

  Future<void> _decidirRuta() async {
    if (!mounted) return;
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      Navigator.pushReplacementNamed(context, '/login');
      return;
    }

    try {
      final doc = await FirebaseFirestore.instance
          .collection('usuarios')
          .doc(user.uid)
          .get();
      if (!mounted) return;
      final data = doc.data();
      if (data != null && data['perfil_completo'] == true) {
        Navigator.pushReplacementNamed(context, '/home');
      } else {
        Navigator.pushReplacementNamed(context, '/crear_perfil');
      }
    } catch (_) {
      if (mounted) Navigator.pushReplacementNamed(context, '/login');
    }
  }

  @override
  void dispose() {
    _entradaCtrl.dispose();
    _latidoCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.softPink,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            FadeTransition(
              opacity: _fadeAnim,
              child: ScaleTransition(
                scale: _scaleAnim,
                child: Image.asset(
                  'assets/LogoLoveUTS.png',
                  width: 200,
                  errorBuilder: (context, error, stackTrace) {
                    return const Icon(Icons.favorite,
                        size: 100, color: AppColors.darkGreen);
                  },
                ),
              ),
            ),
            const SizedBox(height: 32),
            FadeTransition(
              opacity: CurvedAnimation(
                parent: _entradaCtrl,
                curve: const Interval(0.5, 1.0, curve: Curves.easeIn),
              ),
              child: const Text(
                'LOVE UTS',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: AppColors.darkGreen,
                  letterSpacing: 3,
                ),
              ),
            ),
            const SizedBox(height: 8),
            FadeTransition(
              opacity: CurvedAnimation(
                parent: _entradaCtrl,
                curve: const Interval(0.6, 1.0, curve: Curves.easeIn),
              ),
              child: const Text(
                'Conoce a tu alma gemela',
                style: TextStyle(
                  fontSize: 14,
                  color: AppColors.textSecondary,
                  letterSpacing: 1.5,
                ),
              ),
            ),
            const SizedBox(height: 60),
            AnimatedBuilder(
              animation: _latidoCtrl,
              builder: (context, child) {
                final t = _latidoCtrl.value;
                return Transform.scale(
                  scale: 0.9 + (t * 0.25),
                  child: Opacity(
                    opacity: 0.4 + (t * 0.6),
                    child: const Icon(Icons.favorite,
                        color: AppColors.likeRed, size: 28),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
