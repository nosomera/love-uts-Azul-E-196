import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final uidUsuarioActual = FirebaseAuth.instance.currentUser?.uid;

    return Scaffold(
      backgroundColor: const Color(0xFFFFECEF),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 1,
        leading: IconButton(
          icon: const Icon(Icons.grid_view_rounded, color: Colors.redAccent),
          onPressed: () {},
        ),
        title: Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: const BoxDecoration(
              color: Color(0xFF1E5631), // Color representativo UTS
              shape: BoxShape.circle,
            ),
            child: const Text('💘', style: TextStyle(fontSize: 18)),
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.tune, color: Colors.redAccent),
            onPressed: () {},
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        // Escucha cambios en tiempo real en la colección 'usuarios'
        stream: FirebaseFirestore.instance.collection('usuarios').snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: Colors.redAccent));
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text('No hay perfiles disponibles por el momento.'));
          }

          // Filtrar para que no aparezca tu propio perfil en el feed
          final perfiles = snapshot.data!.docs.where((doc) => doc.id != uidUsuarioActual).toList();

          if (perfiles.isEmpty) {
            return const Center(child: Text('¡Vaya! No hay otros usuarios registrados aún.'));
          }

          // Genera un scroll vertical con las tarjetas de prospectos
          return ListView.builder(
            padding: const EdgeInsets.all(20),
            itemCount: perfiles.length,
            itemBuilder: (context, index) {
              final datos = perfiles[index].data() as Map<String, dynamic>;
              
              // Recuperar campos protegiendo la app de valores nulos o vacíos
              final nombre = datos['nombre'] ?? 'Usuario';
              final edad = datos['edad']?.toString() ?? '';
              final List<dynamic> fotos = datos['fotos'] ?? [];
              final List<dynamic> intereses = datos['intereses'] ?? [];

              return Card(
                margin: const EdgeInsets.only(bottom: 25),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
                elevation: 4,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    
                    // 1. Carrusel Cuadrado Interno de Fotos del Candidato (Deslizable horizontalmente)
                    if (fotos.isNotEmpty)
                      SizedBox(
                        height: 320, // Altura cuadrada cómoda para el feed
                        child: ClipRRect(
                          borderRadius: const BorderRadius.only(
                            topLeft: Radius.circular(25),
                            topRight: Radius.circular(25),
                          ),
                          child: PageView.builder(
                            itemCount: fotos.length,
                            itemBuilder: (context, fotoIndex) {
                              return Image.network(
                                fotos[fotoIndex],
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) {
                                  return const Center(child: Icon(Icons.broken_image, size: 50));
                                },
                              );
                            },
                          ),
                        ),
                      )
                    else
                      Container(
                        height: 250,
                        decoration: const BoxDecoration(
                          color: Colors.grey,
                          borderRadius: BorderRadius.only(topLeft: Radius.circular(25), topRight: Radius.circular(25)),
                        ),
                        child: const Center(child: Icon(Icons.person, size: 80, color: Colors.white)),
                      ),

                    // 2. Información del Perfil (Nombre, Edad)
                    Padding(
                      padding: const EdgeInsets.all(18),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                '$nombre, ',
                                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                              ),
                              Text(
                                edad,
                                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w400),
                              ),
                            ],
                          ),
                          const SizedBox(height: 5),
                          const Text(
                            'Estudiante en UTS',
                            style: TextStyle(color: Colors.grey, fontSize: 14),
                          ),
                          const SizedBox(height: 15),

                          // 3. Etiquetas de Gustos / Intereses del Candidato
                          if (intereses.isNotEmpty)
                            Wrap(
                              spacing: 8,
                              runSpacing: 4,
                              children: intereses.map((interes) {
                                return Chip(
                                  backgroundColor: const Color(0xFFFFECEF),
                                  side: BorderSide.none,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                                  label: Text(
                                    interes.toString(),
                                    style: const TextStyle(color: Colors.redAccent, fontSize: 12, fontWeight: FontWeight.bold),
                                  ),
                                );
                              }).toList(),
                            ),
                          
                          const SizedBox(height: 15),
                          
                          // Botones de acción ilustrativos del Mockup (Sin lógica por ahora)
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              _construirBotonAccion(Icons.close, Colors.redAccent),
                              _construirBotonAccion(Icons.favorite, Colors.pink),
                              _construirBotonAccion(Icons.star, Colors.amber),
                            ],
                          )
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _construirBotonAccion(IconData icono, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(color: color.withOpacity(0.2), blurRadius: 8, offset: const Offset(0, 3)),
        ],
      ),
      child: Icon(icono, color: color, size: 28),
    );
  }
}