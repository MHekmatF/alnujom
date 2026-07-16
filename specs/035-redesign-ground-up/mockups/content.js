/* Renders the mockup content from content-kit.json (single source of truth). */
(async function () {
  const kit = await (await fetch('content-kit.json')).json();
  const byKey = Object.fromEntries(kit.listings.map(l => [l.key, l]));
  const RATE = kit.exchange_rate_hint.usd_to_syp;

  const AR = '٠١٢٣٤٥٦٧٨٩';
  const toAr = n => String(n).replace(/[0-9]/g, d => AR[+d]).replace(/,/g, '٬').replace(/\./g, '٫');
  const grp = n => n.toLocaleString('en-US');
  const priceAr = l => `${toAr(grp(l.price_usd))} $${l.purpose === 'rent' ? ' / شهرياً' : ''}`;
  const approxAr = l => {
    if (l.purpose === 'rent') {
      const m = l.price_usd * RATE / 1e6;
      return `≈ ${toAr(m.toFixed(m < 10 ? 1 : 0))} مليون ل.س`;
    }
    const b = l.price_usd * RATE / 1e9;
    return b >= 1 ? `≈ ${toAr(b.toFixed(1))} مليار ل.س` : `≈ ${toAr((b * 1000).toFixed(0))} مليون ل.س`;
  };

  const I = {
    pin: '<svg class="i" viewBox="0 0 24 24"><path d="M20 10c0 4.99-5.54 10.19-7.4 11.8a1 1 0 0 1-1.2 0C9.54 20.19 4 14.99 4 10a8 8 0 0 1 16 0"/><circle cx="12" cy="10" r="3"/></svg>',
    bed: '<svg class="i" viewBox="0 0 24 24"><path d="M2 20v-8a2 2 0 0 1 2-2h16a2 2 0 0 1 2 2v8"/><path d="M4 10V6a2 2 0 0 1 2-2h12a2 2 0 0 1 2 2v4"/><path d="M2 17h20"/><path d="M6 8v2"/></svg>',
    bath: '<svg class="i" viewBox="0 0 24 24"><path d="M10 4 8 6"/><path d="M17 19v2"/><path d="M2 12h20"/><path d="M7 19v2"/><path d="M9 5 7.62 3.62A2.12 2.12 0 0 0 4 5v7"/><path d="M20 12v5a3 3 0 0 1-3 3H7a3 3 0 0 1-3-3v-5"/></svg>',
    ruler: '<svg class="i" viewBox="0 0 24 24"><path d="M21.3 15.3a2.4 2.4 0 0 1 0 3.4l-2.6 2.6a2.4 2.4 0 0 1-3.4 0L2.7 8.7a2.41 2.41 0 0 1 0-3.4l2.6-2.6a2.41 2.41 0 0 1 3.4 0Z"/><path d="m14.5 12.5 2-2"/><path d="m11.5 9.5 2-2"/><path d="m8.5 6.5 2-2"/><path d="m17.5 15.5 2-2"/></svg>',
    check: '<svg class="i" viewBox="0 0 24 24"><path d="M3.85 8.62a4 4 0 0 1 4.78-4.77 4 4 0 0 1 6.74 0 4 4 0 0 1 4.78 4.78 4 4 0 0 1 0 6.74 4 4 0 0 1-4.77 4.78 4 4 0 0 1-6.75 0 4 4 0 0 1-4.78-4.77 4 4 0 0 1 0-6.76Z"/><path d="m9 12 2 2 4-4"/></svg>',
    star: '<svg class="i" viewBox="0 0 24 24"><path d="M11.5 3.3a.55.55 0 0 1 1 0l2.3 4.7a.55.55 0 0 0 .4.3l5.2.75a.55.55 0 0 1 .3.94l-3.75 3.65a.55.55 0 0 0-.16.49l.89 5.14a.55.55 0 0 1-.8.59l-4.63-2.44a.55.55 0 0 0-.51 0l-4.63 2.44a.55.55 0 0 1-.8-.59l.89-5.14a.55.55 0 0 0-.16-.49L2.3 9.99a.55.55 0 0 1 .3-.94l5.2-.74a.55.55 0 0 0 .4-.31Z"/></svg>',
    heart: '<svg class="i" viewBox="0 0 24 24"><path d="M19 14c1.49-1.46 3-3.21 3-5.5A5.5 5.5 0 0 0 16.5 3c-1.76 0-3 .5-4.5 2-1.5-1.5-2.74-2-4.5-2A5.5 5.5 0 0 0 2 8.5c0 2.3 1.5 4.05 3 5.5l7 7Z"/></svg>',
    clock: '<svg class="i" viewBox="0 0 24 24"><circle cx="12" cy="12" r="10"/><polyline points="12 6 12 12 16 14"/></svg>',
    photos: '<svg class="i" viewBox="0 0 24 24"><rect width="18" height="18" x="3" y="3" rx="2"/><circle cx="9" cy="9" r="2"/><path d="m21 15-3.1-3.1a2 2 0 0 0-2.8 0L6 21"/></svg>',
    wa: '<svg class="i" viewBox="0 0 24 24"><path d="M7.9 20A9 9 0 1 0 4 16.1L2 22Z"/></svg>',
    phone: '<svg class="i" viewBox="0 0 24 24"><path d="M9.03 3.34a2 2 0 0 1 1.98 1.7l.44 2.62a2 2 0 0 1-.55 1.74l-1.05 1.05a14 14 0 0 0 3.7 3.7l1.05-1.05a2 2 0 0 1 1.74-.55l2.62.44a2 2 0 0 1 1.7 1.98v2.11a2 2 0 0 1-2.18 2A18 18 0 0 1 3.02 5.52a2 2 0 0 1 2-2.18Z"/></svg>'
  };

  const locLine = l => `${l.db.area_ar.includes('حلب') || l.key.startsWith('aleppo') || l.key === 'hamdaniyeh-5br' || l.key === 'furqan-4br' ? 'حلب' : (l.key === 'latakia-sea-view' ? 'اللاذقية' : (l.key === 'homs-land' ? 'حمص' : 'دمشق'))} · ${l.db.area_ar}`;

  const photoBadges = l => `
    <span class="photo-badges">
      ${l.verified ? `<span class="badge badge-verified">${I.check} موثّق</span>` : ''}
      ${l.featured ? `<span class="badge badge-featured">${I.star} مميّز</span>` : ''}
    </span>`;

  /* ---------- featured rail ---------- */
  const railKeys = ['abu-rummaneh-duplex', 'dummar-villa-pool', 'malki-3br'];
  document.getElementById('featuredRail').innerHTML = railKeys.map(k => {
    const l = byKey[k];
    return `
    <article class="f-card">
      <div class="f-photo">
        <img src="photos/${l.photos[0]}" alt="">
        ${photoBadges(l)}
      </div>
      <div class="f-body">
        <div class="f-price">${priceAr(l)}</div>
        <div class="f-title">${l.title_ar}</div>
        <div class="f-loc">${I.pin}${locLine(l)}</div>
      </div>
    </article>`;
  }).join('');

  /* ---------- feed cards (comfortable) ---------- */
  const cardHTML = (l, density) => `
    <article class="card ${density}">
      <div class="c-photo">
        <img src="photos/${l.photos[0]}" alt="">
        ${density === 'compact' ? '' : photoBadges(l)}
        <button class="heart-btn">${I.heart}</button>
        ${density === 'comfortable' && l.verified ? `<span class="fresh-pill">${I.clock} تم التأكد قبل ٣ أيام</span>` : ''}
        ${density === 'comfortable' ? `<span class="count-pill">${I.photos} ${toAr(l.photos.length)}</span>` : ''}
      </div>
      <div class="c-body">
        <div class="c-price-row">
          <span class="c-price">${priceAr(l)}</span>
          <span class="c-price-approx">${approxAr(l)}</span>
        </div>
        <div class="c-title">${l.title_ar}</div>
        <div class="c-loc">${I.pin}${locLine(l)}</div>
        <div class="c-specs">
          ${l.rooms ? `<span class="spec">${I.bed}${toAr(l.rooms)} غرف</span>` : ''}
          ${l.bathrooms ? `<span class="spec">${I.bath}${toAr(l.bathrooms)} حمّام</span>` : ''}
          <span class="spec">${I.ruler}${toAr(l.area_m2)} م²</span>
        </div>
        ${density === 'comfortable' ? `
        <div class="agent-strip">
          <span class="avatar">${l.agent_ar.replace('مكتب ', '').slice(0, 1)}</span>
          <div class="agent-info">
            <span class="agent-name">${l.agent_ar}${l.verified ? I.check.replace('class="i"', 'class="i check"') : ''}</span>
            <span class="agent-meta">يرد عادة خلال ساعة</span>
          </div>
          <button class="round-btn round-call">${I.phone}</button>
          <button class="round-btn round-wa">${I.wa}</button>
        </div>` : ''}
      </div>
      ${density === 'compact' ? `<button class="round-btn round-wa compact-wa">${I.wa}</button>` : ''}
    </article>`;

  const feedKeys = ['hamdaniyeh-5br', 'kafarsouseh-3br'];
  document.getElementById('feed').innerHTML = feedKeys.map(k => cardHTML(byKey[k], 'comfortable')).join('');

  /* ---------- density showcase ---------- */
  const m = byKey['malki-3br'];
  document.getElementById('cardComfort').innerHTML = cardHTML(m, 'comfortable');
  document.getElementById('cardBalanced').innerHTML = cardHTML(m, 'balanced');
  document.getElementById('cardCompact').innerHTML = cardHTML(m, 'compact');

  /* ---------- screen switch ---------- */
  const screen = new URLSearchParams(location.search).get('screen') || 'home';
  document.querySelectorAll('[data-screen]').forEach(s => {
    s.hidden = s.dataset.screen !== screen;
  });
})();
