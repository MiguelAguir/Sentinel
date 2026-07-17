import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants.dart';
import '../../models/tarea.dart';
import '../../models/usuario.dart';
import '../../models/evidencia.dart';
import '../../models/invitacion.dart';
import '../../providers/auth_provider.dart';
import '../../providers/usuarios_provider.dart';
import '../../providers/tareas_provider.dart';
import '../../providers/invitaciones_provider.dart';
import '../../services/supabase_service.dart';
import '../../widgets/shimmer_loading.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final usuarioAsync = ref.watch(currentUserProvider);
    if (usuarioAsync.isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (usuarioAsync.hasError) {
      return Scaffold(body: Center(child: Text('Error: ${usuarioAsync.error}')));
    }
    final usuario = usuarioAsync.value;
    if (usuario == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => context.go('/login'));
      return const Scaffold(body: Center(child: Text('Redirigiendo...')));
    }
    return usuario.esSupervisor
        ? _SupervisorDashboard(usuario: usuario)
        : _UsuarioDashboard(usuario: usuario);
  }
}

class _CambiarPerfilButton extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final perfilesAsync = ref.watch(perfilesProvider);
    return perfilesAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
      data: (perfiles) {
        if (perfiles.length < 2) return const SizedBox.shrink();
        return IconButton(
          icon: const Icon(Icons.swap_horiz),
          tooltip: 'Cambiar perfil',
          onPressed: () => _mostrarSelectorPerfil(context, ref, perfiles),
        );
      },
    );
  }
}

void _mostrarSelectorPerfil(BuildContext context, WidgetRef ref, List<Usuario> perfiles) {
  showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Cambiar perfil'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: perfiles.map((p) => ListTile(
          leading: CircleAvatar(
            backgroundColor: p.esSupervisor
                ? Theme.of(context).colorScheme.primaryContainer
                : Theme.of(context).colorScheme.secondaryContainer,
            child: Icon(
              p.esSupervisor ? Icons.shield : Icons.person,
              color: p.esSupervisor
                  ? Theme.of(context).colorScheme.primary
                  : Theme.of(context).colorScheme.secondary,
            ),
          ),
          title: Text(p.nombre),
          subtitle: Text(p.esSupervisor ? 'Supervisor' : 'Usuario'),
          onTap: () {
            ref.read(selectedProfileIdProvider.notifier).select(p.id);
            Navigator.pop(ctx);
          },
        )).toList(),
      ),
    ),
  );
}

void _mostrarDialogoInvitacion(BuildContext context) {
  final emailCtrl = TextEditingController();
  showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Invitar usuario'),
      content: TextField(
        controller: emailCtrl,
        decoration: const InputDecoration(
          labelText: 'Email del usuario',
          hintText: 'usuario@ejemplo.com',
          prefixIcon: Icon(Icons.email),
        ),
        keyboardType: TextInputType.emailAddress,
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
        FilledButton(
          onPressed: () async {
            final email = emailCtrl.text.trim();
            if (email.isEmpty || !email.contains('@')) {
              ScaffoldMessenger.of(ctx).showSnackBar(
                const SnackBar(content: Text('Ingresa un email válido')),
              );
              return;
            }
            try {
              final usuario = SupabaseService().client.auth.currentUser;
              if (usuario != null) {
                final perfiles = await SupabaseService().getPerfiles(usuario.id);
                final supervisorProfile = perfiles.where((p) => p.esSupervisor).firstOrNull;
                if (supervisorProfile == null) return;
                await SupabaseService().crearInvitacion(
                  supervisorProfile.id, supervisorProfile.nombre, email);
              }
              if (!ctx.mounted) return;
              Navigator.pop(ctx);
              if (!context.mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Invitación enviada')),
              );
            } catch (e) {
              if (!ctx.mounted) return;
              ScaffoldMessenger.of(ctx).showSnackBar(
                SnackBar(content: Text('Error: $e')),
              );
            }
          },
          child: const Text('Enviar invitación'),
        ),
      ],
    ),
  );
}

// ───── Supervisor Dashboard ─────

class _SupervisorDashboard extends ConsumerStatefulWidget {
  final Usuario usuario;
  const _SupervisorDashboard({required this.usuario});

  @override
  ConsumerState<_SupervisorDashboard> createState() => _SupervisorDashboardState();
}

class _SupervisorDashboardState extends ConsumerState<_SupervisorDashboard> {
  final _searchCtrl = TextEditingController();
  bool _tareasExpandidas = false;

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tareasAsync = ref.watch(tareasSupervisorProvider);
    final usuariosAsync = ref.watch(usuariosSupervisionProvider);
    final tareas = tareasAsync.asData?.value ?? [];
    final usuarios = usuariosAsync.asData?.value ?? [];
    final tareasPendientes = tareas.where((t) => t.estado == EstadoTarea.pendiente).length;
    final buscando = _searchCtrl.text.isNotEmpty;
    final mostrarTareas = _tareasExpandidas || buscando;

    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: cs.surface,
      appBar: AppBar(
        title: Text(widget.usuario.nombre, style: TextStyle(fontWeight: FontWeight.w600)),
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_month),
            tooltip: 'Calendario',
            onPressed: () => context.push('/calendario'),
          ),
          IconButton(
            icon: const Icon(Icons.person),
            tooltip: 'Perfil',
            onPressed: () => context.push('/perfil'),
          ),
          _CambiarPerfilButton(),
          IconButton(
            icon: const Icon(Icons.person_add_alt),
            tooltip: 'Invitar usuario',
            onPressed: () => _mostrarDialogoInvitacion(context),
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await SupabaseService().signOut();
              if (!context.mounted) return;
              context.go('/login');
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => Future.wait([
          ref.refresh(tareasSupervisorProvider.future),
          ref.refresh(usuariosSupervisionProvider.future),
        ]),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
          children: [
            _headerGradient(context, tareas.length, tareasPendientes, usuarios.length),
            const SizedBox(height: 20),
            _tasksSection(context, tareasAsync, mostrarTareas),
            const SizedBox(height: 20),
            Text('Tus usuarios', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            _usuariosWidget(context, ref, usuariosAsync),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/recompensas'),
        icon: const Icon(Icons.card_giftcard),
        label: const Text('Recompensas'),
      ),
    );
  }

  Widget _headerGradient(BuildContext context, int totalTareas, int pendientes, int totalUsuarios) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [cs.primary, cs.primary.withValues(alpha: 0.8)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('¡Bienvenido!', style: TextStyle(color: cs.onPrimary.withValues(alpha: 0.7), fontSize: 14)),
          const SizedBox(height: 4),
          Text(widget.usuario.nombre, style: TextStyle(color: cs.onPrimary, fontSize: 24, fontWeight: FontWeight.bold)),
          const SizedBox(height: 20),
          Row(
            children: [
              _statBox(context, 'Tareas', totalTareas, Icons.assignment),
              const SizedBox(width: 12),
              _statBox(context, 'Pendientes', pendientes, Icons.hourglass_empty),
              const SizedBox(width: 12),
              _statBox(context, 'Usuarios', totalUsuarios, Icons.people),
            ],
          ),
        ],
      ),
    );
  }

  Widget _statBox(BuildContext context, String label, int value, IconData icon) {
    final cs = Theme.of(context).colorScheme;
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: cs.onPrimary.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Icon(icon, color: cs.onPrimary, size: 20),
            const SizedBox(height: 4),
            Text('$value', style: TextStyle(color: cs.onPrimary, fontSize: 20, fontWeight: FontWeight.bold)),
            Text(label, style: TextStyle(color: cs.onPrimary.withValues(alpha: 0.8), fontSize: 12)),
          ],
        ),
      ),
    );
  }

  Widget _tasksSection(BuildContext context, AsyncValue<List<Tarea>> tareasAsync, bool mostrar) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: () => setState(() => _tareasExpandidas = !_tareasExpandidas),
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
            child: Row(
              children: [
                Text('Tus tareas creadas', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(_tareasExpandidas ? Icons.expand_less : Icons.expand_more, size: 20),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 4),
        TextField(
          controller: _searchCtrl,
          decoration: InputDecoration(
            hintText: 'Buscar tareas...',
            prefixIcon: const Icon(Icons.search, size: 20),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          ),
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 8),
        if (mostrar)
          _tareasSupervisorWidget(context, ref, tareasAsync, _searchCtrl.text)
        else
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Row(
              children: [
                Icon(Icons.touch_app, size: 16, color: Colors.grey[400]),
                const SizedBox(width: 6),
                Text('Toca el buscador o la sección para ver tareas', style: TextStyle(color: Colors.grey[400], fontSize: 13)),
              ],
            ),
          ),
      ],
    );
  }
}

String _estadoLabel(EstadoTarea e) {
  switch (e) {
    case EstadoTarea.pendiente: return 'Pendiente';
    case EstadoTarea.evidenciaSubida: return 'En revisión';
    case EstadoTarea.completada: return 'Completada';
    case EstadoTarea.rechazada: return 'Rechazada';
  }
}

Widget _tareasSupervisorWidget(BuildContext context, WidgetRef ref, AsyncValue<List<Tarea>> tareasAsync, String query) {
  return tareasAsync.when(
    loading: () => const ShimmerTaskList(count: 4),
    error: (e, _) => Text('Error: $e'),
    data: (tareas) {
      final filtradas = query.isEmpty
          ? tareas
          : tareas.where((t) =>
              t.titulo.toLowerCase().contains(query.toLowerCase()) ||
              _estadoLabel(t.estado).toLowerCase().contains(query.toLowerCase())).toList();
      if (filtradas.isEmpty) {
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.search_off, size: 40, color: Colors.grey[300]),
                  const SizedBox(height: 8),
                  Text(query.isEmpty ? 'No hay tareas aún' : 'Sin resultados', style: TextStyle(color: Colors.grey[500])),
                ],
              ),
            ),
          ),
        );
      }
      return Column(
        children: filtradas.map((t) {
          final color = _colorEstado(t.estado);
          return Card(
            margin: const EdgeInsets.only(bottom: 10),
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () => context.push('/tareas/${t.id}'),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Container(
                      width: 44, height: 44,
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(_iconoEstado(t.estado), color: color, size: 22),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(t.titulo, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: color.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(_estadoLabel(t.estado), style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600)),
                              ),
                              const SizedBox(width: 8),
                              Icon(Icons.monetization_on, size: 12, color: Colors.grey[500]),
                              const SizedBox(width: 2),
                              Text('${t.puntos} pts', style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.chevron_right, size: 20, color: Colors.grey),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      );
    },
  );
}

Widget _usuariosWidget(BuildContext context, WidgetRef ref, AsyncValue<List<Usuario>> usuariosAsync) {
  return usuariosAsync.when(
    loading: () => const Padding(padding: EdgeInsets.all(16), child: CircularProgressIndicator()),
    error: (e, _) => Text('Error: $e'),
    data: (usuarios) {
      if (usuarios.isEmpty) {
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.people_outline, size: 48, color: Colors.grey[300]),
                  const SizedBox(height: 8),
                  Text('No hay usuarios', style: TextStyle(color: Colors.grey[500])),
                ],
              ),
            ),
          ),
        );
      }
      return Column(
        children: usuarios.map((u) => _UsuarioExpandible(usuario: u)).toList(),
      );
    },
  );
}

class _UsuarioExpandible extends ConsumerStatefulWidget {
  final Usuario usuario;
  const _UsuarioExpandible({required this.usuario});

  @override
  ConsumerState<_UsuarioExpandible> createState() => _UsuarioExpandibleState();
}

class _UsuarioExpandibleState extends ConsumerState<_UsuarioExpandible> {
  bool _expandido = false;
  bool _maxAlcanzado = false;

  @override
  void initState() {
    super.initState();
    _checkMax();
  }

  Future<void> _checkMax() async {
    final usuarios = await ref.read(usuariosSupervisionProvider.future);
    if (mounted) setState(() => _maxAlcanzado = usuarios.length >= 2);
  }

  @override
  Widget build(BuildContext context) {
    final tareasAsync = ref.watch(tareasDeUsuarioProvider(widget.usuario.id));
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Column(
        children: [
          ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            leading: CircleAvatar(
              backgroundColor: Theme.of(context).colorScheme.secondaryContainer,
              child: Text(
                widget.usuario.nombre[0].toUpperCase(),
                style: TextStyle(color: Theme.of(context).colorScheme.onSecondaryContainer, fontWeight: FontWeight.w600),
              ),
            ),
            title: Text(widget.usuario.nombre, style: const TextStyle(fontWeight: FontWeight.w600)),
            subtitle: Text('${widget.usuario.email} • ${widget.usuario.puntos} pts', style: TextStyle(color: Colors.grey[600], fontSize: 13)),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (!_maxAlcanzado)
                  IconButton(
                    icon: Icon(Icons.add_task, color: Theme.of(context).colorScheme.primary),
                    tooltip: 'Crear tarea',
                    onPressed: () => context.push('/tareas/crear', extra: widget.usuario.id),
                  ),
                AnimatedRotation(
                  turns: _expandido ? 0.5 : 0,
                  duration: const Duration(milliseconds: 200),
                  child: Icon(Icons.expand_more, color: Colors.grey[600]),
                ),
              ],
            ),
            onTap: () => setState(() => _expandido = !_expandido),
          ),
          AnimatedCrossFade(
            firstChild: const SizedBox(),
            secondChild: _buildTareasList(tareasAsync),
            crossFadeState: _expandido ? CrossFadeState.showSecond : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 200),
          ),
        ],
      ),
    );
  }

  Widget _buildTareasList(AsyncValue<List<Tarea>> tareasAsync) {
    return tareasAsync.when(
      loading: () => const Padding(
        padding: EdgeInsets.all(16),
        child: Center(child: SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2))),
      ),
      error: (e, _) => Padding(
        padding: const EdgeInsets.all(16),
        child: Text('Error: $e', style: TextStyle(color: Theme.of(context).colorScheme.error)),
      ),
      data: (tareas) {
        if (tareas.isEmpty) {
          return const Padding(
            padding: EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Text('Sin tareas asignadas', style: TextStyle(color: Colors.grey)),
          );
        }
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: Column(
            children: tareas.map((t) => ListTile(
              dense: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
              leading: Icon(_iconoEstado(t.estado), color: _colorEstado(t.estado), size: 20),
              title: Text(t.titulo, style: const TextStyle(fontSize: 14)),
              subtitle: Text('${t.estado.value} • ${t.puntos} pts', style: TextStyle(fontSize: 12, color: Colors.grey[500])),
              onTap: () => context.push('/tareas/${t.id}'),
            )).toList(),
          ),
        );
      },
    );
  }
}

IconData _iconoEstado(EstadoTarea estado) {
  switch (estado) {
    case EstadoTarea.completada: return Icons.check_circle;
    case EstadoTarea.rechazada: return Icons.cancel;
    default: return Icons.pending;
  }
}

Color _colorEstado(EstadoTarea estado) {
  switch (estado) {
    case EstadoTarea.completada: return Colors.green;
    case EstadoTarea.rechazada: return Colors.red;
    default: return Colors.orange;
  }
}

// ───── User Dashboard ─────

class _UsuarioDashboard extends ConsumerStatefulWidget {
  final Usuario usuario;
  const _UsuarioDashboard({required this.usuario});

  @override
  ConsumerState<_UsuarioDashboard> createState() => _UsuarioDashboardState();
}

class _UsuarioDashboardState extends ConsumerState<_UsuarioDashboard> {
  @override
  void initState() {
    super.initState();
    _refrescarStreak();
  }

  Future<void> _refrescarStreak() async {
    final supabase = SupabaseService();
    try {
      await supabase.refrescarRacha(widget.usuario.id);
      if (mounted) ref.invalidate(currentUserProvider);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final tareasAsync = ref.watch(tareasUsuarioProvider);
    final invitacionesAsync = ref.watch(invitacionesPendientesProvider);

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        title: Text(widget.usuario.nombre, style: TextStyle(fontWeight: FontWeight.w600)),
        actions: [
          Text('${widget.usuario.puntos} pts', style: TextStyle(
            color: Theme.of(context).colorScheme.primary,
            fontWeight: FontWeight.w600,
          )),
          const SizedBox(width: 4),
          IconButton(
            icon: const Icon(Icons.calendar_month),
            tooltip: 'Calendario',
            onPressed: () => context.push('/calendario'),
          ),
          IconButton(
            icon: const Icon(Icons.person),
            tooltip: 'Perfil',
            onPressed: () => context.push('/perfil'),
          ),
          _CambiarPerfilButton(),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await SupabaseService().signOut();
              if (!context.mounted) return;
              context.go('/login');
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(tareasUsuarioProvider);
          ref.invalidate(invitacionesPendientesProvider);
          await ref.read(tareasUsuarioProvider.future);
        },
        child: _buildCuerpo(context, tareasAsync, invitacionesAsync),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push('/recompensas'),
        child: const Icon(Icons.card_giftcard),
      ),
    );
  }

  Widget _buildCuerpo(BuildContext context, AsyncValue<List<Tarea>> tareasAsync, AsyncValue<List<Invitacion>> invitacionesAsync) {
    final cs = Theme.of(context).colorScheme;
    final children = <Widget>[];

    // Header gradient card
    children.add(
      Container(
        margin: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [cs.secondary, cs.secondary.withValues(alpha: 0.8)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
        ),
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            CircleAvatar(
              radius: 28,
              backgroundColor: cs.onSecondary.withValues(alpha: 0.2),
              child: Text(
                widget.usuario.nombre[0].toUpperCase(),
                style: TextStyle(color: cs.onSecondary, fontSize: 24, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(widget.usuario.nombre, style: TextStyle(color: cs.onSecondary, fontSize: 20, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text('${widget.usuario.puntos} puntos', style: TextStyle(color: cs.onSecondary.withValues(alpha: 0.8), fontSize: 14)),
                ],
              ),
            ),
            if (widget.usuario.rachaActual > 0)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: cs.onSecondary.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.local_fire_department, color: Colors.white, size: 18),
                    const SizedBox(width: 4),
                    Text('${widget.usuario.rachaActual}', style: TextStyle(color: cs.onSecondary, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
          ],
        ),
      ),
    );

    // Streak card (when 0)
    if (widget.usuario.rachaActual == 0) {
      children.add(
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: _streakZeroCard(context),
        ),
      );
    }

    // Invitations
    if (invitacionesAsync.hasValue) {
      for (final inv in invitacionesAsync.value!) {
        children.add(Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: _InvitacionCard(invitacion: inv),
        ));
      }
    }

    // Section title
    children.add(
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
        child: Text('Tus tareas', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
      ),
    );

    // Task list
    tareasAsync.when(
      loading: () => children.add(const Padding(
        padding: EdgeInsets.symmetric(horizontal: 16),
        child: ShimmerTaskList(count: 4),
      )),
      error: (e, _) => children.add(Center(child: Text('Error: $e'))),
      data: (tareas) {
        if (tareas.isEmpty) {
          children.add(
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(40),
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.task_alt, size: 48, color: Colors.grey[300]),
                        const SizedBox(height: 12),
                        Text('No tienes tareas asignadas', style: TextStyle(color: Colors.grey[500])),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
        } else {
          children.addAll(tareas.map((t) => Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: _TareaUsuarioCard(tarea: t),
          )));
        }
      },
    );

    return ListView(
      padding: const EdgeInsets.only(bottom: 100),
      children: children,
    );
  }

  Widget _streakZeroCard(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(Icons.local_fire_department, color: Colors.grey[400], size: 24),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Sin racha aún', style: TextStyle(fontWeight: FontWeight.w600, color: Colors.grey[600])),
                  const SizedBox(height: 2),
                  Text('Completa tareas para iniciar tu racha', style: TextStyle(color: Colors.grey[400], fontSize: 13)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InvitacionCard extends ConsumerWidget {
  final Invitacion invitacion;
  const _InvitacionCard({required this.invitacion});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: cs.primaryContainer,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(Icons.person_add, color: cs.primary, size: 24),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Invitación', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                  const SizedBox(height: 2),
                  Text('${invitacion.supervisorNombre} quiere que seas su usuario', style: TextStyle(color: Colors.grey[600], fontSize: 13)),
                ],
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              icon: Icon(Icons.check_circle, color: cs.secondary),
              tooltip: 'Aceptar',
              onPressed: () async {
                try {
                  final usuario = await ref.read(currentUserProvider.future);
                  if (usuario == null) return;
                  await SupabaseService().aceptarInvitacion(invitacion.id, usuario.id);
                  ref.invalidate(invitacionesPendientesProvider);
                  ref.invalidate(currentUserProvider);
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Supervisor vinculado')),
                  );
                } catch (e) {
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error: $e')),
                  );
                }
              },
            ),
            IconButton(
              icon: Icon(Icons.cancel, color: cs.error),
              tooltip: 'Rechazar',
              onPressed: () async {
                try {
                  await SupabaseService().rechazarInvitacion(invitacion.id);
                  ref.invalidate(invitacionesPendientesProvider);
                } catch (e) {
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error: $e')),
                  );
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _TareaUsuarioCard extends ConsumerStatefulWidget {
  final Tarea tarea;
  const _TareaUsuarioCard({required this.tarea});

  @override
  ConsumerState<_TareaUsuarioCard> createState() => _TareaUsuarioCardState();
}

class _TareaUsuarioCardState extends ConsumerState<_TareaUsuarioCard> {
  static const _motivaciones = [
    '¡Excelente trabajo! Sigue así.',
    '¡Vas por muy buen camino!',
    '¡Felicidades, sigue esforzándote!',
    '¡Buen trabajo! Cada paso cuenta.',
    '¡Impresionante! No te detengas.',
    '¡Genial! Sigue dando lo mejor de ti.',
  ];

  bool _expandido = false;
  String? _comentarioSupervisor;
  List<Evidencia> _evidencias = [];
  bool _cargandoDetalles = true;

  @override
  void initState() {
    super.initState();
    _cargarDetalles();
  }

  Future<void> _cargarDetalles() async {
    final estado = widget.tarea.estado;
    if (estado == EstadoTarea.completada || estado == EstadoTarea.rechazada || estado == EstadoTarea.evidenciaSubida) {
      try {
        final service = SupabaseService();
        final evidencias = await service.getEvidenciasDeTarea(widget.tarea.id);
        _evidencias = evidencias;
        final aprobada = evidencias.where((e) => e.aprobado == true);
        if (aprobada.isNotEmpty) {
          _comentarioSupervisor = aprobada.first.comentarioSupervisor;
        } else if (estado == EstadoTarea.rechazada) {
          final rechazada = evidencias.where((e) => e.aprobado == false);
          if (rechazada.isNotEmpty) {
            _comentarioSupervisor = rechazada.first.comentarioSupervisor;
          }
        }
      } catch (_) {}
    }
    if (mounted) setState(() => _cargandoDetalles = false);
  }

  void _mostrarRevision(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.schedule, color: Theme.of(context).colorScheme.primary),
            const SizedBox(width: 8),
            const Text('En revisión'),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(widget.tarea.titulo, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 8),
              Text('Puntos: ${widget.tarea.puntos}'),
              if (widget.tarea.descripcion != null) Text('Descripción: ${widget.tarea.descripcion}'),
              const SizedBox(height: 16),
              const Text('Tu evidencia ha sido recibida y está siendo revisada por el supervisor.'),
              const SizedBox(height: 8),
              const Text('Recibirás una notificación cuando sea aprobada o rechazada.'),
              if (_evidencias.isNotEmpty) ...[
                const SizedBox(height: 16),
                const Text('Lo que enviaste:', style: TextStyle(fontWeight: FontWeight.w600)),
                ..._evidencias.map((e) => Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Row(
                    children: [
                      Icon(e.aprobado == null ? Icons.hourglass_empty : Icons.check, size: 16, color: Colors.grey),
                      const SizedBox(width: 6),
                      Expanded(child: Text(e.texto ?? e.tipo.value)),
                    ],
                  ),
                )),
              ],
            ],
          ),
        ),
        actions: [
          FilledButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cerrar')),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.tarea;
    final estado = t.estado;
    final motivacion = _motivaciones[t.hashCode.abs() % _motivaciones.length];
    final expandible = estado == EstadoTarea.rechazada || estado == EstadoTarea.completada;
    final cs = Theme.of(context).colorScheme;

    Color statusColor;
    IconData statusIcon;
    String statusText;
    switch (estado) {
      case EstadoTarea.pendiente:
        statusColor = Colors.orange; statusIcon = Icons.hourglass_empty; statusText = 'Pendiente';
      case EstadoTarea.evidenciaSubida:
        statusColor = cs.primary; statusIcon = Icons.schedule; statusText = 'En revisión';
      case EstadoTarea.rechazada:
        statusColor = cs.error; statusIcon = Icons.refresh; statusText = 'Rechazada';
      case EstadoTarea.completada:
        statusColor = Colors.green; statusIcon = Icons.check_circle; statusText = 'Completada';
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Column(
        children: [
          ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            leading: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(statusIcon, color: statusColor, size: 22),
            ),
            title: Text(t.titulo, style: const TextStyle(fontWeight: FontWeight.w600)),
            subtitle: Text(statusText, style: TextStyle(color: statusColor, fontWeight: FontWeight.w500, fontSize: 13)),
            trailing: estado == EstadoTarea.completada
                ? Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.green.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text('+${t.puntos} pts', style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 13)),
                  )
                : estado == EstadoTarea.pendiente
                    ? Text('${t.puntos} pts', style: TextStyle(color: Colors.grey[500], fontWeight: FontWeight.w500))
                    : AnimatedRotation(
                        turns: (_expandido && expandible) ? 0.5 : 0,
                        duration: const Duration(milliseconds: 200),
                        child: Icon(Icons.expand_more, color: Colors.grey[400]),
                      ),
            onTap: () {
              if (estado == EstadoTarea.pendiente) {
                context.push('/evidencias/subir/${t.id}');
              } else if (estado == EstadoTarea.evidenciaSubida) {
                _mostrarRevision(context);
              } else if (expandible) {
                setState(() => _expandido = !_expandido);
              }
            },
          ),
          AnimatedCrossFade(
            firstChild: const SizedBox(),
            secondChild: _buildDetallesExpandidos(context, t, motivacion),
            crossFadeState: (expandible && _expandido) ? CrossFadeState.showSecond : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 200),
          ),
        ],
      ),
    );
  }

  Widget _buildDetallesExpandidos(BuildContext context, Tarea t, String motivacion) {
    final cs = Theme.of(context).colorScheme;
    if (_cargandoDetalles) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: Center(child: SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2))),
      );
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Divider(),
          if (t.descripcion != null) ...[
            Text('Descripción', style: TextStyle(fontWeight: FontWeight.w600, color: Colors.grey[700], fontSize: 13)),
            const SizedBox(height: 4),
            Text(t.descripcion!, style: TextStyle(color: Colors.grey[600])),
            const SizedBox(height: 8),
          ],
          if (t.estado == EstadoTarea.rechazada) ...[
            if (_comentarioSupervisor != null) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: cs.errorContainer.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.chat, size: 16, color: cs.error),
                    const SizedBox(width: 8),
                    Expanded(child: Text(_comentarioSupervisor!, style: TextStyle(color: cs.onErrorContainer))),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],
            FilledButton.icon(
              onPressed: () => context.push('/evidencias/subir/${t.id}'),
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('Reenviar evidencia'),
            ),
          ],
          if (t.estado == EstadoTarea.completada) ...[
            if (_comentarioSupervisor != null) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: cs.primaryContainer.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.chat, size: 16, color: cs.primary),
                    const SizedBox(width: 8),
                    Expanded(child: Text(_comentarioSupervisor!, style: TextStyle(color: cs.onPrimaryContainer))),
                  ],
                ),
              ),
              const SizedBox(height: 8),
            ],
            Row(
              children: [
                Icon(Icons.emoji_events, size: 18, color: Colors.amber[700]),
                const SizedBox(width: 6),
                Expanded(child: Text(motivacion, style: TextStyle(color: Colors.amber[700], fontWeight: FontWeight.w500))),
              ],
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.green.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text('+${t.puntos} pts', style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 15)),
            ),
          ],
        ],
      ),
    );
  }
}
