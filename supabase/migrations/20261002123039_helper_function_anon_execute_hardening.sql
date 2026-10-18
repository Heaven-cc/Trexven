revoke execute on function public.is_business_member(uuid) from public, anon;
revoke execute on function public.user_owns_business(uuid) from public, anon;
grant execute on function public.is_business_member(uuid) to authenticated;
grant execute on function public.user_owns_business(uuid) to authenticated;
