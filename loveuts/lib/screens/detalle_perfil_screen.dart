import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import '../theme/app_colors.dart';

class DetallePerfilScreen extends StatelessWidget {
  final String uid;
  final Map<String, dynamic> datosIniciales;
  final double? miLat;
  final double? miLng;
  final Future<void> Function(String tipo)? onAccion;

  const DetallePerfilScreen({
    super.key,
    required this.uid,
    required this.datosIniciales,
    this.miLat,
    this.miLng,
    this.onAccion,
  });

  String _calcularDistancia(Map<String, dynamic> data) {
    final lat = (data['latitud'] as num?)?.toDouble();
    final lng = (data['longitud'] as num?)?.toDouble();
    if (miLat != null && miLng != null && lat != null && lng != null) {
      final metros = Geolocator.distanceBetween(miLat!, miLng!, lat, lng);
      final km = (metros / 1000).round();
      return '$km KMS';
    }
    return 'Estudiante en UTS';
  }

  Future<void> _ejecutarAccion(BuildContext context, String tipo) async {
    if (onAccion != null) {
      await onAccion!(tipo);
    }
    if (context.mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.softPink,
      body: FutureBuilder<DocumentSnapshot>(
        future: FirebaseFirestore.instance.collection('usuarios').doc(uid).get(),
        builder: (context, snapshot) {
          final data = snapshot.hasData
              ? (snapshot.data!.data() as Map<String, dynamic>? ?? datosIniciales)
              : datosIniciales;

          final nombre = data['nombre'] ?? 'Usuario';
          final edad = data['edad']?.toString() ?? '';
          final genero = data['genero'] ?? '';
          final queBusca = data['que_busca'] ?? '';
          final orientacion = data['orientacion'] ?? '';
          final intereses = (data['intereses'] as List<dynamic>?) ?? [];
          final fotos = (data['fotos'] as List<dynamic>?) ?? [];
          final ubicacion = _calcularDistancia(data);

          return CustomScrollView(
            slivers: [
              SliverAppBar(
                expandedHeight: 420,
                pinned: true,
                backgroundColor: AppColors.softPink,
                iconTheme: const IconThemeData(color: Colors.white),
                flexibleSpace: FlexibleSpaceBar(
                  background: _GaleriaFotos(fotos: fotos),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Flexible(
                            child: Text(
                              nombre,
                              style: const TextStyle(
                                  fontSize: 28, fontWeight: FontWeight.bold),
                            ),
                          ),
                          if (edad.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(left: 8, bottom: 3),
                              child: Text(edad,
                                  style: const TextStyle(
                                      fontSize: 22,
                                      color: AppColors.textSecondary)),
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(Icons.location_on,
                              color: AppColors.likeRed, size: 16),
                          const SizedBox(width: 4),
                          Text(
                            ubicacion,
                            style: const TextStyle(
                                fontSize: 14, color: AppColors.textSecondary),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      if (queBusca.toString().isNotEmpty)
                        _seccion('Está buscando',
                            Icons.favorite_border, queBusca.toString()),
                      if (genero.toString().isNotEmpty)
                        _seccion('Género', Icons.person, genero.toString()),
                      if (orientacion.toString().isNotEmpty)
                        _seccion('Orientación',
                            Icons.diversity_3, orientacion.toString()),
                      if (intereses.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        const Text(
                          'Intereses',
                          style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: AppColors.darkGreen),
                        ),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: intereses
                              .map((i) => Chip(
                                    backgroundColor: AppColors.softPink,
                                    side: BorderSide.none,
                                    shape: RoundedRectangleBorder(
                                        borderRadius:
                                            BorderRadius.circular(20)),
                                    label: Text(
                                      i.toString(),
                                      style: const TextStyle(
                                          color: AppColors.likeRed,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 13),
                                    ),
                                  ))
                              .toList(),
                        ),
                      ],
                      const SizedBox(height: 30),
                      if (onAccion != null)
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            _botonAccion(Icons.close, AppColors.likeRed,
                                () => _ejecutarAccion(context, 'dislike')),
                            _botonAccion(Icons.favorite, AppColors.likeHeart,
                                () => _ejecutarAccion(context, 'like')),
                            _botonAccion(Icons.star, AppColors.superStar,
                                () => _ejecutarAccion(context, 'super')),
                          ],
                        ),
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _seccion(String label, IconData icono, String valor) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        children: [
          Icon(icono, color: AppColors.darkGreen, size: 20),
          const SizedBox(width: 10),
          Text('$label: ',
              style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: AppColors.darkGreen,
                  fontSize: 15)),
          Expanded(
            child: Text(valor,
                style: const TextStyle(
                    fontSize: 15, color: AppColors.textPrimary)),
          ),
        ],
      ),
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

class _GaleriaFotos extends StatefulWidget {
  final List<dynamic> fotos;
  const _GaleriaFotos({required this.fotos});

  @override
  State<_GaleriaFotos> createState() => _GaleriaFotosState();
}

class _GaleriaFotosState extends State<_GaleriaFotos> {
  int _indice = 0;
  final PageController _ctrl = PageController();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.fotos.isEmpty) {
      return Container(
        color: Colors.grey[300],
        child: const Center(
            child: Icon(Icons.person, size: 100, color: Colors.white)),
      );
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        PageView.builder(
          controller: _ctrl,
          itemCount: widget.fotos.length,
          onPageChanged: (i) => setState(() => _indice = i),
          itemBuilder: (context, i) => Image.network(
            widget.fotos[i].toString(),
            fit: BoxFit.cover,
            errorBuilder: (context, error, stack) => Container(
              color: Colors.grey[300],
              child: const Icon(Icons.broken_image, size: 60),
            ),
          ),
        ),
        Positioned(
          top: 60,
          left: 16,
          right: 16,
          child: Row(
            children: List.generate(widget.fotos.length, (i) {
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  child: Container(
                    height: 3,
                    decoration: BoxDecoration(
                      color: i == _indice ? Colors.white : Colors.white38,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
              );
            }),
          ),
        ),
      ],
    );
  }
}
