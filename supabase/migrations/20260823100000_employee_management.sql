-- ============================================================================
-- EMPLOYEE MANAGEMENT SYSTEM
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 1. EMPLOYEES TABLE
-- Stores employment details. Auth credentials remain in auth.users.
-- ----------------------------------------------------------------------------
create table if not exists public.employees (
    id uuid primary key default gen_random_uuid(),
    business_id uuid not null references public.businesses(id) on delete cascade,
    user_id uuid references auth.users(id) on delete set null,
    name text not null,
    email text,
    phone text,
    role text not null check (role in ('owner', 'manager', 'sales_employee', 'inventory_employee', 'employee')),
    employee_code text unique not null, -- format: TRX-EMP-XXXXXX
    status text not null default 'active' check (status in ('active', 'suspended', 'inactive', 'terminated')),
    created_at timestamptz default now(),
    updated_at timestamptz default now()
);

-- ----------------------------------------------------------------------------
-- 2. AUDIT LOGS
-- Tracks sensitive actions (employee creation, status changes, password resets).
-- ----------------------------------------------------------------------------
create table if not exists public.audit_logs (
    id uuid primary key default gen_random_uuid(),
    business_id uuid not null references public.businesses(id) on delete cascade,
    actor_id uuid not null references auth.users(id), -- The user performing the action
    target_id uuid references public.employees(id), -- The employee affected
    action text not null,
    metadata jsonb default '{}'::jsonb,
    created_at timestamptz default now()
);

-- ----------------------------------------------------------------------------
-- 3. PERMISSIONS (GRANULAR)
-- ----------------------------------------------------------------------------
create table if not exists public.permissions (
    id text primary key, -- e.g. 'pos_access', 'manage_inventory'
    description text
);

insert into public.permissions (id, description) values
    ('pos_access', 'Access Trexven POS'),
    ('complete_sales', 'Process and complete transactions'),
    ('add_products', 'Add new products to inventory'),
    ('edit_products', 'Modify existing product details'),
    ('view_inventory', 'View stock levels and reports'),
    ('manage_employees', 'Add, edit, or suspend employees'),
    ('view_camera_events', 'Access security camera feed and events')
on conflict (id) do nothing;

create table if not exists public.employee_permissions (
    employee_id uuid references public.employees(id) on delete cascade,
    permission_id text references public.permissions(id) on delete cascade,
    primary key (employee_id, permission_id)
);

-- ----------------------------------------------------------------------------
-- 4. RLS POLICIES
-- ----------------------------------------------------------------------------
alter table public.employees enable row level security;
alter table public.audit_logs enable row level security;
alter table public.employee_permissions enable row level security;

-- Employees: Owners can view all employees in their business.
-- Employees can view their own record.
create policy "Owners can view business employees"
    on public.employees for select
    using (
        exists (
            select 1 from public.businesses
            where id = public.employees.business_id
            and owner_id = auth.uid()
        )
        or user_id = auth.uid()
    );

create policy "Owners can insert employees"
    on public.employees for insert
    with check (
        exists (
            select 1 from public.businesses
            where id = public.employees.business_id
            and owner_id = auth.uid()
        )
    );

create policy "Owners can update employees"
    on public.employees for update
    using (
        exists (
            select 1 from public.businesses
            where id = public.employees.business_id
            and owner_id = auth.uid()
        )
    );

-- Audit Logs: Only owners can view.
create policy "Owners can view audit logs"
    on public.audit_logs for select
    using (
        exists (
            select 1 from public.businesses
            where id = public.audit_logs.business_id
            and owner_id = auth.uid()
        )
    );

-- ----------------------------------------------------------------------------
-- 5. REALTIME
-- ----------------------------------------------------------------------------
DO $$
BEGIN
  ALTER PUBLICATION supabase_realtime
  ADD TABLE public.employees;
EXCEPTION
  WHEN duplicate_object THEN
    NULL;
END $$;
