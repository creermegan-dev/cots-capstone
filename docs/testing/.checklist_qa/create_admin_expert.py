from pathlib import Path
from docx import Document
from docx.shared import Inches, Pt, RGBColor
from docx.oxml import OxmlElement

ROOT = Path('C:/dev/Capstone Flutter/docs/testing')
OUT = ROOT / 'COTS_Monitor_Admin_and_Expert_Testing_Checklist.docx'
admin = [
('Dashboard totals and navigation', 'Admin account and existing records', [
'Open the dashboard and record the totals and selected period.',
'Compare recent submissions with the Records page using the same scope.',
'Open a recent submission and confirm the correct record appears.']),
('Search filters and pagination', 'Admin account and several records', [
'Search for an existing submission ID, then try a value with no matches.',
'Combine the available site, status and date filters; check every visible result.',
'Clear filters and change pages; confirm no rows are skipped or repeated.']),
('Grouped submission details', 'A submission containing multiple photos', [
'Open the submission and switch through every photo in the selector.',
'Check that the image, boxes, GPS, date and model belong to the selected photo.',
'Compare the submission totals with the individual photo results.']),
('Admin has no verification decisions', 'Admin account and pending test records', [
'Open pending and reviewed submissions and inspect the available controls.',
'Confirm Admin cannot approve or reject COTS or verify field personnel.',
'Confirm Admin cannot approve partnerships, temporary coverage or handovers.']),
('Site directory and details', 'Admin account', [
'Check that Tambo, Adecor, Linosutan and Balet display their site names.',
'Search and sort the directory, then open View site for each site.',
'Check that the map, reports and latest dates belong to that site; no reports must not imply zero COTS.']),
('Map controls and record markers', 'Admin account and mapped records', [
'Switch the map view and month; confirm the controls remain usable.',
'Tap a site and check it zooms to the selected boundary; open a record marker.',
'Switch between map and satellite; confirm records and boundaries remain aligned.']),
('Analytics totals and site levels', 'Admin account and a month with records', [
'Choose a month and site where filters are available; note the selected scope.',
'Compare confirmed and waiting totals with records for that same scope.',
'Check monthly levels use confirmed COTS counts, with Low green, Moderate orange and High red.']),
('Model comparison in Admin analytics', 'Records from YOLOv8, YOLO11 and YOLO26', [
'Find the model comparison section and check all models with records are represented.',
'Open sample records and compare their saved model names with the table.',
'Confirm counts follow the selected scope and historical unknown models are not silently relabeled.']),
('Report preview and exported PDF', 'Admin account and a PDF viewer', [
'Create a report for a month and site containing records.',
'Export and open the PDF; compare its totals, site names and period with the preview.',
'Confirm the Admin model comparison appears consistently in preview and PDF where model data is available.']),
('Empty period and report retry', 'Admin account', [
'Create a report for a period with no records; check it shows an empty result.',
'Switch back to a period with records; confirm old values are replaced correctly.',
'If a timeout occurs, capture it and use Retry; confirm the page recovers without duplicate output.']),
('No COTS survey in monitoring records', 'An existing genuine no COTS survey', [
'Find the survey in monitoring records and open its details.',
'Confirm it is clearly a Diver observation with its own site, survey time and location.',
'Check that it completes the relevant visit without requiring Expert approval or erasing confirmed COTS totals.']),
('Preferences and notifications', 'Admin account and available settings', [
'Change a harmless preference, save it, reopen Settings and check persistence.',
'Restore the original preference and confirm the saved value survives reopening.',
'Check notification controls show their actual state; treat email delivery as Blocked until its server setup is confirmed.']),
]
expert = [
('Dashboard work queue', 'Expert account and pending work', [
'Open the dashboard and compare pending counts with the Verification page.',
'Open a dashboard work item and confirm it leads to the correct record or request.',
'Refresh after a test decision and check the work queue updates.']),
('Verification search and filters', 'Expert account and mixed record statuses', [
'Search for a known submission and then a value with no matches.',
'Use the available status, site and date filters; check the visible rows.',
'Clear filters and move between pages; confirm the full list returns.']),
('Photo selector and review controls', 'A grouped submission requiring review', [
'Open the submission and switch through all photos.',
'Check the image, boxes, information and review controls follow the selected photo.',
'Confirm a photo needing an Expert decision has an appropriate action or a clear reason it cannot yet be reviewed.']),
('Accept and reject individual detections', 'A pending practice record with multiple COTS', [
'Accept one detection and reject another using the normal review controls.',
'Save the decision, reopen the record and confirm both decisions persist.',
'Check Expert accepted boxes are green and rejected boxes red; AI accepted stays blue and waiting stays orange.']),
('Grouped record waits for remaining reviews', 'A batch with more than one photo requiring review', [
'Complete one photo review while leaving another required review unfinished.',
'Confirm the grouped record does not become fully accepted prematurely.',
'Complete the remaining review and check the final status and confirmed count match every saved decision.']),
('AI accepted photo and submission state', 'A batch with AI accepted photos and a waiting status', [
'Compare each photo status with the grouped submission status.',
'Check whether pending evidence or eligibility review explains any difference.',
'Record unexplained Processing evidence states with the submission ID; do not assume waiting alone resolves them.']),
('Personnel verification lists', 'An authorized unverified practice Diver account', [
'Find the Diver in Personnel Verification using search.',
'Check credentials and verify the practice account through the normal workflow.',
'Confirm it moves to the verified list and the status persists after reopening; check another account with the same search.']),
('Partner request approval', 'Main Diver, invited Diver and Expert test accounts', [
'Have the Main Diver invite a partner and the invited Diver accept.',
'Open Partner requests and confirm the correct people and site before approval.',
'Approve the practice request; confirm both Divers see the team and no duplicate pending request remains.']),
('Temporary coverage', 'A genuine practice coverage request and eligible replacement', [
'Open Temporary coverage and check the site, requested month and reason.',
'Assign a verified replacement and have that Diver accept through the normal flow.',
'Confirm coverage is for the correct month and acceptance is separate from completing a monitoring visit.']),
('Site handover and assignment overview', 'A practice site and authorized handover participants', [
'Review the handover site, current Diver and proposed replacement before acting.',
'Complete the available acceptance and Expert decision steps in their normal order.',
'Check Overview and both Diver accounts show the resulting team; old evidence must remain attached to its original submitter.']),
('Expert map reports and time', 'Expert account and a PDF viewer', [
'Tap a site on Map Monitoring; check zoom, month selection and satellite view.',
'Create and export a report; compare it with the preview for the same month and site.',
'Check known timestamps use Philippine time and Expert reports do not include the Admin model comparison.']),
('Notifications and decision propagation', 'Expert and Diver accounts with a practice decision', [
'Make one authorized practice review decision, then refresh the Diver record.',
'Confirm the status, confirmed count and bounding box colors match the Expert decision.',
'Check unread indicators, available category filters and Mark all as read; test Clear all only on disposable practice notifications.']),
]

doc = Document()
s = doc.sections[0]
s.page_width, s.page_height = Inches(8.5), Inches(11)
s.top_margin = s.bottom_margin = Inches(.65)
s.left_margin = s.right_margin = Inches(.7)
for name, size in [('Normal',11),('Title',23),('Heading 1',15),('Heading 2',12)]:
 st=doc.styles[name]; st.font.name='Calibri'; st.font.size=Pt(size); st.font.color.rgb=RGBColor(0,0,0)
 st.paragraph_format.space_after=Pt(5)
doc.styles['Normal'].paragraph_format.line_spacing=1.04
doc.styles['Heading 2'].paragraph_format.space_before=Pt(10)
f=s.footer.paragraphs[0]; f.alignment=2
f.add_run('Page '); field=OxmlElement('w:fldSimple'); field.set('{http://schemas.openxmlformats.org/wordprocessingml/2006/main}instr','PAGE'); f._p.append(field)
doc.core_properties.title='COTS Monitor Admin and Expert Testing Checklist'
doc.add_paragraph('COTS Monitor Admin and Expert Testing Checklist','Title')
doc.add_paragraph('Remote checks for reports permissions and review decisions','Subtitle')
doc.add_paragraph('Use this checklist to test the Admin and Expert roles separately. Record actual outcomes and evidence. A checklist describes what to check; it does not certify that a feature already passed.')
doc.add_paragraph('Prepared 11 November 2026 | Philippine time')
for text in ['Tester ____________________  Date and time ____________________', 'Device and Android version ___________________________________', 'App build __________________  Last update ____________________', 'Account role _______________  Connection ______________________']:
 doc.add_paragraph(text)
doc.add_paragraph('Working remotely','Heading 1')
for text in [
'Most read-only checks can be done on a phone using the installed app. Use screenshots and record IDs to report problems; USB logs can wait until laptop access is available.',
'Partner, coverage and handover tests need another authorized tester or separate test accounts. Mark Blocked when you lack an account, pending request, genuine survey or required device access.',
'Use practice records for decisions. Do not alter genuine monitoring decisions just to test a button. Do not delete records, uninstall the app, clear app data or change the phone clock.',
'New APK changes are available only after that build is installed. Note your build before comparing behavior across devices. Never include passwords or keys in evidence.'
]: doc.add_paragraph(text)
doc.add_paragraph('How to record results','Heading 1')
doc.add_paragraph('Use Pass, Fail, Blocked or Not tested. For a failure, capture the screen and note the exact Philippine time, role, site, record ID and steps. The last page provides an issue report form.')
doc.add_paragraph('Start with Admin A4 and A9, then Expert E3, E4 and E5. These cover role boundaries, exported reports and review results.')

def test(code, item):
 title, needs, steps=item
 doc.add_paragraph(code+'  '+title,'Heading 2')
 p=doc.add_paragraph(); p.add_run('Needs: ').bold=True; p.add_run(needs)
 for step in steps: doc.add_paragraph('[ ]  '+step)
 doc.add_paragraph('Result ________________  Evidence or record ID __________________')
 doc.add_paragraph('Notes _______________________________________________________')

for role, data, prefix in [('Admin',admin,'A'),('Expert',expert,'E')]:
 for start in range(0,12,4):
  doc.add_page_break()
  doc.add_paragraph(role+' checklist '+str(start+1)+' to '+str(start+4),'Heading 1')
  for i in range(start,start+4): test(prefix+str(i+1),data[i])
doc.add_page_break()
doc.add_paragraph('Issue report and session summary','Heading 1')
doc.add_paragraph('Complete one report per failure. Keep screenshots free of passwords and other private account information.')
for label in ['Test code and title','Role and app build','Site and submission or record ID','Exact Philippine date and time','Connection and device','Steps that caused the issue','Expected result','Actual result','Screenshot or video reference']:
 doc.add_paragraph(label); doc.add_paragraph('____________________________________________________________')
doc.add_paragraph('Session totals','Heading 1')
doc.add_paragraph('Admin   Pass ____  Fail ____  Blocked ____  Not tested ____')
doc.add_paragraph('Expert  Pass ____  Fail ____  Blocked ____  Not tested ____')
doc.add_paragraph('Next checks or people needed __________________________________')
for style in doc.styles:
 for border in style.element.xpath('.//w:pBdr'): border.getparent().remove(border)
for p in doc.paragraphs:
 for border in p._p.xpath('.//w:pBdr'): border.getparent().remove(border)
for name in ['Subtitle']:
 doc.styles[name].font.color.rgb=RGBColor(0,0,0)
OUT.parent.mkdir(parents=True,exist_ok=True)
doc.save(OUT)
print(OUT)
