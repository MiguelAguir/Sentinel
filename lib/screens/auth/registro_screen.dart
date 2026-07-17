import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../providers/auth_provider.dart';
import '../../services/supabase_service.dart';

class RegistroScreen extends ConsumerStatefulWidget {
  const RegistroScreen({super.key});
  @override
  ConsumerState<RegistroScreen> createState() => _RegistroScreenState();
}

class _RegistroScreenState extends ConsumerState<RegistroScreen> {
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _nombreCtrl = TextEditingController();
  final _supervisorEmailCtrl = TextEditingController();
  String _rol = 'usuario';
  bool _loading = false;
  bool _obscure = true;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _nombreCtrl.dispose();
    _supervisorEmailCtrl.dispose();
    super.dispose();
  }

  bool _validar() {
    if (_nombreCtrl.text.trim().isEmpty) {
      _mostrarError('Ingresa tu nombre');
      return false;
    }
    if (_emailCtrl.text.trim().isEmpty || !_emailCtrl.text.contains('@')) {
      _mostrarError('Ingresa un email válido');
      return false;
    }
    if (_passwordCtrl.text.length < 6) {
      _mostrarError('La contraseña debe tener al menos 6 caracteres');
      return false;
    }
    return true;
  }

  void _mostrarError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _register() async {
    if (!_validar()) return;
    setState(() => _loading = true);
    try {
      final service = SupabaseService();
      final yaLogueado = service.client.auth.currentUser != null;

      if (yaLogueado) {
        final perfiles = await service.getPerfiles(service.client.auth.currentUser!.id);
        if (perfiles.length >= 2) {
          if (!mounted) return;
          _mostrarError('Ya tienes el máximo de 2 perfiles (supervisor + usuario)');
          return;
        }
      }

      if (yaLogueado) {
        await service.crearSegundoPerfil(
          email: _emailCtrl.text,
          nombre: _nombreCtrl.text,
          rol: _rol,
          supervisorEmail: _rol == 'usuario' ? _supervisorEmailCtrl.text : null,
        );
      } else {
        await service.signUp(
          email: _emailCtrl.text,
          password: _passwordCtrl.text,
          nombre: _nombreCtrl.text,
          rol: _rol,
          supervisorEmail: _rol == 'usuario' ? _supervisorEmailCtrl.text : null,
        );
      }

      if (!mounted) return;
      if (yaLogueado) {
        ref.invalidate(perfilesProvider);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Perfil de $_rol creado')),
        );
      }
      context.go('/dashboard');
    } on AuthException catch (e) {
      if (!mounted) return;
      if (e.message.contains('already') || e.message.contains('duplicate')) {
        final confirm = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Email ya registrado'),
            content: const Text('Este email ya tiene una cuenta. ¿Quieres agregar un nuevo perfil con este email?'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
              FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Agregar perfil')),
            ],
          ),
        );
        if (confirm == true && mounted) {
          final service = SupabaseService();
          await service.client.auth.signInWithPassword(
            email: _emailCtrl.text,
            password: _passwordCtrl.text,
          );
          if (!mounted) return;
          final perfiles = await service.getPerfiles(service.client.auth.currentUser!.id);
          if (perfiles.length >= 2) {
            _mostrarError('Ya tienes el máximo de 2 perfiles');
            return;
          }
          await service.crearSegundoPerfil(
            email: _emailCtrl.text,
            nombre: _nombreCtrl.text,
            rol: _rol,
            supervisorEmail: _rol == 'usuario' ? _supervisorEmailCtrl.text : null,
          );
          ref.invalidate(perfilesProvider);
          if (mounted) context.go('/dashboard');
        }
      } else {
        _mostrarError(e.message);
      }
    } catch (e) {
      if (!mounted) return;
      _mostrarError('Error de conexión: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Crear cuenta')),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: cs.primaryContainer,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(Icons.person_add, color: cs.primary, size: 32),
              ),
              const SizedBox(height: 8),
              Text('Nueva cuenta', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: cs.onSurface)),
              const SizedBox(height: 4),
              Text('Completa los datos para registrarte', style: TextStyle(color: cs.onSurfaceVariant, fontSize: 14)),
              const SizedBox(height: 24),
              TextField(
                controller: _nombreCtrl,
                decoration: const InputDecoration(labelText: 'Nombre', prefixIcon: Icon(Icons.person)),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _emailCtrl,
                decoration: const InputDecoration(labelText: 'Email', prefixIcon: Icon(Icons.email)),
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _passwordCtrl,
                decoration: InputDecoration(
                  labelText: 'Contraseña (min. 6 caracteres)',
                  prefixIcon: const Icon(Icons.lock),
                  suffixIcon: IconButton(
                    icon: Icon(_obscure ? Icons.visibility_off : Icons.visibility),
                    onPressed: () => setState(() => _obscure = !_obscure),
                  ),
                ),
                obscureText: _obscure,
              ),
              const SizedBox(height: 16),
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'usuario', label: Text('Usuario'), icon: Icon(Icons.person)),
                  ButtonSegment(value: 'supervisor', label: Text('Supervisor'), icon: Icon(Icons.shield)),
                ],
                selected: {_rol},
                onSelectionChanged: (v) => setState(() => _rol = v.first),
              ),
              if (_rol == 'usuario') ...[
                const SizedBox(height: 16),
                TextField(
                  controller: _supervisorEmailCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Email del supervisor (opcional)',
                    prefixIcon: Icon(Icons.supervisor_account),
                  ),
                ),
              ],
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _loading ? null : _register,
                  child: _loading
                      ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Text('Crear cuenta'),
                ),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: () => context.go('/login'),
                child: const Text('¿Ya tienes cuenta? Inicia sesión'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
