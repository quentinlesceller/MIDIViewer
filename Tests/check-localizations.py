from pathlib import Path
import re, subprocess, plistlib
root=Path(__file__).resolve().parents[1]
reference=None
for lang in ['en','fr','es','de','it']:
    path=root/'Resources'/f'{lang}.lproj/Localizable.strings'
    data=plistlib.loads(subprocess.check_output(['plutil','-convert','xml1','-o','-',str(path)]))
    assert all(data.values())
    if reference is None: reference=data
    assert data.keys()==reference.keys(),lang
    for k,v in data.items():assert re.findall(r'%[d@sf]',v)==re.findall(r'%[d@sf]',reference[k]),(lang,k)
    print(f'PASS: {lang}: {len(data)} nonempty, matching localization keys and placeholders')
