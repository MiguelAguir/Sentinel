import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/recompensa.dart';
import '../models/canje.dart';
import 'auth_provider.dart';

final recompensasProvider = FutureProvider.autoDispose<List<Recompensa>>((ref) async {
  final usuario = await ref.read(currentUserProvider.future);
  if (usuario == null) return [];
  if (usuario.esSupervisor) {
    return await ref.read(supabaseServiceProvider).getRecompensas(usuario.id);
  }
  if (usuario.supervisorId == null) return [];
  return await ref.read(supabaseServiceProvider).getRecompensas(usuario.supervisorId!, usuarioId: usuario.id);
});

final canjesProvider = FutureProvider.autoDispose<List<Canje>>((ref) async {
  final usuario = await ref.read(currentUserProvider.future);
  if (usuario == null) return [];
  if (usuario.esSupervisor) {
    return await ref.read(supabaseServiceProvider).getCanjesDeSupervisor(usuario.id);
  }
  return await ref.read(supabaseServiceProvider).getCanjesDeUsuario(usuario.id);
});
