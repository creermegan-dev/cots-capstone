# Samal trip plan: field test + defense video (2026-11-06)

Written 2026-11-05 19:30. Nothing in the app or database was changed for this plan.

## Map colours
- Site level (COTS per hectare): **Low <=15 = green**, **Moderate 16-100 = orange**, **High >100 = red**, **No data yet = grey**.
- Record dots: **red = confirmed COTS**, **orange = waiting for the Expert**.
- Your own sites have a dark border and "Your site".

## Tonight: rehearse at Practice · Home or Practice · DNSC
1. Sync the action camera clock to the phone.
2. Take photos with the camera, move them to the phone, submit inside the practice site.
3. Expert confirms; check the red dot and the site colour on the map.
4. **Offline test:** airplane mode inside the practice site -> submit (should say
   "saved on this device and pending synchronization") -> walk out of the circle (100+ m)
   -> turn data on -> wait a minute -> check the record arrives and the Expert sees it.

What the code does (read 2026-11-05, not yet tested on a phone): an offline record is saved
on the phone together with the location taken at submit time, and the app retries every few
minutes and when it comes back online. The database only checks that the saved location is
inside a site; the 2-hour photo rule is checked on the phone at submit time. So a record
submitted offline at the site should be accepted later. The test above confirms it.

## Bring
- 3 phones signed in and trusted: Diver, Expert, Admin (Admin can be filmed on land/laptop).
- Power banks, mobile data, waterproof pouch for the phone.

## Shots to film (in order)
1. **Arrival:** Diver's map, blue location dot inside the site; say date and place.
2. **The dive:** underwater footage of photographing COTS.
3. **Submit at the surface (most important):** move photos to the phone, submit while still
   over the site. Show the AI count, the site name found automatically, location "Phone GPS",
   with the sea in frame.
4. **Expert verification:** "Needs your action" -> review photos -> confirm or correct the count.
5. **Result:** Diver sees the record confirmed, red dot on the map, site colour changes.
6. **Admin view:** all records, site details, reports (can be filmed on land).
7. **Refusal proof (optional):** at the pier/outside a site, try to submit -> refused
   "outside every dive site".
8. **Optional extras:** removal record (only if the Expert/permit allows), site partner invite
   (invite -> accept -> Expert approves), monthly visit page.

## Tips
- Film each clip twice: phone screen recording (clear app) + someone filming the phone with
  the sea behind it (proof of place).
- Check the signal at the site. No signal -> submit offline (see test above).
- Submit within 2 hours of taking the photos.
- Free fallback if anything fails: run a GPS tracking app during the dive, later write GPS
  into the photos with GeoSetter/ExifTool, then submit (uses the photo's own GPS).
- Samal records are real data and stay. Only practice records get deleted after the trip
  (with OK), together with the practice sites.
