import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/tarea.dart';
import 'auth_provider.dart';

final tareasUsuarioProvider = FutureProvider.autoDispose<List<Tarea>>((ref) async {
  final usuario = await ref.read(currentUserProvider.future);
  if (usuario == null) return [];
  return await ref.read(supabaseServiceProvider).getTareasDeUsuario(usuario.id);
});

final tareasSupervisorProvider = FutureProvider.autoDispose<List<Tarea>>((ref) async {
  final usuario = await ref.read(currentUserProvider.future);
  if (usuario == null) return [];
  return await ref.read(supabaseServiceProvider).getTareasDeSupervisor(usuario.id);
});

final tareasDeUsuarioProvider = FutureProvider.autoDispose.family<List<Tarea>, String>((ref, userId) async {
  return await ref.read(supabaseServiceProvider).getTareasDeUsuario(userId);
});
