import 'dart:typed_data';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/usuario.dart';
import '../models/tarea.dart';
import '../models/evidencia.dart';
import '../models/recompensa.dart';
import '../models/canje.dart';
import '../models/invitacion.dart';

import '../core/constants.dart';

class SupabaseService {
  static final SupabaseService _instance = SupabaseService._internal();
  factory SupabaseService() => _instance;
  SupabaseService._internal();

  SupabaseClient get client => Supabase.instance.client;

  // ============================
  // AUTH
  // ============================
  Future<Usuario?> signIn(String email, String password) async {
    final resp = await client.auth.signInWithPassword(
      email: email.trim(),
      password: password,
    );
    if (resp.user == null) return null;
    final perfiles = await getPerfiles(resp.user!.id);
    if (perfiles.isEmpty) return null;
    return perfiles.first;
  }

  Future<Usuario?> signUp({
    required String email,
    required String password,
    required String nombre,
    required String rol,
    String? supervisorEmail,
  }) async {
    final resp = await client.auth.signUp(
      email: email,
      password: password,
    );
    if (resp.user == null) return null;

    String? supervisorId;
    if (rol == 'usuario' && supervisorEmail != null) {
      final sup = await client
          .from('usuarios')
          .select('id')
          .eq('email', supervisorEmail)
          .maybeSingle();
      if (sup != null) supervisorId = sup['id'] as String;
    }

    final inserted = await client.from('usuarios').insert({
      'auth_user_id': resp.user!.id,
      'email': email,
      'nombre': nombre,
      'rol': rol,
      'supervisor_id': supervisorId,
    }).select().single();

    return Usuario.fromJson(inserted);
  }

  Future<Usuario?> crearSegundoPerfil({
    required String email,
    required String nombre,
    required String rol,
    String? supervisorEmail,
  }) async {
    final authUser = client.auth.currentUser;
    if (authUser == null) return null;

    String? supervisorId;
    if (rol == 'usuario' && supervisorEmail != null) {
      final sup = await client
          .from('usuarios')
          .select('id')
          .eq('email', supervisorEmail)
          .maybeSingle();
      if (sup != null) supervisorId = sup['id'] as String;
    }

    final inserted = await client.from('usuarios').insert({
      'auth_user_id': authUser.id,
      'email': email,
      'nombre': nombre,
      'rol': rol,
      'supervisor_id': supervisorId,
    }).select().single();

    return Usuario.fromJson(inserted);
  }

  Future<void> signOut() async {
    await client.auth.signOut();
  }

  Future<List<Usuario>> getPerfiles(String authUserId) async {
    final resp = await client
        .from('usuarios')
        .select()
        .eq('auth_user_id', authUserId)
        .order('created_at');
    return resp.map((j) => Usuario.fromJson(j)).toList();
  }

  Future<Usuario> getUsuario(String id) async {
    final resp = await client.from('usuarios').select().eq('id', id).single();
    return Usuario.fromJson(resp);
  }

  Future<List<Usuario>> getUsuariosDeSupervisor(String supervisorId) async {
    final resp = await client
        .from('usuarios')
        .select()
        .eq('supervisor_id', supervisorId)
        .eq('rol', 'usuario')
        .order('created_at');
    return resp.map((j) => Usuario.fromJson(j)).toList();
  }

  Future<int> contarUsuariosDeSupervisor(String supervisorProfileId) async {
    final result = await client.rpc('contar_usuarios_de_supervisor', params: {
      'p_supervisor_id': supervisorProfileId,
    });
    return result as int;
  }

  // ============================
  // INVITACIONES
  // ============================
  Future<void> crearInvitacion(String supervisorId, String supervisorNombre, String usuarioEmail) async {
    await client.from('invitaciones').insert({
      'supervisor_id': supervisorId,
      'supervisor_nombre': supervisorNombre,
      'usuario_email': usuarioEmail,
    });
  }

  Future<List<Invitacion>> getInvitacionesPendientes(String email) async {
    final resp = await client
        .from('invitaciones')
        .select()
        .eq('usuario_email', email)
        .eq('estado', 'pendiente')
        .order('created_at', ascending: false);
    return resp.map((j) => Invitacion.fromJson(j)).toList();
  }

  Future<List<Invitacion>> getInvitacionesEnviadas(String supervisorId) async {
    final resp = await client
        .from('invitaciones')
        .select()
        .eq('supervisor_id', supervisorId)
        .order('created_at', ascending: false);
    return resp.map((j) => Invitacion.fromJson(j)).toList();
  }

  Future<void> aceptarInvitacion(String invitacionId, String usuarioId) async {
    await client.from('invitaciones').update({'estado': 'aceptada'}).eq('id', invitacionId);
    final inv = await client.from('invitaciones').select('supervisor_id').eq('id', invitacionId).single();
    await client.from('usuarios').update({'supervisor_id': inv['supervisor_id']}).eq('id', usuarioId);
  }

  Future<void> rechazarInvitacion(String invitacionId) async {
    await client.from('invitaciones').update({'estado': 'rechazada'}).eq('id', invitacionId);
  }

  // ============================
  // TAREAS
  // ============================
  Future<List<Tarea>> getTareasDeUsuario(String usuarioId) async {
    final resp = await client
        .from('tareas')
        .select()
        .eq('usuario_id', usuarioId)
        .order('created_at', ascending: false);
    return resp.map((j) => Tarea.fromJson(j)).toList();
  }

  Future<List<Tarea>> getTareasDeSupervisor(String supervisorId) async {
    final resp = await client
        .from('tareas')
        .select()
        .eq('supervisor_id', supervisorId)
        .order('created_at', ascending: false);
    return resp.map((j) => Tarea.fromJson(j)).toList();
  }

  Future<Tarea> crearTarea(Tarea tarea) async {
    final resp = await client.from('tareas').insert(tarea.toJson()).select().single();
    return Tarea.fromJson(resp);
  }

  Future<void> actualizarEstadoTarea(String tareaId, EstadoTarea estado) async {
    await client.from('tareas').update({'estado': estado.value}).eq('id', tareaId);
  }

  Future<Tarea> actualizarTarea(String id, Map<String, dynamic> datos) async {
    final resp = await client.from('tareas').update(datos).eq('id', id).select().single();
    return Tarea.fromJson(resp);
  }

  Future<void> eliminarTarea(String id) async {
    await client.from('evidencias').delete().eq('tarea_id', id);
    await client.from('tareas').delete().eq('id', id);
  }

  // ============================
  // EVIDENCIAS
  // ============================
  Future<List<Evidencia>> getEvidenciasDeTarea(String tareaId) async {
    final resp = await client
        .from('evidencias')
        .select()
        .eq('tarea_id', tareaId)
        .order('created_at');
    return resp.map((j) => Evidencia.fromJson(j)).toList();
  }

  Future<Evidencia> subirEvidencia({
    required String tareaId,
    required TipoEvidencia tipo,
    String? url,
    String? texto,
    required String usuarioId,
  }) async {
    final resp = await client.from('evidencias').insert({
      'tarea_id': tareaId,
      'tipo': tipo.value,
      'url': url,
      'texto': texto,
      'usuario_id': usuarioId,
    }).select().single();
    await client
        .from('tareas')
        .update({'estado': 'evidencia_subida'})
        .eq('id', tareaId);
    return Evidencia.fromJson(resp);
  }

  Future<String> subirArchivo(String bucket, String path, Uint8List bytes, {String? contentType}) async {
    await client.storage.from(bucket).uploadBinary(
      path,
      bytes,
      fileOptions: FileOptions(contentType: contentType),
    );
    return client.storage.from(bucket).getPublicUrl(path);
  }

  Future<void> aprobarEvidencia(String evidenciaId, String comentario) async {
    await client
        .from('evidencias')
        .update({'aprobado': true, 'comentario_supervisor': comentario})
        .eq('id', evidenciaId);
    await actualizarRacha(evidenciaId);
  }

  Future<void> actualizarRacha(String evidenciaId) async {
    final ev = await client
        .from('evidencias')
        .select('usuario_id, tarea_id')
        .eq('id', evidenciaId)
        .single();
    final usuarioId = ev['usuario_id'] as String;

    final tareaResp = await client
        .from('tareas')
        .select('fecha_limite')
        .eq('id', ev['tarea_id'] as String)
        .single();

    final hoy = DateTime.now();
    String? fechaLimiteStr = tareaResp['fecha_limite'] as String?;

    DateTime effectiveDate;
    if (fechaLimiteStr != null) {
      final limite = DateTime.parse(fechaLimiteStr);
      if (limite.isAfter(hoy) ||
          (limite.year == hoy.year && limite.month == hoy.month && limite.day == hoy.day)) {
        effectiveDate = limite;
      } else {
        effectiveDate = hoy;
      }
    } else {
      effectiveDate = hoy;
    }

    final effectiveStr = '${effectiveDate.year}-${effectiveDate.month.toString().padLeft(2, '0')}-${effectiveDate.day.toString().padLeft(2, '0')}';
    final user = await getUsuario(usuarioId);

    int nuevaRacha;
    if (user.ultimaCompletada == null || user.ultimaCompletada == effectiveStr) {
      nuevaRacha = user.rachaActual > 0 ? user.rachaActual : 1;
    } else {
      final lastDate = DateTime.parse(user.ultimaCompletada!);
      final diff = effectiveDate.difference(lastDate).inDays;
      if (diff == 1) {
        nuevaRacha = user.rachaActual + 1;
      } else {
        final tareasEnMedio = await client
            .from('tareas')
            .select('id')
            .eq('usuario_id', usuarioId)
            .gt('created_at', user.ultimaCompletada!)
            .lt('created_at', effectiveStr);
        if (tareasEnMedio.isNotEmpty) {
          nuevaRacha = 1;
        } else {
          nuevaRacha = user.rachaActual + 1;
        }
      }
    }
    await client.from('usuarios').update({
      'racha_actual': nuevaRacha,
      'ultima_completada': effectiveStr,
    }).eq('id', usuarioId);
  }

  Future<void> refrescarRacha(String usuarioId) async {
    final user = await getUsuario(usuarioId);
    if (user.ultimaCompletada == null) return;

    final hoy = DateTime.now();
    final ultima = DateTime.parse(user.ultimaCompletada!);

    if (ultima.isAfter(hoy)) {
      await client.from('usuarios').update({
        'ultima_completada': '${hoy.year}-${hoy.month.toString().padLeft(2, '0')}-${hoy.day.toString().padLeft(2, '0')}',
      }).eq('id', usuarioId);
      return;
    }

    final diff = hoy.difference(ultima).inDays;
    if (diff <= 1) return;

    int avanzar = 0;
    for (int i = 1; i < diff; i++) {
      final dia = DateTime(ultima.year, ultima.month, ultima.day + i);
      final diaStr = '${dia.year}-${dia.month.toString().padLeft(2, '0')}-${dia.day.toString().padLeft(2, '0')}';
      final diaFin = DateTime(dia.year, dia.month, dia.day + 1).toIso8601String();

      final tareasDelDia = await client
          .from('tareas')
          .select('estado')
          .eq('usuario_id', usuarioId)
          .gte('created_at', diaStr)
          .lt('created_at', diaFin);

      final noCompletadas = tareasDelDia.where((t) => t['estado'] != 'completada').length;
      if (noCompletadas > 0) break;
      avanzar++;
    }

    if (avanzar > 0) {
      await client.from('usuarios').update({
        'racha_actual': user.rachaActual + avanzar,
        'ultima_completada': '${hoy.year}-${hoy.month.toString().padLeft(2, '0')}-${hoy.day.toString().padLeft(2, '0')}',
      }).eq('id', usuarioId);
    }
  }

  Future<void> rechazarEvidencia(String evidenciaId, String comentario) async {
    await client
        .from('evidencias')
        .update({'aprobado': false, 'comentario_supervisor': comentario})
        .eq('id', evidenciaId);
    final ev = await client
        .from('evidencias')
        .select('tarea_id')
        .eq('id', evidenciaId)
        .single();
    await client
        .from('tareas')
        .update({'estado': 'rechazada'})
        .eq('id', ev['tarea_id']);
  }

  // ============================
  // RECOMPENSAS
  // ============================
  Future<List<Recompensa>> getRecompensas(String supervisorId, {String? usuarioId}) async {
    var query = client
        .from('recompensas')
        .select()
        .eq('supervisor_id', supervisorId)
        .eq('disponible', true);
    if (usuarioId != null) {
      query = query.or('usuario_id.is.null,usuario_id.eq.$usuarioId');
    }
    final resp = await query.order('created_at');
    return resp.map((j) => Recompensa.fromJson(j)).toList();
  }

  Future<Recompensa> crearRecompensa(Recompensa r) async {
    final resp = await client.from('recompensas').insert(r.toJson()).select().single();
    return Recompensa.fromJson(resp);
  }

  Future<void> desactivarRecompensa(String id) async {
    await client.from('recompensas').update({'disponible': false}).eq('id', id);
  }

  // ============================
  // CANJES
  // ============================
  Future<bool> canjearPuntos(String usuarioId, String recompensaId) async {
    final result = await client.rpc('canjear_puntos', params: {
      'p_usuario_id': usuarioId,
      'p_recompensa_id': recompensaId,
    });
    return result as bool;
  }

  Future<List<Canje>> getCanjesDeUsuario(String usuarioId) async {
    final resp = await client
        .from('canjes')
        .select('*, recompensas(*)')
        .eq('usuario_id', usuarioId)
        .order('created_at', ascending: false);
    return resp.map((j) => Canje.fromJson(j)).toList();
  }

  Future<List<Canje>> getCanjesDeSupervisor(String supervisorId) async {
    final recompensas = await client
        .from('recompensas')
        .select('id')
        .eq('supervisor_id', supervisorId);
    final ids = recompensas.map((r) => r['id'] as String).toList();
    if (ids.isEmpty) return [];
    final resp = await client
        .from('canjes')
        .select('*, recompensas(*)')
        .inFilter('recompensa_id', ids)
        .order('created_at', ascending: false);
    return resp.map((j) => Canje.fromJson(j)).toList();
  }
}
