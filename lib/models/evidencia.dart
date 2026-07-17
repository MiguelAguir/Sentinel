import '../core/constants.dart';

class Evidencia {
  final String id;
  final String tareaId;
  final TipoEvidencia tipo;
  final String? url;
  final String? texto;
  final String? comentarioSupervisor;
  final bool? aprobado;
  final String usuarioId;
  final DateTime createdAt;

  Evidencia({
    required this.id,
    required this.tareaId,
    required this.tipo,
    this.url,
    this.texto,
    this.comentarioSupervisor,
    this.aprobado,
    required this.usuarioId,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  factory Evidencia.fromJson(Map<String, dynamic> json) {
    return Evidencia(
      id: json['id'] as String,
      tareaId: json['tarea_id'] as String,
      tipo: TipoEvidencia.fromString(json['tipo'] as String),
      url: json['url'] as String?,
      texto: json['texto'] as String?,
      comentarioSupervisor: json['comentario_supervisor'] as String?,
      aprobado: json['aprobado'] as bool?,
      usuarioId: json['usuario_id'] as String,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'tarea_id': tareaId,
      'tipo': tipo.value,
      'url': url,
      'texto': texto,
    };
  }
}
