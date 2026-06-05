import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'chat_screen.dart';

class MensajesScreen extends StatefulWidget {
  const MensajesScreen({super.key});

  @override
  State<MensajesScreen> createState() => _MensajesScreenState();
}

class _MensajesScreenState extends State<MensajesScreen> {
  final TextEditingController _busquedaController = TextEditingController();
  String _filtroNombre = '';

  @override
  void dispose() {
    _busquedaController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final miUid = FirebaseAuth.instance.currentUser?.uid;

    return Scaffold(
      backgroundColor: const Color(0xFFFFECEF),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 1,
        title: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: const BoxDecoration(
            color: Color(0xFF1E5631),
            shape: BoxShape.circle,
          ),
          child: const Text('💘', style: TextStyle(fontSize: 18)),
        ),
        centerTitle: true,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _busquedaController,
              onChanged: (v) =>
                  setState(() => _filtroNombre = v.trim().toLowerCase()),
              decoration: InputDecoration(
                hintText: 'A quien buscas?',
                prefixIcon: const Icon(Icons.search, color: Colors.grey),
                fillColor: Colors.white,
                filled: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 0),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(30),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          Expanded(
            child: miUid == null
                ? _estadoVacio()
                : StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('matches')
                        .where('users', arrayContains: miUid)
                        .snapshots(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(
                          child: CircularProgressIndicator(
                            color: Colors.redAccent,
                          ),
                        );
                      }
                      final docs = snapshot.data?.docs ?? [];
                      if (docs.isEmpty) return _estadoVacio();

                      return ListView.separated(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: docs.length,
                        separatorBuilder: (context, index) =>
                            const SizedBox(height: 8),
                        itemBuilder: (context, i) {
                          final data = docs[i].data() as Map<String, dynamic>;
                          final users = List<String>.from(data['users'] ?? []);
                          final otroUid = users.firstWhere(
                            (u) => u != miUid,
                            orElse: () => '',
                          );
                          if (otroUid.isEmpty) return const SizedBox.shrink();

                          return FutureBuilder<DocumentSnapshot>(
                            future: FirebaseFirestore.instance
                                .collection('usuarios')
                                .doc(otroUid)
                                .get(),
                            builder: (context, perfilSnap) {
                              if (!perfilSnap.hasData) {
                                return const SizedBox.shrink();
                              }
                              final perfil =
                                  perfilSnap.data!.data()
                                      as Map<String, dynamic>?;
                              if (perfil == null) {
                                return const SizedBox.shrink();
                              }

                              final nombre = perfil['nombre'] ?? 'Usuario';
                              if (_filtroNombre.isNotEmpty &&
                                  !nombre.toString().toLowerCase().contains(
                                    _filtroNombre,
                                  )) {
                                return const SizedBox.shrink();
                              }

                              final fotos = perfil['fotos'] as List<dynamic>?;
                              final fotoUrl =
                                  (fotos != null && fotos.isNotEmpty)
                                  ? fotos[0]
                                  : null;
                              final ultimoMensaje =
                                  data['ultimo_mensaje'] ??
                                  'Es un match. ¡Salúdalo!';

                              return _MensajeTile(
                                nombre: nombre,
                                ultimoMensaje: ultimoMensaje,
                                fotoUrl: fotoUrl,
                                matchId: docs[i].id,
                                otroUid: otroUid,
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => ChatScreen(
                                        matchId: docs[i].id,
                                        otroUid: otroUid,
                                        nombreOtro: nombre,
                                        fotoOtro: fotoUrl,
                                        heroTag: 'avatar_msgs_$otroUid',
                                      ),
                                    ),
                                  );
                                },
                              );
                            },
                          );
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _estadoVacio() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.chat_bubble_outline, size: 80, color: Colors.grey[400]),
          const SizedBox(height: 20),
          Text(
            'Aca apareceran tus mensajes\ncon tus match',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey[600],
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}

class _MensajeTile extends StatelessWidget {
  final String nombre;
  final String ultimoMensaje;
  final String? fotoUrl;
  final String matchId;
  final String otroUid;
  final VoidCallback onTap;

  const _MensajeTile({
    required this.nombre,
    required this.ultimoMensaje,
    required this.fotoUrl,
    required this.matchId,
    required this.otroUid,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: ListTile(
        leading: Hero(
          tag: 'avatar_msgs_$otroUid',
          child: CircleAvatar(
            radius: 26,
            backgroundColor: Colors.grey[200],
            backgroundImage: fotoUrl != null ? NetworkImage(fotoUrl!) : null,
            child: fotoUrl == null
                ? const Icon(Icons.person, color: Colors.grey)
                : null,
          ),
        ),
        title: Text(
          nombre,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(
          ultimoMensaje,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        onTap: onTap,
      ),
    );
  }
}
