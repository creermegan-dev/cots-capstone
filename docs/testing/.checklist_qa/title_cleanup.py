from pathlib import Path
p=Path('docs/testing/.checklist_qa/create_checklist.py')
s=p.read_text(encoding='utf-8').replace('doc.save(OUT)', '''for style in doc.styles:
+ for border in style.element.xpath('.//w:pBdr'):
+  border.getparent().remove(border)
+for paragraph in doc.paragraphs:
+ for border in paragraph._p.xpath('.//w:pBdr'):
+  border.getparent().remove(border)
+doc.save(OUT)'''.replace('\n+','\n'))
p.write_text(s,encoding='utf-8')
