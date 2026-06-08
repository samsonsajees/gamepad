import 'dart:convert';

/// Stores how far an element has been moved / scaled / rotated from its
/// default position.  All values are *deltas* from the element's natural
/// spot so the layout automatically adapts to any screen size.
class ElementLayout {
  final String id;
  final double dx;       // horizontal offset from default (logical px)
  final double dy;       // vertical offset from default (logical px)
  final double scale;    // size multiplier — clamped to [0.4, 2.5]
  final double rotation; // degrees; snaps near 0 / 90 / 180 / 270

  const ElementLayout({
    required this.id,
    this.dx = 0.0,
    this.dy = 0.0,
    this.scale = 1.0,
    this.rotation = 0.0,
  });

  bool get isDefault =>
      dx == 0.0 && dy == 0.0 && scale == 1.0 && rotation == 0.0;

  ElementLayout copyWith({
    double? dx,
    double? dy,
    double? scale,
    double? rotation,
  }) =>
      ElementLayout(
        id: id,
        dx: dx ?? this.dx,
        dy: dy ?? this.dy,
        scale: scale ?? this.scale,
        rotation: rotation ?? this.rotation,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'dx': dx,
        'dy': dy,
        'scale': scale,
        'rotation': rotation,
      };

  factory ElementLayout.fromJson(Map<String, dynamic> json) => ElementLayout(
        id: json['id'] as String,
        dx: (json['dx'] as num?)?.toDouble() ?? 0.0,
        dy: (json['dy'] as num?)?.toDouble() ?? 0.0,
        scale: (json['scale'] as num?)?.toDouble() ?? 1.0,
        rotation: (json['rotation'] as num?)?.toDouble() ?? 0.0,
      );
}

/// The complete layout for one gamepad screen.
class ScreenLayout {
  final Map<String, ElementLayout> elements;

  const ScreenLayout({this.elements = const {}});

  /// Returns the stored layout for [id], or a default (no-op) layout.
  ElementLayout forId(String id) =>
      elements[id] ?? ElementLayout(id: id);

  ScreenLayout withElement(ElementLayout el) => ScreenLayout(
        elements: Map.unmodifiable({...elements, el.id: el}),
      );

  ScreenLayout withoutElement(String id) {
    final copy = Map<String, ElementLayout>.from(elements)..remove(id);
    return ScreenLayout(elements: Map.unmodifiable(copy));
  }

  Map<String, dynamic> toJson() => {
        'elements': elements.map((k, v) => MapEntry(k, v.toJson())),
      };

  factory ScreenLayout.fromJson(Map<String, dynamic> json) {
    final raw = (json['elements'] as Map<String, dynamic>?) ?? {};
    return ScreenLayout(
      elements: Map.unmodifiable(raw.map(
        (k, v) => MapEntry(k, ElementLayout.fromJson(v as Map<String, dynamic>)),
      )),
    );
  }

  String toJsonString() => jsonEncode(toJson());

  factory ScreenLayout.fromJsonString(String s) =>
      ScreenLayout.fromJson(jsonDecode(s) as Map<String, dynamic>);
}
