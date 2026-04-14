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

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 620),
    );
    _animation = CurvedAnimation(parent: _controller, curve: Curves.elasticOut);
  }

  @override
  void didUpdateWidget(covariant LiquidBottomNav oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.currentIndex != widget.currentIndex) {
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

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final t = _controller.isAnimating ? _animation.value : 1.0;
        final wave = math.sin(math.pi * t);
        final bounceY = wave * 6.0;

        return Container(
          padding: EdgeInsets.fromLTRB(16, 8, 16, math.max(10, mediaBottom)),
          child: Container(
            height: 78,
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: widget.backgroundColor,
              borderRadius: BorderRadius.circular(36),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x22000000),
                  blurRadius: 22,
                  offset: Offset(0, 10),
                ),
              ],
            ),
            child: Row(
              children: List.generate(widget.items.length, (index) {
                final item = widget.items[index];
                final active = index == widget.currentIndex;
                return Expanded(
                  child: Semantics(
                    button: true,
                    selected: active,
                    label: item.semanticLabel,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(24),
                      onTap: () => widget.onTap(index),
                      child: Center(
                        child: Transform.translate(
                          offset: Offset(0, active ? -bounceY : 0),
                          child: AnimatedScale(
                            scale: active ? 1.12 : 1,
                            duration: const Duration(milliseconds: 220),
                            curve: Curves.easeInOut,
                            child: Icon(
                              item.icon,
                              size: 25,
                              color: active
                                  ? widget.activeIconColor
                                  : widget.inactiveIconColor,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              }),
            ),
          ),
        );
      },
    );
  }
}
