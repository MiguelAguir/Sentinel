import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../models/tarea.dart';
import '../../providers/auth_provider.dart';
import '../../providers/tareas_provider.dart';
import '../../providers/usuarios_provider.dart';
import '../../services/supabase_service.dart';

class TareaFormScreen extends ConsumerStatefulWidget {
  final String? usuarioId;
  final Tarea? tarea;

  const TareaFormScreen({super.key, this.usuarioId, this.tarea});

  @override
  ConsumerState<TareaFormScreen> createState() => _TareaFormScreenState();
}

class _TareaFormScreenState extends ConsumerState<TareaFormScreen> {
  final _tituloCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _puntosCtrl = TextEditingController(text: '10');
  DateTime? _fechaLimite;
  bool _loading = false;

  bool get _editando => widget.tarea != null;

  @override
  void initState() {
    super.initState();
    if (_editando) {
      _tituloCtrl.text = widget.tarea!.titulo;
      _descCtrl.text = widget.tarea!.descripcion ?? '';
      _puntosCtrl.text = widget.tarea!.puntos.toString();
      _fechaLimite = widget.tarea!.fechaLimite;
    }
  }

  @override
  void dispose() {
    _tituloCtrl.dispose();
    _descCtrl.dispose();
    _puntosCtrl.dispose();
    super.dispose();
  }

  bool _validar() {
    if (_tituloCtrl.text.trim().isEmpty) {
      HapticFeedback.heavyImpact();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ingresa un título para la tarea')),
      );
      return false;
    }
    final pts = int.tryParse(_puntosCtrl.text);
    if (pts == null || pts < 1) {
      HapticFeedback.heavyImpact();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Los puntos deben ser un número positivo')),
      );
      return false;
    }
    return true;
  }

  Future<void> _seleccionarFecha() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _fechaLimite ?? DateTime.now().add(const Duration(days: 7)),
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) {
      setState(() => _fechaLimite = picked);
    }
  }

  Future<void> _guardar() async {
    if (!_validar()) return;
    HapticFeedback.mediumImpact();
    setState(() => _loading = true);
    try {
      final usuario = await ref.read(currentUserProvider.future);
      if (usuario == null) return;
      final service = SupabaseService();

      if (_editando) {
        await service.actualizarTarea(widget.tarea!.id, {
          'titulo': _tituloCtrl.text,
          'descripcion': _descCtrl.text.isEmpty ? null : _descCtrl.text,
          'puntos': int.tryParse(_puntosCtrl.text) ?? 10,
          'fecha_limite': _fechaLimite?.toIso8601String(),
        });
      } else {
        final tarea = Tarea(
          id: '',
          titulo: _tituloCtrl.text,
          descripcion: _descCtrl.text.isEmpty ? null : _descCtrl.text,
          puntos: int.tryParse(_puntosCtrl.text) ?? 10,
          fechaLimite: _fechaLimite,
          supervisorId: usuario.id,
          usuarioId: widget.usuarioId ?? '',
        );
        await service.crearTarea(tarea);
      }

      ref.invalidate(tareasSupervisorProvider);
      ref.invalidate(tareasUsuarioProvider);
      ref.invalidate(currentUserProvider);
      ref.invalidate(usuariosSupervisionProvider);
      final targetUserId = widget.tarea?.usuarioId ?? widget.usuarioId;
      if (targetUserId != null) ref.invalidate(tareasDeUsuarioProvider(targetUserId));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tarea guardada')),
      );
      if (!mounted) return;
      context.pop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: Text(_editando ? 'Editar tarea' : 'Nueva tarea')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('Información de la tarea', style: TextStyle(fontWeight: FontWeight.w600, color: cs.onSurfaceVariant)),
          const SizedBox(height: 16),
          TextField(
            controller: _tituloCtrl,
            decoration: const InputDecoration(labelText: 'Título', hintText: 'Nombre de la tarea'),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _descCtrl,
            decoration: const InputDecoration(
              labelText: 'Descripción (opcional)',
              hintText: 'Describe la tarea...',
              alignLabelWithHint: true,
            ),
            maxLines: 3,
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _puntosCtrl,
            decoration: const InputDecoration(
              labelText: 'Puntos al completar',
              prefixText: 'Pts: ',
            ),
            keyboardType: TextInputType.number,
          ),
          const SizedBox(height: 16),
          Card(
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: cs.primaryContainer,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.calendar_today, color: cs.primary, size: 20),
              ),
              title: Text(
                _fechaLimite != null
                    ? '${_fechaLimite!.day}/${_fechaLimite!.month}/${_fechaLimite!.year}'
                    : 'Sin fecha límite',
                style: TextStyle(fontWeight: FontWeight.w500),
              ),
              subtitle: const Text('Tocar para asignar fecha (opcional)'),
              trailing: _fechaLimite != null
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () => setState(() => _fechaLimite = null),
                    )
                  : const Icon(Icons.chevron_right, color: Colors.grey),
              onTap: _seleccionarFecha,
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _loading ? null : _guardar,
              child: _loading
                  ? const SizedBox(
                      width: 20, height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : Text(_editando ? 'Guardar cambios' : 'Crear tarea'),
            ),
          ),
        ],
      ),
    );
  }
}
