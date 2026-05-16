import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class CrearPerfilPasosScreen extends StatefulWidget {
  const CrearPerfilPasosScreen({super.key});

  @override
  State<CrearPerfilPasosScreen> createState() => _CrearPerfilPasosScreenState();
}

class _CrearPerfilPasosScreenState extends State<CrearPerfilPasosScreen> {
  final PageController _pageController = PageController();
  int _paginaActual = 0;
  final int _totalPaginas = 8; // ¡Subimos a 8 pasos!

  // Controladores de Cajas de Texto
  final TextEditingController _telefonoController = TextEditingController();
  final TextEditingController _nombreController = TextEditingController();
  final TextEditingController _edadController = TextEditingController();

  // Variables de Selección Única
  String? _generoSeleccionado;
  String? _busquedaSeleccionada;
  String? _orientacionSeleccionada;

  // NUEVO: Datos para la fórmula del Match
  final List<String> _interesesSeleccionados = [];
  RangeValues _rangoEdadPreferido = const RangeValues(18, 25); // Rango inicial por defecto
  double _distanciaMaxima = 10.0; // En kilómetros

  bool _isLoading = false;

  // Listas de opciones estáticas
  final List<String> _generos = ['Hombre', 'Mujer'];
  final List<String> _opcionesBusqueda = ['Una relación', 'Algo Casual', 'No estoy segura o seguro','Amistad', 'Prefiero No decirlo'];
  final List<String> _opcionesOrientacion = ['Heterosexual', 'Homosexual', 'Bisexual', 'Otro'];
  
  // Lista de Intereses del Backlog
  final List<String> _listaIntereses = [
    'Lectura', 'Películas', 'Videojuegos', 'Tecnología', 
    'Viajar', 'Música', 'Pintura', 'Moda',
    'Anime', 'Gym', 'Estudiar',
    'Deporte', 'Mascotas', 'Cocina', 'Baile', 'Fotografía'
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
    if (_paginaActual == 0 && _telefonoController.text.trim().isEmpty) mensaje = 'Por favor ingresa tu teléfono';
    if (_paginaActual == 1 && _nombreController.text.trim().isEmpty) mensaje = 'Por favor dinos tu nombre';
    if (_paginaActual == 2) {
      final edad = int.tryParse(_edadController.text.trim());
      if (edad == null || edad < 18) mensaje = 'Debes ingresar una edad válida (Mayor de 18)';
    }
    if (_paginaActual == 3 && _generoSeleccionado == null) mensaje = 'Selecciona tu género';
    if (_paginaActual == 4 && _busquedaSeleccionada == null) mensaje = 'Cuéntanos qué buscas';
    if (_paginaActual == 5 && _orientacionSeleccionada == null) mensaje = 'Selecciona tu orientación';
    
    // VALIDACIÓN NUEVA: Mínimo 3 intereses
    if (_paginaActual == 6 && _interesesSeleccionados.length < 3) {
      mensaje = 'Por favor selecciona al menos 3 intereses (${_interesesSeleccionados.length}/3)';
    }

    if (mensaje.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(mensaje)));
      return false;
    }
    return true;
  }

  Future<void> _finalizarPerfil() async {
    setState(() => _isLoading = true);
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        // Guardamos todo el paquete consolidado en Firestore
        await FirebaseFirestore.instance.collection('usuarios').doc(user.uid).set({
          'telefono': _telefonoController.text.trim(),
          'nombre': _nombreController.text.trim(),
          'edad': int.parse(_edadController.text.trim()),
          'genero': _generoSeleccionado,
          'que_busca': _busquedaSeleccionada,
          'orientacion': _orientacionSeleccionada,
          // Guardando datos del algoritmo de Match:
          'intereses': _interesesSeleccionados,
          'match_edad_min': _rangoEdadPreferido.start.round(),
          'match_edad_max': _rangoEdadPreferido.end.round(),
          'match_distancia_max': _distanciaMaxima.round(),
          'perfil_completo': true,
          'fecha_creacion': FieldValue.serverTimestamp(),
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('¡Tu perfil de Love UTS está completo!')),
        );
        Navigator.pushReplacementNamed(context, '/home');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    double progreso = (_paginaActual + 1) / _totalPaginas;

    return Scaffold(
      backgroundColor: const Color(0xFFFFECEF), // Fondo rosa sutil del mockup
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: _paginaActual > 0
            ? IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.black),
                onPressed: () {
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
                      onPageChanged: (index) => setState(() => _paginaActual = index),
                      children: [
                        _construirPasoTexto('Mi número es', 'Necesitaremos tu número de teléfono para contactarte.', _telefonoController, 'Número de teléfono', TextInputType.phone),
                        _construirPasoTexto('¿Cómo te llamas?', 'Conozcámonos un poco.', _nombreController, 'Nombre o apodo', TextInputType.text),
                        _construirPasoTexto('¿Qué edad tienes?', 'Debes ser mayor de edad para usar Love UTS.', _edadController, 'Tu edad', TextInputType.number),
                        _construirPasoSeleccion('Mi género es', 'Selecciona la opción con la que te identificas.', _generos, _generoSeleccionado, (val) => setState(() => _generoSeleccionado = val)),
                        _construirPasoSeleccion('Estoy buscando...', 'Esto nos ayudará a filtrar tus posibles matches.', _opcionesBusqueda, _busquedaSeleccionada, (val) => setState(() => _busquedaSeleccionada = val)),
                        _construirPasoSeleccion('Mi orientación es', 'Dinos cuál es tu orientación sexual.', _opcionesOrientacion, _orientacionSeleccionada, (val) => setState(() => _orientacionSeleccionada = val)),
                        
                        // PASO 7: Intereses en Burbujas Seleccionables
                        _construirPasoIntereses(),

                        // PASO 8: Filtros del algoritmo (Edad y Distancia)
                        _construirPasoFiltrosMatch(),
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
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
                      ),
                      child: Text(
                        _paginaActual == _totalPaginas - 1 ? 'Finalizar Perfil' : 'Continuar',
                        style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
    );
  }

  // --- VISTAS EXISTENTES OPTIMIZADAS ---
  Widget _construirPasoTexto(String titulo, String subtitulo, TextEditingController controller, String hint, TextInputType tipoTeclado) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(titulo, style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold)),
        const SizedBox(height: 10),
        Text(subtitulo, textAlign: TextAlign.center, style: const TextStyle(fontSize: 14, color: Colors.grey)),
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

  Widget _construirPasoSeleccion(String titulo, String subtitulo, List<String> opciones, String? seleccionado, Function(String) alCambiar) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(titulo, style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold)),
        const SizedBox(height: 10),
        Text(subtitulo, textAlign: TextAlign.center, style: const TextStyle(fontSize: 14, color: Colors.grey)),
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
                    backgroundColor: esSeleccionado ? Colors.redAccent[100] : Colors.white,
                    side: BorderSide(color: esSeleccionado ? Colors.redAccent : Colors.grey[400]!, width: 2),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                  ),
                  onPressed: () => alCambiar(opcion),
                  child: Text(opcion, style: const TextStyle(fontSize: 15, color: Colors.black)),
                ),
              ),
            );
          }).toList(),
        )
      ],
    );
  }

  // --- NUEVAS VISTAS AGREGADAS ---

  // Vista de Intereses con Wrap y FilterChips automáticos
  Widget _construirPasoIntereses() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Text('Tus intereses', style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold)),
        const SizedBox(height: 10),
        Text(
          'Selecciona al menos 3 opciones (${_interesesSeleccionados.length} elegidas)',
          style: const TextStyle(fontSize: 14, color: Colors.grey),
        ),
        const SizedBox(height: 25),
        SingleChildScrollView(
          child: Wrap(
            spacing: 10.0, // Espacio horizontal entre burbujas
            runSpacing: 10.0, // Espacio vertical entre líneas
            alignment: WrapAlignment.center,
            children: _listaIntereses.map((interes) {
              final estaSeleccionado = _interesesSeleccionados.contains(interes);
              return FilterChip(
                label: Text(interes),
                selected: estaSeleccionado,
                selectedColor: Colors.redAccent[100],
                checkmarkColor: Colors.redAccent,
                backgroundColor: Colors.white,
                labelStyle: TextStyle(
                  color: estaSeleccionado ? Colors.redAccent[900] : Colors.black87,
                  fontWeight: estaSeleccionado ? FontWeight.bold : FontWeight.normal,
                ),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
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

  // Vista de Filtros Avanzados (Edad y Distancia) para el Match
  Widget _construirPasoFiltrosMatch() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Center(
          child: Text('Preferencias de Match', style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold)),
        ),
        const Center(
          child: Text('Configura tus filtros ideales para conectar.', style: TextStyle(fontSize: 14, color: Colors.grey)),
        ),
        const SizedBox(height: 40),

        // Rango de Edad
        Text(
          'Rango de edad cómodo: ${_rangoEdadPreferido.start.round()} - ${_rangoEdadPreferido.end.round()} años',
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 10),
        Card(
          color: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
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

        // Distancia Máxima
        Text(
          'Distancia máxima: ${_distanciaMaxima.round()} km',
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 10),
        Card(
          color: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
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
}