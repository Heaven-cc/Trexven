-- Installed clients sort every operations repository by id. Keep sale_id as
-- Filename aligned with the verified production migration identity.
-- the canonical primary key and expose a read-only alias for those clients.
alter table public.credit_accounts add column id uuid generated always as (sale_id) stored;
comment on column public.credit_accounts.id is 'Compatibility alias for legacy readers; sale_id remains the canonical account identity.';
