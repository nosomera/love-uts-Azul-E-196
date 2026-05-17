import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';

class Historia {
  final String id;
  final String uid;
  final String url;
  final DateTime timestamp;
  final List<String> vistas;

  Historia({
    required this.id,
    required this.uid,
    required this.url,
    required this.timestamp,
    required this.vistas,
  });

  factory Historia.fromDoc(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Historia(
      id: doc.id,
      uid: data['uid'] as String? ?? '',
      url: data['url'] as String? ?? '',
      timestamp:
          (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
      vistas: List<String>.from(data['vistas'] ?? const []),
    );
  }
}

/// Agrupa varias historias de un mismo autor en un solo "anillo".
class GrupoHistorias {
  final String uid;
  final List<Historia> historias;

  GrupoHistorias({required this.uid, required this.historias});

  bool todasVistas(String miUid) =>
      historias.every((h) => h.vistas.contains(miUid));

  Historia get masReciente => historias.last;
}

class StoriesService {
  StoriesService._();
  static final instance = StoriesService._();

  static const Duration _duracionStory = Duration(hours: 24);

  CollectionReference<Map<String, dynamic>> get _col =>
      FirebaseFirestore.instance.collection('historias');

  /// Stream de historias activas (últimas 24h) de [uids].
  /// Devuelve agrupadas por autor, ordenadas por última publicación.
  Stream<List<GrupoHistorias>> streamHistoriasDe(List<String> uids) {
    if (uids.isEmpty) return Stream.value(const []);

    final corte = Timestamp.fromDate(
      DateTime.now().subtract(_duracionStory),
    );

    // Firestore whereIn admite hasta 30 valores (v5+). Para más, habría
    // que dividir en bloques. Para nuestro caso (matches reales) alcanza.
    final lote = uids.take(30).toList();

    return _col
        .where('uid', whereIn: lote)
        .where('timestamp', isGreaterThan: corte)
        .orderBy('timestamp', descending: false)
        .snapshots()
        .map((snap) {
      final mapa = <String, List<Historia>>{};
      for (final doc in snap.docs) {
        final h = Historia.fromDoc(doc);
        mapa.putIfAbsent(h.uid, () => []).add(h);
      }
      final grupos = mapa.entries
          .map((e) => GrupoHistorias(uid: e.key, historias: e.value))
          .toList();
      grupos.sort(
        (a, b) => b.masReciente.timestamp.compareTo(a.masReciente.timestamp),
      );
      return grupos;
    });
  }

  /// Sube una imagen a Firebase Storage y crea el doc en Firestore.
  Future<void> subirHistoria(File archivo) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) throw Exception('Sesión inválida');

    final nombre = DateTime.now().millisecondsSinceEpoch.toString();
    final ref = FirebaseStorage.instance.ref('historias/$uid/$nombre.jpg');
    await ref.putFile(archivo);
    final url = await ref.getDownloadURL();

    await _col.add({
      'uid': uid,
      'url': url,
      'timestamp': FieldValue.serverTimestamp(),
      'vistas': <String>[],
    });
  }

  /// Marca una historia como vista por el usuario actual.
  Future<void> marcarVista(String historiaId) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    await _col.doc(historiaId).update({
      'vistas': FieldValue.arrayUnion([uid]),
    });
  }
}
