#!/usr/bin/env node
// ---------------------------------------------------------------------------
// build_syria_seed.mjs — Phase 031 WS-C
//
// Generates supabase/migrations/20260615120002_seed_syria_locations.sql:
// a full real Syria locations dataset (governorates -> districts/cities ->
// sub-districts/neighborhoods/areas) sourced from the official OCHA HDX
// COD-AB (Common Operational Dataset — Administrative Boundaries) v02 for the
// Syrian Arab Republic, layered with a small curated set of well-known
// neighborhoods for the major cities.
//
// DATA SOURCE / ATTRIBUTION
//   Syrian Arab Republic - Subnational Administrative Boundaries (COD-AB).
//   Source: OCHA Field Information Services Section (FISS) via HDX
//     https://data.humdata.org/dataset/cod-ab-syr
//   License: Creative Commons Attribution for Intergovernmental Organisations
//            (CC BY-IGO) — attribution required, redistribution permitted.
//   The dataset ships bilingual names (en + ar) and per-feature representative
//   centroids (center_lat/center_lon) for ADM1/ADM2/ADM3 — exactly what the
//   areas table CHECK (centroid_lat/lng inside the Syria bounding box) needs.
//
// MAPPING
//   ADM1 (14 governorates)      -> referenced by existing key (NOT re-inserted)
//   ADM2 (62 districts/manatiq) -> public.cities
//   ADM3 (272 sub-districts)    -> public.areas  (+ one "<city>-center" per city)
//   curated marquee neighborhoods of major cities -> public.areas
//
// RUN
//   node tool/locations/build_syria_seed.mjs
// It first tries a local cache (tool/locations/.cache/syr_admin{1,2,3}.geojson),
// then fetches+unzips the HDX GeoJSON bundle, and finally falls back to a small
// embedded curated hierarchy if the network is unavailable. It writes the .sql
// only — it does NOT apply the migration.
// ---------------------------------------------------------------------------

import fs from 'node:fs';
import path from 'node:path';
import os from 'node:os';
import { fileURLToPath } from 'node:url';
import { execFileSync } from 'node:child_process';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const REPO_ROOT = path.resolve(__dirname, '..', '..');
const CACHE_DIR = path.join(__dirname, '.cache');
const OUT_SQL = path.join(
  REPO_ROOT,
  'supabase',
  'migrations',
  '20260615120002_seed_syria_locations.sql',
);

const HDX_GEOJSON_ZIP_URL =
  'https://data.humdata.org/dataset/356a63e9-90aa-4b9c-a938-58ef24469c00/resource/ab4b6f19-3854-4b2b-8f5c-b5dc474a4c0c/download/syr_admin_boundaries.geojson.zip';

// Syria bounding box enforced by the areas_centroid_syria_bounds CHECK.
const LAT_MIN = 32, LAT_MAX = 37, LNG_MIN = 35, LNG_MAX = 43;

// ADM1 pcode -> existing governorate key (must match the 14 already-seeded keys).
const PCODE_TO_GOV = {
  SY01: 'damascus',
  SY02: 'aleppo',
  SY03: 'rif-dimashq',
  SY04: 'homs',
  SY05: 'hama',
  SY06: 'latakia',
  SY07: 'idlib',
  SY08: 'al-hasakah',
  SY09: 'deir-ez-zor',
  SY10: 'tartus',
  SY11: 'al-raqqah',
  SY12: 'daraa',
  SY13: 'as-suwayda',
  SY14: 'quneitra',
};

// City keys already seeded by 20260517120002_create_cities.sql (gov/key). Used so
// curated neighborhoods may attach to an existing city even when our OCHA ADM2
// mapping did not (re)create that exact city key. ON CONFLICT keeps the existing
// row; the area resolves it by the (gov key, city key) join either way.
const EXISTING_SEEDED_CITIES = new Set([
  'damascus/damascus',
  'aleppo/aleppo', 'aleppo/manbij', 'aleppo/afrin', 'aleppo/azaz',
  'homs/homs', 'homs/palmyra', 'homs/talkalakh',
  'latakia/latakia', 'latakia/jableh',
  'tartus/tartus', 'tartus/banias',
  'hama/hama', 'hama/salamiya', 'hama/masyaf',
  'rif-dimashq/douma', 'rif-dimashq/yabroud', 'rif-dimashq/qatana',
  'idlib/idlib', 'idlib/maaret-al-numan',
  'daraa/daraa', 'daraa/bosra',
  'deir-ez-zor/deir-ez-zor', 'deir-ez-zor/albu-kamal', 'deir-ez-zor/mayadeen',
  'al-hasakah/al-hasakah', 'al-hasakah/qamishli',
  'al-raqqah/al-raqqah', 'al-raqqah/tabqa',
  'as-suwayda/as-suwayda', 'as-suwayda/shahba',
  'quneitra/quneitra',
]);

// Canonical slug overrides — fold an OCHA ADM2 name onto the city key already
// seeded in 20260517120002_create_cities.sql so we attach to the existing row
// (ON CONFLICT keeps it) instead of creating a near-duplicate slug.
const CITY_KEY_OVERRIDE = {
  'SY02/menbij': 'manbij',
  'SY02/azaz': 'azaz',
  'SY02/jebel-saman': 'aleppo', // Aleppo city = Jebel Saman district -> attach to seeded 'aleppo'
  'SY03/duma': 'douma',
  'SY04/tadmor': 'palmyra',
  'SY04/tall-kalakh': 'talkalakh',
  'SY04/homs': 'homs',
  'SY05/as-salamiyeh': 'salamiya',
  'SY05/hama': 'hama',
  'SY06/jablah': 'jableh',
  'SY06/lattakia': 'latakia',
  'SY07/al-mara': 'maaret-al-numan',
  'SY07/idleb': 'idlib',
  'SY08/al-hasakeh': 'al-hasakah',
  'SY08/quamishli': 'qamishli',
  'SY09/abu-kamal': 'albu-kamal',
  'SY09/al-mayadin': 'mayadeen',
  'SY09/deir-ez-zor': 'deir-ez-zor',
  'SY10/banyas': 'banias',
  'SY10/tartous': 'tartus',
  'SY11/ar-raqqa': 'al-raqqah',
  'SY11/ath-thawrah': 'tabqa',
  'SY12/dara': 'daraa',
  'SY13/as-sweida': 'as-suwayda',
  'SY13/shahba': 'shahba',
  'SY14/quneitra': 'quneitra',
  'SY01/damascus': 'damascus',
  'SY03/rural-damascus': 'rif-dimashq-center',
};

// ---------------------------------------------------------------------------
// Curated marquee neighborhoods for the major cities (correct ar/en + plausible
// centroids inside the Syria bounds). Attached as areas to the listed city key
// under the listed governorate key. These complement the official ADM3 coverage.
// gov, city refer to the seeded keys; key is unique-per-city.
// ---------------------------------------------------------------------------
const CURATED_NEIGHBORHOODS = [
  // --- Damascus city ---
  { gov: 'damascus', city: 'damascus', key: 'mezzeh', ar: 'المزة', en: 'Mezzeh', lat: 33.502155, lng: 36.245687 },
  { gov: 'damascus', city: 'damascus', key: 'malki', ar: 'المالكي', en: 'Malki', lat: 33.515000, lng: 36.276000 },
  { gov: 'damascus', city: 'damascus', key: 'abu-rummaneh', ar: 'أبو رمانة', en: 'Abu Rummaneh', lat: 33.518500, lng: 36.283000 },
  { gov: 'damascus', city: 'damascus', key: 'old-city', ar: 'دمشق القديمة', en: 'Old City', lat: 33.511500, lng: 36.306500 },
  { gov: 'damascus', city: 'damascus', key: 'midan', ar: 'الميدان', en: 'Midan', lat: 33.495000, lng: 36.293000 },
  { gov: 'damascus', city: 'damascus', key: 'qaboun', ar: 'القابون', en: 'Qaboun', lat: 33.539000, lng: 36.330000 },
  { gov: 'damascus', city: 'damascus', key: 'barzeh', ar: 'برزة', en: 'Barzeh', lat: 33.546000, lng: 36.318000 },
  { gov: 'damascus', city: 'damascus', key: 'kafr-souseh', ar: 'كفر سوسة', en: 'Kafr Souseh', lat: 33.494000, lng: 36.262000 },
  { gov: 'damascus', city: 'damascus', key: 'dummar', ar: 'دمر', en: 'Dummar', lat: 33.531000, lng: 36.218000 },
  // --- Aleppo city ---
  { gov: 'aleppo', city: 'aleppo', key: 'aziziyah', ar: 'العزيزية', en: 'Aziziyah', lat: 36.205000, lng: 37.146000 },
  { gov: 'aleppo', city: 'aleppo', key: 'sulaymaniyah', ar: 'السليمانية', en: 'Sulaymaniyah', lat: 36.216548, lng: 37.159055 },
  { gov: 'aleppo', city: 'aleppo', key: 'old-city', ar: 'حلب القديمة', en: 'Old City', lat: 36.199469, lng: 37.163613 },
  { gov: 'aleppo', city: 'aleppo', key: 'hamdaniyah', ar: 'الحمدانية', en: 'Hamdaniyah', lat: 36.180000, lng: 37.110000 },
  { gov: 'aleppo', city: 'aleppo', key: 'furqan', ar: 'الفرقان', en: 'Furqan', lat: 36.219000, lng: 37.123000 },
  // --- Homs city ---
  { gov: 'homs', city: 'homs', key: 'old-city', ar: 'حمص القديمة', en: 'Old City', lat: 34.725181, lng: 36.724225 },
  { gov: 'homs', city: 'homs', key: 'al-waer', ar: 'الوعر', en: 'Al-Waer', lat: 34.740000, lng: 36.671000 },
  { gov: 'homs', city: 'homs', key: 'akrama', ar: 'عكرمة', en: 'Akrama', lat: 34.717000, lng: 36.742000 },
  // --- Latakia city ---
  { gov: 'latakia', city: 'latakia', key: 'corniche', ar: 'الكورنيش', en: 'Corniche', lat: 35.520997, lng: 35.801044 },
  { gov: 'latakia', city: 'latakia', key: 'al-ziraa', ar: 'الزراعة', en: 'Al-Ziraa', lat: 35.531000, lng: 35.793000 },
  { gov: 'latakia', city: 'latakia', key: 'al-sleibeh', ar: 'الصليبة', en: 'Al-Sleibeh', lat: 35.524000, lng: 35.787000 },
  // --- Hama city ---
  { gov: 'hama', city: 'hama', key: 'norias', ar: 'النواعير', en: 'Norias', lat: 35.135055, lng: 36.768125 },
  { gov: 'hama', city: 'hama', key: 'al-hadher', ar: 'الحاضر', en: 'Al-Hadher', lat: 35.126000, lng: 36.758000 },
  // --- Tartus city ---
  { gov: 'tartus', city: 'tartus', key: 'corniche', ar: 'الكورنيش', en: 'Corniche', lat: 34.873137, lng: 35.882914 },
  { gov: 'tartus', city: 'tartus', key: 'al-thawra', ar: 'الثورة', en: 'Al-Thawra', lat: 34.889000, lng: 35.889000 },
  // --- Deir ez-Zor city ---
  { gov: 'deir-ez-zor', city: 'deir-ez-zor', key: 'al-joura', ar: 'الجورة', en: 'Al-Joura', lat: 35.336000, lng: 40.144000 },
  { gov: 'deir-ez-zor', city: 'deir-ez-zor', key: 'al-qusour', ar: 'القصور', en: 'Al-Qusour', lat: 35.341000, lng: 40.152000 },
  // --- Raqqa city ---
  { gov: 'al-raqqah', city: 'al-raqqah', key: 'al-mansour', ar: 'المنصور', en: 'Al-Mansour', lat: 35.953000, lng: 39.009000 },
  { gov: 'al-raqqah', city: 'al-raqqah', key: 'al-mishlab', ar: 'المشلب', en: 'Al-Mishlab', lat: 35.948000, lng: 39.030000 },
  // --- Hasakah city ---
  { gov: 'al-hasakah', city: 'al-hasakah', key: 'al-aziziyah', ar: 'العزيزية', en: 'Al-Aziziyah', lat: 36.504000, lng: 40.748000 },
  { gov: 'al-hasakah', city: 'al-hasakah', key: 'al-nashwa', ar: 'النشوة', en: 'Al-Nashwa', lat: 36.491000, lng: 40.760000 },
  // --- Idlib city ---
  { gov: 'idlib', city: 'idlib', key: 'downtown', ar: 'وسط إدلب', en: 'Downtown', lat: 35.930000, lng: 36.634000 },
  { gov: 'idlib', city: 'idlib', key: 'al-qusour', ar: 'القصور', en: 'Al-Qusour', lat: 35.937000, lng: 36.640000 },
  // --- Daraa city ---
  { gov: 'daraa', city: 'daraa', key: 'al-balad', ar: 'درعا البلد', en: 'Al-Balad', lat: 32.617000, lng: 36.105000 },
  { gov: 'daraa', city: 'daraa', key: 'al-mahatta', ar: 'المحطة', en: 'Al-Mahatta', lat: 32.625000, lng: 36.114000 },
  // --- Suwayda city ---
  { gov: 'as-suwayda', city: 'as-suwayda', key: 'downtown', ar: 'وسط السويداء', en: 'Downtown', lat: 32.709000, lng: 36.566000 },
  { gov: 'as-suwayda', city: 'as-suwayda', key: 'al-maqwas', ar: 'المقوس', en: 'Al-Maqwas', lat: 32.715000, lng: 36.575000 },
  // --- Quneitra ---
  { gov: 'quneitra', city: 'quneitra', key: 'downtown', ar: 'وسط القنيطرة', en: 'Downtown', lat: 33.126000, lng: 35.825000 },
  // --- Existing seeded cities with no OCHA ADM2/ADM3 coverage: give them a center area ---
  { gov: 'daraa', city: 'bosra', key: 'bosra-center', ar: 'وسط بصرى', en: 'Bosra Center', lat: 32.518100, lng: 36.481900 },
];

// ---------------------------------------------------------------------------
// helpers
// ---------------------------------------------------------------------------
function slug(s) {
  return String(s ?? '')
    .toLowerCase()
    .replace(/[’‘'"`،]/g, '') // strip apostrophes / curly quotes / arabic comma
    .replace(/[^a-z0-9]+/g, '-')
    .replace(/^-+|-+$/g, '')
    .replace(/-+/g, '-');
}

function clampLat(v) {
  return Math.min(LAT_MAX, Math.max(LAT_MIN, v));
}
function clampLng(v) {
  return Math.min(LNG_MAX, Math.max(LNG_MIN, v));
}
function inBounds(lat, lng) {
  return lat >= LAT_MIN && lat <= LAT_MAX && lng >= LNG_MIN && lng <= LNG_MAX;
}
function round6(v) {
  return Math.round(v * 1e6) / 1e6;
}

// SQL string literal (single-quote escaped).
function sql(s) {
  return "'" + String(s).replace(/'/g, "''") + "'";
}
// JSONB display_name literal.
function jname(ar, en) {
  const o = { ar: String(ar).trim() };
  if (en != null && String(en).trim() !== '') o.en = String(en).trim();
  return sql(JSON.stringify(o)) + '::jsonb';
}

// ---------------------------------------------------------------------------
// data acquisition: cache -> fetch+unzip -> embedded fallback
// ---------------------------------------------------------------------------
function readCachedLayer(name) {
  const p = path.join(CACHE_DIR, name);
  if (fs.existsSync(p)) return JSON.parse(fs.readFileSync(p, 'utf8'));
  return null;
}

async function ensureLayers() {
  let a1 = readCachedLayer('syr_admin1.geojson');
  let a2 = readCachedLayer('syr_admin2.geojson');
  let a3 = readCachedLayer('syr_admin3.geojson');
  if (a1 && a2 && a3) {
    console.error('[locations] using cached OCHA HDX COD-AB layers.');
    return { a1, a2, a3, source: 'OCHA HDX COD-AB v02 (cached)' };
  }
  try {
    fs.mkdirSync(CACHE_DIR, { recursive: true });
    const tmpZip = path.join(os.tmpdir(), 'syr_geojson_' + Date.now() + '.zip');
    console.error('[locations] fetching OCHA HDX COD-AB GeoJSON bundle ...');
    execFileSync('curl', ['-sSL', '--max-time', '180', HDX_GEOJSON_ZIP_URL, '-o', tmpZip], {
      stdio: ['ignore', 'ignore', 'inherit'],
    });
    execFileSync(
      'unzip',
      ['-o', tmpZip, 'syr_admin1.geojson', 'syr_admin2.geojson', 'syr_admin3.geojson', '-d', CACHE_DIR],
      { stdio: ['ignore', 'ignore', 'inherit'] },
    );
    a1 = readCachedLayer('syr_admin1.geojson');
    a2 = readCachedLayer('syr_admin2.geojson');
    a3 = readCachedLayer('syr_admin3.geojson');
    if (a1 && a2 && a3) {
      console.error('[locations] fetched OCHA HDX COD-AB layers.');
      return { a1, a2, a3, source: 'OCHA HDX COD-AB v02 (fetched)' };
    }
  } catch (e) {
    console.error('[locations] network fetch failed:', e.message);
  }
  console.error('[locations] FALLBACK: embedded curated hierarchy (network/data unavailable).');
  return { a1: null, a2: null, a3: null, source: 'embedded curated fallback' };
}

// ---------------------------------------------------------------------------
// build the in-memory model
// ---------------------------------------------------------------------------
function buildModel({ a1, a2, a3 }) {
  // cities: keyed by gov key -> [{key, ar, en, pos, pcode, lat, lng}]
  // areas:  list of {gov, city, key, ar, en, lat, lng}
  const cities = []; // {gov, key, ar, en, pos}
  const cityByPcode = {}; // adm2_pcode -> {gov, key}
  const areas = [];
  const govPos = {}; // running position per gov

  if (a2) {
    let pos = 10;
    const order = {}; // gov -> next position
    for (const f of a2.features) {
      const p = f.properties;
      const gov = PCODE_TO_GOV[p.adm1_pcode];
      if (!gov) {
        console.error('[locations] skip ADM2 with unknown gov pcode:', p.adm1_pcode, p.adm2_name);
        continue;
      }
      const ovKey = p.adm1_pcode + '/' + slug(p.adm2_name);
      const key = CITY_KEY_OVERRIDE[ovKey] || slug(p.adm2_name);
      order[gov] = (order[gov] || 0) + 10;
      cities.push({ gov, key, ar: p.adm2_name1, en: p.adm2_name, pos: order[gov] });
      cityByPcode[p.adm2_pcode] = { gov, key };

      // default "<city>-center" area at the district centroid.
      let lat = Number(p.center_lat), lng = Number(p.center_lon);
      if (!inBounds(lat, lng)) { lat = clampLat(lat); lng = clampLng(lng); }
      areas.push({
        gov, city: key, key: key + '-center',
        ar: 'وسط ' + p.adm2_name1, en: p.adm2_name + ' Center',
        lat: round6(lat), lng: round6(lng),
      });
    }
  }

  if (a3) {
    const seenAreaKey = new Set(areas.map((a) => a.gov + '/' + a.city + '/' + a.key));
    for (const f of a3.features) {
      const p = f.properties;
      const parent = cityByPcode[p.adm2_pcode];
      if (!parent) continue; // ADM3 whose parent ADM2 we did not emit
      let key = slug(p.adm3_name);
      if (!key) continue;
      const guard = parent.gov + '/' + parent.key + '/' + key;
      if (seenAreaKey.has(guard)) continue; // avoid duplicate vs. the -center area
      let lat = Number(p.center_lat), lng = Number(p.center_lon);
      if (!inBounds(lat, lng)) { lat = clampLat(lat); lng = clampLng(lng); }
      seenAreaKey.add(guard);
      areas.push({
        gov: parent.gov, city: parent.key, key,
        ar: p.adm3_name1, en: p.adm3_name,
        lat: round6(lat), lng: round6(lng),
      });
    }
  }

  return { cities, areas };
}

// Embedded curated fallback (used only when no OCHA data is available). A real
// — if smaller — hierarchy: every governorate gets its seat district as a city
// plus a couple of well-known districts, each with a -center area, and the
// marquee neighborhoods are appended below for every path.
function buildFallbackModel() {
  // gov key -> [{key, ar, en, lat, lng}]  (each becomes a city + a -center area)
  const FALLBACK_CITIES = {
    'damascus': [{ key: 'damascus', ar: 'دمشق', en: 'Damascus', lat: 33.5155, lng: 36.2738 }],
    'aleppo': [
      { key: 'aleppo', ar: 'حلب', en: 'Aleppo', lat: 36.1469, lng: 37.3952 },
      { key: 'manbij', ar: 'منبج', en: 'Manbij', lat: 36.5281, lng: 37.9550 },
      { key: 'afrin', ar: 'عفرين', en: 'Afrin', lat: 36.5117, lng: 36.8694 },
      { key: 'azaz', ar: 'أعزاز', en: 'Azaz', lat: 36.5867, lng: 37.0464 },
    ],
    'homs': [
      { key: 'homs', ar: 'حمص', en: 'Homs', lat: 34.7324, lng: 36.7137 },
      { key: 'palmyra', ar: 'تدمر', en: 'Palmyra', lat: 34.5566, lng: 38.2843 },
      { key: 'talkalakh', ar: 'تلكلخ', en: 'Talkalakh', lat: 34.6669, lng: 36.2595 },
    ],
    'latakia': [
      { key: 'latakia', ar: 'اللاذقية', en: 'Latakia', lat: 35.5196, lng: 35.7915 },
      { key: 'jableh', ar: 'جبلة', en: 'Jableh', lat: 35.3614, lng: 35.9258 },
    ],
    'tartus': [
      { key: 'tartus', ar: 'طرطوس', en: 'Tartus', lat: 34.8890, lng: 35.8866 },
      { key: 'banias', ar: 'بانياس', en: 'Banias', lat: 35.1820, lng: 35.9460 },
    ],
    'hama': [
      { key: 'hama', ar: 'حماة', en: 'Hama', lat: 35.1318, lng: 36.7578 },
      { key: 'salamiya', ar: 'سلمية', en: 'Salamiya', lat: 35.0117, lng: 37.0530 },
      { key: 'masyaf', ar: 'مصياف', en: 'Masyaf', lat: 35.0656, lng: 36.3408 },
    ],
    'rif-dimashq': [
      { key: 'rif-dimashq-center', ar: 'مركز ريف دمشق', en: 'Rural Damascus', lat: 33.4525, lng: 36.5500 },
      { key: 'douma', ar: 'دوما', en: 'Douma', lat: 33.5719, lng: 36.4031 },
      { key: 'yabroud', ar: 'يبرود', en: 'Yabroud', lat: 33.9697, lng: 36.6575 },
      { key: 'qatana', ar: 'قطنا', en: 'Qatana', lat: 33.4378, lng: 36.0775 },
    ],
    'idlib': [
      { key: 'idlib', ar: 'إدلب', en: 'Idlib', lat: 35.9306, lng: 36.6339 },
      { key: 'maaret-al-numan', ar: 'معرة النعمان', en: 'Maaret al-Numan', lat: 35.6486, lng: 36.6786 },
    ],
    'daraa': [
      { key: 'daraa', ar: 'درعا', en: 'Daraa', lat: 32.6189, lng: 36.1021 },
      { key: 'bosra', ar: 'بصرى', en: 'Bosra', lat: 32.5181, lng: 36.4819 },
    ],
    'deir-ez-zor': [
      { key: 'deir-ez-zor', ar: 'دير الزور', en: 'Deir ez-Zor', lat: 35.3359, lng: 40.1408 },
      { key: 'albu-kamal', ar: 'البوكمال', en: 'Albu Kamal', lat: 34.4517, lng: 40.9189 },
      { key: 'mayadeen', ar: 'الميادين', en: 'Mayadeen', lat: 35.0186, lng: 40.4506 },
    ],
    'al-hasakah': [
      { key: 'al-hasakah', ar: 'الحسكة', en: 'Al-Hasakah', lat: 36.5004, lng: 40.7478 },
      { key: 'qamishli', ar: 'القامشلي', en: 'Qamishli', lat: 37.0522, lng: 41.2317 },
    ],
    'al-raqqah': [
      { key: 'al-raqqah', ar: 'الرقة', en: 'Al-Raqqah', lat: 35.9528, lng: 39.0079 },
      { key: 'tabqa', ar: 'الطبقة', en: 'Tabqa', lat: 35.8367, lng: 38.5481 },
    ],
    'as-suwayda': [
      { key: 'as-suwayda', ar: 'السويداء', en: 'As-Suwayda', lat: 32.7089, lng: 36.5664 },
      { key: 'shahba', ar: 'شهبا', en: 'Shahba', lat: 32.8542, lng: 36.6286 },
    ],
    'quneitra': [
      { key: 'quneitra', ar: 'القنيطرة', en: 'Quneitra', lat: 33.1261, lng: 35.8250 },
    ],
  };
  const cities = [];
  const areas = [];
  for (const gov of Object.keys(FALLBACK_CITIES)) {
    let pos = 0;
    for (const c of FALLBACK_CITIES[gov]) {
      pos += 10;
      cities.push({ gov, key: c.key, ar: c.ar, en: c.en, pos });
      let lat = c.lat, lng = c.lng;
      if (!inBounds(lat, lng)) { lat = clampLat(lat); lng = clampLng(lng); }
      areas.push({
        gov, city: c.key, key: c.key + '-center',
        ar: 'وسط ' + c.ar, en: c.en + ' Center',
        lat: round6(lat), lng: round6(lng),
      });
    }
  }
  return { cities, areas };
}

// ---------------------------------------------------------------------------
// merge curated neighborhoods (skip if the (gov,city,key) already present, and
// only if its city exists in the model)
// ---------------------------------------------------------------------------
function mergeCurated(model, extraAttachableCities = new Set()) {
  const cityKeys = new Set(model.cities.map((c) => c.gov + '/' + c.key));
  for (const k of extraAttachableCities) cityKeys.add(k);
  const areaKeys = new Set(model.areas.map((a) => a.gov + '/' + a.city + '/' + a.key));
  let added = 0;
  for (const n of CURATED_NEIGHBORHOODS) {
    if (!cityKeys.has(n.gov + '/' + n.city)) continue; // city neither in model nor a known existing seeded city
    const guard = n.gov + '/' + n.city + '/' + n.key;
    if (areaKeys.has(guard)) continue;
    let lat = n.lat, lng = n.lng;
    if (!inBounds(lat, lng)) { lat = clampLat(lat); lng = clampLng(lng); }
    areaKeys.add(guard);
    model.areas.push({
      gov: n.gov, city: n.city, key: n.key, ar: n.ar, en: n.en,
      lat: round6(lat), lng: round6(lng),
    });
    added++;
  }
  return added;
}

// ---------------------------------------------------------------------------
// validation
// ---------------------------------------------------------------------------
function validate(model) {
  const keyRe = /^[a-z0-9][a-z0-9-]*$/;
  // city key unique per gov + valid format
  const cseen = new Set();
  for (const c of model.cities) {
    if (!keyRe.test(c.key)) throw new Error('bad city key: ' + c.gov + '/' + c.key);
    const id = c.gov + '/' + c.key;
    if (cseen.has(id)) {
      // collapse duplicates (same gov+key) — keep first; harmless ON CONFLICT
      c.__dup = true;
    }
    cseen.add(id);
    if (!c.ar || !String(c.ar).trim()) throw new Error('city missing ar: ' + id);
  }
  model.cities = model.cities.filter((c) => !c.__dup);

  const aseen = new Set();
  for (const a of model.areas) {
    if (!keyRe.test(a.key)) throw new Error('bad area key: ' + a.gov + '/' + a.city + '/' + a.key);
    const id = a.gov + '/' + a.city + '/' + a.key;
    if (aseen.has(id)) { a.__dup = true; }
    aseen.add(id);
    if (!a.ar || !String(a.ar).trim()) throw new Error('area missing ar: ' + id);
    if (!inBounds(a.lat, a.lng)) {
      throw new Error('area centroid out of bounds after clamp: ' + id + ' ' + a.lat + ',' + a.lng);
    }
  }
  model.areas = model.areas.filter((a) => !a.__dup);
}

// ---------------------------------------------------------------------------
// SQL emission
// ---------------------------------------------------------------------------
function emitSql(model, source) {
  const L = [];
  L.push('-- Phase 031 WS-C — Full Syria locations dataset (governorates -> cities -> areas).');
  L.push('--');
  L.push('-- DATA SOURCE / ATTRIBUTION:');
  L.push('--   Syrian Arab Republic - Subnational Administrative Boundaries (COD-AB).');
  L.push('--   OCHA Field Information Services Section (FISS), via HDX:');
  L.push('--     https://data.humdata.org/dataset/cod-ab-syr');
  L.push('--   License: CC BY-IGO (attribution required). Bilingual (ar+en) names and');
  L.push('--   per-feature representative centroids ship with the dataset.');
  L.push('--   Marquee city neighborhoods are a small curated supplement.');
  L.push('--   Generated by tool/locations/build_syria_seed.mjs');
  L.push('--   Source used for this build: ' + source + '.');
  L.push('--');
  L.push('-- MAPPING: ADM1 -> existing governorate (referenced by key, NOT re-inserted);');
  L.push('--          ADM2 (districts/manatiq) -> public.cities;');
  L.push('--          ADM3 (sub-districts) + curated neighborhoods -> public.areas.');
  L.push('--          Every city gets a default "<city>-center" area so submit_listing');
  L.push('--          always has at least one selectable area.');
  L.push('--');
  L.push('-- ROW COUNTS (new rows; ON CONFLICT DO NOTHING makes this idempotent):');
  L.push('--   new cities: ' + model.cities.length);
  L.push('--   new areas:  ' + model.areas.length);
  L.push('--');
  L.push('-- All new rows: is_system=false (cities), is_active=true. Centroids validated');
  L.push('-- inside lat 32..37 / lng 35..43 (areas_centroid_syria_bounds).');
  L.push('');
  L.push('BEGIN;');
  L.push('');

  // ---- cities ----
  L.push('-- ============================================================');
  L.push('-- CITIES (' + model.cities.length + ' rows) — ADM2 districts/manatiq');
  L.push('-- ============================================================');
  for (const c of model.cities) {
    L.push('INSERT INTO public.cities (governorate_id, key, display_name, position, is_active, is_system)');
    L.push('SELECT g.id, ' + sql(c.key) + ', ' + jname(c.ar, c.en) + ', ' + c.pos + ', true, false');
    L.push('FROM public.governorates g WHERE g.key = ' + sql(c.gov));
    L.push('ON CONFLICT (governorate_id, key) DO NOTHING;');
    L.push('');
  }

  // ---- areas ----
  L.push('-- ============================================================');
  L.push('-- AREAS (' + model.areas.length + ' rows) — ADM3 sub-districts + curated neighborhoods');
  L.push('-- city_id resolved by joining governorates + cities on (gov key, city key).');
  L.push('-- ============================================================');
  // group areas by gov/city for readability, but each is its own idempotent stmt.
  let posByCity = {};
  for (const a of model.areas) {
    const ck = a.gov + '/' + a.city;
    posByCity[ck] = (posByCity[ck] || 0) + 10;
    const pos = posByCity[ck];
    L.push('INSERT INTO public.areas (city_id, key, display_name, position, is_active, centroid_lat, centroid_lng)');
    L.push('SELECT c.id, ' + sql(a.key) + ', ' + jname(a.ar, a.en) + ', ' + pos + ', true, ' +
      a.lat.toFixed(6) + ', ' + a.lng.toFixed(6));
    L.push('FROM public.cities c JOIN public.governorates g ON g.id = c.governorate_id');
    L.push('WHERE g.key = ' + sql(a.gov) + ' AND c.key = ' + sql(a.city));
    L.push('ON CONFLICT (city_id, key) DO NOTHING;');
    L.push('');
  }

  L.push('COMMIT;');
  L.push('');
  return L.join('\n');
}

// ---------------------------------------------------------------------------
// main
// ---------------------------------------------------------------------------
async function main() {
  const layers = await ensureLayers();
  let model;
  if (layers.a2) {
    model = buildModel(layers);
  } else {
    model = buildFallbackModel();
  }
  const curatedAdded = mergeCurated(model, EXISTING_SEEDED_CITIES);
  validate(model);

  const sqlText = emitSql(model, layers.source);
  fs.mkdirSync(path.dirname(OUT_SQL), { recursive: true });
  fs.writeFileSync(OUT_SQL, sqlText, 'utf8');

  const govCities = {};
  for (const c of model.cities) govCities[c.gov] = (govCities[c.gov] || 0) + 1;

  console.error('--------------------------------------------------------');
  console.error('[locations] source       : ' + layers.source);
  console.error('[locations] new cities    : ' + model.cities.length);
  console.error('[locations] new areas     : ' + model.areas.length +
    '  (curated neighborhoods merged: ' + curatedAdded + ')');
  console.error('[locations] cities/gov    : ' +
    Object.keys(govCities).map((g) => g + '=' + govCities[g]).join(', '));
  console.error('[locations] wrote         : ' + path.relative(REPO_ROOT, OUT_SQL));
  console.error('--------------------------------------------------------');
}

main().catch((e) => {
  console.error('[locations] FAILED:', e);
  process.exit(1);
});
