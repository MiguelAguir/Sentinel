import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../providers/auth_provider.dart';
import '../../providers/theme_provider.dart';

class PerfilScreen extends ConsumerWidget {
  const PerfilScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final usuarioAsync = ref.watch(currentUserProvider);
    final perfilesAsync = ref.watch(perfilesProvider);
    final themeMode = ref.watch(themeModeProvider);
    final supervisorNameAsync = ref.watch(supervisorNameProvider);
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Perfil')),
      body: usuarioAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (usuario) {
          if (usuario == null) return const Center(child: Text('No hay sesión'));
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Avatar + name section
              Center(
                child: Column(
                  children: [
                    CircleAvatar(
                      radius: 44,
                      backgroundColor: usuario.esSupervisor
                          ? cs.primaryContainer
                          : cs.secondaryContainer,
                      child: Text(
                        usuario.nombre[0].toUpperCase(),
                        style: TextStyle(
                          fontSize: 36,
                          fontWeight: FontWeight.bold,
                          color: usuario.esSupervisor
                              ? cs.primary
                              : cs.secondary,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(usuario.nombre, style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: cs.onSurface)),
                    const SizedBox(height: 4),
                    Text(usuario.email, style: TextStyle(color: cs.onSurfaceVariant)),
                    const SizedBox(height: 8),
                    Chip(
                      avatar: Icon(
                        usuario.esSupervisor ? Icons.shield : Icons.person,
                        size: 16,
                        color: usuario.esSupervisor ? cs.primary : cs.secondary,
                      ),
                      label: Text(usuario.esSupervisor ? 'Supervisor' : 'Usuario'),
                      backgroundColor: usuario.esSupervisor
                          ? cs.primaryContainer
                          : cs.secondaryContainer,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Stats card
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          children: [
                            Icon(Icons.monetization_on, color: Colors.amber[700], size: 28),
                            const SizedBox(height: 4),
                            Text('${usuario.puntos}', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: cs.onSurface)),
                            Text('Puntos', style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12)),
                          ],
                        ),
                      ),
                      Container(width: 1, height: 40, color: cs.outlineVariant),
                      Expanded(
                        child: Column(
                          children: [
                            Icon(
                              usuario.rachaActual > 0 ? Icons.local_fire_department : Icons.local_fire_department,
                              color: usuario.rachaActual > 0 ? Colors.orange : Colors.grey[400],
                              size: 28,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${usuario.rachaActual}',
                              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: cs.onSurface),
                            ),
                            Text('Racha (días)', style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12)),
                          ],
                        ),
                      ),
                      if (usuario.supervisorId != null) ...[
                        Container(width: 1, height: 40, color: cs.outlineVariant),
                        Expanded(
                          child: Column(
                            children: [
                              Icon(Icons.supervisor_account, color: cs.primary, size: 28),
                              const SizedBox(height: 4),
                              supervisorNameAsync.when(
                                loading: () => const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
                                error: (_, _) => const Text('--', style: TextStyle(fontSize: 14)),
                                data: (nombre) => Text(
                                  nombre ?? '--',
                                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: cs.onSurface),
                                  textAlign: TextAlign.center,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              Text('Supervisor', style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12)),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Settings card
              Card(
                child: Column(
                  children: [
                    SwitchListTile(
                      secondary: Icon(Icons.dark_mode, color: cs.onSurfaceVariant),
                      title: const Text('Modo oscuro'),
                      value: themeMode == ThemeMode.dark,
                      onChanged: (_) => ref.read(themeModeProvider.notifier).toggle(),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Profile switcher
              perfilesAsync.when(
                loading: () => const SizedBox.shrink(),
                error: (_, _) => const SizedBox.shrink(),
                data: (perfiles) {
                  if (perfiles.length < 2) return const SizedBox.shrink();
                  return Card(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                          child: Text('Tus perfiles', style: TextStyle(fontWeight: FontWeight.w600, color: cs.onSurfaceVariant)),
                        ),
                        ...perfiles.map((p) => ListTile(
                          leading: CircleAvatar(
                            radius: 16,
                            backgroundColor: p.esSupervisor ? cs.primaryContainer : cs.secondaryContainer,
                            child: Icon(
                              p.esSupervisor ? Icons.shield : Icons.person,
                              size: 16,
                              color: p.esSupervisor ? cs.primary : cs.secondary,
                            ),
                          ),
                          title: Text(p.nombre),
                          subtitle: Text(p.esSupervisor ? 'Supervisor' : 'Usuario'),
                          trailing: p.id == usuario.id
                              ? Icon(Icons.check_circle, color: cs.secondary, size: 20)
                              : IconButton(
                                  icon: const Icon(Icons.swap_horiz),
                                  onPressed: () {
                                    ref.read(selectedProfileIdProvider.notifier).select(p.id);
                                    context.go('/dashboard');
                                  },
                                ),
                        )),
                      ],
                    ),
                  );
                },
              ),
            ],
          );
        },
      ),
    );
  }
}
