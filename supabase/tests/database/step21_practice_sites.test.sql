begin;
create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions, pg_temp;
select plan(8);
select is((select count(*)::int from public.monitoring_areas where code in ('P1','P2') and active and map_zone = 'Practice'), 2, 'two practice sites are active');
select is((select code from public.monitoring_areas where id = cots_private.area_at(7.311361, 125.690736)), 'P1', 'the house is inside Practice · Home');
select is((select code from public.monitoring_areas where id = cots_private.area_at(7.313715, 125.670413)), 'P2', 'DNSC is inside Practice · DNSC');
select is((select code from public.monitoring_areas where id = cots_private.area_at(7.3115, 125.6830)), null, 'between home and DNSC is outside every site');
select is((select code from public.monitoring_areas where id = cots_private.area_at(7.012384, 125.717742)), 'S2', 'Samal sites still work');
select is((select count(*)::int from cots_private.area_cells ac join public.monitoring_areas a on a.id = ac.area_id where a.code like 'P%'), 19, 'practice lookup runs');
select is(cots_private.area_short_code((select id from public.monitoring_areas where code = 'P2')), 'Practice · DNSC', 'messages use the practice site name');
insert into auth.users(id, email, email_confirmed_at)
values ('d2100000-0000-4000-8000-000000000001', 'practice-map@example.invalid', now());
select set_config('request.jwt.claim.sub', 'd2100000-0000-4000-8000-000000000001', true);
select is(jsonb_typeof(public.site_levels_json()), 'array', 'site levels still load for an active account');
select * from finish();
rollback;
