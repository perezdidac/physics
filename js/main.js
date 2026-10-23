"use strict";

// ═══════════════════════════════════════════════════════════════════════════
//  11. MAIN GAME LOOP (DIRECT PLAYER SELECTION MENU, CUSTOMIZE & MATCH)
// ═══════════════════════════════════════════════════════════════════════════
let lastT = performance.now();

function updateMenuCursorUI() {
  document.querySelectorAll('#updown-menu .updown-item').forEach((el, idx) => {
    el.classList.toggle('active', idx === menuCursorIdx);
  });
}

function exitCurrentMatchToMenu() {
  SND.init();
  SND.tick();
  isCharging = false;
  chargePower = 0;
  keys.left = false;
  keys.right = false;
  keys.up = false;
  keys.down = false;
  hasStartedMatchOnce = false;
  setWeaponDrawerOpen(false);
  document.getElementById('victory-modal').classList.remove('open');
  document.getElementById('campaign-lobby').classList.remove('open');
  document.getElementById('splash-screen').classList.remove('hidden');
  appStage = 'SPLASH';
}

function activateMenuOption(idx) {
  SND.init();
  if (idx === 0) {
    // Start Quick Game vs CPU immediately with a RANDOM Catalan background & level!
    SND.titleFanfare();
    gameMode = '1P_CPU';
    currentMapIdx = Math.floor(Math.random() * MAPS.length);
    document.getElementById('lbl-mode').textContent = MODE_SHORT[gameMode];
    hasStartedMatchOnce = true;
    document.getElementById('splash-screen').classList.add('hidden');
    document.getElementById('campaign-lobby').classList.remove('open');
    appStage = 'PLAYING';
    initMatch(true);
  } else if (idx === 1) {
    // Start 2 Players Local immediately with a RANDOM Catalan background & level!
    SND.titleFanfare();
    gameMode = '2P_LOCAL';
    currentMapIdx = Math.floor(Math.random() * MAPS.length);
    document.getElementById('lbl-mode').textContent = MODE_SHORT[gameMode];
    hasStartedMatchOnce = true;
    document.getElementById('splash-screen').classList.add('hidden');
    document.getElementById('campaign-lobby').classList.remove('open');
    appStage = 'PLAYING';
    initMatch(true);
  } else if (idx === 2) {
    // Open Customize Game & Squads modal!
    SND.tick();
    document.getElementById('splash-screen').classList.add('hidden');
    openLobbyModal();
  }
}

function loop(now) {
  let rawDt = Math.min((now - lastT) / 1000, 0.033);
  lastT = now;

  if (hitStopTimer > 0) {
    hitStopTimer -= rawDt;
    render();
    requestAnimationFrame(loop);
    return;
  }

  let dt = rawDt;
  if (slowMoTimer > 0) {
    slowMoTimer -= rawDt;
    dt = rawDt * 0.38;
  }

  tNow += dt;

  if (shake > 0) shake *= Math.pow(0.04, dt);
  if (flashLight > 0) flashLight = Math.max(0, flashLight - dt * 2.6);
  if (turnSpotlightTimer > 0) turnSpotlightTimer = Math.max(0, turnSpotlightTimer - dt);

  for (let i = touchRipples.length - 1; i >= 0; i--) {
    const rp = touchRipples[i];
    rp.r += 75 * dt;
    rp.life -= 2.1 * dt;
    if (rp.life <= 0) touchRipples.splice(i, 1);
  }

  // Live Dynamic Wind, Multi-Layer Volumetric Clouds & Wind-Stream Ribbons!
  updateDynamicWind(dt);
  SND.updateAmbient(wind, appStage === 'PLAYING');

  // Classic Worms Keyboard & Button Pitch Aiming (Up / Down smoothly rotates the aim guide!)
  if (appStage === 'PLAYING' && !isCurrentTurnAI() && (turnPhase === 'TURN_PLAY' || turnPhase === 'RETREAT') &&
      activeFighter && activeFighter.alive && !activeFighter.drowning) {
    const pitchInput = (keys.down ? 1 : 0) - (keys.up ? 1 : 0);
    if (pitchInput !== 0) {
      const curWpn = WEAPONS[selectedWeaponIdx];
      if (curWpn && curWpn.id === 'AIRSTRIKE') {
        mouseWorld.x = clamp(mouseWorld.x - pitchInput * activeFighter.facing * 360 * dt, 120, TERRAIN_W - 120);
        mouseWorld.y = clamp(findSurfaceY(mouseWorld.x, 220) - 24, 90, WATER_Y - 40);
      } else {
        aimPitch = clamp(aimPitch + pitchInput * 1.55 * dt, -1.48, 1.30);
        syncAimAngleFromPitch();
      }
    }
  }

  if (appStage === 'PLAYING' && isCharging && !isCurrentTurnAI() && turnPhase === 'TURN_PLAY') {
    chargePower += chargeDir * dt * 0.92;
    if (tNow - lastChargeTick > 0.06) {
      lastChargeTick = tNow;
      SND.charge(chargePower);
    }
    if (chargePower >= 1.0) {
      chargePower = 1.0;
      isCharging = false;
      fireWeapon(WEAPONS[selectedWeaponIdx], aimAngle, chargePower, mouseWorld);
    }
  }

  // Update mobile fire button charge progress bar
  const mcFill = document.getElementById('mc-fire-fill');
  if (mcFill) {
    mcFill.style.width = (isCharging && !isCurrentTurnAI()) ? `${Math.round(chargePower * 100)}%` : '0%';
  }

  if (appStage === 'PLAYING') {
    updateAI(dt);
  }
  stepPhysics(dt);

  if (appStage === 'PLAYING') {
    const t0AliveCount = fighters.filter(f => f.team === 0 && f.alive && !f.drowning).length;
    const t1AliveCount = fighters.filter(f => f.team === 1 && f.alive && !f.drowning).length;

    const timerEl = document.getElementById('turn-timer');
    if (turnPhase === 'TURN_PLAY') {
      actionWaitTimer = 0;
      turnTimer -= dt;
      const ceilSec = Math.max(0, Math.ceil(turnTimer));
      if (timerEl) {
        timerEl.textContent = ceilSec;
        timerEl.style.color = ceilSec <= 5 ? '#ff5247' : '';
      }
      if (ceilSec <= 5 && ceilSec > 0 && ceilSec < lastTurnTickSec) {
        lastTurnTickSec = ceilSec;
        SND.tick();
      }
      if (turnTimer <= 0 || !activeFighter || !activeFighter.alive || activeFighter.drowning || t0AliveCount === 0 || t1AliveCount === 0) {
        isCharging = false;
        turnPhase = 'ACTION_WAIT';
      }
    } else if (turnPhase === 'RETREAT') {
      actionWaitTimer = 0;
      phaseTimer -= dt;
      if (timerEl) {
        timerEl.textContent = Math.max(0, Math.ceil(phaseTimer));
        timerEl.style.color = '#ffd966';
      }
      if (phaseTimer <= 0 || !activeFighter || !activeFighter.alive || activeFighter.drowning || t0AliveCount === 0 || t1AliveCount === 0) {
        turnPhase = 'ACTION_WAIT';
      }
    } else if (turnPhase === 'ACTION_WAIT') {
      actionWaitTimer += dt;
      if (timerEl) {
        timerEl.textContent = '—';
        timerEl.style.color = '';
      }

      // While waiting for action to settle, keep impactCam tracking any worm near the impact that is still flying/sliding/drowning!
      if (impactCam.active) {
        if (impactCam.trackedWorm && impactCam.trackedWorm.alive &&
            (!impactCam.trackedWorm.grounded || impactCam.trackedWorm.sliding || impactCam.trackedWorm.drowning)) {
          impactCam.x = impactCam.trackedWorm.x;
          impactCam.y = impactCam.trackedWorm.drowning ? WATER_Y - 30 : impactCam.trackedWorm.y - 24;
        } else {
          let movingNear = null, bestDist = 520;
          for (const f of fighters) {
            if (f.alive && (!f.grounded || f.sliding || f.drowning)) {
              const d = Math.hypot(f.x - impactCam.x, f.y - impactCam.y);
              if (d < bestDist) {
                bestDist = d;
                movingNear = f;
              }
            }
          }
          if (movingNear) {
            impactCam.trackedWorm = movingNear;
            impactCam.x = movingNear.x;
            impactCam.y = movingNear.drowning ? WATER_Y - 30 : movingNear.y - 24;
          }
        }
      }

      const anyMovingFighter = fighters.some(f => f.alive && (f.drowning || !f.grounded || f.sliding || f.spoonTimer > 0 || f.drillTimer > 0 || !!f.grapple));
      const anyArmedMine = mines.some(m => m.triggered);
      const waitTimeout = (projectiles.length === 0 && airstrikePlanes.length === 0 && actionWaitTimer > 3.6) || actionWaitTimer > 6.2;

      if ((projectiles.length === 0 && airstrikePlanes.length === 0 && !anyMovingFighter && !anyArmedMine) || waitTimeout) {
        if (waitTimeout) {
          // Force settle any residual motion so turn progression never blocks
          projectiles.length = 0;
          airstrikePlanes.length = 0;
          for (const f of fighters) {
            if (f.alive && !f.drowning) {
              f.vx = 0;
              f.vy = 0;
              f.sliding = false;
              f.spoonTimer = 0;
              f.drillTimer = 0;
              f.grapple = null;
              f.grounded = true;
            }
          }
        }
        actionWaitTimer = 0;
        turnPhase = 'TURN_DELAY';
        // Hold camera still at the impact / resting worm position for 2.0 seconds after all movement stops!
        phaseTimer = 2.0;
      }
    } else if (turnPhase === 'TURN_DELAY') {
      phaseTimer -= dt;
      if (phaseTimer <= 0) {
        startNextTurn();
      }
    }

    const drowningWorm = fighters.find(f => f.alive && f.drowning);
    if (projectiles.length > 0) {
      const p = projectiles[projectiles.length - 1];
      cam.panOffsetX = 0;
      cam.panOffsetY = 0;
      impactCam.active = true;
      impactCam.x = p.x;
      impactCam.y = p.y;
      cam.targetX = clamp(p.x, 220, TERRAIN_W - 220);
      cam.targetY = clamp(p.y, 160, 560);
      cam.targetZoom = slowMoTimer > 0 ? 1.16 : 1.00;
    } else if (airstrikePlanes.length > 0) {
      const pl = airstrikePlanes[0];
      cam.panOffsetX = 0;
      cam.panOffsetY = 0;
      impactCam.active = true;
      impactCam.x = pl.targetX;
      impactCam.y = 360;
      cam.targetX = clamp(pl.targetX, 220, TERRAIN_W - 220);
      cam.targetY = 360;
      cam.targetZoom = 0.96;
    } else if (drowningWorm) {
      cam.panOffsetX = 0;
      cam.panOffsetY = 0;
      impactCam.active = true;
      impactCam.x = drowningWorm.x;
      impactCam.y = WATER_Y - 40;
      cam.targetX = clamp(drowningWorm.x, 220, TERRAIN_W - 220);
      cam.targetY = clamp(WATER_Y - 40, 240, 580);
      cam.targetZoom = 1.14;
    } else if (impactCam.active && (turnPhase === 'ACTION_WAIT' || turnPhase === 'TURN_DELAY')) {
      // Keep the camera still at the impact site / affected worm until all worms stop moving + 2 seconds!
      cam.panOffsetX = 0;
      cam.panOffsetY = 0;
      cam.targetX = clamp(impactCam.x, 220, TERRAIN_W - 220);
      cam.targetY = clamp(impactCam.y, 160, 560);
      cam.targetZoom = slowMoTimer > 0 ? 1.18 : 1.08;
    } else if (activeFighter && activeFighter.alive) {
      if (keys.left || keys.right || keys.up) {
        cam.panOffsetX = lerp(cam.panOffsetX, 0, 0.14);
        cam.panOffsetY = lerp(cam.panOffsetY, 0, 0.14);
      }
      cam.targetX = clamp(activeFighter.x + cam.panOffsetX, 200, TERRAIN_W - 200);
      cam.targetY = clamp(activeFighter.y - 35 + cam.panOffsetY, 150, 580);
      cam.targetZoom = slowMoTimer > 0 ? 1.20 : 1.08;
    }
  } else if (appStage === 'SPLASH' || appStage === 'LOBBY') {
    cam.targetX = TERRAIN_W * 0.5 + Math.sin(tNow * 0.24) * 580;
    cam.targetY = 380 + Math.cos(tNow * 0.2) * 30;
    cam.targetZoom = 0.96;
  }

  const camLerp = 1 - Math.pow(0.015, rawDt);
  cam.x = lerp(cam.x, cam.targetX, camLerp);
  cam.y = lerp(cam.y, cam.targetY, camLerp);
  cam.zoom = lerp(cam.zoom, cam.targetZoom, camLerp);
  cam.smoothMouseX = lerp(cam.smoothMouseX, cam.mouseOffX, camLerp);
  cam.smoothMouseY = lerp(cam.smoothMouseY, cam.mouseOffY, camLerp);

  for (let i = particles.length - 1; i >= 0; i--) {
    const p = particles[i];
    if (!p.isBeam) {
      p.vy += (p.isHair ? 95 : 420) * dt;
      const nextX = p.x + (p.vx + (p.isHair ? wind * 0.8 : 0)) * dt;
      const nextY = p.y + p.vy * dt;
      // Physics P3: Terrain-Colliding Bouncing Rock Debris & Embers!
      if (p.collidesTerrain && nextY < WATER_Y && isSolid(nextX, nextY)) {
        if (!isSolid(p.x, nextY)) {
          p.vx = -p.vx * 0.55;
        } else {
          p.vy = -Math.abs(p.vy) * (p.isEmber ? 0.52 : 0.42);
          p.vx *= 0.74;
        }
        p.vrot *= 0.65;
      } else {
        p.x = nextX;
        p.y = nextY;
      }
      if (p.collidesTerrain && p.y >= WATER_Y) {
        // Quench ember or splash rock into water
        if (p.isEmber) p.life = 0;
        else { p.vy *= 0.35; p.vx *= 0.5; }
      }
      p.rot += p.vrot * dt;
    }
    p.life -= p.decay * dt;
    if (p.life <= 0) particles.splice(i, 1);
  }

  for (let i = fireballs.length - 1; i >= 0; i--) {
    const fb = fireballs[i];
    fb.r += (fb.maxR - fb.r) * 10 * dt;
    fb.y -= 18 * dt;
    fb.life -= (fb.decay || 2.35) * dt;
    if (!(fb.life > 0)) fireballs.splice(i, 1);
  }

  for (let i = waterRipples.length - 1; i >= 0; i--) {
    const rp = waterRipples[i];
    rp.phase = (rp.phase || 0) + dt;
    rp.life -= 0.85 * dt;
    if (!(rp.life > 0)) waterRipples.splice(i, 1);
  }

  for (let i = smokePuffs.length - 1; i >= 0; i--) {
    const s = smokePuffs[i];
    s.x += (s.vx + wind * 0.25) * dt;
    s.y += s.vy * dt;
    s.r += s.vr * dt;
    s.life -= s.decay * dt;
    if (s.life <= 0) smokePuffs.splice(i, 1);
  }

  for (let i = shockwaves.length - 1; i >= 0; i--) {
    const sw = shockwaves[i];
    sw.r += (sw.maxR - sw.r) * 9 * dt;
    sw.alpha -= 2.4 * dt;
    if (sw.alpha <= 0) shockwaves.splice(i, 1);
  }

  for (let i = waterPlumes.length - 1; i >= 0; i--) {
    const wp = waterPlumes[i];
    wp.h = Math.sin((1 - wp.life) * Math.PI) * wp.maxH;
    wp.ringR += (wp.maxRingR - wp.ringR) * 5 * dt;
    wp.life -= 1.65 * dt;
    if (wp.life <= 0) waterPlumes.splice(i, 1);
  }

  for (let i = bubbles.length - 1; i >= 0; i--) {
    const b = bubbles[i];
    b.y += b.vy * dt;
    if (b.y <= WATER_Y + 2) bubbles.splice(i, 1);
  }

  for (let i = floatingTexts.length - 1; i >= 0; i--) {
    const ft = floatingTexts[i];
    ft.y -= 26 * dt;
    ft.life -= dt;
    if (ft.life <= 0) floatingTexts.splice(i, 1);
  }

  for (let i = speechBubbles.length - 1; i >= 0; i--) {
    speechBubbles[i].life -= dt;
    if (speechBubbles[i].life <= 0) speechBubbles.splice(i, 1);
  }

  render();
  requestAnimationFrame(loop);
}

// ═══════════════════════════════════════════════════════════════════════════
//  12. INPUT CONTROLS, UP/DOWN MENU & CUSTOM SQUAD / FACE UPLOADER
// ═══════════════════════════════════════════════════════════════════════════
window.addEventListener('wheel', e => {
  if (appStage !== 'PLAYING') return;
  userZoomMult = clamp(userZoomMult - Math.sign(e.deltaY) * 0.08, 0.50, 2.25);
}, { passive: true });

// ───────────────────────────────────────────────────────────────────────────
//  CLASSIC WORMS KEYBOARD AIMING & MOBILE SWIPE / MULTI-TAP GESTURES:
//  - No point-and-click mouse aiming! Aim elevation (`aimPitch`) is controlled
//    purely by Up/Down keys (Desktop) or Vertical Swipes / ▲▼ buttons (Mobile),
//    keeping long-range shots fair and skill-based!
//  - Mobile Canvas Gestures:
//      • Swipe Up / Down   -> Smoothly moves the aim guide up or down
//      • Swipe Left / Right -> Walks the active worm left or right
//      • Double-Tap        -> Jumps forward
//      • Triple-Tap        -> Jumps backwards (360° backflip!)
//      • Long-Press Hold   -> Charges & fires along the current aim guide
//      • 2-Finger Drag/Pinch -> Pans and zooms the camera
// ───────────────────────────────────────────────────────────────────────────
const LONG_PRESS_MS = 250;
const SWIPE_THRESHOLD_PX = 9;
const MULTI_TAP_WINDOW_MS = 360;

let isTouchDraggingCanvas = false;
let mouseIsPanning = false;
let mouseDownX = 0;
let mouseDownY = 0;
let mouseLastX = 0;
let mouseLastY = 0;

let touchGestureMode = 'NONE'; // 'NONE' | 'PENDING' | 'SWIPE_AIM' | 'SWIPE_WALK' | 'SHOOT' | 'PAN'
let touchStartX = 0;
let touchStartY = 0;
let touchLastX = 0;
let touchLastY = 0;
let touchLongPressTimer = null;
let pinchLastDist = 0;
let pinchLastMidX = 0;
let pinchLastMidY = 0;

let canvasTapCount = 0;
let lastCanvasTapTime = 0;

function panMapByScreenDelta(dxScreen, dyScreen) {
  const tr = getCameraTransform();
  const worldPerCssPx = canvasDpr / Math.max(0.2, tr.scale);
  cam.panOffsetX = clamp(cam.panOffsetX - dxScreen * worldPerCssPx, -TERRAIN_W * 0.85, TERRAIN_W * 0.85);
  cam.panOffsetY = clamp(cam.panOffsetY - dyScreen * worldPerCssPx, -360, 320);
}

function updateParallaxFromPointer(clientX, clientY) {
  const nx = (clientX / Math.max(1, viewW)) - 0.5;
  const ny = (clientY / Math.max(1, viewH)) - 0.5;
  cam.mouseOffX = nx * 36;
  cam.mouseOffY = ny * 18;
}

function beginChargeOrFireCurrentAim() {
  if (isCurrentTurnAI() || turnPhase !== 'TURN_PLAY' || !activeFighter || !activeFighter.alive || activeFighter.drowning) return;
  const wpn = WEAPONS[selectedWeaponIdx];
  if (!wpn || teamAmmo[activeTeam][wpn.id] <= 0) return;

  cam.panOffsetX = 0;
  cam.panOffsetY = 0;
  syncAimAngleFromPitch();

  if (wpn.type === 'CHARGE') {
    if (!isCharging) {
      isCharging = true;
      chargePower = 0.08;
      chargeDir = 1;
    }
  } else {
    fireWeapon(wpn, aimAngle, 1.0, mouseWorld);
  }
}

function releaseChargedShot() {
  if (!isCharging) return;
  if (isCurrentTurnAI() || turnPhase !== 'TURN_PLAY' || !activeFighter || !activeFighter.alive || activeFighter.drowning) {
    isCharging = false;
    chargePower = 0;
    return;
  }
  const wpn = WEAPONS[selectedWeaponIdx];
  const pwr = Math.max(0.12, chargePower);
  isCharging = false;
  chargePower = 0;
  if (wpn && teamAmmo[activeTeam][wpn.id] > 0) {
    syncAimAngleFromPitch();
    fireWeapon(wpn, aimAngle, pwr, mouseWorld);
  }
}

function triggerForwardJump(f) {
  if (!f || !f.alive || f.drowning) return false;
  if (f.grounded && !f.sliding) {
    hasActedOrMovedThisTurn = true;
    f.grounded = false;
    f.jumpStartX = f.x;
    f.jumpStartY = f.y;
    f.peakAirY = f.y;
    f.isVoluntaryJump = true;
    f.wasBlasted = false;
    f.flipAngle = 0;
    f.flipSpin = 0;
    f.vx = f.facing * 92;
    f.vy = -178;
    f.squashX = 0.82;
    f.squashY = 1.22;
    lastJumpPressTime = performance.now();
    SND.jump();
    return true;
  }
  return false;
}

function triggerBackwardsJump(f) {
  if (!f || !f.alive || f.drowning) return;
  hasActedOrMovedThisTurn = true;
  f.grounded = false;
  f.sliding = false;
  f.jumpStartY = f.y;
  f.peakAirY = f.y;
  f.isVoluntaryJump = true;
  f.wasBlasted = false;
  // Classic Worms backwards jump: very little X-axis movement, crisp vertical hop + 360° backflip somersault!
  f.vx = -f.facing * 34;
  f.vy = -212;
  f.flipAngle = 0;
  f.flipSpin = -f.facing * Math.PI * 2.35;
  f.squashX = 0.76;
  f.squashY = 1.30;
  SND.backflip();
}

// Desktop Mouse: Dragging pans the camera view; never alters aimAngle!
window.addEventListener('mousemove', e => {
  if (isTouchDraggingCanvas) return;
  updateParallaxFromPointer(e.clientX, e.clientY);

  if (mouseIsPanning && appStage === 'PLAYING') {
    const dx = e.clientX - mouseLastX;
    const dy = e.clientY - mouseLastY;
    mouseLastX = e.clientX;
    mouseLastY = e.clientY;
    panMapByScreenDelta(dx, dy);
  }
});

canvas.addEventListener('mousedown', e => {
  if (e.button !== 0 || appStage !== 'PLAYING' || isTouchDraggingCanvas) return;
  SND.init();

  if (turnPhase === 'GAME_OVER') {
    initMatch(true);
    return;
  }

  mouseIsPanning = true;
  mouseDownX = e.clientX;
  mouseDownY = e.clientY;
  mouseLastX = e.clientX;
  mouseLastY = e.clientY;
});

window.addEventListener('mouseup', e => {
  if (e.button !== 0 || isTouchDraggingCanvas) return;
  if (mouseIsPanning && appStage === 'PLAYING' && !hasActedOrMovedThisTurn && turnPhase === 'TURN_PLAY' && !isCurrentTurnAI()) {
    if (Math.hypot(e.clientX - mouseDownX, e.clientY - mouseDownY) <= 6) {
      const clickWorld = screenToWorld(e.clientX, e.clientY);
      const clickedAlly = fighters.find(f =>
        f !== activeFighter && f.team === activeTeam && f.alive && !f.drowning &&
        Math.hypot(f.x - clickWorld.x, (f.y - 6) - clickWorld.y) <= 28
      );
      if (clickedAlly) {
        switchActiveWormBeforeMove(clickedAlly);
      }
    }
  }
  mouseIsPanning = false;
});

// ───────────────────────────────────────────────────────────────────────────
//  MOBILE TOUCH GESTURES ON CANVAS:
//  - Swipe Up / Down    -> Move Aim Guide Up or Down (`aimPitch`)
//  - Swipe Left / Right -> Walk Worm Left or Right (`keys.left` / `keys.right`)
//  - Double-Tap         -> Jump Forward (`triggerForwardJump`)
//  - Triple-Tap         -> Jump Backwards / Backflip (`triggerBackwardsJump`)
//  - Long-Press Hold    -> Charge & Fire along current Aim Guide
//  - 2-Finger Pinch/Pan -> Zoom & Pan Map
// ───────────────────────────────────────────────────────────────────────────
canvas.addEventListener('touchstart', e => {
  document.body.classList.add('touch-device');
  if (appStage !== 'PLAYING') return;
  e.preventDefault();
  SND.init();
  isTouchDraggingCanvas = true;

  if (turnPhase === 'GAME_OVER') {
    initMatch(true);
    return;
  }

  if (touchLongPressTimer) {
    clearTimeout(touchLongPressTimer);
    touchLongPressTimer = null;
  }

  if (e.touches.length === 1) {
    const t = e.touches[0];
    touchStartX = t.clientX;
    touchStartY = t.clientY;
    touchLastX = t.clientX;
    touchLastY = t.clientY;
    touchGestureMode = 'PENDING';

    touchLongPressTimer = setTimeout(() => {
      touchLongPressTimer = null;
      if (touchGestureMode === 'PENDING' && appStage === 'PLAYING') {
        touchGestureMode = 'SHOOT';
        beginChargeOrFireCurrentAim();
      }
    }, LONG_PRESS_MS);
  } else if (e.touches.length >= 2) {
    touchGestureMode = 'PAN';
    keys.left = false;
    keys.right = false;
    isCharging = false;
    chargePower = 0;
    const t0 = e.touches[0], t1 = e.touches[1];
    pinchLastDist = Math.hypot(t1.clientX - t0.clientX, t1.clientY - t0.clientY);
    pinchLastMidX = (t0.clientX + t1.clientX) * 0.5;
    pinchLastMidY = (t0.clientY + t1.clientY) * 0.5;
  }
}, { passive: false });

canvas.addEventListener('touchmove', e => {
  if (appStage !== 'PLAYING') return;
  e.preventDefault();

  if (e.touches.length === 1) {
    const t = e.touches[0];
    const dxScreen = t.clientX - touchLastX;
    const dyScreen = t.clientY - touchLastY;
    touchLastX = t.clientX;
    touchLastY = t.clientY;

    if (touchGestureMode === 'PENDING') {
      const totalDx = t.clientX - touchStartX;
      const totalDy = t.clientY - touchStartY;
      const distFromStart = Math.hypot(totalDx, totalDy);
      if (distFromStart > SWIPE_THRESHOLD_PX) {
        if (touchLongPressTimer) {
          clearTimeout(touchLongPressTimer);
          touchLongPressTimer = null;
        }
        isCharging = false;
        chargePower = 0;
        // Lock gesture into Vertical Aiming or Horizontal Walking!
        if (Math.abs(totalDy) > Math.abs(totalDx) * 1.08) {
          touchGestureMode = 'SWIPE_AIM';
        } else {
          touchGestureMode = 'SWIPE_WALK';
        }
      }
    }

    if (touchGestureMode === 'SWIPE_AIM') {
      // Swiping Up/Down smoothly elevates or lowers the aim guide!
      if (!isCurrentTurnAI() && (turnPhase === 'TURN_PLAY' || turnPhase === 'RETREAT') &&
          activeFighter && activeFighter.alive && !activeFighter.drowning) {
        cam.panOffsetX = lerp(cam.panOffsetX, 0, 0.2);
        cam.panOffsetY = lerp(cam.panOffsetY, 0, 0.2);
        aimPitch = clamp(aimPitch + dyScreen * 0.0085, -1.48, 1.30);
        syncAimAngleFromPitch();
      } else {
        panMapByScreenDelta(dxScreen, dyScreen);
      }
    } else if (touchGestureMode === 'SWIPE_WALK') {
      // Swiping Left/Right walks the worm left or right (or moves Correfoc airstrike target)!
      if (!isCurrentTurnAI() && (turnPhase === 'TURN_PLAY' || turnPhase === 'RETREAT') &&
          activeFighter && activeFighter.alive && !activeFighter.drowning) {
        const curWpn = WEAPONS[selectedWeaponIdx];
        if (curWpn && curWpn.id === 'AIRSTRIKE' && Math.abs(dxScreen) > 0.5) {
          const tr = getCameraTransform();
          const worldPerCssPx = canvasDpr / Math.max(0.2, tr.scale);
          mouseWorld.x = clamp(mouseWorld.x + dxScreen * worldPerCssPx, 120, TERRAIN_W - 120);
          mouseWorld.y = clamp(findSurfaceY(mouseWorld.x, 220) - 24, 90, WATER_Y - 40);
        } else {
          const offsetFromStart = t.clientX - touchStartX;
          if (Math.abs(offsetFromStart) > 6) {
            const dir = offsetFromStart > 0 ? 1 : -1;
            keys.left = dir < 0;
            keys.right = dir > 0;
            if (activeFighter.facing !== dir) {
              activeFighter.facing = dir;
              syncAimAngleFromPitch();
            }
          }
        }
      } else {
        panMapByScreenDelta(dxScreen, dyScreen);
      }
    } else if (touchGestureMode === 'SHOOT') {
      // While holding long-press to charge, slight vertical drag can still fine-tune aimPitch!
      if (Math.abs(dyScreen) > 0.4) {
        aimPitch = clamp(aimPitch + dyScreen * 0.0065, -1.48, 1.30);
        syncAimAngleFromPitch();
      }
    } else if (touchGestureMode === 'PAN') {
      panMapByScreenDelta(dxScreen, dyScreen);
    }
  } else if (e.touches.length >= 2) {
    if (touchLongPressTimer) {
      clearTimeout(touchLongPressTimer);
      touchLongPressTimer = null;
    }
    touchGestureMode = 'PAN';
    keys.left = false;
    keys.right = false;
    isCharging = false;
    chargePower = 0;

    const t0 = e.touches[0], t1 = e.touches[1];
    const dist = Math.hypot(t1.clientX - t0.clientX, t1.clientY - t0.clientY);
    const midX = (t0.clientX + t1.clientX) * 0.5;
    const midY = (t0.clientY + t1.clientY) * 0.5;

    if (pinchLastDist > 12) {
      const zoomFactor = dist / pinchLastDist;
      userZoomMult = clamp(userZoomMult * zoomFactor, 0.50, 2.25);
    }
    panMapByScreenDelta(midX - pinchLastMidX, midY - pinchLastMidY);

    pinchLastDist = dist;
    pinchLastMidX = midX;
    pinchLastMidY = midY;
  }
}, { passive: false });

canvas.addEventListener('touchend', e => {
  if (touchLongPressTimer) {
    clearTimeout(touchLongPressTimer);
    touchLongPressTimer = null;
  }
  if (e.touches.length === 0) {
    const mode = touchGestureMode;
    touchGestureMode = 'NONE';
    keys.left = false;
    keys.right = false;

    if (mode === 'SHOOT') {
      releaseChargedShot();
    } else if (mode === 'PENDING') {
      // Stationary quick tap on canvas -> Multi-tap detector for Double-Tap Jump & Triple-Tap Backflip!
      const now = performance.now();
      if (now - lastCanvasTapTime < MULTI_TAP_WINDOW_MS) {
        canvasTapCount++;
      } else {
        canvasTapCount = 1;
      }
      lastCanvasTapTime = now;

      if ((turnPhase === 'TURN_PLAY' || turnPhase === 'RETREAT') &&
          activeFighter && activeFighter.alive && !activeFighter.drowning &&
          activeFighter.jetFuel <= 0 && !isCurrentTurnAI()) {
        if (canvasTapCount === 1 && !hasActedOrMovedThisTurn && turnPhase === 'TURN_PLAY') {
          // Single-tap directly on another allied worm before moving switches active worm!
          const tapWorld = screenToWorld(touchLastX, touchLastY);
          const tappedAlly = fighters.find(f =>
            f !== activeFighter && f.team === activeTeam && f.alive && !f.drowning &&
            Math.hypot(f.x - tapWorld.x, (f.y - 6) - tapWorld.y) <= 32
          );
          if (tappedAlly) {
            switchActiveWormBeforeMove(tappedAlly);
            touchRipples.push({ x: touchLastX, y: touchLastY, r: 8, life: 1.0, label: tappedAlly.name.toUpperCase() });
            canvasTapCount = 0;
          }
        } else if (canvasTapCount === 2) {
          // Double-tap -> Jump forward!
          triggerForwardJump(activeFighter);
          touchRipples.push({ x: touchLastX, y: touchLastY, r: 8, life: 1.0, label: '¡SALT!' });
        } else if (canvasTapCount >= 3) {
          // Triple-tap -> Jump backwards (backflip), even converting an in-air double-tap hop!
          if (activeFighter.jumpStartX !== undefined) {
            activeFighter.x = lerp(activeFighter.x, activeFighter.jumpStartX, 0.75);
          }
          triggerBackwardsJump(activeFighter);
          touchRipples.push({ x: touchLastX, y: touchLastY, r: 10, life: 1.0, label: '¡MORTAL ENRERE!', color: '#ff8b3d' });
          canvasTapCount = 0;
        }
      }
    } else {
      isCharging = false;
      chargePower = 0;
    }
    setTimeout(() => { isTouchDraggingCanvas = false; }, 280);
  } else if (e.touches.length === 1) {
    touchLastX = e.touches[0].clientX;
    touchLastY = e.touches[0].clientY;
    pinchLastDist = 0;
  }
}, { passive: false });

canvas.addEventListener('touchcancel', () => {
  if (touchLongPressTimer) {
    clearTimeout(touchLongPressTimer);
    touchLongPressTimer = null;
  }
  touchGestureMode = 'NONE';
  keys.left = false;
  keys.right = false;
  isCharging = false;
  chargePower = 0;
  setTimeout(() => { isTouchDraggingCanvas = false; }, 280);
}, { passive: false });

// ───────────────────────────────────────────────────────────────────────────
//  TACTILE MOBILE GAMEPAD BUTTONS (Works in Portrait & Landscape!)
// ───────────────────────────────────────────────────────────────────────────
function bindHoldButton(btnId, onDown, onUp) {
  const btn = document.getElementById(btnId);
  if (!btn) return;
  btn.addEventListener('pointerdown', e => {
    e.preventDefault();
    e.stopPropagation();
    document.body.classList.add('touch-device');
    SND.init();
    btn.classList.add('pressed');
    try { btn.setPointerCapture(e.pointerId); } catch (_) {}
    onDown();
  });
  const release = e => {
    e.preventDefault();
    e.stopPropagation();
    if (!btn.classList.contains('pressed')) return;
    btn.classList.remove('pressed');
    onUp();
  };
  btn.addEventListener('pointerup', release);
  btn.addEventListener('pointercancel', release);
}

bindHoldButton('mc-left', () => {
  keys.left = true;
  keys.right = false;
  if (activeFighter && activeFighter.alive && !isCurrentTurnAI() && (turnPhase === 'TURN_PLAY' || turnPhase === 'RETREAT')) {
    activeFighter.facing = -1;
    syncAimAngleFromPitch();
  }
}, () => {
  keys.left = false;
});

bindHoldButton('mc-right', () => {
  keys.right = true;
  keys.left = false;
  if (activeFighter && activeFighter.alive && !isCurrentTurnAI() && (turnPhase === 'TURN_PLAY' || turnPhase === 'RETREAT')) {
    activeFighter.facing = 1;
    syncAimAngleFromPitch();
  }
}, () => {
  keys.right = false;
});

bindHoldButton('mc-aim-up', () => {
  keys.up = true;
  keys.down = false;
}, () => {
  keys.up = false;
});

bindHoldButton('mc-aim-down', () => {
  keys.down = true;
  keys.up = false;
}, () => {
  keys.down = false;
});

bindHoldButton('mc-jump', () => {
  if ((turnPhase === 'TURN_PLAY' || turnPhase === 'RETREAT') &&
      activeFighter && activeFighter.alive && !activeFighter.drowning &&
      activeFighter.jetFuel <= 0 && !isCurrentTurnAI()) {
    const now = performance.now();
    if (activeFighter.grounded && !activeFighter.sliding) {
      triggerForwardJump(activeFighter);
    } else if (!activeFighter.grounded && now - lastJumpPressTime < 360) {
      if (activeFighter.jumpStartX !== undefined) {
        activeFighter.x = lerp(activeFighter.x, activeFighter.jumpStartX, 0.72);
      }
      triggerBackwardsJump(activeFighter);
      lastJumpPressTime = 0;
    }
  }
}, () => {});

bindHoldButton('mc-fire', () => {
  if (appStage !== 'PLAYING') return;
  if (turnPhase === 'GAME_OVER') {
    initMatch(true);
    return;
  }
  beginChargeOrFireCurrentAim();
}, () => {
  releaseChargedShot();
});

document.getElementById('mc-zoom-in').onclick = e => {
  e.stopPropagation();
  SND.init();
  userZoomMult = clamp(userZoomMult + 0.16, 0.50, 2.25);
};

document.getElementById('mc-zoom-out').onclick = e => {
  e.stopPropagation();
  SND.init();
  userZoomMult = clamp(userZoomMult - 0.16, 0.50, 2.25);
};

document.getElementById('mc-pan').onclick = e => {
  e.stopPropagation();
  SND.init();
  cam.panOffsetX = 0;
  cam.panOffsetY = 0;
};

// ───────────────────────────────────────────────────────────────────────────
//  CLASSIC WORMS KEYBOARD CONTROLS:
//  - Up / Down (or W / S)   -> Rotate Aim Guide Up / Down (`aimPitch`)
//  - Left / Right (or A / D)-> Walk Worm Left / Right
//  - Spacebar               -> Hold to Charge Power, Release to Shoot!
//  - Enter (or J)           -> Jump Forward (Double-press Enter -> Backflip!)
//  - Backspace              -> Jump Backwards (360° Backflip)
// ───────────────────────────────────────────────────────────────────────────
window.addEventListener('keydown', e => {
  // Up/Down Keyboard Navigation on the Main Player Selection Menu!
  if (appStage === 'SPLASH') {
    if (e.key === 'ArrowUp' || e.key === 'w' || e.key === 'W') {
      e.preventDefault();
      SND.init();
      SND.tick();
      menuCursorIdx = (menuCursorIdx + 2) % 3;
      updateMenuCursorUI();
    } else if (e.key === 'ArrowDown' || e.key === 's' || e.key === 'S') {
      e.preventDefault();
      SND.init();
      SND.tick();
      menuCursorIdx = (menuCursorIdx + 1) % 3;
      updateMenuCursorUI();
    } else if (e.key === 'Enter' || e.key === ' ') {
      e.preventDefault();
      activateMenuOption(menuCursorIdx);
    }
    return;
  }

  if (appStage === 'LOBBY' && e.key === 'Escape') {
    lobbyModal.classList.remove('open');
    if (hasStartedMatchOnce) {
      appStage = 'PLAYING';
    } else {
      document.getElementById('splash-screen').classList.remove('hidden');
      appStage = 'SPLASH';
    }
    return;
  }

  if (appStage !== 'PLAYING') return;
  SND.init();

  if (e.key === 'a' || e.key === 'A' || e.key === 'ArrowLeft') {
    if (e.key === 'ArrowLeft') e.preventDefault();
    keys.left = true;
    if (activeFighter && activeFighter.alive && !isCurrentTurnAI() && (turnPhase === 'TURN_PLAY' || turnPhase === 'RETREAT')) {
      activeFighter.facing = -1;
      syncAimAngleFromPitch();
    }
  }
  if (e.key === 'd' || e.key === 'D' || e.key === 'ArrowRight') {
    if (e.key === 'ArrowRight') e.preventDefault();
    keys.right = true;
    if (activeFighter && activeFighter.alive && !isCurrentTurnAI() && (turnPhase === 'TURN_PLAY' || turnPhase === 'RETREAT')) {
      activeFighter.facing = 1;
      syncAimAngleFromPitch();
    }
  }

  // Aim Up (Up Arrow / W) — also thrusts Jetpack / glides Moth Wings while airborne
  if (e.key === 'w' || e.key === 'W' || e.key === 'ArrowUp') {
    if (e.key === 'ArrowUp') e.preventDefault();
    keys.up = true;
  }

  // Aim Down (Down Arrow / S)
  if (e.key === 's' || e.key === 'S' || e.key === 'ArrowDown') {
    if (e.key === 'ArrowDown') e.preventDefault();
    keys.down = true;
  }

  // Spacebar: Hold to Charge & Fire Weapon along the Aim Guide!
  if (e.key === ' ') {
    e.preventDefault();
    if (turnPhase === 'GAME_OVER') {
      initMatch(true);
      return;
    }
    if (!e.repeat) {
      beginChargeOrFireCurrentAim();
    }
  }

  // Classic Worms Forward Jump (Enter or J) — double-press within 360ms converts into Backwards Jump!
  if ((e.key === 'Enter' || e.key === 'j' || e.key === 'J') && !e.repeat) {
    e.preventDefault();
    if ((turnPhase === 'TURN_PLAY' || turnPhase === 'RETREAT') &&
        activeFighter && activeFighter.alive && !activeFighter.drowning &&
        activeFighter.jetFuel <= 0 && !isCurrentTurnAI()) {
      const now = performance.now();
      if (activeFighter.grounded && !activeFighter.sliding) {
        triggerForwardJump(activeFighter);
      } else if (!activeFighter.grounded && now - lastJumpPressTime < 360) {
        if (activeFighter.jumpStartX !== undefined) {
          activeFighter.x = lerp(activeFighter.x, activeFighter.jumpStartX, 0.72);
        }
        triggerBackwardsJump(activeFighter);
        lastJumpPressTime = 0;
      }
    }
  }

  // Dedicated Classic Worms Backwards Jump / Backflip (Backspace)
  if (e.key === 'Backspace' && !e.repeat) {
    e.preventDefault();
    if ((turnPhase === 'TURN_PLAY' || turnPhase === 'RETREAT') &&
        activeFighter && activeFighter.alive && !activeFighter.drowning &&
        activeFighter.jetFuel <= 0 && !isCurrentTurnAI() &&
        activeFighter.grounded && !activeFighter.sliding) {
      triggerBackwardsJump(activeFighter);
    }
  }

  // [Escape] Exit current match back to Main Menu!
  if (e.key === 'Escape') {
    e.preventDefault();
    exitCurrentMatchToMenu();
    return;
  }

  // [M] Toggle MIDI Music On / Off
  if ((e.key === 'm' || e.key === 'M') && !e.repeat) {
    SND.toggleMusic();
  }

  // [Tab] Classic Worms "Worm Select" before moving or firing!
  if (e.key === 'Tab' && !e.repeat) {
    e.preventDefault();
    switchActiveWormBeforeMove();
  }

  // [C] Spin Elastic Silk Web Trampoline / Shield
  if (e.key === 'c' || e.key === 'C') {
    if (!isCurrentTurnAI()) spinElasticSilkWeb();
  }

  // [F] Toggle Nose-to-Tail Procession Convoy March
  if (e.key === 'f' || e.key === 'F') {
    processionConvoyEnabled = !processionConvoyEnabled;
    const pLbl = document.getElementById('lbl-procession');
    if (pLbl) pLbl.textContent = processionConvoyEnabled ? 'Processó: Auto [F]' : 'Processó: Sol [F]';
  }

  if (e.key === 'q' || e.key === 'Q') {
    customGrenadeFuse = Math.max(1, customGrenadeFuse - 1);
    updateFuseUI();
  }
  if (e.key === 'e' || e.key === 'E') {
    customGrenadeFuse = Math.min(5, customGrenadeFuse + 1);
    updateFuseUI();
  }

  const keyIdx = WEAPONS.findIndex(w => w.key === e.key);
  if (keyIdx >= 0 && keyIdx < WEAPONS.length) {
    if (!isCurrentTurnAI() && teamAmmo[activeTeam][WEAPONS[keyIdx].id] > 0) {
      selectedWeaponIdx = keyIdx;
      teamSelectedWeaponIdx[activeTeam] = keyIdx;
      if (WEAPONS[keyIdx].id === 'AIRSTRIKE' && activeFighter) {
        mouseWorld = {
          x: clamp(activeFighter.x + activeFighter.facing * 220, 200, TERRAIN_W - 200),
          y: Math.max(160, activeFighter.y - 110)
        };
      }
      buildWeaponBar();
    }
  }
});

window.addEventListener('keyup', e => {
  if (e.key === 'a' || e.key === 'A' || e.key === 'ArrowLeft') keys.left = false;
  if (e.key === 'd' || e.key === 'D' || e.key === 'ArrowRight') keys.right = false;
  if (e.key === 'w' || e.key === 'W' || e.key === 'ArrowUp') keys.up = false;
  if (e.key === 's' || e.key === 'S' || e.key === 'ArrowDown') keys.down = false;
  if (e.key === ' ') {
    e.preventDefault();
    releaseChargedShot();
  }
});

function updateFuseUI() {
  document.querySelectorAll('.fuse-btn').forEach(btn => {
    btn.classList.toggle('active', parseInt(btn.dataset.fuse, 10) === customGrenadeFuse);
  });
}

document.querySelectorAll('.fuse-btn').forEach(btn => {
  btn.onclick = () => {
    customGrenadeFuse = parseInt(btn.dataset.fuse, 10);
    updateFuseUI();
  };
});

function updateHUD() {
  let hp0 = 0, hp1 = 0;
  const pips0 = document.getElementById('t1-pips');
  const pips1 = document.getElementById('t2-pips');
  pips0.innerHTML = '';
  pips1.innerHTML = '';

  for (const f of fighters) {
    const alive = f.alive && !f.drowning;
    if (alive) {
      if (f.team === 0) hp0 += f.hp;
      else hp1 += f.hp;
    }
    const pip = document.createElement('div');
    pip.className = 'worm-pip' +
      (f === activeFighter && alive ? ' active' : '') +
      (!alive ? ' dead' : '');
    pip.style.cursor = alive ? 'pointer' : 'default';
    pip.title = alive
      ? (f.team === activeTeam ? 'Toca abans de moure per jugar amb aquest cuc' : 'Toca per mirar on és aquest cuc')
      : '';
    const col = f.team === 0 ? '#f5b945' : '#ea5648';
    const pct = alive ? clamp((f.hp / f.maxHp) * 100, 0, 100) : 0;
    pip.innerHTML = `
      <div class="worm-pip-name">${f.name}</div>
      <div class="worm-pip-bar"><div class="worm-pip-fill" style="width:${pct}%;background:${col}"></div></div>
    `;
    if (alive) {
      pip.onclick = e => {
        e.stopPropagation();
        SND.init();
        if (!switchActiveWormBeforeMove(f) && activeFighter) {
          // Pan camera to inspect this worm on the battlefield!
          SND.tick();
          cam.panOffsetX = clamp(f.x - activeFighter.x, -TERRAIN_W * 0.85, TERRAIN_W * 0.85);
          cam.panOffsetY = clamp(f.y - activeFighter.y, -360, 320);
        }
      };
    }
    if (f.team === 0) pips0.appendChild(pip);
    else pips1.appendChild(pip);
  }

  document.getElementById('t1-hp-text').textContent = `${hp0} PV`;
  document.getElementById('t2-hp-text').textContent = `${hp1} PV`;
}

function setWeaponDrawerOpen(isOpen) {
  const bar = document.getElementById('weapon-bar');
  const toggleBtn = document.getElementById('weapon-toggle-btn');
  const chev = document.getElementById('wt-chevron');
  if (!bar || !toggleBtn) return;
  bar.classList.toggle('open', isOpen);
  toggleBtn.classList.toggle('open', isOpen);
  if (chev) chev.innerHTML = isOpen ? '&#9660; Tanca' : '&#9650; Arsenal';
}

const weaponToggleBtnEl = document.getElementById('weapon-toggle-btn');
if (weaponToggleBtnEl) {
  weaponToggleBtnEl.onclick = e => {
    e.stopPropagation();
    SND.init();
    SND.tick();
    const bar = document.getElementById('weapon-bar');
    setWeaponDrawerOpen(!bar.classList.contains('open'));
  };
}

canvas.addEventListener('pointerdown', () => {
  setWeaponDrawerOpen(false);
});

function buildWeaponBar() {
  const bar = document.getElementById('weapon-bar');
  bar.innerHTML = '';
  const curWpn = WEAPONS[selectedWeaponIdx];
  document.getElementById('fuse-picker').classList.toggle('visible', !!curWpn.hasCustomFuse);

  // Update the sleek active weapon pill button
  if (curWpn) {
    const curAmmo = teamAmmo[activeTeam] ? teamAmmo[activeTeam][curWpn.id] : curWpn.defaultAmmo;
    const wtIcon = document.getElementById('wt-icon');
    const wtName = document.getElementById('wt-name');
    const wtAmmo = document.getElementById('wt-ammo');
    if (wtIcon) wtIcon.innerHTML = curWpn.svg;
    if (wtName) wtName.textContent = curWpn.name;
    if (wtAmmo) wtAmmo.textContent = curAmmo === Infinity ? '∞' : curAmmo;
  }

  const fireLbl = document.getElementById('mc-fire-label');
  if (fireLbl && curWpn) {
    if (curWpn.type === 'CHARGE') fireLbl.textContent = 'MANTÉN: FOC!';
    else if (curWpn.id === 'AIRSTRIKE') fireLbl.textContent = 'CORREFOC!';
    else if (curWpn.id === 'CULLERA') fireLbl.textContent = 'CULLERADA!';
    else if (curWpn.id === 'BARRINA') fireLbl.textContent = 'BARRINA!';
    else if (curWpn.id === 'PONT_PEDRA') fireLbl.textContent = 'PEDRA SECA!';
    else if (curWpn.id === 'GANXO') fireLbl.textContent = 'GANXO!';
    else if (curWpn.type === 'MELEE') fireLbl.textContent = 'ATACA!';
    else if (curWpn.type === 'DROP') fireLbl.textContent = 'DEIXA TIÓ!';
    else if (curWpn.type === 'UTILITY_JET') fireLbl.textContent = 'ALES!';
    else fireLbl.textContent = 'FOC!';
  }

  WEAPONS.forEach((w, i) => {
    const ammo = teamAmmo[activeTeam] ? teamAmmo[activeTeam][w.id] : w.defaultAmmo;
    const slot = document.createElement('div');
    slot.className = 'ord-slot' +
      (i === selectedWeaponIdx ? ' active' : '') +
      (ammo <= 0 ? ' depleted' : '');
    slot.innerHTML = `
      <span class="ord-hotkey">${w.key}</span>
      <span class="ord-ammo">${ammo === Infinity ? '∞' : ammo}</span>
      <div class="ord-icon">${w.svg}</div>
      <span class="ord-label">${w.name}</span>
    `;
    slot.onclick = () => {
      if (!isCurrentTurnAI() && ammo > 0) {
        SND.init();
        SND.tick();
        selectedWeaponIdx = i;
        teamSelectedWeaponIdx[activeTeam] = i;
        if (w.id === 'AIRSTRIKE' && activeFighter) {
          mouseWorld = {
            x: clamp(activeFighter.x + activeFighter.facing * 220, 200, TERRAIN_W - 200),
            y: Math.max(160, activeFighter.y - 110)
          };
        }
        buildWeaponBar();
        setWeaponDrawerOpen(false);
      }
    };
    bar.appendChild(slot);
  });
}

// Campaign Lobby Modal (Modes, Difficulty, 4 Catalan Theatres, Hats, Names & Faces)
const lobbyModal = document.getElementById('campaign-lobby');

function openLobbyModal() {
  appStage = 'LOBBY';
  const t1Container = document.getElementById('t1-inputs');
  const t2Container = document.getElementById('t2-inputs');
  t1Container.innerHTML = '';
  t2Container.innerHTML = '';

  for (let i = 0; i < 4; i++) {
    t1Container.innerHTML += `
      <div class="oruga-row">
        <span class="oruga-idx">0${i + 1}</span>
        <input type="text" id="inp-t0-${i}" value="${teamNames[0][i]}" maxlength="16">
        <label class="face-upload-label" title="Puja la foto de la cara d'un amic per a aquest cuc">
          ${customFaces[0][i] ? '✓ Cara Llista' : '+ Cara'}
          <input type="file" accept="image/*" style="display:none" onchange="handleFaceUpload(0, ${i}, this)">
        </label>
      </div>
    `;
    t2Container.innerHTML += `
      <div class="oruga-row">
        <span class="oruga-idx">0${i + 1}</span>
        <input type="text" id="inp-t1-${i}" value="${teamNames[1][i]}" maxlength="16">
        <label class="face-upload-label" title="Puja la foto de la cara d'un amic per a aquest cuc">
          ${customFaces[1][i] ? '✓ Cara Llista' : '+ Cara'}
          <input type="file" accept="image/*" style="display:none" onchange="handleFaceUpload(1, ${i}, this)">
        </label>
      </div>
    `;
  }

  document.getElementById('hat-t0').value = teamHats[0];
  document.getElementById('hat-t1').value = teamHats[1];

  document.querySelectorAll('#mode-selector .tactical-card').forEach(el => {
    el.classList.toggle('selected', el.dataset.mode === gameMode);
  });
  document.querySelectorAll('#diff-selector .tactical-card').forEach(el => {
    el.classList.toggle('selected', el.dataset.diff === aiDifficulty);
  });

  const mapSel = document.getElementById('map-selector');
  mapSel.innerHTML = '';
  MAPS.forEach((m, idx) => {
    const card = document.createElement('div');
    card.className = 'theatre-card' + (idx === currentMapIdx ? ' selected' : '');
    card.innerHTML = `
      <img src="${m.bgPath}" alt="${m.name}">
      <div class="theatre-overlay">
        <span class="theatre-badge">${m.badge}</span>
        <div class="theatre-name">${m.name}</div>
        <div class="theatre-landmarks">${m.subtitle}</div>
      </div>
    `;
    card.onclick = () => {
      currentMapIdx = idx;
      generateDestructibleTerrain(currentMapIdx);
      document.querySelectorAll('#map-selector .theatre-card').forEach((el, i) => el.classList.toggle('selected', i === idx));
    };
    mapSel.appendChild(card);
  });

  document.getElementById('btn-close-setup').style.display = hasStartedMatchOnce ? 'inline-flex' : 'none';
  lobbyModal.classList.add('open');
}

window.handleFaceUpload = function(team, idx, inputEl) {
  const file = inputEl.files && inputEl.files[0];
  if (!file) return;
  const reader = new FileReader();
  reader.onload = e => {
    const img = new Image();
    img.onload = () => {
      customFaces[team][idx] = img;
      for (const f of fighters) {
        if (f.team === team && f.memberIdx === idx) f.customFaceImg = img;
      }
      inputEl.parentElement.childNodes[0].textContent = '✓ Cara Llista';
    };
    img.src = e.target.result;
  };
  reader.readAsDataURL(file);
};

document.querySelectorAll('#mode-selector .tactical-card').forEach(el => {
  el.onclick = () => {
    gameMode = el.dataset.mode;
    document.getElementById('lbl-mode').textContent = MODE_SHORT[gameMode];
    document.querySelectorAll('#mode-selector .tactical-card').forEach(o => o.classList.toggle('selected', o === el));
    aiPlan = null;
  };
});

document.querySelectorAll('#diff-selector .tactical-card').forEach(el => {
  el.onclick = () => {
    aiDifficulty = el.dataset.diff;
    document.querySelectorAll('#diff-selector .tactical-card').forEach(o => o.classList.toggle('selected', o === el));
  };
});

function readLobbyCustomization() {
  for (let i = 0; i < 4; i++) {
    const v0 = document.getElementById(`inp-t0-${i}`).value.trim();
    const v1 = document.getElementById(`inp-t1-${i}`).value.trim();
    if (v0) teamNames[0][i] = v0;
    if (v1) teamNames[1][i] = v1;
  }
  teamHats[0] = document.getElementById('hat-t0').value;
  teamHats[1] = document.getElementById('hat-t1').value;
  for (const f of fighters) {
    f.name = teamNames[f.team][f.memberIdx];
  }
  if (activeFighter) {
    document.getElementById('turn-status').textContent = `Torn de ${activeFighter.name}`;
  }
  updateHUD();
}

document.getElementById('btn-random-names').onclick = () => {
  const pool0 = ['Peluda', 'Serrallonga', 'Pinassa', 'Rovelló', 'Botifarra', 'Calçot', 'Gaudí', 'Garbí', 'Fuet', 'Escudella'];
  const pool1 = ['Urticària', 'Tramuntana', 'Boira', 'Espina', 'Caganer', 'Tió', 'Fageda', 'Ratafia', 'Empordà', 'Canigó'];
  pool0.sort(() => Math.random() - 0.5);
  pool1.sort(() => Math.random() - 0.5);
  for (let i = 0; i < 4; i++) {
    teamNames[0][i] = pool0[i];
    teamNames[1][i] = pool1[i];
    const i0 = document.getElementById(`inp-t0-${i}`);
    const i1 = document.getElementById(`inp-t1-${i}`);
    if (i0) i0.value = pool0[i];
    if (i1) i1.value = pool1[i];
  }
};

// Up/Down Main Menu Item Click & Hover Listeners
document.querySelectorAll('#updown-menu .updown-item').forEach((btn, idx) => {
  btn.addEventListener('mouseenter', () => {
    menuCursorIdx = idx;
    updateMenuCursorUI();
  });
  btn.addEventListener('click', () => {
    menuCursorIdx = idx;
    updateMenuCursorUI();
    activateMenuOption(idx);
  });
});

document.getElementById('btn-back-menu').onclick = () => {
  SND.init();
  SND.tick();
  readLobbyCustomization();
  lobbyModal.classList.remove('open');
  document.getElementById('splash-screen').classList.remove('hidden');
  appStage = 'SPLASH';
};

document.getElementById('btn-roster').onclick = openLobbyModal;

document.getElementById('btn-silk-web').onclick = () => {
  SND.init();
  if (!isCurrentTurnAI()) spinElasticSilkWeb();
};

document.getElementById('btn-procession').onclick = () => {
  processionConvoyEnabled = !processionConvoyEnabled;
  document.getElementById('lbl-procession').textContent =
    processionConvoyEnabled ? 'Processó: Auto [F]' : 'Processó: Sol [F]';
};

document.getElementById('btn-close-setup').onclick = () => {
  readLobbyCustomization();
  lobbyModal.classList.remove('open');
  appStage = 'PLAYING';
};

document.getElementById('btn-restart-match').onclick = () => {
  SND.init();
  readLobbyCustomization();
  hasStartedMatchOnce = true;
  lobbyModal.classList.remove('open');
  document.getElementById('splash-screen').classList.add('hidden');
  appStage = 'PLAYING';
  initMatch(true);
};

document.getElementById('btn-vic-lobby').onclick = () => {
  document.getElementById('victory-modal').classList.remove('open');
  openLobbyModal();
};

document.getElementById('btn-vic-rematch').onclick = () => {
  document.getElementById('victory-modal').classList.remove('open');
  initMatch(true);
};

document.getElementById('btn-mode').onclick = () => {
  const nextIdx = (GAME_MODES.indexOf(gameMode) + 1) % GAME_MODES.length;
  gameMode = GAME_MODES[nextIdx];
  document.getElementById('lbl-mode').textContent = MODE_SHORT[gameMode];
  aiPlan = null;
};

const btnMusicEl = document.getElementById('btn-music');
if (btnMusicEl) {
  btnMusicEl.onclick = e => {
    e.stopPropagation();
    SND.toggleMusic();
    SND.tick();
  };
}

const btnExitGameEl = document.getElementById('btn-exit-game');
if (btnExitGameEl) {
  btnExitGameEl.onclick = e => {
    e.stopPropagation();
    exitCurrentMatchToMenu();
  };
}

// Initialize background world with a random Catalan map and open directly on the Up/Down Player Selection Menu!
initMatch(true);
requestAnimationFrame(loop);
