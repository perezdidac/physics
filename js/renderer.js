"use strict";

// ═══════════════════════════════════════════════════════════════════════════
//  9. 2.5D REGIONAL PARALLAX PANORAMA & WEATHER RENDERER
// ═══════════════════════════════════════════════════════════════════════════
function getCameraTransform() {
  // Responsive base scale for Portrait Mobile, Landscape Mobile, and Desktop + Retina DPR scaling!
  const isPortrait = viewW < viewH && viewW <= 820;
  const isLandscapeMobile = viewH <= 540 && viewW > viewH;
  let cssBaseScale;
  if (isPortrait) {
    // Portrait phone (e.g. 390x844): frame ~460-540 world units horizontally so Cucs, names & terrain are crisp
    cssBaseScale = clamp(viewW / 600, 0.56, 0.86);
  } else if (isLandscapeMobile) {
    // Landscape phone (e.g. 844x390): fit vertical playfield comfortably between compact top & bottom HUDs
    cssBaseScale = clamp(Math.min(viewW / 1220, viewH / 580), 0.54, 0.88);
  } else {
    // Desktop / Tablet
    cssBaseScale = clamp(Math.min(viewW / 1620, viewH / 760), 0.85, 1.45);
  }
  const scale = cssBaseScale * canvasDpr * cam.zoom * userZoomMult;
  // In Portrait mode, shift camera center slightly down (+42 world px) so the active Cuc sits above the bottom touch controls!
  const portraitOffsetY = (isPortrait && appStage === 'PLAYING') ? 42 : 0;
  return {
    scale,
    cx: cam.x + cam.smoothMouseX,
    cy: cam.y + cam.smoothMouseY + portraitOffsetY
  };
}

function screenToWorld(clientX, clientY) {
  const rect = canvas.getBoundingClientRect();
  const sx = (clientX - rect.left) * (canvas.width / rect.width);
  const sy = (clientY - rect.top) * (canvas.height / rect.height);
  const tr = getCameraTransform();
  return {
    x: (sx - canvas.width * 0.5) / tr.scale + tr.cx,
    y: (sy - canvas.height * 0.5) / tr.scale + tr.cy
  };
}

function render() {
  const W = canvas.width;
  const H = canvas.height;
  const tr = getCameraTransform();
  const mCfg = MAPS[currentMapIdx];

  ctx.save();
  if (shake > 0.2) {
    ctx.translate((Math.random() - 0.5) * shake * 1.4, (Math.random() - 0.5) * shake * 1.4);
  }

  const dxCam = tr.cx - TERRAIN_W * 0.5;
  const dyCam = tr.cy - 400;

  // 1. Fallback Biome Sky Dome
  const skyGrad = ctx.createLinearGradient(0, 0, 0, H);
  skyGrad.addColorStop(0,    mCfg.sky[0]);
  skyGrad.addColorStop(0.32, mCfg.sky[1]);
  skyGrad.addColorStop(0.64, mCfg.sky[2]);
  skyGrad.addColorStop(0.86, mCfg.sky[3]);
  skyGrad.addColorStop(1.0,  mCfg.sky[4]);
  ctx.fillStyle = skyGrad;
  ctx.fillRect(0, 0, W, H);

  // 2. High-Resolution Scenic Regional Panorama with 2.5D Parallax Motion!
  const bgImg = BG_IMAGES[mCfg.id];
  if (bgImg && bgImg.complete && bgImg.naturalWidth > 0) {
    const imgAspect = bgImg.naturalWidth / bgImg.naturalHeight;
    // Overscan by 28% so moving the camera across 3200px shifts the scenic background smoothly without edges
    let drawW = W * 1.28;
    let drawH = drawW / imgAspect;
    if (drawH < H * 1.22) {
      drawH = H * 1.22;
      drawW = drawH * imgAspect;
    }
    const parX = -dxCam * 0.14 * tr.scale - cam.smoothMouseX * 1.6;
    const parY = -dyCam * 0.16 * tr.scale - cam.smoothMouseY * 1.3;
    const bx = (W - drawW) * 0.5 + clamp(parX, -(drawW - W) * 0.48, (drawW - W) * 0.48);
    const by = (H - drawH) * 0.5 + clamp(parY, -(drawH - H) * 0.48, (drawH - H) * 0.48);
    ctx.drawImage(bgImg, bx, by, drawW, drawH);

    // Subtle atmospheric depth grade so foreground destructible terrain pops
    const atmo = ctx.createLinearGradient(0, 0, 0, H);
    atmo.addColorStop(0, 'rgba(8, 10, 15, 0.12)');
    atmo.addColorStop(0.65, 'rgba(10, 14, 20, 0.08)');
    atmo.addColorStop(1, 'rgba(6, 10, 16, 0.38)');
    ctx.fillStyle = atmo;
    ctx.fillRect(0, 0, W, H);
  }

  // 3. Volumetric God-Rays, Sun Halo, Sky Birds & Multi-Layered Volumetric Clouds!
  drawSkyAtmosphereAndClouds(ctx, W, H, tr, dxCam, dyCam, mCfg);

  // ─────────────────────────────────────────────────────────────────
  // 4. 2.5D GAMEPLAY WORLD PLANE (1.0x Camera Transform)
  // ─────────────────────────────────────────────────────────────────
  ctx.save();
  ctx.translate(W * 0.5, H * 0.5);
  ctx.scale(tr.scale, tr.scale);
  ctx.translate(-tr.cx, -tr.cy);

  drawWaterBack(ctx);

  // 2.5D Extruded Interior Rock Wall
  const perspX = clamp((TERRAIN_W * 0.5 - tr.cx) * 0.018, -14, 14);
  const perspY = -9 + clamp((400 - tr.cy) * 0.02, -6, 6);
  ctx.drawImage(terrainBack, perspX, perspY);

  // Front Destructible Terrain (including destructible regional Pine Trees & Nests!)
  ctx.drawImage(terrainFront, 0, 0);

  // Hand-Painted Wind-Swaying Catalan Surface Flora (Rosemary & Ginesta in Montserrat, Agave in Cadaqués, Edelweiss in Taüll, Autumn Ferns in Castellfollit!)
  drawSurfaceFlora(ctx);

  // Dynamic Sun-Cast Ground Contact Shadows under Cucs, Barrels, Crates, Mines, Rovellons & Caganers!
  drawGroundContactShadows(ctx, mCfg);

  // Thermal Pine-Resin Updraft Currents
  for (const u of updrafts) {
    ctx.save();
    const ug = ctx.createLinearGradient(u.x, u.y, u.x, u.y - u.h);
    ug.addColorStop(0, 'rgba(246, 207, 119, 0.22)');
    ug.addColorStop(0.6, 'rgba(180, 235, 255, 0.12)');
    ug.addColorStop(1, 'rgba(180, 235, 255, 0)');
    ctx.fillStyle = ug;
    ctx.fillRect(u.x - u.w * 0.7, u.y - u.h, u.w * 1.4, u.h);

    ctx.strokeStyle = 'rgba(255, 235, 175, 0.36)';
    ctx.lineWidth = 1.4;
    for (let s = -1; s <= 1; s++) {
      const flowY = ((tNow * 95 + (s + 1) * 65) % u.h);
      const sx = u.x + s * 11 + Math.sin(tNow * 5 + s) * 4;
      const sy = u.y - flowY;
      ctx.beginPath();
      ctx.moveTo(sx, sy);
      ctx.quadraticCurveTo(sx + 4, sy - 14, sx - 2, sy - 28);
      ctx.stroke();
    }
    ctx.restore();
  }

  // Hanging Interactive Silk Nests ("Bolsones Vivos") in the Pine Trees!
  for (const nest of silkNests) {
    ctx.save();
    // Silk suspension thread
    ctx.strokeStyle = 'rgba(245, 240, 230, 0.78)';
    ctx.lineWidth = 1.8;
    ctx.beginPath();
    ctx.moveTo(nest.anchorX, nest.anchorY);
    ctx.lineTo(nest.x, nest.y);
    ctx.stroke();

    ctx.translate(nest.x, nest.y);
    const pulse = 1 + Math.sin(tNow * 5 + nest.swayPhase) * 0.05;
    ctx.scale(pulse, pulse);

    // Glow aura
    const ng = ctx.createRadialGradient(0, 0, 2, 0, 0, nest.r * 1.6);
    ng.addColorStop(0, 'rgba(255, 235, 175, 0.65)');
    ng.addColorStop(1, 'rgba(255, 235, 175, 0)');
    ctx.fillStyle = ng;
    ctx.beginPath();
    ctx.arc(0, 0, nest.r * 1.6, 0, Math.PI * 2);
    ctx.fill();

    // Silky white cocoon body
    ctx.fillStyle = '#f5f0e6';
    ctx.strokeStyle = '#d4a153';
    ctx.lineWidth = 1.6;
    ctx.beginPath();
    ctx.ellipse(0, 0, nest.r * 1.1, nest.r * 0.85, 0, 0, Math.PI * 2);
    ctx.fill();
    ctx.stroke();

    // Translucent wriggling caterpillar silhouettes inside the Bolsón cocoon!
    ctx.strokeStyle = 'rgba(65, 52, 42, 0.42)';
    ctx.lineWidth = 2.1;
    ctx.lineCap = 'round';
    for (let w = -1; w <= 1; w += 2) {
      const wx = w * 3.5 + Math.sin(tNow * 7 + w + nest.swayPhase) * 2.2;
      const wy = w * 1.8 + Math.cos(tNow * 6 + w) * 1.5;
      ctx.beginPath();
      ctx.moveTo(wx - 3.5, wy);
      ctx.quadraticCurveTo(wx, wy - 2.5, wx + 3.5, wy + 0.5);
      ctx.stroke();
    }

    // Webbing lines across the Bolsón
    ctx.strokeStyle = 'rgba(180, 165, 145, 0.55)';
    ctx.lineWidth = 1;
    ctx.beginPath();
    ctx.moveTo(-8, -4); ctx.lineTo(9, 3);
    ctx.moveTo(-7, 4);  ctx.lineTo(8, -4);
    ctx.stroke();
    ctx.restore();
  }

  // Spun Elastic Silk Web Trampolines & Shields ("Seda Elástica")!
  for (const w of silkWebs) {
    ctx.save();
    const midX = (w.x1 + w.x2) * 0.5;
    const midY = (w.y1 + w.y2) * 0.5;
    const dx = w.x2 - w.x1, dy = w.y2 - w.y1;
    const len = Math.max(1, Math.hypot(dx, dy));
    const nx = -dy / len, ny = dx / len;
    const vibOffset = Math.sin(tNow * 42) * (w.vibration || 0) * 9;

    // Anchor nodes
    ctx.fillStyle = '#fff6df';
    ctx.beginPath();
    ctx.arc(w.x1, w.y1, 3.5, 0, Math.PI * 2);
    ctx.arc(w.x2, w.y2, 3.5, 0, Math.PI * 2);
    ctx.fill();

    // Glowing silk strands
    for (let s = -1; s <= 1; s++) {
      ctx.strokeStyle = s === 0 ? 'rgba(255, 248, 225, 0.95)' : 'rgba(245, 185, 69, 0.55)';
      ctx.lineWidth = s === 0 ? 2.6 : 1.3;
      ctx.beginPath();
      ctx.moveTo(w.x1, w.y1);
      ctx.quadraticCurveTo(
        midX + nx * (vibOffset + s * 4),
        midY + ny * (vibOffset + s * 4),
        w.x2, w.y2
      );
      ctx.stroke();
    }
    ctx.restore();
  }

  // Golden Pine Nuts ("Piñones Dorados")
  for (const pn of pineNuts) {
    ctx.save();
    ctx.translate(pn.x, pn.y);
    const pg = ctx.createRadialGradient(0, 0, 1, 0, 0, 11);
    pg.addColorStop(0, 'rgba(255, 225, 115, 0.85)');
    pg.addColorStop(1, 'rgba(255, 190, 60, 0)');
    ctx.fillStyle = pg;
    ctx.beginPath();
    ctx.arc(0, 0, 11, 0, Math.PI * 2);
    ctx.fill();

    ctx.fillStyle = '#f6cf77';
    ctx.strokeStyle = '#6e471b';
    ctx.lineWidth = 1.4;
    ctx.beginPath();
    ctx.ellipse(0, 0, 5.5, 3.8, Math.sin(tNow * 4) * 0.3, 0, Math.PI * 2);
    ctx.fill();
    ctx.stroke();
    ctx.restore();
  }

  // Angry Micro-Larvae Swarms
  for (const sw of larvaeSwarms) {
    ctx.save();
    ctx.translate(sw.x, sw.y);
    for (let k = 0; k < 4; k++) {
      const lx = Math.cos(tNow * 12 + k * 1.6) * 7;
      const ly = Math.sin(tNow * 15 + k * 2.1) * 4;
      ctx.fillStyle = '#252934';
      ctx.strokeStyle = '#ffae42';
      ctx.lineWidth = 1;
      ctx.beginPath();
      ctx.ellipse(lx, ly, 4.2, 2.2, 0, 0, Math.PI * 2);
      ctx.fill();
      ctx.stroke();
    }
    ctx.restore();
  }

  for (const rv of rovellons) drawRovello(ctx, rv);
  for (const cg of caganers) drawCaganer(ctx, cg);
  for (const ol of escudelles) drawEscudella(ctx, ol);
  for (const tb of tombstones) drawTombstone(ctx, tb);
  for (const m of mines) drawMine(ctx, m);
  for (const c of crates) drawCrate(ctx, c);
  for (const b of barrels) drawBarrel(ctx, b);

  // Active Ganxo de Pastor (Pyrenean Shepherd's Crook Grapple Rope)
  for (const f of fighters) {
    if (f.alive && f.grapple) {
      ctx.save();
      ctx.strokeStyle = '#d9b372';
      ctx.lineWidth = 2.6;
      ctx.beginPath();
      ctx.moveTo(f.x, f.y - 4);
      ctx.lineTo(f.grapple.hookX, f.grapple.hookY);
      ctx.stroke();

      // Shepherd's iron crook at latch point
      ctx.strokeStyle = '#e2e8f0';
      ctx.lineWidth = 3.0;
      ctx.beginPath();
      ctx.arc(f.grapple.hookX, f.grapple.hookY, 6, 0, Math.PI * 1.35);
      ctx.stroke();
      ctx.restore();
    }
  }

  // Nose-to-Tail Golden Procession Silk Tethers between linked allied Orugas!
  for (const f of fighters) {
    if (!f.alive || f.drowning || !f.linkedAllies) continue;
    for (const ally of f.linkedAllies) {
      if (f.memberIdx < ally.memberIdx) {
        ctx.save();
        ctx.strokeStyle = f.team === 0 ? 'rgba(245, 185, 69, 0.78)' : 'rgba(234, 86, 72, 0.78)';
        ctx.lineWidth = 2.4;
        ctx.setLineDash([5, 3]);
        ctx.beginPath();
        ctx.moveTo(f.x, f.y + 2);
        ctx.quadraticCurveTo((f.x + ally.x) * 0.5, Math.min(f.y, ally.y) - 6, ally.x, ally.y + 2);
        ctx.stroke();
        ctx.restore();
      }
    }
  }

  // Spanish Oruga Procesionaria Squadrons!
  for (const f of fighters) {
    if (f.alive) drawFighter(ctx, f);
  }

  // Active Aiming Reticle & Charge Cone
  if (appStage === 'PLAYING' && (turnPhase === 'TURN_PLAY') && activeFighter && activeFighter.alive && !activeFighter.drowning && !isCurrentTurnAI()) {
    drawAimingHUD(ctx, activeFighter);
  }

  for (const pl of airstrikePlanes) drawAirstrikePlane(ctx, pl);
  for (const p of projectiles) drawProjectile(ctx, p);

  // Multi-Stage Volumetric Fireball Cores
  for (const fb of fireballs) {
    ctx.save();
    ctx.globalCompositeOperation = 'screen';
    const alpha = clamp(fb.life, 0, 1);
    const fg = ctx.createRadialGradient(fb.x, fb.y, fb.r * 0.08, fb.x, fb.y, fb.r);
    if (fb.isUrticating) {
      fg.addColorStop(0, `rgba(255, 235, 255, ${alpha})`);
      fg.addColorStop(0.4, `rgba(210, 105, 255, ${alpha * 0.82})`);
      fg.addColorStop(0.75, `rgba(125, 40, 190, ${alpha * 0.45})`);
      fg.addColorStop(1, 'rgba(90, 20, 140, 0)');
    } else {
      fg.addColorStop(0, `rgba(255, 252, 225, ${alpha})`);
      fg.addColorStop(0.32, `rgba(255, 198, 75, ${alpha * 0.92})`);
      fg.addColorStop(0.68, `rgba(242, 82, 28, ${alpha * 0.65})`);
      fg.addColorStop(1, 'rgba(120, 24, 10, 0)');
    }
    ctx.fillStyle = fg;
    ctx.beginPath();
    ctx.arc(fb.x, fb.y, fb.r, 0, Math.PI * 2);
    ctx.fill();
    ctx.restore();
  }

  // Volumetric Smoke
  for (const s of smokePuffs) {
    ctx.save();
    ctx.globalAlpha = Math.max(0, s.life * 0.72);
    const rg = ctx.createRadialGradient(s.x, s.y, 1, s.x, s.y, s.r);
    rg.addColorStop(0, s.color);
    rg.addColorStop(1, 'rgba(30, 28, 28, 0)');
    ctx.fillStyle = rg;
    ctx.beginPath();
    ctx.arc(s.x, s.y, s.r, 0, Math.PI * 2);
    ctx.fill();
    ctx.restore();
  }

  // Shockwaves
  for (const sw of shockwaves) {
    ctx.save();
    const col = sw.color || '255, 225, 175';
    ctx.strokeStyle = `rgba(${col}, ${sw.alpha * 0.68})`;
    ctx.lineWidth = 3.2;
    ctx.beginPath();
    ctx.arc(sw.x, sw.y, sw.r, 0, Math.PI * 2);
    ctx.stroke();
    ctx.restore();
  }

  // Water Plume Columns & Surface Foam Rings
  for (const wp of waterPlumes) {
    ctx.save();
    ctx.globalAlpha = clamp(wp.life, 0, 1);
    const pg = ctx.createLinearGradient(wp.x, wp.y - wp.h, wp.x, wp.y + 8);
    pg.addColorStop(0, 'rgba(235, 250, 255, 0.92)');
    pg.addColorStop(1, 'rgba(110, 195, 235, 0.2)');
    ctx.fillStyle = pg;
    ctx.beginPath();
    ctx.moveTo(wp.x - wp.w * 0.6, wp.y + 4);
    ctx.quadraticCurveTo(wp.x, wp.y - wp.h * 1.4, wp.x + wp.w * 0.6, wp.y + 4);
    ctx.closePath();
    ctx.fill();

    ctx.strokeStyle = 'rgba(235, 250, 255, 0.85)';
    ctx.lineWidth = 3;
    ctx.beginPath();
    ctx.ellipse(wp.x, wp.y, wp.ringR, wp.ringR * 0.22, 0, 0, Math.PI * 2);
    ctx.stroke();
    ctx.restore();
  }

  // Sparks, Bouncing Embers, Debris, Urticating Bristle Hairs & Shotgun Beams
  for (const p of particles) {
    ctx.save();
    ctx.globalAlpha = Math.max(0, Math.min(1, p.life));
    if (p.isBeam) {
      ctx.strokeStyle = 'rgba(255, 238, 185, 0.85)';
      ctx.lineWidth = 3;
      ctx.beginPath();
      ctx.moveTo(p.x1, p.y1);
      ctx.lineTo(p.x2, p.y2);
      ctx.stroke();
    } else if (p.isEmber) {
      const eg = ctx.createRadialGradient(p.x, p.y, 0.5, p.x, p.y, 5.5);
      eg.addColorStop(0, '#fff9d6');
      eg.addColorStop(0.45, p.color);
      eg.addColorStop(1, 'rgba(255, 80, 20, 0)');
      ctx.fillStyle = eg;
      ctx.beginPath();
      ctx.arc(p.x, p.y, 5.5, 0, Math.PI * 2);
      ctx.fill();
    } else if (p.isHair) {
      ctx.translate(p.x, p.y);
      ctx.rotate(p.rot);
      ctx.strokeStyle = p.color;
      ctx.lineWidth = 1.6;
      ctx.beginPath();
      ctx.moveTo(-4, 0);
      ctx.quadraticCurveTo(0, -2, 4, 0);
      ctx.stroke();
    } else if (p.isSpark) {
      ctx.strokeStyle = p.color;
      ctx.lineWidth = 2.2;
      ctx.beginPath();
      ctx.moveTo(p.x, p.y);
      ctx.lineTo(p.x - p.vx * 0.028, p.y - p.vy * 0.028);
      ctx.stroke();
    } else {
      ctx.fillStyle = p.color;
      ctx.translate(p.x, p.y);
      ctx.rotate(p.rot);
      ctx.fillRect(-p.w / 2, -p.h / 2, p.w, p.h);
    }
    ctx.restore();
  }

  // Dynamic Explosion Point-Light Flash
  if (flashLight > 0.01) {
    ctx.save();
    ctx.globalCompositeOperation = 'screen';
    const fg = ctx.createRadialGradient(flashPos.x, flashPos.y, 8, flashPos.x, flashPos.y, 360);
    fg.addColorStop(0, `rgba(255, 205, 120, ${flashLight * 0.82})`);
    fg.addColorStop(0.5, `rgba(255, 115, 40, ${flashLight * 0.38})`);
    fg.addColorStop(1, 'rgba(255, 90, 20, 0)');
    ctx.fillStyle = fg;
    ctx.beginPath();
    ctx.arc(flashPos.x, flashPos.y, 360, 0, Math.PI * 2);
    ctx.fill();
    ctx.restore();
  }

  drawWaterFront(ctx);

  for (const b of bubbles) {
    ctx.save();
    ctx.strokeStyle = 'rgba(220, 245, 255, 0.85)';
    ctx.fillStyle = 'rgba(180, 230, 255, 0.28)';
    ctx.lineWidth = 1.4;
    ctx.beginPath();
    ctx.arc(b.x + Math.sin(tNow * 8 + b.wobble) * 3, b.y, b.r, 0, Math.PI * 2);
    ctx.fill();
    ctx.stroke();
    ctx.restore();
  }

  // Oruga Speech Bubbles ("¡A por el pino!", "¡Polvo urticante!")
  for (const sb of speechBubbles) {
    if (!sb.fighter || !sb.fighter.alive || sb.fighter.drowning) continue;
    ctx.save();
    ctx.globalAlpha = clamp(sb.life * 1.5, 0, 1);
    ctx.font = '700 11px "Plus Jakarta Sans", sans-serif';
    const tw = ctx.measureText(sb.text).width + 16;
    const bx = sb.fighter.x;
    const by = sb.fighter.y - 54;
    ctx.fillStyle = 'rgba(15, 18, 25, 0.92)';
    ctx.strokeStyle = '#f6cf77';
    ctx.lineWidth = 1.3;
    ctx.beginPath();
    ctx.roundRect(bx - tw / 2, by - 14, tw, 20, 4);
    ctx.fill();
    ctx.stroke();
    ctx.fillStyle = '#fff5df';
    ctx.textAlign = 'center';
    ctx.fillText(sb.text, bx, by);
    ctx.restore();
  }

  // Floating Damage & Callout Numbers
  for (const ft of floatingTexts) {
    ctx.save();
    ctx.globalAlpha = clamp(ft.life, 0, 1);
    ctx.font = '800 13.5px "Plus Jakarta Sans", sans-serif';
    ctx.textAlign = 'center';
    ctx.fillStyle = '#000';
    ctx.fillText(ft.text, ft.x + 1, ft.y + 1);
    ctx.fillStyle = ft.color;
    ctx.fillText(ft.text, ft.x, ft.y);
    ctx.restore();
  }

  ctx.restore(); // End 1.0x World Plane

  // 5. Dynamic Regional Weather Layer (Seattle Rain, Catalonia Pine Pollen, SF Fog & Gulls)
  drawWeatherLayer(ctx, W, H, tr, dxCam, dyCam, mCfg.weather);

  // 5b. Off-Screen High-Altitude Projectile Tracker Pill & Tactile Touch Gesture Ripples!
  if (appStage === 'PLAYING') {
    for (const p of projectiles) {
      const sx = W * 0.5 + (p.x - tr.cx) * tr.scale;
      const sy = H * 0.5 + (p.y - tr.cy) * tr.scale;
      if (sy < 14 * canvasDpr) {
        const clampedX = clamp(sx, 48 * canvasDpr, W - 48 * canvasDpr);
        const topY = 58 * canvasDpr;
        const metersUp = Math.max(1, Math.round((tr.cy - (H * 0.5) / tr.scale - p.y) * 0.12));
        ctx.save();
        ctx.fillStyle = 'rgba(11, 14, 22, 0.88)';
        ctx.strokeStyle = p.type === 'HOLY' ? '#ffd966' : (p.isUrticating ? '#d88aff' : '#ff8b3d');
        ctx.lineWidth = 1.6 * canvasDpr;
        const pw = 62 * canvasDpr, ph = 20 * canvasDpr;
        ctx.beginPath();
        ctx.roundRect(clampedX - pw * 0.5, topY, pw, ph, 10 * canvasDpr);
        ctx.fill();
        ctx.stroke();

        ctx.fillStyle = '#fff8eb';
        ctx.font = `800 ${Math.round(10.5 * canvasDpr)}px "JetBrains Mono", monospace`;
        ctx.textAlign = 'center';
        ctx.fillText(`▲ ${metersUp}m`, clampedX, topY + 13.5 * canvasDpr);
        ctx.restore();
      }
    }

    for (const rp of touchRipples) {
      ctx.save();
      const alpha = clamp(rp.life, 0, 1);
      ctx.strokeStyle = rp.color || `rgba(245, 185, 69, ${alpha * 0.85})`;
      ctx.globalAlpha = alpha;
      ctx.lineWidth = 2.4 * canvasDpr;
      ctx.beginPath();
      ctx.arc(rp.x * canvasDpr, rp.y * canvasDpr, rp.r * canvasDpr, 0, Math.PI * 2);
      ctx.stroke();
      if (rp.label) {
        ctx.font = `800 ${Math.round(10.5 * canvasDpr)}px "Plus Jakarta Sans", sans-serif`;
        ctx.textAlign = 'center';
        ctx.fillStyle = '#ffe082';
        ctx.fillText(rp.label, rp.x * canvasDpr, (rp.y - rp.r - 8) * canvasDpr);
      }
      ctx.restore();
    }
  }

  // 6. Special Foreground Animated Procession on Splash Screen!
  if (appStage === 'SPLASH') {
    drawSplashProcessionSilhouette(ctx, W, H);
  }

  // Cinematic Vignette
  const vig = ctx.createRadialGradient(W * 0.5, H * 0.5, Math.min(W, H) * 0.4, W * 0.5, H * 0.5, Math.max(W, H) * 0.76);
  vig.addColorStop(0, 'rgba(0, 0, 0, 0)');
  vig.addColorStop(1, 'rgba(5, 6, 9, 0.58)');
  ctx.fillStyle = vig;
  ctx.fillRect(0, 0, W, H);

  ctx.restore();
}

function drawSplashProcessionSilhouette(ctx, W, H) {
  // Draws a dramatic close-up pine branch with a nose-to-tail procession of Orugas Procesionarias marching across!
  ctx.save();
  const branchY = H * 0.74;
  ctx.strokeStyle = '#12151c';
  ctx.lineWidth = 14;
  ctx.beginPath();
  ctx.moveTo(0, branchY + 18);
  ctx.quadraticCurveTo(W * 0.5, branchY - 12, W, branchY + 10);
  ctx.stroke();

  const marchSpeed = 48;
  const totalSpan = W + 400;
  for (let c = 0; c < 6; c++) {
    const headX = ((tNow * marchSpeed + c * 92) % totalSpan) - 200;
    const slopeT = headX / Math.max(1, W);
    const baseY = (1 - slopeT) * (1 - slopeT) * (branchY + 18) +
                  2 * (1 - slopeT) * slopeT * (branchY - 12) +
                  slopeT * slopeT * (branchY + 10) - 10;

    for (let s = 5; s >= 0; s--) {
      const sx = headX - s * 11;
      const sy = baseY + Math.sin(tNow * 9 - s * 0.9 + c) * 2.4;
      const r = s === 0 ? 7.5 : 6.5 - s * 0.35;

      // Bristly golden/white aura hairs
      ctx.strokeStyle = 'rgba(246, 207, 119, 0.55)';
      ctx.lineWidth = 1.2;
      for (let h = -3; h <= 3; h++) {
        const ha = -Math.PI * 0.5 + h * 0.35;
        ctx.beginPath();
        ctx.moveTo(sx + Math.cos(ha) * r, sy + Math.sin(ha) * r);
        ctx.lineTo(sx + Math.cos(ha) * (r + 6), sy + Math.sin(ha) * (r + 6));
        ctx.stroke();
      }

      ctx.fillStyle = s === 0 ? '#16181f' : '#252934';
      ctx.beginPath();
      ctx.arc(sx, sy, r, 0, Math.PI * 2);
      ctx.fill();

      if (s > 0) {
        ctx.fillStyle = '#e6772e';
        ctx.beginPath();
        ctx.ellipse(sx, sy - r * 0.45, r * 0.65, r * 0.35, 0, 0, Math.PI * 2);
        ctx.fill();
      } else {
        ctx.fillStyle = '#f5b945';
        ctx.beginPath();
        ctx.arc(sx + 3, sy - 1, 1.8, 0, Math.PI * 2);
        ctx.fill();
      }
    }
  }
  ctx.restore();
}

function drawSkyAtmosphereAndClouds(ctx, W, H, tr, dxCam, dyCam, mCfg) {
  ctx.save();

  // 1. Celestial Sun / Golden-Hour Glow & Angled Volumetric God-Rays across the 4 Catalan Comarques
  const sunX = W * (mCfg.id === 'MONTSERRAT' ? 0.68 : (mCfg.id === 'CADAQUES' ? 0.30 : (mCfg.id === 'TAULL' ? 0.44 : 0.62))) - dxCam * 0.04 * tr.scale;
  const sunY = H * 0.19 - dyCam * 0.04 * tr.scale;
  const sunCol = mCfg.id === 'MONTSERRAT' ? '255, 205, 115'
    : (mCfg.id === 'CADAQUES' ? '255, 232, 165'
    : (mCfg.id === 'TAULL' ? '210, 235, 255' : '255, 198, 125'));

  const sunGlow = ctx.createRadialGradient(sunX, sunY, 8 * tr.scale, sunX, sunY, 340 * tr.scale);
  sunGlow.addColorStop(0, `rgba(${sunCol}, 0.42)`);
  sunGlow.addColorStop(0.35, `rgba(${sunCol}, 0.16)`);
  sunGlow.addColorStop(1, `rgba(${sunCol}, 0)`);
  ctx.fillStyle = sunGlow;
  ctx.beginPath();
  ctx.arc(sunX, sunY, 340 * tr.scale, 0, Math.PI * 2);
  ctx.fill();

  // Soft angled volumetric God-Rays slanting across the sky
  ctx.save();
  ctx.globalCompositeOperation = 'screen';
  for (let r = 0; r < 5; r++) {
    const rayPhase = tNow * 0.28 + r * 1.35;
    const rayAlpha = (0.045 + Math.sin(rayPhase) * 0.02) * (mCfg.id === 'TAULL' ? 0.78 : 1.0);
    const rx = sunX + (r - 2) * 140 * tr.scale;
    const spread = (65 + (r % 2) * 35) * tr.scale;
    const slant = (wind * 0.9 + (r - 1.5) * 55) * tr.scale;
    const rg = ctx.createLinearGradient(rx, sunY, rx + slant, H * 0.88);
    rg.addColorStop(0, `rgba(${sunCol}, ${rayAlpha * 1.4})`);
    rg.addColorStop(0.65, `rgba(${sunCol}, ${rayAlpha * 0.55})`);
    rg.addColorStop(1, `rgba(${sunCol}, 0)`);
    ctx.fillStyle = rg;
    ctx.beginPath();
    ctx.moveTo(rx - spread * 0.35, sunY);
    ctx.lineTo(rx + spread * 0.35, sunY);
    ctx.lineTo(rx + slant + spread * 1.5, H * 0.92);
    ctx.lineTo(rx + slant - spread * 1.5, H * 0.92);
    ctx.closePath();
    ctx.fill();
  }
  ctx.restore();

  // 2. Subtle Tiled Cumulus / Pyrenees & Valley Mist Veil (Base atmospheric cloud sheet)
  if (ASSETS.cloudLayer) {
    ctx.save();
    ctx.globalAlpha = mCfg.id === 'TAULL' ? 0.48 : 0.34;
    const cw = Math.max(400, ASSETS.cloudLayer.width * tr.scale);
    const ch = ASSETS.cloudLayer.height * tr.scale;
    const drift = (tNow * (10 + wind * 0.25)) % ASSETS.cloudLayer.width;
    const baseOx = -(((dxCam * 0.14 - drift) * tr.scale) % cw);
    const oy = (mCfg.id === 'MONTSERRAT' ? H * 0.14 : H * 0.04) - dyCam * 0.10 * tr.scale;
    for (let tileX = baseOx - cw * 2; tileX < W + cw; tileX += cw) {
      ctx.drawImage(ASSETS.cloudLayer, tileX, oy, cw, ch);
    }
    ctx.restore();
  }

  // 3. Flocking Catalan Sky Birds (Gavines de Cap de Creus, Àligues de Montserrat & Trencalossos Pirinencs)
  ctx.save();
  ctx.strokeStyle = (mCfg.id === 'MONTSERRAT' || mCfg.id === 'CASTELLFOLLIT') ? 'rgba(42, 26, 22, 0.58)' : 'rgba(28, 38, 48, 0.55)';
  ctx.lineWidth = 1.6 * tr.scale;
  ctx.lineCap = 'round';
  for (const b of skyBirds) {
    const sx = W * 0.5 + (b.x - TERRAIN_W * 0.5 - dxCam * b.z) * tr.scale;
    const sy = H * 0.5 + (b.y - 400 - dyCam * b.z + Math.sin(tNow * 2.5 + b.wingPhase) * 6) * tr.scale;
    if (sx < -60 || sx > W + 60) continue;
    const flap = Math.sin(tNow * 8.5 + b.wingPhase) * b.size * 0.65 * tr.scale;
    const span = b.size * tr.scale;
    ctx.beginPath();
    ctx.moveTo(sx - span, sy - flap);
    ctx.quadraticCurveTo(sx - span * 0.4, sy - span * 0.35, sx, sy);
    ctx.quadraticCurveTo(sx + span * 0.4, sy - span * 0.35, sx + span, sy - flap);
    ctx.stroke();
  }
  ctx.restore();

  // 4. Multi-Layered Sculpted Volumetric Clouds (3 Parallax Depth Tiers reacting to live Wind!)
  const rimCol = (mCfg.id === 'MONTSERRAT' || mCfg.id === 'CASTELLFOLLIT') ? '#fff0d4' : (mCfg.id === 'CADAQUES' ? '#fff9eb' : '#ebf5ff');
  const midCol = (mCfg.id === 'MONTSERRAT' || mCfg.id === 'CASTELLFOLLIT') ? '#f0cbb0' : (mCfg.id === 'CADAQUES' ? '#dce6f0' : '#c4d6e8');
  const shdCol = (mCfg.id === 'MONTSERRAT' || mCfg.id === 'CASTELLFOLLIT') ? 'rgba(98, 74, 88, 0.42)' : 'rgba(68, 84, 104, 0.42)';

  for (const c of cloudFlock) {
    const cx = W * 0.5 + (c.x - TERRAIN_W * 0.5 - dxCam * c.z) * tr.scale;
    const bob = Math.sin(tNow * 0.9 + c.bobPhase) * 4;
    const cy = H * 0.5 + (c.y + bob - 400 - dyCam * c.z) * tr.scale;
    if (cx < -320 * tr.scale || cx > W + 320 * tr.scale) continue;

    ctx.save();
    ctx.translate(cx, cy);
    ctx.scale(tr.scale, tr.scale);
    ctx.globalAlpha = c.tier === 0 ? 0.52 : (c.tier === 1 ? 0.76 : 0.46);

    // Subtle wind-shear lean on cloud puffs when wind is strong
    const windShear = clamp(wind * 0.0018, -0.18, 0.18);
    ctx.transform(1, 0, windShear, 1, 0, 0);

    // Pass 1: Cool ambient underside shadow base
    ctx.fillStyle = shdCol;
    ctx.beginPath();
    for (const lb of c.lobes) {
      ctx.moveTo(lb.ox + lb.rx, lb.oy + 7);
      ctx.ellipse(lb.ox, lb.oy + 7, lb.rx * 0.98, lb.ry * 0.88, 0, 0, Math.PI * 2);
    }
    ctx.fill();

    // Pass 2: Soft mid-tone cloud body
    ctx.fillStyle = midCol;
    ctx.beginPath();
    for (const lb of c.lobes) {
      ctx.moveTo(lb.ox + lb.rx, lb.oy + 2);
      ctx.ellipse(lb.ox, lb.oy + 2, lb.rx, lb.ry * 0.92, 0, 0, Math.PI * 2);
    }
    ctx.fill();

    // Pass 3: Sunlit ivory/golden top crown highlight
    ctx.fillStyle = rimCol;
    ctx.beginPath();
    for (const lb of c.lobes) {
      ctx.moveTo(lb.ox + lb.rx * 0.92, lb.oy - 4);
      ctx.ellipse(lb.ox - 2, lb.oy - 4, lb.rx * 0.92, lb.ry * 0.82, 0, 0, Math.PI * 2);
    }
    ctx.fill();

    ctx.restore();
  }

  ctx.restore();
}

function drawSurfaceFlora(ctx) {
  ctx.save();
  for (const fl of surfaceFlora) {
    const sway = Math.sin(tNow * 2.8 + fl.phase) * (0.08 + Math.abs(wind) * 0.0028) + wind * 0.0035;
    ctx.save();
    ctx.translate(fl.x, fl.y);
    ctx.scale(fl.scale, fl.scale);
    ctx.rotate(sway);

    if (fl.type === 'MONTSERRAT') {
      // Mediterranean Rosemary ("Romaní") & Golden Broom ("Ginesta")
      ctx.strokeStyle = '#3b5c34';
      ctx.lineWidth = 1.6;
      ctx.lineCap = 'round';
      for (let b = -2; b <= 2; b++) {
        const bx = b * 3.2;
        const bh = 9 + (2 - Math.abs(b)) * 3;
        ctx.beginPath();
        ctx.moveTo(0, 1);
        ctx.quadraticCurveTo(bx * 0.5, -bh * 0.5, bx, -bh);
        ctx.stroke();

        // Blossom dots (golden ginesta or violet romaní)
        ctx.fillStyle = fl.variant === 0 ? '#ffd54f' : '#b39ddb';
        ctx.beginPath();
        ctx.arc(bx, -bh, 1.6, 0, Math.PI * 2);
        ctx.fill();
      }
    } else if (fl.type === 'CADAQUES') {
      if (fl.variant === 0) {
        // Cap de Creus Coastal Agave ("Atzavara") rosette
        ctx.fillStyle = '#4e7a6b';
        ctx.strokeStyle = '#254238';
        ctx.lineWidth = 1.1;
        for (let b = -2; b <= 2; b++) {
          ctx.save();
          ctx.rotate(b * 0.36);
          ctx.beginPath();
          ctx.moveTo(-2, 1);
          ctx.quadraticCurveTo(0, -13, 0, -15);
          ctx.quadraticCurveTo(0, -13, 2, 1);
          ctx.closePath();
          ctx.fill();
          ctx.stroke();
          ctx.restore();
        }
      } else {
        // Prickly Pear ("Figuera de Moro") & white coastal sea-daisies
        ctx.fillStyle = '#5c8c46';
        ctx.strokeStyle = '#2b471f';
        ctx.lineWidth = 1.1;
        ctx.beginPath();
        ctx.ellipse(0, -5, 4.5, 5.5, 0, 0, Math.PI * 2);
        ctx.ellipse(-4.5, -11, 3.2, 4.2, -0.35, 0, Math.PI * 2);
        ctx.ellipse(4.2, -10, 3.0, 3.8, 0.35, 0, Math.PI * 2);
        ctx.fill();
        ctx.stroke();
        ctx.fillStyle = '#ff7043';
        ctx.beginPath();
        ctx.arc(-6, -15, 1.7, 0, Math.PI * 2);
        ctx.arc(5.5, -13.5, 1.6, 0, Math.PI * 2);
        ctx.fill();
      }
    } else if (fl.type === 'TAULL') {
      // Pyrenean Alpine Edelweiss ("Flor de Neu") & snow-dusted shoots
      ctx.strokeStyle = '#4a6b53';
      ctx.lineWidth = 1.5;
      ctx.beginPath();
      ctx.moveTo(0, 1);
      ctx.lineTo(0, -10);
      ctx.stroke();
      ctx.fillStyle = '#f4f9ff';
      for (let p = 0; p < 5; p++) {
        const a = (p / 5) * Math.PI * 2;
        ctx.beginPath();
        ctx.ellipse(Math.cos(a) * 3.2, -10 + Math.sin(a) * 3.2, 2.2, 1.1, a, 0, Math.PI * 2);
        ctx.fill();
      }
      ctx.fillStyle = '#ffe082';
      ctx.beginPath();
      ctx.arc(0, -10, 1.5, 0, Math.PI * 2);
      ctx.fill();
    } else {
      // Castellfollit / La Garrotxa Autumn Ferns & Red/Amber Beech Saplings
      const col = fl.variant === 0 ? '#d9531e' : (fl.variant === 1 ? '#e89b2d' : '#6e8c3a');
      ctx.strokeStyle = '#4a2e18';
      ctx.lineWidth = 1.4;
      for (let b = -1; b <= 1; b++) {
        ctx.beginPath();
        ctx.moveTo(0, 1);
        ctx.quadraticCurveTo(b * 4, -6, b * 6, -11);
        ctx.stroke();
        ctx.fillStyle = col;
        ctx.beginPath();
        ctx.ellipse(b * 5, -9, 3.4, 2.0, b * 0.4, 0, Math.PI * 2);
        ctx.fill();
      }
    }

    ctx.restore();
  }
  ctx.restore();
}

function drawGroundContactShadows(ctx, mCfg) {
  ctx.save();
  // Sun-cast directional offset based on regional sun position
  const sunShiftX = (mCfg.id === 'MONTSERRAT' || mCfg.id === 'CASTELLFOLLIT') ? -3.5 : (mCfg.id === 'CADAQUES' ? 3.5 : 1.0);

  const drawShadow = (x, y, rx, ry, alpha) => {
    const sy = findSurfaceY(x, y - 4);
    const dist = sy - y;
    if (dist < -6 || dist > 54 || sy >= WATER_Y) return;
    const falloff = clamp(1 - Math.max(0, dist) / 54, 0.15, 1.0);
    ctx.fillStyle = `rgba(6, 8, 14, ${alpha * falloff})`;
    ctx.beginPath();
    ctx.ellipse(x + sunShiftX * (0.4 + (1 - falloff) * 0.8), sy + 1, rx * (0.7 + falloff * 0.35), ry, 0, 0, Math.PI * 2);
    ctx.fill();
  };

  for (const f of fighters) {
    if (!f.alive || f.drowning) continue;
    drawShadow(f.x, f.y + f.r, 12.5, 3.8, 0.44);
    if (f.segs) {
      for (let i = 0; i < f.segs.length; i += 2) {
        drawShadow(f.segs[i].x, f.segs[i].y + 5, 7.5 - i * 0.5, 2.5, 0.32);
      }
    }
  }
  for (const b of barrels) drawShadow(b.x, b.y + b.r, 14, 4.2, 0.48);
  for (const c of crates) drawShadow(c.x, c.y + 10, 12, 3.6, 0.45);
  for (const m of mines) drawShadow(m.x, m.y + 4, 9, 2.8, 0.42);
  for (const rv of rovellons) drawShadow(rv.x, rv.y, rv.r * 0.9, 3.8, 0.44);
  for (const cg of caganers) drawShadow(cg.x, cg.y + 7, 10, 3.2, 0.44);
  for (const tb of tombstones) drawShadow(tb.x, tb.y + 10, 11, 3.4, 0.46);

  ctx.restore();
}

function drawRovello(ctx, rv) {
  ctx.save();
  ctx.translate(rv.x, rv.y);
  ctx.scale(2 - rv.squash, rv.squash);

  // Soft warm spore glow around the Catalan Rovelló mushroom
  const rg = ctx.createRadialGradient(0, -10, 2, 0, -10, rv.r * 1.5);
  rg.addColorStop(0, 'rgba(255, 165, 75, 0.38)');
  rg.addColorStop(1, 'rgba(255, 140, 45, 0)');
  ctx.fillStyle = rg;
  ctx.beginPath();
  ctx.arc(0, -10, rv.r * 1.5, 0, Math.PI * 2);
  ctx.fill();

  // Creamy terracotta stalk (peu del rovelló)
  ctx.fillStyle = '#f2d8bd';
  ctx.strokeStyle = '#5c3118';
  ctx.lineWidth = 1.5;
  ctx.beginPath();
  ctx.roundRect(-5.5, -13, 11, 15, 3);
  ctx.fill();
  ctx.stroke();

  // Iconic wavy funnel-shaped Saffron Milk Cap (Lactarius deliciosus)
  const capG = ctx.createLinearGradient(0, -22, 0, -9);
  capG.addColorStop(0, '#ff8833');
  capG.addColorStop(0.6, '#d9531e');
  capG.addColorStop(1, '#8c2d10');
  ctx.fillStyle = capG;
  ctx.beginPath();
  ctx.moveTo(-rv.r, -11);
  ctx.bezierCurveTo(-rv.r * 0.85, -23, -4, -18, 0, -16);
  ctx.bezierCurveTo(4, -18, rv.r * 0.85, -23, rv.r, -11);
  ctx.quadraticCurveTo(0, -7, -rv.r, -11);
  ctx.closePath();
  ctx.fill();
  ctx.stroke();

  // Concentric terracotta rings & characteristic green Rovelló oxidation spots!
  ctx.strokeStyle = 'rgba(255, 215, 165, 0.55)';
  ctx.lineWidth = 1.1;
  ctx.beginPath();
  ctx.arc(0, -13, rv.r * 0.58, Math.PI * 1.1, Math.PI * 1.9);
  ctx.stroke();

  ctx.fillStyle = '#4e8c45';
  ctx.beginPath();
  ctx.arc(-rv.r * 0.45, -14, 1.8, 0, Math.PI * 2);
  ctx.arc(rv.r * 0.38, -13, 1.5, 0, Math.PI * 2);
  ctx.fill();

  ctx.restore();
}

function drawCaganer(ctx, cg) {
  ctx.save();
  const bob = Math.sin(tNow * 3.5 + cg.bobPhase) * 1.5;
  ctx.translate(cg.x, cg.y + bob);

  // Lucky golden aura
  const hg = ctx.createRadialGradient(0, -4, 2, 0, -4, 20);
  hg.addColorStop(0, 'rgba(255, 224, 102, 0.72)');
  hg.addColorStop(1, 'rgba(255, 195, 50, 0)');
  ctx.fillStyle = hg;
  ctx.beginPath();
  ctx.arc(0, -4, 20, 0, Math.PI * 2);
  ctx.fill();

  // Tiny "sort" coil on the ground behind the crouching figurine
  ctx.fillStyle = '#6e421c';
  ctx.strokeStyle = '#ffd966';
  ctx.lineWidth = 0.9;
  ctx.beginPath();
  ctx.ellipse(-6, 5, 3.8, 2.2, 0, 0, Math.PI * 2);
  ctx.fill();
  ctx.stroke();

  // Crouching black peasant trousers & red faixa (sash)
  ctx.fillStyle = '#1d2028';
  ctx.beginPath();
  ctx.ellipse(-1, 3, 5.5, 3.8, 0, 0, Math.PI * 2);
  ctx.fill();
  ctx.fillStyle = '#d93226';
  ctx.fillRect(-4.5, -1, 8, 2.5);

  // White peasant shirt torso
  ctx.fillStyle = '#f7f3e8';
  ctx.strokeStyle = '#241a14';
  ctx.lineWidth = 1.2;
  ctx.beginPath();
  ctx.roundRect(-4.5, -7, 8.5, 6.5, 2.5);
  ctx.fill();
  ctx.stroke();

  // Smiling rosy head
  ctx.fillStyle = '#f2c199';
  ctx.beginPath();
  ctx.arc(0.5, -10.5, 4.2, 0, Math.PI * 2);
  ctx.fill();
  ctx.stroke();

  // Iconic Red Catalan Barretina Cap with black band!
  ctx.fillStyle = '#181a20';
  ctx.fillRect(-3.5, -14, 8, 2);
  ctx.fillStyle = '#e02f24';
  ctx.beginPath();
  ctx.moveTo(-3.5, -14);
  ctx.lineTo(1, -20);
  ctx.lineTo(6.5, -16);
  ctx.lineTo(4.5, -14);
  ctx.closePath();
  ctx.fill();
  ctx.stroke();

  ctx.restore();
}

function drawEscudella(ctx, ol) {
  ctx.save();
  ctx.translate(ol.x, ol.y);

  // Glowing wood embers underneath the cauldron
  ctx.fillStyle = Math.sin(tNow * 9 + ol.steamPhase) > 0 ? '#ff7b29' : '#e03e1a';
  ctx.beginPath();
  ctx.ellipse(0, 11, 11, 3.2, 0, 0, Math.PI * 2);
  ctx.fill();

  // Traditional black cast-iron Catalan Olla d'Escudella pot
  ctx.fillStyle = '#23262e';
  ctx.strokeStyle = '#0e1014';
  ctx.lineWidth = 1.6;
  ctx.beginPath();
  ctx.arc(0, 1, 13, 0, Math.PI, false);
  ctx.lineTo(-11, -6);
  ctx.lineTo(11, -6);
  ctx.closePath();
  ctx.fill();
  ctx.stroke();

  // Side iron handles
  ctx.strokeStyle = '#3a3f4b';
  ctx.lineWidth = 1.8;
  ctx.beginPath();
  ctx.arc(-12, -2, 3.2, Math.PI * 0.5, Math.PI * 1.5);
  ctx.stroke();
  ctx.beginPath();
  ctx.arc(12, -2, 3.2, -Math.PI * 0.5, Math.PI * 0.5);
  ctx.stroke();

  // Simmering golden Escudella broth rim
  ctx.fillStyle = '#f2b949';
  ctx.beginPath();
  ctx.ellipse(0, -6, 10.5, 3.5, 0, 0, Math.PI * 2);
  ctx.fill();
  ctx.stroke();

  // Giant Catalan "Pilota" (spiced meatball) & Galet pasta bobbing in the broth!
  const bob = Math.sin(tNow * 4.5 + ol.steamPhase) * 1.1;
  ctx.fillStyle = '#a86438';
  ctx.strokeStyle = '#4a2810';
  ctx.lineWidth = 1.1;
  ctx.beginPath();
  ctx.ellipse(-2, -7.2 + bob, 5.2, 3.6, -0.1, 0, Math.PI * 2);
  ctx.fill();
  ctx.stroke();

  // White Galet pasta shell beside the Pilota
  ctx.fillStyle = '#fff5df';
  ctx.beginPath();
  ctx.arc(4.5, -6.5 - bob * 0.6, 2.8, 0, Math.PI * 2);
  ctx.fill();

  ctx.restore();
}

function drawWeatherLayer(ctx, W, H, tr, dxCam, dyCam, weatherType) {
  ctx.save();

  // 1. Live Wind-Stream Air Ribbons (Visually show wind speed, direction & gusts in real time!)
  const windMag = Math.abs(wind);
  if (windMag > 4) {
    const dir = wind >= 0 ? 1 : -1;
    const ribbonCol = wind >= 0 ? '255, 226, 155' : '165, 228, 255';
    ctx.lineCap = 'round';
    for (const r of windRibbons) {
      const sx = W * 0.5 + (r.x - TERRAIN_W * 0.5 - dxCam * r.z) * tr.scale;
      const sy = H * 0.5 + (r.y - 400 - dyCam * r.z) * tr.scale;
      if (sx < -220 || sx > W + 220 || sy < -60 || sy > H + 60) continue;

      const len = (r.len * (0.45 + windMag * 0.011)) * tr.scale * dir;
      const wave = Math.sin(tNow * 4.5 + r.phase) * r.amp * tr.scale;
      const alpha = r.alpha * clamp(windMag / 55, 0.22, 0.95);

      const grad = ctx.createLinearGradient(sx - len * 0.5, sy, sx + len * 0.5, sy);
      grad.addColorStop(0, `rgba(${ribbonCol}, 0)`);
      grad.addColorStop(0.5, `rgba(${ribbonCol}, ${alpha})`);
      grad.addColorStop(1, `rgba(${ribbonCol}, 0)`);

      ctx.strokeStyle = grad;
      ctx.lineWidth = (1.3 + (windMag / 100) * 1.2) * tr.scale;
      ctx.beginPath();
      ctx.moveTo(sx - len * 0.5, sy - wave * 0.4);
      ctx.bezierCurveTo(
        sx - len * 0.15, sy + wave,
        sx + len * 0.15, sy - wave,
        sx + len * 0.5, sy + wave * 0.3
      );
      ctx.stroke();
    }
  }

  // 2. Comarcal Atmospheric Weather Particles (Taüll Snow, Cadaqués Sea Spray, Castellfollit Autumn Beech Leaves, Montserrat Golden Pine Pollen)
  for (const m of weatherParticles) {
    let mx, my;
    if (weatherType === 'SNOW') {
      // Taüll Pyrenean Snowflakes drifting in the mountain wind
      mx = ((m.x + tNow * (m.vx * 1.1 + wind * 0.85)) % TERRAIN_W + TERRAIN_W) % TERRAIN_W;
      my = ((m.y + tNow * 95 + Math.sin(tNow * 2.2 + m.phase) * 8) % 800);
      const sx = W * 0.5 + (mx - TERRAIN_W * 0.5 - dxCam * m.z) * tr.scale;
      const sy = H * 0.5 + (my - 400 - dyCam * m.z) * tr.scale;
      ctx.fillStyle = 'rgba(242, 248, 255, 0.72)';
      ctx.beginPath();
      ctx.arc(sx, sy, (m.r * 1.15) * m.z * tr.scale, 0, Math.PI * 2);
      ctx.fill();
    } else if (weatherType === 'GULLS_BREEZE') {
      // Cadaqués / Cap de Creus Tramuntana Sea Mist & Salt Spray
      mx = ((m.x + tNow * (m.vx * 1.5 + wind * 0.6)) % TERRAIN_W + TERRAIN_W) % TERRAIN_W;
      my = m.y + Math.sin(tNow * 1.8 + m.phase) * 10;
      const sx = W * 0.5 + (mx - TERRAIN_W * 0.5 - dxCam * m.z) * tr.scale;
      const sy = H * 0.5 + (my - 400 - dyCam * m.z) * tr.scale;
      ctx.fillStyle = 'rgba(235, 248, 255, 0.36)';
      ctx.beginPath();
      ctx.arc(sx, sy, m.r * 1.5 * tr.scale, 0, Math.PI * 2);
      ctx.fill();
    } else if (weatherType === 'AUTUMN_LEAVES') {
      // Castellfollit / La Garrotxa Autumn Beech Leaves (Fageda d'en Jordà) swirling in the wind!
      mx = ((m.x + tNow * (m.vx * 1.2 + wind * 0.75)) % TERRAIN_W + TERRAIN_W) % TERRAIN_W;
      my = ((m.y + tNow * 48 + Math.sin(tNow * 2.4 + m.phase) * 14) % 800);
      const sx = W * 0.5 + (mx - TERRAIN_W * 0.5 - dxCam * m.z) * tr.scale;
      const sy = H * 0.5 + (my - 400 - dyCam * m.z) * tr.scale;
      ctx.save();
      ctx.translate(sx, sy);
      ctx.rotate(tNow * 2.2 + m.phase);
      ctx.fillStyle = m.phase > 3.14 ? 'rgba(230, 118, 45, 0.68)' : 'rgba(245, 182, 66, 0.68)';
      ctx.beginPath();
      ctx.ellipse(0, 0, m.r * 1.7 * tr.scale, m.r * 0.95 * tr.scale, 0, 0, Math.PI * 2);
      ctx.fill();
      ctx.restore();
    } else {
      // Montserrat Golden Pine Pollen & Floating Pine Needles
      mx = ((m.x + tNow * (m.vx + wind * 0.45)) % TERRAIN_W + TERRAIN_W) % TERRAIN_W;
      my = m.y + Math.sin(tNow * 1.5 + m.phase) * 12;
      const sx = W * 0.5 + (mx - TERRAIN_W * 0.5 - dxCam * m.z) * tr.scale;
      const sy = H * 0.5 + (my - 400 - dyCam * m.z) * tr.scale;
      ctx.fillStyle = 'rgba(255, 224, 150, 0.48)';
      ctx.beginPath();
      ctx.arc(sx, sy, m.r * m.z * tr.scale, 0, Math.PI * 2);
      ctx.fill();
    }
  }
  ctx.restore();
}

// ═══════════════════════════════════════════════════════════════════════════
//  10. SPANISH "ORUGA PROCESIONARIA" MULTI-SEGMENT CATERPILLAR RENDERER
// ═══════════════════════════════════════════════════════════════════════════
function drawFighter(ctx, f) {
  ctx.save();

  const isCurrent = (f === activeFighter && turnPhase !== 'GAME_OVER');
  const teamCol = f.team === 0 ? '#f5b945' : '#ea5648';
  const dorsalCol = f.team === 0 ? '#e87a24' : '#d93b2b';
  const bristleCol = f.urticatingTicks > 0 ? '#d88aff' : 'rgba(245, 236, 215, 0.82)';

  // 1. Draw the 6 articulated furry Oruga Procesionaria segments from tail (5) to neck (0)
  if (f.segs && f.segs.length > 0) {
    // Silk procession thread connecting segments along the ground
    if (f.grounded && !f.drowning) {
      ctx.save();
      ctx.strokeStyle = 'rgba(245, 242, 235, 0.28)';
      ctx.lineWidth = 1.4;
      ctx.beginPath();
      ctx.moveTo(f.x, f.y + 8);
      for (const seg of f.segs) ctx.lineTo(seg.x, seg.y + 5);
      ctx.stroke();
      ctx.restore();
    }

    for (let i = f.segs.length - 1; i >= 0; i--) {
      const seg = f.segs[i];
      const segR = 6.8 - i * 0.45;
      const stepWave = Math.sin(f.walkCycle * 1.5 - i * 0.9);

      ctx.save();
      ctx.translate(seg.x, seg.y);

      // Tiny caterpillar prolegs ("falsas patas") underneath each segment
      if (!f.drowning) {
        ctx.fillStyle = '#d98a4e';
        ctx.beginPath();
        ctx.arc(-1.2, segR - 0.5 + Math.max(0, stepWave * 1.4), 1.7, 0, Math.PI * 2);
        ctx.arc(1.5, segR - 0.5 + Math.max(0, -stepWave * 1.4), 1.7, 0, Math.PI * 2);
        ctx.fill();
      }

      // Radiating urticating bristles ("pelos urticantes") on every segment!
      ctx.strokeStyle = bristleCol;
      ctx.lineWidth = 1.1;
      for (let b = -3; b <= 3; b++) {
        const ba = -Math.PI * 0.5 + b * 0.34 + Math.sin(tNow * 6 + i + b) * 0.08;
        const hLen = segR + (b % 2 === 0 ? 4.8 : 3.2);
        ctx.beginPath();
        ctx.moveTo(Math.cos(ba) * (segR - 1), Math.sin(ba) * (segR - 1));
        ctx.lineTo(Math.cos(ba) * hLen, Math.sin(ba) * hLen);
        ctx.stroke();
      }

      // Dark charcoal-slate velvety caterpillar segment body
      const sg = ctx.createRadialGradient(-1, -2, 1, 0, 0, segR);
      if (f.drowning) {
        sg.addColorStop(0, '#6a9ab8');
        sg.addColorStop(1, '#263e52');
      } else {
        sg.addColorStop(0, '#3a3f4d');
        sg.addColorStop(0.65, '#22252e');
        sg.addColorStop(1, '#111318');
      }
      ctx.fillStyle = sg;
      ctx.strokeStyle = '#0d0e12';
      ctx.lineWidth = 1.5;
      ctx.beginPath();
      ctx.arc(0, 0, segR, 0, Math.PI * 2);
      ctx.fill();
      ctx.stroke();

      // Iconic Oruga Procesionaria reddish-orange dorsal urticating mirror patch!
      if (!f.drowning) {
        ctx.fillStyle = dorsalCol;
        ctx.beginPath();
        ctx.ellipse(0, -segR * 0.42, segR * 0.62, segR * 0.32, 0, 0, Math.PI * 2);
        ctx.fill();

        // Lateral golden-amber spiracle dot
        ctx.fillStyle = teamCol;
        ctx.beginPath();
        ctx.arc(0, 1.2, 1.3, 0, Math.PI * 2);
        ctx.fill();
      }

      ctx.restore();
    }
  }

  // 2. Draw Anterior Thorax & Armored Chitin Head Capsule at (f.x, f.y)
  ctx.translate(f.x, f.y);
  const bob = f.grounded ? Math.sin(f.walkCycle) * 1.8 : 0;

  ctx.save();
  if (f.flipAngle) {
    ctx.rotate(f.flipAngle);
  } else if (f.sliding && f.grounded) {
    ctx.rotate(f.slideAngle + f.facing * 0.32);
  } else if (!f.grounded && !f.drowning && Math.hypot(f.vx, f.vy) > 210) {
    ctx.rotate(Math.sin(tNow * 14) * 0.35);
  }
  ctx.scale(f.facing * f.squashX, f.squashY);

  // Metamorphosed Thaumetopoea Moth Wings OR Jetpack thrusters!
  if (f.metamorphosed || f.jetFuel > 0) {
    ctx.save();
    const wingFlap = (!f.grounded ? Math.sin(tNow * 32) * 0.38 : Math.sin(tNow * 5) * 0.12);
    ctx.fillStyle = f.metamorphosed ? 'rgba(246, 207, 119, 0.76)' : '#c89b52';
    ctx.strokeStyle = '#fff5df';
    ctx.lineWidth = 1.2;
    ctx.beginPath();
    ctx.ellipse(-8, -8, 11, 5.2, -0.45 + wingFlap, 0, Math.PI * 2);
    ctx.fill();
    ctx.stroke();
    ctx.fillStyle = 'rgba(232, 122, 36, 0.58)';
    ctx.beginPath();
    ctx.ellipse(-10, -4, 7.5, 3.5, -0.25 + wingFlap * 0.8, 0, Math.PI * 2);
    ctx.fill();
    ctx.restore();
  }

  // Anterior furry thorax collar with long forward bristles
  ctx.strokeStyle = bristleCol;
  ctx.lineWidth = 1.25;
  for (let b = -4; b <= 2; b++) {
    const ba = -Math.PI * 0.55 + b * 0.28;
    ctx.beginPath();
    ctx.moveTo(Math.cos(ba) * 6, Math.sin(ba) * 6);
    ctx.lineTo(Math.cos(ba) * 13.5, Math.sin(ba) * 13.5);
    ctx.stroke();
  }

  ctx.fillStyle = '#252934';
  ctx.strokeStyle = '#0e1015';
  ctx.lineWidth = 1.7;
  ctx.beginPath();
  ctx.ellipse(-1, 1 + bob, 7.8, 8.2, 0, 0, Math.PI * 2);
  ctx.fill();
  ctx.stroke();

  // Team-colored thoracic shield stripe
  ctx.fillStyle = teamCol;
  ctx.beginPath();
  ctx.ellipse(-1, -4 + bob, 5.5, 2.5, 0, 0, Math.PI * 2);
  ctx.fill();

  drawFighterHead(ctx, f, bob, teamCol);
  ctx.restore();

  // 3. Purple Urticating Itch Sparks if afflicted!
  if (f.urticatingTicks > 0 && !f.drowning) {
    ctx.save();
    for (let i = 0; i < 3; i++) {
      const a = tNow * 9 + i * 2.1;
      ctx.strokeStyle = '#d88aff';
      ctx.lineWidth = 1.5;
      ctx.beginPath();
      ctx.moveTo(Math.cos(a) * 13, -8 + Math.sin(a) * 8);
      ctx.lineTo(Math.cos(a) * 18, -8 + Math.sin(a) * 11);
      ctx.stroke();
    }
    ctx.restore();
  }

  // 4. Orbiting Dizzy Stars after a hard slam
  if (f.dizzyTimer > 0 && !f.drowning) {
    ctx.save();
    for (let i = 0; i < 3; i++) {
      const a = tNow * 6.5 + (i * Math.PI * 2) / 3;
      const sx = Math.cos(a) * 14;
      const sy = -24 + Math.sin(a) * 4.5;
      ctx.fillStyle = i % 2 === 0 ? '#ffe066' : '#ffffff';
      ctx.beginPath();
      ctx.arc(sx, sy, 2.6, 0, Math.PI * 2);
      ctx.fill();
    }
    ctx.restore();
  }

  // 5. Held Weapon
  if (isCurrent && !f.sliding && !f.drowning && (turnPhase === 'TURN_PLAY' || turnPhase === 'RETREAT')) {
    drawHeldWeapon(ctx, f);
  }

  // 6. Decluttered Contextual Nameplate & Minimalist Health Pill (+ Automatic Golden Procession Glow!)
  if (!f.drowning) {
    const linkedCount = f.linkedAllies ? f.linkedAllies.length : 0;

    // Warm golden silk aura when marching in automatic Processó or stacked in a Castell de Cucs!
    if (f.castellTower || linkedCount > 0) {
      ctx.save();
      const auraCol = f.castellTower ? 'rgba(255, 217, 102, 0.72)' : 'rgba(245, 200, 105, 0.38)';
      ctx.strokeStyle = auraCol;
      ctx.lineWidth = f.castellTower ? 2.2 : 1.5;
      if (f.castellTower) ctx.setLineDash([4, 3]);
      ctx.beginPath();
      ctx.arc(0, -5, 19 + Math.sin(tNow * 6) * 1.5, 0, Math.PI * 2);
      ctx.stroke();
      ctx.restore();
    }

    const isNearAim = mouseWorld && Math.hypot(mouseWorld.x - f.x, mouseWorld.y - f.y) < 62;
    const showFullCard = isCurrent || f.hurtTimer > 0 || f.dizzyTimer > 0 || isNearAim;

    if (showFullCard) {
      const labelY = -36;
      ctx.font = '800 12px "Plus Jakarta Sans", sans-serif';
      ctx.textAlign = 'center';

      const dispName = f.name;
      const tw = ctx.measureText(dispName).width + 18;
      ctx.fillStyle = 'rgba(11, 14, 22, 0.84)';
      ctx.strokeStyle = isCurrent ? teamCol : 'rgba(240, 195, 110, 0.38)';
      ctx.lineWidth = isCurrent ? 1.6 : 1.1;
      ctx.beginPath();
      ctx.roundRect(-tw / 2, labelY - 13, tw, 18, 9);
      ctx.fill();
      ctx.stroke();

      ctx.fillStyle = '#fff8eb';
      ctx.fillText(dispName, 0, labelY);

      const bw = 38, bh = 4.5;
      ctx.fillStyle = 'rgba(0, 0, 0, 0.72)';
      ctx.beginPath();
      ctx.roundRect(-bw / 2 - 1, labelY + 7, bw + 2, bh + 2, 99);
      ctx.fill();
      ctx.fillStyle = teamCol;
      ctx.beginPath();
      ctx.roundRect(-bw / 2, labelY + 8, Math.max(2, bw * clamp(f.hp / f.maxHp, 0, 1)), bh, 99);
      ctx.fill();

      if (f.jetFuel > 0) {
        ctx.fillStyle = 'rgba(0, 0, 0, 0.75)';
        ctx.beginPath();
        ctx.roundRect(-bw / 2, labelY + 14, bw, 3, 99);
        ctx.fill();
        ctx.fillStyle = '#5ad2f4';
        ctx.beginPath();
        ctx.roundRect(-bw / 2, labelY + 14, bw * (f.jetFuel / 100), 3, 99);
        ctx.fill();
      }

      if (isCurrent && turnPhase === 'TURN_PLAY') {
        const arrowY = labelY - 21 + Math.sin(tNow * 6) * 3;
        ctx.fillStyle = teamCol;
        ctx.beginPath();
        ctx.moveTo(0, arrowY + 6);
        ctx.lineTo(-5.5, arrowY - 2);
        ctx.lineTo(5.5, arrowY - 2);
        ctx.closePath();
        ctx.fill();
      }
    } else {
      // Idle Cucs: sleek minimalist floating health pill so the Catalan scenery & hats stay uncluttered!
      const pillY = -28;
      const bw = 28, bh = 4;
      ctx.fillStyle = 'rgba(9, 12, 18, 0.72)';
      ctx.beginPath();
      ctx.roundRect(-bw / 2 - 1, pillY - 1, bw + 2, bh + 2, 99);
      ctx.fill();
      ctx.fillStyle = teamCol;
      ctx.beginPath();
      ctx.roundRect(-bw / 2, pillY, Math.max(2, bw * clamp(f.hp / f.maxHp, 0, 1)), bh, 99);
      ctx.fill();
    }
  }

  ctx.restore();
}

function drawFighterHead(ctx, f, bob, teamCol) {
  ctx.save();
  ctx.translate(2, -8 + bob);

  if (f.customFaceImg) {
    // Custom Friend Photo Face clipped inside Oruga head capsule!
    ctx.save();
    ctx.beginPath();
    ctx.arc(0, 0, 10.5, 0, Math.PI * 2);
    ctx.clip();
    ctx.drawImage(f.customFaceImg, -11, -11, 22, 22);
    ctx.restore();
    ctx.strokeStyle = teamCol;
    ctx.lineWidth = 2.0;
    ctx.beginPath();
    ctx.arc(0, 0, 10.5, 0, Math.PI * 2);
    ctx.stroke();
  } else {
    // Authentic Shiny Dark-Chitin Oruga Procesionaria Head Capsule
    const hg = ctx.createRadialGradient(2, -3, 1, 0, 0, 10);
    if (f.drowning) {
      hg.addColorStop(0, '#7ab4d6');
      hg.addColorStop(0.7, '#3d6987');
      hg.addColorStop(1, '#1d3547');
    } else {
      hg.addColorStop(0, '#4f5666');
      hg.addColorStop(0.55, '#252932');
      hg.addColorStop(1, '#0f1116');
    }
    ctx.fillStyle = hg;
    ctx.strokeStyle = '#090a0d';
    ctx.lineWidth = 1.8;
    ctx.beginPath();
    ctx.arc(0, 0, 9.2, 0, Math.PI * 2);
    ctx.fill();
    ctx.stroke();

    // Graphics G2: Sunlit Chitin Specular Rim Highlight on Head Capsule
    ctx.strokeStyle = 'rgba(255, 250, 235, 0.34)';
    ctx.lineWidth = 1.3;
    ctx.beginPath();
    ctx.arc(0.5, -0.5, 7.6, -Math.PI * 0.78, -Math.PI * 0.18);
    ctx.stroke();

    // Cute/fierce curved caterpillar antennae with amber tips
    const antWiggle = Math.sin(tNow * 8 + f.x) * 1.4;
    ctx.strokeStyle = '#1b1e26';
    ctx.lineWidth = 1.5;
    ctx.beginPath();
    ctx.moveTo(2, -8);
    ctx.quadraticCurveTo(5, -14, 8 + antWiggle, -13);
    ctx.moveTo(-2, -8);
    ctx.quadraticCurveTo(-1, -14, 2 - antWiggle, -14);
    ctx.stroke();

    ctx.fillStyle = teamCol;
    ctx.beginPath();
    ctx.arc(8 + antWiggle, -13, 1.7, 0, Math.PI * 2);
    ctx.arc(2 - antWiggle, -14, 1.5, 0, Math.PI * 2);
    ctx.fill();

    // Details D1: Expressive Reactive Caterpillar Faces (Blinking, Panic near explosives, Charging war-squint)
    const blinkCycle = (tNow * 0.9 + f.id * 1.73) % 4.2;
    const isBlinking = blinkCycle > 4.04 && f.dizzyTimer <= 0 && f.hurtTimer <= 0;
    const isNearDanger = projectiles.some(p => Math.hypot(p.x - f.x, p.y - f.y) < 115) ||
                         mines.some(m => m.triggered && Math.hypot(m.x - f.x, m.y - f.y) < 115);
    const isFiringSquint = (f === activeFighter && isCharging);

    // Expressive Amber/Ivory Eyes
    const eyeScaleY = isBlinking ? 0.12 : (isNearDanger ? 1.22 : (isFiringSquint ? 0.78 : 1.0));
    ctx.fillStyle = '#fff8e7';
    ctx.beginPath();
    ctx.ellipse(3.4, -1.2, 2.7, 3.3 * eyeScaleY, 0, 0, Math.PI * 2);
    ctx.ellipse(7.1, -1.2, 2.2, 2.8 * eyeScaleY, 0, 0, Math.PI * 2);
    ctx.fill();

    if (f.dizzyTimer > 0 || f.hurtTimer > 0.2) {
      ctx.strokeStyle = '#181412';
      ctx.lineWidth = 1.3;
      ctx.beginPath();
      ctx.moveTo(2.2, -2.4); ctx.lineTo(4.6, 0.0);
      ctx.moveTo(4.6, -2.4); ctx.lineTo(2.2, 0.0);
      ctx.moveTo(6.0, -2.2); ctx.lineTo(8.2, 0.0);
      ctx.moveTo(8.2, -2.2); ctx.lineTo(6.0, 0.0);
      ctx.stroke();
    } else if (!isBlinking) {
      ctx.fillStyle = '#141110';
      const pupilR = (f.sliding || f.drowning || isNearDanger) ? 0.82 : 1.35;
      ctx.beginPath();
      ctx.arc(4.2, -1.2, pupilR, 0, Math.PI * 2);
      ctx.arc(7.7, -1.2, pupilR * 0.85, 0, Math.PI * 2);
      ctx.fill();

      // Glossy corneal catchlight dot
      ctx.fillStyle = '#ffffff';
      ctx.beginPath();
      ctx.arc(3.7, -2.0, 0.65, 0, Math.PI * 2);
      ctx.arc(7.3, -1.9, 0.55, 0, Math.PI * 2);
      ctx.fill();

      // Fierce or worried brow ridge
      ctx.strokeStyle = teamCol;
      ctx.lineWidth = 1.6;
      ctx.beginPath();
      if (isNearDanger) {
        ctx.moveTo(1.0, -3.6);
        ctx.lineTo(8.4, -5.0);
      } else if (isFiringSquint) {
        ctx.moveTo(0.8, -5.0);
        ctx.lineTo(8.8, -2.5);
      } else {
        ctx.moveTo(1.0, -4.6);
        ctx.lineTo(8.6, -3.2);
      }
      ctx.stroke();
    }

    // Little chitin mandibles at the front of the head
    ctx.fillStyle = '#d48a46';
    ctx.beginPath();
    ctx.moveTo(5.5, 4.2);
    ctx.lineTo(8.5, 5.5);
    ctx.lineTo(5.0, 6.2);
    ctx.closePath();
    ctx.fill();
  }

  // Catalan Headgear (Barretina Catalana, Casc de Casteller, Capell de Bandoler, Barret de Palla de Pagès, or Plomall de Pèls Urticants)
  drawOrugaHat(ctx, teamHats[f.team], teamCol);

  ctx.restore();
}

function drawOrugaHat(ctx, hatType, teamCol) {
  ctx.save();
  if (hatType === 'CATALAN') {
    // Traditional red & black Catalan Barretina cap!
    ctx.fillStyle = '#16181f';
    ctx.fillRect(-8, -9.5, 15, 2.8);
    ctx.fillStyle = '#d93228';
    ctx.strokeStyle = '#16181f';
    ctx.lineWidth = 1.2;
    ctx.beginPath();
    ctx.moveTo(-7.5, -9.5);
    ctx.quadraticCurveTo(-2, -19, -12, -14);
    ctx.quadraticCurveTo(-6, -11, 6.5, -9.5);
    ctx.closePath();
    ctx.fill();
    ctx.stroke();
  } else if (hatType === 'CASTELLER') {
    // Casc d'Enxaneta Casteller amb les Quatre Barres de la Senyera!
    ctx.fillStyle = '#f5c23b';
    ctx.strokeStyle = '#14161d';
    ctx.lineWidth = 1.3;
    ctx.beginPath();
    ctx.arc(-0.5, -8.2, 8.2, Math.PI, 0, false);
    ctx.closePath();
    ctx.fill();
    ctx.stroke();
    // Four red Catalan stripes (Quatre Barres)
    ctx.strokeStyle = '#d92b22';
    ctx.lineWidth = 1.5;
    for (let s = -4.5; s <= 4.5; s += 3) {
      ctx.beginPath();
      ctx.moveTo(s, -8.5);
      ctx.lineTo(s * 0.75, -15.8);
      ctx.stroke();
    }
    ctx.fillStyle = '#181b22';
    ctx.fillRect(-8.5, -9.2, 16, 2.4);
  } else if (hatType === 'BANDOLER') {
    // Capell de Bandoler Català (Serrallonga wide-brimmed felt hat with red band & feather!)
    ctx.fillStyle = '#241e1a';
    ctx.strokeStyle = '#0e0b09';
    ctx.lineWidth = 1.2;
    ctx.beginPath();
    ctx.moveTo(-6, -8.5);
    ctx.lineTo(-4, -17);
    ctx.lineTo(3, -17);
    ctx.lineTo(5, -8.5);
    ctx.closePath();
    ctx.fill();
    ctx.stroke();
    // Red bandoler sash ribbon + golden buckle
    ctx.fillStyle = '#d93228';
    ctx.fillRect(-5.5, -11, 10, 2.2);
    ctx.fillStyle = '#f5b945';
    ctx.fillRect(-1, -11.3, 2.6, 2.6);
    // Wide sweeping brim
    ctx.fillStyle = '#2b231e';
    ctx.beginPath();
    ctx.ellipse(-0.5, -8.5, 11.5, 2.3, -0.05, 0, Math.PI * 2);
    ctx.fill();
    ctx.stroke();
  } else if (hatType === 'PAGES') {
    // Barret de Palla de Pagès Català (Golden braided straw hat with red ribbon)
    ctx.fillStyle = '#e8c168';
    ctx.strokeStyle = '#5c3d14';
    ctx.lineWidth = 1.2;
    ctx.beginPath();
    ctx.arc(-0.5, -8.5, 7.6, Math.PI, 0, false);
    ctx.fill();
    ctx.stroke();
    ctx.fillStyle = '#d93228';
    ctx.fillRect(-7.8, -10.5, 14.6, 2.0);
    ctx.fillStyle = '#f0cf7b';
    ctx.beginPath();
    ctx.ellipse(-0.5, -8.2, 12.2, 2.4, -0.04, 0, Math.PI * 2);
    ctx.fill();
    ctx.stroke();
  } else {
    // Natural Golden Stinging Bristle Crown Tufts (Plomall de Pèls Urticants)
    ctx.strokeStyle = '#ffae42';
    ctx.lineWidth = 1.4;
    for (let i = -3; i <= 3; i++) {
      ctx.beginPath();
      ctx.moveTo(i * 1.8, -8);
      ctx.lineTo(i * 2.8, -15 - (i % 2 === 0 ? 2 : 0));
      ctx.stroke();
    }
  }
  ctx.restore();
}

function drawCrate(ctx, c) {
  ctx.save();
  ctx.translate(c.x, c.y);

  if (c.parachuting) {
    const sway = Math.sin(tNow * 3.5 + c.x * 0.05) * 0.16;
    ctx.save();
    ctx.rotate(sway);
    ctx.strokeStyle = 'rgba(239, 232, 218, 0.65)';
    ctx.lineWidth = 1.2;
    ctx.beginPath();
    ctx.moveTo(-8, -8); ctx.lineTo(-18, -28);
    ctx.moveTo(8, -8);  ctx.lineTo(18, -28);
    ctx.moveTo(0, -8);  ctx.lineTo(0, -30);
    ctx.stroke();

    ctx.fillStyle = c.isMedkit ? '#d9483b' : '#d99b43';
    ctx.strokeStyle = '#181a20';
    ctx.lineWidth = 1.6;
    ctx.beginPath();
    ctx.arc(0, -26, 19, Math.PI, 0, false);
    ctx.closePath();
    ctx.fill();
    ctx.stroke();
    ctx.restore();
  }

  ctx.fillStyle = c.isMedkit ? '#e8e4dc' : '#7a5434';
  ctx.strokeStyle = '#1b1612';
  ctx.lineWidth = 1.8;
  ctx.fillRect(-10, -10, 20, 20);
  ctx.strokeRect(-10, -10, 20, 20);

  if (c.isMedkit) {
    ctx.fillStyle = '#d93829';
    ctx.fillRect(-2.5, -6.5, 5, 13);
    ctx.fillRect(-6.5, -2.5, 13, 5);
  } else {
    ctx.strokeStyle = '#c89b52';
    ctx.lineWidth = 1.8;
    ctx.strokeRect(-7, -7, 14, 14);
    ctx.beginPath();
    ctx.moveTo(-7, -7); ctx.lineTo(7, 7);
    ctx.stroke();
  }
  ctx.restore();
}

function drawMine(ctx, m) {
  ctx.save();
  ctx.translate(m.x, m.y);
  ctx.fillStyle = '#3b424c';
  ctx.strokeStyle = '#14161a';
  ctx.lineWidth = 1.6;
  ctx.beginPath();
  ctx.ellipse(0, 1, 8, 4.5, 0, 0, Math.PI * 2);
  ctx.fill();
  ctx.stroke();

  const flashOn = m.triggered ? (Math.sin(tNow * 32) > 0) : (Math.sin(tNow * 3) > 0.7);
  ctx.fillStyle = flashOn ? '#ff3b30' : '#6e1c18';
  ctx.beginPath();
  ctx.arc(0, -2.5, 2.6, 0, Math.PI * 2);
  ctx.fill();
  ctx.restore();
}

function drawTombstone(ctx, tb) {
  ctx.save();
  ctx.translate(tb.x, tb.y);

  // Carved Romanesque Stone Memorial
  const sg = ctx.createLinearGradient(-9, -13, 9, 10);
  sg.addColorStop(0, '#888590');
  sg.addColorStop(0.5, '#6c6a72');
  sg.addColorStop(1, '#49474f');
  ctx.fillStyle = sg;
  ctx.strokeStyle = '#222026';
  ctx.lineWidth = 1.8;
  ctx.beginPath();
  ctx.moveTo(-9, 10);
  ctx.lineTo(-9, -4);
  ctx.arc(0, -4, 9, Math.PI, 0, false);
  ctx.lineTo(9, 10);
  ctx.closePath();
  ctx.fill();
  ctx.stroke();

  // Mossy base tuft
  ctx.fillStyle = '#4e7c3e';
  ctx.beginPath();
  ctx.arc(-6, 9.5, 2.4, Math.PI, 0);
  ctx.arc(5, 9.5, 2.8, Math.PI, 0);
  ctx.fill();

  // Engraved Cross
  ctx.strokeStyle = '#3b3940';
  ctx.lineWidth = 1.5;
  ctx.beginPath();
  ctx.moveTo(0, -9); ctx.lineTo(0, 1);
  ctx.moveTo(-3.5, -5.5); ctx.lineTo(3.5, -5.5);
  ctx.stroke();

  // Details D2: Engraved fallen caterpillar name + resting Barretina on top!
  if (tb.name) {
    ctx.font = '700 5.5px "Plus Jakarta Sans", sans-serif';
    ctx.textAlign = 'center';
    ctx.fillStyle = '#e2dfd7';
    ctx.fillText(tb.name.slice(0, 7).toUpperCase(), 0, 6.8);
  }
  // Miniature team-colored Barretina draped over the tombstone crest
  const hatCol = tb.team === 0 ? '#d93228' : (tb.team === 1 ? '#3b82f6' : '#d93228');
  ctx.fillStyle = hatCol;
  ctx.strokeStyle = '#18161b';
  ctx.lineWidth = 1.0;
  ctx.beginPath();
  ctx.moveTo(-5, -11.5);
  ctx.quadraticCurveTo(0, -18, 7, -14);
  ctx.quadraticCurveTo(3, -11, 4, -11.5);
  ctx.closePath();
  ctx.fill();
  ctx.stroke();

  ctx.restore();
}

function drawHeldWeapon(ctx, f) {
  const wpn = WEAPONS[selectedWeaponIdx];
  ctx.save();
  ctx.translate(0, -3);
  const swingOffset = f.batSwingTimer > 0 ? Math.sin(f.batSwingTimer * 18) * 1.8 : 0;
  ctx.rotate(aimAngle + swingOffset);

  if (wpn.id === 'BAZOOKA') {
    // Catalan Trabuc (Bandit Blunderbuss with flared brass bell muzzle!)
    ctx.fillStyle = '#7a4621';
    ctx.strokeStyle = '#1a120b';
    ctx.lineWidth = 1.4;
    ctx.beginPath();
    ctx.moveTo(-10, 4);
    ctx.lineTo(-2, -2);
    ctx.lineTo(-2, 3);
    ctx.lineTo(-8, 7);
    ctx.closePath();
    ctx.fill();
    ctx.stroke();

    ctx.fillStyle = '#3f464e';
    ctx.fillRect(-2, -3, 14, 5);
    ctx.strokeRect(-2, -3, 14, 5);

    ctx.fillStyle = '#d99b43';
    ctx.beginPath();
    ctx.moveTo(12, -3.5);
    ctx.lineTo(22, -7.5);
    ctx.lineTo(22, 6.5);
    ctx.lineTo(12, 2.5);
    ctx.closePath();
    ctx.fill();
    ctx.stroke();
  } else if (wpn.id === 'CARQUINYOLI') {
    // Toasted Catalan Carquinyoli almond biscotti held in hand!
    ctx.save();
    ctx.translate(12, 0);
    ctx.rotate(-0.22);
    ctx.fillStyle = '#c87d32';
    ctx.strokeStyle = '#4a280a';
    ctx.lineWidth = 1.3;
    ctx.beginPath();
    ctx.roundRect(-7, -3.5, 14, 7, 3);
    ctx.fill();
    ctx.stroke();
    // Whole white Marcona almonds embedded in the biscuit
    ctx.fillStyle = '#fff5df';
    ctx.beginPath();
    ctx.ellipse(-2.5, 0, 2.2, 1.3, 0.3, 0, Math.PI * 2);
    ctx.ellipse(2.5, -0.3, 2.0, 1.2, -0.25, 0, Math.PI * 2);
    ctx.fill();
    ctx.restore();
  } else if (wpn.id === 'URTICARIA') {
    ctx.fillStyle = '#8b3eb8';
    ctx.strokeStyle = '#f6cf77';
    ctx.lineWidth = 1.4;
    ctx.beginPath();
    ctx.arc(12, 0, 5.5, 0, Math.PI * 2);
    ctx.fill();
    ctx.stroke();
  } else if (wpn.id === 'SHOTGUN') {
    // Catalan Pedrenyal (17th-century flintlock pistol)
    ctx.fillStyle = '#8c542b';
    ctx.strokeStyle = '#1c120a';
    ctx.lineWidth = 1.3;
    ctx.beginPath();
    ctx.moveTo(-6, 5);
    ctx.quadraticCurveTo(-3, -1, 4, -1);
    ctx.lineTo(4, 3);
    ctx.quadraticCurveTo(-1, 3, -3, 7);
    ctx.closePath();
    ctx.fill();
    ctx.stroke();

    ctx.fillStyle = '#8d96a3';
    ctx.fillRect(3, -3, 17, 3.5);
    ctx.strokeRect(3, -3, 17, 3.5);
    // Flintlock hammer (clau de pedrenyal)
    ctx.fillStyle = '#d9a14a';
    ctx.fillRect(5, -6, 3, 3);
  } else if (wpn.id === 'FUET') {
    // El Fuet de Vic (Long cured Catalan pork sausage dusted with white penicillium & tied with twine!)
    const whipBend = f.batSwingTimer > 0 ? Math.sin(f.batSwingTimer * 26) * 7 : -2.5;
    ctx.lineCap = 'round';
    // Dark cured pork core
    ctx.strokeStyle = '#7a1f2d';
    ctx.lineWidth = 5.4;
    ctx.beginPath();
    ctx.moveTo(2, 1);
    ctx.quadraticCurveTo(15, whipBend, 28, whipBend * 0.6);
    ctx.stroke();
    // White penicillium flour crust
    ctx.strokeStyle = '#f4eee1';
    ctx.lineWidth = 4.2;
    ctx.setLineDash([2.8, 2.2]);
    ctx.beginPath();
    ctx.moveTo(3, 1);
    ctx.quadraticCurveTo(15, whipBend, 27, whipBend * 0.6);
    ctx.stroke();
    ctx.setLineDash([]);
    // Tied butcher's twine at the tip
    ctx.strokeStyle = '#d9b372';
    ctx.lineWidth = 1.4;
    ctx.beginPath();
    ctx.moveTo(28, whipBend * 0.6);
    ctx.lineTo(32, whipBend * 0.6 - 3);
    ctx.moveTo(28, whipBend * 0.6);
    ctx.lineTo(32, whipBend * 0.6 + 2.5);
    ctx.stroke();
  } else if (wpn.id === 'BAT') {
    // La Falç (Els Segadors Curved Reaper's Sickle!)
    ctx.fillStyle = '#b87430';
    ctx.strokeStyle = '#2b1808';
    ctx.lineWidth = 1.3;
    ctx.fillRect(2, -2, 8, 4);
    ctx.strokeRect(2, -2, 8, 4);

    ctx.fillStyle = '#dce3ec';
    ctx.strokeStyle = '#4a525d';
    ctx.lineWidth = 1.4;
    ctx.beginPath();
    ctx.moveTo(10, 0);
    ctx.bezierCurveTo(16, -13, 28, -10, 26, 2);
    ctx.bezierCurveTo(24, 8, 17, 8, 14, 5);
    ctx.bezierCurveTo(19, 5, 22, 2, 22, -2);
    ctx.bezierCurveTo(22, -7, 15, -7, 10, 1);
    ctx.closePath();
    ctx.fill();
    ctx.stroke();
  } else if (wpn.id === 'GRENADE') {
    // Pinya (Mediterranean Stone Pine Cone)
    ctx.fillStyle = '#7c4d2b';
    ctx.strokeStyle = '#f6cf77';
    ctx.lineWidth = 1.2;
    ctx.beginPath();
    ctx.ellipse(12, 0, 5.5, 4.5, 0, 0, Math.PI * 2);
    ctx.fill();
    ctx.stroke();
  } else if (wpn.id === 'CLUSTER') {
    // Calçotada (Bundle of Calçots tied with red twine)
    ctx.strokeStyle = '#f2ecdf';
    ctx.lineWidth = 2.2;
    ctx.beginPath();
    ctx.moveTo(9, 4); ctx.lineTo(13, -2);
    ctx.moveTo(12, 5); ctx.lineTo(15, -2);
    ctx.stroke();
    ctx.strokeStyle = '#5ca856';
    ctx.beginPath();
    ctx.moveTo(13, -2); ctx.lineTo(16, -7);
    ctx.moveTo(15, -2); ctx.lineTo(19, -6);
    ctx.stroke();
    ctx.fillStyle = '#d93829';
    ctx.fillRect(10, 0, 6, 2.5);
  } else if (wpn.id === 'HOLY') {
    // Porró Sagrat (Golden Catalan Wine Porró)
    ctx.fillStyle = '#f0b849';
    ctx.strokeStyle = '#fff';
    ctx.lineWidth = 1.3;
    ctx.beginPath();
    ctx.moveTo(9, 5);
    ctx.lineTo(12, -5);
    ctx.lineTo(15, -5);
    ctx.lineTo(18, 5);
    ctx.closePath();
    ctx.fill();
    ctx.stroke();
  } else if (wpn.id === 'DYNAMITE') {
    // El Tió (Miniature Caga Tió log with red blanket)
    ctx.fillStyle = '#8c5830';
    ctx.fillRect(7, -4, 12, 7);
    ctx.fillStyle = '#d93829';
    ctx.fillRect(7, -4, 6, 7);
  } else if (wpn.id === 'AIRSTRIKE') {
    ctx.fillStyle = '#d94638';
    ctx.fillRect(8, -5, 6, 9);
    ctx.strokeStyle = '#f6cf77';
    ctx.lineWidth = 1.5;
    ctx.beginPath();
    ctx.moveTo(11, -5);
    ctx.lineTo(11, -13);
    ctx.stroke();
  } else if (wpn.id === 'CULLERA') {
    // Giant Catalan Boxwood Wooden Spoon (Cullera de Fusta de Boix)
    const scoopWobble = f.spoonTimer > 0 ? Math.sin(tNow * 28) * 0.28 : 0;
    ctx.rotate(scoopWobble);
    ctx.fillStyle = '#cfa05a';
    ctx.strokeStyle = '#4a2c0d';
    ctx.lineWidth = 1.3;
    ctx.beginPath();
    ctx.roundRect(2, -2, 16, 4, 1.5);
    ctx.fill();
    ctx.stroke();
    ctx.fillStyle = '#e6b973';
    ctx.beginPath();
    ctx.ellipse(22, 0, 7.5, 5.0, 0, 0, Math.PI * 2);
    ctx.fill();
    ctx.stroke();
    ctx.fillStyle = '#b8843e';
    ctx.beginPath();
    ctx.ellipse(22.5, 0, 5.0, 3.2, 0, 0, Math.PI * 2);
    ctx.fill();
  } else if (wpn.id === 'BARRINA') {
    // Catalan Quarry Pneumatic Rock Drill (Barrina de Pedrera)
    const drillJitter = f.drillTimer > 0 ? (Math.random() - 0.5) * 3.0 : 0;
    ctx.translate(drillJitter, 0);
    ctx.fillStyle = '#d97b29';
    ctx.strokeStyle = '#1c1612';
    ctx.lineWidth = 1.3;
    ctx.fillRect(3, -4.5, 11, 9);
    ctx.strokeRect(3, -4.5, 11, 9);
    ctx.fillStyle = '#b8c2cf';
    ctx.beginPath();
    ctx.moveTo(14, -3.5);
    ctx.lineTo(28, 0);
    ctx.lineTo(14, 3.5);
    ctx.closePath();
    ctx.fill();
    ctx.stroke();
  } else if (wpn.id === 'PONT_PEDRA') {
    // Mestre Marger Dry-Stone Trowel & Stone Block (Pedra Seca)
    ctx.fillStyle = '#a8a298';
    ctx.strokeStyle = '#2d2a26';
    ctx.lineWidth = 1.3;
    ctx.fillRect(8, -4.5, 13, 8);
    ctx.strokeRect(8, -4.5, 13, 8);
    ctx.fillStyle = '#82a858';
    ctx.fillRect(8, -4.5, 13, 2.5);
  } else if (wpn.id === 'GANXO') {
    // Pyrenean Shepherd's Crook (Ganxo de Pastor)
    ctx.strokeStyle = '#9c6234';
    ctx.lineWidth = 2.6;
    ctx.beginPath();
    ctx.moveTo(2, 1);
    ctx.lineTo(18, -1);
    ctx.stroke();
    ctx.strokeStyle = '#e2e8f0';
    ctx.lineWidth = 2.4;
    ctx.beginPath();
    ctx.arc(21, -1, 4.5, -Math.PI * 0.6, Math.PI * 0.65);
    ctx.stroke();
  }
  ctx.restore();
}

function drawAimingHUD(ctx, f) {
  const wpn = WEAPONS[selectedWeaponIdx];
  if (wpn.id === 'AIRSTRIKE') {
    ctx.save();
    ctx.strokeStyle = '#ff6b5b';
    ctx.lineWidth = 2.2;
    ctx.beginPath();
    ctx.arc(mouseWorld.x, mouseWorld.y, 16 + Math.sin(tNow * 8) * 3, 0, Math.PI * 2);
    ctx.moveTo(mouseWorld.x - 24, mouseWorld.y);
    ctx.lineTo(mouseWorld.x + 24, mouseWorld.y);
    ctx.moveTo(mouseWorld.x, mouseWorld.y - 24);
    ctx.lineTo(mouseWorld.x, mouseWorld.y + 24);
    ctx.stroke();

    ctx.font = '800 11px "Plus Jakarta Sans", sans-serif';
    ctx.textAlign = 'center';
    ctx.fillStyle = '#ffe082';
    ctx.fillText('OBJECTIU CORREFOC', mouseWorld.x, mouseWorld.y - 28);
    ctx.restore();
    return;
  }

  if (wpn.id === 'DYNAMITE' || wpn.id === 'JETPACK') return;

  const dirX = Math.cos(aimAngle);
  const dirY = Math.sin(aimAngle);
  const originX = f.x;
  const originY = f.y - 4;

  ctx.save();

  // Soft Turn-Start Spotlight Ring around the active Cuc so it is immediately easy to spot on multi-level maps!
  if (turnSpotlightTimer > 0) {
    ctx.save();
    const spAlpha = clamp(turnSpotlightTimer / 1.9, 0, 1);
    const spCol = f.team === 0 ? `rgba(245, 185, 69, ${spAlpha * 0.65})` : `rgba(234, 86, 72, ${spAlpha * 0.65})`;
    ctx.strokeStyle = spCol;
    ctx.lineWidth = 2.4;
    ctx.setLineDash([6, 4]);
    ctx.beginPath();
    ctx.arc(originX, originY, 31 + (1 - spAlpha) * 18, 0, Math.PI * 2);
    ctx.stroke();
    ctx.setLineDash([]);
    if (!hasActedOrMovedThisTurn && spAlpha > 0.25) {
      ctx.font = '700 9.5px "Plus Jakarta Sans", sans-serif';
      ctx.textAlign = 'center';
      ctx.fillStyle = `rgba(255, 245, 220, ${spAlpha * 0.85})`;
      ctx.fillText('TAB / TOCA CUC: CANVIA', originX, originY + 34);
    }
    ctx.restore();
  }

  // Crisp Elevation Angle Degree Badge (+24°) beside the aim guide!
  const elevDeg = Math.round((-aimPitch * 180) / Math.PI);
  const degText = `${elevDeg >= 0 ? '+' : ''}${elevDeg}°`;
  const badgeX = originX + dirX * 34;
  const badgeY = originY + dirY * 34 - 11;
  ctx.save();
  ctx.font = '800 9.5px "JetBrains Mono", monospace';
  ctx.textAlign = 'center';
  ctx.fillStyle = 'rgba(11, 14, 22, 0.78)';
  ctx.beginPath();
  ctx.roundRect(badgeX - 16, badgeY - 8, 32, 13, 5);
  ctx.fill();
  ctx.fillStyle = isCharging ? '#ffd966' : 'rgba(255, 244, 214, 0.92)';
  ctx.fillText(degText, badgeX, badgeY + 1.5);
  ctx.restore();

  if (wpn.type === 'CHARGE') {
    // 1. Silky-smooth Unified Curved Trajectory Arc that bends naturally with live Wind!
    const previewPower = isCharging ? Math.max(0.22, chargePower) : 0.56;
    const speed = 180 + previewPower * 760;
    const wf = wpn.windFactor || 0;
    let px = originX + dirX * 18;
    let py = originY + dirY * 18;
    let pvx = dirX * speed;
    let pvy = dirY * speed;
    const stepDt = 0.028;
    const pts = [{ x: px, y: py }];
    for (let b = 1; b <= 11; b++) {
      pvx += (wind * 2.4 * wf) * stepDt;
      pvy += GRAVITY * stepDt;
      px += pvx * stepDt;
      py += pvy * stepDt;
      pts.push({ x: px, y: py });
    }

    // Soft glowing trajectory curve
    const lastPt = pts[pts.length - 1];
    const arcGrad = ctx.createLinearGradient(pts[0].x, pts[0].y, lastPt.x, lastPt.y);
    const windTint = wf > 0 && Math.abs(wind) > 18
      ? (wind > 0 ? '255, 200, 95' : '135, 215, 245')
      : '248, 224, 168';
    arcGrad.addColorStop(0, `rgba(${windTint}, 0.82)`);
    arcGrad.addColorStop(0.65, `rgba(${windTint}, 0.42)`);
    arcGrad.addColorStop(1, `rgba(${windTint}, 0)`);

    ctx.strokeStyle = arcGrad;
    ctx.lineWidth = 2.4;
    ctx.lineCap = 'round';
    ctx.setLineDash([5, 6]);
    ctx.beginPath();
    ctx.moveTo(pts[0].x, pts[0].y);
    for (let i = 1; i < pts.length; i++) {
      ctx.lineTo(pts[i].x, pts[i].y);
    }
    ctx.stroke();
    ctx.setLineDash([]);

    // Luminous pearl dots along the curved trajectory
    for (let i = 2; i < pts.length; i += 2) {
      const alpha = (1 - i / (pts.length + 1)) * 0.85;
      ctx.fillStyle = `rgba(${windTint}, ${alpha})`;
      ctx.beginPath();
      ctx.arc(pts[i].x, pts[i].y, 3.0 - i * 0.16, 0, Math.PI * 2);
      ctx.fill();
    }

    // 2. Integrated Circular Radial Power Ring around the active Cuc while charging!
    const ringR = 24;
    ctx.strokeStyle = isCharging ? 'rgba(255, 255, 255, 0.22)' : 'rgba(245, 208, 138, 0.22)';
    ctx.lineWidth = isCharging ? 4.5 : 1.5;
    ctx.beginPath();
    ctx.arc(originX, originY, ringR, 0, Math.PI * 2);
    ctx.stroke();

    // Classic Worms Previous-Shot Power Memory Tick (`◆`) on the Radial Ring!
    if (f.lastChargePower !== null && f.lastChargePower !== undefined) {
      const prevA = -Math.PI * 0.5 + clamp(f.lastChargePower, 0.04, 1.0) * Math.PI * 2;
      const mx = originX + Math.cos(prevA) * ringR;
      const my = originY + Math.sin(prevA) * ringR;
      ctx.save();
      ctx.fillStyle = '#7ec8e3';
      ctx.strokeStyle = '#0c1017';
      ctx.lineWidth = 1.2;
      ctx.beginPath();
      ctx.arc(mx, my, 3.3, 0, Math.PI * 2);
      ctx.fill();
      ctx.stroke();
      ctx.restore();
    }

    if (isCharging) {
      const startA = -Math.PI * 0.5;
      const endA = startA + clamp(chargePower, 0.04, 1.0) * Math.PI * 2;
      const ringCol = chargePower < 0.5
        ? '#ffd966'
        : (chargePower < 0.82 ? '#ff8b3d' : '#ff3b30');

      ctx.save();
      ctx.strokeStyle = ringCol;
      ctx.lineWidth = 4.8;
      ctx.lineCap = 'round';
      ctx.shadowColor = ringCol;
      ctx.shadowBlur = 10;
      ctx.beginPath();
      ctx.arc(originX, originY, ringR, startA, endA, false);
      ctx.stroke();
      ctx.restore();
    }
  } else if (wpn.id === 'PONT_PEDRA') {
    // Live Blueprint Preview of the Dry-Stone Wall / Bridge ("Marge de Pedra Seca")!
    const gx = originX + dirX * 52;
    const gy = originY + dirY * 52;
    ctx.save();
    ctx.translate(gx, gy);
    ctx.rotate(aimAngle);
    ctx.fillStyle = 'rgba(210, 200, 182, 0.36)';
    ctx.strokeStyle = '#ffe082';
    ctx.lineWidth = 1.8;
    ctx.setLineDash([4, 3]);
    ctx.beginPath();
    ctx.roundRect(-41, -8, 82, 16, 5);
    ctx.fill();
    ctx.stroke();
    ctx.restore();
  } else if (wpn.id === 'GANXO') {
    // Shepherd's Crook Grapple Sight Line & Latch Indicator!
    let latchX = originX + dirX * 480;
    let latchY = originY + dirY * 480;
    let canLatch = false;
    for (let d = 14; d <= 480; d += 5) {
      const rx = originX + dirX * d;
      const ry = originY + dirY * d;
      if (ry >= WATER_Y - 6) break;
      if (isSolid(rx, ry) || fighters.some(other => other !== f && other.alive && Math.hypot(other.x - rx, (other.y - 4) - ry) <= other.r + 8)) {
        latchX = rx;
        latchY = ry;
        canLatch = true;
        break;
      }
    }
    ctx.strokeStyle = canLatch ? 'rgba(134, 239, 172, 0.72)' : 'rgba(248, 113, 113, 0.45)';
    ctx.lineWidth = 1.8;
    ctx.setLineDash([5, 5]);
    ctx.beginPath();
    ctx.moveTo(originX + dirX * 18, originY + dirY * 18);
    ctx.lineTo(latchX, latchY);
    ctx.stroke();
    ctx.setLineDash([]);
    if (canLatch) {
      ctx.strokeStyle = '#86efac';
      ctx.lineWidth = 2.2;
      ctx.beginPath();
      ctx.arc(latchX, latchY, 7 + Math.sin(tNow * 10) * 1.5, 0, Math.PI * 2);
      ctx.stroke();
    }
  } else {
    // Clean minimalist directional reticle for Melee, Instant & Excavating Tools (El Fuet, La Falç, Pedrenyal, Cullera, Barrina)
    const cx = originX + dirX * 44;
    const cy = originY + dirY * 44;
    ctx.strokeStyle = 'rgba(245, 215, 150, 0.45)';
    ctx.lineWidth = 1.6;
    ctx.setLineDash([3, 4]);
    ctx.beginPath();
    ctx.moveTo(originX + dirX * 18, originY + dirY * 18);
    ctx.lineTo(cx, cy);
    ctx.stroke();
    ctx.setLineDash([]);

    ctx.strokeStyle = '#ffe082';
    ctx.lineWidth = 2.0;
    ctx.beginPath();
    ctx.arc(cx, cy, 6.5, 0, Math.PI * 2);
    ctx.stroke();
  }

  ctx.restore();
}

function drawBarrel(ctx, b) {
  ctx.save();
  ctx.translate(b.x, b.y);
  const g = ctx.createLinearGradient(-b.r, 0, b.r, 0);
  g.addColorStop(0, '#591c15');
  g.addColorStop(0.4, '#a63427');
  g.addColorStop(1, '#3b110c');
  ctx.fillStyle = g;
  ctx.strokeStyle = '#1a1210';
  ctx.lineWidth = 1.8;
  ctx.beginPath();
  ctx.roundRect(-b.r * 0.85, -b.r, b.r * 1.7, b.r * 2, 3);
  ctx.fill();
  ctx.stroke();

  ctx.strokeStyle = '#2d3138';
  ctx.lineWidth = 2.5;
  ctx.beginPath();
  ctx.moveTo(-b.r * 0.85, -b.r * 0.4); ctx.lineTo(b.r * 0.85, -b.r * 0.4);
  ctx.moveTo(-b.r * 0.85, b.r * 0.4);  ctx.lineTo(b.r * 0.85, b.r * 0.4);
  ctx.stroke();

  ctx.fillStyle = '#f3c66f';
  ctx.beginPath();
  ctx.moveTo(0, -4); ctx.lineTo(4, 0); ctx.lineTo(0, 4); ctx.lineTo(-4, 0);
  ctx.closePath();
  ctx.fill();
  ctx.restore();
}

function drawProjectile(ctx, p) {
  // Effects E1: Continuous Tapered Luminous Ribbon Trail behind flying projectiles
  if (p.trail && p.trail.length > 2) {
    ctx.save();
    ctx.lineCap = 'round';
    ctx.lineJoin = 'round';
    const isHoly = p.type === 'HOLY';
    const isUrticaria = p.type === 'URTICARIA';
    const isBazooka = p.type === 'BAZOOKA' || p.type === 'BOMBLER';
    for (let i = 1; i < p.trail.length; i++) {
      const frac = i / p.trail.length;
      const pt0 = p.trail[i - 1];
      const pt1 = p.trail[i];
      ctx.strokeStyle = isHoly
        ? `rgba(255, 222, 115, ${frac * 0.55})`
        : (isUrticaria
          ? `rgba(216, 138, 255, ${frac * 0.52})`
          : (isBazooka
            ? `rgba(255, 165, 75, ${frac * 0.48})`
            : `rgba(245, 238, 220, ${frac * 0.34})`));
      ctx.lineWidth = Math.max(1.0, frac * (isHoly ? 7.5 : (isBazooka ? 6.0 : 4.2)));
      ctx.beginPath();
      ctx.moveTo(pt0.x, pt0.y);
      ctx.lineTo(pt1.x, pt1.y);
      ctx.stroke();
    }
    ctx.restore();
  }

  ctx.save();
  ctx.translate(p.x, p.y);

  if (p.type === 'CARQUINYOLI') {
    ctx.rotate((p.ang || 0) + tNow * 14);
    if (p.isFuetSlice) {
      // Flying slice of cured Fuet de Vic with white rind & pork marbling!
      ctx.fillStyle = '#8a2434';
      ctx.strokeStyle = '#f4eee1';
      ctx.lineWidth = 2.2;
      ctx.beginPath();
      ctx.arc(0, 0, 6.2, 0, Math.PI * 2);
      ctx.fill();
      ctx.stroke();
      ctx.fillStyle = '#f4eee1';
      ctx.beginPath();
      ctx.arc(-2, -1.5, 1.2, 0, Math.PI * 2);
      ctx.arc(2, 1.5, 1.3, 0, Math.PI * 2);
      ctx.arc(1.5, -2, 0.9, 0, Math.PI * 2);
      ctx.fill();
    } else {
      // Spinning rock-hard Catalan Carquinyoli almond biscotti!
      ctx.fillStyle = '#c87d32';
      ctx.strokeStyle = '#5c310c';
      ctx.lineWidth = 1.5;
      ctx.beginPath();
      ctx.roundRect(-7.5, -4, 15, 8, 3.5);
      ctx.fill();
      ctx.stroke();

      // Embedded whole Marcona almonds
      ctx.fillStyle = '#fff5df';
      ctx.strokeStyle = '#7a4414';
      ctx.lineWidth = 0.8;
      ctx.beginPath();
      ctx.ellipse(-2.8, 0, 2.3, 1.4, 0.3, 0, Math.PI * 2);
      ctx.ellipse(2.8, -0.3, 2.1, 1.3, -0.25, 0, Math.PI * 2);
      ctx.fill();
      ctx.stroke();
    }
  } else if (p.type === 'BAZOOKA' || p.type === 'BOMBLER' || p.type === 'URTICARIA') {
    const ang = Math.atan2(p.vy, p.vx);
    ctx.rotate(ang);
    if (p.type === 'BOMBLER') {
      // Flaming individual Calçot bomblet!
      ctx.strokeStyle = '#f2ecdf';
      ctx.lineWidth = 3;
      ctx.beginPath();
      ctx.moveTo(-5, 0);
      ctx.lineTo(3, 0);
      ctx.stroke();
      ctx.strokeStyle = '#5ca856';
      ctx.lineWidth = 2.5;
      ctx.beginPath();
      ctx.moveTo(3, 0);
      ctx.lineTo(8, -2);
      ctx.moveTo(3, 0);
      ctx.lineTo(8, 2);
      ctx.stroke();
      ctx.fillStyle = '#ff6b2b';
      ctx.beginPath();
      ctx.arc(-5, 0, 3, 0, Math.PI * 2);
      ctx.fill();
    } else if (p.type === 'BAZOOKA') {
      // Heavy cast-iron Trabuc cannonball with glowing brass/ember rim!
      ctx.fillStyle = '#282d34';
      ctx.strokeStyle = '#d99b43';
      ctx.lineWidth = 1.6;
      ctx.beginPath();
      ctx.arc(0, 0, 6, 0, Math.PI * 2);
      ctx.fill();
      ctx.stroke();

      ctx.fillStyle = '#ff9b3b';
      ctx.beginPath();
      ctx.moveTo(-6, -2.5);
      ctx.lineTo(-15 - Math.random() * 6, 0);
      ctx.lineTo(-6, 2.5);
      ctx.closePath();
      ctx.fill();
    } else {
      // Urticating Hair Sac
      ctx.fillStyle = '#7a2eb0';
      ctx.strokeStyle = '#f5b945';
      ctx.lineWidth = 1.5;
      ctx.beginPath();
      ctx.ellipse(0, 0, 7, 4.5, 0, 0, Math.PI * 2);
      ctx.fill();
      ctx.stroke();

      ctx.fillStyle = '#d88aff';
      ctx.beginPath();
      ctx.moveTo(-7, -2);
      ctx.lineTo(-14 - Math.random() * 5, 0);
      ctx.lineTo(-7, 2);
      ctx.closePath();
      ctx.fill();
    }
  } else if (p.type === 'GRENADE' || p.type === 'CLUSTER' || p.type === 'HOLY') {
    ctx.rotate(p.ang || 0);
    if (p.type === 'HOLY') {
      // Sacred Golden Catalan Porró with angled spout & halo!
      const hg = ctx.createRadialGradient(0, 0, 2, 0, 0, 19);
      hg.addColorStop(0, 'rgba(255, 235, 145, 0.78)');
      hg.addColorStop(1, 'rgba(255, 200, 75, 0)');
      ctx.fillStyle = hg;
      ctx.beginPath();
      ctx.arc(0, 0, 19, 0, Math.PI * 2);
      ctx.fill();

      ctx.fillStyle = '#f0b849';
      ctx.strokeStyle = '#fff';
      ctx.lineWidth = 1.6;
      ctx.beginPath();
      ctx.moveTo(-5, 6);
      ctx.lineTo(-2, -6);
      ctx.lineTo(2, -6);
      ctx.lineTo(5, 6);
      ctx.closePath();
      ctx.fill();
      ctx.stroke();

      // Angled Porró drinking spout
      ctx.beginPath();
      ctx.moveTo(-3, 2);
      ctx.lineTo(-10, -4);
      ctx.stroke();

      // Ruby wine inside
      ctx.fillStyle = '#a81c1c';
      ctx.fillRect(-3.5, 1, 7, 4.5);

      // Holy Cross above neck
      ctx.strokeStyle = '#fff';
      ctx.lineWidth = 2;
      ctx.beginPath();
      ctx.moveTo(0, -13); ctx.lineTo(0, -7);
      ctx.moveTo(-3.5, -10.5); ctx.lineTo(3.5, -10.5);
      ctx.stroke();
    } else if (p.type === 'CLUSTER') {
      // Manat de Calçots (Bundle of grilled Calçots tied with red ribbon)
      ctx.strokeStyle = '#f2ecdf';
      ctx.lineWidth = 2.4;
      ctx.beginPath();
      ctx.moveTo(-3, 6); ctx.lineTo(-2, -2);
      ctx.moveTo(0, 6);  ctx.lineTo(0, -3);
      ctx.moveTo(3, 6);  ctx.lineTo(2, -2);
      ctx.stroke();
      ctx.strokeStyle = '#5ca856';
      ctx.lineWidth = 2.2;
      ctx.beginPath();
      ctx.moveTo(-2, -2); ctx.lineTo(-5, -7);
      ctx.moveTo(0, -3);  ctx.lineTo(0, -8);
      ctx.moveTo(2, -2);  ctx.lineTo(5, -7);
      ctx.stroke();
      ctx.fillStyle = '#d93829';
      ctx.fillRect(-4, -1, 8, 2.5);
    } else {
      // Pinya Explosiva (Pine Cone Grenade)
      ctx.fillStyle = '#7c4d2b';
      ctx.strokeStyle = '#241509';
      ctx.lineWidth = 1.6;
      ctx.beginPath();
      ctx.ellipse(0, 0, p.r, p.r * 1.15, 0, 0, Math.PI * 2);
      ctx.fill();
      ctx.stroke();
      ctx.strokeStyle = '#d9a15b';
      ctx.lineWidth = 1.1;
      ctx.beginPath();
      ctx.moveTo(-4, -2); ctx.lineTo(0, -5); ctx.lineTo(4, -2);
      ctx.moveTo(-4, 2);  ctx.lineTo(0, -1); ctx.lineTo(4, 2);
      ctx.stroke();
    }
    ctx.rotate(-(p.ang || 0));

    if (p.fuse !== undefined) {
      ctx.font = '700 12px "Plus Jakarta Sans", sans-serif';
      ctx.textAlign = 'center';
      ctx.fillStyle = p.type === 'HOLY' ? '#ffe57f' : '#fff';
      ctx.fillText(Math.ceil(p.fuse), 0, -14);
    }
  } else if (p.type === 'DYNAMITE') {
    // El Tió de Nadal (Smiling wooden log with red blanket, stick legs & Barretina!)
    ctx.strokeStyle = '#5c3818';
    ctx.lineWidth = 2.2;
    ctx.beginPath();
    ctx.moveTo(-5, 4); ctx.lineTo(-7, 10);
    ctx.moveTo(5, 4);  ctx.lineTo(7, 10);
    ctx.stroke();

    // Wooden log body
    ctx.fillStyle = '#8c5830';
    ctx.strokeStyle = '#241408';
    ctx.lineWidth = 1.6;
    ctx.beginPath();
    ctx.roundRect(-9, -5, 18, 10, 3);
    ctx.fill();
    ctx.stroke();

    // Red blanket on back half
    ctx.fillStyle = '#d93829';
    ctx.beginPath();
    ctx.roundRect(-9, -5, 9, 10, 2);
    ctx.fill();

    // Smiling face on front half
    ctx.fillStyle = '#fff';
    ctx.beginPath();
    ctx.arc(5, -1.5, 1.3, 0, Math.PI * 2);
    ctx.fill();
    ctx.strokeStyle = '#fff';
    ctx.lineWidth = 1.2;
    ctx.beginPath();
    ctx.arc(5, 1, 2.2, 0.1, Math.PI - 0.1);
    ctx.stroke();

    // Tiny Red Barretina Cap on top of Tió!
    ctx.fillStyle = '#e03228';
    ctx.beginPath();
    ctx.moveTo(2, -5);
    ctx.lineTo(8, -11);
    ctx.lineTo(11, -7);
    ctx.lineTo(7, -5);
    ctx.closePath();
    ctx.fill();

    // Sparking fuse
    ctx.fillStyle = Math.sin(tNow * 35) > 0 ? '#ffee77' : '#ff6622';
    ctx.beginPath();
    ctx.arc(-2, -9, 3.2, 0, Math.PI * 2);
    ctx.fill();

    if (p.fuse !== undefined) {
      ctx.font = '700 12px "Plus Jakarta Sans", sans-serif';
      ctx.textAlign = 'center';
      ctx.fillStyle = '#ffeb99';
      ctx.fillText(Math.ceil(p.fuse), 0, -15);
    }
  }

  ctx.restore();
}

function drawAirstrikePlane(ctx, pl) {
  ctx.save();
  ctx.translate(pl.x, pl.y);
  if (pl.vx < 0) ctx.scale(-1, 1);

  ctx.fillStyle = '#2b3038';
  ctx.strokeStyle = '#121418';
  ctx.lineWidth = 2;
  ctx.beginPath();
  ctx.moveTo(-42, -4);
  ctx.lineTo(36, 0);
  ctx.lineTo(48, 5);
  ctx.lineTo(-38, 7);
  ctx.closePath();
  ctx.fill();
  ctx.stroke();

  ctx.beginPath();
  ctx.moveTo(-32, -4);
  ctx.lineTo(-44, -18);
  ctx.lineTo(-22, -4);
  ctx.closePath();
  ctx.fill();

  ctx.fillStyle = '#ff9b42';
  ctx.beginPath();
  ctx.moveTo(-40, 0);
  ctx.lineTo(-58 - Math.random() * 10, 2);
  ctx.lineTo(-40, 5);
  ctx.closePath();
  ctx.fill();

  ctx.restore();
}

function drawWaterBack(ctx) {
  ctx.save();
  ctx.fillStyle = 'rgba(18, 38, 52, 0.72)';
  ctx.beginPath();
  // Span far beyond ultrawide horizontal (-4800..TERRAIN_W+4800) and vertical (TERRAIN_H+3600) bounds
  const leftEdge = -4800;
  const rightEdge = TERRAIN_W + 4800;
  const bottomEdge = TERRAIN_H + 3600;
  ctx.moveTo(leftEdge, bottomEdge);
  for (let x = leftEdge; x <= rightEdge; x += 32) {
    const wy = WATER_Y - 4 + Math.sin(x * 0.018 + tNow * 2.1) * 4;
    ctx.lineTo(x, wy);
  }
  ctx.lineTo(rightEdge, bottomEdge);
  ctx.closePath();
  ctx.fill();
  ctx.restore();
}

function drawWaterFront(ctx) {
  ctx.save();
  const mCfg = MAPS[currentMapIdx];
  const wg = ctx.createLinearGradient(0, WATER_Y, 0, TERRAIN_H + 220);
  wg.addColorStop(0, mCfg.waterTop);
  wg.addColorStop(1, mCfg.waterDeep);
  ctx.fillStyle = wg;

  const leftEdge = -4800;
  const rightEdge = TERRAIN_W + 4800;
  const bottomEdge = TERRAIN_H + 3600;
  const waveSpeed = tNow * (2.8 + wind * 0.025);
  ctx.beginPath();
  ctx.moveTo(leftEdge, bottomEdge);
  for (let x = leftEdge; x <= rightEdge; x += 28) {
    let wy = WATER_Y + Math.sin(x * 0.022 - waveSpeed) * 4.5 + Math.cos(x * 0.05 + tNow * 1.6) * 2;
    // Rendering R2: Interactive Wave Displacement from explosions and water plunges!
    for (let r = 0; r < waterRipples.length; r++) {
      const rp = waterRipples[r];
      const dist = Math.abs(x - rp.x);
      if (dist < 260) {
        const env = (1 - dist / 260) * rp.life;
        wy += Math.sin(dist * 0.09 - rp.phase * 14) * rp.amp * env;
      }
    }
    ctx.lineTo(x, wy);
  }
  ctx.lineTo(rightEdge, bottomEdge);
  ctx.closePath();
  ctx.fill();

  // Sunlit Specular Foam Crest
  ctx.strokeStyle = (mCfg.id === 'MONTSERRAT' || mCfg.id === 'CASTELLFOLLIT') ? 'rgba(255, 224, 170, 0.58)' : 'rgba(235, 248, 255, 0.56)';
  ctx.lineWidth = 2.4;
  ctx.stroke();

  // Rendering R2: Real-Time Water Surface Reflections (Horizon Sun/Moon Column + Live Fireball Blooms)
  ctx.save();
  ctx.globalCompositeOperation = 'screen';
  const sunRefX = TERRAIN_W * 0.68;
  const sunCol = (mCfg.id === 'MONTSERRAT' || mCfg.id === 'CASTELLFOLLIT') ? 'rgba(255, 195, 110, 0.14)' : 'rgba(200, 235, 255, 0.13)';
  ctx.fillStyle = sunCol;
  for (let band = 0; band < 7; band++) {
    const by = WATER_Y + 8 + band * 11;
    const bw = (95 - band * 9) + Math.sin(tNow * 3.2 + band * 1.4) * 18;
    const bx = sunRefX + Math.sin(tNow * 2.1 + band) * 10;
    ctx.fillRect(bx - bw * 0.5, by, bw, 4.5);
  }
  // Mirrored reflections of active volumetric fireballs & glowing projectiles on the water surface!
  for (const fb of fireballs) {
    if (fb.life > 0 && fb.y < WATER_Y + 60) {
      const refAlpha = clamp(fb.life * 0.38, 0, 0.42);
      const rg = ctx.createRadialGradient(fb.x, WATER_Y + 24, 4, fb.x, WATER_Y + 34, fb.r * 1.35);
      rg.addColorStop(0, fb.isHoly ? `rgba(255, 235, 140, ${refAlpha})` : `rgba(255, 150, 55, ${refAlpha})`);
      rg.addColorStop(1, 'rgba(255, 90, 20, 0)');
      ctx.fillStyle = rg;
      ctx.beginPath();
      ctx.ellipse(fb.x, WATER_Y + 28, fb.r * 1.35, fb.r * 0.45, 0, 0, Math.PI * 2);
      ctx.fill();
    }
  }
  ctx.restore();

  // Shimmering Sub-Surface Specular Ripples & Caustic Glints
  ctx.strokeStyle = (mCfg.id === 'MONTSERRAT' || mCfg.id === 'CASTELLFOLLIT') ? 'rgba(255, 215, 145, 0.24)' : 'rgba(195, 238, 255, 0.24)';
  ctx.lineWidth = 1.6;
  for (let row = 0; row < 3; row++) {
    const ry = WATER_Y + 14 + row * 18;
    ctx.beginPath();
    for (let sx = -400; sx < TERRAIN_W + 400; sx += 110) {
      const shimmerX = sx + Math.sin(tNow * 2.1 + row * 1.7 + sx * 0.01) * 22 + wind * 0.25;
      const shimmerLen = 28 + Math.sin(tNow * 3.4 + sx * 0.03 + row) * 14;
      if (shimmerLen > 18) {
        ctx.moveTo(shimmerX, ry);
        ctx.lineTo(shimmerX + shimmerLen, ry + Math.sin(sx + tNow) * 1.5);
      }
    }
    ctx.stroke();
  }
  ctx.restore();
}

