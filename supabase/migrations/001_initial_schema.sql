create extension if not exists "pgcrypto";

create type public.user_role as enum ('customer','staff','admin');
create type public.vehicle_condition as enum ('new','used','certified');
create type public.vehicle_status as enum ('draft','available','reserved','sold','unavailable');

create table public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  full_name text,
  phone text,
  role public.user_role not null default 'customer',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.brands (
  id uuid primary key default gen_random_uuid(),
  name text not null unique,
  slug text not null unique,
  created_at timestamptz not null default now()
);

create table public.vehicles (
  id uuid primary key default gen_random_uuid(),
  brand_id uuid references public.brands(id) on delete set null,
  make text not null,
  model text not null,
  trim text,
  slug text not null unique,
  year integer not null check (year >= 1900),
  price numeric(14,2) not null check (price >= 0),
  mileage integer not null default 0 check (mileage >= 0),
  vin text unique,
  stock_number text unique,
  body_type text,
  fuel_type text,
  transmission text,
  drivetrain text,
  engine text,
  horsepower integer,
  exterior_color text,
  interior_color text,
  condition public.vehicle_condition not null default 'used',
  description text,
  location text,
  status public.vehicle_status not null default 'draft',
  featured boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.vehicle_images (
  id uuid primary key default gen_random_uuid(),
  vehicle_id uuid not null references public.vehicles(id) on delete cascade,
  storage_path text not null,
  alt_text text,
  sort_order integer not null default 0,
  is_primary boolean not null default false,
  created_at timestamptz not null default now()
);

create table public.favorites (
  user_id uuid not null references auth.users(id) on delete cascade,
  vehicle_id uuid not null references public.vehicles(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (user_id, vehicle_id)
);

create table public.test_drive_bookings (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references auth.users(id) on delete set null,
  vehicle_id uuid not null references public.vehicles(id) on delete restrict,
  full_name text not null,
  email text not null,
  phone text not null,
  preferred_date date not null,
  preferred_time time not null,
  location text,
  notes text,
  status text not null default 'pending' check (status in ('pending','confirmed','completed','cancelled')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index vehicles_status_idx on public.vehicles(status);
create index vehicles_brand_idx on public.vehicles(brand_id);
create index vehicles_price_idx on public.vehicles(price);
create index vehicles_year_idx on public.vehicles(year);
create index test_drive_vehicle_date_idx on public.test_drive_bookings(vehicle_id, preferred_date);

alter table public.profiles enable row level security;
alter table public.brands enable row level security;
alter table public.vehicles enable row level security;
alter table public.vehicle_images enable row level security;
alter table public.favorites enable row level security;
alter table public.test_drive_bookings enable row level security;

create policy "public can view active brands" on public.brands for select to anon, authenticated using (true);
create policy "public can view available vehicles" on public.vehicles for select to anon, authenticated using (status in ('available','reserved'));
create policy "public can view vehicle images" on public.vehicle_images for select to anon, authenticated using (exists (select 1 from public.vehicles v where v.id=vehicle_id and v.status in ('available','reserved')));

create policy "users can view own profile" on public.profiles for select to authenticated using ((select auth.uid())=id);
create policy "users can update own profile" on public.profiles for update to authenticated using ((select auth.uid())=id) with check ((select auth.uid())=id);

create policy "users manage own favorites" on public.favorites for all to authenticated using ((select auth.uid())=user_id) with check ((select auth.uid())=user_id);
create policy "users view own test drives" on public.test_drive_bookings for select to authenticated using ((select auth.uid())=user_id);
create policy "users create test drives" on public.test_drive_bookings for insert to authenticated with check ((select auth.uid())=user_id);
