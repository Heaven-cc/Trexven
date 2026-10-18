alter table public.audit_logs alter column actor_id drop not null;

alter table public.audit_logs
  drop constraint if exists audit_logs_actor_id_fkey,
  add constraint audit_logs_actor_id_fkey
    foreign key (actor_id) references auth.users(id) on delete set null;

alter table public.audit_logs
  drop constraint if exists audit_logs_target_id_fkey,
  add constraint audit_logs_target_id_fkey
    foreign key (target_id) references public.employees(id) on delete set null;
