import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/constants.dart';
import '../../models/tarea.dart';
import '../../models/evidencia.dart';
import '../../models/usuario.dart';
import '../../providers/auth_provider.dart';
import '../../providers/tareas_provider.dart';
import '../../providers/usuarios_provider.dart';
import '../../services/supabase_service.dart';

class TareaDetailScreen extends ConsumerStatefulWidget {
  final String tareaId;
  const TareaDetailScreen({super.key, required this.tareaId});
  @override
  ConsumerState<TareaDetailScreen> createState() => _TareaDetailScreenState();
}

class _TareaDetailScreenState extends ConsumerState<TareaDetailScreen> {
  Tarea? _tarea;
  List<Evidencia> _evidencias = [];
  Usuario? _usuario;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final service = SupabaseService();
    try {
      final tareaResp = await service.client.from('tareas').select().eq('id', widget.tareaId).single();
      _tarea = Tarea.fromJson(tareaResp);
      _evidencias = await service.getEvidenciasDeTarea(widget.tareaId);
      _usuario = await service.getUsuario(_tarea!.usuarioId);
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _eliminar() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar tarea'),
        content: const Text('¿Estás seguro? Esta acción no se puede deshacer.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.error),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      await SupabaseService().eliminarTarea(widget.tareaId);
      ref.invalidate(tareasSupervisorProvider);
      ref.invalidate(tareasUsuarioProvider);
      if (_tarea != null) ref.invalidate(tareasDeUsuarioProvider(_tarea!.usuarioId));
      ref.invalidate(currentUserProvider);
      ref.invalidate(usuariosSupervisionProvider);
      if (mounted) context.pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    if (_loading) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    if (_tarea == null) return const Scaffold(body: Center(child: Text('No encontrada')));
    final perfilActual = ref.watch(currentUserProvider).value;
    final soySupervisorDeTarea = perfilActual != null && perfilActual.id == _tarea!.supervisorId;
    final tareaCompletada = _tarea!.estado.value == 'completada';

    Color estadoColor;
    IconData estadoIcon;
    switch (_tarea!.estado) {
      case EstadoTarea.completada: estadoColor = Colors.green; estadoIcon = Icons.check_circle;
      case EstadoTarea.rechazada: estadoColor = cs.error; estadoIcon = Icons.cancel;
      case EstadoTarea.evidenciaSubida: estadoColor = cs.primary; estadoIcon = Icons.schedule;
      default: estadoColor = Colors.orange; estadoIcon = Icons.hourglass_empty;
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(_tarea!.titulo),
        actions: soySupervisorDeTarea && !tareaCompletada
            ? [
                IconButton(
                  icon: const Icon(Icons.edit),
                  onPressed: () => context.push('/tareas/${_tarea!.id}/editar', extra: _tarea),
                ),
                IconButton(
                  icon: Icon(Icons.delete, color: cs.error),
                  onPressed: _eliminar,
                ),
              ]
            : null,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: estadoColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(estadoIcon, color: estadoColor, size: 24),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(_tarea!.titulo, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: cs.onSurface)),
                            const SizedBox(height: 4),
                            Text(_tarea!.estado.value, style: TextStyle(color: estadoColor, fontWeight: FontWeight.w500)),
                          ],
                        ),
                      ),
                    ],
                  ),
                  if (_tarea!.descripcion != null) ...[
                    const Divider(),
                    Text('Descripción', style: TextStyle(fontWeight: FontWeight.w600, color: cs.onSurfaceVariant)),
                    const SizedBox(height: 4),
                    Text(_tarea!.descripcion!, style: TextStyle(color: cs.onSurface)),
                  ],
                  const Divider(),
                  Row(
                    children: [
                      _infoChip(cs, Icons.monetization_on, '${_tarea!.puntos} pts', Colors.amber[700]!),
                      const SizedBox(width: 12),
                      if (_usuario != null)
                        _infoChip(cs, Icons.person, _usuario!.nombre, cs.secondary),
                      if (_tarea!.fechaLimite != null) ...[
                        const SizedBox(width: 12),
                        _infoChip(cs, Icons.calendar_today,
                          '${_tarea!.fechaLimite!.day}/${_tarea!.fechaLimite!.month}/${_tarea!.fechaLimite!.year}',
                          cs.primary),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text('Evidencias', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: cs.onSurface)),
          const SizedBox(height: 8),
          if (_evidencias.isEmpty)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Center(
                  child: Column(
                    children: [
                      Icon(Icons.folder_open, size: 40, color: Colors.grey[300]),
                      const SizedBox(height: 8),
                      Text('Sin evidencias aún', style: TextStyle(color: Colors.grey[500])),
                    ],
                  ),
                ),
              ),
            )
          else
            ..._evidencias.map((e) => Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: cs.primaryContainer,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        e.tipo == TipoEvidencia.texto ? Icons.text_fields :
                        e.tipo == TipoEvidencia.foto ? Icons.image : Icons.description,
                        color: cs.primary, size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(e.tipo.value, style: const TextStyle(fontWeight: FontWeight.w500)),
                          if (e.url != null)
                            TextButton.icon(
                              onPressed: () => launchUrl(Uri.parse(e.url!)),
                              icon: const Icon(Icons.open_in_new, size: 14),
                              label: const Text('Ver archivo'),
                              style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: Size.zero, tapTargetSize: MaterialTapTargetSize.shrinkWrap),
                            )
                          else if (e.texto != null)
                            Text(e.texto!, style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13)),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    e.aprobado == null && soySupervisorDeTarea
                        ? Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: Icon(Icons.check_circle, color: cs.secondary),
                                onPressed: () => _aprobar(e.id),
                              ),
                              IconButton(
                                icon: Icon(Icons.cancel, color: cs.error),
                                onPressed: () => _rechazar(e.id),
                              ),
                            ],
                          )
                        : Icon(
                            e.aprobado == null ? Icons.hourglass_empty :
                            e.aprobado! ? Icons.check_circle : Icons.cancel,
                            color: e.aprobado == null ? Colors.grey :
                                   e.aprobado! ? Colors.green : cs.error,
                          ),
                  ],
                ),
              ),
            )),
        ],
      ),
    );
  }

  Widget _infoChip(ColorScheme cs, IconData icon, String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(text, style: TextStyle(color: color, fontWeight: FontWeight.w500, fontSize: 13)),
        ],
      ),
    );
  }

  Future<void> _aprobar(String id) async {
    final comentario = await _pedirComentario();
    if (comentario == null) return;
    await SupabaseService().aprobarEvidencia(id, comentario);
    ref.invalidate(tareasSupervisorProvider);
    ref.invalidate(tareasUsuarioProvider);
    if (_tarea != null) ref.invalidate(tareasDeUsuarioProvider(_tarea!.usuarioId));
    ref.invalidate(currentUserProvider);
    ref.invalidate(usuariosSupervisionProvider);
    _load();
  }

  Future<void> _rechazar(String id) async {
    final comentario = await _pedirComentario();
    if (comentario == null) return;
    await SupabaseService().rechazarEvidencia(id, comentario);
    ref.invalidate(tareasSupervisorProvider);
    ref.invalidate(tareasUsuarioProvider);
    if (_tarea != null) ref.invalidate(tareasDeUsuarioProvider(_tarea!.usuarioId));
    ref.invalidate(currentUserProvider);
    ref.invalidate(usuariosSupervisionProvider);
    _load();
  }

  Future<String?> _pedirComentario() => showDialog<String>(
    context: context,
    builder: (ctx) {
      final ctrl = TextEditingController();
      return AlertDialog(
        title: const Text('Comentario'),
        content: TextField(controller: ctrl, decoration: const InputDecoration(labelText: 'Comentario', hintText: 'Escribe un comentario...')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(ctx, ctrl.text), child: const Text('OK')),
        ],
      );
    },
  );
}
