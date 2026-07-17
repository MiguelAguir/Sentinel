import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/usuario.dart';
import 'auth_provider.dart';

final usuariosSupervisionProvider = FutureProvider.autoDispose<List<Usuario>>((ref) async {
  final usuario = await ref.read(currentUserProvider.future);
  if (usuario == null || !usuario.esSupervisor) return [];
  return await ref.read(supabaseServiceProvider).getUsuariosDeSupervisor(usuario.id);
});
