/// A node (junction) in an electrical circuit schematic.
class CircuitNode {
  final String id;
  final String label;
  final double x;
  final double y;

  const CircuitNode({
    required this.id,
    required this.label,
    required this.x,
    required this.y,
  });

  CircuitNode copyWith({
    String? id,
    String? label,
    double? x,
    double? y,
  }) {
    return CircuitNode(
      id: id ?? this.id,
      label: label ?? this.label,
      x: x ?? this.x,
      y: y ?? this.y,
    );
  }
}
