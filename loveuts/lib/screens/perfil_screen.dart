import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'editar_perfil_screen.dart';
import 'cambiar_contrasena_screen.dart';

class PerfilScreen extends StatefulWidget {
  const PerfilScreen({super.key});

  @override
  State<PerfilScreen> createState() => _PerfilScreenState();
}

class _PerfilScreenState extends State<PerfilScreen> {
  Key _futureKey = UniqueKey();

  void _refrescar() => setState(() => _futureKey = UniqueKey());

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      backgroundColor: const Color(0xFFFFECEF),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 1,
        title: const Text(
          'Perfil',
          style: TextStyle(
            color: Color(0xFF1E5631),
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),
      body: user == null
          ? const Center(child: Text('No hay sesión activa'))
          : FutureBuilder<DocumentSnapshot>(
              key: _futureKey,
              future: FirebaseFirestore.instance
                  .collection('usuarios')
                  .doc(user.uid)
                  .get(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(color: Colors.redAccent),
                  );
                }
                final data = snapshot.data?.data() as Map<String, dynamic>?;
                final nombre = data?['nombre'] ?? 'Usuario';
                final fotos = data?['fotos'] as List<dynamic>?;
                final fotoUrl = (fotos != null && fotos.isNotEmpty)
                    ? fotos[0]
                    : null;

                return SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 30,
                  ),
                  child: Column(
                    children: [
                      CircleAvatar(
                        radius: 65,
                        backgroundColor: Colors.white,
                        backgroundImage: fotoUrl != null
                            ? NetworkImage(fotoUrl)
                            : null,
                        child: fotoUrl == null
                            ? const Icon(
                                Icons.person,
                                size: 70,
                                color: Color(0xFF1E5631),
                              )
                            : null,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        nombre,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 30),
                      _opcion(
                        context,
                        icono: Icons.person_outline,
                        titulo: 'Editar Perfil',
                        onTap: () async {
                          await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const EditarPerfilScreen(),
                            ),
                          );
                          _refrescar();
                        },
                      ),
                      _opcion(
                        context,
                        icono: Icons.lock_outline,
                        titulo: 'Cambiar Contraseña',
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const CambiarContrasenaScreen(),
                          ),
                        ),
                      ),
                      _opcion(
                        context,
                        icono: Icons.settings_outlined,
                        titulo: 'Preferencias',
                        subtitulo: 'Público/Privado',
                        trailing: const Icon(
                          Icons.check_box,
                          color: Color(0xFF1E5631),
                        ),
                        onTap: () => _proximamente(context, 'Preferencias'),
                      ),
                      _opcion(
                        context,
                        icono: Icons.logout,
                        titulo: 'Cerrar Sesión',
                        color: Colors.redAccent,
                        onTap: () => _cerrarSesion(context),
                      ),
                    ],
                  ),
                );
              },
            ),
    );
  }

  Widget _opcion(
    BuildContext context, {
    required IconData icono,
    required String titulo,
    String? subtitulo,
    Widget? trailing,
    Color color = Colors.black87,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
      ),
      child: ListTile(
        leading: Icon(icono, color: color),
        title: Text(
          titulo,
          style: TextStyle(color: color, fontWeight: FontWeight.w600),
        ),
        subtitle: subtitulo != null ? Text(subtitulo) : null,
        trailing: trailing ?? const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }

  void _proximamente(BuildContext context, String nombre) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('$nombre - próximamente')));
  }

  Future<void> _cerrarSesion(BuildContext context) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cerrar Sesión'),
        content: const Text('¿Seguro que quieres cerrar sesión?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Salir', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmar == true) {
      await FirebaseAuth.instance.signOut();
      if (context.mounted) {
        Navigator.of(context, rootNavigator: true)
            .pushNamedAndRemoveUntil('/login', (_) => false);
      }
    }
  }
}
