import 'package:cloud_firestore/cloud_firestore.dart';

class NotificationsService {
  NotificationsService({FirebaseFirestore? firestore})
      : _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  Stream<QuerySnapshot<Map<String, dynamic>>> streamRecibidas(String uid) {
    return _db
        .collection('notificaciones')
        .where('uidDestino', isEqualTo: uid)
        .snapshots();
  }

  Future<void> marcarComoLeida(String notificacionId) {
    return _db.collection('notificaciones').doc(notificacionId).update({
      'leida': true,
      'leidaEn': FieldValue.serverTimestamp(),
    });
  }

  Future<void> crearNotificacionesMatch({
    required String matchId,
    required String uidA,
    required String uidB,
  }) async {
    final perfiles = await Future.wait([
      _db.collection('usuarios').doc(uidA).get(),
      _db.collection('usuarios').doc(uidB).get(),
    ]);
    final nombreA = perfiles[0].data()?['nombre'] ?? 'Usuario';
    final nombreB = perfiles[1].data()?['nombre'] ?? 'Usuario';

    final batch = _db.batch();
    final creadaEn = FieldValue.serverTimestamp();

    _agregarNotificacionBatch(
      batch: batch,
      uidDestino: uidA,
      uidOrigen: uidB,
      tipo: 'match',
      asunto: 'Nuevo match',
      contenido: 'Tú y $nombreB se gustaron mutuamente. Ya pueden chatear.',
      preview: 'Tienes un nuevo match con $nombreB',
      matchId: matchId,
      creadaEn: creadaEn,
      data: {'nombreOrigen': nombreB},
    );

    _agregarNotificacionBatch(
      batch: batch,
      uidDestino: uidB,
      uidOrigen: uidA,
      tipo: 'match',
      asunto: 'Nuevo match',
      contenido: 'Tú y $nombreA se gustaron mutuamente. Ya pueden chatear.',
      preview: 'Tienes un nuevo match con $nombreA',
      matchId: matchId,
      creadaEn: creadaEn,
      data: {'nombreOrigen': nombreA},
    );

    await batch.commit();
  }

  Future<void> crearNotificacionMensaje({
    required String uidDestino,
    required String uidOrigen,
    required String matchId,
    required String mensajeId,
    required String texto,
  }) async {
    final origen = await _db.collection('usuarios').doc(uidOrigen).get();
    final nombreOrigen = origen.data()?['nombre'] ?? 'Usuario';
    final preview = texto.length > 80 ? '${texto.substring(0, 80)}...' : texto;

    await _db.collection('notificaciones').add({
      'uidDestino': uidDestino,
      'uidOrigen': uidOrigen,
      'tipo': 'mensaje',
      'asunto': 'Nuevo mensaje de $nombreOrigen',
      'contenido': texto,
      'preview': preview,
      'matchId': matchId,
      'mensajeId': mensajeId,
      'leida': false,
      'creadaEn': FieldValue.serverTimestamp(),
      'direccion': 'recibida',
      'data': {
        'nombreOrigen': nombreOrigen,
        'fcmReady': true,
      },
    });
  }

  void _agregarNotificacionBatch({
    required WriteBatch batch,
    required String uidDestino,
    required String uidOrigen,
    required String tipo,
    required String asunto,
    required String contenido,
    required String preview,
    required FieldValue creadaEn,
    String? matchId,
    String? mensajeId,
    Map<String, dynamic>? data,
  }) {
    final ref = _db.collection('notificaciones').doc();
    batch.set(ref, {
      'uidDestino': uidDestino,
      'uidOrigen': uidOrigen,
      'tipo': tipo,
      'asunto': asunto,
      'contenido': contenido,
      'preview': preview,
      'matchId': matchId,
      'mensajeId': mensajeId,
      'leida': false,
      'creadaEn': creadaEn,
      'direccion': 'recibida',
      'data': {
        ...?data,
        'fcmReady': true,
      },
    });
  }
}
