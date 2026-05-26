import 'dart:math' as math;

import 'package:flutter/material.dart';

class LiquidNavItem {
  const LiquidNavItem({required this.icon, required this.semanticLabel});

  final IconData icon;
  final String semanticLabel;
}

class LiquidBottomNav extends StatefulWidget {
  const LiquidBottomNav({
    super.key,
    required this.currentIndex,
    required this.items,
    required this.onTap,
    this.backgroundColor = Colors.white,
    this.activeIconColor = const Color.fromARGB(255, 181, 115, 183),
    this.inactiveIconColor = const Color(0xFF8A8793),
  }) : assert(items.length >= 2);

  final int currentIndex;
  final List<LiquidNavItem> items;
  final ValueChanged<int> onTap;
  final Color backgroundColor;
  final Color activeIconColor;
  final Color inactiveIconColor;

  @override
  State<LiquidBottomNav> createState() => _LiquidBottomNavState();
}

class _LiquidBottomNavState extends State<LiquidBottomNav>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _animation;

  double _prevIndex = 0.0;
  double _currentIndex = 0.0;

  @override
  void initState() {
    super.initState();
    _prevIndex = widget.currentIndex.toDouble();
    _currentIndex = widget.currentIndex.toDouble();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 380),
    );

    _animation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOutCubic,
    );
  }

  @override
  void didUpdateWidget(covariant LiquidBottomNav oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.currentIndex != widget.currentIndex) {
      // Si ya hay una animación en curso, capturar el valor actual para un despegue fluido
      _prevIndex = _controller.isAnimating
          ? (_prevIndex + (_currentIndex - _prevIndex) * _animation.value)
          : oldWidget.currentIndex.toDouble();
      _currentIndex = widget.currentIndex.toDouble();
      
      _controller
        ..stop()
        ..reset()
        ..forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final mediaBottom = MediaQuery.of(context).padding.bottom;

    return LayoutBuilder(
      builder: (context, constraints) {
        final totalWidth = constraints.maxWidth;
        final itemCount = widget.items.length;
        final itemWidth = totalWidth / itemCount;

        return AnimatedBuilder(
          animation: _animation,
          builder: (context, _) {
            // Progreso t de la animación (0.0 a 1.0)
            final t = _controller.isAnimating ? _animation.value : 1.0;
            
            // Índice interpolado actual
            final double interpolatedIndex = _prevIndex + (_currentIndex - _prevIndex) * t;

            // Coordenada X del centro del ítem seleccionado
            final activeX = itemWidth * interpolatedIndex + itemWidth / 2;

            // Física del brinco parabólico (math.sin alcanza 1.0 en t = 0.5)
            final jumpProgress = math.sin(math.pi * t);
            
            // El desplazamiento vertical (top): la pelota sube en el aire hasta 38px
            final topOffset = -14.0 - (jumpProgress * 38.0);

            // Efecto elástico de squish & stretch (deformación de pelota de goma)
            // Se reduce en X y se estira en Y al saltar, y se aplasta al caer.
            final scaleX = 1.0 - (jumpProgress * 0.12);
            final scaleY = 1.0 + (jumpProgress * 0.08);

            return Container(
              padding: EdgeInsets.fromLTRB(16, 8, 16, math.max(10, mediaBottom)),
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  // 1. Fondo de Navbar pintado a mano con curva y sombra (alto 76)
                  CustomPaint(
                    size: Size(totalWidth, 76),
                    painter: BottomNavPainter(
                      activeX: activeX,
                      backgroundColor: widget.backgroundColor,
                      cornerRadius: 36.0,
                      depth: 28.0,
                    ),
                  ),

                  // 2. Pelota saltarina flotante
                  Positioned(
                    left: activeX - 27, // Centrado horizontal
                    top: topOffset,
                    child: Transform(
                      alignment: Alignment.center,
                      transform: Matrix4.diagonal3Values(scaleX, scaleY, 1.0),
                      child: Container(
                        width: 54,
                        height: 54,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: widget.activeIconColor,
                          boxShadow: [
                            BoxShadow(
                              color: widget.activeIconColor.withOpacity(0.4),
                              blurRadius: 12,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: Center(
                          child: AnimatedSwitcher(
                            duration: const Duration(milliseconds: 180),
                            transitionBuilder: (child, animation) {
                              return ScaleTransition(
                                scale: animation,
                                child: FadeTransition(
                                  opacity: animation,
                                  child: child,
                                ),
                              );
                            },
                            child: Icon(
                              widget.items[widget.currentIndex].icon,
                              key: ValueKey<int>(widget.currentIndex),
                              color: Colors.white,
                              size: 25,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),

                  // 3. Íconos inactivos interactivos con etiquetas flotantes (alto 76)
                  SizedBox(
                    height: 76,
                    child: Row(
                      children: List.generate(itemCount, (index) {
                        final item = widget.items[index];
                        final isSelected = index == widget.currentIndex;

                        return Expanded(
                          child: Semantics(
                            button: true,
                            selected: isSelected,
                            label: item.semanticLabel,
                            child: InkWell(
                              borderRadius: BorderRadius.circular(24),
                              onTap: () => widget.onTap(index),
                              child: Stack(
                                alignment: Alignment.center,
                                children: [
                                  // Ícono normal (centrado verticalmente, desaparece al seleccionarse)
                                  Center(
                                    child: AnimatedOpacity(
                                      duration: const Duration(milliseconds: 180),
                                      opacity: isSelected ? 0.0 : 1.0,
                                      child: AnimatedScale(
                                        duration: const Duration(milliseconds: 180),
                                        scale: isSelected ? 0.4 : 1.0,
                                        child: Icon(
                                          item.icon,
                                          size: 25,
                                          color: widget.inactiveIconColor,
                                        ),
                                      ),
                                    ),
                                  ),
                                  
                                  // Nombre de la opción (aparece pequeño abajo cuando es seleccionado)
                                  Positioned(
                                    bottom: 10,
                                    child: AnimatedOpacity(
                                      duration: const Duration(milliseconds: 250),
                                      curve: Curves.easeInOut,
                                      opacity: isSelected ? 1.0 : 0.0,
                                      child: AnimatedSlide(
                                        duration: const Duration(milliseconds: 250),
                                        curve: Curves.easeOutBack,
                                        offset: isSelected ? Offset.zero : const Offset(0, 0.5),
                                        child: AnimatedScale(
                                          duration: const Duration(milliseconds: 250),
                                          scale: isSelected ? 1.0 : 0.7,
                                          child: Text(
                                            item.semanticLabel,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              fontSize: 10.5,
                                              fontWeight: FontWeight.w800,
                                              color: widget.activeIconColor,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      }),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

class BottomNavPainter extends CustomPainter {
  final double activeX;
  final Color backgroundColor;
  final double cornerRadius;
  final double depth;

  BottomNavPainter({
    required this.activeX,
    required this.backgroundColor,
    this.cornerRadius = 36.0,
    this.depth = 28.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = backgroundColor
      ..style = PaintingStyle.fill;

    final path = Path();
    final width = size.width;
    final height = size.height;

    // Ancho de la curva/recorte de la pestaña activa
    const halfWidth = 46.0;
    final left = activeX - halfWidth;
    final right = activeX + halfWidth;

    // Prevenir solapamientos inversos y glitches en las esquinas extremas (izquierda y derecha)
    final leftStart = math.min(left, cornerRadius);
    final rightStart = math.max(right, width - cornerRadius);

    // Dibujar la silueta superior de la barra de navegación con esquinas redondeadas
    path.moveTo(0, cornerRadius);
    path.quadraticBezierTo(0, 0, leftStart, 0);
    path.lineTo(left, 0);

    // Curva bezier cúbica suave y orgánica (la cuna o notch de la pelota)
    path.cubicTo(
      activeX - halfWidth + 18.0, 0,
      activeX - 22.0, depth,
      activeX, depth,
    );
    path.cubicTo(
      activeX + 22.0, depth,
      activeX + halfWidth - 18.0, 0,
      right, 0,
    );

    // Resto del contorno del contenedor
    path.lineTo(rightStart, 0);
    path.quadraticBezierTo(width, 0, width, cornerRadius);
    path.lineTo(width, height - cornerRadius);
    path.quadraticBezierTo(width, height, width - cornerRadius, height);
    path.lineTo(cornerRadius, height);
    path.quadraticBezierTo(0, height, 0, height - cornerRadius);
    path.close();

    // 1. Pintar la sombra suave en la parte externa (sin recortar para que se vea la elevación)
    final shadowPaint = Paint()
      ..color = const Color(0x1A000000)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 16);
    canvas.drawPath(path.shift(const Offset(0, 6)), shadowPaint);

    // 2. Pintar el fondo blanco de forma segura recortando con el contenedor RRect
    // Esto asegura que la curva blanca NUNCA sobresalga de las esquinas redondeadas
    canvas.save();
    final RRect rrect = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 0, width, height),
      Radius.circular(cornerRadius),
    );
    canvas.clipRRect(rrect);
    canvas.drawPath(path, paint);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant BottomNavPainter oldDelegate) {
    return oldDelegate.activeX != activeX ||
        oldDelegate.backgroundColor != backgroundColor ||
        oldDelegate.cornerRadius != cornerRadius ||
        oldDelegate.depth != depth;
  }
}
