import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../models/tarea.dart';
import '../../models/usuario.dart';
import '../../core/constants.dart';
import '../../providers/auth_provider.dart';
import '../../providers/tareas_provider.dart';
import '../../providers/usuarios_provider.dart';

class CalendarioScreen extends ConsumerStatefulWidget {
  const CalendarioScreen({super.key});
  @override
  ConsumerState<CalendarioScreen> createState() => _CalendarioScreenState();
}

class _CalendarioScreenState extends ConsumerState<CalendarioScreen> {
  DateTime _mesActual = DateTime(DateTime.now().year, DateTime.now().month);

  void _mesAnterior() => setState(() => _mesActual = DateTime(_mesActual.year, _mesActual.month - 1));
  void _mesSiguiente() => setState(() => _mesActual = DateTime(_mesActual.year, _mesActual.month + 1));

  @override
  Widget build(BuildContext context) {
    final usuario = ref.watch(currentUserProvider).value;
    if (usuario == null) return const Scaffold(body: Center(child: Text('No hay sesión')));

    return Scaffold(
      appBar: AppBar(title: const Text('Calendario')),
      body: usuario.esSupervisor
          ? _buildSupervisorView(usuario)
          : _buildUserView(usuario),
    );
  }

  Widget _buildSupervisorView(Usuario usuario) {
    final tareasAsync = ref.watch(tareasSupervisorProvider);
    final usuariosAsync = ref.watch(usuariosSupervisionProvider);
    final usuarios = usuariosAsync.value ?? [];

    return tareasAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (tareas) => _buildCalendar(tareas, usuarios),
    );
  }

  Widget _buildUserView(Usuario usuario) {
    final tareasAsync = ref.watch(tareasUsuarioProvider);
    return tareasAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (tareas) => _buildCalendar(tareas, []),
    );
  }

  Widget _buildCalendar(List<Tarea> tareas, List<Usuario> usuarios) {
    final cs = Theme.of(context).colorScheme;
    final conFecha = tareas.where((t) => t.fechaLimite != null).toList();
    final diasDelMes = _generarDias(_mesActual);
    final primerDiaSemana = _mesActual.weekday % 7;

    final tareasPorDia = <int, List<Tarea>>{};
    for (final t in conFecha) {
      final d = t.fechaLimite!;
      if (d.year == _mesActual.year && d.month == _mesActual.month) {
        tareasPorDia.putIfAbsent(d.day, () => []);
        tareasPorDia[d.day]!.add(t);
      }
    }

    return Column(
      children: [
        _header(),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            children: [
              Card(
                elevation: 2,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
                  child: Column(
                    children: [
                      _diasSemana(cs),
                      const SizedBox(height: 4),
                      _gridDias(diasDelMes, tareasPorDia, cs, primerDiaSemana),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Text('Tareas con fecha', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: cs.onSurface)),
                  const Spacer(),
                  if (tareasPorDia.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: cs.primaryContainer,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text('${tareasPorDia.length} día(s)', style: TextStyle(color: cs.primary, fontSize: 12, fontWeight: FontWeight.w600)),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              if (tareasPorDia.isEmpty)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.event_busy, size: 40, color: Colors.grey[300]),
                          const SizedBox(height: 8),
                          Text('No hay tareas con fecha este mes', style: TextStyle(color: Colors.grey[500])),
                        ],
                      ),
                    ),
                  ),
                )
              else
                ..._tareasDelMes(conFecha, usuarios),
            ],
          ),
        ),
      ],
    );
  }

  Widget _header() {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left),
            onPressed: _mesAnterior,
            style: IconButton.styleFrom(
              backgroundColor: cs.surfaceContainerHighest,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
          Text(
            '${_mesNombre(_mesActual.month)} ${_mesActual.year}',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: cs.onSurface),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right),
            onPressed: _mesSiguiente,
            style: IconButton.styleFrom(
              backgroundColor: cs.surfaceContainerHighest,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _diasSemana(ColorScheme cs) {
    const dias = ['L', 'M', 'M', 'J', 'V', 'S', 'D'];
    return Row(
      children: dias.map((d) => Expanded(
        child: Center(
          child: Text(d, style: TextStyle(
            color: cs.onSurfaceVariant,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          )),
        ),
      )).toList(),
    );
  }

  Widget _gridDias(List<int?> dias, Map<int, List<Tarea>> tareasPorDia, ColorScheme cs, int inicioSemana) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 7,
        childAspectRatio: 1.1,
      ),
      itemCount: dias.length,
      itemBuilder: (_, i) {
        final d = dias[i];
        if (d == null) return const SizedBox();
        final tareasDelDia = tareasPorDia[d];
        final count = tareasDelDia?.length ?? 0;
        final completadas = tareasDelDia?.where((t) => t.estado == EstadoTarea.completada).length ?? 0;
        final pendientes = count - completadas;
        final isToday = d == DateTime.now().day &&
            _mesActual.month == DateTime.now().month &&
            _mesActual.year == DateTime.now().year;

        Color? bgColor;
        if (isToday) {
          bgColor = cs.primaryContainer;
        } else if (count > 0) {
          bgColor = completadas == count
              ? Colors.green.withValues(alpha: 0.12)
              : cs.secondaryContainer.withValues(alpha: 0.25);
        }

        return AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: const EdgeInsets.all(2),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(10),
            border: isToday ? Border.all(color: cs.primary, width: 2) : null,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('$d', style: TextStyle(
                fontWeight: isToday ? FontWeight.bold : (count > 0 ? FontWeight.w600 : null),
                fontSize: isToday ? 15 : 13,
                color: count > 0 && !isToday ? cs.onSurface : null,
              )),
              if (count > 0 && pendientes > 0)
                Container(
                  margin: const EdgeInsets.only(top: 2),
                  width: 6, height: 6,
                  decoration: BoxDecoration(
                    color: cs.secondary,
                    shape: BoxShape.circle,
                  ),
                ),
              if (count > 0 && pendientes == 0)
                Container(
                  margin: const EdgeInsets.only(top: 2),
                  width: 6, height: 6,
                  decoration: BoxDecoration(
                    color: Colors.green,
                    shape: BoxShape.circle,
                  ),
                ),
              if (count > 0 && pendientes > 0 && completadas > 0)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 4, height: 4,
                      decoration: const BoxDecoration(color: Colors.green, shape: BoxShape.circle),
                    ),
                    const SizedBox(width: 2),
                    Container(
                      width: 4, height: 4,
                      decoration: BoxDecoration(color: cs.secondary, shape: BoxShape.circle),
                    ),
                  ],
                ),
            ],
          ),
        );
      },
    );
  }

  List<Widget> _tareasDelMes(List<Tarea> tareas, List<Usuario> usuarios) {
    final cs = Theme.of(context).colorScheme;
    final sorted = List<Tarea>.from(tareas)
      ..sort((a, b) => a.fechaLimite!.compareTo(b.fechaLimite!));

    DateTime? currentDay;
    final widgets = <Widget>[];

    for (final t in sorted) {
      final day = DateTime(t.fechaLimite!.year, t.fechaLimite!.month, t.fechaLimite!.day);
      if (currentDay == null || day != currentDay) {
        currentDay = day;
        final dayTareas = sorted.where((x) =>
          x.fechaLimite!.year == day.year &&
          x.fechaLimite!.month == day.month &&
          x.fechaLimite!.day == day.day).toList();
        final total = dayTareas.length;
        final completadas = dayTareas.where((x) => x.estado == EstadoTarea.completada).length;

        widgets.add(
          Padding(
            padding: const EdgeInsets.only(top: 8, bottom: 4),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: completadas == total ? Colors.green.withValues(alpha: 0.1) : cs.primaryContainer,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '${day.day}/${day.month}',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                      color: completadas == total ? Colors.green[700] : cs.primary,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Divider(color: cs.outlineVariant, thickness: 1),
                ),
                Text('$completadas/$total', style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12)),
              ],
            ),
          ),
        );
      }

      final user = usuarios.where((u) => u.id == t.usuarioId).firstOrNull;
      final completada = t.estado == EstadoTarea.completada;

      widgets.add(
        Card(
          margin: const EdgeInsets.only(bottom: 6),
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () => context.push('/tareas/${t.id}'),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(
                children: [
                  Container(
                    width: 36, height: 36,
                    decoration: BoxDecoration(
                      color: completada ? Colors.green.withValues(alpha: 0.12) : Colors.orange.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      completada ? Icons.check_circle : Icons.pending,
                      color: completada ? Colors.green : Colors.orange,
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(t.titulo, style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: cs.onSurface)),
                        const SizedBox(height: 2),
                        Text(
                          '${user != null ? user.nombre : ''}${user != null ? ' • ' : ''}${t.estado == EstadoTarea.completada ? "Completada" : t.estado == EstadoTarea.evidenciaSubida ? "En revisión" : t.estado == EstadoTarea.rechazada ? "Rechazada" : "Pendiente"}',
                          style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  Icon(Icons.chevron_right, size: 18, color: Colors.grey[400]),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return widgets;
  }

  List<int?> _generarDias(DateTime mes) {
    final primero = DateTime(mes.year, mes.month, 1);
    final diasEnMes = DateTime(mes.year, mes.month + 1, 0).day;
    final inicioSemana = primero.weekday % 7;
    final result = <int?>[];
    for (int i = 0; i < inicioSemana; i++) { result.add(null); }
    for (int d = 1; d <= diasEnMes; d++) { result.add(d); }
    return result;
  }

  String _mesNombre(int m) {
    const nombres = ['Enero', 'Febrero', 'Marzo', 'Abril', 'Mayo', 'Junio',
      'Julio', 'Agosto', 'Septiembre', 'Octubre', 'Noviembre', 'Diciembre'];
    return nombres[m - 1];
  }
}
