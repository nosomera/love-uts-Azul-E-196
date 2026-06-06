import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../services/notification_navigation_service.dart';
import '../services/notifications_service.dart';

class NotificacionesScreen extends StatelessWidget {
  const NotificacionesScreen({super.key});

  static final NotificationsService _service = NotificationsService();

  @override
  Widget build(BuildContext context) {
    final miUid = FirebaseAuth.instance.currentUser?.uid;

    return Scaffold(
      backgroundColor: const Color(0xFFFFECEF),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 1,
        centerTitle: true,
        title: const Text(
          'Notificaciones',
          style: TextStyle(
            color: Color(0xFF1E5631),
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: miUid == null
          ? const Center(child: Text('No hay sesión activa'))
          : StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: _service.streamRecibidas(miUid),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(color: Colors.redAccent),
                  );
                }

                final docs = [...snapshot.data?.docs ?? []]
                  ..sort((a, b) {
                    final fechaA = a.data()['creadaEn'] as Timestamp?;
                    final fechaB = b.data()['creadaEn'] as Timestamp?;
                    return (fechaB?.millisecondsSinceEpoch ?? 0).compareTo(
                      fechaA?.millisecondsSinceEpoch ?? 0,
                    );
                  });
                if (docs.isEmpty) return _estadoVacio();

                return ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: docs.length,
                  separatorBuilder: (context, index) =>
                      const SizedBox(height: 8),
                  itemBuilder: (context, i) {
                    final doc = docs[i];
                    final data = doc.data();
                    return _NotificacionTile(
                      data: data,
                      onTap: () => _abrirNotificacion(context, doc.id, data),
                    );
                  },
                );
              },
            ),
    );
  }

  Widget _estadoVacio() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.notifications_none, size: 80, color: Colors.grey[400]),
          const SizedBox(height: 20),
          Text(
            'Aca apareceran tus notificaciones',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 16, color: Colors.grey[600]),
          ),
        ],
      ),
    );
  }

  Future<void> _abrirNotificacion(
    BuildContext context,
    String notificacionId,
    Map<String, dynamic> data,
  ) async {
    try {
      await _service.marcarComoLeida(notificacionId);

      final matchId = data['matchId'] as String?;
      if (matchId != null && matchId.isNotEmpty) {
        if (!context.mounted) return;
        await NotificationNavigationService.instance.abrirChatDesdeMatch(
          navigator: Navigator.of(context),
          matchId: matchId,
        );
        return;
      }

      if (!context.mounted) return;
      await showDialog<void>(
        context: context,
        builder: (ctx) => _DetalleNotificacionDialog(data: data),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al abrir notificación: $e')),
      );
    }
  }

}

class _NotificacionTile extends StatelessWidget {
  final Map<String, dynamic> data;
  final VoidCallback onTap;

  const _NotificacionTile({required this.data, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final leida = data['leida'] == true;
    final asunto = data['asunto'] ?? 'Notificación';
    final preview = data['preview'] ?? data['contenido'] ?? '';
    final creadaEn = data['creadaEn'] as Timestamp?;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: leida
            ? null
            : Border.all(color: Colors.redAccent.withValues(alpha: 0.35)),
      ),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor:
              leida ? Colors.grey[200] : Colors.redAccent.withValues(alpha: 0.15),
          child: Icon(
            _iconoTipo(data['tipo'] as String?),
            color: leida ? Colors.grey : Colors.redAccent,
          ),
        ),
        title: Text(
          asunto,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontWeight: leida ? FontWeight.w500 : FontWeight.bold,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(preview, maxLines: 1, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 3),
            Text(
              _formatearFecha(creadaEn),
              style: TextStyle(fontSize: 11, color: Colors.grey[600]),
            ),
          ],
        ),
        trailing: leida
            ? null
            : const Icon(Icons.circle, color: Colors.redAccent, size: 10),
        onTap: onTap,
      ),
    );
  }

  IconData _iconoTipo(String? tipo) {
    if (tipo == 'match') return Icons.favorite;
    if (tipo == 'mensaje') return Icons.chat_bubble;
    return Icons.notifications;
  }

  String _formatearFecha(Timestamp? ts) {
    if (ts == null) return '';
    final dt = ts.toDate();
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '${dt.day}/${dt.month}/${dt.year} $h:$m';
  }
}

class _DetalleNotificacionDialog extends StatelessWidget {
  final Map<String, dynamic> data;

  const _DetalleNotificacionDialog({required this.data});

  @override
  Widget build(BuildContext context) {
    final creadaEn = data['creadaEn'] as Timestamp?;
    return AlertDialog(
      title: Text(data['asunto'] ?? 'Notificación'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(data['contenido'] ?? ''),
          const SizedBox(height: 16),
          Text('Tipo: ${data['tipo'] ?? 'sistema'}'),
          Text('Origen: ${data['uidOrigen'] ?? 'sistema'}'),
          Text('Fecha: ${_formatearFecha(creadaEn)}'),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cerrar'),
        ),
      ],
    );
  }

  String _formatearFecha(Timestamp? ts) {
    if (ts == null) return '';
    final dt = ts.toDate();
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '${dt.day}/${dt.month}/${dt.year} $h:$m';
  }
}
