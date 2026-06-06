import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../firebase_options.dart';
import '../services/notification_navigation_service.dart';
import '../screens/notificaciones_screen.dart';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
}

class FcmService {
  FcmService._();

  static final FcmService instance = FcmService._();

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  GlobalKey<NavigatorState>? _navigatorKey;

  Future<void> initialize(GlobalKey<NavigatorState> navigatorKey) async {
    _navigatorKey = navigatorKey;

    try {
      await _messaging.requestPermission(alert: true, badge: true, sound: true);
      await _messaging.setForegroundNotificationPresentationOptions(
        alert: true,
        badge: true,
        sound: true,
      );
    } catch (_) {}

    FirebaseAuth.instance.authStateChanges().listen((user) {
      if (user != null) _guardarTokenActual(user.uid).catchError((_) {});
    });

    _messaging.onTokenRefresh.listen((token) {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid != null) _guardarToken(uid, token).catchError((_) {});
    });

    FirebaseMessaging.onMessage.listen(_mostrarAvisoForeground);
    FirebaseMessaging.onMessageOpenedApp.listen(_abrirDesdeMensaje);

    final initialMessage = await _messaging.getInitialMessage();
    if (initialMessage != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _abrirDesdeMensajeInicial(initialMessage);
      });
    }
  }

  Future<void> _abrirDesdeMensajeInicial(RemoteMessage message) async {
    NavigatorState? navigator;
    for (var i = 0; i < 20; i++) {
      navigator = _navigatorKey?.currentState;
      if (navigator != null) break;
      await Future<void>.delayed(const Duration(milliseconds: 100));
    }

    final user = FirebaseAuth.instance.currentUser;
    if (navigator == null || user == null) return;

    navigator.pushNamedAndRemoveUntil('/home', (route) => false);
    await Future<void>.delayed(const Duration(milliseconds: 300));
    await _abrirDesdeMensaje(message);
  }

  Future<void> _guardarTokenActual(String uid) async {
    final token = await _messaging.getToken();
    if (token != null) await _guardarToken(uid, token);
  }

  Future<void> _guardarToken(String uid, String token) async {
    await _db
        .collection('usuarios')
        .doc(uid)
        .collection('fcmTokens')
        .doc(token)
        .set({
          'token': token,
          'plataforma': _plataforma,
          'actualizadoEn': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
  }

  Future<void> eliminarTokenActual() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final token = await _messaging.getToken();
    if (token == null) return;

    await _db
        .collection('usuarios')
        .doc(uid)
        .collection('fcmTokens')
        .doc(token)
        .delete();
  }

  String get _plataforma {
    if (kIsWeb) return 'web';
    return defaultTargetPlatform.name.toLowerCase();
  }

  void _mostrarAvisoForeground(RemoteMessage message) {
    final context = _navigatorKey?.currentContext;
    if (context == null) return;

    final title = message.notification?.title ?? message.data['asunto'];
    final body = message.notification?.body ?? message.data['preview'];
    if (title == null && body == null) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text([title, body].whereType<String>().join('\n')),
        action: SnackBarAction(
          label: 'Abrir',
          onPressed: () => _abrirDesdeMensaje(message),
        ),
      ),
    );
  }

  Future<void> _abrirDesdeMensaje(RemoteMessage message) async {
    final navigator = _navigatorKey?.currentState;
    final context = _navigatorKey?.currentContext;
    if (navigator == null || context == null) return;

    final notificacionId = message.data['notificacionId'];
    if (notificacionId is String && notificacionId.isNotEmpty) {
      await NotificationNavigationService.instance.marcarNotificacionLeida(
        notificacionId,
      );
    }

    final matchId = message.data['matchId'];
    if (matchId is String && matchId.isNotEmpty) {
      await NotificationNavigationService.instance.abrirChatDesdeMatch(
        navigator: navigator,
        matchId: matchId,
      );
      return;
    }

    navigator.push(
      MaterialPageRoute(builder: (_) => const NotificacionesScreen()),
    );
  }
}
