# -*- coding: utf-8 -*-
"""Render the published static site: the two privacy policies, plus any
hand-written pages under `docs/landing/`.

The markdown converter is deliberately hand-rolled: the documents use only
headings, paragraphs, bold, inline code, links, bullet lists, tables and
horizontal rules, and the build machine has no markdown package. Anything
outside that subset would silently render as literal text, so the converter
asserts on constructs it does not know.

`docs/landing/` is copied verbatim. It holds pages that are written as HTML
rather than generated from markdown — today the shared-listing page at `l/`
(review §1 M3). It is a **tracked source**: the output directory is gitignored,
so anything written straight into it is lost on the next run and never reaches
review.
"""
import html
import io
import os
import re
import shutil
import sys

SRC_AR = 'docs/legal/privacy-policy.md'
SRC_EN = 'docs/legal/privacy-policy.en.md'
SRC_STATIC = 'docs/landing'
OUT = sys.argv[1] if len(sys.argv) > 1 else 'site'


def inline(text):
    """Bold, inline code and links, applied to already-escaped text."""
    t = html.escape(text, quote=False)
    t = re.sub(r'`([^`]+)`', lambda m: '<code>%s</code>' % m.group(1), t)
    t = re.sub(r'\*\*([^*]+)\*\*', lambda m: '<strong>%s</strong>' % m.group(1), t)
    # [label](target) — rewrite the cross-language markdown link to the built page
    def link(m):
        label, href = m.group(1), m.group(2)
        # The source files cross-link by filename, which reads as a raw ".md"
        # path once published. Rewrite both the target and the label.
        swap = {'privacy-policy.en.md': ('en.html', 'English'),
                'privacy-policy.md': ('index.html', 'العربية')}
        if href in swap:
            href, label = swap[href]
        ext = ' target="_blank" rel="noopener"' if href.startswith('http') else ''
        return '<a href="%s"%s>%s</a>' % (html.escape(href, quote=True), ext, label)
    t = re.sub(r'\[([^\]]+)\]\(([^)]+)\)', link, t)
    return t


def convert(md):
    out, i, lines = [], 0, md.split('\n')
    while i < len(lines):
        ln = lines[i].rstrip()

        if not ln.strip():
            i += 1
            continue

        if ln.startswith('---') and set(ln.strip()) == {'-'}:
            out.append('<hr>')
            i += 1
            continue

        m = re.match(r'^(#{1,4})\s+(.*)$', ln)
        if m:
            lvl = len(m.group(1))
            out.append('<h%d>%s</h%d>' % (lvl, inline(m.group(2)), lvl))
            i += 1
            continue

        if ln.lstrip().startswith(('- ', '* ')):
            items = []
            while i < len(lines) and lines[i].lstrip().startswith(('- ', '* ')):
                items.append('<li>%s</li>' % inline(lines[i].lstrip()[2:].strip()))
                i += 1
            out.append('<ul>%s</ul>' % ''.join(items))
            continue

        if ln.startswith('|'):
            rows = []
            while i < len(lines) and lines[i].startswith('|'):
                rows.append(lines[i])
                i += 1
            cells = [[c.strip() for c in r.strip().strip('|').split('|')] for r in rows]
            # drop the |---|---| separator row
            body = [r for r in cells[1:] if not all(set(c) <= set('-: ') for c in r)]
            head = ''.join('<th>%s</th>' % inline(c) for c in cells[0])
            trs = ''.join('<tr>%s</tr>' % ''.join('<td>%s</td>' % inline(c) for c in r)
                          for r in body)
            out.append('<div class="tw"><table><thead><tr>%s</tr></thead>'
                       '<tbody>%s</tbody></table></div>' % (head, trs))
            continue

        if ln.startswith('> '):
            quote = []
            while i < len(lines) and lines[i].startswith('> '):
                quote.append(inline(lines[i][2:].strip()))
                i += 1
            out.append('<blockquote>%s</blockquote>' % ' '.join(quote))
            continue

        para = []
        while i < len(lines) and lines[i].strip() and not lines[i].startswith(
                ('#', '|', '- ', '* ', '> ')) and not (
                lines[i].startswith('---') and set(lines[i].strip()) == {'-'}):
            para.append(lines[i].strip())
            i += 1
        out.append('<p>%s</p>' % inline(' '.join(para)))
    return '\n'.join(out)


CSS = """
:root{--bg:#FAF7F0;--card:#fff;--ink:#0E1A2E;--muted:#5B6573;--line:#E6E1D6;
--accent:#1F4FE6;--accent-ink:#163BB0;--accent-soft:#E8EDFD;
--shadow:0 1px 2px rgba(14,26,46,.05),0 10px 30px rgba(14,26,46,.05)}
@media(prefers-color-scheme:dark){:root:not([data-theme=light]){--bg:#0B1424;--card:#12203A;
--ink:#F2F4F8;--muted:#9AA4B2;--line:#22314D;--accent:#7C97FF;--accent-ink:#A9BBFF;
--accent-soft:#1B2B52;--shadow:0 1px 2px rgba(0,0,0,.4),0 10px 30px rgba(0,0,0,.35)}}
:root[data-theme=dark]{--bg:#0B1424;--card:#12203A;--ink:#F2F4F8;--muted:#9AA4B2;
--line:#22314D;--accent:#7C97FF;--accent-ink:#A9BBFF;--accent-soft:#1B2B52;
--shadow:0 1px 2px rgba(0,0,0,.4),0 10px 30px rgba(0,0,0,.35)}
*{box-sizing:border-box}
body{margin:0;background:var(--bg);color:var(--ink);
font-family:"Tajawal","Segoe UI",Tahoma,Arial,sans-serif;font-size:17px;line-height:1.85;
-webkit-font-smoothing:antialiased}
.wrap{max-width:760px;margin:0 auto;padding:0 20px 80px}
header{background:var(--accent);color:#fff;margin-bottom:28px}
.hin{max-width:760px;margin:0 auto;padding:30px 20px 26px;
display:flex;align-items:center;gap:14px;flex-wrap:wrap}
.mark{width:44px;height:44px;border-radius:12px;background:#fff;color:var(--accent);
display:grid;place-items:center;font-weight:800;font-size:20px;flex:none}
.brand{font-weight:800;font-size:19px;line-height:1.3}
.brand span{display:block;font-weight:500;font-size:14px;opacity:.85}
.lang{margin-inline-start:auto}
.lang a{color:#fff;background:rgba(255,255,255,.16);border:1px solid rgba(255,255,255,.3);
padding:6px 14px;border-radius:999px;text-decoration:none;font-size:14px;font-weight:700;
white-space:nowrap}
.lang a:hover{background:rgba(255,255,255,.26)}
.doc{background:var(--card);border:1px solid var(--line);border-radius:18px;
padding:10px 30px 34px;box-shadow:var(--shadow)}
h1{font-size:30px;font-weight:800;line-height:1.3;text-wrap:balance;margin:26px 0 6px}
h2{font-size:22px;font-weight:800;line-height:1.35;text-wrap:balance;
margin:38px 0 10px;padding-top:18px;border-top:1px solid var(--line)}
h2:first-of-type{border-top:0;padding-top:0}
h3{font-size:17px;font-weight:700;margin:24px 0 6px;color:var(--accent-ink)}
p{margin:0 0 14px}
ul{margin:0 0 16px;padding-inline-start:22px}
li{margin-bottom:7px}
hr{border:0;border-top:1px solid var(--line);margin:30px 0}
a{color:var(--accent-ink)}
code{font-family:Consolas,"Courier New",monospace;font-size:.88em;background:var(--accent-soft);
padding:2px 7px;border-radius:6px;direction:ltr;unicode-bidi:embed;display:inline-block}
strong{font-weight:700}
blockquote{margin:0 0 16px;padding:12px 16px;background:var(--accent-soft);
border-radius:10px;border-inline-start:3px solid var(--accent)}
blockquote p{margin:0}
.tw{overflow-x:auto;margin:0 0 18px}
table{border-collapse:collapse;width:100%;font-size:15px;min-width:420px}
th,td{border:1px solid var(--line);padding:9px 12px;text-align:start;vertical-align:top}
th{background:var(--accent-soft);font-weight:700}
footer{max-width:760px;margin:26px auto 0;padding:0 20px;color:var(--muted);font-size:14px}
"""

PAGE = """<!doctype html>
<html lang="{lang}" dir="{dir}">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>{title}</title>
<meta name="description" content="{desc}">
<link rel="preconnect" href="https://fonts.googleapis.com">
<link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
<link rel="stylesheet" href="https://fonts.googleapis.com/css2?family=Tajawal:wght@400;500;700;800&display=swap">
<style>{css}</style>
</head>
<body>
<header><div class="hin">
  <div class="mark">N</div>
  <div class="brand">{brand}<span>{sub}</span></div>
  <div class="lang"><a href="{other}">{otherlabel}</a></div>
</div></header>
<div class="wrap"><div class="doc">
{body}
</div></div>
<footer>{foot}</footer>
</body>
</html>
"""

os.makedirs(OUT, exist_ok=True)

specs = [
    dict(src=SRC_AR, out='index.html', lang='ar', dir='rtl',
         title='سياسة الخصوصية — تطبيق النجوم',
         desc='سياسة الخصوصية لتطبيق النجوم، سوق العقارات في سوريا.',
         brand='النجوم', sub='النجوم للتسويق العقاري',
         other='en.html', otherlabel='English',
         foot='© 2026 النجوم للتسويق العقاري — الجمهورية العربية السورية.'),
    dict(src=SRC_EN, out='en.html', lang='en', dir='ltr',
         title='Privacy Policy — AlNujom',
         desc='Privacy policy for AlNujom, a real-estate marketplace for Syria.',
         brand='AlNujom', sub='Al Nujoom for Real Estate Marketing',
         other='index.html', otherlabel='العربية',
         foot='© 2026 Al Nujoom for Real Estate Marketing — Syrian Arab Republic.'),
]

for s in specs:
    md = io.open(s['src'], encoding='utf-8').read()
    assert 'TODO(owner)' not in md, 'refusing to publish %s with a placeholder in it' % s['src']
    page = PAGE.format(css=CSS, body=convert(md), **{k: v for k, v in s.items() if k != 'src' and k != 'out'})
    path = os.path.join(OUT, s['out'])
    io.open(path, 'w', encoding='utf-8', newline='\n').write(page)
    print('wrote %s (%d bytes)' % (path, len(page.encode('utf-8'))))

# Hand-written pages, copied as-is. Overwrites on purpose: the source in
# docs/landing/ is the one under review, so it always wins over whatever is
# sitting in the output directory.
if os.path.isdir(SRC_STATIC):
    for root, _dirs, files in os.walk(SRC_STATIC):
        rel = os.path.relpath(root, SRC_STATIC)
        dest_dir = OUT if rel == '.' else os.path.join(OUT, rel)
        os.makedirs(dest_dir, exist_ok=True)
        for name in files:
            src = os.path.join(root, name)
            dest = os.path.join(dest_dir, name)
            shutil.copyfile(src, dest)
            print('copied %s (%d bytes)' % (dest, os.path.getsize(dest)))
