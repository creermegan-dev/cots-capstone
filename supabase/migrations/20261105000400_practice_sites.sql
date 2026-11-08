-- Practice sites (user, 2026-11-05): two small temporary sites on land, to rehearse the field test
-- before the Samal trip. P1 = 75 m around the house (Santo Niño, Panabo), P2 = 200 m around DNSC.
-- They use the same version as the dive sites, so every location check treats them as real sites.
-- REMOVE AFTER THE TRIP (separate migration; practice records must be deleted first, with OK).

do $$ begin
  if exists (select 1 from public.monitoring_areas where code in ('P1','P2')) then
    raise exception 'Practice sites already exist';
  end if;
end $$;

insert into public.monitoring_areas
  (code, name, municipality, barangay, geography_version, geographic_reference, approximate_boundary, active,
   map_zone, map_area, map_part, map_reef_ha, map_barangay_psgc, map_centre_lat, map_centre_lon)
values
  ('P1', 'Practice · Home', 'Panabo City', 'Santo Niño', 'cots-samal-sites-v1',
   jsonb_build_object('zone_code','PRACTICE','practice',true,'radius_m',75,'hectares',1.9), true, true,
   'Practice', 'P1', 0, 1.9, null, 7.311361, 125.690736),
  ('P2', 'Practice · DNSC', 'Panabo City', 'New Visayas', 'cots-samal-sites-v1',
   jsonb_build_object('zone_code','PRACTICE','practice',true,'radius_m',200,'hectares',12.3), true, true,
   'Practice', 'P2', 0, 12.3, null, 7.313715, 125.670413);

create temporary table practice_cell_codes (iy integer, ix_start integer, ix_end integer, code text);
insert into practice_cell_codes values
(2620,-35,-33,'P1'),
(2621,-36,-32,'P1'),
(2622,-36,-32,'P1'),
(2623,-36,-32,'P1'),
(2624,-109,-109,'P2'),
(2624,-35,-33,'P1'),
(2625,-112,-106,'P2'),
(2626,-113,-105,'P2'),
(2627,-114,-104,'P2'),
(2628,-115,-103,'P2'),
(2629,-115,-103,'P2'),
(2630,-115,-103,'P2'),
(2631,-115,-103,'P2'),
(2632,-115,-103,'P2'),
(2633,-115,-103,'P2'),
(2634,-114,-104,'P2'),
(2635,-114,-105,'P2'),
(2636,-112,-106,'P2'),
(2637,-110,-108,'P2');

do $$ begin
  if exists (select 1 from cots_private.area_cells ac join practice_cell_codes p
             on ac.iy = p.iy and ac.ix_start <= p.ix_end and p.ix_start <= ac.ix_end) then
    raise exception 'Practice site overlaps an existing site';
  end if;
end $$;

insert into cots_private.area_cells (iy, ix_start, ix_end, area_id)
select p.iy, p.ix_start, p.ix_end, a.id from practice_cell_codes p
join public.monitoring_areas a on a.code = p.code and a.geography_version = 'cots-samal-sites-v1';
drop table practice_cell_codes;
