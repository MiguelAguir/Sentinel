enum EstadoTarea {
  pendiente,
  evidenciaSubida,
  completada,
  rechazada;

  String get value {
    switch (this) {
      case EstadoTarea.pendiente:
        return 'pendiente';
      case EstadoTarea.evidenciaSubida:
        return 'evidencia_subida';
      case EstadoTarea.completada:
        return 'completada';
      case EstadoTarea.rechazada:
        return 'rechazada';
    }
  }

  static EstadoTarea fromString(String s) {
    switch (s) {
      case 'pendiente':
        return EstadoTarea.pendiente;
      case 'evidencia_subida':
        return EstadoTarea.evidenciaSubida;
      case 'completada':
        return EstadoTarea.completada;
      case 'rechazada':
        return EstadoTarea.rechazada;
      default:
        return EstadoTarea.pendiente;
    }
  }
}

enum TipoEvidencia {
  foto,
  documento,
  texto;

  String get value {
    switch (this) {
      case TipoEvidencia.foto:
        return 'foto';
      case TipoEvidencia.documento:
        return 'documento';
      case TipoEvidencia.texto:
        return 'texto';
    }
  }

  static TipoEvidencia fromString(String s) {
    switch (s) {
      case 'foto':
        return TipoEvidencia.foto;
      case 'documento':
        return TipoEvidencia.documento;
      case 'texto':
        return TipoEvidencia.texto;
      default:
        return TipoEvidencia.texto;
    }
  }
}
