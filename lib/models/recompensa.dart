class Recompensa {
  final String id;
  final String nombre;
  final String? descripcion;
  final int costoPuntos;
  final bool disponible;
  final String supervisorId;
  final String? usuarioId;
  final DateTime createdAt;

  Recompensa({
    required this.id,
    required this.nombre,
    this.descripcion,
    required this.costoPuntos,
    this.disponible = true,
    required this.supervisorId,
    this.usuarioId,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  factory Recompensa.fromJson(Map<String, dynamic> json) {
    return Recompensa(
      id: json['id'] as String,
      nombre: json['nombre'] as String,
      descripcion: json['descripcion'] as String?,
      costoPuntos: json['costo_puntos'] as int,
      disponible: json['disponible'] as bool? ?? true,
      supervisorId: json['supervisor_id'] as String,
      usuarioId: json['usuario_id'] as String?,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'nombre': nombre,
      'descripcion': descripcion,
      'costo_puntos': costoPuntos,
      'disponible': disponible,
      'supervisor_id': supervisorId,
      'usuario_id': usuarioId,
    };
  }
}
