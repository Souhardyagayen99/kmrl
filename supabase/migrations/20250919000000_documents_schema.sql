-- Documents feature schema and policies
create extension if not exists pgcrypto;

create table if not exists public.users (
  id uuid primary key references auth.users(id) on delete cascade,
  name text,
  email text unique,
  role text check (role in ('admin','employee')) not null default 'employee'
);

create table if not exists public.documents (
  id uuid primary key default gen_random_uuid(),
  title text not null,
  file_url text not null,
  parsed_text text,
  summary text,
  status text check (status in ('pending','approved','rejected')) not null default 'pending',
  created_at timestamptz not null default now(),
  created_by uuid references public.users(id) on delete set null
);

create table if not exists public.document_assignments (
  id uuid primary key default gen_random_uuid(),
  doc_id uuid not null references public.documents(id) on delete cascade,
  user_id uuid not null,
  assigned_at timestamptz not null default now(),
  unique (doc_id, user_id)
);

-- Storage bucket for documents (create if missing and storage available)
DO $$ BEGIN
  IF to_regclass('storage.buckets') IS NOT NULL THEN
    INSERT INTO storage.buckets (id, name, public)
    VALUES ('documents', 'documents', true)
    ON CONFLICT (id) DO NOTHING;
  END IF;
END $$;

alter table public.users enable row level security;
alter table public.documents enable row level security;
alter table public.document_assignments enable row level security;

-- Users policies
do $$ begin
  create policy users_self_select on public.users for select using (
    auth.uid() = id or exists (
      select 1 from public.users u where u.id = auth.uid() and u.role = 'admin'
    )
  );
exception when duplicate_object then null; end $$;


do $$ begin
  create policy users_admin_all on public.users for all using (
    exists (select 1 from public.users u where u.id = auth.uid() and u.role = 'admin')
  ) with check (true);
exception when duplicate_object then null; end $$;

-- Documents policies
DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = 'document_assignments' AND column_name = 'doc_id'
  ) THEN
    BEGIN
      CREATE POLICY documents_admin_all ON public.documents FOR ALL USING (
        EXISTS (SELECT 1 FROM public.users u WHERE u.id = auth.uid() AND u.role = 'admin')
      ) WITH CHECK (true);
    EXCEPTION WHEN duplicate_object THEN NULL; END;

    BEGIN
      CREATE POLICY documents_employee_select_assigned ON public.documents FOR SELECT USING (
        status = 'approved' AND EXISTS (
          SELECT 1 FROM public.document_assignments da
          WHERE da.doc_id = documents.id AND da.user_id = auth.uid()
        )
      );
    EXCEPTION WHEN duplicate_object THEN NULL; END;
  ELSE
    BEGIN
      CREATE POLICY documents_admin_all ON public.documents FOR ALL USING (
        EXISTS (SELECT 1 FROM public.users u WHERE u.id = auth.uid() AND u.role = 'admin')
      ) WITH CHECK (true);
    EXCEPTION WHEN duplicate_object THEN NULL; END;

    BEGIN
      CREATE POLICY documents_employee_select_assigned ON public.documents FOR SELECT USING (
        status = 'approved' AND EXISTS (
          SELECT 1 FROM public.document_assignments da
          WHERE da.document_id = documents.id AND da.user_id = auth.uid()
        )
      );
    EXCEPTION WHEN duplicate_object THEN NULL; END;
  END IF;
END $$;

-- Assignments policies
do $$ begin
  create policy assignments_admin_all on public.document_assignments for all using (
    exists (select 1 from public.users u where u.id = auth.uid() and u.role = 'admin')
  ) with check (true);
exception when duplicate_object then null; end $$;


do $$ begin
  create policy assignments_employee_select_self on public.document_assignments for select using (true);
exception when duplicate_object then null; end $$;


