import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import '../theme/app_colors.dart';

class EditarPerfilScreen extends StatefulWidget {
  const EditarPerfilScreen({super.key});

  @override
  State<EditarPerfilScreen> createState() => _EditarPerfilScreenState();
}

class _EditarPerfilScreenState extends State<EditarPerfilScreen> {
  final _nombreController = TextEditingController();
  final _edadController = TextEditingController();
  final _telefonoController = TextEditingController();
  String? _generoSeleccionado;
  String? _fotoActualUrl;
  File? _fotoNueva;
  bool _cargando = true;
  bool _guardando = false;

  final List<String> _generos = const ['Hombre', 'Mujer'];

  @override
  void initState() {
    super.initState();
    _cargarPerfil();
  }

  @override
  void dispose() {
    _nombreController.dispose();
    _edadController.dispose();
    _telefonoController.dispose();
    super.dispose();
  }

  Future<void> _cargarPerfil() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      setState(() => _cargando = false);
      return;
    }
    try {
      final doc = await FirebaseFirestore.instance
          .collection('usuarios')
          .doc(uid)
          .get();
      final data = doc.data();
      if (data != null) {
        _nombreController.text = data['nombre'] ?? '';
        _edadController.text = data['edad']?.toString() ?? '';
        _telefonoController.text = data['telefono'] ?? '';
        _generoSeleccionado = data['genero'];
        final fotos = data['fotos'] as List<dynamic>?;
        if (fotos != null && fotos.isNotEmpty) {
          _fotoActualUrl = fotos[0];
        }
      }
    } catch (_) {}
    if (mounted) setState(() => _cargando = false);
  }

  Future<void> _seleccionarFoto() async {
    final picker = ImagePicker();
    final foto = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 70,
    );
    if (foto != null) {
      setState(() => _fotoNueva = File(foto.path));
    }
  }

  Future<void> _guardar() async {
    final nombre = _nombreController.text.trim();
    final edadTxt = _edadController.text.trim();
    final telefono = _telefonoController.text.trim();

    if (nombre.isEmpty || edadTxt.isEmpty || telefono.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Por favor completa todos los campos')),
      );
      return;
    }
    final edad = int.tryParse(edadTxt);
    if (edad == null || edad < 18) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Edad inválida (debes ser mayor de 18)')),
      );
      return;
    }
    if (_generoSeleccionado == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Selecciona tu género')));
      return;
    }

    setState(() => _guardando = true);
    try {
      final uid = FirebaseAuth.instance.currentUser!.uid;
      final db = FirebaseFirestore.instance;
      final actualizaciones = <String, dynamic>{
        'nombre': nombre,
        'edad': edad,
        'telefono': telefono,
        'genero': _generoSeleccionado,
      };

      if (_fotoNueva != null) {
        final ref = FirebaseStorage.instance
            .ref()
            .child('usuarios')
            .child(uid)
            .child('foto_0.jpg');
        await ref.putFile(_fotoNueva!);
        final url = await ref.getDownloadURL();

        final doc = await db.collection('usuarios').doc(uid).get();
        final fotos = List<dynamic>.from(
          (doc.data()?['fotos'] as List<dynamic>?) ?? [],
        );
        if (fotos.isEmpty) {
          fotos.add(url);
        } else {
          fotos[0] = url;
        }
        actualizaciones['fotos'] = fotos;
      }

      await db.collection('usuarios').doc(uid).update(actualizaciones);

      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Perfil actualizado')));
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error al guardar: $e')));
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.softPink,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        title: const Text(
          'Editar Perfil',
          style: TextStyle(
            color: AppColors.darkGreen,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),
      body: _cargando
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.likeRed),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  GestureDetector(
                    onTap: _seleccionarFoto,
                    child: Stack(
                      children: [
                        CircleAvatar(
                          radius: 60,
                          backgroundColor: Colors.white,
                          backgroundImage: _fotoNueva != null
                              ? FileImage(_fotoNueva!)
                              : (_fotoActualUrl != null
                                        ? NetworkImage(_fotoActualUrl!)
                                        : null)
                                    as ImageProvider?,
                          child: (_fotoNueva == null && _fotoActualUrl == null)
                              ? const Icon(
                                  Icons.person,
                                  size: 60,
                                  color: AppColors.darkGreen,
                                )
                              : null,
                        ),
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: const BoxDecoration(
                              color: AppColors.darkGreen,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.camera_alt,
                              color: Colors.white,
                              size: 18,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Cambiar foto de perfil',
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 24),
                  _campo('Nombres', _nombreController),
                  _campo(
                    'Edad',
                    _edadController,
                    teclado: TextInputType.number,
                  ),
                  _campo(
                    'Número de tel',
                    _telefonoController,
                    teclado: TextInputType.phone,
                  ),
                  _selectorGenero(),
                  const SizedBox(height: 28),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            backgroundColor: AppColors.likeRed,
                            side: BorderSide.none,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                          onPressed: _guardando
                              ? null
                              : () => Navigator.pop(context),
                          child: const Text(
                            'Cancelar',
                            style: TextStyle(color: Colors.white),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: _guardando ? null : _guardar,
                          child: _guardando
                              ? const SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Text('Confirmar'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
    );
  }

  Widget _campo(
    String label,
    TextEditingController c, {
    TextInputType? teclado,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: AppColors.darkGreen,
            ),
          ),
          const SizedBox(height: 6),
          TextField(
            controller: c,
            keyboardType: teclado,
            decoration: const InputDecoration(),
          ),
        ],
      ),
    );
  }

  Widget _selectorGenero() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Género',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: AppColors.darkGreen,
          ),
        ),
        const SizedBox(height: 6),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.divider),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _generoSeleccionado,
              isExpanded: true,
              hint: const Text('Selecciona'),
              items: _generos
                  .map((g) => DropdownMenuItem(value: g, child: Text(g)))
                  .toList(),
              onChanged: (v) => setState(() => _generoSeleccionado = v),
            ),
          ),
        ),
      ],
    );
  }
}
