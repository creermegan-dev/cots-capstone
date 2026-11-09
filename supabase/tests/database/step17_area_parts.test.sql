-- Location checks (Stages 6-7) on the Stage 9 map: the 3 Samal dive sites.
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
  select id from public.monitoring_areas where code = c and geography_version = 'cots-samal-sites-v1'
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
select is((select count(*)::integer from public.monitoring_areas where geography_version='cots-samal-sites-v1' and map_zone='Samal' and active),4,'4 sites are active');
select is((select count(*)::integer from public.monitoring_areas where geography_version in ('cots-davao-gulf-v1','cots-davao-gulf-v2')),0,'The old Davao Gulf map is deleted');
select is((select string_agg(name, ', ' order by code) from public.monitoring_areas where geography_version='cots-samal-sites-v1' and map_zone='Samal'),
  'Site 1 · Tambo, Site 2 · Adecor, Site 3 · Linosutan, Site 4 · Balet','Sites are named with number and barangay');
select is((select count(distinct map_zone)::integer from public.monitoring_areas where geography_version='cots-samal-sites-v1' and map_zone='Samal'),1,'One zone (Samal)');
select is((select count(*)::integer from public.monitoring_areas where geography_version='cots-samal-sites-v1' and map_zone='Samal' and map_part=0),4,'Sites have no parts');
select is((select count(*)::integer from public.monitoring_areas a where a.geography_version='cots-samal-sites-v1'
  and not exists(select 1 from cots_private.area_cells c where c.area_id=a.id)),0,'Every site has water in the lookup');
select is((select count(*)::integer from cots_private.area_cells c join public.monitoring_areas a on a.id=c.area_id where a.map_zone='Samal'),640,'Lookup rows loaded');
select is((select count(*)::integer from cots_private.area_cells c join public.monitoring_areas a on a.id=c.area_id
  where a.geography_version<>'cots-samal-sites-v1'),0,'The lookup only points to the 3 sites');
select is((select count(*)::integer from cots_private.area_cells a join cots_private.area_cells b
  on a.iy=b.iy and a.ix_start<b.ix_start and a.ix_end>=b.ix_start),0,'No spot of water belongs to two sites');

-- Which site is at a location.
select is(pg_temp.code_at(7.1616148,125.6839938),'S1','A point inside Site 1 finds Site 1');
select is(pg_temp.code_at(7.0123935,125.7183122),'S2','A point inside Site 2 finds Site 2');
select is(pg_temp.code_at(6.9198763,125.6819591),'S3','A point inside Site 3 finds Site 3');
select is(pg_temp.code_at(6.9198763,125.6791558),'S3','10 m past the edge still counts (15 m GPS allowance)');
select is(pg_temp.code_at(6.9198763,125.6788845),null,'40 m past the edge is outside every site');
select is(pg_temp.code_at(7.0800000,125.7200000),null,'A point inland on Samal is in no site');
select is(pg_temp.code_at(7.3000000,125.7000000),null,'A point in the old Panabo zone is in no site');

-- The app cannot read the lookup or call the check directly.
select is(has_table_privilege('authenticated','cots_private.area_cells','SELECT'),false,'The app cannot read the lookup table');
select is(has_function_privilege('authenticated','cots_private.area_at(double precision,double precision,double precision)','EXECUTE'),false,'The app cannot call the location function directly');

-- People: 1 Admin, 2 Expert, 3 Diver.
insert into auth.users(id,email,email_confirmed_at)
select pg_temp.uid(n),'stage9-' || n || '@example.invalid',now() from generate_series(1,3) n;
select public.appoint_initial_role('administrator',pg_temp.uid(1));
select public.appoint_initial_role('expert',pg_temp.uid(2));
select pg_temp.act(1);
set local role authenticated;
select set_config('request.jwt.claim.sub',pg_temp.uid(2)::text,true);
select public.verify_personnel(pg_temp.uid(3),true,true);
select set_config('request.jwt.claim.sub',pg_temp.uid(1)::text,true);
reset role;

-- Location checks on photos.
select lives_ok($$select pg_temp.capture(20,3,pg_temp.area('S3'),6.9198763,125.6819591)$$,'A photo inside its site is accepted');
select lives_ok($$select pg_temp.capture(21,3,pg_temp.area('S3'),6.9198763,125.6791558)$$,'A photo 10 m past its site is accepted (GPS allowance)');
select throws_like($$select pg_temp.capture(22,3,pg_temp.area('S3'),6.9198763,125.6788845)$$,'COTS_AREA_OUTSIDE:%every site%','A photo 40 m past every site is refused');
select throws_like($$select pg_temp.capture(23,3,pg_temp.area('S2'),7.0800000,125.7200000)$$,'COTS_AREA_OUTSIDE:%','A photo on land is refused');
select throws_like($$select pg_temp.capture(24,3,pg_temp.area('S1'),7.0123935,125.7183122)$$,
  'COTS_AREA_MISMATCH:S2: This photo was taken in Site 2 · Adecor, not Site 1 · Tambo.','A photo in another site is refused and names that site');
select throws_like($$select pg_temp.capture(25,3,pg_temp.area('S1'),null,null)$$,'COTS_AREA_NO_LOCATION:%','A photo without a location is refused (Stage 7)');
select lives_ok($$select pg_temp.capture(27,3,pg_temp.area('S2'),7.0123935,125.7183122)$$,'A photo in Site 2, filed there, is accepted');

-- A visit and its photos must be in the visit's site.
update public.captures set status='finalized', finalized_at=now() where id=pg_temp.uid(20);
insert into public.follow_up_assignments(id,area_id,primary_diver_id,originating_capture_id)
values(pg_temp.uid(60),pg_temp.area('S3'),pg_temp.uid(3),pg_temp.uid(20));
create function pg_temp.visit(v integer, lat double precision, lon double precision) returns void language sql as $$
  insert into public.follow_up_surveys(id,owner_id,idempotency_key,assignment_id,captured_at,month,
    authorization_revision,latitude,longitude,gps_source,observed_count,eliminated_count,elimination_method,surveyed_area_m2,survey_date)
  values(pg_temp.uid(v),pg_temp.uid(3),pg_temp.uid(v+500),pg_temp.uid(60),now(),
    date_trunc('month', now() at time zone 'Asia/Manila')::date,0,lat,lon,
    case when lat is null then 'unavailable' else 'exif' end,0,0,'',100,(now() at time zone 'Asia/Manila')::date);
$$;
select throws_like($$select pg_temp.visit(70,6.9198763,125.6788845)$$,'COTS_AREA_OUTSIDE:%','A visit recorded outside every site is refused');
select throws_like($$select pg_temp.visit(71,7.0123935,125.7183122)$$,'COTS_AREA_MISMATCH:S2:%','A visit recorded in another site is refused');
select lives_ok($$select pg_temp.visit(72,6.9198763,125.6819591)$$,'A visit recorded in its site is accepted');
select lives_ok($$insert into public.survey_captures(survey_id,capture_id) values(pg_temp.uid(72),pg_temp.uid(21))$$,'A photo from the same site can be added to the visit');
select throws_like($$insert into public.survey_captures(survey_id,capture_id) values(pg_temp.uid(72),pg_temp.uid(27))$$,
  'COTS_AREA_MISMATCH:S2:%','A photo from another site cannot be added; it must be a separate visit');

select * from finish();
rollback;
