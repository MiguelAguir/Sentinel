import '../core/constants.dart';

class Tarea {
  final String id;
  final String titulo;
  final String? descripcion;
  final int puntos;
  final DateTime? fechaLimite;
  final bool evidenciaRequerida;
  EstadoTarea estado;
  final String supervisorId;
  final String usuarioId;
  final DateTime createdAt;

  Tarea({
    required this.id,
    required this.titulo,
    this.descripcion,
    this.puntos = 10,
    this.fechaLimite,
    this.evidenciaRequerida = true,
    this.estado = EstadoTarea.pendiente,
    required this.supervisorId,
    required this.usuarioId,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  factory Tarea.fromJson(Map<String, dynamic> json) {
    return Tarea(
      id: json['id'] as String,
      titulo: json['titulo'] as String,
      descripcion: json['descripcion'] as String?,
      puntos: json['puntos'] as int? ?? 10,
      fechaLimite: json['fecha_limite'] != null
          ? DateTime.parse(json['fecha_limite'] as String)
          : null,
      evidenciaRequerida: json['evidencia_requerida'] as bool? ?? true,
      estado: EstadoTarea.fromString(json['estado'] as String? ?? 'pendiente'),
      supervisorId: json['supervisor_id'] as String,
      usuarioId: json['usuario_id'] as String,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'titulo': titulo,
      'descripcion': descripcion,
      'puntos': puntos,
      'fecha_limite': fechaLimite?.toIso8601String(),
      'evidencia_requerida': evidenciaRequerida,
      'estado': estado.value,
      'supervisor_id': supervisorId,
      'usuario_id': usuarioId,
    };
  }
}
