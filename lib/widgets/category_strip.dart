import 'package:flutter/material.dart';
import '../theme/moda_theme.dart';

/// Keeps the familiar swipeable chips, with explicit controls for offscreen items.
class CategoryStrip extends StatefulWidget {
  const CategoryStrip({
    super.key,
    required this.child,
    this.padding = EdgeInsets.zero,
  });
  final Widget child;
  final EdgeInsets padding;

  @override
  State<CategoryStrip> createState() => _CategoryStripState();
}

class _CategoryStripState extends State<CategoryStrip> {
  final _scroll = ScrollController();
  bool _back = false, _forward = false, _scheduled = false;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_sync);
    _schedule();
  }

  void _schedule() {
    if (_scheduled) return;
    _scheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scheduled = false;
      if (mounted) _sync();
    });
  }

  void _sync() {
    if (!_scroll.hasClients || !_scroll.position.hasContentDimensions) return;
    final position = _scroll.position;
    final back = position.pixels > position.minScrollExtent + 1;
    final forward = position.pixels < position.maxScrollExtent - 1;
    if (back != _back || forward != _forward) {
      setState(() {
        _back = back;
        _forward = forward;
      });
    }
  }

  void _move(int direction) {
    final position = _scroll.position;
    final target =
        (position.pixels + direction * position.viewportDimension * .72).clamp(
          position.minScrollExtent,
          position.maxScrollExtent,
        );
    if (MediaQuery.disableAnimationsOf(context)) {
      _scroll.jumpTo(target);
    } else {
      _scroll.animateTo(
        target,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      NotificationListener<ScrollMetricsNotification>(
        onNotification: (_) {
          _schedule();
          return false;
        },
        child: Row(
          children: [
            if (_back)
              IconButton(
                tooltip: 'Previous categories',
                color: ModaStyle.charcoal,
                onPressed: () => _move(-1),
                icon: const Icon(Icons.chevron_left),
              ),
            Expanded(
              child: SingleChildScrollView(
                controller: _scroll,
                scrollDirection: Axis.horizontal,
                padding: widget.padding,
                child: widget.child,
              ),
            ),
            if (_forward)
              IconButton(
                tooltip: 'More categories',
                color: ModaStyle.charcoal,
                onPressed: () => _move(1),
                icon: const Icon(Icons.chevron_right),
              ),
          ],
        ),
      );
}
