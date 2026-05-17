import 'package:flutter/material.dart';

class StoryItem {
  final String url;
  final DateTime timestamp;
  const StoryItem({required this.url, required this.timestamp});
}

class StoryViewerScreen extends StatefulWidget {
  final String nombreAutor;
  final String? fotoAutor;
  final List<StoryItem> historias;

  const StoryViewerScreen({
    super.key,
    required this.nombreAutor,
    required this.fotoAutor,
    required this.historias,
  });

  @override
  State<StoryViewerScreen> createState() => _StoryViewerScreenState();
}

class _StoryViewerScreenState extends State<StoryViewerScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _progressCtrl;
  int _currentIndex = 0;
  static const Duration _duracion = Duration(seconds: 5);

  @override
  void initState() {
    super.initState();
    _progressCtrl = AnimationController(vsync: this, duration: _duracion);
    _progressCtrl.addStatusListener(_onStatus);
    _progressCtrl.forward();
  }

  void _onStatus(AnimationStatus status) {
    if (status == AnimationStatus.completed) _siguiente();
  }

  @override
  void dispose() {
    _progressCtrl.removeStatusListener(_onStatus);
    _progressCtrl.dispose();
    super.dispose();
  }

  void _siguiente() {
    if (_currentIndex < widget.historias.length - 1) {
      setState(() => _currentIndex++);
      _progressCtrl.reset();
      _progressCtrl.forward();
    } else {
      Navigator.pop(context);
    }
  }

  void _anterior() {
    if (_currentIndex > 0) {
      setState(() => _currentIndex--);
      _progressCtrl.reset();
      _progressCtrl.forward();
    }
  }

  void _onTap(TapDownDetails details) {
    final width = MediaQuery.of(context).size.width;
    if (details.globalPosition.dx < width / 3) {
      _anterior();
    } else {
      _siguiente();
    }
  }

  @override
  Widget build(BuildContext context) {
    final story = widget.historias[_currentIndex];

    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onTapDown: _onTap,
        onLongPressStart: (_) => _progressCtrl.stop(),
        onLongPressEnd: (_) => _progressCtrl.forward(),
        onVerticalDragEnd: (d) {
          if ((d.primaryVelocity ?? 0) > 200) Navigator.pop(context);
        },
        child: Stack(
          children: [
            Positioned.fill(
              child: Image.network(
                story.url,
                fit: BoxFit.contain,
                loadingBuilder: (context, child, prog) {
                  if (prog == null) return child;
                  return const Center(
                    child: CircularProgressIndicator(color: Colors.white),
                  );
                },
                errorBuilder: (context, error, stack) => const Center(
                  child: Icon(Icons.broken_image,
                      color: Colors.white, size: 60),
                ),
              ),
            ),
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                child: Column(
                  children: [
                    Row(
                      children: List.generate(widget.historias.length, (i) {
                        return Expanded(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 2),
                            child: _BarraProgreso(
                              controller: _progressCtrl,
                              completada: i < _currentIndex,
                              activa: i == _currentIndex,
                            ),
                          ),
                        );
                      }),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 18,
                          backgroundColor: Colors.grey[800],
                          backgroundImage: widget.fotoAutor != null
                              ? NetworkImage(widget.fotoAutor!)
                              : null,
                          child: widget.fotoAutor == null
                              ? const Icon(Icons.person,
                                  color: Colors.white, size: 20)
                              : null,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            widget.nombreAutor,
                            style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 14),
                          ),
                        ),
                        Text(
                          _tiempoRelativo(story.timestamp),
                          style: const TextStyle(
                              color: Colors.white70, fontSize: 12),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, color: Colors.white),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _tiempoRelativo(DateTime ts) {
    final diff = DateTime.now().difference(ts);
    if (diff.inMinutes < 1) return 'ahora';
    if (diff.inMinutes < 60) return 'hace ${diff.inMinutes}m';
    return 'hace ${diff.inHours}h';
  }
}

class _BarraProgreso extends StatelessWidget {
  final AnimationController controller;
  final bool completada;
  final bool activa;

  const _BarraProgreso({
    required this.controller,
    required this.completada,
    required this.activa,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(2),
      child: SizedBox(
        height: 3,
        child: completada
            ? Container(color: Colors.white)
            : activa
                ? AnimatedBuilder(
                    animation: controller,
                    builder: (context, child) => LinearProgressIndicator(
                      value: controller.value,
                      backgroundColor: Colors.white24,
                      valueColor:
                          const AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : Container(color: Colors.white24),
      ),
    );
  }
}
