class Usuario {
  final String id;
  final String authUserId;
  final String email;
  final String nombre;
  final String rol;
  final String? supervisorId;
  final int puntos;
  final int rachaActual;
  final String? ultimaCompletada;
  final DateTime createdAt;

  Usuario({
    required this.id,
    required this.authUserId,
    required this.email,
    required this.nombre,
    required this.rol,
    this.supervisorId,
    this.puntos = 0,
    this.rachaActual = 0,
    this.ultimaCompletada,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  bool get esSupervisor => rol == 'supervisor';
  bool get esUsuario => rol == 'usuario';

  factory Usuario.fromJson(Map<String, dynamic> json) {
    return Usuario(
      id: json['id'] as String,
      authUserId: json['auth_user_id'] as String? ?? json['id'] as String,
      email: json['email'] as String,
      nombre: json['nombre'] as String,
      rol: json['rol'] as String,
      supervisorId: json['supervisor_id'] as String?,
      puntos: json['puntos'] as int? ?? 0,
      rachaActual: json['racha_actual'] as int? ?? 0,
      ultimaCompletada: json['ultima_completada'] as String?,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'auth_user_id': authUserId,
      'email': email,
      'nombre': nombre,
      'rol': rol,
      'supervisor_id': supervisorId,
      'puntos': puntos,
    };
  }
}
