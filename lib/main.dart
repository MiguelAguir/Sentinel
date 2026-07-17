import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:go_router/go_router.dart';
import 'models/tarea.dart';
import 'providers/theme_provider.dart';
import 'screens/auth/login_screen.dart';
import 'screens/auth/registro_screen.dart';
import 'screens/dashboard/dashboard_screen.dart';
import 'screens/tareas/tarea_form_screen.dart';
import 'screens/tareas/tarea_detail_screen.dart';
import 'screens/evidencias/evidencia_form_screen.dart';
import 'screens/gamificacion/recompensa_form_screen.dart';
import 'screens/gamificacion/recompensa_list_screen.dart';
import 'screens/gamificacion/calendario_screen.dart';
import 'screens/perfil/perfil_screen.dart';

final supabaseProvider = Provider<SupabaseClient>((ref) {
  return Supabase.instance.client;
});

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: '.env');
  await Supabase.initialize(
    url: dotenv.env['SUPABASE_URL']!,
    publishableKey: dotenv.env['SUPABASE_ANON_KEY']!,
  );
  runApp(const ProviderScope(child: SentinelApp()));
}

final _router = GoRouter(
  initialLocation: '/login',
  routes: [
    GoRoute(path: '/login', builder: (_, _) => const LoginScreen()),
    GoRoute(path: '/registro', builder: (_, _) => const RegistroScreen()),
    GoRoute(path: '/dashboard', builder: (_, _) => const DashboardScreen()),
    GoRoute(path: '/perfil', builder: (_, _) => const PerfilScreen()),
    GoRoute(path: '/calendario', builder: (_, _) => const CalendarioScreen()),

    GoRoute(
      path: '/tareas/crear',
      builder: (_, state) => TareaFormScreen(usuarioId: state.extra as String?),
    ),
    GoRoute(
      path: '/tareas/:id',
      builder: (_, state) => TareaDetailScreen(tareaId: state.pathParameters['id']!),
    ),
    GoRoute(
      path: '/tareas/:id/editar',
      builder: (_, state) => TareaFormScreen(tarea: state.extra as Tarea?),
    ),
    GoRoute(
      path: '/evidencias/subir/:tareaId',
      builder: (_, state) => EvidenciaFormScreen(tareaId: state.pathParameters['tareaId']!),
    ),
    GoRoute(
      path: '/recompensas/crear',
      builder: (_, _) => const RecompensaFormScreen(),
    ),
    GoRoute(
      path: '/recompensas',
      builder: (_, _) => const RecompensaListScreen(),
    ),
  ],
  redirect: (context, state) {
    final path = state.uri.path;
    if (path == '/') return '/login';
    final session = Supabase.instance.client.auth.currentSession;
    final isLoggedIn = session != null;
    final isGoingToLogin = path == '/login';
    final isGoingToRegistro = path == '/registro';
    if (!isLoggedIn && !isGoingToLogin && !isGoingToRegistro) return '/login';
    if (isLoggedIn && (isGoingToLogin || isGoingToRegistro)) return '/dashboard';
    return null;
  },
);

const _lightColorScheme = ColorScheme(
  brightness: Brightness.light,
  primary: Color(0xFF2563EB),
  onPrimary: Colors.white,
  primaryContainer: Color(0xFFDBEAFE),
  onPrimaryContainer: Color(0xFF1E3A5F),
  secondary: Color(0xFF059669),
  onSecondary: Colors.white,
  secondaryContainer: Color(0xFFD1FAE5),
  onSecondaryContainer: Color(0xFF064E3B),
  tertiary: Color(0xFF7C3AED),
  onTertiary: Colors.white,
  tertiaryContainer: Color(0xFFEDE9FE),
  onTertiaryContainer: Color(0xFF3B0764),
  error: Color(0xFFDC2626),
  onError: Colors.white,
  errorContainer: Color(0xFFFEE2E2),
  onErrorContainer: Color(0xFF7F1D1D),
  surface: Colors.white,
  onSurface: Color(0xFF0F172A),
  surfaceContainerHighest: Color(0xFFF1F5F9),
  onSurfaceVariant: Color(0xFF475569),
  outline: Color(0xFFCBD5E1),
  outlineVariant: Color(0xFFE2E8F0),
  inverseSurface: Color(0xFF0F172A),
  onInverseSurface: Color(0xFFF1F5F9),
  inversePrimary: Color(0xFF93C5FD),
  shadow: Color(0xFF0F172A),
);

const _darkColorScheme = ColorScheme(
  brightness: Brightness.dark,
  primary: Color(0xFF60A5FA),
  onPrimary: Color(0xFF0C4A6E),
  primaryContainer: Color(0xFF1E3A5F),
  onPrimaryContainer: Color(0xFFDBEAFE),
  secondary: Color(0xFF34D399),
  onSecondary: Color(0xFF064E3B),
  secondaryContainer: Color(0xFF065F46),
  onSecondaryContainer: Color(0xFFD1FAE5),
  tertiary: Color(0xFFA78BFA),
  onTertiary: Color(0xFF3B0764),
  tertiaryContainer: Color(0xFF5B21B6),
  onTertiaryContainer: Color(0xFFEDE9FE),
  error: Color(0xFFFCA5A5),
  onError: Color(0xFF7F1D1D),
  errorContainer: Color(0xFF991B1B),
  onErrorContainer: Color(0xFFFEE2E2),
  surface: Color(0xFF0F172A),
  onSurface: Color(0xFFF1F5F9),
  surfaceContainerHighest: Color(0xFF1E293B),
  onSurfaceVariant: Color(0xFF94A3B8),
  outline: Color(0xFF334155),
  outlineVariant: Color(0xFF1E293B),
  inverseSurface: Color(0xFFF1F5F9),
  onInverseSurface: Color(0xFF0F172A),
  inversePrimary: Color(0xFF2563EB),
  shadow: Color(0xFF000000),
);

class SentinelApp extends ConsumerWidget {
  const SentinelApp({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);
    return MaterialApp.router(
      title: 'Sentinel',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: _lightColorScheme,
        scaffoldBackgroundColor: const Color(0xFFF8FAFC),
        cardTheme: CardThemeData(
          elevation: 1,
          shadowColor: const Color(0xFF0F172A).withValues(alpha: 0.08),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          clipBehavior: Clip.antiAlias,
        ),
        appBarTheme: const AppBarTheme(
          elevation: 0,
          scrolledUnderElevation: 1,
          centerTitle: true,
          backgroundColor: Colors.white,
          foregroundColor: Color(0xFF0F172A),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: const Color(0xFFF1F5F9),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFF2563EB), width: 2),
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        chipTheme: ChipThemeData(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        ),
        segmentedButtonTheme: SegmentedButtonThemeData(
          style: SegmentedButton.styleFrom(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        dividerTheme: const DividerThemeData(
          space: 0,
          thickness: 1,
          color: Color(0xFFF1F5F9),
        ),
        snackBarTheme: SnackBarThemeData(
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        colorScheme: _darkColorScheme,
        scaffoldBackgroundColor: const Color(0xFF0F172A),
        cardTheme: CardThemeData(
          elevation: 1,
          shadowColor: Colors.black.withValues(alpha: 0.3),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          clipBehavior: Clip.antiAlias,
        ),
        appBarTheme: const AppBarTheme(
          elevation: 0,
          scrolledUnderElevation: 1,
          centerTitle: true,
          backgroundColor: Color(0xFF1E293B),
          foregroundColor: Color(0xFFF1F5F9),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: const Color(0xFF1E293B),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFF334155)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFF60A5FA), width: 2),
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        chipTheme: ChipThemeData(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        ),
        segmentedButtonTheme: SegmentedButtonThemeData(
          style: SegmentedButton.styleFrom(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        dividerTheme: const DividerThemeData(
          space: 0,
          thickness: 1,
          color: Color(0xFF1E293B),
        ),
        snackBarTheme: SnackBarThemeData(
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
      themeMode: themeMode,
      routerConfig: _router,
      debugShowCheckedModeBanner: false,
    );
  }
}
