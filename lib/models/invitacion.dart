class Invitacion {
  final String id;
  final String supervisorId;
  final String supervisorNombre;
  final String usuarioEmail;
  final String estado;
  final DateTime createdAt;

  Invitacion({
    required this.id,
    required this.supervisorId,
    this.supervisorNombre = '',
    required this.usuarioEmail,
    this.estado = 'pendiente',
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  bool get esPendiente => estado == 'pendiente';

  factory Invitacion.fromJson(Map<String, dynamic> json) {
    return Invitacion(
      id: json['id'] as String,
      supervisorId: json['supervisor_id'] as String,
      supervisorNombre: json['supervisor_nombre'] as String? ?? '',
      usuarioEmail: json['usuario_email'] as String,
      estado: json['estado'] as String? ?? 'pendiente',
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'supervisor_id': supervisorId,
      'supervisor_nombre': supervisorNombre,
      'usuario_email': usuarioEmail,
    };
  }
}
