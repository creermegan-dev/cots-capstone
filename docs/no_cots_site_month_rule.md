# No COTS survey rule

A no-COTS survey records what the Diver observed during that visit. It is not a declaration that the site contains no COTS for the rest of the month.

## Validation

- Calendar months use Philippine time, based on the survey or photo capture time.
- The first no-COTS survey is allowed only before a COTS photo report has been successfully submitted for that site and month.
- Only one new no-COTS survey is allowed per site and month, across all Divers and both initial and monthly entry points.
- A later COTS photo report is allowed. Its normal eligibility, evidence verification and Expert review rules remain in force.
- A photo reservation without uploaded linked evidence is not a successful COTS report.
- Retrying the exact original survey ID and contents remains idempotent, including after later detections or coverage changes.
- A conflict is shown as a refusal, not a successful survey. A retained local draft explains why it was refused. An offline draft is not proof that the server accepted it.
- Both observation outcomes still count as monthly visit completion. No-COTS surveys never reset confirmed COTS totals or create assignments.

## Data dictionary changes

No new tables or stored columns are introduced by this rule.

For `no_cots_surveys`, document the new insert validation across `area_id` and `month`. Existing historical duplicates are preserved; this is a trigger-enforced rule for new inserts, not a new unique index.

`no_cots_surveys_json` adds the derived boolean `cots_reported_later`. It is a response field, not a stored column. It allows the app to identify an earlier no-COTS observation when COTS reports exist for that same site and month. It does not rewrite the observation or expose another Diver's private record details.

Server refusal codes: `NC001` means a no-COTS survey already exists for the site and month. `NC002` means COTS have already been reported for that site and month.

## Records and Monthly visits

Records includes no-COTS surveys alongside photo submissions, sorted by submission time. Loaded surveys remain visible during refresh failures. The survey loader stays mounted while the record list scrolls.

Monthly visits retains the completed visit. When COTS are reported later, both screens label the survey as an earlier observation and show that COTS were reported later that month. History and COTS totals are preserved.
