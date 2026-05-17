import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';

class CrearPerfilPasosScreen extends StatefulWidget {
  const CrearPerfilPasosScreen({super.key});

  @override
  State<CrearPerfilPasosScreen> createState() => _CrearPerfilPasosScreenState();
}

class _CrearPerfilPasosScreenState extends State<CrearPerfilPasosScreen> {
  final PageController _pageController = PageController();
  int _paginaActual = 0;
  final int _totalPaginas = 9; // 8 pasos de datos + 1 paso final de fotos = 9

  // Controladores del carrusel de imágenes (Cambiado a 3 como definiste en tu lista)
  final List<File?> _imagenesSeleccionadas = [null, null, null];
  final ImagePicker _picker = ImagePicker();
  int _fotoActualCarrusel = 0; // Controla el puntito indicador del carrusel

  // Controladores de Cajas de Texto
  final TextEditingController _telefonoController = TextEditingController();
  final TextEditingController _nombreController = TextEditingController();
  final TextEditingController _edadController = TextEditingController();

  // Variables de Selección Única
  String? _generoSeleccionado;
  String? _busquedaSeleccionada;
  String? _orientacionSeleccionada;

  // Datos para la fórmula del Match
  final List<String> _interesesSeleccionados = [];
  RangeValues _rangoEdadPreferido = const RangeValues(18, 25);
  double _distanciaMaxima = 10.0; // En kilómetros

  bool _isLoading = false;

  // Listas de opciones estáticas
  final List<String> _generos = ['Hombre', 'Mujer'];
  final List<String> _opcionesBusqueda = [
    'Una relación',
    'Algo Casual',
    'No estoy segura o seguro',
    'Amistad',
    'Prefiero No decirlo',
  ];
  final List<String> _opcionesOrientacion = [
    'Heterosexual',
    'Homosexual',
    'Bisexual',
    'Otro',
  ];

  final List<String> _listaIntereses = [
    'Lectura',
    'Películas',
    'Videojuegos',
    'Tecnología',
    'Viajar',
    'Música',
    'Pintura',
    'Moda',
    'Anime',
    'Gym',
    'Estudiar',
    'Deporte',
    'Mascotas',
    'Cocina',
    'Baile',
    'Fotografía',
  ];

  @override
  void dispose() {
    _pageController.dispose();
    _telefonoController.dispose();
    _nombreController.dispose();
    _edadController.dispose();
    super.dispose();
  }

  void _siguientePaso() {
    if (_validarPasoActual()) {
      FocusScope.of(context).unfocus();
      if (_paginaActual < _totalPaginas - 1) {
        _pageController.nextPage(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
      } else {
        _finalizarPerfil();
      }
    }
  }

  bool _validarPasoActual() {
    String mensaje = '';
    if (_paginaActual == 0 && _telefonoController.text.trim().isEmpty)
      mensaje = 'Por favor ingresa tu teléfono';
    if (_paginaActual == 1 && _nombreController.text.trim().isEmpty)
      mensaje = 'Por favor dinos tu nombre';
    if (_paginaActual == 2) {
      final edad = int.tryParse(_edadController.text.trim());
      if (edad == null || edad < 18)
        mensaje = 'Debes ingresar una edad válida (Mayor de 18)';
    }
    if (_paginaActual == 3 && _generoSeleccionado == null)
      mensaje = 'Selecciona tu género';
    if (_paginaActual == 4 && _busquedaSeleccionada == null)
      mensaje = 'Cuéntanos qué buscas';
    if (_paginaActual == 5 && _orientacionSeleccionada == null)
      mensaje = 'Selecciona tu orientación';

    if (_paginaActual == 6 && _interesesSeleccionados.length < 3) {
      mensaje =
          'Por favor selecciona al menos 3 intereses (${_interesesSeleccionados.length}/3)';
    }

    // Se corrigió el índice: el paso de las fotos es el último (índice 8)
    if (_paginaActual == 8) {
      int fotosSubidas = _imagenesSeleccionadas
          .where((foto) => foto != null)
          .length;
      if (fotosSubidas < 3) {
        mensaje =
            'Por favor selecciona las 3 fotos obligatorias para tu perfil';
      }
    }

    if (mensaje.isNotEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(mensaje)));
      return false;
    }
    return true;
  }

  Future<void> _finalizarPerfil() async {
    setState(() => _isLoading = true);
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        List<String> urlsDeFotos = [];

        // 1. Subir las imágenes del carrusel a Firebase Storage de manera ordenada
        for (int i = 0; i < _imagenesSeleccionadas.length; i++) {
          if (_imagenesSeleccionadas[i] != null) {
            Reference ref = FirebaseStorage.instance
                .ref()
                .child('usuarios')
                .child(user.uid)
                .child('foto_$i.jpg');

            UploadTask uploadTask = ref.putFile(_imagenesSeleccionadas[i]!);
            TaskSnapshot snapshot = await uploadTask;

            String urlDescarga = await snapshot.ref.getDownloadURL();
            urlsDeFotos.add(urlDescarga);
          }
        }

        // 2. Guardamos todo el paquete consolidado en Firestore junto a las URLs del Storage
        await FirebaseFirestore.instance
            .collection('usuarios')
            .doc(user.uid)
            .set({
              'telefono': _telefonoController.text.trim(),
              'nombre': _nombreController.text.trim(),
              'edad': int.parse(_edadController.text.trim()),
              'genero': _generoSeleccionado,
              'que_busca': _busquedaSeleccionada,
              'orientacion': _orientacionSeleccionada,
              'intereses': _interesesSeleccionados,
              'match_edad_min': _rangoEdadPreferido.start.round(),
              'match_edad_max': _rangoEdadPreferido.end.round(),
              'match_distancia_max': _distanciaMaxima.round(),
              'fotos': urlsDeFotos, // Guardado exitoso del array de fotos
              'perfil_completo': true,
              'fecha_creacion': FieldValue.serverTimestamp(),
            });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('¡Tu perfil de Love UTS está completo!'),
          ),
        );
        Navigator.pushReplacementNamed(context, '/solicitar_ubicacion');
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error al guardar datos: $e')));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _seleccionarFoto(int indice) async {
    final XFile? imagenSoportada = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 70,
    );

    if (imagenSoportada != null) {
      setState(() {
        _imagenesSeleccionadas[indice] = File(imagenSoportada.path);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    double progreso = (_paginaActual + 1) / _totalPaginas;

    return Scaffold(
      backgroundColor: const Color(0xFFFFECEF),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: _paginaActual > 0
            ? IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.black),
                onPressed: () {
                  FocusScope.of(context).unfocus();
                  _pageController.previousPage(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeInOut,
                  );
                },
              )
            : null,
        title: LinearProgressIndicator(
          value: progreso,
          backgroundColor: Colors.grey[300],
          color: Colors.redAccent,
          minHeight: 6,
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.green))
          : Padding(
              padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 20),
              child: Column(
                children: [
                  Expanded(
                    child: PageView(
                      controller: _pageController,
                      physics: const NeverScrollableScrollPhysics(),
                      onPageChanged: (index) =>
                          setState(() => _paginaActual = index),
                      children: [
                        _construirPasoTexto(
                          'Mi número es',
                          'Necesitaremos tu número de teléfono para contactarte.',
                          _telefonoController,
                          'Número de teléfono',
                          TextInputType.phone,
                        ),
                        _construirPasoTexto(
                          '¿Cómo te llamas?',
                          'Conozcámonos un poco.',
                          _nombreController,
                          'Nombre o apodo',
                          TextInputType.text,
                        ),
                        _construirPasoTexto(
                          '¿Qué edad tienes?',
                          'Debes ser mayor de edad para usar Love UTS.',
                          _edadController,
                          'Tu edad',
                          TextInputType.number,
                        ),
                        _construirPasoSeleccion(
                          'Mi género es',
                          'Selecciona la opción con la que te identificas.',
                          _generos,
                          _generoSeleccionado,
                          (val) => setState(() => _generoSeleccionado = val),
                        ),
                        _construirPasoSeleccion(
                          'Estoy buscando...',
                          'Esto nos ayudará a filtrar tus posibles matches.',
                          _opcionesBusqueda,
                          _busquedaSeleccionada,
                          (val) => setState(() => _busquedaSeleccionada = val),
                        ),
                        _construirPasoSeleccion(
                          'Mi orientación es',
                          'Dinos cuál es tu orientación sexual.',
                          _opcionesOrientacion,
                          _orientacionSeleccionada,
                          (val) =>
                              setState(() => _orientacionSeleccionada = val),
                        ),
                        _construirPasoIntereses(),
                        _construirPasoFiltrosMatch(),
                        _construirPasoCarruselFotos(), // <-- El nuevo carrusel interactivo
                      ],
                    ),
                  ),

                  SizedBox(
                    width: double.infinity,
                    height: 55,
                    child: ElevatedButton(
                      onPressed: _siguientePaso,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green[700],
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(25),
                        ),
                      ),
                      child: Text(
                        _paginaActual == _totalPaginas - 1
                            ? 'Finalizar Perfil'
                            : 'Continuar',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
    );
  }

  // --- VISTAS AUXILIARES EXISTENTES ---
  Widget _construirPasoTexto(
    String titulo,
    String subtitulo,
    TextEditingController controller,
    String hint,
    TextInputType tipoTeclado,
  ) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          titulo,
          style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 10),
        Text(
          subtitulo,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 14, color: Colors.grey),
        ),
        const SizedBox(height: 35),
        TextField(
          controller: controller,
          keyboardType: tipoTeclado,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 18),
          decoration: InputDecoration(
            hintText: hint,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)),
            fillColor: Colors.white,
            filled: true,
          ),
        ),
      ],
    );
  }

  Widget _construirPasoSeleccion(
    String titulo,
    String subtitulo,
    List<String> opciones,
    String? seleccionado,
    Function(String) alCambiar,
  ) {
    return SingleChildScrollView(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
        Text(
          titulo,
          style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 10),
        Text(
          subtitulo,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 14, color: Colors.grey),
        ),
        const SizedBox(height: 25),
        Column(
          children: opciones.map((opcion) {
            final esSeleccionado = seleccionado == opcion;
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: SizedBox(
                width: double.infinity,
                height: 48,
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    backgroundColor: esSeleccionado
                        ? Colors.redAccent[100]
                        : Colors.white,
                    side: BorderSide(
                      color: esSeleccionado
                          ? Colors.redAccent
                          : Colors.grey[400]!,
                      width: 2,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15),
                    ),
                  ),
                  onPressed: () => alCambiar(opcion),
                  child: Text(
                    opcion,
                    style: const TextStyle(fontSize: 15, color: Colors.black),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
        ],
      ),
    );
  }

  Widget _construirPasoIntereses() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Text(
          'Tus intereses',
          style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 10),
        Text(
          'Selecciona al menos 3 opciones (${_interesesSeleccionados.length} elegidas)',
          style: const TextStyle(fontSize: 14, color: Colors.grey),
        ),
        const SizedBox(height: 25),
        SingleChildScrollView(
          child: Wrap(
            spacing: 10.0,
            runSpacing: 10.0,
            alignment: WrapAlignment.center,
            children: _listaIntereses.map((interes) {
              final estaSeleccionado = _interesesSeleccionados.contains(
                interes,
              );
              return FilterChip(
                label: Text(interes),
                selected: estaSeleccionado,
                selectedColor: Colors.redAccent[100],
                checkmarkColor: Colors.redAccent,
                backgroundColor: Colors.white,
                labelStyle: TextStyle(
                  color: estaSeleccionado
                      ? Colors.redAccent[900]
                      : Colors.black87,
                  fontWeight: estaSeleccionado
                      ? FontWeight.bold
                      : FontWeight.normal,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                onSelected: (bool seleccionado) {
                  setState(() {
                    if (seleccionado) {
                      _interesesSeleccionados.add(interes);
                    } else {
                      _interesesSeleccionados.remove(interes);
                    }
                  });
                },
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _construirPasoFiltrosMatch() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Center(
          child: Text(
            'Preferencias de Match',
            style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
          ),
        ),
        const Center(
          child: Text(
            'Configura tus filtros ideales para conectar.',
            style: TextStyle(fontSize: 14, color: Colors.grey),
          ),
        ),
        const SizedBox(height: 40),
        Text(
          'Rango de edad cómodo: ${_rangoEdadPreferido.start.round()} - ${_rangoEdadPreferido.end.round()} años',
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 10),
        Card(
          color: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
          child: RangeSlider(
            values: _rangoEdadPreferido,
            min: 18,
            max: 50,
            divisions: 32,
            activeColor: Colors.redAccent,
            inactiveColor: Colors.grey[300],
            labels: RangeLabels(
              _rangoEdadPreferido.start.round().toString(),
              _rangoEdadPreferido.end.round().toString(),
            ),
            onChanged: (RangeValues valores) {
              setState(() => _rangoEdadPreferido = valores);
            },
          ),
        ),
        const SizedBox(height: 30),
        Text(
          'Distancia máxima: ${_distanciaMaxima.round()} km',
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 10),
        Card(
          color: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
          child: Slider(
            value: _distanciaMaxima,
            min: 1,
            max: 50,
            divisions: 49,
            activeColor: Colors.green,
            inactiveColor: Colors.grey[300],
            label: '${_distanciaMaxima.round()} km',
            onChanged: (double valor) {
              setState(() => _distanciaMaxima = valor);
            },
          ),
        ),
      ],
    );
  }

  // === NUEVA INTERFAZ: PASO DE CARRUSEL DE FOTOS CUADRADO ===
  Widget _construirPasoCarruselFotos() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Text(
          'Agrega Tus Fotos',
          style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        const Text(
          'Desliza el cuadrado para añadir o cambiar cada una de tus 3 fotos obligatorias.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 14, color: Colors.grey),
        ),
        const SizedBox(height: 30),

        // Contenedor Cuadrado del Carrusel Deslizable
        ClipRRect(
          borderRadius: BorderRadius.circular(25),
          child: Container(
            width: 280,
            height: 280, // Relación perfecta 1:1 (Cuadrado)
            color: Colors.white,
            child: PageView.builder(
              itemCount: _imagenesSeleccionadas.length,
              onPageChanged: (int index) {
                setState(() => _fotoActualCarrusel = index);
              },
              itemBuilder: (context, index) {
                final imagen = _imagenesSeleccionadas[index];
                return GestureDetector(
                  onTap: () => _seleccionarFoto(index),
                  child: Container(
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: const Color(0xFFFF94B4),
                        width: 2,
                      ),
                      borderRadius: BorderRadius.circular(25),
                      image: imagen != null
                          ? DecorationImage(
                              image: FileImage(imagen),
                              fit: BoxFit.cover,
                            )
                          : null,
                    ),
                    child: imagen == null
                        ? Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(
                                Icons.add_photo_alternate,
                                color: Color(0xFFFF3366),
                                size: 50,
                              ),
                              const SizedBox(height: 10),
                              Text(
                                'Toca para subir la foto ${index + 1}',
                                style: const TextStyle(
                                  color: Color(0xFFFF3366),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          )
                        : Stack(
                            children: [
                              Positioned(
                                bottom: 15,
                                right: 15,
                                child: Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: const BoxDecoration(
                                    color: Colors.black54,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.edit,
                                    color: Colors.white,
                                    size: 18,
                                  ),
                                ),
                              ),
                            ],
                          ),
                  ),
                );
              },
            ),
          ),
        ),
        const SizedBox(height: 20),

        // Puntitos Indicadores del Carrusel (Page Indicators)
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(_imagenesSeleccionadas.length, (index) {
            return AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.symmetric(horizontal: 5),
              height: 8,
              width: _fotoActualCarrusel == index ? 24 : 8,
              decoration: BoxDecoration(
                color: _fotoActualCarrusel == index
                    ? const Color(0xFFFF3366)
                    : Colors.grey[400],
                borderRadius: BorderRadius.circular(10),
              ),
            );
          }),
        ),
        const SizedBox(height: 30),
      ],
    );
  }
}
