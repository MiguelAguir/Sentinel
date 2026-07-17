import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/invitacion.dart';
import 'auth_provider.dart';

final invitacionesPendientesProvider = FutureProvider.autoDispose<List<Invitacion>>((ref) async {
  final usuario = await ref.read(currentUserProvider.future);
  if (usuario == null || usuario.esSupervisor) return [];
  return await ref.read(supabaseServiceProvider).getInvitacionesPendientes(usuario.email);
});
