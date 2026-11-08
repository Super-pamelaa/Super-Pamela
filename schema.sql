-- SUPER PAMELA · Base de datos (Supabase > SQL Editor > New query > pegar todo > Run)
-- Al final, reemplazá TU_CORREO por el correo del administrador.

create table if not exists admins (email text primary key);

create or replace function is_admin() returns boolean
language sql stable security definer set search_path = public as $$
  select exists(select 1 from admins where lower(email) = lower(coalesce(auth.jwt()->>'email','')))
$$;

create table if not exists settings (id int primary key default 1 check (id = 1), data jsonb not null default '{}');
insert into settings (id) values (1) on conflict do nothing;

create table if not exists products (
  id uuid primary key default gen_random_uuid(),
  name text not null, description text default '',
  price numeric not null check (price >= 0), unit text default 'unidad',
  category text not null, image_url text, stock int check (stock >= 0), -- stock vacío = sin control
  featured boolean default false, active boolean default true,
  created_at timestamptz default now()
);

create table if not exists offers (
  id uuid primary key default gen_random_uuid(),
  title text not null, tag text default 'Oferta', description text default '',
  price numeric not null check (price >= 0), old_price numeric, unit text default 'unidad',
  emoji text default '🏷️', image_url text,
  starts_on date, ends_on date, featured boolean default false, active boolean default true,
  created_at timestamptz default now()
);

create table if not exists orders (
  id uuid primary key default gen_random_uuid(),
  created_at timestamptz default now(),
  customer_name text not null check (length(customer_name) between 1 and 100),
  customer_phone text not null check (length(customer_phone) between 6 and 30),
  items jsonb not null check (jsonb_typeof(items) = 'array'),
  total numeric not null default 0, notes text default '',
  status text not null default 'pendiente'
    check (status in ('pendiente','confirmado','en preparación','entregado','cancelado'))
);

alter table admins enable row level security;
alter table settings enable row level security;
alter table products enable row level security;
alter table offers enable row level security;
alter table orders enable row level security;

create policy "admin ve su fila" on admins for select using (lower(email) = lower(coalesce(auth.jwt()->>'email','')));
create policy "settings lectura publica" on settings for select using (true);
create policy "settings admin" on settings for all using (is_admin()) with check (is_admin());
create policy "productos lectura" on products for select using (active or is_admin());
create policy "productos admin" on products for all using (is_admin()) with check (is_admin());
create policy "ofertas lectura" on offers for select using (active or is_admin());
create policy "ofertas admin" on offers for all using (is_admin()) with check (is_admin());
-- Clientes anónimos solo pueden CREAR pedidos (en estado pendiente); nunca leerlos.
create policy "pedido publico" on orders for insert to anon, authenticated
  with check (status = 'pendiente' and jsonb_typeof(items) = 'array');
create policy "pedidos admin" on orders for all using (is_admin()) with check (is_admin());

-- Fotos
insert into storage.buckets (id, name, public) values ('images', 'images', true) on conflict do nothing;
create policy "fotos lectura" on storage.objects for select using (bucket_id = 'images');
create policy "fotos admin subir" on storage.objects for insert with check (bucket_id = 'images' and is_admin());
create policy "fotos admin editar" on storage.objects for update using (bucket_id = 'images' and is_admin());
create policy "fotos admin borrar" on storage.objects for delete using (bucket_id = 'images' and is_admin());

-- Administrador (creá antes el usuario en Authentication > Users con ese mismo correo)
insert into admins (email) values ('TU_CORREO') on conflict do nothing;
