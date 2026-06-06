import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../screens/chat_screen.dart';

class NotificationNavigationService {
  NotificationNavigationService._();

  static final NotificationNavigationService instance =
      NotificationNavigationService._();

  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Future<void> marcarNotificacionLeida(String notificacionId) async {
    if (notificacionId.isEmpty) return;
    await _db.collection('notificaciones').doc(notificacionId).update({
      'leida': true,
      'leidaEn': FieldValue.serverTimestamp(),
    });
  }

  Future<void> abrirChatDesdeMatch({
    required NavigatorState navigator,
    required String matchId,
  }) async {
    final miUid = FirebaseAuth.instance.currentUser?.uid;
    if (miUid == null || matchId.isEmpty) return;

    final match = await _db.collection('matches').doc(matchId).get();
    final users = List<String>.from(match.data()?['users'] ?? []);
    final otroUid = users.firstWhere((u) => u != miUid, orElse: () => '');
    if (otroUid.isEmpty) return;

    final perfil = await _db.collection('usuarios').doc(otroUid).get();
    final perfilData = perfil.data();
    final nombre = perfilData?['nombre'] ?? 'Usuario';
    final fotos = perfilData?['fotos'] as List<dynamic>?;
    final fotoUrl = fotos != null && fotos.isNotEmpty ? fotos[0] : null;

    navigator.push(
      MaterialPageRoute(
        builder: (_) => ChatScreen(
          matchId: matchId,
          otroUid: otroUid,
          nombreOtro: nombre,
          fotoOtro: fotoUrl,
        ),
      ),
    );
  }
}
