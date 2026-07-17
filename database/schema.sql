CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

CREATE TABLE usuarios (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  auth_user_id UUID NOT NULL,
  email TEXT NOT NULL,
  nombre TEXT NOT NULL,
  rol TEXT NOT NULL CHECK (rol IN ('supervisor', 'usuario')),
  supervisor_id UUID REFERENCES usuarios(id),
  puntos INT DEFAULT 0 CHECK (puntos >= 0),
  racha_actual INT DEFAULT 0,
  ultima_completada DATE,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE (auth_user_id, rol)
);

CREATE TABLE tareas (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  titulo TEXT NOT NULL,
  descripcion TEXT,
  puntos INT DEFAULT 10,
  fecha_limite TIMESTAMPTZ,
  evidencia_requerida BOOLEAN DEFAULT true,
  estado TEXT DEFAULT 'pendiente' CHECK (estado IN ('pendiente','evidencia_subida','completada','rechazada')),
  supervisor_id UUID NOT NULL REFERENCES usuarios(id),
  usuario_id UUID NOT NULL REFERENCES usuarios(id),
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE evidencias (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  tarea_id UUID NOT NULL REFERENCES tareas(id) ON DELETE CASCADE,
  tipo TEXT NOT NULL CHECK (tipo IN ('foto','documento','texto')),
  url TEXT,
  texto TEXT,
  comentario_supervisor TEXT,
  aprobado BOOLEAN,
  usuario_id UUID NOT NULL REFERENCES usuarios(id),
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE recompensas (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  nombre TEXT NOT NULL,
  descripcion TEXT,
  costo_puntos INT NOT NULL,
  disponible BOOLEAN DEFAULT true,
  supervisor_id UUID NOT NULL REFERENCES usuarios(id),
  usuario_id UUID REFERENCES usuarios(id),
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE canjes (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  usuario_id UUID NOT NULL REFERENCES usuarios(id),
  recompensa_id UUID NOT NULL REFERENCES recompensas(id),
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE invitaciones (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  supervisor_id UUID NOT NULL REFERENCES usuarios(id),
  supervisor_nombre TEXT NOT NULL DEFAULT '',
  usuario_email TEXT NOT NULL,
  estado TEXT DEFAULT 'pendiente' CHECK (estado IN ('pendiente','aceptada','rechazada')),
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE movimientos_puntos (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  usuario_id UUID NOT NULL REFERENCES usuarios(id),
  cantidad INT NOT NULL,
  tipo TEXT NOT NULL CHECK (tipo IN ('tarea_completada', 'canje')),
  descripcion TEXT NOT NULL DEFAULT '',
  created_at TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE usuarios ENABLE ROW LEVEL SECURITY;
ALTER TABLE tareas ENABLE ROW LEVEL SECURITY;
ALTER TABLE evidencias ENABLE ROW LEVEL SECURITY;
ALTER TABLE recompensas ENABLE ROW LEVEL SECURITY;
ALTER TABLE canjes ENABLE ROW LEVEL SECURITY;
ALTER TABLE invitaciones ENABLE ROW LEVEL SECURITY;
ALTER TABLE movimientos_puntos ENABLE ROW LEVEL SECURITY;

CREATE OR REPLACE FUNCTION public.is_supervisor()
RETURNS boolean
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT EXISTS (SELECT 1 FROM usuarios WHERE auth_user_id = auth.uid()::uuid AND rol = 'supervisor');
$$;

CREATE OR REPLACE FUNCTION public.perfil_actual_id()
RETURNS UUID
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT id FROM usuarios WHERE auth_user_id = auth.uid()::uuid LIMIT 1;
$$;

CREATE OR REPLACE FUNCTION public.supervisor_profile_id()
RETURNS UUID
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT id FROM usuarios WHERE auth_user_id = auth.uid()::uuid AND rol = 'supervisor' LIMIT 1;
$$;

CREATE POLICY "usuarios_read_self" ON usuarios FOR SELECT USING (
  auth_user_id = auth.uid()::uuid
);

CREATE POLICY "usuarios_insert_self" ON usuarios FOR INSERT WITH CHECK (
  auth_user_id = auth.uid()::uuid
);

CREATE POLICY "usuarios_update_self" ON usuarios FOR UPDATE USING (
  auth_user_id = auth.uid()::uuid
);

CREATE POLICY "usuarios_delete_self" ON usuarios FOR DELETE USING (
  auth_user_id = auth.uid()::uuid
);

CREATE POLICY "supervisores_read_usuarios" ON usuarios FOR SELECT USING (
  EXISTS (
    SELECT 1 FROM usuarios AS sp
    WHERE sp.auth_user_id = auth.uid()::uuid
      AND sp.rol = 'supervisor'
      AND sp.id = usuarios.supervisor_id
  )
);

CREATE POLICY "tareas_self" ON tareas FOR ALL USING (
  usuario_id IN (SELECT id FROM usuarios WHERE auth_user_id = auth.uid()::uuid)
);

CREATE POLICY "tareas_supervisor" ON tareas FOR ALL USING (
  supervisor_id IN (SELECT id FROM usuarios WHERE auth_user_id = auth.uid()::uuid AND rol = 'supervisor')
);

CREATE POLICY "evidencias_self" ON evidencias FOR ALL USING (
  usuario_id IN (SELECT id FROM usuarios WHERE auth_user_id = auth.uid()::uuid)
);

CREATE POLICY "evidencias_supervisor" ON evidencias FOR ALL USING (
  EXISTS (
    SELECT 1 FROM tareas
    WHERE tareas.id = evidencias.tarea_id
      AND tareas.supervisor_id IN (SELECT id FROM usuarios WHERE auth_user_id = auth.uid()::uuid AND rol = 'supervisor')
  )
);

CREATE POLICY "recompensas_supervisor" ON recompensas FOR ALL USING (
  supervisor_id IN (SELECT id FROM usuarios WHERE auth_user_id = auth.uid()::uuid AND rol = 'supervisor')
);

CREATE POLICY "recompensas_usuarios_ven" ON recompensas FOR SELECT USING (
  EXISTS (
    SELECT 1 FROM usuarios
    WHERE auth_user_id = auth.uid()::uuid
      AND (
        usuarios.supervisor_id = recompensas.supervisor_id
        OR usuarios.id = recompensas.supervisor_id
      )
  )
);

CREATE POLICY "canjes_self" ON canjes FOR ALL USING (
  usuario_id IN (SELECT id FROM usuarios WHERE auth_user_id = auth.uid()::uuid)
);

CREATE POLICY "canjes_supervisor" ON canjes FOR SELECT USING (public.is_supervisor());

CREATE POLICY "movimientos_self" ON movimientos_puntos FOR ALL USING (
  usuario_id IN (SELECT id FROM usuarios WHERE auth_user_id = auth.uid()::uuid)
);
CREATE POLICY "movimientos_supervisor_select" ON movimientos_puntos FOR SELECT USING (
  EXISTS (SELECT 1 FROM usuarios WHERE auth_user_id = auth.uid()::uuid AND rol = 'supervisor')
);

CREATE POLICY "invitaciones_insert" ON invitaciones FOR INSERT WITH CHECK (
  supervisor_id IN (SELECT id FROM usuarios WHERE auth_user_id = auth.uid()::uuid AND rol = 'supervisor')
);
CREATE POLICY "invitaciones_select_invitado" ON invitaciones FOR SELECT USING (
  usuario_email = (SELECT email FROM usuarios WHERE auth_user_id = auth.uid()::uuid LIMIT 1)
);
CREATE POLICY "invitaciones_select_supervisor" ON invitaciones FOR SELECT USING (
  supervisor_id IN (SELECT id FROM usuarios WHERE auth_user_id = auth.uid()::uuid AND rol = 'supervisor')
);
CREATE POLICY "invitaciones_update" ON invitaciones FOR UPDATE USING (
  usuario_email = (SELECT email FROM usuarios WHERE auth_user_id = auth.uid()::uuid LIMIT 1)
);

INSERT INTO storage.buckets (id, name, public)
VALUES ('evidencias', 'evidencias', true)
ON CONFLICT (id) DO NOTHING;

CREATE POLICY "evidencias_storage_insert" ON storage.objects FOR INSERT WITH CHECK (
  bucket_id = 'evidencias' AND auth.role() = 'authenticated'
);
CREATE POLICY "evidencias_storage_select" ON storage.objects FOR SELECT USING (
  bucket_id = 'evidencias'
);

CREATE OR REPLACE FUNCTION sumar_puntos()
RETURNS TRIGGER AS $$
DECLARE
  v_puntos INT;
  v_titulo TEXT;
BEGIN
  IF NEW.aprobado = true AND (OLD.aprobado IS NULL OR OLD.aprobado = false) THEN
    SELECT puntos, titulo INTO v_puntos, v_titulo FROM tareas WHERE id = NEW.tarea_id;
    UPDATE usuarios SET puntos = puntos + v_puntos WHERE id = NEW.usuario_id;
    UPDATE tareas SET estado = 'completada' WHERE id = NEW.tarea_id;
    INSERT INTO movimientos_puntos (usuario_id, cantidad, tipo, descripcion)
    VALUES (NEW.usuario_id, v_puntos, 'tarea_completada', 'Tarea: ' || v_titulo);
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE TRIGGER on_evidencia_aprobada
  AFTER UPDATE ON evidencias
  FOR EACH ROW
  EXECUTE FUNCTION sumar_puntos();

CREATE OR REPLACE FUNCTION canjear_puntos(p_usuario_id UUID, p_recompensa_id UUID)
RETURNS BOOLEAN AS $$
DECLARE
  v_costo INT;
  v_puntos INT;
  v_nombre TEXT;
BEGIN
  IF EXISTS (SELECT 1 FROM canjes WHERE usuario_id = p_usuario_id AND recompensa_id = p_recompensa_id) THEN
    RETURN false;
  END IF;
  SELECT costo_puntos, nombre INTO v_costo, v_nombre FROM recompensas WHERE id = p_recompensa_id;
  SELECT puntos INTO v_puntos FROM usuarios WHERE id = p_usuario_id;
  IF v_puntos >= v_costo THEN
    UPDATE usuarios SET puntos = puntos - v_costo WHERE id = p_usuario_id;
    INSERT INTO canjes (usuario_id, recompensa_id) VALUES (p_usuario_id, p_recompensa_id);
    INSERT INTO movimientos_puntos (usuario_id, cantidad, tipo, descripcion)
    VALUES (p_usuario_id, -v_costo, 'canje', 'Canje: ' || v_nombre);
    RETURN true;
  END IF;
  RETURN false;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION contar_usuarios_de_supervisor(p_supervisor_id UUID)
RETURNS INT AS $$
  SELECT COUNT(*)::INT FROM usuarios WHERE supervisor_id = p_supervisor_id AND rol = 'usuario';
$$ LANGUAGE sql SECURITY DEFINER;
