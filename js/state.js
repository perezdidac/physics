"use strict";

// ═══════════════════════════════════════════════════════════════════════════
//  4. 12-WEAPON CATALANIZED ORDNANCE ARSENAL (TRABUC, CARQUINYOLIS, FUET, TIÓ!)
// ═══════════════════════════════════════════════════════════════════════════
const WEAPONS = [
  {
    id: 'BAZOOKA',
    key: '1',
    name: 'Trabuc',
    defaultAmmo: Infinity,
    type: 'CHARGE',
    windFactor: 1.0,
    blastR: 50,
    maxDmg: 50,
    knockback: 470,
    // Iconic flared-bell Catalan Bandit Blunderbuss (Trabuc de Serrallonga)
    svg: `<svg viewBox="0 0 36 22"><path d="M2 16 L10 11 L10 16 L4 19 Z" fill="#8c542b" stroke="#efe8da" stroke-width="1"/><rect x="10" y="9" width="14" height="5" fill="#4f565e" stroke="#f0b849" stroke-width="1.1"/><path d="M24 8 L34 4 L34 19 L24 15 Z" fill="#d9a14a" stroke="#fff3d1" stroke-width="1.2"/></svg>`
  },
  {
    id: 'CARQUINYOLI',
    key: '2',
    name: 'Carquinyolis',
    defaultAmmo: Infinity,
    type: 'CHARGE',
    windFactor: 0.25,
    blastR: 32,
    maxDmg: 26,
    knockback: 360,
    // Rock-hard toasted Catalan almond biscotti (Carquinyolis trencadents!)
    svg: `<svg viewBox="0 0 36 22"><g transform="rotate(-14 18 11)"><rect x="6" y="6" width="24" height="10" rx="5" fill="#c87d32" stroke="#f6cf77" stroke-width="1.2"/><ellipse cx="13" cy="11" rx="3.2" ry="2.1" transform="rotate(20 13 11)" fill="#fff5df" stroke="#7a4414" stroke-width="0.9"/><ellipse cx="22" cy="10.5" rx="3.0" ry="2.0" transform="rotate(-18 22 10.5)" fill="#fff5df" stroke="#7a4414" stroke-width="0.9"/><circle cx="17.5" cy="13.5" r="1.3" fill="#f3d59b"/></g></svg>`
  },
  {
    id: 'GRENADE',
    key: '3',
    name: 'Pinya',
    defaultAmmo: Infinity,
    type: 'CHARGE',
    windFactor: 0.0,
    hasCustomFuse: true,
    fuse: 3.0,
    blastR: 48,
    maxDmg: 45,
    knockback: 440,
    // Explosive Mediterranean Stone Pine Cone (Pinya Explosiva)
    svg: `<svg viewBox="0 0 36 22"><ellipse cx="18" cy="13" rx="6.5" ry="7.5" fill="#7c4d2b" stroke="#f6cf77" stroke-width="1.2"/><path d="M13 11 L18 8 L23 11 M12 15 L18 12 L24 15" fill="none" stroke="#d9a15b" stroke-width="1.3"/><path d="M18 5 Q21 1 25 3" fill="none" stroke="#efe8da" stroke-width="1.4"/><circle cx="25" cy="3" r="2" fill="#ff9b3b"/></svg>`
  },
  {
    id: 'CLUSTER',
    key: '4',
    name: 'Calçotada',
    defaultAmmo: 3,
    type: 'CHARGE',
    windFactor: 0.0,
    hasCustomFuse: true,
    fuse: 3.0,
    blastR: 36,
    maxDmg: 30,
    knockback: 350,
    // Bundle of flaming grilled Calçots dipped in Romesco sauce
    svg: `<svg viewBox="0 0 36 22"><path d="M12 19 L14 9 M18 19 L18 8 M24 19 L22 9" stroke="#f2ecdf" stroke-width="2.6" stroke-linecap="round"/><path d="M14 9 L11 3 M18 8 L18 2 M22 9 L25 3" stroke="#5ca856" stroke-width="2.4" stroke-linecap="round"/><rect x="12" y="12" width="12" height="2.5" fill="#d93829"/><circle cx="18" cy="18" r="3" fill="#ff7b29"/></svg>`
  },
  {
    id: 'URTICARIA',
    key: '5',
    name: 'Urticant',
    defaultAmmo: 3,
    type: 'CHARGE',
    windFactor: 0.35,
    blastR: 34,
    maxDmg: 28,
    knockback: 310,
    svg: `<svg viewBox="0 0 36 22"><circle cx="18" cy="11" r="6" fill="#9c4dcc" stroke="#f6cf77" stroke-width="1.2"/><line x1="18" y1="1" x2="18" y2="5" stroke="#ffae42" stroke-width="1.5"/><line x1="18" y1="17" x2="18" y2="21" stroke="#ffae42" stroke-width="1.5"/><line x1="8" y1="11" x2="12" y2="11" stroke="#ffae42" stroke-width="1.5"/><line x1="24" y1="11" x2="28" y2="11" stroke="#ffae42" stroke-width="1.5"/><line x1="11" y1="4" x2="14" y2="7" stroke="#ffae42" stroke-width="1.4"/><line x1="25" y1="18" x2="22" y2="15" stroke="#ffae42" stroke-width="1.4"/></svg>`
  },
  {
    id: 'SHOTGUN',
    key: '6',
    name: 'Pedrenyal',
    defaultAmmo: Infinity,
    type: 'INSTANT',
    blastR: 28,
    maxDmg: 38,
    knockback: 440,
    // 17th-Century Catalan Flintlock Pistol (Pedrenyal Català)
    svg: `<svg viewBox="0 0 36 22"><path d="M3 18 C4 13 8 11 12 11 L12 15 C9 15 7 17 6 20 Z" fill="#9c6234" stroke="#f6cf77" stroke-width="1"/><rect x="11" y="9" width="21" height="3.5" fill="#9ba3b0" stroke="#efe8da" stroke-width="0.9"/><path d="M13 9 L11 4 L15 5 L15 9" fill="#d9a14a"/><circle cx="5" cy="19" r="2" fill="#d9a14a"/></svg>`
  },
  {
    id: 'FUET',
    key: '7',
    name: 'El Fuet',
    defaultAmmo: Infinity,
    type: 'MELEE',
    maxDmg: 38,
    knockback: 780,
    // Iconic Catalan Fuet de Vic cured sausage dusted in white penicillium with tied twine!
    svg: `<svg viewBox="0 0 36 22"><path d="M5 17 Q16 5 30 7" fill="none" stroke="#8a2836" stroke-width="5.2" stroke-linecap="round"/><path d="M5 17 Q16 5 30 7" fill="none" stroke="#f4eee1" stroke-width="4.2" stroke-dasharray="2.5 2" stroke-linecap="round"/><path d="M30 7 L34 4 M30 7 L34 9" stroke="#d9b372" stroke-width="1.4" stroke-linecap="round"/></svg>`
  },
  {
    id: 'BAT',
    key: '8',
    name: 'La Falç',
    defaultAmmo: Infinity,
    type: 'MELEE',
    maxDmg: 34,
    knockback: 690,
    // Els Segadors Curved Reaper's Sickle (La Falç)
    svg: `<svg viewBox="0 0 36 22"><rect x="5" y="14" width="9" height="3.5" rx="1.5" transform="rotate(-28 5 14)" fill="#b87430" stroke="#f6cf77" stroke-width="1"/><path d="M13 12 C21 2 32 4 30 14 C28 19 21 20 17 17 C23 17 26 14 26 10 C26 6 19 6 14 13 Z" fill="#dce3ec" stroke="#ffffff" stroke-width="1.1"/></svg>`
  },
  {
    id: 'DYNAMITE',
    key: '9',
    name: 'El Tió',
    defaultAmmo: 2,
    type: 'DROP',
    fuse: 4.0,
    blastR: 74,
    maxDmg: 75,
    knockback: 610,
    // Smiling Catalan Caga Tió log wearing a red Barretina & stick legs!
    svg: `<svg viewBox="0 0 36 22"><rect x="7" y="8" width="20" height="9" rx="3" fill="#8c5830" stroke="#f6cf77" stroke-width="1.1"/><rect x="7" y="8" width="10" height="9" rx="2" fill="#d93829"/><path d="M22 8 L28 2 L32 6 L26 9 Z" fill="#e03228" stroke="#181a20" stroke-width="1"/><circle cx="24" cy="11.5" r="1.1" fill="#fff"/><path d="M22 14 Q24.5 16 26 13.5" fill="none" stroke="#fff" stroke-width="1.2"/><line x1="11" y1="17" x2="9" y2="21" stroke="#734623" stroke-width="2"/><line x1="23" y1="17" x2="25" y2="21" stroke="#734623" stroke-width="2"/></svg>`
  },
  {
    id: 'HOLY',
    key: '0',
    name: 'Porró Sagrat',
    defaultAmmo: 1,
    type: 'CHARGE',
    windFactor: 0.0,
    fuse: 3.5,
    blastR: 94,
    maxDmg: 90,
    knockback: 720,
    // Sacred Golden Catalan Porró with angled wine spout & holy cross
    svg: `<svg viewBox="0 0 36 22"><path d="M13 19 L16 8 L20 8 L23 19 Z" fill="#f0b849" stroke="#fff" stroke-width="1.2"/><path d="M15 14 L7 8 L8 6.5 L16 12" fill="#f0b849" stroke="#fff" stroke-width="1"/><path d="M14 18 L22 18 L21 13 L15 13 Z" fill="#a82020"/><line x1="18" y1="1" x2="18" y2="7" stroke="#fff" stroke-width="1.8"/><line x1="15" y1="3.8" x2="21" y2="3.8" stroke="#fff" stroke-width="1.8"/></svg>`
  },
  {
    id: 'AIRSTRIKE',
    key: '-',
    name: 'Correfoc',
    defaultAmmo: 2,
    type: 'TARGET_MAP',
    windFactor: 0.4,
    blastR: 42,
    maxDmg: 40,
    knockback: 420,
    svg: `<svg viewBox="0 0 36 22"><path d="M3 13 L33 9 L26 16 L14 15 L8 19 L9 14 Z" fill="#d94638" stroke="#f6cf77" stroke-width="1.2"/><circle cx="29" cy="10" r="2" fill="#ffee77"/></svg>`
  },
  {
    id: 'JETPACK',
    key: '=',
    name: 'Ales Pinar',
    defaultAmmo: 2,
    type: 'UTILITY_JET',
    svg: `<svg viewBox="0 0 36 22"><path d="M18 11 C10 2 3 5 6 13 C8 18 14 17 18 13 C22 17 28 18 30 13 C33 5 26 2 18 11 Z" fill="#d9a15b" stroke="#fff3d1" stroke-width="1.2"/></svg>`
  },
  {
    id: 'CULLERA',
    key: 'u',
    name: 'Cullera Boix',
    defaultAmmo: 3,
    type: 'TOOL_AIM',
    maxDmg: 28,
    knockback: 420,
    // Giant Catalan Boxwood Wooden Cooking Spoon (Cullera de Fusta de Boix) that scoops forward through hills!
    svg: `<svg viewBox="0 0 36 22"><g transform="rotate(-16 18 11)"><rect x="3" y="9.5" width="17" height="3.2" rx="1.5" fill="#cfa05a" stroke="#5c3a14" stroke-width="1"/><ellipse cx="25.5" cy="11" rx="7.5" ry="5.2" fill="#e6b973" stroke="#fff3d1" stroke-width="1.1"/><ellipse cx="26" cy="11" rx="5.0" ry="3.2" fill="#b8843e"/></g></svg>`
  },
  {
    id: 'BARRINA',
    key: 'i',
    name: 'Barrina',
    defaultAmmo: 3,
    type: 'TOOL_AIM',
    maxDmg: 36,
    knockback: 320,
    // Catalan Quarry Pneumatic Rock Drill (Barrina de Pedrera) that bores tunnels downward/diagonally!
    svg: `<svg viewBox="0 0 36 22"><rect x="4" y="7" width="12" height="8" rx="2" fill="#d97b29" stroke="#fff3d1" stroke-width="1.1"/><line x1="4" y1="4" x2="4" y2="18" stroke="#8d96a3" stroke-width="2.4" stroke-linecap="round"/><polygon points="16,8 34,11 16,14" fill="#b8c2cf" stroke="#282d34" stroke-width="1"/><path d="M19 8.5 L22 13.5 M24 9.2 L27 12.8 M29 10 L31 12" stroke="#282d34" stroke-width="1.3"/></svg>`
  },
  {
    id: 'PONT_PEDRA',
    key: 'o',
    name: 'Pedra Seca',
    defaultAmmo: 3,
    type: 'TOOL_AIM',
    // Traditional Catalan Dry-Stone Wall & Bridge Builder (Marge de Pedra Seca)
    svg: `<svg viewBox="0 0 36 22"><rect x="4" y="6" width="13" height="5" rx="1.5" fill="#a8a298" stroke="#f6cf77" stroke-width="1"/><rect x="19" y="6" width="13" height="5" rx="1.5" fill="#8f8980" stroke="#f6cf77" stroke-width="1"/><rect x="3" y="12.5" width="9" height="5" rx="1.5" fill="#8a847b" stroke="#efe8da" stroke-width="0.9"/><rect x="13.5" y="12.5" width="10" height="5" rx="1.5" fill="#b5afa4" stroke="#efe8da" stroke-width="0.9"/><rect x="25" y="12.5" width="8" height="5" rx="1.5" fill="#969086" stroke="#efe8da" stroke-width="0.9"/></svg>`
  },
  {
    id: 'GANXO',
    key: 'p',
    name: 'Ganxo Pastor',
    defaultAmmo: 3,
    type: 'TOOL_AIM',
    maxDmg: 22,
    knockback: 380,
    // Pyrenean Shepherd's Crook Grapple Hook (Ganxo de Pastor) to zip onto high cliffs or yank enemies!
    svg: `<svg viewBox="0 0 36 22"><path d="M4 17 L22 8" stroke="#b87b3c" stroke-width="2.8" stroke-linecap="round"/><path d="M22 8 C28 5 33 7 32 13 C31 17 26 18 24 14" fill="none" stroke="#e2e8f0" stroke-width="2.6" stroke-linecap="round"/><path d="M4 17 Q11 20 16 14" fill="none" stroke="#f6cf77" stroke-width="1.3" stroke-dasharray="2 2"/></svg>`
  }
];

// ═══════════════════════════════════════════════════════════════════════════
//  5. GAME FLOW STATE (DIRECT UP/DOWN MENU -> CUSTOMIZE OR PLAY)
// ═══════════════════════════════════════════════════════════════════════════
const canvas = document.getElementById('canvas');
const ctx = canvas.getContext('2d');

let viewW = window.innerWidth;
let viewH = window.innerHeight;
let canvasDpr = 1;
function resizeCanvas() {
  canvasDpr = Math.min(window.devicePixelRatio || 1, 2);
  viewW = window.innerWidth;
  viewH = window.innerHeight;
  canvas.width = Math.floor(viewW * canvasDpr);
  canvas.height = Math.floor(viewH * canvasDpr);
}
window.addEventListener('resize', resizeCanvas);
window.addEventListener('orientationchange', () => setTimeout(resizeCanvas, 120));
resizeCanvas();

buildBackgroundAssets();

// Authentic Catalan Procesionaria Caterpillar Squad Names
const teamNames = [
  ['Peluda', 'Serrallonga', 'Pinassa', 'Rovelló'],
  ['Urticària', 'Tramuntana', 'Boira', 'Calçot']
];
const teamHats = ['CATALAN', 'BANDOLER'];
const customFaces = [
  [null, null, null, null],
  [null, null, null, null]
];

const GAME_MODES = ['1P_CPU', '2P_LOCAL', 'CPU_CPU'];
const MODE_SHORT = {
  '1P_CPU': '1J vs CPU',
  '2P_LOCAL': '2J Local',
  'CPU_CPU': 'CPU vs CPU'
};
let gameMode = '1P_CPU';
let aiDifficulty = 'VETERAN';

// Screen flow: 'SPLASH' (Up/Down Player Selection Menu) | 'LOBBY' (Customize) | 'PLAYING'
let appStage = 'SPLASH';
let menuCursorIdx = 0; // 0 = Quick Game vs CPU, 1 = 2P Local, 2 = Customize Game
let hasStartedMatchOnce = false;

const ORUGA_TAUNTS = {
  TURN: ['A pel pi!', 'En processó!', 'Prepara el trabuc!', 'Tasta el fuet de Vic!', 'Carquinyoli trencadents!', 'Bon cop de falç!'],
  HIT: ['Ai els meus pèls!', 'Quina picor!', 'Mal llamp!', 'El meu capoll!'],
  URTICARIA: ['Pols urticant!', 'Grata, grata!', 'Al·lèrgia total!'],
  PROCESSION: ['Columna unida!', 'Fúria processionària!', 'Seda i ferro!'],
  METAMORPH: ['METAMORFOSI!', 'Ales de Thaumetopoea!', 'Ja puc planar!']
};

let fighters = [];
let barrels = [];
let mines = [];
let crates = [];
let projectiles = [];
let airstrikePlanes = [];
let floatingTexts = [];
let speechBubbles = [];
let particles = [];
let smokePuffs = [];
let fireballs = [];
let shockwaves = [];
let waterPlumes = [];
let waterRipples = [];
let bubbles = [];
let tombstones = [];
let surfaceFlora = [];

// Original Non-Clone Gameplay Entities!
let silkWebs = [];      // Elastic physics Silk Trampolines & Deflector Bridges spun by Orugas [Key C]
let silkNests = [];     // Hanging Pine Silk Nests ("Bolsones") that burst into Golden Pine Nuts & Larvae Swarms
let pineNuts = [];      // Golden Piñones that heal +20 HP & evolve Max HP
let larvaeSwarms = [];  // Angry micro-caterpillar swarms that chase and nibble nearby enemies
let updrafts = [];      // Thermal pine-resin wind currents that lift gliding caterpillars & curve shells
let rovellons = [];     // Giant Bouncy Catalan Rovelló Mushrooms (spring trampolines & healing spores!)
let caganers = [];      // Hidden Lucky Catalan Caganer Figurines (grant Golden Blessing + Porró & Tió!)
let escudelles = [];    // Simmering Catalan "Olla d'Escudella i Carn d'Olla" Cauldrons (heal +Pilota buff or erupt in Galets pasta geyser!)

let processionConvoyEnabled = true; // Nose-to-tail linked column march & +25% Procession Fury bonus [Key F]
let silkWebUsedThisTurn = false;

let teamAmmo = [{}, {}];
let teamDamageDealt = [0, 0];
let teamTurnIdx = [0, 0];
let teamSelectedWeaponIdx = [0, 0]; // Remembers each team's last chosen weapon!
let activeTeam = 0;
let activeFighter = null;
let selectedWeaponIdx = 0;
let customGrenadeFuse = 3;
let roundNumber = 1;
let userZoomMult = 1.22; // Closer default zoom so Cucs and their names are crisp and easy to read!

let turnPhase = 'TURN_PLAY';
let turnTimer = 30;
let phaseTimer = 0;
let actionWaitTimer = 0;
let shotgunShotsLeft = 1;
let wind = 0;
let windFloat = 0;
let windTarget = 0;
let windGustTimer = 4.5;
let windGustFlash = 0;

let hitStopTimer = 0;
let slowMoTimer = 0;

let aimPitch = -0.42; // Relative pitch in facing direction: -1.48 (up) .. 0 (horizontal) .. +1.30 (down)
let aimAngle = -0.42;
let isCharging = false;
let chargePower = 0;
let chargeDir = 1;
let lastChargeTick = 0;
let mouseWorld = { x: 1600, y: 360 };
let hasActedOrMovedThisTurn = false;
let turnSpotlightTimer = 0;
let lastTurnTickSec = 30;
let touchRipples = [];

const keys = { left: false, right: false, up: false, down: false };
let lastJumpPressTime = 0;
let aiPlan = null;

function syncAimAngleFromPitch() {
  const facing = (activeFighter && activeFighter.facing < 0) ? -1 : 1;
  aimPitch = clamp(aimPitch, -1.48, 1.30);
  aimAngle = facing >= 0 ? aimPitch : (Math.PI - aimPitch);
  if (activeFighter) {
    const curWpn = WEAPONS[selectedWeaponIdx];
    if (!curWpn || curWpn.id !== 'AIRSTRIKE') {
      mouseWorld = {
        x: clamp(activeFighter.x + Math.cos(aimAngle) * 260, 120, TERRAIN_W - 120),
        y: clamp((activeFighter.y - 4) + Math.sin(aimAngle) * 260, 60, WATER_Y - 20)
      };
    }
  }
}

function switchActiveWormBeforeMove(targetWorm = null) {
  if (appStage !== 'PLAYING' || turnPhase !== 'TURN_PLAY' || isCurrentTurnAI() || isCharging || hasActedOrMovedThisTurn) return false;
  const teamAlive = fighters.filter(f => f.team === activeTeam && f.alive && !f.drowning);
  if (teamAlive.length <= 1) return false;

  let nextWorm = targetWorm;
  if (!nextWorm || nextWorm.team !== activeTeam || !nextWorm.alive || nextWorm.drowning) {
    const curIdx = Math.max(0, teamAlive.indexOf(activeFighter));
    nextWorm = teamAlive[(curIdx + 1) % teamAlive.length];
  }
  if (!nextWorm || nextWorm === activeFighter) return false;

  activeFighter = nextWorm;
  cam.panOffsetX = 0;
  cam.panOffsetY = 0;
  turnSpotlightTimer = 1.6;
  aimPitch = (activeFighter.lastAimPitch !== undefined) ? activeFighter.lastAimPitch : -0.42;
  syncAimAngleFromPitch();

  SND.tick();
  floatingTexts.push({
    x: activeFighter.x,
    y: activeFighter.y - 42,
    text: `¡TORN DE ${activeFighter.name.toUpperCase()}! [TAB]`,
    color: activeTeam === 0 ? '#f5b945' : '#ea5648',
    life: 1.35
  });

  const st = document.getElementById('turn-status');
  if (st) st.textContent = `Torn de ${activeFighter.name}`;
  updateHUD();
  return true;
}

const cam = {
  x: 1600,
  y: 400,
  targetX: 1600,
  targetY: 400,
  panOffsetX: 0,
  panOffsetY: 0,
  zoom: 1.0,
  targetZoom: 1.0,
  mouseOffX: 0,
  mouseOffY: 0,
  smoothMouseX: 0,
  smoothMouseY: 0
};
let mobilePanMode = false;

// Impact camera lock: keeps the camera at the projectile crash site until nearby worms stop moving + 2s!
const impactCam = {
  active: false,
  x: 1600,
  y: 400,
  trackedWorm: null
};

let shake = 0;
let flashLight = 0;
let flashPos = { x: 1600, y: 400 };
let tNow = 0;

const weatherParticles = Array.from({ length: 110 }, () => ({
  x: Math.random() * 3200,
  y: Math.random() * 760,
  z: 0.5 + Math.random() * 1.0,
  r: 1.0 + Math.random() * 1.8,
  vx: (Math.random() - 0.5) * 18,
  vy: 25 + Math.random() * 65,
  phase: Math.random() * Math.PI * 2
}));

// Multi-layered Volumetric Cloud Clusters (3 parallax tiers: far cirrus, mid cumulus, foreground mist)
const cloudFlock = Array.from({ length: 24 }, (_, idx) => {
  const tier = idx < 8 ? 0 : (idx < 17 ? 1 : 2);
  const z = tier === 0 ? 0.09 : (tier === 1 ? 0.20 : 0.36);
  const scale = tier === 0 ? (0.65 + Math.random() * 0.35) : (tier === 1 ? (0.95 + Math.random() * 0.55) : (1.15 + Math.random() * 0.55));
  const lobeCount = 5 + Math.floor(Math.random() * 3);
  const lobes = [];
  for (let l = 0; l < lobeCount; l++) {
    const frac = (l / (lobeCount - 1)) - 0.5;
    lobes.push({
      ox: frac * 115 * scale + (Math.random() - 0.5) * 16,
      oy: Math.abs(frac) * 18 * scale - (l === Math.floor(lobeCount * 0.5) ? 14 * scale : 0) + (Math.random() - 0.5) * 8,
      rx: (34 + (1 - Math.abs(frac)) * 32 + Math.random() * 14) * scale,
      ry: (22 + (1 - Math.abs(frac)) * 20 + Math.random() * 10) * scale
    });
  }
  return {
    x: (idx / 24) * 3800 - 300 + (Math.random() - 0.5) * 120,
    y: tier === 0 ? (45 + Math.random() * 90) : (tier === 1 ? (85 + Math.random() * 135) : (165 + Math.random() * 130)),
    z,
    tier,
    scale,
    baseDrift: (Math.random() - 0.5) * 8,
    bobPhase: Math.random() * Math.PI * 2,
    lobes
  };
});

// Live Wind-Stream Air Ribbons sweeping across the sky and battlefield
const windRibbons = Array.from({ length: 16 }, () => ({
  x: Math.random() * 3200,
  y: 70 + Math.random() * 540,
  z: 0.45 + Math.random() * 0.65,
  len: 65 + Math.random() * 85,
  amp: 4 + Math.random() * 7,
  phase: Math.random() * Math.PI * 2,
  alpha: 0.16 + Math.random() * 0.22
}));

// Animated Flocks of Regional Sky Birds (Gulls, Falcons, Swifts)
const skyBirds = Array.from({ length: 12 }, (_, i) => ({
  x: Math.random() * 3400,
  y: 65 + (i % 4) * 28 + Math.random() * 85,
  z: 0.16 + (i % 3) * 0.08,
  speed: 22 + Math.random() * 18,
  dir: i % 2 === 0 ? 1 : -1,
  wingPhase: Math.random() * Math.PI * 2,
  size: 5.5 + (i % 3) * 1.8
}));

function spawnSpeechBubble(f, text, duration = 2.0) {
  speechBubbles = speechBubbles.filter(b => b.fighter !== f);
  speechBubbles.push({
    fighter: f,
    text,
    life: duration
  });
}

function findValidLandX(preferredX, maxRadius = 260) {
  for (let r = 0; r <= maxRadius; r += 18) {
    const dirs = r === 0 ? [0] : [-1, 1];
    for (const d of dirs) {
      const testX = clamp(Math.round(preferredX + d * r), 240, TERRAIN_W - 240);
      const sy = findSurfaceY(testX, 40);
      if (sy < WATER_Y - 28) return testX;
    }
  }
  return clamp(Math.round(preferredX), 260, TERRAIN_W - 260);
}

// Finds a valid (x, y) spawn point across ALL vertical levels (upper peaks, mid balconies, or lower grotto decks)!
function findMultiLevelSpawnSpot(preferredX, maxRadius = 260, preferLower = false) {
  for (let r = 0; r <= maxRadius; r += 18) {
    const dirs = r === 0 ? [0] : [-1, 1];
    for (const d of dirs) {
      const testX = clamp(Math.round(preferredX + d * r), 240, TERRAIN_W - 240);
      const tiers = findAllWalkableSurfacesAtX(testX);
      if (tiers.length > 0) {
        let chosenY = tiers[0];
        if (tiers.length > 1 && (preferLower || Math.random() < 0.52)) {
          chosenY = tiers[tiers.length - 1];
        }
        return { x: testX, y: chosenY };
      }
    }
  }
  const fallbackX = findValidLandX(preferredX, maxRadius);
  return { x: fallbackX, y: findSurfaceY(fallbackX, 40) };
}

function initMatch(regenerateMap = true) {
  if (regenerateMap) generateDestructibleTerrain(currentMapIdx);

  fighters = [];
  barrels = [];
  mines = [];
  crates = [];
  projectiles = [];
  airstrikePlanes = [];
  floatingTexts = [];
  speechBubbles = [];
  particles = [];
  smokePuffs = [];
  fireballs = [];
  shockwaves = [];
  waterPlumes = [];
  waterRipples = [];
  bubbles = [];
  tombstones = [];
  surfaceFlora = [];
  silkWebs = [];
  silkNests = [];
  pineNuts = [];
  larvaeSwarms = [];
  updrafts = [];
  rovellons = [];
  caganers = [];
  escudelles = [];
  roundNumber = 1;
  hitStopTimer = 0;
  slowMoTimer = 0;
  teamDamageDealt = [0, 0];
  teamSelectedWeaponIdx = [0, 0];
  selectedWeaponIdx = 0;

  for (let t = 0; t < 2; t++) {
    teamAmmo[t] = {};
    for (const w of WEAPONS) teamAmmo[t][w.id] = w.defaultAmmo;
  }

  // Spread fighters across the 3200px battlefield AND across multiple vertical levels (upper balconies & lower terraces)!
  const baseT1 = [420, 1020, 1840, 2480];
  const baseT2 = [700, 1420, 2160, 2820];

  for (let i = 0; i < 4; i++) {
    const s1 = findMultiLevelSpawnSpot(baseT1[i] + (Math.random() - 0.5) * 160, 260, i % 2 === 1);
    const s2 = findMultiLevelSpawnSpot(baseT2[i] + (Math.random() - 0.5) * 160, 260, i % 2 === 0);
    fighters.push(createFighter(0, i, teamNames[0][i], s1.x, 1, s1.y));
    fighters.push(createFighter(1, i, teamNames[1][i], s2.x, -1, s2.y));
  }

  // Varied number and placement of explosive barrels each match across upper & lower tiers (3 to 7)
  const barrelCount = 3 + Math.floor(Math.random() * 5);
  for (let b = 0; b < barrelCount; b++) {
    const rawX = 360 + ((b + 0.3 + Math.random() * 0.4) / barrelCount) * (TERRAIN_W - 720);
    const spot = findMultiLevelSpawnSpot(rawX, 180, b % 2 === 1);
    const bx = spot.x, sy = spot.y;
    if (sy < WATER_Y - 22 && !fighters.some(f => Math.hypot(f.x - bx, f.y - sy) < 42)) {
      barrels.push({
        x: bx,
        y: sy - 14,
        vx: 0,
        vy: 0,
        r: 14,
        hp: 20,
        grounded: true
      });
    }
  }

  // Varied number and placement of proximity mines each match across upper & lower tiers (2 to 5)
  const mineCount = 2 + Math.floor(Math.random() * 4);
  for (let m = 0; m < mineCount; m++) {
    const rawX = 440 + ((m + 0.25 + Math.random() * 0.5) / mineCount) * (TERRAIN_W - 880);
    const spot = findMultiLevelSpawnSpot(rawX, 180, m % 2 === 0);
    const mx = spot.x, sy = spot.y;
    if (sy < WATER_Y - 22 && !fighters.some(f => Math.hypot(f.x - mx, f.y - sy) < 58)) {
      mines.push({
        x: mx,
        y: sy - 5,
        vx: 0,
        vy: 0,
        grounded: true,
        triggered: false,
        fuse: 1.8,
        beepTimer: 0
      });
    }
  }

  // Spawn Hanging Silk Nests ("Bolsones Vivos") on a randomized subset of generated Pine Trees!
  const treeSubset = generatedTreeSpots.filter(() => Math.random() < 0.68);
  const chosenTrees = treeSubset.length >= 2 ? treeSubset : generatedTreeSpots.slice(0, 3);
  for (const spot of chosenTrees) {
    const anchorX = spot.tx - 18;
    const anchorY = Math.max(85, spot.crownY + 4);
    silkNests.push({
      anchorX,
      anchorY,
      x: anchorX,
      y: anchorY + 28,
      r: 13,
      hp: 15,
      swayPhase: Math.random() * Math.PI * 2,
      swingAngle: 0,
      swingVel: 0
    });
  }

  // Spawn Regional Catalan Surface Flora on ALL vertical tiers!
  const mapId = MAPS[currentMapIdx].id;
  for (let fx = 240; fx < TERRAIN_W - 240; fx += 44 + Math.floor(Math.random() * 38)) {
    const tiers = findAllWalkableSurfacesAtX(fx);
    for (const sy of tiers) {
      if (sy < WATER_Y - 22 && !isSolid(fx, sy - 10)) {
        const n = getSurfaceNormal(fx, sy);
        if (Math.abs(n.x) < 0.62) {
          surfaceFlora.push({
            x: fx,
            y: sy,
            type: mapId,
            variant: Math.floor(Math.random() * 3),
            scale: 0.78 + Math.random() * 0.45,
            phase: Math.random() * Math.PI * 2
          });
        }
      }
    }
  }

  // Spawn 1 to 3 Thermal Pine-Resin Updrafts in randomized valleys!
  const shuffledValleys = [...generatedValleySpots].sort(() => Math.random() - 0.5);
  const updraftCount = 1 + Math.floor(Math.random() * Math.min(3, shuffledValleys.length));
  for (let u = 0; u < updraftCount; u++) {
    const ux = shuffledValleys[u];
    const uy = Math.min(WATER_Y - 12, findSurfaceY(ux, 140));
    updrafts.push({
      x: ux,
      y: uy,
      w: 42,
      h: 230
    });
  }

  // SURPRISE 1: Spawn 3 to 5 Giant Bouncy Catalan Rovelló Mushrooms on hillsides & lower ledges!
  const rovCount = 3 + Math.floor(Math.random() * 3);
  for (let r = 0; r < rovCount; r++) {
    const rawX = 480 + ((r + 0.2 + Math.random() * 0.6) / rovCount) * (TERRAIN_W - 960);
    const spot = findMultiLevelSpawnSpot(rawX, 160, r % 2 === 1);
    const rx = spot.x, sy = spot.y;
    if (sy < WATER_Y - 25 && !fighters.some(f => Math.hypot(f.x - rx, f.y - sy) < 44) && !barrels.some(b => Math.hypot(b.x - rx, b.y - sy) < 36)) {
      rovellons.push({
        x: rx,
        y: sy,
        r: 17 + Math.random() * 4,
        squash: 1.0,
        hp: 25
      });
    }
  }

  // SURPRISE 2: Spawn 1 or 2 Hidden Lucky "Caganer de la Sort" Figurines on scenic ledges or inside grottos!
  const cagCount = 1 + Math.floor(Math.random() * 2);
  for (let c = 0; c < cagCount; c++) {
    const rawX = 620 + c * 1450 + (Math.random() - 0.5) * 420;
    const spot = findMultiLevelSpawnSpot(rawX, 200, true); // Prefer lower/hidden grotto or terrace ledges!
    const cx = spot.x, sy = spot.y;
    if (sy < WATER_Y - 30 && !fighters.some(f => Math.hypot(f.x - cx, f.y - sy) < 55)) {
      caganers.push({
        x: cx,
        y: sy - 8,
        r: 11,
        bobPhase: Math.random() * Math.PI * 2
      });
    }
  }

  // SURPRISE 4: Spawn 2 Simmering Cast-Iron "Olles d'Escudella i Carn d'Olla" Soup Cauldrons!
  for (let e = 0; e < 2; e++) {
    const rawX = 920 + e * 1280 + (Math.random() - 0.5) * 320;
    const spot = findMultiLevelSpawnSpot(rawX, 180, e === 1);
    if (spot.y < WATER_Y - 28 && !fighters.some(f => Math.hypot(f.x - spot.x, f.y - spot.y) < 52)) {
      escudelles.push({
        x: spot.x,
        y: spot.y - 12,
        r: 15,
        hp: 25,
        steamPhase: Math.random() * Math.PI * 2
      });
    }
  }

  document.getElementById('lbl-map').textContent = MAPS[currentMapIdx].name;
  document.getElementById('victory-modal').classList.remove('open');
  teamTurnIdx = [0, 0];
  activeTeam = 1;
  startNextTurn();
  updateHUD();
  buildWeaponBar();
}

function createFighter(team, memberIdx, name, x, facing, explicitSurfY = null) {
  const sy = explicitSurfY !== null ? explicitSurfY : findSurfaceY(x, 30);
  const fy = Math.min(WATER_Y - 30, sy - 14);
  // Multi-segmented Oruga Procesionaria body (6 articulated trailing segments!)
  const segs = [];
  for (let s = 0; s < 6; s++) {
    segs.push({
      x: x - facing * (s + 1) * 5.2,
      y: fy + 4
    });
  }
  return {
    team,
    memberIdx,
    name,
    x,
    y: fy,
    vx: 0,
    vy: 0,
    r: 12,
    hp: 100,
    maxHp: 100,
    alive: true,
    drowning: false,
    drownTimer: 0,
    grounded: false,
    sliding: false,
    slideAngle: 0,
    jumpStartY: fy,
    isVoluntaryJump: true, // Prevent initial spawn drop from sliding
    wasBlasted: false,
    flipAngle: 0,
    flipSpin: 0,
    metamorphosed: false, // Awakens Thaumetopoea Moth Wings at low HP or 80+ DMG!
    linkedAllies: [],     // Nose-to-tail Procession Link allies
    castellTower: false,  // Active when stacked on top of an allied Cuc ("Castell de Cucs!")
    pilotaBuff: false,    // Active after eating from the Olla d'Escudella (+25% jump & knockback!)
    wineTipsy: 0,         // Turns of Priorat wine tipsy bubbles when splashed by a wine barrel!
    spoonTimer: 0,        // Active while bulldozing terrain with the Cullera de Fusta de Boix!
    drillTimer: 0,        // Active while boring downward/diagonally with the Barrina de Pedrera!
    grapple: null,        // Active while swinging/zipping on the Ganxo de Pastor!
    squashX: 1,
    squashY: 1,
    dizzyTimer: 0,
    urticatingTicks: 0, // Poisonous itching turns from Polvo Urticante!
    jetFuel: 0,
    batSwingTimer: 0,
    facing,
    walkCycle: 0,
    hurtTimer: 0,
    dmgDealt: 0,
    lastAimPitch: -0.42,
    lastChargePower: null,
    segs,
    customFaceImg: customFaces[team][memberIdx]
  };
}

function spawnSupplyDrop() {
  const cx = 300 + Math.random() * (TERRAIN_W - 600);
  const isMedkit = Math.random() < 0.42;
  const rewardPool = ['HOLY', 'AIRSTRIKE', 'DYNAMITE', 'JETPACK', 'CLUSTER', 'URTICARIA', 'CULLERA', 'BARRINA', 'PONT_PEDRA', 'GANXO'];
  const rewardWpn = rewardPool[Math.floor(Math.random() * rewardPool.length)];
  crates.push({
    x: cx,
    y: -30,
    vx: 0,
    vy: 55,
    parachuting: true,
    grounded: false,
    isMedkit,
    rewardWpn
  });
}

function updateWindHUD() {
  const bar = document.getElementById('wind-bar');
  const lbl = document.getElementById('wind-label');
  if (!bar || !lbl) return;
  const pct = clamp(Math.abs(wind) * 0.5, 0, 50);
  if (wind >= 0) {
    bar.style.left = '50%';
    bar.style.width = pct + '%';
    bar.style.background = windGustFlash > 0.1 ? '#ffe899' : '#f5b945';
  } else {
    bar.style.left = (50 - pct) + '%';
    bar.style.width = pct + '%';
    bar.style.background = windGustFlash > 0.1 ? '#b8f0ff' : '#7ec8e3';
  }
  const delta = windTarget - windFloat;
  const trendArrow = Math.abs(delta) > 14 ? (delta > 0 ? ' »' : ' «') : '';
  lbl.textContent = (wind > 0 ? '+' : '') + wind + trendArrow;
}

function randomizeWind() {
  windFloat = (Math.random() * 2 - 1) * 85;
  windTarget = clamp(windFloat + (Math.random() - 0.5) * 65, -100, 100);
  windGustTimer = 3.6 + Math.random() * 2.8;
  wind = Math.round(windFloat);
  updateWindHUD();
}

function updateDynamicWind(dt) {
  if (windGustFlash > 0) windGustFlash = Math.max(0, windGustFlash - dt * 1.8);

  // Continuously evolve wind during active gameplay so the player feels live gusts & shifts!
  if (appStage === 'PLAYING' && (turnPhase === 'TURN_PLAY' || turnPhase === 'RETREAT' || turnPhase === 'ACTION_WAIT')) {
    windGustTimer -= dt;
    if (windGustTimer <= 0) {
      const isStrongGust = Math.random() < 0.28;
      if (isStrongGust) {
        // Sudden Catalan Tramuntana or Garbí gust!
        const dir = Math.random() < 0.5 ? 1 : -1;
        windTarget = clamp(dir * (62 + Math.random() * 38), -100, 100);
        windGustTimer = 4.8 + Math.random() * 3.0;
        windGustFlash = 1.0;
        if (turnPhase === 'TURN_PLAY' && activeFighter) {
          SND.windGust();
          floatingTexts.push({
            x: activeFighter.x,
            y: activeFighter.y - 54,
            text: dir > 0 ? '¡RÀFEGA DE TRAMUNTANA! »' : '« ¡VENT DE GARBÍ!',
            color: dir > 0 ? '#f6cf77' : '#8fd8f2',
            life: 1.55
          });
        }
      } else {
        // Smooth natural shift in wind speed or direction as the player aims/moves
        windTarget = clamp(windTarget + (Math.random() - 0.5) * 78, -96, 96);
        windGustTimer = 3.2 + Math.random() * 2.8;
      }
    }

    // Smoothly approach windTarget + natural breathing gust oscillation
    const gustOsc = Math.sin(tNow * 1.75) * 5.5 + Math.cos(tNow * 0.92) * 3.5;
    windFloat = lerp(windFloat, windTarget, Math.min(1, dt * 0.62));
    wind = Math.round(clamp(windFloat + gustOsc, -100, 100));
    updateWindHUD();
  }

  // Drift all multi-layered volumetric clouds according to live wind!
  for (const c of cloudFlock) {
    const speed = (wind * 0.58 + c.baseDrift + 12) * (0.45 + c.z * 1.6);
    c.x += speed * dt;
    if (c.x > TERRAIN_W + 450) c.x -= (TERRAIN_W + 900);
    if (c.x < -450) c.x += (TERRAIN_W + 900);
  }

  // Advance visible wind-stream air ribbons across the battlefield
  for (const r of windRibbons) {
    const streamVx = (Math.abs(wind) < 6 ? 14 : wind * 2.6) * r.z;
    r.x += streamVx * dt;
    r.y += Math.sin(tNow * 2.2 + r.phase) * 8 * dt;
    if (r.x > TERRAIN_W + 250) r.x -= (TERRAIN_W + 500);
    if (r.x < -250) r.x += (TERRAIN_W + 500);
  }

  // Advance regional sky birds gliding in the wind
  for (const b of skyBirds) {
    const vx = (b.dir * b.speed + wind * 0.25) * (0.6 + b.z);
    b.x += vx * dt;
    if (b.x > TERRAIN_W + 350) b.x = -340;
    if (b.x < -350) b.x = TERRAIN_W + 340;
  }
}

function showVictoryModal(winningTeam) {
  const modal = document.getElementById('victory-modal');
  const title = document.getElementById('vic-title');
  const sub = document.getElementById('vic-sub');
  const stats = document.getElementById('vic-stats');

  if (winningTeam === 0) {
    title.textContent = '¡VICTÒRIA DE LA BRIGADA DEL PINAR!';
    title.style.color = '#f5b945';
    sub.textContent = `La Processó Daurada conquereix ${MAPS[currentMapIdx].name}!`;
  } else if (winningTeam === 1) {
    title.textContent = '¡VICTÒRIA DE LA COLUMNA TRAMUNTANA!';
    title.style.color = '#ea5648';
    sub.textContent = `La Processó Grana conquereix ${MAPS[currentMapIdx].name}!`;
  } else {
    title.textContent = '¡DESTRUCCIÓ MÚTUA — EMPAT!';
    title.style.color = '#f2ecdf';
    sub.textContent = 'Tots els cucs han caigut en combat!';
  }

  let mvp = fighters[0];
  for (const f of fighters) {
    if (f.dmgDealt > (mvp ? mvp.dmgDealt : -1)) mvp = f;
  }

  stats.innerHTML = `
    <div><span style="color:var(--ivory-muted)">Indret:</span> <b>${MAPS[currentMapIdx].name}</b></div>
    <div><span style="color:var(--ivory-muted)">Rondes Totals:</span> <b>${roundNumber}</b></div>
    <div><span style="color:var(--ivory-muted)">Dany Brigada del Pinar:</span> <b style="color:#f5b945">${teamDamageDealt[0]} PV</b></div>
    <div><span style="color:var(--ivory-muted)">Dany Tramuntana:</span> <b style="color:#ea5648">${teamDamageDealt[1]} PV</b></div>
    <div style="grid-column:span 2;border-top:1px solid rgba(255,255,255,0.1);padding-top:8px;margin-top:4px;">
      <span style="color:var(--brass-bright)">Cuc Processionari MVP:</span> <b>${mvp ? mvp.name : '—'}</b> (${mvp ? mvp.dmgDealt : 0} punts de dany)
    </div>
  `;

  if (appStage === 'PLAYING') {
    modal.classList.add('open');
  }
}

function startNextTurn() {
  const t0Alive = fighters.filter(f => f.team === 0 && f.alive && !f.drowning);
  const t1Alive = fighters.filter(f => f.team === 1 && f.alive && !f.drowning);

  if (t0Alive.length === 0 || t1Alive.length === 0) {
    turnPhase = 'GAME_OVER';
    const status = document.getElementById('turn-status');
    let winner = -1;
    if (t0Alive.length > 0) {
      winner = 0;
      status.textContent = '¡Victòria de la Brigada del Pinar!';
      status.style.color = '#f5b945';
    } else if (t1Alive.length > 0) {
      winner = 1;
      status.textContent = '¡Victòria de la Tramuntana!';
      status.style.color = '#ea5648';
    } else {
      status.textContent = '¡Destrucció Mútua — Empat!';
      status.style.color = '#f2ecdf';
    }
    SND.victory();
    showVictoryModal(winner);
    return;
  }

  activeTeam = 1 - activeTeam;
  if (activeTeam === 0) roundNumber++;

  if (roundNumber > 1 && Math.random() < 0.48 && crates.length < 3) {
    spawnSupplyDrop();
  }

  if (roundNumber >= 10 && WATER_Y > 460) {
    WATER_Y -= 14;
    floatingTexts.push({
      x: activeFighter ? activeFighter.x : TERRAIN_W * 0.5,
      y: WATER_Y - 30,
      text: '¡MORT SOBTADA — PUJA LA MAREA!',
      color: '#ff6b5b',
      life: 2.2
    });
  }

  const teamAlive = activeTeam === 0 ? t0Alive : t1Alive;
  const pickIdx = teamTurnIdx[activeTeam] % teamAlive.length;
  teamTurnIdx[activeTeam]++;
  activeFighter = teamAlive[pickIdx];
  activeFighter.jetFuel = 0;
  silkWebUsedThisTurn = false;
  const silkLbl = document.getElementById('lbl-silk-web');
  if (silkLbl) silkLbl.textContent = 'Teixir Seda [C]';

  // Apply Urticating Hair Itch damage at turn start if afflicted!
  if (activeFighter.urticatingTicks > 0) {
    activeFighter.urticatingTicks--;
    SND.wormVoice('ITCH');
    damageFighter(activeFighter, 8, '¡PICOR URTICANT!');
    spawnUrticatingHairs(activeFighter.x, activeFighter.y - 6, 14);
    if (!activeFighter.alive) {
      activeTeam = 1 - activeTeam; // Preserve this team's turn for its next surviving Cuc!
      startNextTurn();
      return;
    }
  }

  if (Math.random() < 0.65) {
    const list = ORUGA_TAUNTS.TURN;
    spawnSpeechBubble(activeFighter, list[Math.floor(Math.random() * list.length)], 2.2);
  }

  turnPhase = 'TURN_PLAY';
  turnTimer = 30;
  lastTurnTickSec = 30;
  hasActedOrMovedThisTurn = false;
  turnSpotlightTimer = 1.9;
  actionWaitTimer = 0;
  shotgunShotsLeft = 1;
  isCharging = false;
  chargePower = 0;
  aiPlan = null;
  cam.panOffsetX = 0;
  cam.panOffsetY = 0;
  impactCam.active = false;
  impactCam.trackedWorm = null;

  // Restore this worm's remembered classic Worms aim pitch & target point!
  aimPitch = (activeFighter.lastAimPitch !== undefined) ? activeFighter.lastAimPitch : -0.42;
  syncAimAngleFromPitch();
  mouseWorld = {
    x: clamp(activeFighter.x + activeFighter.facing * 260, 200, TERRAIN_W - 200),
    y: Math.max(180, activeFighter.y - 95)
  };

  // Restore this team's own last selected weapon so the enemy's weapon choice never overrides yours!
  selectedWeaponIdx = teamSelectedWeaponIdx[activeTeam] ?? 0;
  if (teamAmmo[activeTeam][WEAPONS[selectedWeaponIdx].id] <= 0) {
    selectedWeaponIdx = 0;
    teamSelectedWeaponIdx[activeTeam] = 0;
  }

  randomizeWind();
  updateHUD();
  buildWeaponBar();

  const st = document.getElementById('turn-status');
  st.textContent = `Torn de ${activeFighter.name}`;
  st.style.color = activeTeam === 0 ? '#f5b945' : '#ea5648';
  document.getElementById('round-sub').textContent =
    `Ronda ${roundNumber} · ${MAPS[currentMapIdx].name}`;
}

function isCurrentTurnAI() {
  if (appStage !== 'PLAYING') return true; // Background showcase AI during Splash/Intro
  if (turnPhase === 'GAME_OVER') return false;
  if (gameMode === 'CPU_CPU') return true;
  if (gameMode === '1P_CPU' && activeTeam === 1) return true;
  return false;
}

