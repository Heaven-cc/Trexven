-- Included only inside the empty, synthetic replay transaction and fixture.
select id::text as owner from batch2_ids where key='owner' \gset
select id::text as employee from batch2_ids where key='sales_user' \gset
select id::text as other_owner from batch2_ids where key='other_owner' \gset
select id::text as business from batch2_ids where key='business' \gset
select id::text as other_business from batch2_ids where key='other_business' \gset
select set_config('request.jwt.claim.sub',:'owner',true);
set local role authenticated;
insert into public.angel_conversations(business_id,user_id,title)
 values(:'business',:'owner','Synthetic first chat') returning id::text as first_chat \gset
insert into public.angel_conversations(business_id,user_id,title)
 values(:'business',:'owner','Synthetic new chat') returning id::text as new_chat \gset
insert into public.angel_messages(conversation_id,role,content) values
 (:'first_chat','user','Synthetic question'),(:'first_chat','assistant','Synthetic reply'),
 (:'new_chat','user','Separate synthetic question');
select pg_temp.assert_true(:'first_chat'<>:'new_chat','new conversation has a distinct identity');
select pg_temp.assert_true((select count(*)=2 from public.angel_conversations where business_id=:'business' and user_id=:'owner'),'owner can reload both chats');
select pg_temp.assert_true((select count(*)=2 from public.angel_messages where conversation_id=:'first_chat'),'owner can reload persisted conversation history');
reset role;
-- Test the author restriction even when the reader owns the same business.
insert into public.angel_conversations(business_id,user_id,title)
 values(:'business',:'other_owner','Synthetic other author') returning id::text as other_author_chat \gset
insert into public.angel_messages(conversation_id,role,content)
 values(:'other_author_chat','user','Other author only');
set local role authenticated;
select pg_temp.assert_true(not exists(select from public.angel_conversations where id=:'other_author_chat'),'owner cannot read another author conversation');
select pg_temp.assert_true(not exists(select from public.angel_messages where conversation_id=:'other_author_chat'),'owner cannot read another author messages');
select pg_temp.denied(format('delete from public.angel_conversations where id=%L',:'other_author_chat'));
select set_config('request.jwt.claim.sub',:'employee',true);
select pg_temp.assert_true(not exists(select from public.angel_conversations where id=:'first_chat'),'employee cannot read owner history');
select pg_temp.assert_true(not exists(select from public.angel_messages where conversation_id=:'first_chat'),'employee cannot read owner messages');
select pg_temp.denied(format('delete from public.angel_conversations where id=%L',:'first_chat'));
select set_config('request.jwt.claim.sub',:'other_owner',true);
select pg_temp.assert_true(not exists(select from public.angel_conversations where id=:'first_chat'),'other tenant cannot read owner conversation');
select pg_temp.denied(format('delete from public.angel_conversations where id=%L',:'first_chat'));
select set_config('request.jwt.claim.sub',:'owner',true);
with deleted as (
 delete from public.angel_conversations where id=:'first_chat'
 and business_id=:'business' and user_id=:'owner' returning id
) select pg_temp.assert_true((select count(*)=1 from deleted),'frontend delete filters return one authorized row');
select pg_temp.assert_true(not exists(select from public.angel_messages where conversation_id=:'first_chat'),'authorized conversation deletion cascades messages');
select pg_temp.assert_true((select count(*)=1 from public.angel_messages where conversation_id=:'new_chat'),'deleting one conversation preserves another');
reset role;
select pg_temp.assert_true(exists(select from public.angel_conversations where id=:'other_author_chat'),'denied deletes preserve other author data');
