import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/auth_provider.dart';
import '../../providers/puntos_provider.dart';

class CanjeScreen extends ConsumerWidget {
  const CanjeScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final canjesAsync = ref.watch(canjesProvider);
    final usuario = ref.watch(currentUserProvider).value;
    if (canjesAsync.isLoading) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    if (canjesAsync.hasError) return Scaffold(body: Center(child: Text('${canjesAsync.error}')));
    final canjes = canjesAsync.value ?? [];
    return Scaffold(
      appBar: AppBar(title: const Text('Canjes')),
      body: canjes.isEmpty
          ? const Center(child: Text('No hay canjes aún'))
          : ListView.builder(
              itemCount: canjes.length,
              itemBuilder: (_, i) {
                final c = canjes[i];
                return ListTile(
                  title: Text(c.recompensaNombre ?? 'Recompensa'),
                  subtitle: Text('${c.recompensaCosto ?? '?'} pts - ${c.createdAt.toString().substring(0, 10)}'),
                  trailing: usuario?.esSupervisor == true ? Text(c.usuarioId.substring(0, 8)) : null,
                );
              },
            ),
    );
  }
}
