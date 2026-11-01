-- Stage 7: every photo needs a location (agreed 2026-11-01, option B).
-- The app uses the photo's own GPS, or the phone's GPS for photos taken within the last hour.
-- The database now refuses a photo without a location for the new map (old and test areas are not checked).
CREATE OR REPLACE FUNCTION cots_private.check_capture_area()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare a public.monitoring_areas; found uuid;
begin
  select * into a from public.monitoring_areas where id = new.area_id;
  if not a.active then
    raise exception 'COTS_AREA_INACTIVE: This monitoring area is no longer used. Please update the app.' using errcode = '23514';
  end if;
  if a.geography_version = 'cots-davao-gulf-v2' and new.latitude is null then
    raise exception 'COTS_AREA_NO_LOCATION: A location is required. Turn on location, or use a photo that has GPS.' using errcode = '23514';
  end if;
  if a.geography_version = 'cots-davao-gulf-v2' and new.latitude is not null then
    found := cots_private.area_at(new.latitude::double precision, new.longitude::double precision);
    if found is null then
      raise exception 'COTS_AREA_OUTSIDE: This photo''s location is outside every monitoring area (on land or in deep water).' using errcode = '23514';
    elsif found <> new.area_id then
      raise exception 'COTS_AREA_MISMATCH:%: This photo was taken in %, not %.', cots_private.area_short_code(found),
        cots_private.area_short_code(found), a.code using errcode = '23514';
    end if;
  end if;
  return new;
end $function$;
