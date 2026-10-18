"""Pure SQL renderer. Does not connect, deploy, or alter canonical migrations."""
import re

def render(path, expected_history):
    text = path.read_text(encoding='utf-8-sig')
    starts = list(re.finditer(r'^begin;\s*$',text,re.M|re.I))
    finishes = list(re.finditer(r'^commit;\s*$',text,re.M|re.I))
    assert len(starts)==1 and len(finishes)==1 and finishes[0].end()==len(text), 'Single reviewed transaction required'
    version,name = path.stem.split('_',1)
    assert version not in expected_history
    expected = 'array['+','.join("'"+v+"'" for v in sorted(expected_history))+']::text[]'
    guard = """
-- Release history guard and history insert are in the SAME transaction as DDL.
select pg_advisory_xact_lock(hashtextextended('trexven:coordinated-release',0));
do $trexven_history_guard$ begin
 if (select array_agg(version order by version) from supabase_migrations.schema_migrations)
    is distinct from EXPECTED_HISTORY then
  raise exception 'TREXVEN predecessor history mismatch; no migration changes committed';
 end if;
end $trexven_history_guard$;
""".replace('EXPECTED_HISTORY',expected)
    tag = '$trexven_release_source$'
    assert tag not in text
    history = ("insert into supabase_migrations.schema_migrations(version,name,statements) values ("
      +"'"+version+"','"+name+"',array["+tag+text+tag+"]::text[]);\n")
    return text[:starts[0].end()]+guard+text[starts[0].end():finishes[0].start()]+history+text[finishes[0].start():]
