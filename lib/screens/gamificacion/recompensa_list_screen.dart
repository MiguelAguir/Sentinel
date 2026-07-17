import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../models/recompensa.dart';
import '../../models/canje.dart';
import '../../models/usuario.dart';
import '../../providers/auth_provider.dart';
import '../../providers/puntos_provider.dart';
import '../../providers/usuarios_provider.dart';
import '../../services/supabase_service.dart';

class RecompensaListScreen extends ConsumerStatefulWidget {
  const RecompensaListScreen({super.key});
  @override
  ConsumerState<RecompensaListScreen> createState() => _RecompensaListScreenState();
}

class _RecompensaListScreenState extends ConsumerState<RecompensaListScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final usuario = ref.watch(currentUserProvider).value;
    final recompensasAsync = ref.watch(recompensasProvider);
    final canjesAsync = ref.watch(canjesProvider);
    final usuariosAsync = ref.watch(usuariosSupervisionProvider);

    if (recompensasAsync.isLoading && canjesAsync.isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final recompensas = recompensasAsync.value ?? [];
    final canjes = canjesAsync.value ?? [];
    final esSupervisor = usuario?.esSupervisor == true;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Recompensas'),
        actions: esSupervisor
            ? [
                IconButton(
                  icon: const Icon(Icons.add),
                  onPressed: () => context.push('/recompensas/crear'),
                ),
              ]
            : null,
        bottom: esSupervisor
            ? null
            : TabBar(
                controller: _tabCtrl,
                tabs: const [
                  Tab(text: 'Canjear'),
                  Tab(text: 'Canjeados'),
                ],
              ),
      ),
      body: esSupervisor
          ? _listaSupervisor(recompensas, usuariosAsync.value ?? [])
          : TabBarView(
              controller: _tabCtrl,
              children: [
                _listaCanjear(recompensas, canjes),
                _listaCanjeados(canjes),
              ],
            ),
    );
  }

  Widget _listaSupervisor(List<Recompensa> recompensas, List<Usuario> usuarios) {
    if (recompensas.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.card_giftcard, size: 56, color: Colors.grey[300]),
            const SizedBox(height: 12),
            Text('No hay recompensas', style: TextStyle(color: Colors.grey[500])),
          ],
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: recompensas.length,
      itemBuilder: (_, i) {
        final r = recompensas[i];
        final usuarioAsignado = r.usuarioId != null
            ? usuarios.where((u) => u.id == r.usuarioId).firstOrNull
            : null;
        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            leading: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(Icons.card_giftcard, color: Theme.of(context).colorScheme.primary, size: 22),
            ),
            title: Text(r.nombre, style: const TextStyle(fontWeight: FontWeight.w600)),
            subtitle: Text(
              '${r.descripcion ?? ''} • ${r.costoPuntos} pts'
              '${usuarioAsignado != null ? '\nPara: ${usuarioAsignado.nombre}' : ''}',
            ),
            trailing: IconButton(
              onPressed: () => SupabaseService().desactivarRecompensa(r.id).then((_) {
                ref.invalidate(recompensasProvider);
              }),
              icon: Icon(Icons.delete_outline, color: Theme.of(context).colorScheme.error),
            ),
          ),
        );
      },
    );
  }

  Widget _listaCanjear(List<Recompensa> recompensas, List<Canje> canjes) {
    final idsCanjeados = canjes.map((c) => c.recompensaId).toSet();
    final disponibles = recompensas.where((r) => !idsCanjeados.contains(r.id)).toList();
    if (disponibles.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.check_circle, size: 56, color: Colors.green[200]),
            const SizedBox(height: 12),
            Text('No hay recompensas disponibles', style: TextStyle(color: Colors.grey[500])),
          ],
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: disponibles.length,
      itemBuilder: (_, i) {
        final r = disponibles[i];
        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            leading: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.amber[50],
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(Icons.card_giftcard, color: Colors.amber[700], size: 22),
            ),
            title: Text(r.nombre, style: const TextStyle(fontWeight: FontWeight.w600)),
            subtitle: Text('${r.descripcion ?? ''} • ${r.costoPuntos} pts'),
            trailing: FilledButton(
              onPressed: () => _canjear(r.id),
              child: const Text('Canjear'),
            ),
          ),
        );
      },
    );
  }

  Widget _listaCanjeados(List<Canje> canjes) {
    if (canjes.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.history, size: 56, color: Colors.grey[300]),
            const SizedBox(height: 12),
            Text('Aún no has canjeado nada', style: TextStyle(color: Colors.grey[500])),
          ],
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: canjes.length,
      itemBuilder: (_, i) {
        final c = canjes[i];
        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            leading: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.green[50],
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.check_circle, color: Colors.green, size: 22),
            ),
            title: Text(c.recompensaNombre ?? 'Recompensa', style: const TextStyle(fontWeight: FontWeight.w600)),
            subtitle: Text('${c.recompensaCosto ?? '?'} pts • ${c.createdAt.toString().substring(0, 10)}'),
          ),
        );
      },
    );
  }

  Future<void> _canjear(String recompensaId) async {
    HapticFeedback.lightImpact();
    final usuario = await ref.read(currentUserProvider.future);
    if (usuario == null) return;
    final ok = await SupabaseService().canjearPuntos(usuario.id, recompensaId);
    ref.invalidate(recompensasProvider);
    ref.invalidate(canjesProvider);
    ref.invalidate(currentUserProvider);
    ref.invalidate(usuariosSupervisionProvider);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(ok ? 'Recompensa canjeada' : 'No tienes suficientes puntos')),
    );
  }
}
