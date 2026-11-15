// import 'dart:typed_data';

// import 'package:flutter/gestures.dart';
// import 'package:flutter/material.dart';

// import '../api.dart';
// import '../common.dart';

// enum EditMode { select, draw }

// /// Foto parkiran dengan kotak slot di atasnya.
// ///
// /// Semua koordinat (slot, mobil) memakai piksel foto asli, sama seperti yang
// /// dipakai YOLO di backend; widget ini yang mengubahnya ke ukuran layar.
// class SlotCanvas extends StatefulWidget {
//   const SlotCanvas({
//     super.key,
//     required this.imageUrl,
//     required this.imageSize,
//     required this.slots,
//     required this.selected,
//     required this.mode,
//     required this.onSelect,
//     required this.onAdd,
//     required this.onChange,
//     this.statuses,
//     this.cars = const [],
//     this.imageBytes,
//     this.readOnly = false,
//   });

//   /// Tampilan hasil untuk pengunjung: tanpa gestur, lot diwarnai sesuai status.
//   const SlotCanvas.result({
//     super.key,
//     required this.imageSize,
//     required this.slots,
//     required List<String> this.statuses,
//     this.imageUrl = '',
//     this.imageBytes,
//   }) : selected = null,
//        mode = EditMode.select,
//        onSelect = _noSelect,
//        onAdd = _noAdd,
//        onChange = _noChange,
//        cars = const [],
//        readOnly = true;

//   static void _noSelect(int? _) {}
//   static void _noAdd(Rect _) {}
//   static void _noChange(int _, Rect _) {}

//   final String imageUrl;
//   final Uint8List? imageBytes;
//   final bool readOnly;
//   final Size imageSize;
//   final List<Slot> slots;
//   final int? selected;
//   final EditMode mode;
//   final List<String>? statuses;
//   final List<Rect> cars;
//   final ValueChanged<int?> onSelect;
//   final ValueChanged<Rect> onAdd;
//   final void Function(int index, Rect rect) onChange;

//   @override
//   State<SlotCanvas> createState() => _SlotCanvasState();
// }

// enum _Drag { none, draw, move, resize }

// class _SlotCanvasState extends State<SlotCanvas> {
//   static const _handleRadius = 10.0; // dalam piksel layar
//   static const _minSize = 4.0; // dalam piksel foto

//   double _scale = 1;
//   _Drag _drag = _Drag.none;
//   Offset _start = Offset.zero;
//   Offset _current = Offset.zero;
//   Rect _rectAtStart = Rect.zero;
//   Offset _fixedCorner = Offset.zero;
//   int? _dragIndex;

//   Offset _toImage(Offset local) => Offset(
//     (local.dx / _scale).clamp(0, widget.imageSize.width),
//     (local.dy / _scale).clamp(0, widget.imageSize.height),
//   );

//   int? _slotAt(Offset p) {
//     for (var i = widget.slots.length - 1; i >= 0; i--) {
//       if (widget.slots[i].rect.contains(p)) return i;
//     }
//     return null;
//   }

//   List<Offset> _corners(Rect r) => [r.topLeft, r.topRight, r.bottomLeft, r.bottomRight];

//   void _onPanStart(DragStartDetails d) {
//     final p = _toImage(d.localPosition);
//     _start = _current = p;
//     if (widget.mode == EditMode.draw) {
//       setState(() => _drag = _Drag.draw);
//       return;
//     }
//     final sel = widget.selected;
//     if (sel != null && sel < widget.slots.length) {
//       final rect = widget.slots[sel].rect;
//       final corners = _corners(rect);
//       for (var c = 0; c < 4; c++) {
//         if ((corners[c] - p).distance <= _handleRadius / _scale) {
//           _drag = _Drag.resize;
//           _dragIndex = sel;
//           _fixedCorner = corners[3 - c];
//           return;
//         }
//       }
//       if (rect.contains(p)) {
//         _drag = _Drag.move;
//         _dragIndex = sel;
//         _rectAtStart = rect;
//         return;
//       }
//     }
//     final hit = _slotAt(p);
//     if (hit != null) {
//       widget.onSelect(hit);
//       _drag = _Drag.move;
//       _dragIndex = hit;
//       _rectAtStart = widget.slots[hit].rect;
//     } else {
//       _drag = _Drag.none;
//     }
//   }

//   void _onPanUpdate(DragUpdateDetails d) {
//     final p = _toImage(d.localPosition);
//     final size = widget.imageSize;
//     switch (_drag) {
//       case _Drag.draw:
//         setState(() => _current = p);
//       case _Drag.move:
//         var r = _rectAtStart.shift(p - _start);
//         final dx = r.left < 0 ? -r.left : (r.right > size.width ? size.width - r.right : 0.0);
//         final dy = r.top < 0 ? -r.top : (r.bottom > size.height ? size.height - r.bottom : 0.0);
//         r = r.shift(Offset(dx, dy));
//         widget.onChange(_dragIndex!, r);
//       case _Drag.resize:
//         final r = Rect.fromPoints(_fixedCorner, p);
//         if (r.width >= _minSize && r.height >= _minSize) widget.onChange(_dragIndex!, r);
//       case _Drag.none:
//         break;
//     }
//   }

//   void _onPanEnd(DragEndDetails d) {
//     if (_drag == _Drag.draw) {
//       final r = Rect.fromPoints(_start, _current);
//       if (r.width >= _minSize && r.height >= _minSize) widget.onAdd(r);
//     }
//     setState(() {
//       _drag = _Drag.none;
//       _dragIndex = null;
//     });
//   }

//   @override
//   Widget build(BuildContext context) {
//     return LayoutBuilder(
//       builder: (context, constraints) {
//         final img = widget.imageSize;
//         _scale = [constraints.maxWidth / img.width, constraints.maxHeight / img.height].reduce((a, b) => a < b ? a : b);
//         final display = Size(img.width * _scale, img.height * _scale);
//         return Center(
//           child: MouseRegion(
//             cursor: widget.mode == EditMode.draw ? SystemMouseCursors.precise : SystemMouseCursors.basic,
//             child: GestureDetector(
//               // Posisi awal geser = titik mouse ditekan, bukan titik saat geser dikenali,
//               // supaya sudut slot tepat kena dan kotak mengikuti kursor.
//               dragStartBehavior: DragStartBehavior.down,
//               onTapUp: !widget.readOnly && widget.mode == EditMode.select
//                   ? (d) => widget.onSelect(_slotAt(_toImage(d.localPosition)))
//                   : null,
//               onPanStart: widget.readOnly ? null : _onPanStart,
//               onPanUpdate: widget.readOnly ? null : _onPanUpdate,
//               onPanEnd: widget.readOnly ? null : _onPanEnd,
//               child: SizedBox.fromSize(
//                 size: display,
//                 child: Stack(
//                   fit: StackFit.expand,
//                   children: [
//                     if (widget.imageBytes != null)
//                       Image.memory(widget.imageBytes!, fit: BoxFit.fill)
//                     else
//                       Image.network(
//                         widget.imageUrl,
//                         fit: BoxFit.fill,
//                         loadingBuilder: (_, child, progress) =>
//                             progress == null ? child : const Center(child: CircularProgressIndicator()),
//                         errorBuilder: (_, _, _) => const Center(child: Text('Foto gagal dimuat')),
//                       ),
//                     CustomPaint(
//                       painter: _SlotPainter(
//                         scale: _scale,
//                         slots: widget.slots,
//                         selected: widget.selected,
//                         statuses: widget.statuses,
//                         cars: widget.cars,
//                         drawing: _drag == _Drag.draw ? Rect.fromPoints(_start, _current) : null,
//                         handleRadius: _handleRadius,
//                       ),
//                     ),
//                   ],
//                 ),
//               ),
//             ),
//           ),
//         );
//       },
//     );
//   }
// }

// class _SlotPainter extends CustomPainter {
//   _SlotPainter({
//     required this.scale,
//     required this.slots,
//     required this.selected,
//     required this.statuses,
//     required this.cars,
//     required this.drawing,
//     required this.handleRadius,
//   });

//   final double scale;
//   final List<Slot> slots;
//   final int? selected;
//   final List<String>? statuses;
//   final List<Rect> cars;
//   final Rect? drawing;
//   final double handleRadius;

//   static const _neutral = Color(0xFF3B6EF0);
//   static const _car = Color(0xFF00B8D9);

//   Rect _toScreen(Rect r) => Rect.fromLTRB(r.left * scale, r.top * scale, r.right * scale, r.bottom * scale);

//   @override
//   void paint(Canvas canvas, Size size) {
//     final carPaint = Paint()
//       ..style = PaintingStyle.stroke
//       ..strokeWidth = 1.5
//       ..color = _car.withValues(alpha: 0.9);
//     for (final car in cars) {
//       canvas.drawRect(_toScreen(car), carPaint);
//     }

//     for (var i = 0; i < slots.length; i++) {
//       final isSelected = i == selected;
//       final status = statuses != null && i < statuses!.length ? statuses![i] : null;
//       final color = statusColors[status] ?? _neutral;
//       final r = _toScreen(slots[i].rect);
//       canvas.drawRect(r, Paint()..color = color.withValues(alpha: isSelected ? 0.35 : 0.18));
//       canvas.drawRect(
//         r,
//         Paint()
//           ..style = PaintingStyle.stroke
//           ..strokeWidth = isSelected ? 3 : 2
//           ..color = color,
//       );
//       _label(canvas, slots[i].label, r.topLeft, color, textColor: statusTextColor(status));
//       if (isSelected) {
//         for (final c in [r.topLeft, r.topRight, r.bottomLeft, r.bottomRight]) {
//           final h = Rect.fromCenter(center: c, width: handleRadius, height: handleRadius);
//           canvas.drawRect(h, Paint()..color = Colors.white);
//           canvas.drawRect(
//             h,
//             Paint()
//               ..style = PaintingStyle.stroke
//               ..strokeWidth = 1.5
//               ..color = color,
//           );
//         }
//       }
//     }

//     final d = drawing;
//     if (d != null) {
//       final r = _toScreen(d);
//       canvas.drawRect(r, Paint()..color = _neutral.withValues(alpha: 0.2));
//       canvas.drawRect(
//         r,
//         Paint()
//           ..style = PaintingStyle.stroke
//           ..strokeWidth = 2
//           ..color = _neutral,
//       );
//     }
//   }

//   void _label(Canvas canvas, String text, Offset at, Color color, {Color textColor = Colors.white}) {
//     final tp = TextPainter(
//       text: TextSpan(
//         text: text,
//         style: TextStyle(color: textColor, fontSize: 11, fontWeight: FontWeight.w600),
//       ),
//       textDirection: TextDirection.ltr,
//     )..layout();
//     final bg = Rect.fromLTWH(at.dx, at.dy - tp.height - 2, tp.width + 6, tp.height + 2);
//     final box = bg.top < 0 ? bg.shift(Offset(0, -bg.top)) : bg;
//     canvas.drawRect(box, Paint()..color = color);
//     tp.paint(canvas, box.topLeft + const Offset(3, 1));
//   }

//   @override
//   bool shouldRepaint(covariant _SlotPainter old) => true;
// }


import 'dart:typed_data';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../api.dart';
import '../common.dart';

enum EditMode { select, draw }

/// Foto parkiran dengan poligon 4 titik slot di atasnya.
class SlotCanvas extends StatefulWidget {
  const SlotCanvas({
    super.key,
    required this.imageUrl,
    required this.imageSize,
    required this.slots,
    required this.selected,
    required this.mode,
    required this.onSelect,
    required this.onAdd,
    required this.onChange,
    this.statuses,
    this.cars = const [],
    this.imageBytes,
    this.readOnly = false,
  });

  const SlotCanvas.result({
    super.key,
    required this.imageSize,
    required this.slots,
    required List<String> this.statuses,
    this.imageUrl = '',
    this.imageBytes,
  }) : selected = null,
       mode = EditMode.select,
       onSelect = _noSelect,
       onAdd = _noAdd,
       onChange = _noChange,
       cars = const [],
       readOnly = true;

  static void _noSelect(int? _) {}
  static void _noAdd(List<Offset> _) {}
  static void _noChange(int _, List<Offset> _) {}

  final String imageUrl;
  final Uint8List? imageBytes;
  final bool readOnly;
  final Size imageSize;
  final List<Slot> slots;
  final int? selected;
  final EditMode mode;
  final List<String>? statuses;
  final List<Rect> cars;
  final ValueChanged<int?> onSelect;
  final ValueChanged<List<Offset>> onAdd;
  final void Function(int index, List<Offset> points) onChange;

  @override
  State<SlotCanvas> createState() => _SlotCanvasState();
}

enum _Drag { none, move, vertex }

class _SlotCanvasState extends State<SlotCanvas> {
  static const _handleRadius = 11.0;

  double _scale = 1;
  _Drag _drag = _Drag.none;
  Offset _start = Offset.zero;
  List<Offset> _pointsAtStart = [];
  int? _dragIndex;
  int? _vertexIndex;

  // Titik-titik sementara saat mode gambar poligon 4 titik
  final List<Offset> _draftPoints = [];
  Offset? _hoverPoint;

  @override
  void didUpdateWidget(covariant SlotCanvas oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.mode != widget.mode && widget.mode != EditMode.draw) {
      _draftPoints.clear();
      _hoverPoint = null;
    }
  }

  Offset _toImage(Offset local) => Offset(
    (local.dx / _scale).clamp(0, widget.imageSize.width),
    (local.dy / _scale).clamp(0, widget.imageSize.height),
  );

  bool _pointInPolygon(Offset p, List<Offset> poly) {
    bool inside = false;
    for (int i = 0, j = poly.length - 1; i < poly.length; j = i++) {
      if (((poly[i].dy > p.dy) != (poly[j].dy > p.dy)) &&
          (p.dx < (poly[j].dx - poly[i].dx) * (p.dy - poly[i].dy) / (poly[j].dy - poly[i].dy) + poly[i].dx)) {
        inside = !inside;
      }
    }
    return inside;
  }

  int? _slotAt(Offset p) {
    for (var i = widget.slots.length - 1; i >= 0; i--) {
      if (_pointInPolygon(p, widget.slots[i].points)) return i;
    }
    return null;
  }

  void _onTapUp(TapUpDetails d) {
    final p = _toImage(d.localPosition);
    if (widget.mode == EditMode.draw) {
      setState(() {
        _draftPoints.add(p);
        if (_draftPoints.length == 4) {
          widget.onAdd(List<Offset>.from(_draftPoints));
          _draftPoints.clear();
        }
      });
    } else {
      widget.onSelect(_slotAt(p));
    }
  }

  void _onPanStart(DragStartDetails d) {
    if (widget.mode == EditMode.draw) return;
    final p = _toImage(d.localPosition);
    _start = p;

    final sel = widget.selected;
    if (sel != null && sel < widget.slots.length) {
      final pts = widget.slots[sel].points;
      for (var c = 0; c < pts.length; c++) {
        if ((pts[c] - p).distance <= _handleRadius / _scale) {
          _drag = _Drag.vertex;
          _dragIndex = sel;
          _vertexIndex = c;
          _pointsAtStart = List<Offset>.from(pts);
          return;
        }
      }
      if (_pointInPolygon(p, pts)) {
        _drag = _Drag.move;
        _dragIndex = sel;
        _pointsAtStart = List<Offset>.from(pts);
        return;
      }
    }

    final hit = _slotAt(p);
    if (hit != null) {
      widget.onSelect(hit);
      _drag = _Drag.move;
      _dragIndex = hit;
      _pointsAtStart = List<Offset>.from(widget.slots[hit].points);
    } else {
      _drag = _Drag.none;
    }
  }

  void _onPanUpdate(DragUpdateDetails d) {
    final p = _toImage(d.localPosition);
    final size = widget.imageSize;

    if (_drag == _Drag.move && _dragIndex != null) {
      var delta = p - _start;
      double minX = _pointsAtStart.first.dx, maxX = _pointsAtStart.first.dx;
      double minY = _pointsAtStart.first.dy, maxY = _pointsAtStart.first.dy;
      for (final pt in _pointsAtStart) {
        if (pt.dx < minX) minX = pt.dx;
        if (pt.dx > maxX) maxX = pt.dx;
        if (pt.dy < minY) minY = pt.dy;
        if (pt.dy > maxY) maxY = pt.dy;
      }
      final dx = (minX + delta.dx < 0)
          ? -minX
          : (maxX + delta.dx > size.width ? size.width - maxX : delta.dx);
      final dy = (minY + delta.dy < 0)
          ? -minY
          : (maxY + delta.dy > size.height ? size.height - maxY : delta.dy);
      final moved = _pointsAtStart.map((pt) => pt + Offset(dx, dy)).toList();
      widget.onChange(_dragIndex!, moved);
    } else if (_drag == _Drag.vertex && _dragIndex != null && _vertexIndex != null) {
      final updated = List<Offset>.from(_pointsAtStart);
      updated[_vertexIndex!] = p;
      widget.onChange(_dragIndex!, updated);
    }
  }

  void _onPanEnd(DragEndDetails d) {
    setState(() {
      _drag = _Drag.none;
      _dragIndex = null;
      _vertexIndex = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final img = widget.imageSize;
        _scale = [constraints.maxWidth / img.width, constraints.maxHeight / img.height].reduce((a, b) => a < b ? a : b);
        final display = Size(img.width * _scale, img.height * _scale);
        return Center(
          child: MouseRegion(
            cursor: widget.mode == EditMode.draw ? SystemMouseCursors.precise : SystemMouseCursors.basic,
            onHover: (e) {
              if (!widget.readOnly && widget.mode == EditMode.draw) {
                setState(() => _hoverPoint = _toImage(e.localPosition));
              }
            },
            onExit: (_) => setState(() => _hoverPoint = null),
            child: GestureDetector(
              dragStartBehavior: DragStartBehavior.down,
              onTapUp: widget.readOnly ? null : _onTapUp,
              onPanStart: widget.readOnly ? null : _onPanStart,
              onPanUpdate: widget.readOnly ? null : _onPanUpdate,
              onPanEnd: widget.readOnly ? null : _onPanEnd,
              child: SizedBox.fromSize(
                size: display,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (widget.imageBytes != null)
                      Image.memory(widget.imageBytes!, fit: BoxFit.fill)
                    else
                      Image.network(
                        widget.imageUrl,
                        fit: BoxFit.fill,
                        loadingBuilder: (_, child, progress) =>
                            progress == null ? child : const Center(child: CircularProgressIndicator()),
                        errorBuilder: (_, _, _) => const Center(child: Text('Foto gagal dimuat')),
                      ),
                    CustomPaint(
                      painter: _SlotPainter(
                        scale: _scale,
                        slots: widget.slots,
                        selected: widget.selected,
                        statuses: widget.statuses,
                        cars: widget.cars,
                        draftPoints: _draftPoints,
                        hoverPoint: _hoverPoint,
                        handleRadius: _handleRadius,
                      ),
                    ),
                    if (!widget.readOnly && widget.mode == EditMode.draw)
                      Positioned(
                        top: 8,
                        left: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.72),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'Klik sudut slot: ${_draftPoints.length} / 4 titik',
                                style: const TextStyle(color: Colors.white, fontSize: 12),
                              ),
                              if (_draftPoints.isNotEmpty) ...[
                                const SizedBox(width: 8),
                                InkWell(
                                  onTap: () => setState(() => _draftPoints.clear()),
                                  child: const Text(
                                    'Batal',
                                    style: TextStyle(color: Colors.amberAccent, fontSize: 12, fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _SlotPainter extends CustomPainter {
  _SlotPainter({
    required this.scale,
    required this.slots,
    required this.selected,
    required this.statuses,
    required this.cars,
    required this.draftPoints,
    required this.hoverPoint,
    required this.handleRadius,
  });

  final double scale;
  final List<Slot> slots;
  final int? selected;
  final List<String>? statuses;
  final List<Rect> cars;
  final List<Offset> draftPoints;
  final Offset? hoverPoint;
  final double handleRadius;

  static const _neutral = Color(0xFF3B6EF0);
  static const _car = Color(0xFF00B8D9);

  Offset _toScreenPt(Offset p) => Offset(p.dx * scale, p.dy * scale);
  Rect _toScreenRect(Rect r) => Rect.fromLTRB(r.left * scale, r.top * scale, r.right * scale, r.bottom * scale);

  @override
  void paint(Canvas canvas, Size size) {
    final carPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..color = _car.withValues(alpha: 0.9);
    for (final car in cars) {
      canvas.drawRect(_toScreenRect(car), carPaint);
    }

    for (var i = 0; i < slots.length; i++) {
      final isSelected = i == selected;
      final status = statuses != null && i < statuses!.length ? statuses![i] : null;
      final color = statusColors[status] ?? _neutral;
      final pts = slots[i].points.map(_toScreenPt).toList();
      if (pts.length < 3) continue;

      final path = Path()..addPolygon(pts, true);
      canvas.drawPath(path, Paint()..color = color.withValues(alpha: isSelected ? 0.35 : 0.18));
      canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = isSelected ? 3 : 2
          ..color = color,
      );

      _label(canvas, slots[i].label, pts.first, color, textColor: statusTextColor(status));

      if (isSelected) {
        for (final c in pts) {
          canvas.drawCircle(c, handleRadius / 2, Paint()..color = Colors.white);
          canvas.drawCircle(
            c,
            handleRadius / 2,
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 2
              ..color = color,
          );
        }
      }
    }

    // Gambar titik-titik sementara & garis bantu saat user menggambar poligon 4 titik
    if (draftPoints.isNotEmpty) {
      final screenDraft = draftPoints.map(_toScreenPt).toList();
      final linePaint = Paint()
        ..color = Colors.cyanAccent
        ..strokeWidth = 2.5
        ..style = PaintingStyle.stroke;

      final draftPath = Path()..moveTo(screenDraft.first.dx, screenDraft.first.dy);
      for (var i = 1; i < screenDraft.length; i++) {
        draftPath.lineTo(screenDraft[i].dx, screenDraft[i].dy);
      }
      if (hoverPoint != null) {
        final hp = _toScreenPt(hoverPoint!);
        draftPath.lineTo(hp.dx, hp.dy);
        if (screenDraft.length == 3) {
          draftPath.lineTo(screenDraft.first.dx, screenDraft.first.dy);
        }
      }
      canvas.drawPath(draftPath, linePaint);

      for (final pt in screenDraft) {
        canvas.drawCircle(pt, 5, Paint()..color = Colors.cyanAccent);
        canvas.drawCircle(
          pt,
          5,
          Paint()
            ..color = Colors.black
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.5,
        );
      }
    }
  }

  void _label(Canvas canvas, String text, Offset at, Color color, {Color textColor = Colors.white}) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(color: textColor, fontSize: 11, fontWeight: FontWeight.w600),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    final bg = Rect.fromLTWH(at.dx, at.dy - tp.height - 2, tp.width + 6, tp.height + 2);
    final box = bg.top < 0 ? bg.shift(Offset(0, -bg.top)) : bg;
    canvas.drawRect(box, Paint()..color = color);
    tp.paint(canvas, box.topLeft + const Offset(3, 1));
  }

  @override
  bool shouldRepaint(covariant _SlotPainter old) => true;
}