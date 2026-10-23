"use strict";

// ═══════════════════════════════════════════════════════════════════════════
//  1. PROCEDURAL NOISE & 4 SPECIFIC CATALAN PARALLAX THEATRES
// ═══════════════════════════════════════════════════════════════════════════
const PERM = new Uint8Array(512);
(function initNoise() {
  const p = new Uint8Array(256);
  for (let i = 0; i < 256; i++) p[i] = i;
  let seed = 4219;
  for (let i = 255; i > 0; i--) {
    seed = (seed * 16807) % 2147483647;
    const j = seed % (i + 1);
    const t = p[i]; p[i] = p[j]; p[j] = t;
  }
  for (let i = 0; i < 512; i++) PERM[i] = p[i & 255];
})();

function fade(t) { return t * t * t * (t * (t * 6 - 15) + 10); }
function lerp(a, b, t) { return a + t * (b - a); }
function clamp(v, lo, hi) { return Number.isFinite(v) ? Math.max(lo, Math.min(hi, v)) : lo; }

function grad2(hash, x, y) {
  const h = hash & 7;
  const u = h < 4 ? x : y;
  const v = h < 4 ? y : x;
  return ((h & 1) ? -u : u) + ((h & 2) ? -2.0 * v : 2.0 * v);
}

function noise2D(x, y) {
  const X = Math.floor(x) & 255, Y = Math.floor(y) & 255;
  x -= Math.floor(x); y -= Math.floor(y);
  const u = fade(x), v = fade(y);
  const A = PERM[X] + Y, B = PERM[X + 1] + Y;
  return lerp(
    lerp(grad2(PERM[A], x, y), grad2(PERM[B], x - 1, y), u),
    lerp(grad2(PERM[A + 1], x, y - 1), grad2(PERM[B + 1], x - 1, y - 1), u),
    v
  ) * 0.5 + 0.5;
}

function fbm(x, y, octaves = 5) {
  let val = 0, amp = 0.5, freq = 1, max = 0;
  for (let i = 0; i < octaves; i++) {
    val += noise2D(x * freq, y * freq) * amp;
    max += amp;
    freq *= 2.04;
    amp *= 0.5;
  }
  return val / max;
}

function ridgedFbm(x, y, octaves = 5) {
  let val = 0, amp = 0.5, freq = 1, weight = 1, max = 0;
  for (let i = 0; i < octaves; i++) {
    let n = 1.0 - Math.abs(noise2D(x * freq, y * freq) * 2.0 - 1.0);
    n = n * n * weight;
    weight = clamp(n * 2.0, 0, 1);
    val += n * amp;
    max += amp;
    freq *= 2.12;
    amp *= 0.5;
  }
  return val / max;
}

// 4 Hyper-Specific, Geographically Authentic Catalan Theatres!
const MAPS = [
  {
    id: 'MONTSERRAT',
    name: 'Massís de Montserrat',
    subtitle: 'Monestir de Santa Maria, Agulles i Aeri (Bages)',
    badge: 'BOIRA I PINARS',
    bgPath: 'assets/bg_montserrat.jpg',
    weather: 'POLLEN',
    slideFriction: 0.964,
    sky: ['#2a1e2e', '#593b4f', '#9c6352', '#de9659', '#fae6b1'],
    waterTop: 'rgba(42, 114, 122, 0.82)',
    waterDeep: 'rgba(12, 36, 44, 0.98)',
    turfCol: [92, 118, 52],
    soilCol: [134, 84, 58],
    rockCol: [148, 128, 122], // Pale pinkish-grey Montserrat conglomerate rock!
    treeStyle: 'UMBRELLA_PINE'
  },
  {
    id: 'CADAQUES',
    name: 'Cadaqués i Cap de Creus',
    subtitle: 'Església de Santa Maria, Llaguts i Feixes (Alt Empordà)',
    badge: 'TRAMUNTANA VIVA',
    bgPath: 'assets/bg_cadaques.jpg',
    weather: 'GULLS_BREEZE',
    slideFriction: 0.968,
    sky: ['#10355c', '#1f5a8f', '#4287bd', '#7eb8de', '#cbe6f7'],
    waterTop: 'rgba(18, 152, 178, 0.82)',
    waterDeep: 'rgba(6, 42, 68, 0.98)',
    turfCol: [88, 108, 56],
    soilCol: [92, 76, 62],
    rockCol: [74, 80, 92], // Dark Cap de Creus Empordà slate (pissarra)!
    treeStyle: 'CYPRESS'
  },
  {
    id: 'TAULL',
    name: 'Taüll i la Vall de Boí',
    subtitle: 'Sant Climent de Taüll i Aigüestortes (Alta Ribagorça)',
    badge: 'NEU DEL PIRINEU',
    bgPath: 'assets/bg_taull.jpg',
    weather: 'SNOW',
    slideFriction: 0.976, // Slippery Pyrenean alpine frost & moss!
    sky: ['#172b47', '#2c4c73', '#527ca6', '#8eb3d4', '#d9eaf7'],
    waterTop: 'rgba(48, 126, 162, 0.82)',
    waterDeep: 'rgba(10, 32, 52, 0.98)',
    turfCol: [64, 126, 56],
    soilCol: [78, 58, 42],
    rockCol: [98, 106, 116], // Pyrenean granite & slate!
    treeStyle: 'DOUGLAS_FIR'
  },
  {
    id: 'CASTELLFOLLIT',
    name: 'Castellfollit de la Roca',
    subtitle: 'Cinglera Basàltica i Fageda d\'en Jordà (La Garrotxa)',
    badge: 'FULLES DE FAIG',
    bgPath: 'assets/bg_castellfollit.jpg',
    weather: 'AUTUMN_LEAVES',
    slideFriction: 0.966,
    sky: ['#2b1d1c', '#633c2e', '#a8673e', '#dea05a', '#f7d89c'],
    waterTop: 'rgba(44, 106, 112, 0.82)',
    waterDeep: 'rgba(14, 34, 38, 0.98)',
    turfCol: [118, 104, 46],
    soilCol: [86, 52, 38],
    rockCol: [64, 62, 68], // Dark volcanic Garrotxa basalt columns!
    treeStyle: 'UMBRELLA_PINE'
  }
];

let currentMapIdx = Math.floor(Math.random() * MAPS.length); // Random Catalan background on load!

const BG_IMAGES = {};
MAPS.forEach(m => {
  const img = new Image();
  img.src = m.bgPath;
  BG_IMAGES[m.id] = img;
});

const ASSETS = {
  cloudLayer: null,
  fogRibbon: null
};

function buildBackgroundAssets() {
  ASSETS.cloudLayer = renderCloudLayer(1600, 320);
}

function renderCloudLayer(w, h) {
  const c = document.createElement('canvas');
  c.width = w; c.height = h;
  const cx = c.getContext('2d');
  const img = cx.createImageData(w, h);
  const d = img.data;

  for (let y = 0; y < h; y++) {
    const vy = y / h;
    const env = Math.sin(vy * Math.PI);
    for (let x = 0; x < w; x++) {
      const nx = x / w;
      const angle = nx * Math.PI * 2;
      const u = Math.cos(angle) * 1.6 + 5.0;
      const n = fbm(u, y * 0.012, 5) * env;
      if (n > 0.36) {
        const density = Math.min(1, (n - 0.36) * 2.6);
        const nAbove = fbm(u, (y - 6) * 0.012, 4) * env;
        const sunRim = clamp((n - nAbove) * 4.5 + 0.65, 0, 1);
        const idx = (y * w + x) * 4;
        d[idx]     = lerp(165, 252, sunRim);
        d[idx + 1] = lerp(155, 234, sunRim);
        d[idx + 2] = lerp(150, 214, sunRim);
        d[idx + 3] = Math.floor(density * 135);
      }
    }
  }
  cx.putImageData(img, 0, 0);
  return c;
}

// ═══════════════════════════════════════════════════════════════════════════
//  2. EXPANSIVE 3200px DESTRUCTIBLE 2.5D TERRAIN & RANDOMIZED LANDMARKS
// ═══════════════════════════════════════════════════════════════════════════
const TERRAIN_W = 3200;
const TERRAIN_H = 820;
let WATER_Y     = 700;

const terrainMask = new Uint8Array(TERRAIN_W * TERRAIN_H);
const terrainFront = document.createElement('canvas');
terrainFront.width = TERRAIN_W; terrainFront.height = TERRAIN_H;
const tfCtx = terrainFront.getContext('2d');

const terrainBack = document.createElement('canvas');
terrainBack.width = TERRAIN_W; terrainBack.height = TERRAIN_H;
const tbCtx = terrainBack.getContext('2d');

let mapSeed = 2.4;
let generatedTreeSpots = [];
let generatedValleySpots = [];

function setTerrainPixel(x, y, r, g, b, fd, bd, br = 38, bg = 32, bb = 28) {
  const ix = Math.floor(x), iy = Math.floor(y);
  if (ix < 0 || ix >= TERRAIN_W || iy < 0 || iy >= TERRAIN_H) return;
  terrainMask[iy * TERRAIN_W + ix] = 1;
  const idx = (iy * TERRAIN_W + ix) * 4;
  fd[idx] = clamp(r, 0, 255);
  fd[idx + 1] = clamp(g, 0, 255);
  fd[idx + 2] = clamp(b, 0, 255);
  fd[idx + 3] = 255;
  bd[idx] = br; bd[idx + 1] = bg; bd[idx + 2] = bb; bd[idx + 3] = 255;
}

function clearTerrainPixel(x, y, fd) {
  const ix = Math.floor(x), iy = Math.floor(y);
  if (ix < 0 || ix >= TERRAIN_W || iy < 0 || iy >= TERRAIN_H) return;
  terrainMask[iy * TERRAIN_W + ix] = 0;
  const idx = (iy * TERRAIN_W + ix) * 4;
  fd[idx + 3] = 0;
}

function stampDestructibleTree(tx, ty, style, frontData, backData, scale = 1.0) {
  const baseTrunk = style === 'DOUGLAS_FIR' ? 76 : (style === 'UMBRELLA_PINE' ? 64 : 58);
  const trunkH = Math.round(baseTrunk * scale);
  for (let y = ty - trunkH; y <= ty + 10; y++) {
    const lean = style === 'UMBRELLA_PINE' ? Math.sin((ty - y) * 0.04) * 6 * scale : 0;
    const halfW = (y > ty - 16 ? 5.5 : 4.0) * scale;
    for (let x = Math.floor(tx + lean - halfW); x <= Math.ceil(tx + lean + halfW); x++) {
      const bark = 0.8 + noise2D(x * 0.25, y * 0.15) * 0.4;
      setTerrainPixel(x, y, 82 * bark, 54 * bark, 36 * bark, frontData, backData, 42, 28, 20);
    }
  }

  const crownY = ty - trunkH;
  if (style === 'UMBRELLA_PINE') {
    const rx = Math.round(48 * scale), ry = Math.round(25 * scale);
    for (let dy = -ry - 4; dy <= 8; dy++) {
      for (let dx = -rx; dx <= rx; dx++) {
        const nx = dx / rx, ny = (dy + 8) / ry;
        if (dy < 5 && (nx * nx + ny * ny) <= 1.0 + (noise2D((tx + dx) * 0.1, (crownY + dy) * 0.1) - 0.5) * 0.35) {
          const px = Math.floor(tx + dx), py = Math.floor(crownY + dy);
          const shade = clamp(0.75 - dy * 0.014 + (noise2D(px * 0.2, py * 0.2) - 0.5) * 0.3, 0.45, 1.25);
          setTerrainPixel(px, py, 62 * shade, 104 * shade, 44 * shade, frontData, backData, 28, 48, 22);
        }
      }
    }
  } else if (style === 'DOUGLAS_FIR') {
    for (let tier = 0; tier < 3; tier++) {
      const cy = crownY - tier * Math.round(18 * scale) + 12;
      const maxW = (34 - tier * 7) * scale;
      for (let dy = -Math.round(20 * scale); dy <= 6; dy++) {
        const span = ((dy + 20 * scale) / (26 * scale)) * maxW;
        for (let dx = -span; dx <= span; dx++) {
          const px = Math.floor(tx + dx), py = Math.floor(cy + dy);
          const shade = clamp(0.8 - dy * 0.016 + (noise2D(px * 0.2, py * 0.2) - 0.5) * 0.25, 0.45, 1.2);
          setTerrainPixel(px, py, 38 * shade, 88 * shade, 56 * shade, frontData, backData, 20, 44, 28);
        }
      }
    }
  } else {
    const rx = Math.round(40 * scale), ry = Math.round(20 * scale);
    for (let dy = -ry - 4; dy <= 6; dy++) {
      for (let dx = -rx; dx <= rx + 4; dx++) {
        const nx = (dx - 4) / rx, ny = (dy + 6) / ry;
        if (nx * nx + ny * ny <= 0.96) {
          const px = Math.floor(tx + dx), py = Math.floor(crownY + dy);
          const shade = clamp(0.78 - dy * 0.014, 0.5, 1.15);
          setTerrainPixel(px, py, 52 * shade, 86 * shade, 50 * shade, frontData, backData, 25, 42, 24);
        }
      }
    }
  }
  return { tx, crownY };
}

// Landmark 1: Destructible Stone Watchtower / Ruined Castle Keep with Sniper Window
function stampStoneWatchtower(cx, sy, fd, bd) {
  const w = 34, h = 84;
  for (let y = sy - h; y <= sy + 12; y++) {
    for (let x = cx - w; x <= cx + w; x++) {
      // Battlement crenelations along the top
      if (y < sy - h + 10 && Math.abs(x - cx) % 14 > 7) continue;
      const brick = ((Math.floor(x / 14) + Math.floor(y / 8)) % 2 === 0) ? 1.07 : 0.93;
      const n = noise2D(x * 0.15, y * 0.15) * 24;
      setTerrainPixel(x, y, (148 + n) * brick, (132 + n) * brick, (114 + n) * brick, fd, bd, 62, 54, 46);
    }
  }
  // Carve hollow arched sniper window & interior chamber so Orugas can hide inside!
  for (let y = sy - 52; y <= sy - 16; y++) {
    for (let x = cx - 18; x <= cx + 18; x++) {
      clearTerrainPixel(x, y, fd);
    }
  }
}

// Landmark 2: Giant Fallen Hollow Pine Log Tunnel
function stampHollowFallenLog(cx, sy, fd, bd) {
  const halfLen = 78;
  const tilt = (Math.random() - 0.5) * 0.14;
  for (let dx = -halfLen; dx <= halfLen; dx++) {
    const lx = cx + dx;
    const ly = sy - 14 + dx * tilt;
    for (let dy = -16; dy <= 12; dy++) {
      const x = Math.floor(lx), y = Math.floor(ly + dy);
      if (Math.abs(dy) >= 9) {
        // Outer bark roof & floor of the hollow log
        const bark = 0.78 + noise2D(x * 0.2, y * 0.2) * 0.35;
        setTerrainPixel(x, y, 92 * bark, 58 * bark, 36 * bark, fd, bd, 44, 28, 18);
      } else {
        // Hollow crawl-through interior!
        clearTerrainPixel(x, y, fd);
      }
    }
  }
}

// Landmark 3: Natural Sweeping Stone Arch / Sea Stack
function stampNaturalRockArch(cx, sy, fd, bd, mCfg) {
  const span = 115;
  const archH = 74;
  for (let dx = -span; dx <= span; dx++) {
    const normX = dx / span;
    const topY = sy - archH * Math.cos(normX * Math.PI * 0.5);
    const botY = sy - (archH - 24) * Math.max(0, Math.cos(normX * Math.PI * 0.68));
    for (let y = Math.floor(topY); y <= Math.floor(botY); y++) {
      const n = noise2D((cx + dx) * 0.08, y * 0.08) * 35;
      setTerrainPixel(
        cx + dx, y,
        mCfg.rockCol[0] + n, mCfg.rockCol[1] + n, mCfg.rockCol[2] + n,
        fd, bd
      );
    }
  }
}

// Landmark 4: Ancient Standing Monoliths / Stonehenge Lintel
function stampAncientMonoliths(cx, sy, fd, bd) {
  const pillars = [-42, 42];
  for (const px of pillars) {
    for (let y = sy - 58; y <= sy + 10; y++) {
      for (let dx = -9; dx <= 9; dx++) {
        const n = noise2D((cx + px + dx) * 0.12, y * 0.12) * 28;
        setTerrainPixel(cx + px + dx, y, 128 + n, 124 + n, 118 + n, fd, bd, 54, 52, 48);
      }
    }
  }
  // Horizontal stone lintel across the top
  for (let y = sy - 68; y <= sy - 54; y++) {
    for (let dx = -56; dx <= 56; dx++) {
      const n = noise2D((cx + dx) * 0.12, y * 0.12) * 28;
      setTerrainPixel(cx + dx, y, 136 + n, 130 + n, 122 + n, fd, bd, 54, 52, 48);
    }
  }
}

// Landmark 5: Multi-Arch Stone Viaduct / Romanesque Bridge
function stampRomanesqueViaduct(x1, x2, deckY, fd, bd) {
  for (let x = Math.floor(x1); x <= Math.ceil(x2); x++) {
    const localX = x - x1;
    const archDist = Math.abs((localX % 130) - 65);
    const maxY = deckY + 14 + Math.pow((65 - archDist) / 65, 2) * 44;
    for (let y = Math.floor(deckY); y <= Math.floor(maxY); y++) {
      const brick = ((Math.floor(x / 18) + Math.floor(y / 9)) % 2 === 0) ? 1.08 : 0.94;
      const n = noise2D(x * 0.08, y * 0.08) * 26;
      setTerrainPixel(x, y, (162 + n) * brick, (126 + n) * brick, (92 + n) * brick, fd, bd, 68, 52, 38);
    }
  }
}

// Landmark 6: Suspension Steel Truss Bridge Span
function stampSteelTrussSpan(x1, x2, deckY, fd, bd, isOrange = true) {
  for (let x = Math.floor(x1); x <= Math.ceil(x2); x++) {
    for (let y = Math.floor(deckY); y <= Math.floor(deckY + 18); y++) {
      const truss = ((x + y) % 14 < 3 || (x - y + 1000) % 14 < 3 || y <= deckY + 4 || y >= deckY + 15);
      if (!truss && (x % 28 > 4)) continue;
      const shade = truss ? 1.08 : 0.85;
      if (isOrange) {
        setTerrainPixel(x, y, 198 * shade, 68 * shade, 44 * shade, fd, bd, 82, 28, 18);
      } else {
        setTerrainPixel(x, y, 102 * shade, 114 * shade, 124 * shade, fd, bd, 44, 50, 56);
      }
    }
  }
}

// Landmark 7: Walkable Elevated Catalan Stone & Turf Sky-Terrace ("Feixa / Cingle Sospès")
function stampSkyTerracePlatform(cx, deckY, halfW, fd, bd, mCfg) {
  const thickness = 24;
  for (let dx = -halfW; dx <= halfW; dx++) {
    const x = Math.floor(cx + dx);
    if (x < 140 || x >= TERRAIN_W - 140) continue;
    const edgeFrac = Math.abs(dx) / halfW;
    const archCurve = Math.round(Math.pow(edgeFrac, 2.2) * 10);
    const topWave = Math.round(Math.sin(x * 0.06) * 2.5);
    const yTop = Math.floor(deckY + topWave);
    const yBot = Math.floor(deckY + thickness - archCurve + Math.cos(x * 0.09) * 3);

    // Clear 38px of headroom above the terrace so caterpillars can walk comfortably on the lower or upper level
    for (let cy = yTop - 38; cy < yTop; cy++) {
      clearTerrainPixel(x, cy, fd);
    }

    for (let y = yTop; y <= yBot; y++) {
      const depth = y - yTop;
      const n = noise2D(x * 0.12, y * 0.12) * 24;
      if (depth <= 6) {
        const sun = depth <= 2 ? 1.28 : 0.96;
        setTerrainPixel(
          x, y,
          mCfg.turfCol[0] * sun + (depth <= 1 ? 18 : 0),
          mCfg.turfCol[1] * sun + (depth <= 1 ? 20 : 0),
          mCfg.turfCol[2] * sun + (depth <= 1 ? 10 : 0),
          fd, bd, 34, 42, 28
        );
      } else {
        // Traditional Catalan "Pedra Seca" dry-stone masonry blocks
        const mortar = ((Math.floor(x / 13) + Math.floor(y / 6)) % 2 === 0) ? 1.06 : 0.90;
        setTerrainPixel(
          x, y,
          (mCfg.rockCol[0] + 24 + n) * mortar,
          (mCfg.rockCol[1] + 20 + n) * mortar,
          (mCfg.rockCol[2] + 16 + n) * mortar,
          fd, bd, 52, 46, 42
        );
      }
    }
  }
}

let currentTerrainArchetypeName = 'Feixes i Cingles';

function generateDestructibleTerrain(mapIdx) {
  const mCfg = MAPS[mapIdx];
  WATER_Y = 700;
  mapSeed += 1.73 + Math.random() * 3.8;
  terrainMask.fill(0);
  generatedTreeSpots = [];
  generatedValleySpots = [];

  // 8 Diverse Multi-Level & Hilly Catalan Terrain Archetypes!
  const archetypes = [
    { id: 'FEIXES_TERRACED',    label: 'Feixes de Pedra Seca' },
    { id: 'AGULLES_SPIRES',     label: 'Agulles i Cingles' },
    { id: 'MULTI_DECK_GROTTO',  label: 'Cova de Dos Nivells' },
    { id: 'FLOATING_BALCONIES', label: 'Balcons Sospesos' },
    { id: 'TWIN_MASSIFS',       label: 'Doble Massís' },
    { id: 'STEPPED_CANYONS',    label: 'Congost Escalonat' },
    { id: 'CITADEL_CALDERA',    label: 'Ciutadella Alta' },
    { id: 'ARCHIPELAGO',        label: 'Illes Escalonades' }
  ];
  const pickedArch = archetypes[Math.floor(Math.random() * archetypes.length)];
  const archetype = pickedArch.id;
  currentTerrainArchetypeName = pickedArch.label;
  const archEl = document.getElementById('lbl-archetype');
  if (archEl) archEl.textContent = pickedArch.label;

  // Randomize hilliness, asymmetry, and frequency each game so the silhouette is always fresh!
  const freqScale = 0.82 + Math.random() * 0.55;
  const hillAmp = 260 + Math.random() * 95;
  const asymTilt = (Math.random() - 0.5) * 90; // One side of the map can be higher than the other!
  const numPeaks = 3 + Math.floor(Math.random() * 4);
  const randomHills = [];
  for (let p = 0; p < numPeaks; p++) {
    randomHills.push({
      cx: 340 + ((p + 0.15 + Math.random() * 0.7) / numPeaks) * (TERRAIN_W - 680),
      w: 130 + Math.random() * 190,
      amp: (Math.random() < 0.62 ? -1 : 1) * (55 + Math.random() * 115)
    });
  }

  const surfaceY = new Float32Array(TERRAIN_W);
  for (let x = 0; x < TERRAIN_W; x++) {
    const edgeDist = Math.min(x - 120, TERRAIN_W - 120 - x);
    if (edgeDist < 0) {
      surfaceY[x] = TERRAIN_H + 80;
      continue;
    }
    const islandEnv = clamp(edgeDist / 190, 0, 1);
    const smoothEnv = islandEnv * islandEnv * (3 - 2 * islandEnv);

    const nLarge  = fbm(x * 0.0016 * freqScale + mapSeed, mapSeed, 4);
    const nMed    = fbm(x * 0.0042 * freqScale + mapSeed * 1.7, mapSeed + 1.9, 4);
    const nDetail = ridgedFbm(x * 0.0065 * freqScale + mapSeed * 2.1, mapSeed + 3.1, 3);

    let h = 265 + (1 - (nLarge * 0.52 + nMed * 0.28 + nDetail * 0.20)) * hillAmp;
    h += ((x / TERRAIN_W) - 0.5) * asymTilt;

    // Layer randomized hills and valleys so no two matches share a silhouette
    for (const rh of randomHills) {
      h += Math.exp(-Math.pow((x - rh.cx) / rh.w, 2)) * rh.amp;
    }

    // Apply randomized layout archetype across the 3200px world
    if (archetype === 'ARCHIPELAGO') {
      const ch1 = Math.exp(-Math.pow((x - 1080) / 110, 2)) * 245;
      const ch2 = Math.exp(-Math.pow((x - 2120) / 110, 2)) * 245;
      h = Math.round(h / 28) * 28 + ch1 + ch2;
    } else if (archetype === 'TWIN_MASSIFS') {
      const fjord = Math.exp(-Math.pow((x - 1600) / 195, 2)) * 265;
      const peakL = -Math.exp(-Math.pow((x - 880) / 230, 2)) * 115;
      const peakR = -Math.exp(-Math.pow((x - 2320) / 230, 2)) * 115;
      h += fjord + peakL + peakR;
    } else if (archetype === 'CITADEL_CALDERA') {
      const lagoonL = Math.exp(-Math.pow((x - 980) / 145, 2)) * 205;
      const lagoonR = Math.exp(-Math.pow((x - 2220) / 145, 2)) * 205;
      const citadel = -Math.exp(-Math.pow((x - 1600) / 270, 2)) * 110;
      h += lagoonL + lagoonR + citadel;
    } else if (archetype === 'FEIXES_TERRACED') {
      // Multi-tiered agricultural dry-stone steps ("Feixes") at distinct heights!
      const stepSize = 46;
      const rawStep = Math.round(h / stepSize) * stepSize;
      h = lerp(h, rawStep, 0.82) + Math.sin(x * 0.025) * 6;
    } else if (archetype === 'AGULLES_SPIRES') {
      // Steep rocky spires & deep mountain ravines!
      const spireWave = Math.sin(x * 0.011 + mapSeed) * Math.cos(x * 0.0045 - mapSeed * 0.5);
      h += spireWave * 115 - Math.abs(Math.sin(x * 0.008)) * 45;
    } else if (archetype === 'MULTI_DECK_GROTTO') {
      // High overarching mountain dome with a huge multi-level cavern carved underneath
      const dome = -Math.exp(-Math.pow((x - 1600) / 760, 2)) * 95;
      h += dome;
    } else if (archetype === 'FLOATING_BALCONIES') {
      // Rolling hills with dramatic stepped valleys
      h = lerp(h, Math.round(h / 38) * 38, 0.65) + Math.sin(x * 0.0065 + mapSeed) * 55;
    } else {
      // STEPPED_CANYONS: terraced plateaus and rolling gorges
      h = Math.round(h / 36) * 36 + (nDetail - 0.5) * 26;
      const gorge = Math.exp(-Math.pow((x - 1600) / 145, 2)) * 175;
      h += gorge;
    }

    // Specific Catalan comarcal geology!
    if (mCfg.id === 'MONTSERRAT') {
      const finger = Math.sin(x * 0.015) * 28 * Math.exp(-Math.pow((x - 1600) / 980, 2));
      h += finger;
    } else if (mCfg.id === 'CADAQUES') {
      const hillWave = Math.cos(x * 0.005) * 28 + Math.round(Math.sin(x * 0.012) * 3) * 7;
      h += hillWave;
    } else if (mCfg.id === 'TAULL') {
      const alpinePeak = -Math.abs(Math.sin(x * 0.0045)) * 42;
      h += alpinePeak;
    } else if (mCfg.id === 'CASTELLFOLLIT') {
      h = Math.round(h / 28) * 28 + Math.sin(x * 0.008) * 18;
    }

    surfaceY[x] = lerp(WATER_Y + 95, clamp(h, 165, WATER_Y + 65), smoothEnv);
  }

  const frontImg = tfCtx.createImageData(TERRAIN_W, TERRAIN_H);
  const backImg  = tbCtx.createImageData(TERRAIN_W, TERRAIN_H);
  const fd = frontImg.data;
  const bd = backImg.data;

  // Pick 2 to 4 randomized underground cavern & tunnel gallery locations
  const cavernCount = archetype === 'MULTI_DECK_GROTTO' ? 4 : (2 + Math.floor(Math.random() * 3));
  const caverns = [];
  for (let c = 0; c < cavernCount; c++) {
    const frac = (c + 0.5) / cavernCount;
    const cx = 520 + frac * (TERRAIN_W - 1040) + (Math.random() - 0.5) * 220;
    const topSurf = surfaceY[clamp(Math.floor(cx), 200, TERRAIN_W - 200)];
    caverns.push({
      cx,
      cy: clamp(topSurf + 95 + Math.random() * 85, 340, WATER_Y - 55),
      rx: (archetype === 'MULTI_DECK_GROTTO' ? 210 : 135) + Math.random() * 95,
      ry: 36 + Math.random() * 20
    });
  }

  for (let x = 0; x < TERRAIN_W; x++) {
    const sy = Math.floor(surfaceY[x]);
    const slope = (surfaceY[Math.min(TERRAIN_W - 1, x + 3)] - surfaceY[Math.max(0, x - 3)]) / 6;

    for (let y = sy; y < TERRAIN_H; y++) {
      const depth = y - sy;

      let inCavern = false;
      if (depth > 32 && y < WATER_Y - 24) {
        const cavN = fbm(x * 0.018 + mapSeed, y * 0.018, 3) * 0.32;
        for (const cav of caverns) {
          const dx = (x - cav.cx) / cav.rx, dy = (y - cav.cy) / cav.ry;
          if (dx * dx + dy * dy < 0.88 + cavN) {
            inCavern = true;
            break;
          }
        }
      }

      // Painterly low-frequency gouache strata instead of harsh pixel noise
      const n1 = fbm(x * 0.014 + mapSeed, y * 0.014, 3);
      const n2 = ridgedFbm(x * 0.028, y * 0.028, 2);
      const strata = Math.sin(y * 0.075 + n1 * 4.2 + Math.cos(x * 0.008) * 1.5) * 0.5 + 0.5;
      const rockVal = n1 * 0.55 + n2 * 0.22 + strata * 0.23;

      const idx4 = (y * TERRAIN_W + x) * 4;
      bd[idx4]     = mCfg.rockCol[0] * 0.48 + rockVal * 22;
      bd[idx4 + 1] = mCfg.rockCol[1] * 0.48 + rockVal * 20;
      bd[idx4 + 2] = mCfg.rockCol[2] * 0.48 + rockVal * 24;
      bd[idx4 + 3] = 255;

      if (inCavern) continue;

      terrainMask[y * TERRAIN_W + x] = 1;

      let r, g, b;
      const tuftWave = Math.sin(x * 0.22 + n1 * 6.0) * 2.2 + Math.cos(x * 0.09) * 1.6;
      const grassThick = Math.max(5, Math.floor(14 - Math.abs(slope) * 2.8 + tuftWave));
      if (depth <= grassThick) {
        const turfLight = clamp(0.88 - slope * 0.18 + (n1 - 0.5) * 0.18, 0.54, 1.24);
        r = clamp(mCfg.turfCol[0] * turfLight, 24, 255);
        g = clamp(mCfg.turfCol[1] * turfLight, 24, 255);
        b = clamp(mCfg.turfCol[2] * turfLight, 24, 255);
        if (depth <= 2) {
          const sunRim = clamp(1.32 - slope * 0.16 - depth * 0.09, 1.02, 1.48);
          r = clamp(r * sunRim + 22, 0, 255);
          g = clamp(g * sunRim + 24, 0, 255);
          b = clamp(b * sunRim + 12, 0, 255);
        } else if (depth >= grassThick - 1) {
          r *= 0.76;
          g *= 0.78;
          b *= 0.76;
        }
      } else if (depth <= grassThick + 16) {
        const ao = depth <= grassThick + 4 ? 0.74 : 0.88;
        const soil = (0.78 + rockVal * 0.36) * ao;
        r = mCfg.soilCol[0] * soil;
        g = mCfg.soilCol[1] * soil;
        b = mCfg.soilCol[2] * soil;
      } else {
        const depthFade = clamp(1.0 - (depth - 20) * 0.0009, 0.72, 1.0);
        const sunShade = clamp(0.92 - slope * 0.14, 0.62, 1.14) * depthFade;
        const bandHighlight = strata > 0.72 ? 12 : (strata < 0.25 ? -8 : 0);
        r = (mCfg.rockCol[0] + rockVal * 48 + bandHighlight) * sunShade;
        g = (mCfg.rockCol[1] + rockVal * 45 + bandHighlight) * sunShade;
        b = (mCfg.rockCol[2] + rockVal * 49 + bandHighlight * 1.1) * sunShade;
      }

      fd[idx4]     = clamp(r, 0, 255);
      fd[idx4 + 1] = clamp(g, 0, 255);
      fd[idx4 + 2] = clamp(b, 0, 255);
      fd[idx4 + 3] = 255;
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // MULTI-LEVEL SKY TERRACES & OVERHANGING BALCONIES ("FEIXES I BALCONS")
  // Stamps 2 to 5 walkable elevated platforms at varied heights!
  // ─────────────────────────────────────────────────────────────────────────
  const numTerraces = archetype === 'FLOATING_BALCONIES' ? 5 : (2 + Math.floor(Math.random() * 3));
  for (let t = 0; t < numTerraces; t++) {
    const tx = Math.floor(460 + ((t + 0.2 + Math.random() * 0.6) / numTerraces) * (TERRAIN_W - 920));
    const groundY = surfaceY[clamp(tx, 200, TERRAIN_W - 200)];
    const halfW = Math.floor(72 + Math.random() * 68);
    // Place the terrace either high above a valley/slope or protruding as a mid-cliff balcony!
    const deckY = clamp(groundY - (78 + Math.random() * 95), 185, WATER_Y - 120);
    stampSkyTerracePlatform(tx, deckY, halfW, fd, bd, mCfg);
  }

  // ─────────────────────────────────────────────────────────────────────────
  // RANDOMIZED PROCEDURAL LANDMARKS (2–4 chosen per match so every game is unique!)
  // ─────────────────────────────────────────────────────────────────────────
  const landmarkPool = ['WATCHTOWER', 'HOLLOW_LOG', 'ROCK_ARCH', 'MONOLITHS', 'BRIDGE_SPAN', 'SECOND_TOWER'];
  landmarkPool.sort(() => Math.random() - 0.5);
  const chosenLandmarks = landmarkPool.slice(0, 2 + Math.floor(Math.random() * 2));

  const zones = [680, 1180, 1600, 2040, 2520];
  zones.sort(() => Math.random() - 0.5);

  chosenLandmarks.forEach((lm, idx) => {
    const zx = Math.floor(zones[idx] + (Math.random() - 0.5) * 140);
    const zy = Math.floor(surfaceY[clamp(zx, 200, TERRAIN_W - 200)]);

    if (lm === 'BRIDGE_SPAN') {
      const spanHalf = 190 + Math.random() * 70;
      const deckY = Math.min(zy - 45, 340 + Math.random() * 60);
      if (mCfg.id === 'MONTSERRAT' || mCfg.id === 'CASTELLFOLLIT' || Math.random() < 0.72) {
        stampRomanesqueViaduct(zx - spanHalf, zx + spanHalf, deckY, fd, bd);
      } else {
        stampSteelTrussSpan(zx - spanHalf, zx + spanHalf, deckY, fd, bd, mCfg.id === 'MONTSERRAT');
      }
    } else if (zy < WATER_Y - 45) {
      if (lm === 'WATCHTOWER' || lm === 'SECOND_TOWER') {
        stampStoneWatchtower(zx, zy, fd, bd);
      } else if (lm === 'HOLLOW_LOG') {
        stampHollowFallenLog(zx, zy, fd, bd);
      } else if (lm === 'ROCK_ARCH') {
        stampNaturalRockArch(zx, zy, fd, bd, mCfg);
      } else if (lm === 'MONOLITHS') {
        stampAncientMonoliths(zx, zy, fd, bd);
      }
    }
  });

  // Stamp 5 to 8 randomized regional Pine Trees across the 3200px map!
  const treeCount = 5 + Math.floor(Math.random() * 4);
  for (let i = 0; i < treeCount; i++) {
    const sectorW = (TERRAIN_W - 560) / treeCount;
    const tx = Math.floor(280 + i * sectorW + (Math.random() - 0.5) * (sectorW * 0.55));
    const ty = Math.floor(surfaceY[clamp(tx, 100, TERRAIN_W - 100)]);
    if (ty < WATER_Y - 50 && !isSolid(tx, ty - 25)) {
      const scale = 0.85 + Math.random() * 0.35;
      const treeInfo = stampDestructibleTree(tx, ty, mCfg.treeStyle, fd, bd, scale);
      generatedTreeSpots.push(treeInfo);
    }
  }

  // Record 2–3 low valley spots for optional Thermal Updrafts
  for (const vx of [880, 1600, 2320]) {
    const jx = Math.floor(vx + (Math.random() - 0.5) * 180);
    generatedValleySpots.push(jx);
  }

  tfCtx.putImageData(frontImg, 0, 0);
  tbCtx.putImageData(backImg, 0, 0);
}

function isSolid(x, y) {
  const ix = Math.floor(x), iy = Math.floor(y);
  if (ix < 0 || ix >= TERRAIN_W || iy >= TERRAIN_H || iy < 0) return false;
  return terrainMask[iy * TERRAIN_W + ix] === 1;
}

function getSurfaceNormal(x, y) {
  let nx = 0, ny = 0;
  for (let dy = -5; dy <= 5; dy++) {
    for (let dx = -5; dx <= 5; dx++) {
      if (dx === 0 && dy === 0) continue;
      if (isSolid(x + dx, y + dy)) {
        nx -= dx;
        ny -= dy;
      }
    }
  }
  const len = Math.hypot(nx, ny);
  if (len < 1e-4) return { x: 0, y: -1 };
  return { x: nx / len, y: ny / len };
}

function findSurfaceY(x, startY = 40) {
  const ix = clamp(Math.floor(x), 0, TERRAIN_W - 1);
  for (let y = Math.max(0, Math.floor(startY)); y < TERRAIN_H; y++) {
    if (terrainMask[y * TERRAIN_W + ix] === 1) return y;
  }
  return TERRAIN_H + 100;
}

// Finds ALL walkable vertical tiers (upper peaks, sky balconies, mid-cliff ledges, cavern floors) at column x!
function findAllWalkableSurfacesAtX(x) {
  const ix = clamp(Math.floor(x), 0, TERRAIN_W - 1);
  const surfaces = [];
  let airRun = 0;
  for (let y = 36; y < WATER_Y - 22; y++) {
    if (terrainMask[y * TERRAIN_W + ix] === 0) {
      airRun++;
    } else {
      if (airRun >= 26) {
        surfaces.push(y);
      }
      airRun = 0;
    }
  }
  return surfaces;
}

// Constructs a real destructible Catalan "Marge de Pedra Seca" dry-stone bridge, ramp, or bunker wall!
function buildDryStoneGirder(cx, cy, angle, length = 78, thickness = 16) {
  const cosA = Math.cos(angle), sinA = Math.sin(angle);
  const halfL = length * 0.5, halfT = thickness * 0.5;
  const boundR = Math.ceil(halfL + halfT + 6);
  const x0 = clamp(Math.floor(cx - boundR), 0, TERRAIN_W - 1);
  const x1 = clamp(Math.ceil(cx + boundR), 0, TERRAIN_W - 1);
  const y0 = clamp(Math.floor(cy - boundR), 0, TERRAIN_H - 1);
  const y1 = clamp(Math.ceil(cy + boundR), 0, TERRAIN_H - 1);
  const w = x1 - x0 + 1, h = y1 - y0 + 1;
  if (w <= 0 || h <= 0) return;

  const frontImg = tfCtx.getImageData(x0, y0, w, h);
  const backImg  = tbCtx.getImageData(x0, y0, w, h);
  const fd = frontImg.data;
  const bd = backImg.data;

  for (let y = y0; y <= y1; y++) {
    for (let x = x0; x <= x1; x++) {
      const dx = x - cx, dy = y - cy;
      const along = dx * cosA + dy * sinA;
      const perp  = -dx * sinA + dy * cosA;
      const roundCap = Math.max(0, Math.abs(along) - (halfL - 5));
      if (Math.abs(along) <= halfL && (perp * perp + roundCap * roundCap) <= halfT * halfT) {
        terrainMask[y * TERRAIN_W + x] = 1;
        const localIdx = ((y - y0) * w + (x - x0)) * 4;
        // Authentic Catalan dry-stone coursework ("pedra seca") with mossy top rim
        const row = Math.floor((perp + halfT) / 5.5);
        const col = Math.floor((along + halfL + (row % 2) * 7) / 14);
        const isMortar = (Math.abs((perp + halfT) % 5.5) < 0.9 || Math.abs((along + halfL + (row % 2) * 7) % 14) < 1.0);
        const stoneVar = ((row * 7 + col * 13) & 3) * 7 - 10;
        const n = (noise2D(x * 0.16, y * 0.16) - 0.5) * 22;
        let r = 154 + stoneVar + n;
        let g = 142 + stoneVar + n;
        let b = 124 + stoneVar + n;
        if (perp < -halfT + 3.2) {
          // Sunlit golden-moss top edge
          r = 142 + n; g = 168 + n; b = 96 + n;
        } else if (isMortar) {
          r *= 0.68; g *= 0.68; b *= 0.68;
        }
        fd[localIdx]     = clamp(r, 0, 255);
        fd[localIdx + 1] = clamp(g, 0, 255);
        fd[localIdx + 2] = clamp(b, 0, 255);
        fd[localIdx + 3] = 255;

        bd[localIdx]     = 64;
        bd[localIdx + 1] = 58;
        bd[localIdx + 2] = 50;
        bd[localIdx + 3] = 255;
      }
    }
  }
  tfCtx.putImageData(frontImg, x0, y0);
  tbCtx.putImageData(backImg, x0, y0);
}

function carveCrater(cx, cy, radius) {
  const r = Math.ceil(radius);
  const x0 = Math.max(0, Math.floor(cx - r - 6));
  const x1 = Math.min(TERRAIN_W - 1, Math.ceil(cx + r + 6));
  const y0 = Math.max(0, Math.floor(cy - r - 6));
  const y1 = Math.min(TERRAIN_H - 1, Math.ceil(cy + r + 6));

  for (let y = y0; y <= y1; y++) {
    for (let x = x0; x <= x1; x++) {
      const dx = x - cx, dy = y - cy;
      const dist = Math.hypot(dx, dy);
      const jitter = (noise2D(x * 0.09, y * 0.09) - 0.5) * 4.5;
      if (dist + jitter <= radius) {
        terrainMask[y * TERRAIN_W + x] = 0;
      }
    }
  }

  tfCtx.save();
  tfCtx.globalCompositeOperation = 'destination-out';
  tfCtx.beginPath();
  const steps = 36;
  for (let i = 0; i < steps; i++) {
    const a = (i / steps) * Math.PI * 2;
    const jr = radius + (noise2D(cx * 0.07 + Math.cos(a) * 1.5, cy * 0.07 + Math.sin(a) * 1.5) - 0.5) * 4.5;
    const px = cx + Math.cos(a) * jr;
    const py = cy + Math.sin(a) * jr;
    if (i === 0) tfCtx.moveTo(px, py); else tfCtx.lineTo(px, py);
  }
  tfCtx.closePath();
  tfCtx.fill();

  // Painterly warm burnt-sienna & soft charcoal crater rim
  tfCtx.globalCompositeOperation = 'source-atop';
  const scorch = tfCtx.createRadialGradient(cx, cy, Math.max(2, radius - 3), cx, cy, radius + 18);
  scorch.addColorStop(0, 'rgba(24, 18, 15, 0.85)');
  scorch.addColorStop(0.35, 'rgba(92, 48, 26, 0.52)');
  scorch.addColorStop(0.7, 'rgba(42, 30, 22, 0.25)');
  scorch.addColorStop(1, 'rgba(32, 24, 18, 0)');
  tfCtx.fillStyle = scorch;
  tfCtx.beginPath();
  tfCtx.arc(cx, cy, radius + 18, 0, Math.PI * 2);
  tfCtx.fill();
  tfCtx.restore();

  tbCtx.save();
  tbCtx.globalCompositeOperation = 'destination-out';
  tbCtx.beginPath();
  tbCtx.arc(cx, cy, radius * 0.68, 0, Math.PI * 2);
  tbCtx.fill();
  tbCtx.restore();
}

