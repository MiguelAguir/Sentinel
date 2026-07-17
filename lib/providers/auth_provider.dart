import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/usuario.dart';
import '../services/supabase_service.dart';

final supabaseServiceProvider = Provider<SupabaseService>((ref) {
  return SupabaseService();
});

final authStateProvider = StreamProvider<User?>((ref) {
  return Supabase.instance.client.auth.onAuthStateChange.map((event) {
    return event.session?.user;
  });
});

final perfilesProvider = FutureProvider.autoDispose<List<Usuario>>((ref) async {
  final supabaseUser = ref.watch(authStateProvider).value;
  if (supabaseUser == null) return [];
  return await ref.read(supabaseServiceProvider).getPerfiles(supabaseUser.id);
});

class SelectedProfileNotifier extends Notifier<String?> {
  @override
  String? build() => null;

  void select(String? id) => state = id;
}

final selectedProfileIdProvider =
    NotifierProvider<SelectedProfileNotifier, String?>(SelectedProfileNotifier.new);

final currentUserProvider = FutureProvider.autoDispose<Usuario?>((ref) async {
  final selectedId = ref.watch(selectedProfileIdProvider);
  if (selectedId != null) {
    return await ref.read(supabaseServiceProvider).getUsuario(selectedId);
  }
  final perfiles = await ref.watch(perfilesProvider.future);
  if (perfiles.isEmpty) return null;
  if (perfiles.length == 1) return perfiles.first;
  return null;
});

final supervisorNameProvider = FutureProvider.autoDispose<String?>((ref) async {
  final usuario = await ref.watch(currentUserProvider.future);
  if (usuario == null || usuario.supervisorId == null) return null;
  final sup = await ref.read(supabaseServiceProvider).getUsuario(usuario.supervisorId!);
  return sup.nombre;
});
