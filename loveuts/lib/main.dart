import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'firebase_options.dart';
import 'services/fcm_service.dart';
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
  FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
  runApp(const LoveUTS());
}

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

class LoveUTS extends StatelessWidget {
  const LoveUTS({super.key});

  @override
  Widget build(BuildContext context) {
    return _FcmInitializer(
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        navigatorKey: navigatorKey,
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
      ),
    );
  }
}

class _FcmInitializer extends StatefulWidget {
  final Widget child;

  const _FcmInitializer({required this.child});

  @override
  State<_FcmInitializer> createState() => _FcmInitializerState();
}

class _FcmInitializerState extends State<_FcmInitializer> {
  @override
  void initState() {
    super.initState();
    FcmService.instance.initialize(navigatorKey);
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
