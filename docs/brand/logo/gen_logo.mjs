// Generates a clean, math-precise VECTOR logo for Alnujom Real Estate:
//   - logo_icon.svg     : N-of-buildings monogram + star (app icon / favicon)
//   - logo_emblem.svg   : the monogram inside a steel ring + 13-star crown
//   - preview.html      : both, at multiple sizes, on light + dark, with wordmark
// Run: node gen_logo.mjs
import { writeFileSync } from 'node:fs';

const BLUE = '#1F4FE6';   // Nujom Blue
const NAVY = '#0E1A2E';   // Ink Navy
const STEEL = '#9AA4B2';  // Steel / silver
const WHITE = '#FFFFFF';

// 5-point star path centered at (cx,cy), outer radius ro, pointing up.
function star(cx, cy, ro) {
  const ri = ro * 0.40;
  const pts = [];
  for (let i = 0; i < 10; i++) {
    const r = i % 2 === 0 ? ro : ri;
    const a = (-90 + i * 36) * Math.PI / 180;
    pts.push(`${(cx + r * Math.cos(a)).toFixed(1)},${(cy + r * Math.sin(a)).toFixed(1)}`);
  }
  return 'M' + pts.join('L') + 'Z';
}

// The N-of-buildings monogram, authored in a 512x512 frame.
// Two full-height towers (the N's verticals) + a bold diagonal + skyline tops.
function monogram() {
  // the two verticals of the N = towers of different heights (a skyline)
  const vert = `
    <rect x="150" y="180" width="66" height="212" rx="5" fill="${BLUE}"/>
    <rect x="346" y="150" width="66" height="242" rx="5" fill="${BLUE}"/>`;
  // small stepped roof blocks on top = building setbacks
  const roofs = `
    <rect x="166" y="160" width="34" height="22" rx="3" fill="${BLUE}"/>
    <rect x="362" y="130" width="34" height="22" rx="3" fill="${BLUE}"/>`;
  // the bold N diagonal: top of the left tower -> bottom of the right tower
  const diag = `<polygon points="216,180 282,180 412,392 346,392" fill="${BLUE}"/>`;
  // subtle navy depth on each tower's right edge
  const sides = `
    <rect x="208" y="180" width="8" height="212" fill="${NAVY}" opacity="0.45"/>
    <rect x="404" y="150" width="8" height="242" fill="${NAVY}" opacity="0.45"/>`;
  // window dashes (read as buildings); kept clear of the diagonal
  let win = '';
  for (const y of [232, 296, 352]) win += `<rect x="160" y="${y}" width="40" height="7" rx="3.5" fill="${WHITE}" opacity="0.9"/>`;
  for (const y of [190, 248, 306]) win += `<rect x="352" y="${y}" width="40" height="7" rx="3.5" fill="${WHITE}" opacity="0.9"/>`;
  // a single star cresting the taller (right) tower
  const st = `<path d="${star(379, 98, 26)}" fill="${STEEL}"/>`;
  return vert + roofs + diag + sides + win + st;
}

const ICON = `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 512 512">${monogram()}</svg>`;

// Emblem: ring + 13-star crown + centered monogram.
function emblem() {
  const cx = 350, cy = 350, R = 300, rs = 252;
  const ring = `<circle cx="${cx}" cy="${cy}" r="${R}" fill="none" stroke="${STEEL}" stroke-width="9"/>`;
  let crown = '';
  const n = 13;
  for (let i = 0; i < n; i++) {
    const a = (160 - i * (140 / (n - 1))) * Math.PI / 180; // 160°..20° over the top
    const x = cx + rs * Math.cos(a);
    const y = cy - rs * Math.sin(a); // screen y is down
    crown += `<path d="${star(x, y, 14)}" fill="${STEEL}"/>`;
  }
  const mono = `<g transform="translate(94,96)">${monogram()}</g>`;
  return `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 700 700">${ring}${crown}${mono}</svg>`;
}

writeFileSync('logo_icon.svg', ICON);
writeFileSync('logo_emblem.svg', emblem());

const html = `<!doctype html><html lang="ar" dir="rtl"><head><meta charset="utf-8">
<style>
  body{margin:0;font-family:Inter,system-ui;background:#E9ECF1;color:#0E1A2E;padding:32px}
  .row{display:flex;gap:24px;flex-wrap:wrap;align-items:center;margin-bottom:24px}
  .card{border-radius:20px;padding:28px;display:flex;align-items:center;justify-content:center;box-shadow:0 8px 28px rgba(15,23,42,.10)}
  .light{background:#F2F4F8}.dark{background:#0E1A2E}.white{background:#fff}
  .label{font-size:12px;color:#7A8597;margin:0 4px 8px;font-weight:600}
  .appicon{border-radius:26%;background:#0E1A2E;box-shadow:0 8px 24px rgba(15,23,42,.25)}
  .wm-ar{font-family:'Tahoma','Segoe UI';font-weight:800;color:#1F4FE6;font-size:40px;line-height:1.2}
  .wm-en{font-family:'Segoe UI';font-weight:700;color:#9AA4B2;font-size:15px;letter-spacing:3px}
  h3{font-family:Inter;font-weight:700;color:#39414F;margin:8px 0 6px}
</style></head><body>
  <h3>الشعار الكامل (Emblem) — فاتح / غامق</h3>
  <div class="row">
    <div><div class="label">on light</div><div class="card light">${emblem().replace('<svg','<svg width="240" height="240"')}</div></div>
    <div><div class="label">on navy</div><div class="card dark">${emblem().replace(/stroke="#9AA4B2"/,'stroke="#C4CBD6"').replace('<svg','<svg width="240" height="240"')}</div></div>
    <div><div class="label">lockup</div><div class="card white" style="gap:18px">
      ${emblem().replace('<svg','<svg width="120" height="120"')}
      <div style="text-align:right"><div class="wm-ar">النجوم للتسويق العقاري</div><div class="wm-en">ALNUJOM REAL ESTATE</div></div>
    </div></div>
  </div>
  <h3>أيقونة التطبيق (Icon only) — يتقلّص بوضوح</h3>
  <div class="row">
    <div><div class="label">app icon</div><div class="appicon" style="width:120px;height:120px;display:flex;align-items:center;justify-content:center">${ICON.replace('<svg','<svg width="86" height="86"')}</div></div>
    <div><div class="label">160</div><div class="card white">${ICON.replace('<svg','<svg width="120" height="120"')}</div></div>
    <div><div class="label">64</div><div class="card white">${ICON.replace('<svg','<svg width="64" height="64"')}</div></div>
    <div><div class="label">32</div><div class="card white">${ICON.replace('<svg','<svg width="32" height="32"')}</div></div>
  </div>
</body></html>`;
writeFileSync('preview.html', html);
writeFileSync('preview.b64', 'data:text/html;base64,' + Buffer.from(html).toString('base64'));
console.log('wrote logo_icon.svg, logo_emblem.svg, preview.html, preview.b64');
