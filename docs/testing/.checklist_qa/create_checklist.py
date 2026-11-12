from pathlib import Path
from docx import Document
from docx.shared import Inches, Pt, RGBColor
from docx.oxml import OxmlElement
from docx.oxml.ns import qn

OUT = Path('C:/dev/Capstone Flutter/docs/testing/COTS_Monitor_Remote_Testing_Checklist.docx')
tests = [
('Separate photos from different sites', 'Phone and genuine photos from two sites', [
 'Select valid COTS photos from two different sites in one batch.',
 'Submit and confirm they become separate submissions by site.',
 'Check that each photo keeps its own GPS, time and model information.']),
('Mix valid and invalid photos', 'Phone and photos with known locations', [
 'Select a valid site photo together with a photo outside every site.',
 'Confirm the app identifies the problematic photo and blocks continuing.',
 'Remove only that photo; confirm the valid photo remains available.']),
('Prevent accidental double submission', 'Phone and a valid test submission', [
 'Tap Submit twice quickly.',
 'Confirm Submit becomes disabled while processing.',
 'Check that only one submission is created.']),
('Cancel photo selection', 'Phone only', [
 'Open the photo picker, then cancel without choosing anything.',
 'Confirm the app remains usable.',
 'Repeat with existing selected photos; confirm canceling keeps them.']),
('Remove and replace a photo', 'Phone and three valid test photos', [
 'Select three photos, remove the middle one and add a replacement.',
 'Check the photo count and analysis results before submitting.',
 'Confirm the removed photo is absent from the final submission.']),
('Test photo limits', 'Phone and enough valid test photos', [
 'Try selecting more than 15 photos for initial Detection.',
 'Try more than 10 photos for a Monthly visit when eligible.',
 'Confirm the limits are enforced without freezing and skipped photos are explained.']),
('Background the app during submission', 'Phone and two valid test photos', [
 'Start a two-photo submission, switch to another app and wait briefly.',
 'Return and confirm the submission completes or remains recoverable.',
 'Check for duplicate records and missing photos.']),
('Lock the screen during submission', 'Phone and a valid test submission', [
 'Start uploading, lock the phone, then unlock it after a short wait.',
 'Check whether the submission completed or can resume.',
 'If still pending, confirm its photo remains available and Retry can recover it.']),
('Check account separation', 'Two authorized Diver test accounts', [
 'Create a pending submission as Diver A, then attempt to sign out.',
 'If sign-out is allowed, sign in as Diver B and confirm A\'s private records and pending photos are not exposed.',
 'Return to Diver A and confirm the pending submission is still available. Respect any sign-out protection warning.']),
('Check an unverified Diver', 'An authorized unverified test account', [
 'Attempt a valid test submission using an unverified Diver account.',
 'Confirm it is not treated as an accepted monitoring record.',
 'Check that any refusal or pending state has a clear explanation.']),
('Check Admin permissions', 'Admin account', [
 'Open accepted, rejected and pending records; confirm their information is viewable.',
 'Confirm Admin cannot approve or reject COTS or verify Divers.',
 'Confirm Admin cannot decide partner, coverage or handover requests.']),
('Check partner request permissions', 'Main Diver, invited Diver and Expert test accounts', [
 'Send a partner invitation and confirm the invited Diver must accept before Expert approval.',
 'Confirm an unrelated Diver cannot approve or act on the invitation.',
 'After Expert approval, check both Divers see the correct site team.']),
('Check photos taken before partner approval', 'Approved partner and genuine dated site photos', [
 'Check a test record whose photo was taken before partnership approval.',
 'Confirm it still receives the required Expert record review.',
 'Compare with an eligible photo taken after approval; approval must not silently change older records.']),
('Check monthly coverage boundaries', 'A temporary replacement assigned for one month', [
 'Confirm the temporary assignment displays the correct month.',
 'Check that it does not appear as a permanent site handover.',
 'Confirm replacement acceptance and monitoring completion are shown separately.']),
('Check empty report periods', 'Admin or Expert account', [
 'Create a report for a month and site with no records.',
 'Confirm the report clearly indicates no data and does not retain the previous report\'s values.',
 'Return to a month with records and confirm its data reloads correctly.']),
('Cancel and retry an export', 'Admin or Expert account and a PDF viewer', [
 'Open Export PDF, then cancel the save dialog if the device offers one.',
 'Confirm the app remains usable and canceling does not falsely report a successful save.',
 'Export again, then open the PDF. Mark Blocked if the platform does not offer a cancellation step.']),
('Navigate after a validation error', 'Phone and a test submission', [
 'Trigger a validation error, such as leaving a required field empty.',
 'Go back, correct it and continue; check selected photos and entered details remain consistent.',
 'Confirm loading indicators and disabled buttons reset correctly.']),
('Check larger text and landscape', 'Phone settings access', [
 'Increase the phone\'s text size and check Detection, Records, reports and dialogs.',
 'Confirm important text and buttons remain readable and reachable.',
 'Rotate the phone where supported; record fixed orientation as Not tested, rather than assuming a fault.']),
]

doc = Document()
section = doc.sections[0]
section.page_width, section.page_height = Inches(8.5), Inches(11)
section.top_margin = section.bottom_margin = Inches(.65)
section.left_margin = section.right_margin = Inches(.7)
for name in ['Normal', 'Title', 'Heading 1', 'Heading 2']:
 st = doc.styles[name]
 st.font.name = 'Calibri'
 st.font.color.rgb = RGBColor(0, 0, 0)
 st.paragraph_format.space_after = Pt(5)
doc.styles['Normal'].font.size = Pt(11)
doc.styles['Normal'].paragraph_format.line_spacing = 1.04
doc.styles['Title'].font.size = Pt(23)
doc.styles['Heading 1'].font.size = Pt(15)
doc.styles['Heading 2'].font.size = Pt(12)
doc.styles['Heading 2'].paragraph_format.space_before = Pt(11)
doc.styles['Heading 2'].paragraph_format.keep_with_next = True
doc.core_properties.title = 'COTS Monitor Remote Testing Checklist'
doc.core_properties.author = 'COTS Monitor Project Team'

doc.add_paragraph('COTS Monitor Remote Testing Checklist', 'Title')
doc.add_paragraph('Additional tests for submissions, permissions and recovery')
doc.add_paragraph('Use this checklist while working remotely. Record actual results and evidence. Leave checks incomplete when you lack the required account, photo, site access or device capability.')
doc.add_paragraph('Prepared 11 November 2026  |  Philippine time')
doc.add_paragraph('Tester ____________________   Date and time ____________________')
doc.add_paragraph('Phone and Android version ____________________   App build ____________________')
doc.add_paragraph('Connection ____________________   Last app update ____________________')
p=doc.add_paragraph();p.add_run('Start with tests 3, 7, 9 and 11. ').bold=True
p.add_run('Use practice sites and authorized test accounts where available. Avoid creating duplicate real monitoring reports.')
p=doc.add_paragraph();p.add_run('While away from the laptop. ').bold=True
p.add_run('You can record screenshots and results on the phone. A no-COTS survey needs a genuine survey and phone GPS at a configured site; mark it Blocked if you are elsewhere. If an app freeze or closure happens, note the exact time, model, photo count and step. Capture logs when laptop access is available.')
doc.add_paragraph('Result choices: Pass / Fail / Blocked / Not tested. Do not uninstall, clear app data, change the phone clock or alter GPS to force a test to pass.')

def add_test(number, title, access, steps):
 doc.add_paragraph(f'{number}  {title}', 'Heading 2')
 p=doc.add_paragraph();p.paragraph_format.space_after=Pt(4)
 p.add_run('Needs: ').bold=True;p.add_run(access)
 for step in steps:
  p=doc.add_paragraph('[ ]  '+step)
  p.paragraph_format.left_indent=Inches(.12)
  p.paragraph_format.first_line_indent=Inches(-.12)
  p.paragraph_format.space_after=Pt(3)
 p=doc.add_paragraph('Result ____________________   Evidence or record ID ____________________')
 p.paragraph_format.space_before=Pt(3);p.paragraph_format.space_after=Pt(3)
 doc.add_paragraph('Notes ______________________________________________________________')

# First page gives the remote setup; subsequent pages keep four tests together.
for i,(title,access,steps) in enumerate(tests,1):
 if i in [3,7,11,15]:
  doc.add_page_break()
 add_test(i,title,access,steps)

doc.add_page_break()
doc.add_paragraph('Issue report and test summary', 'Heading 1')
doc.add_paragraph('Complete one issue report per failure. Send the screenshot and these details to the project team when you can reconnect.')
for label in ['Test number and title','Account role','Submission or record ID','Model and number of photos','Exact date and time in Philippine time','Internet state and connection type','Steps that caused the issue','Expected result','What actually happened','Screenshot or video reference']:
 doc.add_paragraph(label+'\n__________________________________________________________________')
doc.add_paragraph('Session totals', 'Heading 2')
doc.add_paragraph('Passed ______   Failed ______   Blocked ______   Not tested ______')
doc.add_paragraph('Next tests to continue\n__________________________________________________________________')

# Page numbers keep the six-page checklist easy to share without a cover page.
footer=section.footer.paragraphs[0]
footer.alignment=2
r=footer.add_run('Page ');r.font.size=Pt(9)
fld=OxmlElement('w:fldSimple');fld.set(qn('w:instr'),'PAGE');footer._p.append(fld)
OUT.parent.mkdir(parents=True,exist_ok=True)
for style in doc.styles:
 for border in style.element.xpath('.//w:pBdr'):
  border.getparent().remove(border)
for paragraph in doc.paragraphs:
 for border in paragraph._p.xpath('.//w:pBdr'):
  border.getparent().remove(border)
doc.save(OUT)
print(OUT)
