import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../models/recompensa.dart';
import '../../providers/auth_provider.dart';
import '../../providers/usuarios_provider.dart';
import '../../providers/puntos_provider.dart';
import '../../services/supabase_service.dart';

class RecompensaFormScreen extends ConsumerStatefulWidget {
  const RecompensaFormScreen({super.key});
  @override
  ConsumerState<RecompensaFormScreen> createState() => _RecompensaFormScreenState();
}

class _RecompensaFormScreenState extends ConsumerState<RecompensaFormScreen> {
  final _nombreCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _costoCtrl = TextEditingController();
  String? _usuarioIdSeleccionado;
  bool _loading = false;

  @override
  void dispose() {
    _nombreCtrl.dispose();
    _descCtrl.dispose();
    _costoCtrl.dispose();
    super.dispose();
  }

  Future<void> _crear() async {
    if (_nombreCtrl.text.isEmpty || _costoCtrl.text.isEmpty || _usuarioIdSeleccionado == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Completa todos los campos')),
      );
      return;
    }
    setState(() => _loading = true);
    try {
      final usuario = await ref.read(currentUserProvider.future);
      if (usuario == null) return;
      final r = Recompensa(
        id: '',
        nombre: _nombreCtrl.text,
        descripcion: _descCtrl.text.isEmpty ? null : _descCtrl.text,
        costoPuntos: int.parse(_costoCtrl.text),
        supervisorId: usuario.id,
        usuarioId: _usuarioIdSeleccionado,
      );
      await SupabaseService().crearRecompensa(r);
      ref.invalidate(recompensasProvider);
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
    final usuariosAsync = ref.watch(usuariosSupervisionProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Nueva recompensa')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('Detalles de la recompensa', style: TextStyle(fontWeight: FontWeight.w600, color: cs.onSurfaceVariant)),
          const SizedBox(height: 16),
          TextField(
            controller: _nombreCtrl,
            decoration: const InputDecoration(labelText: 'Nombre', hintText: 'Nombre de la recompensa'),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _descCtrl,
            decoration: const InputDecoration(labelText: 'Descripción (opcional)', hintText: 'Describe la recompensa...'),
            maxLines: 3,
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _costoCtrl,
            decoration: const InputDecoration(labelText: 'Costo en puntos', prefixText: 'Pts: '),
            keyboardType: TextInputType.number,
          ),
          const SizedBox(height: 16),
          usuariosAsync.when(
            loading: () => const CircularProgressIndicator(),
            error: (e, _) => Text('Error: $e'),
            data: (usuarios) => DropdownButtonFormField<String>(
              initialValue: _usuarioIdSeleccionado,
              decoration: const InputDecoration(labelText: 'Asignar a usuario'),
              items: usuarios.map((u) => DropdownMenuItem(
                value: u.id,
                child: Text(u.nombre),
              )).toList(),
              onChanged: (v) => setState(() => _usuarioIdSeleccionado = v),
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _loading ? null : _crear,
              child: _loading
                  ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('Crear recompensa'),
            ),
          ),
        ],
      ),
    );
  }
}
