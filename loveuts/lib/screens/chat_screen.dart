import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ChatScreen extends StatefulWidget {
  final String matchId;
  final String otroUid;
  final String nombreOtro;
  final String? fotoOtro;
  final String? heroTag;

  const ChatScreen({
    super.key,
    required this.matchId,
    required this.otroUid,
    required this.nombreOtro,
    this.fotoOtro,
    this.heroTag,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _mensajeController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _enviando = false;

  String? get _miUid => FirebaseAuth.instance.currentUser?.uid;

  Widget _avatarConHero({required double radius, required Widget child}) {
    if (widget.heroTag == null) return child;
    return Hero(tag: widget.heroTag!, child: child);
  }

  @override
  void dispose() {
    _mensajeController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _enviarMensaje() async {
    final texto = _mensajeController.text.trim();
    final miUid = _miUid;
    if (texto.isEmpty || miUid == null) return;

    setState(() => _enviando = true);
    _mensajeController.clear();

    try {
      final db = FirebaseFirestore.instance;
      final matchRef = db.collection('matches').doc(widget.matchId);
      final ahora = FieldValue.serverTimestamp();

      await matchRef.collection('mensajes').add({
        'from': miUid,
        'texto': texto,
        'timestamp': ahora,
      });

      await matchRef.update({
        'ultimo_mensaje': texto,
        'ultimo_mensaje_time': ahora,
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error al enviar: $e')));
      }
    } finally {
      if (mounted) setState(() => _enviando = false);
    }
  }

  Future<void> _borrarChat() async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Borrar chat'),
        content: const Text(
          '¿Seguro que quieres borrar este chat? Se eliminarán todos los mensajes pero la coincidencia se mantendrá.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Borrar', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmar != true) return;

    try {
      final db = FirebaseFirestore.instance;
      final mensajes = await db
          .collection('matches')
          .doc(widget.matchId)
          .collection('mensajes')
          .get();

      final batch = db.batch();
      for (final doc in mensajes.docs) {
        batch.delete(doc.reference);
      }
      batch.update(db.collection('matches').doc(widget.matchId), {
        'ultimo_mensaje': null,
        'ultimo_mensaje_time': null,
      });
      await batch.commit();

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Chat borrado')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error al borrar: $e')));
      }
    }
  }

  Future<void> _bloquearUsuario() async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Seguro/a que quiere bloquear Este Usuario, no podrás enviar, ni ver ni que te vean el perfil, ni recibir más mensajes de este usuario, tampoco te aparecerá en futuros matches.',
              style: TextStyle(color: Colors.grey[700], fontSize: 14),
              textAlign: TextAlign.center,
            ),
          ],
        ),
        actions: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.redAccent,
                ),
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text(
                  'Cancelar',
                  style: TextStyle(color: Colors.white),
                ),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1E5631),
                ),
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text(
                  'Confirmar',
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ],
          ),
        ],
      ),
    );

    if (confirmar != true) return;

    try {
      final miUid = _miUid;
      if (miUid == null) return;
      final db = FirebaseFirestore.instance;

      await db
          .collection('bloqueos')
          .doc(miUid)
          .collection('usuarios')
          .doc(widget.otroUid)
          .set({'timestamp': FieldValue.serverTimestamp()});

      await db.collection('matches').doc(widget.matchId).delete();

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${widget.nombreOtro} ha sido bloqueado')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error al bloquear: $e')));
      }
    }
  }

  Future<void> _reportarUsuario() async {
    final motivos = [
      'Spam o contenido no deseado',
      'Acoso o intimidación',
      'Contenido inapropiado',
      'Prefiero no decirlo',
    ];
    String? seleccionado;

    final motivoElegido = await showDialog<String>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Text(
            'Ayúdanos a mantener\nla comunidad segura',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: motivos.map((m) {
              final esElegido = seleccionado == m;
              return ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(m),
                trailing: Icon(
                  esElegido
                      ? Icons.radio_button_checked
                      : Icons.radio_button_off,
                  color: esElegido ? Colors.redAccent : Colors.grey,
                ),
                onTap: () => setLocal(() => seleccionado = m),
              );
            }).toList(),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1E5631),
              ),
              onPressed: seleccionado == null
                  ? null
                  : () => Navigator.pop(ctx, seleccionado),
              child: const Text(
                'Reportar & bloquear',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );

    if (motivoElegido == null) return;

    try {
      final miUid = _miUid;
      if (miUid == null) return;
      final db = FirebaseFirestore.instance;

      await db.collection('reportes').add({
        'reportador': miUid,
        'reportado': widget.otroUid,
        'motivo': motivoElegido,
        'timestamp': FieldValue.serverTimestamp(),
      });

      await db
          .collection('bloqueos')
          .doc(miUid)
          .collection('usuarios')
          .doc(widget.otroUid)
          .set({
            'timestamp': FieldValue.serverTimestamp(),
            'motivo_reporte': motivoElegido,
          });

      await db.collection('matches').doc(widget.matchId).delete();

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Reporte enviado. Gracias por ayudarnos.'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error al reportar: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final miUid = _miUid;

    return Scaffold(
      backgroundColor: const Color(0xFFFFECEF),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 1,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          children: [
            _avatarConHero(
              radius: 18,
              child: CircleAvatar(
                radius: 18,
                backgroundColor: Colors.grey[200],
                backgroundImage: widget.fotoOtro != null
                    ? NetworkImage(widget.fotoOtro!)
                    : null,
                child: widget.fotoOtro == null
                    ? const Icon(Icons.person, color: Colors.grey, size: 20)
                    : null,
              ),
            ),
            const SizedBox(width: 12),
            Text(
              widget.nombreOtro,
              style: const TextStyle(
                color: Colors.black,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, color: Colors.black),
            onSelected: (val) {
              if (val == 'reportar') _reportarUsuario();
              if (val == 'bloquear') _bloquearUsuario();
              if (val == 'borrar') _borrarChat();
            },
            itemBuilder: (ctx) => const [
              PopupMenuItem(value: 'reportar', child: Text('Reportar')),
              PopupMenuItem(value: 'bloquear', child: Text('Bloquear')),
              PopupMenuItem(value: 'borrar', child: Text('Borrar Chat')),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: miUid == null
                ? const Center(child: Text('No hay sesión activa'))
                : StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('matches')
                        .doc(widget.matchId)
                        .collection('mensajes')
                        .orderBy('timestamp', descending: false)
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
                      if (docs.isEmpty) {
                        return Center(
                          child: Padding(
                            padding: const EdgeInsets.all(40),
                            child: Text(
                              'Es un match con ${widget.nombreOtro}.\n¡Rompe el hielo con un saludo!',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 15,
                              ),
                            ),
                          ),
                        );
                      }

                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        if (_scrollController.hasClients) {
                          _scrollController.animateTo(
                            _scrollController.position.maxScrollExtent,
                            duration: const Duration(milliseconds: 200),
                            curve: Curves.easeOut,
                          );
                        }
                      });

                      return ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        itemCount: docs.length,
                        itemBuilder: (context, i) {
                          final data = docs[i].data() as Map<String, dynamic>;
                          final esMio = data['from'] == miUid;
                          final texto = data['texto'] ?? '';
                          final timestamp = data['timestamp'] as Timestamp?;
                          return _Burbuja(
                            texto: texto,
                            esMio: esMio,
                            hora: _formatearHora(timestamp),
                          );
                        },
                      );
                    },
                  ),
          ),
          _construirInputMensaje(),
        ],
      ),
    );
  }

  String _formatearHora(Timestamp? ts) {
    if (ts == null) return '';
    final dt = ts.toDate();
    final h = dt.hour > 12 ? dt.hour - 12 : (dt.hour == 0 ? 12 : dt.hour);
    final m = dt.minute.toString().padLeft(2, '0');
    final ampm = dt.hour >= 12 ? 'p.m.' : 'a.m.';
    return '$h:$m $ampm';
  }

  Widget _construirInputMensaje() {
    return SafeArea(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        color: const Color(0xFFFFECEF),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _mensajeController,
                textCapitalization: TextCapitalization.sentences,
                onSubmitted: (_) => _enviarMensaje(),
                decoration: InputDecoration(
                  hintText: 'Mensaje',
                  fillColor: Colors.white,
                  filled: true,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 12,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(25),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Material(
              color: const Color(0xFF1E5631),
              shape: const CircleBorder(),
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: _enviando ? null : _enviarMensaje,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: _enviando
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Icon(Icons.send, color: Colors.white, size: 22),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Burbuja extends StatelessWidget {
  final String texto;
  final bool esMio;
  final String hora;

  const _Burbuja({
    required this.texto,
    required this.esMio,
    required this.hora,
  });

  @override
  Widget build(BuildContext context) {
    final colorFondo = esMio ? const Color(0xFF1E5631) : Colors.white;
    final colorTexto = esMio ? Colors.white : Colors.black87;
    final alineacion = esMio
        ? CrossAxisAlignment.end
        : CrossAxisAlignment.start;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: alineacion,
        children: [
          ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.75,
            ),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: colorFondo,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(18),
                  topRight: const Radius.circular(18),
                  bottomLeft: Radius.circular(esMio ? 18 : 4),
                  bottomRight: Radius.circular(esMio ? 4 : 18),
                ),
              ),
              child: Text(
                texto,
                style: TextStyle(color: colorTexto, fontSize: 15),
              ),
            ),
          ),
          if (hora.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 2, left: 4, right: 4),
              child: Text(
                hora,
                style: TextStyle(fontSize: 10, color: Colors.grey[600]),
              ),
            ),
        ],
      ),
    );
  }
}
