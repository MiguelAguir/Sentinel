import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:file_picker/file_picker.dart';
import '../../core/constants.dart';
import '../../models/evidencia.dart';
import '../../models/tarea.dart';
import '../../providers/auth_provider.dart';
import '../../providers/tareas_provider.dart';
import '../../providers/usuarios_provider.dart';
import '../../services/supabase_service.dart';

class EvidenciaFormScreen extends ConsumerStatefulWidget {
  final String tareaId;
  const EvidenciaFormScreen({super.key, required this.tareaId});
  @override
  ConsumerState<EvidenciaFormScreen> createState() => _EvidenciaFormScreenState();
}

class _EvidenciaFormScreenState extends ConsumerState<EvidenciaFormScreen> {
  Tarea? _tarea;
  List<Evidencia> _evidencias = [];
  TipoEvidencia _tipo = TipoEvidencia.texto;
  final _textoCtr = TextEditingController();
  bool _loading = true;
  bool _subiendo = false;
  String? _bloqueadoPor;

  final _motivaciones = [
    '¡Excelente trabajo! Sigue así.',
    '¡Vas por muy buen camino!',
    '¡Felicidades, sigue esforzándote!',
    '¡Buen trabajo! Cada paso cuenta.',
    '¡Impresionante! No te detengas.',
    '¡Genial! Sigue dando lo mejor de ti.',
  ];

  PlatformFile? _archivo;

  String? get _nombreArchivo => _archivo?.name;
  bool get _tieneArchivo => _archivo != null;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _textoCtr.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final service = SupabaseService();
    final resp = await service.client.from('tareas').select().eq('id', widget.tareaId).single();
    _tarea = Tarea.fromJson(resp);
    _evidencias = await service.getEvidenciasDeTarea(widget.tareaId);
    final pendiente = _evidencias.any((e) => e.aprobado == null);
    final aprobada = _evidencias.any((e) => e.aprobado == true);
    _bloqueadoPor = pendiente ? 'pendiente' : (aprobada ? 'aprobada' : null);
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _pickFile() async {
    final result = await FilePicker.pickFiles(
      withData: true,
      type: _tipo == TipoEvidencia.foto ? FileType.image : FileType.custom,
      allowedExtensions: _tipo == TipoEvidencia.foto
          ? null
          : ['jpg', 'jpeg', 'png', 'gif', 'bmp', 'webp', 'pdf', 'doc', 'docx', 'xls', 'xlsx', 'txt'],
    );
    if (result != null && result.files.single.bytes != null) {
      setState(() => _archivo = result.files.single);
    }
  }

  String? _detectarContentType(String name) {
    final ext = name.split('.').last.toLowerCase();
    switch (ext) {
      case 'jpg': case 'jpeg': return 'image/jpeg';
      case 'png': return 'image/png';
      case 'gif': return 'image/gif';
      case 'bmp': return 'image/bmp';
      case 'webp': return 'image/webp';
      case 'pdf': return 'application/pdf';
      case 'doc': return 'application/msword';
      case 'docx': return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
      case 'xls': return 'application/vnd.ms-excel';
      case 'xlsx': return 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';
      case 'txt': return 'text/plain';
      default: return null;
    }
  }

  bool _validar() {
    if (_tipo == TipoEvidencia.texto && _textoCtr.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Escribe un texto para la evidencia')),
      );
      return false;
    }
    if (_tipo != TipoEvidencia.texto && !_tieneArchivo) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selecciona un archivo')),
      );
      return false;
    }
    return true;
  }

  Future<void> _subir() async {
    if (!_validar()) return;
    HapticFeedback.mediumImpact();
    setState(() => _subiendo = true);
    try {
      final service = SupabaseService();
      final usuario = await ref.read(currentUserProvider.future);

      String? url;
      if (_tieneArchivo) {
        final nombre = _nombreArchivo!;
        final bytes = _archivo!.bytes!;
        final path = '${widget.tareaId}/${DateTime.now().millisecondsSinceEpoch}_$nombre';
        final contentType = _detectarContentType(nombre);
        url = await service.subirArchivo('evidencias', path, bytes, contentType: contentType);
      }

      await service.subirEvidencia(
        tareaId: widget.tareaId,
        tipo: _tipo,
        url: url,
        texto: _textoCtr.text.isEmpty ? null : _textoCtr.text,
        usuarioId: usuario!.id,
      );
      ref.invalidate(tareasSupervisorProvider);
      ref.invalidate(tareasUsuarioProvider);
      if (_tarea != null) ref.invalidate(tareasDeUsuarioProvider(_tarea!.usuarioId));
      ref.invalidate(currentUserProvider);
      ref.invalidate(usuariosSupervisionProvider);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Evidencia subida')),
      );
      context.pop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    } finally {
      if (mounted) setState(() => _subiendo = false);
    }
  }

  Widget _buildAprobada() {
    final cs = Theme.of(context).colorScheme;
    final aprobada = _evidencias.where((e) => e.aprobado == true);
    final comentario = aprobada.isNotEmpty ? aprobada.first.comentarioSupervisor : null;
    final motivacion = _motivaciones[widget.tareaId.hashCode.abs() % _motivaciones.length];
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.green.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check_circle, size: 48, color: Colors.green),
            ),
            const SizedBox(height: 16),
            Text('¡Tarea completada!', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.green[700])),
            if (comentario != null) ...[
              const SizedBox(height: 12),
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
                    const SizedBox(width: 6),
                    Expanded(child: Text(comentario, style: const TextStyle(fontSize: 15))),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 12),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.emoji_events, size: 20, color: Colors.amber[700]),
                const SizedBox(width: 6),
                Text(motivacion, style: TextStyle(color: Colors.amber[700], fontSize: 15, fontWeight: FontWeight.w500)),
              ],
            ),
            const SizedBox(height: 24),
            OutlinedButton(
              onPressed: () => context.pop(),
              child: const Text('Volver'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildForm() {
    final cs = Theme.of(context).colorScheme;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('Tipo de evidencia', style: TextStyle(fontWeight: FontWeight.w600, color: cs.onSurfaceVariant)),
        const SizedBox(height: 8),
        SegmentedButton<TipoEvidencia>(
          segments: const [
            ButtonSegment(value: TipoEvidencia.texto, label: Text('Texto'), icon: Icon(Icons.text_fields)),
            ButtonSegment(value: TipoEvidencia.foto, label: Text('Foto'), icon: Icon(Icons.camera_alt)),
            ButtonSegment(value: TipoEvidencia.documento, label: Text('Doc'), icon: Icon(Icons.description)),
          ],
          selected: {_tipo},
          onSelectionChanged: (v) => setState(() {
            _tipo = v.first;
            _archivo = null;
          }),
        ),
        const SizedBox(height: 16),
        if (_tipo == TipoEvidencia.texto)
          TextField(
            controller: _textoCtr,
            maxLines: 5,
            decoration: const InputDecoration(
              labelText: 'Texto',
              hintText: 'Describe tu evidencia...',
              alignLabelWithHint: true,
            ),
          )
        else
          Column(
            children: [
              OutlinedButton.icon(
                onPressed: _pickFile,
                icon: const Icon(Icons.upload_file),
                label: Text(_tieneArchivo ? 'Cambiar archivo' : 'Seleccionar archivo'),
              ),
              if (_tieneArchivo) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: cs.primaryContainer.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.insert_drive_file, size: 16, color: cs.primary),
                      const SizedBox(width: 6),
                      Text(_nombreArchivo!, style: TextStyle(color: cs.primary, fontSize: 13)),
                    ],
                  ),
                ),
              ],
            ],
          ),
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: _subiendo ? null : _subir,
            child: _subiendo
                ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Text('Enviar evidencia'),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    return Scaffold(
      appBar: AppBar(title: Text(_tarea?.titulo ?? 'Subir evidencia')),
      body: _bloqueadoPor == 'pendiente'
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primaryContainer,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.schedule, size: 48, color: Theme.of(context).colorScheme.primary),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Ya has enviado evidencia para esta tarea.\n'
                      'Espera a que el supervisor la revise.',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: () => context.push('/tareas/${widget.tareaId}'),
                      child: const Text('Ver detalle'),
                    ),
                  ],
                ),
              ),
            )
          : _bloqueadoPor == 'aprobada'
          ? _buildAprobada()
          : _buildForm(),
    );
  }
}
