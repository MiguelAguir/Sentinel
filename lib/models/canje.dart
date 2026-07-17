class Canje {
  final String id;
  final String usuarioId;
  final String recompensaId;
  final DateTime createdAt;
  final String? recompensaNombre;
  final int? recompensaCosto;

  Canje({
    required this.id,
    required this.usuarioId,
    required this.recompensaId,
    DateTime? createdAt,
    this.recompensaNombre,
    this.recompensaCosto,
  }) : createdAt = createdAt ?? DateTime.now();

  factory Canje.fromJson(Map<String, dynamic> json) {
    final recompensa = json['recompensas'] as Map<String, dynamic>?;
    return Canje(
      id: json['id'] as String,
      usuarioId: json['usuario_id'] as String,
      recompensaId: json['recompensa_id'] as String,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
      recompensaNombre: recompensa?['nombre'] as String?,
      recompensaCosto: recompensa?['costo_puntos'] as int?,
    );
  }
}
