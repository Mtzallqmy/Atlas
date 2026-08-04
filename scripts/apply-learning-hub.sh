#!/usr/bin/env bash
set -euo pipefail
python3 - <<'PY'
from pathlib import Path
p=Path('app/components/AnatomyApp.tsx')
s=p.read_text()
needle='import { OrganViewer } from "./OrganViewer";'
if 'LearningHub' not in s:
    s=s.replace(needle, needle+'\nimport { LearningHub } from "./LearningHub";')
footer='      <footer className="site-footer">'
insert='      <LearningHub locale={locale} activeOrgan={organId} />\n\n'
if insert.strip() not in s:
    if footer not in s:
        raise SystemExit('footer anchor not found')
    s=s.replace(footer, insert+footer, 1)
p.write_text(s)
PY
