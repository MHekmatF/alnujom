// Al Nujom DS — template loader. One line to edit when this template is copied
// into a consuming project: point `base` at the bound _ds/<folder> tree
// (e.g. '_ds/alnujom' at the project root, or '../_ds/alnujom' one level down).
(() => {
  const base = '../..';
  for (const p of ['styles.css']) {
    const l = document.createElement('link');
    l.rel = 'stylesheet';
    l.href = base + '/' + p;
    document.head.appendChild(l);
  }
  // This template is plain HTML/CSS and does not need the React bundle. If you
  // start composing the DS React primitives here, also load React UMD + then:
  //   const s = document.createElement('script');
  //   s.src = base + '/_ds_bundle.js';
  //   s.onerror = () => console.error('ds-base.js: failed to load ' + s.src);
  //   document.head.appendChild(s);
})();
