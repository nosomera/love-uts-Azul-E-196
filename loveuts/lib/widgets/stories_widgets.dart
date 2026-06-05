import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../services/stories_service.dart';
import '../theme/app_colors.dart';
import 'skeleton.dart';

class StoriesCarousel extends StatelessWidget {
  final List<String> uidsVisibles;
  final ValueChanged<GrupoHistorias> onAbrirHistorias;

  const StoriesCarousel({
    super.key,
    required this.uidsVisibles,
    required this.onAbrirHistorias,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<GrupoHistorias>>(
      stream: StoriesService.instance.streamHistoriasDe(uidsVisibles),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _HistoriasErrorBanner(error: snapshot.error.toString());
        }
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const StoriesSkeleton();
        }
        final grupos = snapshot.data ?? const <GrupoHistorias>[];
        return SizedBox(
          height: 110,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            itemCount: grupos.length + 1,
            separatorBuilder: (_, _) => const SizedBox(width: 12),
            itemBuilder: (context, i) {
              if (i == 0) return const _AgregarHistoriaButton();
              final grupo = grupos[i - 1];
              return _StoryRing(
                grupo: grupo,
                onTap: () => onAbrirHistorias(grupo),
              );
            },
          ),
        );
      },
    );
  }
}

class _HistoriasErrorBanner extends StatelessWidget {
  final String error;
  const _HistoriasErrorBanner({required this.error});

  @override
  Widget build(BuildContext context) {
    final esIndex = error.toLowerCase().contains('index');
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      margin: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.orange.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.orange.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.warning_amber, color: Colors.orange.shade700, size: 20),
              const SizedBox(width: 8),
              Text(
                esIndex
                    ? 'Falta un índice de Firestore para historias'
                    : 'No pude cargar las historias',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.orange.shade900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            esIndex
                ? 'Abrí el link de la consola de Firebase para crearlo automáticamente.'
                : error,
            style: TextStyle(fontSize: 12, color: Colors.orange.shade800),
          ),
        ],
      ),
    );
  }
}

class _StoryRing extends StatelessWidget {
  final GrupoHistorias grupo;
  final VoidCallback onTap;

  const _StoryRing({required this.grupo, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final miUid = FirebaseAuth.instance.currentUser?.uid ?? '';
    final visto = grupo.todasVistas(miUid);

    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance
          .collection('usuarios')
          .doc(grupo.uid)
          .get(),
      builder: (context, snap) {
        final data = snap.data?.data() as Map<String, dynamic>?;
        final nombre = (data?['nombre'] ?? 'Tú').toString();
        final fotos = data?['fotos'] as List<dynamic>?;
        final fotoUrl = (fotos != null && fotos.isNotEmpty) ? fotos[0] : null;

        return InkWell(
          borderRadius: BorderRadius.circular(40),
          onTap: onTap,
          child: SizedBox(
            width: 70,
            child: Column(
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  width: 64,
                  height: 64,
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: visto
                        ? null
                        : const LinearGradient(
                            colors: [AppColors.likeRed, AppColors.darkGreen],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                    color: visto ? Colors.grey[300] : null,
                  ),
                  child: Container(
                    decoration: const BoxDecoration(
                      color: AppColors.background,
                      shape: BoxShape.circle,
                    ),
                    padding: const EdgeInsets.all(2),
                    child: CircleAvatar(
                      backgroundColor: Colors.grey[200],
                      backgroundImage:
                          fotoUrl != null ? NetworkImage(fotoUrl) : null,
                      child: fotoUrl == null
                          ? const Icon(Icons.person,
                              color: Colors.grey, size: 28)
                          : null,
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  nombre,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _AgregarHistoriaButton extends StatefulWidget {
  const _AgregarHistoriaButton();

  @override
  State<_AgregarHistoriaButton> createState() => _AgregarHistoriaButtonState();
}

class _AgregarHistoriaButtonState extends State<_AgregarHistoriaButton> {
  bool _subiendo = false;

  Future<void> _subir() async {
    if (_subiendo) return;
    final picker = ImagePicker();
    final pick = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
      maxWidth: 1080,
    );
    if (pick == null) return;

    setState(() => _subiendo = true);
    try {
      await StoriesService.instance.subirHistoria(File(pick.path));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Historia publicada')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al subir: $e')),
      );
    } finally {
      if (mounted) setState(() => _subiendo = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(40),
      onTap: _subir,
      child: SizedBox(
        width: 70,
        child: Column(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: AppColors.background,
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.darkGreen, width: 2),
              ),
              child: _subiendo
                  ? const Padding(
                      padding: EdgeInsets.all(18),
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: AppColors.darkGreen,
                      ),
                    )
                  : const Icon(
                      Icons.add,
                      color: AppColors.darkGreen,
                      size: 30,
                    ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Tu Historia',
              style: TextStyle(
                fontSize: 11,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
