"""Small original vector counter props; evidence is authored separately in the catalog."""
from pathlib import Path
R=Path(__file__).resolve().parents[1]/'assets/wealthy'
R.mkdir(parents=True,exist_ok=True)
watch='<circle cx="160" cy="35" r="20" fill="none"/><circle cx="160" cy="140" r="96"/><circle cx="160" cy="140" r="79" fill="#e5d6ae"/><path d="M160 76v64l40 26" fill="none" stroke="#423524" stroke-width="6"/>'
shapes={
'embroidery':'<rect x="39" y="30" width="242" height="192" rx="4" fill="#694733"/><rect x="51" y="43" width="218" height="165" fill="#a97761"/><path d="M90 196Q193 143 231 67M140 160Q105 122 80 137M177 132Q222 147 234 119" fill="none" stroke="#dfc393"/><g fill="#ecd7ae"><ellipse cx="151" cy="93" rx="21" ry="11"/><ellipse cx="151" cy="93" rx="11" ry="21"/></g><path d="M54 223v28M269 223v28"/>',
'gold_bangle':'<ellipse cx="160" cy="139" rx="104" ry="65" fill="none" stroke-width="25"/><path d="M67 127Q160 212 253 127" fill="none" stroke="#f1d590"/><path d="M133 89l9 4m12-6 9 3m12-4 9 3" stroke="#77522b"/>',
'gold_watch':watch,
'mantel_clock':'<path d="M55 217V80Q160-11 265 80v137z" fill="#744935"/><rect x="40" y="215" width="240" height="26"/><circle cx="160" cy="106" r="64" fill="#e8d7ae"/><path d="M160 60v46l28 25" fill="none" stroke="#423524"/><rect x="145" y="179" width="30" height="23" fill="#302c28"/>',
'pearl_necklace':'<ellipse cx="160" cy="136" rx="106" ry="82" fill="none" stroke="#e2d9be" stroke-width="19" stroke-dasharray="1 22" stroke-linecap="round"/><path d="M147 55h27v12h-27z"/><ellipse cx="160" cy="219" rx="16" ry="21" fill="#eee0c1"/>',
'jade_pendant':'<path d="M145 46Q160 4 175 46v23h-30z" fill="none"/><path d="M113 70Q160 52 207 70l20 98q-67 88-134 0z" fill="#8aab91" stroke-width="12"/><path d="M150 83Q120 120 158 151T167 199" fill="none" stroke="#c8d5b4"/><path d="M109 87l18 11m70-14-15 14m-70 67 18-9m75 5-20-8"/>',
'album':'<path d="M40 48h116v167H40zm116 0h124v167H156z" fill="#e4d1a5"/><path d="M54 179l28-64 30 44 21-58 12 79m26-3 21-62 31 49 28-82 13 88" fill="#8a9383" stroke="#4e6254"/><path d="M238 59v34m14-34v26M157 49v165" stroke="#473827"/>',
'porcelain_vase':'<path d="M125 32h70v22h-13v47q65 56 42 112-64 37-128 0-23-56 42-112V54h-13z" fill="#dddac9" stroke="#788985"/><path d="M131 71h57M105 197q55 28 110 0M121 136q40-29 73 15t-45 24q-44-9-18-38" fill="none" stroke="#426c83" stroke-width="5"/>',
'repeater':watch+'<circle cx="160" cy="181" r="19" fill="none" stroke="#6d5439" stroke-width="2"/><path d="M55 96v47M249 181l12-27" stroke-width="9"/><path d="M113 88q45-19 90 0" fill="none" stroke="#ad8345" stroke-width="3"/>',
'silver_service':'<ellipse cx="160" cy="217" rx="132" ry="28" fill="#b4b5a5" stroke="#e1decc"/><path d="M77 119q20-22 76-11l14 80q-45 38-89 0z" fill="#c5c7b8" stroke="#e1decc"/><path d="M154 127q63-42 36 35l-23 12M78 137 52 111 42 118 79 171" fill="none" stroke="#c5c7b8" stroke-width="13"/><path d="M76 111q30-50 76 0z" fill="#b2b5a7"/><path d="M205 166h50l-8 41h-34zM245 171q33-10 20 23h-16" fill="#ced0c0" stroke="#f1edd7"/>',
}
for name,shape in shapes.items():
    (R/(name+'.svg')).write_text(f'<svg xmlns="http://www.w3.org/2000/svg" width="320" height="270" viewBox="0 0 320 270"><ellipse cx="160" cy="239" rx="119" ry="12" fill="#241c16" opacity=".22"/><g fill="#c69a52" stroke="#d3b475" stroke-width="5" stroke-linejoin="round">{shape}</g></svg>\n',encoding='utf-8')
