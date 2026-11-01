-- Stage 6: new monitoring map (zones A-V, areas, 1.1 ha parts) and location checks.
-- Synthetic people and records only; everything is rolled back.
begin;
create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions, pg_temp;
select no_plan();

create function pg_temp.uid(n integer) returns uuid language sql immutable as $$
  select ('f6000000-0000-4000-8000-' || lpad(n::text,12,'0'))::uuid
$$;
create function pg_temp.act(n integer) returns void language sql as $$
  select set_config('request.jwt.claim.sub', pg_temp.uid(n)::text, true)
$$;
create function pg_temp.area(c text) returns uuid language sql stable as $$
  select id from public.monitoring_areas where code = c and geography_version = 'cots-davao-gulf-v2'
$$;
create function pg_temp.code_at(lat double precision, lon double precision) returns text language sql stable as $$
  select code from public.monitoring_areas where id = cots_private.area_at(lat, lon)
$$;
-- A COTS photo by person o in area a at (lat, lon); lat null = no GPS.
create function pg_temp.capture(n integer, o integer, a uuid, lat double precision, lon double precision)
returns void language sql as $$
  insert into public.captures(id,owner_id,idempotency_key,area_id,captured_at,capture_time_source,
    model_name,model_sha256,source_width,source_height,latitude,longitude,gps_source)
  values(pg_temp.uid(n),pg_temp.uid(o),pg_temp.uid(n+500),a,now(),'device',
    'synthetic-test',repeat('a',64),2048,1536,lat,lon,case when lat is null then 'unavailable' else 'exif' end);
$$;

-- The map itself.
select is((select count(*)::integer from public.monitoring_areas where geography_version='cots-davao-gulf-v2' and active),17841,'17,841 parts are active');
select is((select count(*)::integer from public.monitoring_areas where geography_version='cots-davao-gulf-v1' and active),0,'The old boxes are switched off');
select is((select count(*)::integer from public.monitoring_areas where geography_version='cots-davao-gulf-v1'),75,'The old boxes are kept, not deleted');
select is((select count(distinct map_zone)::integer from public.monitoring_areas where geography_version='cots-davao-gulf-v2'),22,'22 zones');
select is((select count(distinct map_area)::integer from public.monitoring_areas where geography_version='cots-davao-gulf-v2'),196,'196 areas (one per coastal barangay)');
select is((select name from public.monitoring_areas where code='V3-12'),'V3-12 · Balet Part 12','Parts are named with code, barangay and part number');
select is((select name from public.monitoring_areas where code='K10'),'K10 · Kalbay','An area with no mapped reef is one whole part');
select is((select count(*)::integer from public.monitoring_areas a where a.geography_version='cots-davao-gulf-v2'
  and not exists(select 1 from cots_private.area_cells c where c.area_id=a.id)),0,'Every part has water in the lookup');
select is((select count(*)::integer from cots_private.area_cells),78240,'Lookup rows loaded');
select is((select count(*)::integer from cots_private.area_cells a join cots_private.area_cells b
  on a.iy=b.iy and a.ix_start<b.ix_start and a.ix_end>=b.ix_start),0,'No spot of water belongs to two parts');

-- Which part is at a location.
select is(pg_temp.code_at(6.8924738,125.7075962),'V28-67','A point inside a part finds that part');
select is(pg_temp.code_at(6.8924738,125.7078222),'V28-67','10 m outside the edge still counts (15 m GPS allowance)');
select is(pg_temp.code_at(6.8924738,125.7080935),null,'40 m outside the edge is outside every part');
select is(pg_temp.code_at(6.8908459,125.7046120),'V28-85','Next to a border, a point inside the first part finds the first part');
select is(pg_temp.code_at(6.8908459,125.7048832),'V28-86','and a point inside the neighbouring part finds the neighbour');
select is(pg_temp.code_at(7.0800000,125.7200000),null,'A point inland on Samal is in no part');
select is(pg_temp.code_at(6.8000000,125.8500000),null,'A point in deep water is in no part');

-- The app cannot read the lookup or call the check directly.
select is(has_table_privilege('authenticated','cots_private.area_cells','SELECT'),false,'The app cannot read the lookup table');
select is(has_function_privilege('authenticated','cots_private.area_at(double precision,double precision,double precision)','EXECUTE'),false,'The app cannot call the location function directly');

-- People: 1 Admin, 2 Expert, 3 Diver.
insert into auth.users(id,email,email_confirmed_at)
select pg_temp.uid(n),'stage6-' || n || '@example.invalid',now() from generate_series(1,3) n;
select public.appoint_initial_role('administrator',pg_temp.uid(1));
select public.appoint_initial_role('expert',pg_temp.uid(2));
select pg_temp.act(1);
set local role authenticated;
select public.verify_personnel(pg_temp.uid(3),true,true);
reset role;

-- Location checks on photos.
select lives_ok($$select pg_temp.capture(20,3,pg_temp.area('V28-67'),6.8924738,125.7075962)$$,'A photo inside its part is accepted');
select lives_ok($$select pg_temp.capture(21,3,pg_temp.area('V28-67'),6.8924738,125.7078222)$$,'A photo 10 m outside its part is accepted (GPS allowance)');
select throws_like($$select pg_temp.capture(22,3,pg_temp.area('V28-67'),6.8924738,125.7080935)$$,'COTS_AREA_OUTSIDE:%','A photo 40 m outside every part is refused');
select throws_like($$select pg_temp.capture(23,3,pg_temp.area('V28-67'),7.0800000,125.7200000)$$,'COTS_AREA_OUTSIDE:%','A photo on land is refused');
select throws_like($$select pg_temp.capture(24,3,pg_temp.area('V28-85'),6.8908459,125.7048832)$$,'COTS_AREA_MISMATCH:V28-86:%','A photo in the neighbouring part is refused and names that part');
select throws_like($$select pg_temp.capture(25,3,pg_temp.area('V28-67'),null,null)$$,'COTS_AREA_NO_LOCATION:%','A photo without a location is refused (Stage 7)');
select throws_like($$select pg_temp.capture(26,3,(select id from public.monitoring_areas where geography_version='cots-davao-gulf-v1' limit 1),null,null)$$,
  'COTS_AREA_INACTIVE:%','A photo for an old switched-off box is refused');
select lives_ok($$select pg_temp.capture(27,3,pg_temp.area('V28-85'),6.8908459,125.7046120)$$,'A photo in the neighbouring part, filed there, is accepted');

-- A visit and its photos must be in the visit's part.
update public.captures set status='finalized', finalized_at=now() where id=pg_temp.uid(20);
insert into public.follow_up_assignments(id,area_id,primary_diver_id,originating_capture_id)
values(pg_temp.uid(60),pg_temp.area('V28-67'),pg_temp.uid(3),pg_temp.uid(20));
create function pg_temp.visit(v integer, lat double precision, lon double precision) returns void language sql as $$
  insert into public.follow_up_surveys(id,owner_id,idempotency_key,assignment_id,captured_at,month,
    authorization_revision,latitude,longitude,gps_source,observed_count,eliminated_count,elimination_method,surveyed_area_m2,survey_date)
  values(pg_temp.uid(v),pg_temp.uid(3),pg_temp.uid(v+500),pg_temp.uid(60),now(),
    date_trunc('month', now() at time zone 'Asia/Manila')::date,0,lat,lon,
    case when lat is null then 'unavailable' else 'exif' end,0,0,'',100,(now() at time zone 'Asia/Manila')::date);
$$;
select throws_like($$select pg_temp.visit(70,6.8924738,125.7080935)$$,'COTS_AREA_OUTSIDE:%','A visit recorded outside every part is refused');
select throws_like($$select pg_temp.visit(71,6.8908459,125.7048832)$$,'COTS_AREA_MISMATCH:V28-86:%','A visit recorded in another part is refused');
select lives_ok($$select pg_temp.visit(72,6.8924738,125.7075962)$$,'A visit recorded in its part is accepted');
select lives_ok($$insert into public.survey_captures(survey_id,capture_id) values(pg_temp.uid(72),pg_temp.uid(21))$$,'A photo from the same part can be added to the visit');
select throws_like($$insert into public.survey_captures(survey_id,capture_id) values(pg_temp.uid(72),pg_temp.uid(27))$$,
  'COTS_AREA_MISMATCH:V28-85:%','A photo from another part cannot be added; it must be a separate visit');

select * from finish();
rollback;
