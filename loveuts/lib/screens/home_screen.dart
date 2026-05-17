import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_card_swiper/flutter_card_swiper.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import '../theme/app_colors.dart';
import 'story_viewer_screen.dart';
import 'detalle_perfil_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final Set<String> _yaInteractuados = <String>{};
  final Set<String> _bloqueados = <String>{};
  final Set<String> _miMatchesUids = <String>{};
  bool _cargando = true;
  bool _subiendoStory = false;

  int? _miEdadMin;
  int? _miEdadMax;
  double? _miDistanciaMax;
  double? _miLat;
  double? _miLng;

  final CardSwiperController _swiperController = CardSwiperController();
  final ImagePicker _picker = ImagePicker();

  String? get _miUid => FirebaseAuth.instance.currentUser?.uid;

  @override
  void initState() {
    super.initState();
    _cargarDatosIniciales();
  }

  @override
  void dispose() {
    _swiperController.dispose();
    super.dispose();
  }

  Future<void> _cargarDatosIniciales() async {
    final uid = _miUid;
    if (uid == null) {
      setState(() => _cargando = false);
      return;
    }
    try {
      final db = FirebaseFirestore.instance;
      final results = await Future.wait([
        db.collection('likes').doc(uid).collection('dados').get(),
        db.collection('bloqueos').doc(uid).collection('usuarios').get(),
        db.collection('usuarios').doc(uid).get(),
        db.collection('matches').where('users', arrayContains: uid).get(),
      ]);
      _yaInteractuados
          .addAll((results[0] as QuerySnapshot).docs.map((d) => d.id));
      _bloqueados.addAll((results[1] as QuerySnapshot).docs.map((d) => d.id));
      final matchesSnap = results[3] as QuerySnapshot;
      for (final doc in matchesSnap.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final users = List<String>.from(data['users'] ?? []);
        for (final u in users) {
          if (u != uid) _miMatchesUids.add(u);
        }
      }
      final miPerfil =
          (results[2] as DocumentSnapshot).data() as Map<String, dynamic>?;
      if (miPerfil != null) {
        _miEdadMin = (miPerfil['match_edad_min'] as num?)?.toInt();
        _miEdadMax = (miPerfil['match_edad_max'] as num?)?.toInt();
        _miDistanciaMax =
            (miPerfil['match_distancia_max'] as num?)?.toDouble();
        _miLat = (miPerfil['latitud'] as num?)?.toDouble();
        _miLng = (miPerfil['longitud'] as num?)?.toDouble();
      }
    } catch (_) {}
    if (mounted) setState(() => _cargando = false);
  }

  Future<void> _registrarSwipe(String otroUid, String tipo) async {
    final miUid = _miUid;
    if (miUid == null) return;
    setState(() => _yaInteractuados.add(otroUid));

    try {
      final db = FirebaseFirestore.instance;
      await db
          .collection('likes')
          .doc(miUid)
          .collection('dados')
          .doc(otroUid)
          .set({
        'tipo': tipo,
        'timestamp': FieldValue.serverTimestamp(),
      });
      if (tipo == 'like' || tipo == 'super') {
        final huboMatch = await _verificarMatch(miUid, otroUid);
        if (huboMatch && mounted) await _mostrarDialogMatch(otroUid);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  Future<bool> _verificarMatch(String miUid, String otroUid) async {
    final db = FirebaseFirestore.instance;
    final reciproco = await db
        .collection('likes')
        .doc(otroUid)
        .collection('dados')
        .doc(miUid)
        .get();
    if (!reciproco.exists) return false;
    final tipo = reciproco.data()?['tipo'];
    if (tipo != 'like' && tipo != 'super') return false;

    final uids = [miUid, otroUid]..sort();
    await db.collection('matches').doc(uids.join('_')).set({
      'users': uids,
      'timestamp': FieldValue.serverTimestamp(),
      'ultimo_mensaje': null,
      'ultimo_mensaje_time': null,
    });
    return true;
  }

  Future<void> _mostrarDialogMatch(String otroUid) async {
    final perfil = await FirebaseFirestore.instance
        .collection('usuarios')
        .doc(otroUid)
        .get();
    final nombre = perfil.data()?['nombre'] ?? 'esta persona';
    if (!mounted) return;

    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'match',
      barrierColor: Colors.black54,
      transitionDuration: const Duration(milliseconds: 450),
      pageBuilder: (ctx, anim, secAnim) => const SizedBox.shrink(),
      transitionBuilder: (ctx, anim, secAnim, child) {
        final scale =
            CurvedAnimation(parent: anim, curve: Curves.elasticOut).value;
        return Transform.scale(
          scale: scale.clamp(0.0, 1.0),
          child: Opacity(
            opacity: anim.value.clamp(0.0, 1.0),
            child: AlertDialog(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24)),
              title: const Center(
                child: Text('¡Es un Match!',
                    style: TextStyle(
                        color: AppColors.likeRed,
                        fontWeight: FontWeight.bold,
                        fontSize: 22)),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0.8, end: 1.1),
                    duration: const Duration(milliseconds: 900),
                    curve: Curves.easeInOut,
                    builder: (_, v, child) =>
                        Transform.scale(scale: v, child: child),
                    child: const Icon(Icons.favorite,
                        color: AppColors.likeRed, size: 80),
                  ),
                  const SizedBox(height: 12),
                  Text('Tú y $nombre se gustaron mutuamente',
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 16)),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Seguir explorando'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  String _ciudadODistancia(Map<String, dynamic> datos) {
    final lat = (datos['latitud'] as num?)?.toDouble();
    final lng = (datos['longitud'] as num?)?.toDouble();
    if (_miLat != null && _miLng != null && lat != null && lng != null) {
      final metros = Geolocator.distanceBetween(_miLat!, _miLng!, lat, lng);
      final km = (metros / 1000).round();
      return '$km KMS';
    }
    return 'Estudiante en UTS';
  }

  bool _cumpleFiltros(Map<String, dynamic> datos) {
    final edad = (datos['edad'] as num?)?.toInt();
    if (_miEdadMin != null && edad != null && edad < _miEdadMin!) return false;
    if (_miEdadMax != null && edad != null && edad > _miEdadMax!) return false;
    if (_miDistanciaMax != null) {
      final lat = (datos['latitud'] as num?)?.toDouble();
      final lng = (datos['longitud'] as num?)?.toDouble();
      if (_miLat != null && _miLng != null && lat != null && lng != null) {
        final metros = Geolocator.distanceBetween(_miLat!, _miLng!, lat, lng);
        if ((metros / 1000) > _miDistanciaMax!) return false;
      }
    }
    return true;
  }

  Future<void> _subirHistoria() async {
    final miUid = _miUid;
    if (miUid == null || _subiendoStory) return;

    final foto =
        await _picker.pickImage(source: ImageSource.gallery, imageQuality: 70);
    if (foto == null) return;

    setState(() => _subiendoStory = true);
    try {
      final db = FirebaseFirestore.instance;

      final miPerfil = await db.collection('usuarios').doc(miUid).get();
      final data = miPerfil.data();
      final nombre = data?['nombre'] ?? 'Usuario';
      final fotos = data?['fotos'] as List<dynamic>?;
      final fotoPerfil = (fotos != null && fotos.isNotEmpty) ? fotos[0] : null;

      final storyId = DateTime.now().millisecondsSinceEpoch.toString();
      final ref = FirebaseStorage.instance
          .ref()
          .child('stories')
          .child(miUid)
          .child('$storyId.jpg');
      await ref.putFile(File(foto.path));
      final url = await ref.getDownloadURL();

      await db.collection('stories').add({
        'userId': miUid,
        'nombre': nombre,
        'fotoPerfil': fotoPerfil,
        'url': url,
        'timestamp': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Historia publicada')),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al subir historia: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _subiendoStory = false);
    }
  }

  void _verHistorias(String nombre, String? fotoPerfil, List<StoryItem> items) {
    Navigator.push(
      context,
      PageRouteBuilder(
        opaque: false,
        barrierColor: Colors.black,
        transitionDuration: const Duration(milliseconds: 250),
        pageBuilder: (ctx, anim, secAnim) => StoryViewerScreen(
          nombreAutor: nombre,
          fotoAutor: fotoPerfil,
          historias: items,
        ),
        transitionsBuilder: (ctx, anim, secAnim, child) =>
            FadeTransition(opacity: anim, child: child),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final miUid = _miUid;

    return Scaffold(
      backgroundColor: AppColors.softPink,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 1,
        leading: IconButton(
          icon: const Icon(Icons.grid_view_rounded, color: AppColors.likeRed),
          onPressed: () {},
        ),
        title: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: const BoxDecoration(
            color: AppColors.darkGreen,
            shape: BoxShape.circle,
          ),
          child: const Text('💘', style: TextStyle(fontSize: 18)),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.tune, color: AppColors.likeRed),
            onPressed: () {},
          ),
        ],
      ),
      body: _cargando
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.likeRed))
          : Column(
              children: [
                _construirStories(),
                Expanded(
                  child: StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('usuarios')
                        .snapshots(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(
                            child: CircularProgressIndicator(
                                color: AppColors.likeRed));
                      }
                      if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                        return const Center(
                            child: Text('No hay perfiles disponibles.'));
                      }
                      final perfiles = snapshot.data!.docs.where((doc) {
                        if (doc.id == miUid) return false;
                        if (_yaInteractuados.contains(doc.id)) return false;
                        if (_bloqueados.contains(doc.id)) return false;
                        final datos = doc.data() as Map<String, dynamic>;
                        if (datos['perfil_completo'] != true) return false;
                        if (!_cumpleFiltros(datos)) return false;
                        return true;
                      }).toList();
                      if (perfiles.isEmpty) return _estadoSinPerfiles();
                      return _construirSwiper(perfiles);
                    },
                  ),
                ),
              ],
            ),
    );
  }

  Widget _construirStories() {
    final hace24h = DateTime.now().subtract(const Duration(hours: 24));

    return SizedBox(
      height: 110,
      child: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('stories')
            .where('timestamp', isGreaterThan: Timestamp.fromDate(hace24h))
            .orderBy('timestamp', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          final docs = snapshot.data?.docs ?? [];
          final miUidActual = _miUid;

          // Agrupar por userId: solo mis propias historias o las de personas con quien tengo match
          final Map<String, List<QueryDocumentSnapshot>> grupos = {};
          for (final d in docs) {
            final data = d.data() as Map<String, dynamic>;
            final uid = data['userId'] as String?;
            if (uid == null) continue;
            if (_bloqueados.contains(uid)) continue;
            final esMia = uid == miUidActual;
            final esDeMatch = _miMatchesUids.contains(uid);
            if (!esMia && !esDeMatch) continue;
            grupos.putIfAbsent(uid, () => []).add(d);
          }

          final entries = grupos.entries.toList();

          return ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            itemCount: entries.length + 1,
            itemBuilder: (context, index) {
              if (index == 0) return _storyAgregar();
              final entry = entries[index - 1];
              final firstData = entry.value.first.data() as Map<String, dynamic>;
              final nombre = firstData['nombre'] ?? 'Usuario';
              final fotoPerfil = firstData['fotoPerfil'];

              final items = entry.value.map((doc) {
                final m = doc.data() as Map<String, dynamic>;
                final ts = (m['timestamp'] as Timestamp?)?.toDate() ??
                    DateTime.now();
                return StoryItem(url: m['url'] ?? '', timestamp: ts);
              }).toList()
                ..sort((a, b) => a.timestamp.compareTo(b.timestamp));

              return _StoryCircle(
                nombre: nombre,
                fotoUrl: fotoPerfil,
                onTap: () => _verHistorias(nombre, fotoPerfil, items),
              );
            },
          );
        },
      ),
    );
  }

  Widget _storyAgregar() {
    return Padding(
      padding: const EdgeInsets.only(right: 12),
      child: Column(
        children: [
          GestureDetector(
            onTap: _subiendoStory ? null : _subirHistoria,
            child: Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: AppColors.background,
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.darkGreen, width: 2),
              ),
              child: _subiendoStory
                  ? const Padding(
                      padding: EdgeInsets.all(18),
                      child: CircularProgressIndicator(
                          color: AppColors.darkGreen, strokeWidth: 2),
                    )
                  : const Icon(Icons.add,
                      color: AppColors.darkGreen, size: 30),
            ),
          ),
          const SizedBox(height: 6),
          const Text('Agregar Historia',
              style:
                  TextStyle(fontSize: 11, color: AppColors.textSecondary)),
        ],
      ),
    );
  }

  Widget _estadoSinPerfiles() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.sentiment_satisfied, size: 80, color: Colors.grey[400]),
            const SizedBox(height: 20),
            Text(
              'Ya viste todos los perfiles disponibles.\nVuelve más tarde.',
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 16, color: Colors.grey[600], height: 1.4),
            ),
          ],
        ),
      ),
    );
  }

  Widget _construirSwiper(List<QueryDocumentSnapshot> perfiles) {
    return Column(
      children: [
        Expanded(
          child: CardSwiper(
            controller: _swiperController,
            cardsCount: perfiles.length,
            numberOfCardsDisplayed: perfiles.length >= 3 ? 3 : perfiles.length,
            backCardOffset: const Offset(0, 40),
            padding: const EdgeInsets.all(16),
            allowedSwipeDirection: const AllowedSwipeDirection.only(
                left: true, right: true, up: true),
            onSwipe: (previousIndex, currentIndex, direction) {
              final doc = perfiles[previousIndex];
              if (direction == CardSwiperDirection.left) {
                _registrarSwipe(doc.id, 'dislike');
              } else if (direction == CardSwiperDirection.right) {
                _registrarSwipe(doc.id, 'like');
              } else if (direction == CardSwiperDirection.top) {
                _registrarSwipe(doc.id, 'super');
              }
              return true;
            },
            cardBuilder: (context, index, hPct, vPct) {
              final doc = perfiles[index];
              final datos = doc.data() as Map<String, dynamic>;
              return _PerfilCard(
                datos: datos,
                ubicacionTexto: _ciudadODistancia(datos),
                onMostrarInfo: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => DetallePerfilScreen(
                        uid: doc.id,
                        datosIniciales: datos,
                        miLat: _miLat,
                        miLng: _miLng,
                        onAccion: (tipo) => _registrarSwipe(doc.id, tipo),
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _botonAccion(Icons.close, AppColors.likeRed,
                  () => _swiperController.swipe(CardSwiperDirection.left)),
              _botonAccion(Icons.favorite, AppColors.likeHeart,
                  () => _swiperController.swipe(CardSwiperDirection.right)),
              _botonAccion(Icons.star, AppColors.superStar,
                  () => _swiperController.swipe(CardSwiperDirection.top)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _botonAccion(IconData icono, Color color, VoidCallback onTap) {
    return InkWell(
      borderRadius: BorderRadius.circular(40),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.background,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
                color: color.withValues(alpha: 0.25),
                blurRadius: 10,
                offset: const Offset(0, 3)),
          ],
        ),
        child: Icon(icono, color: color, size: 32),
      ),
    );
  }
}

class _StoryCircle extends StatefulWidget {
  final String nombre;
  final String? fotoUrl;
  final VoidCallback onTap;

  const _StoryCircle({
    required this.nombre,
    required this.fotoUrl,
    required this.onTap,
  });

  @override
  State<_StoryCircle> createState() => _StoryCircleState();
}

class _StoryCircleState extends State<_StoryCircle>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 12),
      child: Column(
        children: [
          GestureDetector(
            onTap: widget.onTap,
            child: AnimatedBuilder(
              animation: _ctrl,
              builder: (_, child) {
                return Container(
                  width: 64,
                  height: 64,
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: SweepGradient(
                      colors: const [
                        AppColors.likeRed,
                        AppColors.darkGreen,
                        AppColors.likeRed,
                      ],
                      transform: GradientRotation(_ctrl.value * 6.28319),
                    ),
                  ),
                  child: child,
                );
              },
              child: CircleAvatar(
                backgroundColor: AppColors.background,
                backgroundImage: widget.fotoUrl != null
                    ? NetworkImage(widget.fotoUrl!)
                    : null,
                child: widget.fotoUrl == null
                    ? const Icon(Icons.person, color: AppColors.darkGreen)
                    : null,
              ),
            ),
          ),
          const SizedBox(height: 6),
          SizedBox(
            width: 64,
            child: Text(
              widget.nombre,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontSize: 11, color: AppColors.textPrimary),
            ),
          ),
        ],
      ),
    );
  }
}

class _PerfilCard extends StatelessWidget {
  final Map<String, dynamic> datos;
  final String ubicacionTexto;
  final VoidCallback? onMostrarInfo;

  const _PerfilCard({
    required this.datos,
    required this.ubicacionTexto,
    this.onMostrarInfo,
  });

  @override
  Widget build(BuildContext context) {
    final nombre = datos['nombre'] ?? 'Usuario';
    final edad = datos['edad']?.toString() ?? '';
    final fotos = datos['fotos'] as List<dynamic>?;
    final fotoUrl = (fotos != null && fotos.isNotEmpty) ? fotos[0] : null;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(25),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 10,
              offset: const Offset(0, 4)),
        ],
        image: fotoUrl != null
            ? DecorationImage(image: NetworkImage(fotoUrl), fit: BoxFit.cover)
            : null,
      ),
      child: Stack(
        children: [
          if (fotoUrl == null)
            const Center(
                child: Icon(Icons.person, size: 120, color: Colors.grey)),
          if (onMostrarInfo != null)
            Positioned(
              top: 12,
              right: 12,
              child: Material(
                color: Colors.black.withValues(alpha: 0.45),
                shape: const CircleBorder(),
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: onMostrarInfo,
                  child: const Padding(
                    padding: EdgeInsets.all(8),
                    child: Icon(Icons.info_outline,
                        color: Colors.white, size: 24),
                  ),
                ),
              ),
            ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(25),
                  bottomRight: Radius.circular(25),
                ),
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.7),
                  ],
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Flexible(
                        child: Text(nombre,
                            style: const TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.bold,
                                color: Colors.white)),
                      ),
                      if (edad.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(left: 8, bottom: 3),
                          child: Text(edad,
                              style: const TextStyle(
                                  fontSize: 22, color: Colors.white)),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(ubicacionTexto.toUpperCase(),
                      style: const TextStyle(
                          color: Colors.white70, fontSize: 12)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
