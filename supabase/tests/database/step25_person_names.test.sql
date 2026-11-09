-- Names for the Expert's pages: only full names, only for staff (or yourself). Rolled back.
begin;
create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions, pg_temp;
select no_plan();
create function pg_temp.uid(n integer) returns uuid language sql immutable as $$
  select ('d2500000-0000-4000-8000-' || lpad(n::text,12,'0'))::uuid
$$;
create function pg_temp.names_as(n integer) returns jsonb language plpgsql as $$
declare j jsonb;
begin
  perform set_config('request.jwt.claim.sub', pg_temp.uid(n)::text, true);
  set local role authenticated;
  j := public.person_names_json(array[pg_temp.uid(3), pg_temp.uid(4)]);
  reset role;
  return j;
end $$;
insert into auth.users(id,email,email_confirmed_at)
select pg_temp.uid(n),'names-' || n || '@example.invalid',now() from generate_series(1,4) n;
update public.profiles set full_name = 'Diver Three' where id = pg_temp.uid(3);
update public.profiles set full_name = 'Diver Four' where id = pg_temp.uid(4);
select public.appoint_initial_role('administrator',pg_temp.uid(1));
select public.appoint_initial_role('expert',pg_temp.uid(2));

select is(jsonb_array_length(pg_temp.names_as(2)), 2, 'The Expert gets the Divers'' names');
select ok(pg_temp.names_as(2)::text like '%Diver Three%', 'with the full name');
select ok(pg_temp.names_as(2)::text not like '%@example%', 'and no email');
select is(jsonb_array_length(pg_temp.names_as(1)), 2, 'The Administrator gets them too');
select is(jsonb_array_length(pg_temp.names_as(3)), 1, 'A Diver gets only their own name');
select ok(pg_temp.names_as(3)::text not like '%Diver Four%', 'not other Divers''');
select ok(not has_function_privilege('anon','public.person_names_json(uuid[])','EXECUTE'), 'Visitors cannot use it');
select * from finish();
rollback;
