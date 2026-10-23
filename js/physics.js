"use strict";

// ═══════════════════════════════════════════════════════════════════════════
//  6. EXPLOSIONS, URTICATING HAIR CLOUDS, SILK NESTS & 10-WEAPON DISPATCH
// ═══════════════════════════════════════════════════════════════════════════
const GRAVITY = 440;

function spawnUrticatingHairs(x, y, count) {
  for (let i = 0; i < count; i++) {
    const a = Math.random() * Math.PI * 2;
    const sp = 40 + Math.random() * 190;
    particles.push({
      x, y,
      vx: Math.cos(a) * sp,
      vy: Math.sin(a) * sp - 45,
      w: 7, h: 1.5,
      rot: a,
      vrot: (Math.random() - 0.5) * 14,
      life: 1.15,
      decay: 0.75 + Math.random() * 0.4,
      color: Math.random() > 0.45 ? '#d88aff' : '#ffae42',
      isHair: true
    });
  }
}

function burstSilkNest(nest) {
  SND.urticatingBurst();
  spawnSmoke(nest.x, nest.y, 12, 'rgba(248, 244, 232, 0.78)');
  spawnUrticatingHairs(nest.x, nest.y, 28);
  floatingTexts.push({
    x: nest.x,
    y: nest.y - 20,
    text: '¡BOSSA DE SEDA REBENTADA! +PINYONS I LARVES!',
    color: '#ffe082',
    life: 2.1
  });

  // Drop 3 Golden Pine Nuts (Pinyons Daurats) that heal +20 PV and evolve Max PV!
  for (let k = 0; k < 3; k++) {
    pineNuts.push({
      x: nest.x + (k - 1) * 10,
      y: nest.y,
      vx: (k - 1) * 65 + (Math.random() - 0.5) * 35,
      vy: -120 - Math.random() * 55,
      r: 6,
      grounded: false,
      life: 18.0
    });
  }

  // Unleash an Angry Micro-Larvae Swarm that chases the nearest fighter!
  larvaeSwarms.push({
    x: nest.x,
    y: nest.y + 8,
    vx: 0,
    vy: 40,
    life: 5.5,
    tickTimer: 0.45
  });
}

function spinElasticSilkWeb() {
  if (!activeFighter || !activeFighter.alive || activeFighter.drowning || silkWebUsedThisTurn) return;
  if (appStage !== 'PLAYING' || (turnPhase !== 'TURN_PLAY' && turnPhase !== 'RETREAT')) return;

  silkWebUsedThisTurn = true;
  const silkLbl = document.getElementById('lbl-silk-web');
  if (silkLbl) silkLbl.textContent = 'Seda Teixida ✓';

  const dirX = Math.cos(aimAngle);
  const dirY = Math.sin(aimAngle);
  const centerDist = 46;
  const cx = activeFighter.x + dirX * centerDist;
  const cy = (activeFighter.y - 6) + dirY * centerDist;
  // Perpendicular span to aim direction so it forms an elastic trampoline / deflector shield!
  const perpX = -dirY;
  const perpY = dirX;
  const halfSpan = 38;

  silkWebs.push({
    x1: cx - perpX * halfSpan,
    y1: cy - perpY * halfSpan,
    x2: cx + perpX * halfSpan,
    y2: cy + perpY * halfSpan,
    hp: 3,
    vibration: 1.0,
    team: activeFighter.team
  });

  SND.jump();
  spawnUrticatingHairs(cx, cy, 12);
  floatingTexts.push({
    x: cx,
    y: cy - 16,
    text: '¡SEDA ELÀSTICA TEIXIDA!',
    color: '#fff6df',
    life: 1.65
  });
}

function checkMetamorphosis(f) {
  if (!f || !f.alive || f.drowning || f.metamorphosed) return;
  if ((f.hp > 0 && f.hp <= 35) || f.dmgDealt >= 75) {
    f.metamorphosed = true;
    SND.cratePickup();
    spawnUrticatingHairs(f.x, f.y - 6, 26);
    shockwaves.push({
      x: f.x,
      y: f.y - 4,
      r: 5,
      maxR: 54,
      alpha: 0.95,
      color: '246, 207, 119'
    });
    const msg = ORUGA_TAUNTS.METAMORPH[Math.floor(Math.random() * ORUGA_TAUNTS.METAMORPH.length)];
    spawnSpeechBubble(f, msg, 2.4);
    floatingTexts.push({
      x: f.x,
      y: f.y - 42,
      text: `¡${f.name}: METAMORFOSI ALADA! (MANTÉN W PER PLANAR)`,
      color: '#ffe082',
      life: 2.4
    });
  }
}

function triggerExplosion(ex, ey, radius, maxDmg, knockback, spawnClusters = 0, isUrticating = false) {
  if (isUrticating) {
    SND.urticatingBurst();
    spawnUrticatingHairs(ex, ey, 48);
    spawnSmoke(ex, ey, 14, 'rgba(168, 85, 235, 0.58)');
  } else {
    SND.boom(radius / 45);
    spawnSmoke(ex, ey, Math.floor(radius * 0.42), 'rgba(32, 28, 26, 0.78)');
    spawnSparks(ex, ey, Math.floor(radius * 0.75));
    spawnEmbers(ex, ey, Math.floor(radius * 0.35));
  }

  // Multi-Stage Volumetric Fireball Core
  fireballs.push({
    x: ex,
    y: ey,
    r: Math.max(8, radius * 0.35),
    maxR: Math.max(20, radius * 1.45),
    life: 1.0,
    decay: 2.35,
    isUrticating: !!isUrticating
  });

  // Lock camera onto the explosion site so it doesn't snap back to the shooter!
  impactCam.active = true;
  impactCam.x = ex;
  impactCam.y = ey;
  if (turnPhase === 'RETREAT') {
    turnPhase = 'ACTION_WAIT';
  }

  shake = Math.max(shake, radius * 0.38);
  flashLight = 1.0;
  flashPos = { x: ex, y: ey };

  if (radius >= 65 && appStage === 'PLAYING') {
    hitStopTimer = 0.055;
    slowMoTimer = 0.45;
  }

  // Double concentric shockwave + heat-refraction ring
  shockwaves.push({
    x: ex,
    y: ey,
    r: 8,
    maxR: radius * 3.2,
    alpha: 1.0,
    color: isUrticating ? '210, 125, 255' : '255, 225, 175'
  });
  shockwaves.push({
    x: ex,
    y: ey,
    r: 4,
    maxR: radius * 1.95,
    alpha: 0.75,
    color: isUrticating ? '245, 195, 255' : '255, 145, 70'
  });

  carveCrater(ex, ey, radius);
  spawnRockDebris(ex, ey, Math.floor(radius * 0.46));

  // Uproot any surface flora caught in the crater or blast wave!
  for (let i = surfaceFlora.length - 1; i >= 0; i--) {
    const fl = surfaceFlora[i];
    const dFl = Math.hypot(fl.x - ex, fl.y - ey);
    if (dFl <= radius * 1.45 || !isSolid(fl.x, fl.y + 3)) {
      surfaceFlora.splice(i, 1);
      for (let p = 0; p < 3; p++) {
        particles.push({
          x: fl.x,
          y: fl.y - 4,
          vx: (fl.x - ex) * 2.2 + (Math.random() - 0.5) * 90,
          vy: -90 - Math.random() * 110,
          w: 4.5,
          h: 2.5,
          rot: Math.random() * 6,
          vrot: (Math.random() - 0.5) * 14,
          life: 1.1,
          decay: 0.8,
          color: fl.type === 'TAULL' ? '#e8f4ff' : (fl.type === 'CASTELLFOLLIT' ? '#e67e22' : '#7cb342'),
          isSpark: false
        });
      }
    }
  }

  // If explosion is near the water surface, kick up a water ripple & spray!
  if (Math.abs(ey - WATER_Y) < radius * 1.5) {
    spawnWaterPlunge(ex, WATER_Y, clamp(radius / 55, 0.5, 1.35));
  }

  const hitRadius = radius * (isUrticating ? 2.1 : 1.68);

  // Check if any Hanging Silk Nests ("Bolsones") are hit or swung by the blast wave!
  for (let i = silkNests.length - 1; i >= 0; i--) {
    const nest = silkNests[i];
    const dNest = Math.hypot(nest.x - ex, nest.y - ey);
    if (dNest <= hitRadius + nest.r) {
      silkNests.splice(i, 1);
      burstSilkNest(nest);
    } else if (dNest <= radius * 4.2) {
      const pushDir = Math.sign(nest.x - ex) || 1;
      nest.swingVel = (nest.swingVel || 0) + pushDir * (1 - dNest / (radius * 4.2)) * 12;
    }
  }

  // Blast wave pushes parachuting or grounded Crates & Mines!
  for (const c of crates) {
    const dC = Math.hypot(c.x - ex, c.y - ey);
    if (dC < hitRadius * 1.35 && dC > 1) {
      const fC = 1 - dC / (hitRadius * 1.35);
      c.vx += ((c.x - ex) / dC) * 220 * fC;
      c.vy -= 160 * fC;
      c.grounded = false;
    }
  }
  for (const m of mines) {
    const dM = Math.hypot(m.x - ex, m.y - ey);
    if (dM < hitRadius * 1.25 && dM > 1) {
      const fM = 1 - dM / (hitRadius * 1.25);
      m.vx += ((m.x - ex) / dM) * 240 * fM;
      m.vy -= 175 * fM;
      m.grounded = false;
      m.triggered = true;
    }
  }

  // Check if any Giant Catalan Rovelló Mushrooms are roasted by the blast!
  for (let i = rovellons.length - 1; i >= 0; i--) {
    const rv = rovellons[i];
    if (Math.hypot(rv.x - ex, (rv.y - 8) - ey) <= hitRadius + rv.r) {
      rovellons.splice(i, 1);
      SND.rovelloBoing();
      spawnSmoke(rv.x, rv.y - 10, 8, 'rgba(235, 128, 52, 0.72)');
      floatingTexts.push({
        x: rv.x,
        y: rv.y - 26,
        text: '¡ROVELLÓ A LA BRASA!',
        color: '#ff9e44',
        life: 1.6
      });
      for (let k = 0; k < 2; k++) {
        pineNuts.push({
          x: rv.x + (k === 0 ? -8 : 8),
          y: rv.y - 14,
          vx: (k === 0 ? -1 : 1) * (55 + Math.random() * 55),
          vy: -135 - Math.random() * 55,
          r: 6,
          grounded: false,
          life: 18.0
        });
      }
    }
  }

  for (const f of fighters) {
    if (!f.alive || f.drowning) continue;
    const dx = f.x - ex;
    const dy = (f.y - 4) - ey;
    const dist = Math.hypot(dx, dy);
    if (dist < hitRadius) {
      const falloff = clamp(1 - dist / hitRadius, 0.14, 1.0);
      // Procession Silk Shield reduces incoming damage by 20% when linked nose-to-tail with allies!
      const shieldMult = (f.linkedAllies && f.linkedAllies.length > 0) ? 0.80 : 1.0;
      const dmg = Math.max(1, Math.round(maxDmg * falloff * shieldMult));
      if ((dmg >= 35 || f.hp <= dmg) && appStage === 'PLAYING') {
        hitStopTimer = Math.max(hitStopTimer, 0.045);
        slowMoTimer = Math.max(slowMoTimer, 0.35);
      }

      if (isUrticating) {
        f.urticatingTicks = 3; // 3 turns of stinging Procesionaria hair allergy!
        const taunt = ORUGA_TAUNTS.URTICARIA[Math.floor(Math.random() * ORUGA_TAUNTS.URTICARIA.length)];
        spawnSpeechBubble(f, taunt, 2.2);
      } else if (Math.random() < 0.55) {
        const taunt = ORUGA_TAUNTS.HIT[Math.floor(Math.random() * ORUGA_TAUNTS.HIT.length)];
        spawnSpeechBubble(f, taunt, 1.8);
      }

      damageFighter(f, dmg, isUrticating ? '¡URTICÀRIA!' : (shieldMult < 1 ? 'ESCUT DE SEDA' : null));
      spawnUrticatingHairs(f.x, f.y - 4, 8);

      const nx = dist > 1 ? dx / dist : (Math.random() - 0.5);
      const ny = dist > 1 ? dy / dist : -1;
      const imp = knockback * falloff;
      f.vx += nx * imp;
      f.vy = Math.min(f.vy, 0) + ny * imp - 155 * falloff;
      f.grounded = false;
      f.sliding = false;
      f.isVoluntaryJump = false;
      f.wasBlasted = true;
      f.jumpStartY = f.y;
      f.peakAirY = f.y;
      f.hurtTimer = 1.0;
      f.squashX = 0.68;
      f.squashY = 1.42;
      if (!impactCam.trackedWorm || f !== activeFighter) {
        impactCam.trackedWorm = f;
      }
    }
  }

  for (let i = barrels.length - 1; i >= 0; i--) {
    const b = barrels[i];
    const dist = Math.hypot(b.x - ex, b.y - ey);
    if (dist < hitRadius) {
      b.hp -= maxDmg * (1 - dist / hitRadius);
      if (b.hp <= 0) {
        barrels.splice(i, 1);
        // Splash ruby-purple Priorat red wine droplets & make nearby caterpillars Wine-Tipsy!
        for (let w = 0; w < 22; w++) {
          const wa = Math.random() * Math.PI * 2;
          const wsp = 60 + Math.random() * 190;
          particles.push({
            x: b.x, y: b.y,
            vx: Math.cos(wa) * wsp,
            vy: Math.sin(wa) * wsp - 50,
            w: 4, h: 4, rot: 0, vrot: 0,
            life: 1.25, decay: 0.85,
            color: Math.random() < 0.6 ? '#9e1b34' : '#d83b56',
            isSpark: false,
            collidesTerrain: true
          });
        }
        for (const f of fighters) {
          if (f.alive && !f.drowning && Math.hypot(f.x - b.x, f.y - b.y) < 115) {
            f.wineTipsy = 2;
            floatingTexts.push({
              x: f.x, y: f.y - 36,
              text: '¡XOP DE VI DEL PRIORAT!',
              color: '#e85d75',
              life: 1.7
            });
          }
        }
        setTimeout(() => {
          triggerExplosion(b.x, b.y, 58, 55, 500, 0, false);
        }, 70);
      } else {
        const nx = (b.x - ex) / Math.max(1, dist);
        b.vx += nx * 240;
        b.vy -= 210;
        b.grounded = false;
      }
    }
  }

  // Check if any Simmering "Olla d'Escudella" Soup Cauldrons are hit -> Erupt in a Galets Pasta & Broth Geyser!
  for (let i = escudelles.length - 1; i >= 0; i--) {
    const ol = escudelles[i];
    if (Math.hypot(ol.x - ex, ol.y - ey) <= hitRadius + ol.r) {
      escudelles.splice(i, 1);
      SND.boom(0.9);
      spawnSmoke(ol.x, ol.y - 8, 12, 'rgba(255, 242, 210, 0.82)');
      floatingTexts.push({
        x: ol.x, y: ol.y - 28,
        text: '¡ESCUDELLA EXPLOSIVA! ¡PLUJA DE GALETS!',
        color: '#ffe082',
        life: 1.95
      });
      for (let g = 0; g < 3; g++) {
        const ga = -Math.PI * 0.5 + (g - 1) * 0.36 + (Math.random() - 0.5) * 0.12;
        const gsp = 210 + Math.random() * 80;
        projectiles.push({
          type: 'CARQUINYOLI',
          isGalet: true,
          x: ol.x,
          y: ol.y - 10,
          vx: Math.cos(ga) * gsp,
          vy: Math.sin(ga) * gsp,
          r: 6,
          windFactor: 0.15,
          bounces: true,
          bouncesLeft: 2,
          fuse: 2.0 + g * 0.15,
          lastSec: 0,
          blastR: 28,
          maxDmg: 22,
          knockback: 320,
          age: 0,
          ang: g
        });
      }
    }
  }

  if (spawnClusters > 0) {
    for (let i = 0; i < spawnClusters; i++) {
      const spread = (i - (spawnClusters - 1) * 0.5) * 0.32 + (Math.random() - 0.5) * 0.12;
      const speed = 210 + Math.random() * 90;
      projectiles.push({
        type: 'BOMBLER',
        x: ex,
        y: ey - 6,
        vx: Math.sin(spread) * speed,
        vy: -Math.cos(spread) * speed,
        r: 4.5,
        windFactor: 0,
        bounces: false,
        blastR: 32,
        maxDmg: 24,
        knockback: 310,
        age: 0
      });
    }
  }

  updateHUD();
}

function damageFighter(f, dmg, customLabel = null) {
  if (!f.alive) return;
  const actual = Math.min(f.hp, dmg);
  f.hp = Math.max(0, f.hp - dmg);
  if (appStage === 'PLAYING') {
    SND.wormHurt(dmg, f.hp <= 0);
  }

  if (activeFighter && activeFighter.team !== f.team) {
    activeFighter.dmgDealt += actual;
    teamDamageDealt[activeFighter.team] += actual;
    checkMetamorphosis(activeFighter);
  }

  floatingTexts.push({
    x: f.x,
    y: f.y - 28,
    text: customLabel ? `${customLabel} -${dmg}` : `-${dmg}`,
    color: customLabel === '¡URTICÀRIA!' ? '#d88aff' : '#ff6b5b',
    life: 1.45
  });
  if (f.hp <= 0 && !f.drowning) {
    f.alive = false;
    floatingTexts.push({
      x: f.x,
      y: f.y - 46,
      text: `¡${f.name} CAIGUT!`,
      color: '#f6cf77',
      life: 1.95
    });
    spawnSmoke(f.x, f.y, 10, 'rgba(210, 195, 175, 0.55)');
    spawnUrticatingHairs(f.x, f.y, 22);
    tombstones.push({
      x: f.x,
      y: f.y - 6,
      vy: -140,
      name: f.name,
      team: f.team
    });
  } else {
    checkMetamorphosis(f);
  }
  updateHUD();
}

function fireWeapon(wpn, angle, power, targetPt) {
  if (!activeFighter || !activeFighter.alive || activeFighter.drowning) return;

  hasActedOrMovedThisTurn = true;
  if (!isCurrentTurnAI() && wpn.type === 'CHARGE') {
    activeFighter.lastAimPitch = aimPitch;
    activeFighter.lastChargePower = power;
  }

  if (teamAmmo[activeTeam][wpn.id] !== Infinity) {
    teamAmmo[activeTeam][wpn.id] = Math.max(0, teamAmmo[activeTeam][wpn.id] - 1);
  }
  buildWeaponBar();

  const dirX = Math.cos(angle);
  const dirY = Math.sin(angle);
  activeFighter.facing = dirX >= 0 ? 1 : -1;

  // Calculate Procession Fury (+25% per linked nose-to-tail ally, up to +50%) + Castell de Cucs (+30%) + Pilota d'Escudella (+25%) + Metamorphosis (+15%)!
  const linkedCount = (activeFighter.linkedAllies ? Math.min(2, activeFighter.linkedAllies.length) : 0);
  const castellBoost = activeFighter.castellTower ? 0.30 : 0;
  const pilotaBoost = activeFighter.pilotaBuff ? 0.25 : 0;
  const dmgBoost = 1.0 + linkedCount * 0.25 + castellBoost + pilotaBoost + (activeFighter.metamorphosed ? 0.15 : 0);
  const radiusBoost = 1.0 + linkedCount * 0.12 + (activeFighter.castellTower ? 0.15 : 0) + (activeFighter.pilotaBuff ? 0.10 : 0);
  const effDmg = Math.round((wpn.maxDmg || 0) * dmgBoost);
  const effBlastR = Math.round((wpn.blastR || 0) * radiusBoost);
  const effKnockback = Math.round((wpn.knockback || 0) * (1 + pilotaBoost));

  if (activeFighter.castellTower) {
    floatingTexts.push({
      x: activeFighter.x,
      y: activeFighter.y - 52,
      text: '¡CASTELL DE CUCS! +30% FORÇA ENXANETA!',
      color: '#ffd966',
      life: 1.75
    });
  } else if (linkedCount > 0) {
    floatingTexts.push({
      x: activeFighter.x,
      y: activeFighter.y - 44,
      text: `¡FÚRIA EN PROCESSÓ! +${Math.round((dmgBoost - 1) * 100)}% DANY`,
      color: '#ffe082',
      life: 1.6
    });
  }

  const muzzleX = activeFighter.x + dirX * 18;
  const muzzleY = (activeFighter.y - 4) + dirY * 18;

  if (wpn.id === 'BAZOOKA' || wpn.id === 'URTICARIA') {
    SND.fireBazooka();
    const speed = 180 + power * 760;
    spawnSmoke(muzzleX, muzzleY, 5, wpn.id === 'URTICARIA' ? 'rgba(185, 110, 245, 0.55)' : 'rgba(220, 210, 195, 0.5)');
    projectiles.push({
      type: wpn.id,
      x: muzzleX,
      y: muzzleY,
      vx: dirX * speed,
      vy: dirY * speed,
      r: 5.5,
      windFactor: wpn.windFactor,
      bounces: false,
      isUrticating: wpn.id === 'URTICARIA',
      blastR: effBlastR,
      maxDmg: effDmg,
      knockback: wpn.knockback,
      age: 0
    });
    turnPhase = 'ACTION_WAIT';
  } else if (wpn.id === 'CARQUINYOLI') {
    SND.carquinyoliCrunch();
    SND.jump();
    floatingTexts.push({
      x: activeFighter.x,
      y: activeFighter.y - 30,
      text: '¡CARQUINYOLIS TRENCADENTS!',
      color: '#f6cf77',
      life: 1.65
    });
    for (let k = 0; k < 3; k++) {
      const a = angle + (k - 1) * 0.085;
      const sp = (210 + power * 680) * (1 - Math.abs(k - 1) * 0.06);
      projectiles.push({
        type: 'CARQUINYOLI',
        x: muzzleX,
        y: muzzleY,
        vx: Math.cos(a) * sp,
        vy: Math.sin(a) * sp,
        r: 5.5,
        windFactor: wpn.windFactor,
        bounces: true,
        bouncesLeft: 3,
        fuse: 2.3 + k * 0.16,
        lastSec: 0,
        blastR: effBlastR,
        maxDmg: effDmg,
        knockback: wpn.knockback,
        age: 0,
        ang: k * 1.1
      });
    }
    turnPhase = 'ACTION_WAIT';
  } else if (wpn.id === 'GRENADE' || wpn.id === 'CLUSTER' || wpn.id === 'HOLY') {
    SND.jump();
    const speed = 150 + power * 680;
    const fuseVal = wpn.hasCustomFuse ? customGrenadeFuse : wpn.fuse;
    projectiles.push({
      type: wpn.id,
      x: muzzleX,
      y: muzzleY,
      vx: dirX * speed,
      vy: dirY * speed,
      r: wpn.id === 'HOLY' ? 8 : 6,
      windFactor: 0,
      bounces: true,
      fuse: fuseVal,
      choirPlayed: false,
      lastSec: Math.ceil(fuseVal),
      blastR: effBlastR,
      maxDmg: effDmg,
      knockback: wpn.knockback,
      clusters: wpn.id === 'CLUSTER' ? 5 : 0,
      age: 0,
      ang: 0
    });
    turnPhase = 'ACTION_WAIT';
  } else if (wpn.id === 'SHOTGUN') {
    SND.shotgun();
    spawnSmoke(muzzleX, muzzleY, 5, 'rgba(235, 220, 195, 0.55)');
    spawnSparks(muzzleX, muzzleY, 8);

    let hitX = muzzleX, hitY = muzzleY;
    for (let d = 4; d < 920; d += 3) {
      const rx = muzzleX + dirX * d;
      const ry = muzzleY + dirY * d;
      let hitSomething = isSolid(rx, ry);
      for (const f of fighters) {
        if (f !== activeFighter && f.alive && !f.drowning && Math.hypot(f.x - rx, (f.y - 4) - ry) <= f.r + 4) {
          hitSomething = true;
          break;
        }
      }
      for (const b of barrels) {
        if (Math.hypot(b.x - rx, b.y - ry) <= b.r + 3) {
          hitSomething = true;
          break;
        }
      }
      for (const nest of silkNests) {
        if (Math.hypot(nest.x - rx, nest.y - ry) <= nest.r + 3) {
          hitSomething = true;
          break;
        }
      }
      hitX = rx; hitY = ry;
      if (hitSomething) break;
    }

    particles.push({
      isBeam: true,
      x1: muzzleX, y1: muzzleY,
      x2: hitX, y2: hitY,
      life: 0.22,
      decay: 1.0
    });

    triggerExplosion(hitX, hitY, effBlastR, effDmg, wpn.knockback, 0, false);

    shotgunShotsLeft = 0;
    turnPhase = 'ACTION_WAIT';
  } else if (wpn.id === 'FUET' || wpn.id === 'BAT') {
    const isFuet = wpn.id === 'FUET';
    activeFighter.batSwingTimer = 0.48;
    activeFighter.lastMeleeId = wpn.id;
    if (isFuet) SND.fuetWhip();
    SND.wormVoice('ATTACK');

    // White penicillium flour cloud when whipping El Fuet!
    if (isFuet) {
      spawnSmoke(muzzleX + dirX * 10, muzzleY + dirY * 10, 8, 'rgba(248, 244, 236, 0.78)');
    }

    const reach = isFuet ? 68 : 48;
    let hitAnyone = false;

    // Live Grenade / Tió / Carquinyoli Deflection ("¡REBOT DE MESTRE!"): bat away any nearby ticking explosive!
    for (const p of projectiles) {
      if (Math.hypot(p.x - activeFighter.x, p.y - activeFighter.y) <= reach + 18) {
        p.vx = dirX * 640;
        p.vy = dirY * 640 - 115;
        if (p.fuse !== undefined) p.fuse = Math.max(p.fuse, 1.8);
        hitAnyone = true;
        SND.homeRun();
        floatingTexts.push({
          x: p.x, y: p.y - 26,
          text: '¡REBOT DE MESTRE!',
          color: '#ffd966',
          life: 1.5
        });
      }
    }

    for (const f of fighters) {
      if (f !== activeFighter && f.alive && !f.drowning) {
        const dist = Math.hypot(f.x - activeFighter.x, f.y - activeFighter.y);
        if (dist <= reach) {
          hitAnyone = true;
          damageFighter(f, effDmg, isFuet ? '¡COP DE FUET DE VIC!' : '¡BON COP DE FALÇ!');
          f.vx = dirX * effKnockback;
          f.vy = Math.min(isFuet ? -185 : -210, dirY * effKnockback - (isFuet ? 95 : 120));
          f.grounded = false;
          f.sliding = false;
          f.isVoluntaryJump = false;
          f.wasBlasted = true;
          f.jumpStartY = f.y;
          f.peakAirY = f.y;
          f.dizzyTimer = 2.8;
          f.squashX = 0.52;
          f.squashY = 1.65;
          impactCam.active = true;
          impactCam.x = f.x;
          impactCam.y = f.y;
          impactCam.trackedWorm = f;
          spawnUrticatingHairs(f.x, f.y - 4, 22);
          if (isFuet) {
            spawnSmoke(f.x, f.y - 4, 10, 'rgba(252, 249, 242, 0.85)');
          }
          shockwaves.push({ x: f.x, y: f.y - 4, r: 4, maxR: isFuet ? 64 : 55, alpha: 1.0 });
        }
      }
    }
    if (hitAnyone) {
      SND.homeRun();
      if (appStage === 'PLAYING') {
        hitStopTimer = 0.068;
        slowMoTimer = 0.52;
      }
      shake = 15;
      turnPhase = 'ACTION_WAIT';
    } else if (isFuet) {
      // If swung without an enemy in immediate melee range, a cured Fuet slice snaps off at high speed!
      floatingTexts.push({
        x: activeFighter.x,
        y: activeFighter.y - 28,
        text: '¡ZASCA DE FUET!',
        color: '#f4eee1',
        life: 1.3
      });
      projectiles.push({
        type: 'CARQUINYOLI',
        isFuetSlice: true,
        x: muzzleX,
        y: muzzleY,
        vx: dirX * 520,
        vy: dirY * 520 - 40,
        r: 5.5,
        windFactor: 0.2,
        bounces: false,
        blastR: 26,
        maxDmg: Math.round(effDmg * 0.75),
        knockback: 480,
        age: 0,
        ang: 0
      });
      turnPhase = 'ACTION_WAIT';
    } else {
      SND.jump();
      turnPhase = 'RETREAT';
      phaseTimer = 2.2;
    }
  } else if (wpn.id === 'DYNAMITE') {
    SND.tick();
    floatingTexts.push({
      x: activeFighter.x,
      y: activeFighter.y - 30,
      text: '¡CAGA TIÓ, CAGA TORRÓ!',
      color: '#ffe082',
      life: 1.8
    });
    projectiles.push({
      type: 'DYNAMITE',
      x: activeFighter.x + activeFighter.facing * 12,
      y: activeFighter.y - 6,
      vx: activeFighter.facing * 28,
      vy: -40,
      r: 7,
      windFactor: 0,
      bounces: true,
      fuse: wpn.fuse,
      lastSec: Math.ceil(wpn.fuse),
      blastR: effBlastR,
      maxDmg: effDmg,
      knockback: wpn.knockback,
      clusters: 0,
      age: 0,
      ang: 0
    });
    turnPhase = 'RETREAT';
    phaseTimer = 4.0;
  } else if (wpn.id === 'AIRSTRIKE') {
    SND.jet();
    const tx = targetPt ? targetPt.x : TERRAIN_W * 0.5;
    const fromLeft = tx >= TERRAIN_W * 0.5;
    airstrikePlanes.push({
      x: fromLeft ? tx - 720 : tx + 720,
      y: 58,
      vx: fromLeft ? 820 : -820,
      targetX: tx,
      dropped: [false, false, false, false, false],
      offsets: [-105, -52, 0, 52, 105]
    });
    turnPhase = 'ACTION_WAIT';
  } else if (wpn.id === 'JETPACK') {
    SND.jet();
    activeFighter.jetFuel = 100;
    activeFighter.grounded = false;
    activeFighter.isVoluntaryJump = true;
    activeFighter.jumpStartY = activeFighter.y;
    activeFighter.vy = -150;
    floatingTexts.push({
      x: activeFighter.x,
      y: activeFighter.y - 28,
      text: '¡ALES DE PINAR (W/A/D)!',
      color: '#f6cf77',
      life: 1.8
    });
    selectedWeaponIdx = 0;
    if (!isCurrentTurnAI()) teamSelectedWeaponIdx[activeTeam] = 0;
    buildWeaponBar();
  } else if (wpn.id === 'CULLERA') {
    // TOOL 1: Cullera de Fusta de Boix (Giant Boxwood Wooden Spoon Bulldozer / Terrain Scooper!)
    SND.spoonScoop();
    SND.wormVoice('ATTACK');
    activeFighter.spoonTimer = 2.15;
    activeFighter.spoonAngle = clamp(angle, -Math.PI * 0.85, Math.PI * 0.85);
    activeFighter.spoonTick = 0;
    floatingTexts.push({
      x: activeFighter.x,
      y: activeFighter.y - 32,
      text: '¡CULLERADA DE BOIX! ¡OBRINT PAS!',
      color: '#f6cf77',
      life: 1.75
    });
    turnPhase = 'ACTION_WAIT';
  } else if (wpn.id === 'BARRINA') {
    // TOOL 2: Barrina de Pedrera (Pneumatic Catalan Quarry Jackhammer / Rock Drill!)
    SND.drillBore();
    // Ensure drill angle points downward or diagonally downward into the earth
    let dAng = angle;
    if (Math.sin(dAng) < 0.22) {
      dAng = activeFighter.facing >= 0 ? 1.05 : (Math.PI - 1.05);
    }
    activeFighter.drillTimer = 1.95;
    activeFighter.drillAngle = dAng;
    activeFighter.drillTick = 0;
    floatingTexts.push({
      x: activeFighter.x,
      y: activeFighter.y - 32,
      text: '¡BARRINA DE MINAIRE! ¡Brrrrr!',
      color: '#ffae42',
      life: 1.75
    });
    turnPhase = 'ACTION_WAIT';
  } else if (wpn.id === 'PONT_PEDRA') {
    // TOOL 3: Marge de Pedra Seca (Dry-Stone Wall, Ramp & Bridge Builder!)
    SND.stoneBuild();
    const girderDist = 52;
    const gx = activeFighter.x + dirX * girderDist;
    const gy = (activeFighter.y - 4) + dirY * girderDist;
    buildDryStoneGirder(gx, gy, angle, 82, 16);
    spawnSmoke(gx, gy, 10, 'rgba(185, 175, 158, 0.65)');
    spawnRockDebris(gx, gy, 8);
    floatingTexts.push({
      x: gx,
      y: gy - 22,
      text: '¡MARGE DE PEDRA SECA CONSTRUÏT!',
      color: '#e8e2d5',
      life: 1.85
    });
    turnPhase = 'RETREAT';
    phaseTimer = 2.8;
  } else if (wpn.id === 'GANXO') {
    // TOOL 4: Ganxo de Pastor (Pyrenean Shepherd's Crook Grapple Hook & Enemy Yanker!)
    SND.grappleWhip();
    let hitX = muzzleX, hitY = muzzleY;
    let latchedTerrain = false;
    let hookedEnemy = null;
    let hookedBarrel = null;

    for (let d = 12; d <= 480; d += 4) {
      const rx = muzzleX + dirX * d;
      const ry = muzzleY + dirY * d;
      if (ry >= WATER_Y - 6 || rx < 20 || rx > TERRAIN_W - 20) break;

      for (const f of fighters) {
        if (f !== activeFighter && f.alive && !f.drowning && Math.hypot(f.x - rx, (f.y - 4) - ry) <= f.r + 8) {
          hookedEnemy = f;
          hitX = f.x;
          hitY = f.y - 4;
          break;
        }
      }
      if (hookedEnemy) break;

      for (const b of barrels) {
        if (Math.hypot(b.x - rx, b.y - ry) <= b.r + 6) {
          hookedBarrel = b;
          hitX = b.x;
          hitY = b.y;
          break;
        }
      }
      if (hookedBarrel) break;

      if (isSolid(rx, ry)) {
        latchedTerrain = true;
        hitX = rx;
        hitY = ry;
        break;
      }
    }

    if (hookedEnemy) {
      // Yank the enemy toward the shepherd's crook and deal impact damage!
      damageFighter(hookedEnemy, effDmg, '¡GANXADA DE PASTOR!');
      hookedEnemy.vx = -dirX * 360;
      hookedEnemy.vy = Math.min(-160, -dirY * 280 - 95);
      hookedEnemy.grounded = false;
      hookedEnemy.sliding = false;
      hookedEnemy.wasBlasted = true;
      hookedEnemy.dizzyTimer = 2.0;
      impactCam.active = true;
      impactCam.x = hookedEnemy.x;
      impactCam.y = hookedEnemy.y;
      impactCam.trackedWorm = hookedEnemy;
      particles.push({
        isBeam: true,
        x1: muzzleX, y1: muzzleY,
        x2: hitX, y2: hitY,
        life: 0.32,
        decay: 1.0
      });
      turnPhase = 'ACTION_WAIT';
    } else if (hookedBarrel) {
      hookedBarrel.vx = -dirX * 310;
      hookedBarrel.vy = -170;
      hookedBarrel.grounded = false;
      particles.push({
        isBeam: true,
        x1: muzzleX, y1: muzzleY,
        x2: hitX, y2: hitY,
        life: 0.32,
        decay: 1.0
      });
      turnPhase = 'RETREAT';
      phaseTimer = 2.4;
    } else if (latchedTerrain) {
      // Carve a small foothold pocket at the latch point so the caterpillar can stand on steep cliffs!
      carveCrater(hitX - dirX * 10, hitY - dirY * 10, 15);
      activeFighter.grapple = {
        startX: activeFighter.x,
        startY: activeFighter.y,
        targetX: clamp(hitX - dirX * 14, 28, TERRAIN_W - 28),
        targetY: clamp(hitY - dirY * 14, 42, WATER_Y - 28),
        hookX: hitX,
        hookY: hitY,
        progress: 0
      };
      activeFighter.grounded = false;
      activeFighter.sliding = false;
      activeFighter.isVoluntaryJump = true;
      activeFighter.wasBlasted = false;
      floatingTexts.push({
        x: activeFighter.x,
        y: activeFighter.y - 30,
        text: '¡GANXO DE PASTOR! ¡AMUNT!',
        color: '#ffe082',
        life: 1.55
      });
      turnPhase = 'ACTION_WAIT';
    } else {
      // Missed grapple shot
      particles.push({
        isBeam: true,
        x1: muzzleX, y1: muzzleY,
        x2: muzzleX + dirX * 260, y2: muzzleY + dirY * 260,
        life: 0.22,
        decay: 1.0
      });
      floatingTexts.push({
        x: activeFighter.x,
        y: activeFighter.y - 26,
        text: '¡GANXO CURT!',
        color: '#cbd5e1',
        life: 1.2
      });
      turnPhase = 'RETREAT';
      phaseTimer = 2.0;
    }
  }
}

// ═══════════════════════════════════════════════════════════════════════════
//  7. PHYSICS STEP (MULTI-SEGMENT CATERPILLAR UNDULATION, SLAM & SLIDING)
// ═══════════════════════════════════════════════════════════════════════════
function updateOrugaSegments(f, dt) {
  // Updates the 6 furry trailing segments so they follow the head like a real Oruga Procesionaria!
  if (!f.segs || f.segs.length === 0) return;
  let leadX = f.x;
  let leadY = f.y + 3;
  const segSpacing = 5.0;

  for (let i = 0; i < f.segs.length; i++) {
    const seg = f.segs[i];
    const targetX = leadX - f.facing * segSpacing;
    const wave = f.grounded && !f.sliding
      ? Math.sin(f.walkCycle * 1.35 - i * 0.95) * 2.2
      : Math.sin(tNow * 14 - i * 0.8) * 1.5;

    seg.x = lerp(seg.x, targetX, Math.min(1, dt * (18 - i * 1.4)));
    let desiredY = leadY + wave * 0.45;

    // Terrain hug for grounded caterpillar segments
    if (f.grounded && !f.drowning) {
      for (let dy = -6; dy <= 8; dy++) {
        if (!isSolid(seg.x, f.y + dy) && isSolid(seg.x, f.y + 10 + dy)) {
          desiredY = f.y + 3 + dy + Math.min(0, wave);
          break;
        }
      }
    }
    seg.y = lerp(seg.y, desiredY, Math.min(1, dt * 16));
    leadX = seg.x;
    leadY = seg.y;
  }
}

function stepPhysics(dt) {
  const SUBS = 4;
  const sdt = dt / SUBS;
  const mapSlideFriction = MAPS[currentMapIdx].slideFriction;

  for (let i = airstrikePlanes.length - 1; i >= 0; i--) {
    const pl = airstrikePlanes[i];
    pl.x += pl.vx * dt;
    for (let k = 0; k < 5; k++) {
      if (!pl.dropped[k]) {
        const dropX = pl.targetX + pl.offsets[k];
        if ((pl.vx > 0 && pl.x >= dropX) || (pl.vx < 0 && pl.x <= dropX)) {
          pl.dropped[k] = true;
          SND.fireBazooka();
          projectiles.push({
            type: 'BAZOOKA',
            x: pl.x,
            y: pl.y + 14,
            vx: pl.vx * 0.22,
            vy: 140,
            r: 5,
            windFactor: 0.4,
            bounces: false,
            blastR: 42,
            maxDmg: 38,
            knockback: 390,
            age: 0
          });
        }
      }
    }
    if (Math.abs(pl.x - pl.targetX) > 820 || pl.x < -300 || pl.x > TERRAIN_W + 300) {
      airstrikePlanes.splice(i, 1);
    }
  }

  for (let i = crates.length - 1; i >= 0; i--) {
    const c = crates[i];
    if (!c.grounded) {
      if (c.parachuting) {
        c.vx = lerp(c.vx, wind * 0.45, dt * 3);
        c.vy = 62;
      } else {
        c.vy += GRAVITY * dt;
      }
      c.x += c.vx * dt;
      c.y += c.vy * dt;

      if (c.y >= WATER_Y) {
        SND.plunge();
        spawnWaterPlunge(c.x, WATER_Y, 0.7);
        crates.splice(i, 1);
        continue;
      }
      if (isSolid(c.x, c.y + 11)) {
        while (isSolid(c.x, c.y + 10) && c.y > 0) c.y--;
        c.vx = 0;
        c.vy = 0;
        c.parachuting = false;
        c.grounded = true;
        SND.bounce();
      }
    } else if (!isSolid(c.x, c.y + 13)) {
      c.grounded = false;
      c.parachuting = false;
    }

    for (const f of fighters) {
      if (f.alive && !f.drowning && Math.hypot(f.x - c.x, f.y - c.y) <= 24) {
        if (!c.grounded && !c.parachuting && c.vy > 140) {
          // A crate whose parachute was shot out drops hard on the worm's head before opening!
          damageFighter(f, 18, '¡CAIXA AL CAP!');
          f.squashX = 1.32;
          f.squashY = 0.68;
          SND.bounce();
          if (!f.alive) {
            crates.splice(i, 1);
            break;
          }
        }
        SND.cratePickup();
        if (c.isMedkit) {
          f.hp = Math.min(150, f.hp + 35);
          f.urticatingTicks = 0;
          floatingTexts.push({
            x: f.x, y: f.y - 28,
            text: '+35 PV ¡RESINA DE PI!',
            color: '#76e082',
            life: 1.65
          });
          updateHUD();
        } else {
          teamAmmo[f.team][c.rewardWpn] = (teamAmmo[f.team][c.rewardWpn] || 0) + 1;
          const wObj = WEAPONS.find(w => w.id === c.rewardWpn);
          floatingTexts.push({
            x: f.x, y: f.y - 28,
            text: `+1 ${wObj ? wObj.name.toUpperCase() : c.rewardWpn}!`,
            color: '#f6cf77',
            life: 1.65
          });
          buildWeaponBar();
        }
        crates.splice(i, 1);
        break;
      }
    }
  }

  for (let i = mines.length - 1; i >= 0; i--) {
    const m = mines[i];
    if (!m.grounded) {
      m.vy += GRAVITY * dt;
      m.x += m.vx * dt;
      m.y += m.vy * dt;
      if (m.y >= WATER_Y) {
        mines.splice(i, 1);
        continue;
      }
      if (isSolid(m.x, m.y + 5)) {
        while (isSolid(m.x, m.y + 4) && m.y > 0) m.y--;
        m.vx = 0; m.vy = 0; m.grounded = true;
      }
    } else if (!isSolid(m.x, m.y + 7)) {
      m.grounded = false;
    }

    if (!m.triggered) {
      for (const f of fighters) {
        if (f.alive && !f.drowning && Math.hypot(f.x - m.x, f.y - m.y) < 38) {
          m.triggered = true;
          m.beepTimer = 0;
          SND.mineBeep();
          floatingTexts.push({
            x: m.x, y: m.y - 18,
            text: '¡CLIC! MINA ARMADA!',
            color: '#ff6b5b',
            life: 1.2
          });
          break;
        }
      }
    } else {
      m.fuse -= dt;
      m.beepTimer -= dt;
      if (m.beepTimer <= 0) {
        m.beepTimer = Math.max(0.12, m.fuse * 0.28);
        SND.mineBeep();
      }
      if (m.fuse <= 0) {
        mines.splice(i, 1);
        triggerExplosion(m.x, m.y, 50, 48, 480, 0, false);
      }
    }
  }

  for (let i = projectiles.length - 1; i >= 0; i--) {
    const p = projectiles[i];
    p.age += dt;

    // Safeguard: clean up any projectile that flies far out of bounds or exceeds max lifetime so turns never hang
    if (p.age > 8.0 || p.x < -380 || p.x > TERRAIN_W + 380 || p.y > WATER_Y + 60) {
      projectiles.splice(i, 1);
      if (p.fuse !== undefined && p.x >= -100 && p.x <= TERRAIN_W + 100 && p.y < WATER_Y) {
        triggerExplosion(p.x, p.y, p.blastR, p.maxDmg, p.knockback, p.clusters || 0, !!p.isUrticating);
      }
      continue;
    }

    if (p.fuse !== undefined) {
      p.fuse -= dt;
      if (p.type === 'HOLY' && !p.choirPlayed && p.fuse <= 1.35) {
        p.choirPlayed = true;
        SND.hallelujah();
        floatingTexts.push({
          x: p.x, y: p.y - 24,
          text: '♪ VIROLAI! AL·LELUIA! ♪',
          color: '#f6cf77',
          life: 1.3
        });
      }
      const sec = Math.ceil(p.fuse);
      if (sec < p.lastSec && sec > 0) {
        p.lastSec = sec;
        SND.tick();
      }
      if (p.fuse <= 0) {
        if (p.type === 'DYNAMITE') {
          floatingTexts.push({
            x: p.x, y: p.y - 26,
            text: '¡CAGA TIÓ!',
            color: '#ffae42',
            life: 1.4
          });
        }
        projectiles.splice(i, 1);
        triggerExplosion(p.x, p.y, p.blastR, p.maxDmg, p.knockback, p.clusters || 0, !!p.isUrticating);
        continue;
      }
    }

    let exploded = false;
    for (let s = 0; s < SUBS; s++) {
      p.vx += (wind * 2.4 * (p.windFactor || 0)) * sdt;
      // Thermal Pine-Resin Updraft lift on projectiles!
      for (const u of updrafts) {
        if (Math.abs(p.x - u.x) < u.w && p.y < u.y && p.y > u.y - u.h) {
          p.vy -= 145 * sdt;
        }
      }
      p.vy += GRAVITY * sdt;
      p.x += p.vx * sdt;
      p.y += p.vy * sdt;
      if (p.ang !== undefined) p.ang += p.vx * 0.015 * sdt;

      if (p.y >= WATER_Y) {
        SND.plunge();
        spawnWaterPlunge(p.x, WATER_Y, 0.75);
        impactCam.active = true;
        impactCam.x = p.x;
        impactCam.y = WATER_Y - 24;
        projectiles.splice(i, 1);
        exploded = true;
        break;
      }

      // Check collision with Hanging Silk Nests ("Bolsones")!
      for (let ni = silkNests.length - 1; ni >= 0; ni--) {
        const nest = silkNests[ni];
        if (Math.hypot(p.x - nest.x, p.y - nest.y) <= nest.r + p.r + 2) {
          silkNests.splice(ni, 1);
          burstSilkNest(nest);
          projectiles.splice(i, 1);
          triggerExplosion(p.x, p.y, p.blastR * 0.75, p.maxDmg, p.knockback, p.clusters || 0, !!p.isUrticating);
          exploded = true;
          break;
        }
      }
      if (exploded) break;

      // Snipable Crate Parachutes: shooting the silk parachute above a falling crate drops it like a stone!
      for (const c of crates) {
        if (c.parachuting && Math.hypot(p.x - c.x, p.y - (c.y - 20)) <= 18) {
          c.parachuting = false;
          SND.carquinyoliCrunch();
          spawnUrticatingHairs(c.x, c.y - 18, 10);
          floatingTexts.push({
            x: c.x,
            y: c.y - 30,
            text: '¡PARACAIGUDES TRENCAT!',
            color: '#ff9e44',
            life: 1.5
          });
        }
      }

      // Check elastic ricochet off Spun Silk Webs ("Seda Elástica")!
      if (p.age > 0.08) {
        for (let wi = silkWebs.length - 1; wi >= 0; wi--) {
          const w = silkWebs[wi];
          const dxW = w.x2 - w.x1, dyW = w.y2 - w.y1;
          const lenSq = dxW * dxW + dyW * dyW;
          if (lenSq > 1) {
            const tProj = clamp(((p.x - w.x1) * dxW + (p.y - w.y1) * dyW) / lenSq, 0, 1);
            const closeX = w.x1 + tProj * dxW, closeY = w.y1 + tProj * dyW;
            const distW = Math.hypot(p.x - closeX, p.y - closeY);
            if (distW <= p.r + 5 && (p._lastWebBounce || 0) < p.age - 0.12) {
              const len = Math.sqrt(lenSq);
              let nx = -dyW / len, ny = dxW / len;
              if (p.vx * nx + p.vy * ny > 0) { nx = -nx; ny = -ny; }
              const vn = p.vx * nx + p.vy * ny;
              p.vx = (p.vx - 2 * vn * nx) * 0.92;
              p.vy = (p.vy - 2 * vn * ny) * 0.92;
              p._lastWebBounce = p.age;
              w.vibration = 1.0;
              w.hp--;
              SND.bounce();
              floatingTexts.push({
                x: closeX, y: closeY - 12,
                text: '¡REBOT EN SEDA!',
                color: '#fff6df',
                life: 1.1
              });
              if (w.hp <= 0) silkWebs.splice(wi, 1);
              break;
            }
          }
        }
      }

      if (p.age > 0.06) {
        for (const f of fighters) {
          if (f.alive && !f.drowning && Math.hypot(f.x - p.x, (f.y - 4) - p.y) <= f.r + p.r) {
            if (!p.bounces) {
              projectiles.splice(i, 1);
              triggerExplosion(p.x, p.y, p.blastR, p.maxDmg, p.knockback, 0, !!p.isUrticating);
              exploded = true;
              break;
            } else if (p.type === 'CARQUINYOLI' && (p._lastFighterHit || 0) < p.age - 0.16) {
              p._lastFighterHit = p.age;
              SND.carquinyoliCrunch();
              damageFighter(f, 12, '¡CREC! TRENCADENTS!');
              f.vx += Math.sign(p.vx || 1) * 165;
              f.vy = Math.min(f.vy, -110);
              f.grounded = false;
              f.wasBlasted = true;
              f.peakAirY = f.y;
              f.squashX = 0.72;
              f.squashY = 1.35;
              impactCam.active = true;
              impactCam.x = f.x;
              impactCam.y = f.y;
              impactCam.trackedWorm = f;
              spawnSparks(p.x, p.y, 10);
              p.vx = -p.vx * 0.65;
              p.vy = -Math.abs(p.vy) * 0.65 - 60;
              break;
            }
          }
        }
        if (exploded) break;
      }

      if (isSolid(p.x, p.y)) {
        if (!p.bounces) {
          projectiles.splice(i, 1);
          triggerExplosion(p.x, p.y, p.blastR, p.maxDmg, p.knockback, p.clusters || 0, !!p.isUrticating);
          exploded = true;
          break;
        } else {
          p.x -= p.vx * sdt;
          p.y -= p.vy * sdt;
          if (p.type === 'CARQUINYOLI' && p.bouncesLeft !== undefined) {
            p.bouncesLeft--;
            SND.carquinyoliCrunch();
            spawnRockDebris(p.x, p.y, 5);
            if (p.bouncesLeft <= 0) {
              projectiles.splice(i, 1);
              triggerExplosion(p.x, p.y, p.blastR, p.maxDmg, p.knockback, 0, false);
              exploded = true;
              break;
            }
          }
          const n = getSurfaceNormal(p.x, p.y);
          const vn = p.vx * n.x + p.vy * n.y;
          if (vn < 0) {
            const restitution = p.type === 'CARQUINYOLI' ? 0.82 : (p.type === 'DYNAMITE' ? 0.15 : (p.type === 'HOLY' ? 0.42 : 0.62));
            const friction = p.type === 'CARQUINYOLI' ? 0.94 : (p.type === 'DYNAMITE' ? 0.35 : 0.88);
            const tx = -n.y, ty = n.x;
            const vt = p.vx * tx + p.vy * ty;
            p.vx = (-vn * restitution) * n.x + (vt * friction) * tx;
            p.vy = (-vn * restitution) * n.y + (vt * friction) * ty;
            if (Math.abs(vn) > 65 && p.type !== 'CARQUINYOLI') SND.bounce();
          }
        }
      }
    }

    if (!exploded) {
      if (!p.trail) p.trail = [];
      p.trail.push({ x: p.x, y: p.y });
      if (p.trail.length > 14) p.trail.shift();

      // Falling artillery whistle when a high-altitude shell plunges downward!
      if (!p._whistled && p.age > 0.45 && p.vy > 210 && p.y < WATER_Y - 120 && (p.type === 'BAZOOKA' || p.type === 'HOLY' || p.type === 'CLUSTER')) {
        p._whistled = true;
        SND.shellWhistle();
      }

      if ((p.type === 'BAZOOKA' || p.type === 'URTICARIA' || p.type === 'BOMBLER') && Math.random() < 0.72) {
        smokePuffs.push({
          x: p.x, y: p.y,
          vx: (Math.random() - 0.5) * 14,
          vy: (Math.random() - 0.5) * 14,
          r: p.type === 'BOMBLER' ? 3.5 : 4.8, vr: 14,
          life: 0.55, decay: 1.0,
          color: p.type === 'URTICARIA' ? 'rgba(200, 120, 255, 0.55)' : (p.type === 'BOMBLER' ? 'rgba(255, 145, 55, 0.55)' : 'rgba(225, 215, 200, 0.45)')
        });
      } else if (p.type === 'HOLY' && Math.random() < 0.75) {
        // Sacred Porró sheds golden halo sparkles & ruby wine droplets in flight!
        particles.push({
          x: p.x + (Math.random() - 0.5) * 8,
          y: p.y + (Math.random() - 0.5) * 8,
          vx: -p.vx * 0.1 + (Math.random() - 0.5) * 30,
          vy: -20 + (Math.random() - 0.5) * 30,
          w: 2.8, h: 2.8, rot: 0, vrot: 0,
          life: 0.55, decay: 1.2,
          color: Math.random() < 0.65 ? '#ffe57f' : '#d92626',
          isSpark: true
        });
      } else if (p.type === 'CARQUINYOLI' && Math.random() < 0.45) {
        // Spinning Carquinyoli sheds toasted almond & biscuit crumbs!
        particles.push({
          x: p.x, y: p.y,
          vx: (Math.random() - 0.5) * 40,
          vy: -15 + Math.random() * 25,
          w: 2.4, h: 2.4, rot: Math.random() * 6, vrot: 8,
          life: 0.5, decay: 1.3,
          color: Math.random() < 0.5 ? '#fff5df' : '#c87d32',
          isSpark: false
        });
      }
    }
  }

  // Update Hanging Silk Nests ("Bolsones Vivos") with spring-damped pendulum physics + wind force
  for (const nest of silkNests) {
    const windTorque = (wind * 0.0045 + Math.sin(tNow * 2.4 + nest.swayPhase) * (0.14 + Math.abs(wind) * 0.002));
    nest.swingVel = ((nest.swingVel || 0) + (windTorque - (nest.swingAngle || 0) * 6.5) * dt) * Math.pow(0.28, dt);
    nest.swingAngle = clamp((nest.swingAngle || 0) + nest.swingVel * dt, -0.95, 0.95);
    const ropeLen = 28;
    nest.x = nest.anchorX + Math.sin(nest.swingAngle) * ropeLen;
    nest.y = nest.anchorY + Math.cos(nest.swingAngle) * ropeLen;
  }

  // Decay Silk Web vibrations
  for (const w of silkWebs) {
    if (w.vibration > 0) w.vibration = Math.max(0, w.vibration - dt * 2.2);
  }

  // Update Giant Bouncy Catalan Rovelló Mushrooms (spring recovery & terrain support)
  for (let i = rovellons.length - 1; i >= 0; i--) {
    const rv = rovellons[i];
    rv.squash = lerp(rv.squash, 1.0, Math.min(1, dt * 9));
    if (!isSolid(rv.x, rv.y + 3)) {
      rv.y += 140 * dt;
      if (rv.y >= WATER_Y) {
        rovellons.splice(i, 1);
      }
    }
  }

  // Update Hidden Lucky Caganer Figurines ("Caganer de la Sort")
  for (let i = caganers.length - 1; i >= 0; i--) {
    const cg = caganers[i];
    if (!isSolid(cg.x, cg.y + 10)) {
      cg.y += 140 * dt;
      if (cg.y >= WATER_Y) {
        caganers.splice(i, 1);
        continue;
      }
    }
    for (const f of fighters) {
      if (f.alive && !f.drowning && Math.hypot(f.x - cg.x, f.y - cg.y) <= f.r + cg.r + 10) {
        SND.caganerBlessing();
        f.hp = Math.min(160, f.hp + 30);
        f.urticatingTicks = 0;
        teamAmmo[f.team]['HOLY'] = (teamAmmo[f.team]['HOLY'] || 0) + 1;
        teamAmmo[f.team]['DYNAMITE'] = (teamAmmo[f.team]['DYNAMITE'] || 0) + 1;
        shockwaves.push({
          x: cg.x,
          y: cg.y,
          r: 5,
          maxR: 65,
          alpha: 1.0,
          color: '255, 215, 90'
        });
        spawnSparks(cg.x, cg.y, 18);
        spawnSpeechBubble(f, '¡El Caganer de la Sort!', 2.4);
        floatingTexts.push({
          x: cg.x,
          y: cg.y - 34,
          text: '¡BENEDICCIÓ DEL CAGANER! +30 PV I +1 PORRÓ!',
          color: '#ffd966',
          life: 2.2
        });
        updateHUD();
        buildWeaponBar();
        caganers.splice(i, 1);
        break;
      }
    }
  }

  // Update Simmering Cast-Iron "Olles d'Escudella i Carn d'Olla" Soup Cauldrons!
  for (let i = escudelles.length - 1; i >= 0; i--) {
    const ol = escudelles[i];
    if (!isSolid(ol.x, ol.y + 13)) {
      ol.y += 140 * dt;
      if (ol.y >= WATER_Y) {
        escudelles.splice(i, 1);
        continue;
      }
    }
    // Emit aromatic broth steam wisps
    if (Math.random() < 0.18) {
      smokePuffs.push({
        x: ol.x + (Math.random() - 0.5) * 10,
        y: ol.y - 10,
        vx: wind * 0.15 + (Math.random() - 0.5) * 8,
        vy: -28 - Math.random() * 18,
        r: 4, vr: 8,
        life: 0.75, decay: 0.9,
        color: 'rgba(255, 248, 232, 0.35)'
      });
    }
    for (const f of fighters) {
      if (f.alive && !f.drowning && Math.hypot(f.x - ol.x, f.y - ol.y) <= f.r + ol.r + 8) {
        SND.cratePickup();
        f.hp = Math.min(165, f.hp + 25);
        f.pilotaBuff = true;
        f.urticatingTicks = 0;
        spawnSparks(ol.x, ol.y - 6, 14);
        spawnSpeechBubble(f, '¡Quina Escudella més bona!', 2.3);
        floatingTexts.push({
          x: ol.x,
          y: ol.y - 32,
          text: '+25 PV ¡FORÇA DE LA PILOTA! (+25% DANY)',
          color: '#ffd966',
          life: 2.1
        });
        updateHUD();
        escudelles.splice(i, 1);
        break;
      }
    }
  }

  // Update Golden Pine Nuts ("Pinyons Daurats") dropped from burst Silk Nests!
  for (let i = pineNuts.length - 1; i >= 0; i--) {
    const pn = pineNuts[i];
    pn.life -= dt;
    if (pn.life <= 0 || pn.y >= WATER_Y) {
      pineNuts.splice(i, 1);
      continue;
    }
    if (!pn.grounded) {
      pn.vy += GRAVITY * dt;
      pn.x += pn.vx * dt;
      pn.y += pn.vy * dt;
      if (isSolid(pn.x, pn.y + pn.r)) {
        while (isSolid(pn.x, pn.y + pn.r - 1) && pn.y > 0) pn.y--;
        pn.vy = -pn.vy * 0.38;
        pn.vx *= 0.65;
        if (Math.abs(pn.vy) < 22) { pn.vy = 0; pn.vx = 0; pn.grounded = true; }
      }
    } else if (!isSolid(pn.x, pn.y + pn.r + 2)) {
      pn.grounded = false;
    }

    for (const f of fighters) {
      if (f.alive && !f.drowning && Math.hypot(f.x - pn.x, f.y - pn.y) <= f.r + pn.r + 6) {
        SND.cratePickup();
        f.maxHp = Math.min(160, f.maxHp + 15);
        f.hp = Math.min(f.maxHp, f.hp + 20);
        f.urticatingTicks = 0;
        floatingTexts.push({
          x: f.x, y: f.y - 30,
          text: '+20 PV ¡PINYÓ DAURAT!',
          color: '#ffe082',
          life: 1.75
        });
        updateHUD();
        pineNuts.splice(i, 1);
        break;
      }
    }
  }

  // Update Angry Micro-Larvae Swarms released from burst Silk Nests!
  for (let i = larvaeSwarms.length - 1; i >= 0; i--) {
    const sw = larvaeSwarms[i];
    sw.life -= dt;
    if (sw.life <= 0 || sw.y >= WATER_Y) {
      larvaeSwarms.splice(i, 1);
      continue;
    }
    // Seek nearest alive fighter
    let nearest = null, bestD = Infinity;
    for (const f of fighters) {
      if (f.alive && !f.drowning) {
        const d = Math.hypot(f.x - sw.x, f.y - sw.y);
        if (d < bestD) { bestD = d; nearest = f; }
      }
    }
    if (nearest) {
      const dir = Math.sign(nearest.x - sw.x);
      sw.vx = lerp(sw.vx, dir * 88, dt * 5);
    }
    if (!isSolid(sw.x, sw.y + 5)) {
      sw.vy = Math.min(260, sw.vy + GRAVITY * dt);
    } else {
      while (isSolid(sw.x, sw.y + 4) && sw.y > 0) sw.y--;
      sw.vy = -55; // Hopping micro-larvae!
    }
    sw.x += sw.vx * dt;
    sw.y += sw.vy * dt;

    sw.tickTimer -= dt;
    if (sw.tickTimer <= 0 && nearest && bestD < 22) {
      sw.tickTimer = 0.65;
      damageFighter(nearest, 4, '¡LARVES!');
      nearest.squashX = 1.18;
      nearest.squashY = 0.85;
      nearest.hurtTimer = 0.35;
      spawnUrticatingHairs(nearest.x, nearest.y, 4);
    }
  }

  for (let i = barrels.length - 1; i >= 0; i--) {
    const b = barrels[i];
    if (!b.grounded) {
      b.vy += GRAVITY * dt;
      b.x += b.vx * dt;
      b.y += b.vy * dt;
      if (b.y >= WATER_Y) {
        SND.plunge();
        spawnWaterPlunge(b.x, WATER_Y, 0.8);
        barrels.splice(i, 1);
        continue;
      }
      if (isSolid(b.x, b.y + b.r)) {
        while (isSolid(b.x, b.y + b.r - 1) && b.y > 0) b.y--;
        b.vy = 0;
        b.vx *= 0.4;
        if (Math.abs(b.vx) < 5) { b.vx = 0; b.grounded = true; }
      }
    } else if (!isSolid(b.x, b.y + b.r + 2)) {
      b.grounded = false;
    }
  }

  for (const tb of tombstones) {
    if (!isSolid(tb.x, tb.y + 10)) {
      tb.vy = Math.min(350, (tb.vy || 0) + GRAVITY * dt);
      tb.y += tb.vy * dt;
      if (isSolid(tb.x, tb.y + 10)) {
        while (isSolid(tb.x, tb.y + 9) && tb.y > 0) tb.y--;
        tb.vy = -tb.vy * 0.25;
        if (Math.abs(tb.vy) < 15) tb.vy = 0;
      }
    }
  }

  const canControl = appStage === 'PLAYING' &&
                     (turnPhase === 'TURN_PLAY' || turnPhase === 'RETREAT') &&
                     activeFighter && activeFighter.alive && !activeFighter.drowning && !isCurrentTurnAI();

  // Update Nose-to-Tail Procession Links ("Modo Procesión") & Vertical "Castell de Cucs" Towers!
  for (const f of fighters) {
    if (!f.alive || f.drowning) {
      f.linkedAllies = [];
      f.castellTower = false;
      continue;
    }
    const prevCount = f.linkedAllies ? f.linkedAllies.length : 0;
    f.linkedAllies = fighters.filter(other =>
      other !== f &&
      other.team === f.team &&
      other.alive &&
      !other.drowning &&
      Math.hypot(other.x - f.x, other.y - f.y) <= 52
    );
    if (f === activeFighter && f.linkedAllies.length > prevCount && appStage === 'PLAYING') {
      const msg = ORUGA_TAUNTS.PROCESSION[Math.floor(Math.random() * ORUGA_TAUNTS.PROCESSION.length)];
      spawnSpeechBubble(f, msg, 2.0);
    }

    // SURPRISE 3: Check if this Cuc is stacked atop an allied Cuc ("Castell de Cucs" / Enxaneta!)
    const wasCastell = !!f.castellTower;
    const baseAlly = fighters.find(other =>
      other !== f &&
      other.team === f.team &&
      other.alive &&
      !other.drowning &&
      Math.abs(other.x - f.x) <= 20 &&
      f.y < other.y - 4 &&
      (other.y - f.y) <= 34
    );
    f.castellTower = !!baseAlly;
    if (f.castellTower && !wasCastell && appStage === 'PLAYING') {
      SND.caganerBlessing();
      spawnSpeechBubble(f, '¡Castell de Cucs! ¡Aleta!', 2.4);
      floatingTexts.push({
        x: f.x,
        y: f.y - 38,
        text: '¡CASTELL DE CUCS! +30% FORÇA ENXANETA!',
        color: '#ffd966',
        life: 1.9
      });
    }
  }

  for (const f of fighters) {
    if (!f.alive) continue;

    f.squashX = lerp(f.squashX, 1.0, Math.min(1, dt * 11));
    f.squashY = lerp(f.squashY, 1.0, Math.min(1, dt * 11));
    if (f.hurtTimer > 0) f.hurtTimer = Math.max(0, f.hurtTimer - dt);
    if (f.dizzyTimer > 0) f.dizzyTimer = Math.max(0, f.dizzyTimer - dt);
    if (f.batSwingTimer > 0) f.batSwingTimer = Math.max(0, f.batSwingTimer - dt);

    if (f.drowning) {
      f.drownTimer -= dt;
      f.vx *= 0.92;
      f.vy = 42;
      f.x += f.vx * dt;
      f.y += f.vy * dt;
      f.walkCycle += dt * 18;
      updateOrugaSegments(f, dt);

      if (Math.random() < 0.48) {
        bubbles.push({
          x: f.x + (Math.random() - 0.5) * 14,
          y: f.y - 6,
          r: 2 + Math.random() * 3.5,
          vy: -45 - Math.random() * 35,
          wobble: Math.random() * Math.PI * 2
        });
      }

      if (f.drownTimer <= 0 || f.y > TERRAIN_H + 35) {
        f.alive = false;
        f.drowning = false;
        updateHUD();
      }
      continue;
    }

    // ACTIVE TOOL 1: Cullera de Fusta de Boix (Wooden Spoon Bulldozer / Terrain Scooper!)
    if (f.spoonTimer > 0) {
      f.spoonTimer = Math.max(0, f.spoonTimer - dt);
      f.spoonTick = (f.spoonTick || 0) - dt;
      // Allow live gentle steering of the spoon angle while scooping!
      if (f === activeFighter && !isCurrentTurnAI()) {
        if (keys.up) f.spoonAngle -= 0.9 * dt * f.facing;
        if (keys.down) f.spoonAngle += 0.9 * dt * f.facing;
      }
      const sDirX = Math.cos(f.spoonAngle || 0);
      const sDirY = Math.sin(f.spoonAngle || 0);
      f.facing = sDirX >= 0 ? 1 : -1;
      f.walkCycle += dt * 22;

      const nextX = clamp(f.x + sDirX * 64 * dt, 28, TERRAIN_W - 28);
      const nextY = clamp(f.y + sDirY * 42 * dt, 38, WATER_Y - 18);
      f.x = nextX;
      f.y = nextY;
      f.jumpStartY = f.y;
      f.peakAirY = f.y;
      f.grounded = isSolid(f.x, f.y + f.r + 2);
      impactCam.active = true;
      impactCam.x = f.x;
      impactCam.y = f.y;
      impactCam.trackedWorm = f;

      if (f.spoonTick <= 0) {
        f.spoonTick = 0.085;
        SND.spoonScoop();
        const scoopX = f.x + sDirX * 15;
        const scoopY = f.y - 2 + sDirY * 10;
        carveCrater(scoopX, scoopY, 19);
        spawnRockDebris(scoopX, scoopY, 4);
        // Fling any enemy or barrel caught in front of the giant wooden spoon!
        for (const other of fighters) {
          if (other !== f && other.alive && !other.drowning && Math.hypot(other.x - scoopX, other.y - scoopY) <= 28) {
            damageFighter(other, 14, '¡CULLERADA!');
            other.vx = sDirX * 320;
            other.vy = -210;
            other.grounded = false;
            other.wasBlasted = true;
            other.jumpStartY = other.y;
            other.peakAirY = other.y;
          }
        }
        for (const b of barrels) {
          if (Math.hypot(b.x - scoopX, b.y - scoopY) <= 28) {
            b.vx = sDirX * 280;
            b.vy = -190;
            b.grounded = false;
          }
        }
      }
      updateOrugaSegments(f, dt);
      if (f.spoonTimer <= 0 && turnPhase === 'ACTION_WAIT') {
        turnPhase = 'RETREAT';
        phaseTimer = 1.8;
      }
      continue;
    }

    // ACTIVE TOOL 2: Barrina de Pedrera (Pneumatic Catalan Quarry Jackhammer / Rock Drill!)
    if (f.drillTimer > 0) {
      f.drillTimer = Math.max(0, f.drillTimer - dt);
      f.drillTick = (f.drillTick || 0) - dt;
      const dDirX = Math.cos(f.drillAngle || (Math.PI * 0.5));
      const dDirY = Math.max(0.25, Math.sin(f.drillAngle || (Math.PI * 0.5)));
      f.facing = dDirX >= 0 ? 1 : -1;
      f.squashX = 1.0 + Math.sin(tNow * 55) * 0.12;
      f.squashY = 1.0 - Math.sin(tNow * 55) * 0.12;
      shake = Math.max(shake, 3.5);

      f.x = clamp(f.x + dDirX * 52 * dt, 28, TERRAIN_W - 28);
      f.y = clamp(f.y + dDirY * 56 * dt, 38, WATER_Y - 22);
      f.jumpStartY = f.y;
      f.peakAirY = f.y;
      f.grounded = isSolid(f.x, f.y + f.r + 2);
      impactCam.active = true;
      impactCam.x = f.x;
      impactCam.y = f.y;
      impactCam.trackedWorm = f;

      if (f.drillTick <= 0) {
        f.drillTick = 0.08;
        SND.drillBore();
        const bitX = f.x + dDirX * 14;
        const bitY = f.y + dDirY * 14;
        carveCrater(bitX, bitY, 16);
        spawnSparks(bitX, bitY, 4);
        spawnRockDebris(bitX, bitY, 3);
        for (const other of fighters) {
          if (other !== f && other.alive && !other.drowning && Math.hypot(other.x - bitX, other.y - bitY) <= 26) {
            damageFighter(other, 7, '¡BARRINA!');
            other.vx = (dDirX || 0.4) * 160;
            other.vy = -120;
            other.grounded = false;
          }
        }
      }
      updateOrugaSegments(f, dt);
      if (f.drillTimer <= 0 && turnPhase === 'ACTION_WAIT') {
        turnPhase = 'RETREAT';
        phaseTimer = 1.8;
      }
      continue;
    }

    // ACTIVE TOOL 4: Ganxo de Pastor (Pyrenean Shepherd's Crook Grapple Zip!)
    if (f.grapple) {
      f.grapple.progress = Math.min(1, f.grapple.progress + dt * 2.6);
      const ease = 1 - Math.pow(1 - f.grapple.progress, 2.2);
      f.x = lerp(f.grapple.startX, f.grapple.targetX, ease);
      f.y = lerp(f.grapple.startY, f.grapple.targetY, ease) - Math.sin(f.grapple.progress * Math.PI) * 18;
      f.vx = 0;
      f.vy = 0;
      f.jumpStartY = f.y;
      f.peakAirY = f.y;
      f.isVoluntaryJump = true;
      f.wasBlasted = false;
      impactCam.active = true;
      impactCam.x = f.x;
      impactCam.y = f.y;
      impactCam.trackedWorm = f;
      updateOrugaSegments(f, dt);

      if (f.grapple.progress >= 1) {
        f.grapple = null;
        f.grounded = isSolid(f.x, f.y + f.r + 2);
        SND.jump();
        if (turnPhase === 'ACTION_WAIT') {
          turnPhase = 'RETREAT';
          phaseTimer = 2.4;
        }
      }
      continue;
    }

    if (f.grounded && !isSolid(f.x, f.y + f.r + 2) && !isSolid(f.x - 4, f.y + f.r + 2) && !isSolid(f.x + 4, f.y + f.r + 2)) {
      f.grounded = false;
      f.sliding = false;
      f.slideAngle = 0;
      f.jumpStartY = f.y;
      f.peakAirY = f.y;
      f.isVoluntaryJump = false;
    }

    if (f.grounded && !f.sliding) {
      f.vx = 0;
      f.vy = 0;
      f.slideTimer = 0;
      f.airTimer = 0;
      f.peakAirY = f.y;
    }

    if (f === activeFighter && f.jetFuel > 0 && canControl) {
      let thrusting = false;
      if (keys.up) {
        f.vy = Math.max(-240, f.vy - 760 * dt);
        thrusting = true;
      }
      if (keys.left) {
        f.vx = Math.max(-190, f.vx - 420 * dt);
        f.facing = -1;
        thrusting = true;
      }
      if (keys.right) {
        f.vx = Math.min(190, f.vx + 420 * dt);
        f.facing = 1;
        thrusting = true;
      }
      if (thrusting) {
        f.grounded = false;
        f.isVoluntaryJump = true;
        f.jumpStartY = f.y;
        f.peakAirY = f.y;
        f.jetFuel = Math.max(0, f.jetFuel - 28 * dt);
        SND.jetThrust();
        if (Math.random() < 0.75) {
          particles.push({
            x: f.x - f.facing * 7 + (Math.random() - 0.5) * 4,
            y: f.y + 4,
            vx: (Math.random() - 0.5) * 35,
            vy: 90 + Math.random() * 60,
            w: 3, h: 3, rot: 0, vrot: 0,
            life: 0.35, decay: 1.4,
            color: Math.random() > 0.4 ? '#ffae42' : '#ff4e22',
            isSpark: true
          });
        }
      }
    }

    if (f === activeFighter && f.grounded && !f.sliding && (canControl || (isCurrentTurnAI() && aiPlan && aiPlan.walkDir !== 0))) {
      let moveDir = 0;
      if (canControl) {
        if (keys.left) moveDir = -1;
        else if (keys.right) moveDir = 1;
      } else if (aiPlan) {
        moveDir = aiPlan.walkDir;
      }

      if (moveDir !== 0 && !isCharging) {
        if (canControl) hasActedOrMovedThisTurn = true;
        if (f.facing !== moveDir) {
          f.facing = moveDir;
          if (!isCurrentTurnAI()) syncAimAngleFromPitch();
        }
        f.walkCycle += dt * 12;
        SND.crawlStep();
        const stepX = clamp(f.x + moveDir * 78 * dt, 30, TERRAIN_W - 30);
        let foundY = null;
        for (let dy = -9; dy <= 10; dy++) {
          if (!isSolid(stepX, f.y + dy) && isSolid(stepX, f.y + f.r + dy)) {
            foundY = f.y + dy;
            break;
          }
        }
        if (foundY !== null) {
          f.x = stepX;
          f.y = foundY;
          f.jumpStartY = f.y;
          f.peakAirY = f.y;
        } else if (!isSolid(stepX, f.y)) {
          f.x = stepX;
          f.grounded = false;
          f.jumpStartY = f.y;
          f.peakAirY = f.y;
          f.isVoluntaryJump = false;
        }

        // Nose-to-Tail Procession Convoy March: linked allied caterpillars crawl right behind the leader!
        if (processionConvoyEnabled && f.linkedAllies && f.linkedAllies.length > 0) {
          let leaderX = f.x;
          for (const ally of f.linkedAllies) {
            if (!ally.grounded || ally.sliding) continue;
            const desiredX = leaderX - moveDir * 30;
            const diffX = desiredX - ally.x;
            if (Math.abs(diffX) > 4) {
              const allyStepX = ally.x + Math.sign(diffX) * Math.min(Math.abs(diffX), 74 * dt);
              ally.facing = moveDir;
              ally.walkCycle += dt * 12;
              for (let dy = -9; dy <= 10; dy++) {
                if (!isSolid(allyStepX, ally.y + dy) && isSolid(allyStepX, ally.y + ally.r + dy)) {
                  ally.x = allyStepX;
                  ally.y = ally.y + dy;
                  break;
                }
              }
            }
            leaderX = ally.x;
          }
        }
      }
    }

    if (f.grounded && f.sliding) {
      f.slideTimer = (f.slideTimer || 0) + dt;
      // Minor slides (from a small drop) brake smoothly in ~0.35s so the player can keep moving afterward!
      const frictionBase = f.isMinorSlide ? 0.90 : mapSlideFriction;
      f.vx *= Math.pow(frictionBase, dt * 60);
      const stepX = clamp(f.x + f.vx * dt, 24, TERRAIN_W - 24);
      f.facing = f.vx >= 0 ? 1 : -1;

      let foundSlopeY = null;
      for (let dy = -10; dy <= 12; dy++) {
        if (!isSolid(stepX, f.y + dy) && isSolid(stepX, f.y + f.r + dy)) {
          foundSlopeY = f.y + dy;
          break;
        }
      }

      if (foundSlopeY !== null) {
        const dySlope = foundSlopeY - f.y;
        f.x = stepX;
        f.y = foundSlopeY;
        f.vx += dySlope * (f.isMinorSlide ? 10 : 18) * dt; // Downhill accelerates slide, uphill decelerates slide!
        f.slideAngle = clamp(dySlope * 0.12, -0.5, 0.5);

        const speed = Math.abs(f.vx);
        if (speed > 26) {
          SND.skid(speed);
          if (Math.random() < 0.65) {
            smokePuffs.push({
              x: f.x - f.facing * 8,
              y: f.y + f.r - 2,
              vx: -f.vx * 0.25 + (Math.random() - 0.5) * 20,
              vy: -15 - Math.random() * 25,
              r: 4 + Math.random() * 5,
              vr: 10,
              life: 0.45,
              decay: 1.2,
              color: 'rgba(155, 132, 108, 0.48)'
            });
          }
        }
      } else if (!isSolid(stepX, f.y)) {
        f.x = stepX;
        f.grounded = false;
        f.sliding = false;
        f.isMinorSlide = false;
        f.slideAngle = 0;
        f.jumpStartY = f.y;
        f.peakAirY = f.y;
        f.isVoluntaryJump = false;
      } else {
        f.vx = -f.vx * 0.4;
      }

      const maxSlideDur = f.isMinorSlide ? 0.42 : 2.2;
      const stopSpeed = f.isMinorSlide ? 24 : 18;
      if (Math.abs(f.vx) < stopSpeed || f.slideTimer > maxSlideDur) {
        f.vx = 0;
        f.vy = 0;
        f.sliding = false;
        f.isMinorSlide = false;
        f.slideAngle = 0;
        f.slideTimer = 0;
        f.squashX = 0.88;
        f.squashY = 1.14;
        if (f === activeFighter && !isCurrentTurnAI()) {
          syncAimAngleFromPitch();
        }
      }
    }

    if (!f.grounded) {
      f.airTimer = (f.airTimer || 0) + dt;
      f.peakAirY = Math.min(f.peakAirY ?? f.y, f.y);

      // Metamorphosed Thaumetopoea Moth Wing Glide when holding W / Space in mid-air!
      if (f.metamorphosed && f === activeFighter && canControl && keys.up && f.vy > 25) {
        f.vy = lerp(f.vy, 48, dt * 9);
        f.vx = lerp(f.vx, f.facing * 125 + wind * 0.55, dt * 3.5);
        f.jumpStartY = f.y; // Gliding cushions landing so it won't slam or slide!
        f.peakAirY = f.y;
        f.isVoluntaryJump = true;
      }

      // Thermal Pine-Resin Updraft lift on airborne caterpillars!
      for (const u of updrafts) {
        if (Math.abs(f.x - u.x) < u.w && f.y < u.y && f.y > u.y - u.h) {
          const lift = (f.metamorphosed && keys.up) ? 620 : 240;
          f.vy -= lift * dt;
        }
      }

      // Spin somersault during a Backwards Jump / Backflip!
      if (f.flipSpin) {
        f.flipAngle = (f.flipAngle || 0) + f.flipSpin * dt;
      }

      f.vy += GRAVITY * dt;
      const steps = 4;
      for (let s = 0; s < steps; s++) {
        f.x = clamp(f.x + (f.vx * dt) / steps, 18, TERRAIN_W - 18);
        f.y += (f.vy * dt) / steps;
        f.peakAirY = Math.min(f.peakAirY ?? f.y, f.y);

        // Check Elastic Silk Web Trampoline Bounce!
        if (f.vy > 0) {
          let bouncedOnWeb = false;
          for (let wi = silkWebs.length - 1; wi >= 0; wi--) {
            const w = silkWebs[wi];
            const dxW = w.x2 - w.x1, dyW = w.y2 - w.y1;
            const lenSq = dxW * dxW + dyW * dyW;
            if (lenSq > 1) {
              const tProj = clamp(((f.x - w.x1) * dxW + ((f.y + f.r * 0.6) - w.y1) * dyW) / lenSq, 0, 1);
              const closeX = w.x1 + tProj * dxW, closeY = w.y1 + tProj * dyW;
              if (Math.hypot(f.x - closeX, (f.y + f.r * 0.6) - closeY) <= 10) {
                f.vy = -Math.max(215, Math.min(310, Math.abs(f.vy) * 0.95));
                f.vx = clamp(f.vx * 1.08, -190, 190);
                f.jumpStartY = f.y;
                f.peakAirY = f.y;
                f.isVoluntaryJump = true;
                f.wasBlasted = false;
                f.squashX = 1.32;
                f.squashY = 0.72;
                w.vibration = 1.0;
                w.hp--;
                if (w.hp <= 0) silkWebs.splice(wi, 1);
                SND.jump();
                floatingTexts.push({
                  x: f.x, y: f.y - 24,
                  text: '¡BOING DE SEDA!',
                  color: '#fff6df',
                  life: 1.0
                });
                bouncedOnWeb = true;
                break;
              }
            }
          }
          if (bouncedOnWeb) break;

          // Check Giant Bouncy Catalan Rovelló Mushroom Trampoline!
          let bouncedOnRovello = false;
          for (const rv of rovellons) {
            if (Math.abs(f.x - rv.x) <= rv.r + 5 && Math.abs((f.y + f.r * 0.7) - (rv.y - 10)) <= 13) {
              f.vy = -Math.max(255, Math.min(340, Math.abs(f.vy) * 1.15 + 120));
              f.vx = clamp(f.vx * 1.12 + f.facing * 35, -210, 210);
              f.jumpStartY = f.y;
              f.peakAirY = f.y;
              f.isVoluntaryJump = true;
              f.wasBlasted = false;
              f.squashX = 1.38;
              f.squashY = 0.68;
              rv.squash = 0.42;
              SND.rovelloBoing();
              if (f.hp < f.maxHp) {
                f.hp = Math.min(f.maxHp, f.hp + 8);
                updateHUD();
              }
              f.urticatingTicks = 0;
              spawnSparks(rv.x, rv.y - 12, 10);
              floatingTexts.push({
                x: f.x,
                y: f.y - 26,
                text: '¡BOING DE ROVELLÓ! +8 PV',
                color: '#ff9e44',
                life: 1.35
              });
              bouncedOnRovello = true;
              break;
            }
          }
          if (bouncedOnRovello) break;
        }

        if (isSolid(f.x, f.y + f.r)) {
          while (isSolid(f.x, f.y + f.r - 1) && f.y > 0) f.y--;

          const vertSpeed = Math.abs(f.vy);
          const horizSpeed = Math.abs(f.vx);
          const totalSpeed = Math.hypot(f.vx, f.vy);
          const fallDrop = f.y - (f.jumpStartY ?? f.y); // Positive when landing LOWER than jump origin
          const dropFromPeak = f.y - (f.peakAirY ?? f.y); // Total vertical drop from highest apex in the air!
          const n = getSurfaceNormal(f.x, f.y + f.r);
          const tx = -n.y, ty = n.x;
          const tangentSpeed = f.vx * tx + f.vy * ty;
          const slopeSteepness = Math.abs(n.x);

          // 3-TIER FALLING & SLIDING PHYSICS:
          // - Significant Fall (fallDrop >= 88 or dropFromPeak >= 126, or blasted hard):
          //   Triggers "PATACADA!", deals fall damage, slides hard, and ENDS the worm's turn!
          // - Little / Moderate Fall (fallDrop >= 12 and < 88, or dropFromPeak >= 54 and < 126):
          //   Slides a little bit ( ~0.3s short skid), takes NO fall damage, and lets you KEEP MOVING & playing your turn!
          // - Flat / Uphill Hop (fallDrop < 12 and dropFromPeak < 54):
          //   Clean planted landing, no slide, turn continues!
          const isSignificantFall = (fallDrop >= 88 || dropFromPeak >= 126) ||
                                    (f.wasBlasted && (vertSpeed > 235 || totalSpeed > 285));
          const isLittleFall = !isSignificantFall && !f.wasBlasted &&
                               (fallDrop >= 12 || dropFromPeak >= 54 || (vertSpeed > 155 && slopeSteepness > 0.22));

          if (isSignificantFall && (vertSpeed > 210 || totalSpeed > 260 || fallDrop >= 88)) {
            SND.hardSlam(totalSpeed);
            shake = Math.max(shake, clamp((totalSpeed - 210) * 0.038, 3, 14));

            const squashMag = clamp((totalSpeed - 200) / 340, 0.25, 0.62);
            f.squashX = 1.0 + squashMag * 0.95;
            f.squashY = 1.0 - squashMag * 0.65;

            shockwaves.push({
              x: f.x,
              y: f.y + f.r - 2,
              r: 4,
              maxR: 26 + squashMag * 32,
              alpha: 0.75
            });
            spawnSmoke(f.x, f.y + f.r, 7, 'rgba(165, 142, 118, 0.55)');
            spawnUrticatingHairs(f.x, f.y, 10);

            const excessDrop = Math.max(dropFromPeak - 115, fallDrop - 78, 0);
            const fallDmg = clamp(Math.round(6 + excessDrop * 0.22 + Math.max(0, totalSpeed - 250) * 0.06), 6, 45);
            damageFighter(f, fallDmg, 'PATACADA!');
            f.dizzyTimer = 2.8;

            if (totalSpeed > 360 || dropFromPeak > 150) {
              carveCrater(f.x, f.y + f.r - 2, 14);
              while (!isSolid(f.x, f.y + f.r) && f.y < WATER_Y) f.y++;
            }

            // Falling from a significant distance ends the active worm's turn so it cannot continue anymore!
            if (f === activeFighter && (turnPhase === 'TURN_PLAY' || turnPhase === 'RETREAT')) {
              isCharging = false;
              chargePower = 0;
              f.jetFuel = 0;
              impactCam.active = true;
              impactCam.x = f.x;
              impactCam.y = f.y;
              impactCam.trackedWorm = f;
              turnPhase = 'ACTION_WAIT';
            }
          }

          f.flipAngle = 0;
          f.flipSpin = 0;
          f.airTimer = 0;
          f.peakAirY = f.y;

          if (isLittleFall) {
            // Fell from a little distance -> slide a little bit, then let the player keep moving & playing!
            const slideDir = horizSpeed > 8
              ? Math.sign(f.vx)
              : (Math.abs(tangentSpeed) > 12 ? Math.sign(tangentSpeed) : (n.x !== 0 ? Math.sign(n.x) : f.facing));
            const littleSlideSpeed = clamp(horizSpeed * 0.68 + Math.max(0, fallDrop) * 0.95 + slopeSteepness * 48, 46, 128);
            f.vx = slideDir * littleSlideSpeed;
            f.vy = 0;
            f.grounded = true;
            f.sliding = true;
            f.isMinorSlide = true;
            f.slideTimer = 0;
            f.squashX = 1.18;
            f.squashY = 0.84;
            SND.skid(littleSlideSpeed);
            spawnSmoke(f.x, f.y + f.r, 3, 'rgba(165, 142, 118, 0.42)');
          } else if (isSignificantFall || f.wasBlasted) {
            // Significant fall or explosion knockback -> heavy slide!
            const slideMag = horizSpeed * 0.82 + Math.max(0, vertSpeed - 195) * (0.45 + slopeSteepness * 0.6);
            if (slideMag > 44 || horizSpeed > 85) {
              const slideDir = Math.abs(tangentSpeed) > 18 ? Math.sign(tangentSpeed) : (horizSpeed > 5 ? Math.sign(f.vx) : (n.x !== 0 ? Math.sign(n.x) : f.facing));
              f.vx = slideDir * clamp(slideMag, 52, 380);
              f.vy = 0;
              f.grounded = true;
              f.sliding = true;
              f.isMinorSlide = false;
              f.slideTimer = 0;
            } else {
              f.vx = 0;
              f.vy = 0;
              f.grounded = true;
              f.sliding = false;
              f.isMinorSlide = false;
              f.slideTimer = 0;
            }
          } else {
            // Clean, planted caterpillar landing on flat/uphill hop — no sliding!
            f.vx = 0;
            f.vy = 0;
            f.grounded = true;
            f.sliding = false;
            f.isMinorSlide = false;
            f.slideTimer = 0;
            f.squashX = 1.14;
            f.squashY = 0.88;
          }
          f.wasBlasted = false;
          f.isVoluntaryJump = false;
          f.jumpStartY = f.y;
          break;
        }

        if (isSolid(f.x, f.y - f.r) && f.vy < 0) {
          f.vy = -f.vy * 0.35;
        }
        if (isSolid(f.x + Math.sign(f.vx) * f.r, f.y)) {
          f.vx = -f.vx * 0.55;
        }
      }

      if (!f.grounded && f.airTimer > 4.5 && f.jetFuel <= 0) {
        f.vx = 0;
        f.vy = 0;
        f.grounded = true;
        f.sliding = false;
        f.airTimer = 0;
      }
    }

    if (f.grounded && !f.sliding) {
      f.vx = 0;
      f.vy = 0;
    }

    // Billiard Knock-On Collisions ("¡CARAMBOLA DE CUCS!"): fast-moving or sliding Cucs knock into other Cucs & Barrels!
    const fSpeed = Math.hypot(f.vx, f.vy);
    if ((f.sliding || f.wasBlasted || (!f.grounded && fSpeed > 155)) && fSpeed > 95) {
      for (const other of fighters) {
        if (other === f || !other.alive || other.drowning) continue;
        const dx = other.x - f.x;
        const dy = other.y - f.y;
        const d = Math.hypot(dx, dy);
        if (d > 0 && d < f.r + other.r - 2 && (f._lastKnockTime || 0) < tNow - 0.28) {
          f._lastKnockTime = tNow;
          other._lastKnockTime = tNow;
          const nx = dx / d;
          other.vx = nx * Math.max(125, Math.abs(f.vx) * 0.78) + f.vx * 0.25;
          other.vy = Math.min(-95, f.vy * 0.45 - 80);
          other.grounded = false;
          other.sliding = false;
          other.wasBlasted = true;
          other.jumpStartY = other.y;
          other.peakAirY = other.y;
          other.squashX = 0.74;
          other.squashY = 1.32;
          f.vx *= 0.48;
          f.squashX = 1.24;
          f.squashY = 0.80;
          SND.bounce();
          spawnUrticatingHairs((f.x + other.x) * 0.5, (f.y + other.y) * 0.5, 6);
          if (fSpeed > 195 && other.team !== f.team) {
            damageFighter(other, 6, '¡CARAMBOLA!');
          } else {
            floatingTexts.push({
              x: other.x,
              y: other.y - 26,
              text: '¡CARAMBOLA!',
              color: '#ffe082',
              life: 1.1
            });
          }
        }
      }
      for (const b of barrels) {
        const dx = b.x - f.x;
        const dy = b.y - f.y;
        const d = Math.hypot(dx, dy);
        if (d > 0 && d < f.r + b.r && (b._lastKnockTime || 0) < tNow - 0.25) {
          b._lastKnockTime = tNow;
          b.vx += (dx / d) * Math.max(95, fSpeed * 0.55);
          b.vy = -85;
          b.grounded = false;
          f.vx *= 0.55;
          SND.bounce();
        }
      }
    }

    updateOrugaSegments(f, dt);

    if (f.y >= WATER_Y && !f.drowning) {
      f.drowning = true;
      f.drownTimer = 1.85;
      f.hp = 0;
      f.vy = 45;
      SND.plunge();
      spawnWaterPlunge(f.x, WATER_Y, 1.25);
      floatingTexts.push({
        x: f.x,
        y: WATER_Y - 26,
        text: `${f.name}: Glu glu... XOF!`,
        color: '#7ec8e3',
        life: 2.2
      });
      updateHUD();
    }
  }
}

function spawnWaterPlunge(wx, wy, scale = 1.0) {
  waterPlumes.push({
    x: wx,
    y: wy,
    h: 0,
    maxH: (65 + Math.random() * 25) * scale,
    w: 26 * scale,
    ringR: 8,
    maxRingR: 75 * scale,
    life: 1.0
  });

  // Dynamic surface wave displacement ripple!
  waterRipples.push({
    x: wx,
    amp: 14 * scale,
    radius: 10,
    speed: 195,
    life: 1.0
  });

  for (let i = 0; i < Math.floor(28 * scale); i++) {
    const a = -Math.PI * 0.18 - Math.random() * Math.PI * 0.64;
    const sp = (80 + Math.random() * 230) * scale;
    particles.push({
      x: wx + (Math.random() - 0.5) * 18,
      y: wy,
      vx: Math.cos(a) * sp,
      vy: Math.sin(a) * sp,
      w: 3.5 + Math.random() * 2.5,
      h: 3.5 + Math.random() * 2.5,
      rot: 0, vrot: 0,
      life: 1.0, decay: 1.05,
      color: Math.random() > 0.4 ? '#d6f2ff' : '#7ec8e3',
      isSpark: false
    });
  }
}

function spawnEmbers(x, y, count) {
  for (let i = 0; i < count; i++) {
    const a = -Math.PI * 0.1 - Math.random() * Math.PI * 0.8;
    const sp = 75 + Math.random() * 240;
    particles.push({
      x, y,
      vx: Math.cos(a) * sp + (Math.random() - 0.5) * 60,
      vy: Math.sin(a) * sp - 40,
      w: 3.2, h: 3.2,
      rot: 0, vrot: 0,
      life: 1.35 + Math.random() * 0.6,
      decay: 0.72 + Math.random() * 0.35,
      color: Math.random() > 0.45 ? '#ff9e3b' : '#ff4d29',
      isEmber: true,
      collidesTerrain: true
    });
  }
}

function spawnRockDebris(x, y, count) {
  for (let i = 0; i < count; i++) {
    const a = Math.random() * Math.PI * 2;
    const sp = 60 + Math.random() * 220;
    particles.push({
      x, y,
      vx: Math.cos(a) * sp,
      vy: Math.sin(a) * sp - 55,
      w: 3 + Math.random() * 5,
      h: 3 + Math.random() * 5,
      rot: Math.random() * 6,
      vrot: (Math.random() - 0.5) * 12,
      life: 1.15,
      decay: 0.75 + Math.random() * 0.6,
      color: Math.random() > 0.5 ? '#5c5552' : '#786248',
      isSpark: false,
      collidesTerrain: true
    });
  }
}

function spawnSparks(x, y, count) {
  for (let i = 0; i < count; i++) {
    const a = Math.random() * Math.PI * 2;
    const sp = 100 + Math.random() * 290;
    particles.push({
      x, y,
      vx: Math.cos(a) * sp,
      vy: Math.sin(a) * sp - 60,
      w: 2, h: 2,
      rot: 0, vrot: 0,
      life: 1,
      decay: 1.4 + Math.random() * 1.4,
      color: Math.random() > 0.35 ? '#ffd166' : '#ff6b35',
      isSpark: true
    });
  }
}

function spawnSmoke(x, y, count, color) {
  for (let i = 0; i < count; i++) {
    const a = Math.random() * Math.PI * 2;
    const sp = 12 + Math.random() * 58;
    smokePuffs.push({
      x: x + (Math.random() - 0.5) * 16,
      y: y + (Math.random() - 0.5) * 16,
      vx: Math.cos(a) * sp,
      vy: Math.sin(a) * sp - 20,
      r: 10 + Math.random() * 18,
      vr: 18 + Math.random() * 22,
      life: 1,
      decay: 0.55 + Math.random() * 0.45,
      color
    });
  }
}

// ═══════════════════════════════════════════════════════════════════════════
//  8. TACTICAL BALLISTIC AI (ROOKIE / VETERAN / NIGHTMARE)
// ═══════════════════════════════════════════════════════════════════════════
function updateAI(dt) {
  if (!isCurrentTurnAI() || turnPhase !== 'TURN_PLAY' || !activeFighter || !activeFighter.alive || activeFighter.drowning) return;

  if (!aiPlan) {
    const enemies = fighters.filter(f => f.team !== activeTeam && f.alive && !f.drowning);
    if (!enemies.length) {
      turnPhase = 'ACTION_WAIT';
      return;
    }
    enemies.sort((a, b) => Math.hypot(a.x - activeFighter.x, a.y - activeFighter.y) -
                           Math.hypot(b.x - activeFighter.x, b.y - activeFighter.y));
    const target = enemies[Math.random() < 0.75 ? 0 : Math.floor(Math.random() * enemies.length)];

    const distToNearest = Math.hypot(enemies[0].x - activeFighter.x, enemies[0].y - activeFighter.y);
    const rChoice = Math.random();
    let chosenId = 'BAZOOKA';
    if (distToNearest < 64) {
      chosenId = Math.random() < 0.6 ? 'FUET' : 'BAT'; // El Fuet de Vic or La Falç up close!
    } else if (rChoice < 0.14 && teamAmmo[activeTeam]['HOLY'] > 0) {
      chosenId = 'HOLY';
    } else if (rChoice < 0.26 && teamAmmo[activeTeam]['AIRSTRIKE'] > 0) {
      chosenId = 'AIRSTRIKE';
    } else if (rChoice < 0.40 && teamAmmo[activeTeam]['URTICARIA'] > 0) {
      chosenId = 'URTICARIA';
    } else if (rChoice < 0.54 && teamAmmo[activeTeam]['CLUSTER'] > 0) {
      chosenId = 'CLUSTER';
    } else if (rChoice < 0.70) {
      chosenId = 'CARQUINYOLI'; // Tirar Carquinyolis!
    } else if (rChoice < 0.84) {
      chosenId = 'GRENADE';
    } else {
      chosenId = 'BAZOOKA';
    }

    const chosenWpnIdx = Math.max(0, WEAPONS.findIndex(w => w.id === chosenId));
    const wpn = WEAPONS[chosenWpnIdx];
    selectedWeaponIdx = chosenWpnIdx;
    buildWeaponBar();

    aiPlan = {
      target,
      wpn,
      angle: target.x >= activeFighter.x ? -Math.PI * 0.28 : -Math.PI * 0.72,
      power: 0.65,
      walkDir: distToNearest < 45 ? 0 : (Math.random() < 0.5 ? 1 : -1),
      walkTime: distToNearest < 45 ? 0.08 : (0.45 + Math.random() * 0.40),
      aimComputed: false,
      aimTime: 0.55,
      totalTime: 0,
      executed: false
    };
  }

  aiPlan.totalTime = (aiPlan.totalTime || 0) + dt;

  if (aiPlan.walkTime > 0) {
    aiPlan.walkTime -= dt;
    return;
  }
  aiPlan.walkDir = 0;

  // Compute ballistic trajectory from the AI's final post-walk position!
  if (!aiPlan.aimComputed) {
    aiPlan.aimComputed = true;
    const target = (aiPlan.target && aiPlan.target.alive && !aiPlan.target.drowning)
      ? aiPlan.target
      : fighters.find(f => f.team !== activeTeam && f.alive && !f.drowning);
    if (!target) {
      turnPhase = 'ACTION_WAIT';
      return;
    }
    aiPlan.target = target;
    const wpn = aiPlan.wpn;
    let bestAngle = target.x >= activeFighter.x ? -Math.PI * 0.32 : -Math.PI * 0.68;
    let bestPower = 0.65;
    let bestDist = Infinity;

    if (wpn.type === 'CHARGE') {
      const dirToTarget = target.x >= activeFighter.x ? 1 : -1;
      for (let aDeg = 18; aDeg <= 78; aDeg += 4) {
        const ang = dirToTarget > 0 ? (-aDeg * Math.PI / 180) : (-Math.PI + aDeg * Math.PI / 180);
        for (let pwr = 0.28; pwr <= 0.98; pwr += 0.05) {
          const sim = simulateArc(activeFighter.x, activeFighter.y - 6, ang, pwr, wpn.windFactor || 0);
          const d = Math.hypot(sim.x - target.x, sim.y - target.y);
          const selfD = Math.hypot(sim.x - activeFighter.x, sim.y - activeFighter.y);
          if (selfD > 75 && d < bestDist) {
            bestDist = d;
            bestAngle = ang;
            bestPower = pwr;
          }
        }
      }
      const jitterScale = aiDifficulty === 'ROOKIE' ? 0.095 : (aiDifficulty === 'NIGHTMARE' ? 0.012 : 0.042);
      bestAngle += (Math.random() - 0.5) * jitterScale;
      bestPower = clamp(bestPower + (Math.random() - 0.5) * jitterScale, 0.22, 0.98);
    } else {
      bestAngle = Math.atan2(target.y - activeFighter.y, target.x - activeFighter.x);
    }
    aiPlan.angle = bestAngle;
    aiPlan.power = bestPower;
  }

  if (aiPlan.aimTime > 0) {
    aiPlan.aimTime -= dt;
    aimAngle = lerp(aimAngle, aiPlan.angle, dt * 7);
    activeFighter.facing = Math.cos(aimAngle) >= 0 ? 1 : -1;
    return;
  }

  if (!aiPlan.executed) {
    if (aiPlan.wpn.type === 'CHARGE' && aiPlan.totalTime < 3.2) {
      isCharging = true;
      chargePower += dt * 0.95;
      if (chargePower >= aiPlan.power) {
        isCharging = false;
        aiPlan.executed = true;
        fireWeapon(aiPlan.wpn, aiPlan.angle, aiPlan.power, null);
      }
    } else if (aiPlan.wpn.id === 'AIRSTRIKE') {
      isCharging = false;
      aiPlan.executed = true;
      fireWeapon(aiPlan.wpn, 0, 1, { x: aiPlan.target.x, y: aiPlan.target.y });
    } else {
      isCharging = false;
      aiPlan.executed = true;
      fireWeapon(aiPlan.wpn, aiPlan.angle, aiPlan.power || 0.7, { x: aiPlan.target.x, y: aiPlan.target.y });
    }
  } else if (turnPhase === 'TURN_PLAY' && aiPlan.totalTime > 3.5) {
    // Safeguard: ensure AI turn always transitions out of TURN_PLAY after firing
    isCharging = false;
    turnPhase = 'ACTION_WAIT';
  }
}

function simulateArc(sx, sy, angle, power, windFactor) {
  const speed = 180 + power * 760;
  let x = sx + Math.cos(angle) * 18;
  let y = sy + Math.sin(angle) * 18;
  let vx = Math.cos(angle) * speed;
  let vy = Math.sin(angle) * speed;
  const dt = 0.025;
  for (let i = 0; i < 160; i++) {
    vx += (wind * 2.4 * windFactor) * dt;
    vy += GRAVITY * dt;
    x += vx * dt;
    y += vy * dt;
    if (y >= WATER_Y || isSolid(x, y)) break;
  }
  return { x, y };
}

