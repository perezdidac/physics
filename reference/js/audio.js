"use strict";

// ═══════════════════════════════════════════════════════════════════════════
//  3. AAA MULTI-LAYERED SYNTH AUDIO & EXPRESSIVE ORUGA VOICE CALLOUTS
// ═══════════════════════════════════════════════════════════════════════════
const SND = {
  ac: null,
  _masterComp: null,
  _fxSend: null,
  _noiseBuf: null,
  _windNode: null,
  _windFilter: null,
  _windGain: null,
  _lastSkid: 0,
  _lastJet: 0,
  _lastStep: 0,
  _lastHurtVoice: 0,
  musicEnabled: true,
  _musicStep: 0,
  _nextNoteTime: 0,

  // Formant vowel table (F1, F2 in Hz) scaled for cute high-pitched cartoon Worms / Oruga voices!
  _VOWELS: {
    A: [920, 1680],
    E: [640, 2320],
    I: [420, 2780],
    O: [590, 1120],
    U: [430, 940]
  },

  // 64-step (16-bar) Multi-Channel Catalan MIDI Score: "La Sardana de Ferro"
  // Lead = Tenora / Reed Oboe & Brass (MIDI notes, 0 = rest), Guitar = Chord Root/Triad, Bass = Pizzicato Tuba
  _MIDI_LEAD: [
    // Section A1 (Am -> Dm -> G7 -> C): Heroic & Playful Catalan Theme
    76, 81, 79, 76,   77, 74, 77, 81,   79, 71, 74, 79,   76, 72, 74, 76,
    // Section A2 (F -> Dm -> E7 -> Am): Expressive Cadence
    77, 81, 79, 77,   74, 77, 76, 74,   76, 80, 83, 80,   81, 76, 81,  0,
    // Section B1 (C -> G -> Am -> Em): Soaring Major Mediterranean Lift!
    79, 84, 83, 79,   83, 79, 74, 79,   81, 76, 72, 76,   79, 77, 76, 74,
    // Section B2 (F -> Dm -> Bdim7 -> E7 -> Am): Cobla Counterpoint & Finale Turnaround!
    77, 79, 81, 83,   84, 81, 77, 74,   76, 80, 83, 86,   81, 76, 81,  0
  ],
  _MIDI_HARMONY: [
    // Thirds/Sixths harmony voice that joins on phrases for rich MIDI brass/woodwind chorus!
     0, 76,  0, 72,    0, 69, 74, 77,    0, 67, 71, 74,   72,  0, 71, 72,
     0, 77,  0, 74,    0, 74, 72, 69,   71, 76, 80, 76,   76, 72, 76,  0,
    76, 79, 79, 76,   79, 74, 71, 74,   76, 72, 69, 72,   76, 74, 72, 71,
    74, 76, 77, 79,   81, 77, 74, 71,   71, 76, 80, 83,   76, 72, 76,  0
  ],
  _MIDI_CHORDS: [
    // 16 bars (4 steps per bar) of Spanish Guitar arpeggio chords
    [57, 60, 64, 69], [62, 65, 69, 74], [55, 59, 62, 67], [60, 64, 67, 72],
    [53, 57, 60, 65], [62, 65, 69, 74], [52, 56, 59, 64], [57, 60, 64, 69],
    [60, 64, 67, 72], [55, 59, 62, 67], [57, 60, 64, 69], [52, 55, 59, 64],
    [53, 57, 60, 65], [62, 65, 69, 74], [52, 56, 59, 64], [57, 60, 64, 69]
  ],
  _MIDI_BASS: [
    45,  0, 52,  0,   50,  0, 57,  0,   43,  0, 50,  0,   48,  0, 55, 52,
    41,  0, 48,  0,   50,  0, 45,  0,   40,  0, 47, 52,   45, 52, 45,  0,
    48,  0, 55,  0,   43,  0, 50,  0,   45,  0, 52,  0,   40,  0, 47,  0,
    41,  0, 48,  0,   50,  0, 45,  0,   40, 44, 47, 52,   45, 52, 45,  0
  ],

  init() {
    if (!this.ac) {
      const A = window.AudioContext || window.webkitAudioContext;
      if (A) {
        this.ac = new A();
        // Master Dynamics Compressor for punchy, non-clipping explosions, cartoon voices & MIDI music!
        this._masterComp = this.ac.createDynamicsCompressor();
        this._masterComp.threshold.value = -14;
        this._masterComp.knee.value = 18;
        this._masterComp.ratio.value = 4.5;
        this._masterComp.attack.value = 0.003;
        this._masterComp.release.value = 0.18;
        this._masterComp.connect(this.ac.destination);

        // Subtle Room Ambience Send Bus (tight, low-feedback short room reflection)
        this._fxSend = this.ac.createGain();
        this._fxSend.gain.value = 0.075;
        const delayNode = this.ac.createDelay(0.4);
        delayNode.delayTime.value = 0.11;
        const fbGain = this.ac.createGain();
        fbGain.gain.value = 0.12;
        const dampFlt = this.ac.createBiquadFilter();
        dampFlt.type = 'lowpass';
        dampFlt.frequency.value = 1800;
        this._fxSend.connect(delayNode);
        delayNode.connect(dampFlt);
        dampFlt.connect(fbGain);
        fbGain.connect(delayNode);
        dampFlt.connect(this._masterComp);

        // Pre-build 1.5s pink/white noise buffer
        const sr = this.ac.sampleRate;
        const len = Math.floor(sr * 1.5);
        this._noiseBuf = this.ac.createBuffer(1, len, sr);
        const data = this._noiseBuf.getChannelData(0);
        let b0 = 0, b1 = 0, b2 = 0;
        for (let i = 0; i < len; i++) {
          const white = Math.random() * 2 - 1;
          b0 = 0.997 * b0 + white * 0.029;
          b1 = 0.985 * b1 + white * 0.032;
          b2 = 0.950 * b2 + white * 0.048;
          data[i] = clamp((b0 + b1 + b2 + white * 0.18) * 0.55, -1, 1);
        }
        this._nextNoteTime = this.ac.currentTime + 0.08;
      }
    }
    if (this.ac && this.ac.state === 'suspended') this.ac.resume();
    this._ensureAmbientWind();
  },

  _dest() {
    return this._masterComp || (this.ac ? this.ac.destination : null);
  },

  _midiToFreq(m) {
    return 440 * Math.pow(2, (m - 69) / 12);
  },

  toggleMusic() {
    this.init();
    this.musicEnabled = !this.musicEnabled;
    if (this.musicEnabled && this.ac) {
      this._nextNoteTime = this.ac.currentTime + 0.05;
    }
    const lbl = document.getElementById('lbl-music');
    if (lbl) lbl.textContent = this.musicEnabled ? 'Música: Sí' : 'Música: No';
    return this.musicEnabled;
  },

  // MIDI Channel 1 & 2: Expressive Catalan Tenora / Reed Oboe + Brass Lead with Vibrato
  _playMidiLead(midiNote, startTime, dur, vol = 0.036, isHarmony = false) {
    if (!this.ac || midiNote <= 0) return;
    try {
      const freq = this._midiToFreq(midiNote);
      const o1 = this.ac.createOscillator();
      const o2 = this.ac.createOscillator();
      o1.type = isHarmony ? 'triangle' : 'sawtooth';
      o2.type = 'square';
      o1.frequency.setValueAtTime(freq, startTime);
      o2.frequency.setValueAtTime(freq * 1.0025, startTime); // Warm chorus detune

      // Expressive 5.5Hz Vibrato LFO
      const vib = this.ac.createOscillator();
      const vibGain = this.ac.createGain();
      vib.frequency.value = 5.6;
      vibGain.gain.setValueAtTime(0.1, startTime);
      vibGain.gain.linearRampToValueAtTime(freq * 0.0085, startTime + dur * 0.65);
      vib.connect(vibGain);
      vibGain.connect(o1.frequency);

      const flt = this.ac.createBiquadFilter();
      flt.type = 'lowpass';
      flt.frequency.setValueAtTime(freq * 2.2, startTime);
      flt.frequency.exponentialRampToValueAtTime(freq * 4.2, startTime + 0.04);
      flt.frequency.exponentialRampToValueAtTime(freq * 2.5, startTime + dur);
      flt.Q.value = 2.1;

      const mix2 = this.ac.createGain();
      mix2.gain.value = 0.28;
      const g = this.ac.createGain();
      g.gain.setValueAtTime(0.0001, startTime);
      g.gain.linearRampToValueAtTime(vol, startTime + 0.018);
      g.gain.setValueAtTime(vol * 0.82, startTime + dur * 0.65);
      g.gain.exponentialRampToValueAtTime(0.0001, startTime + dur);

      o1.connect(flt);
      o2.connect(mix2);
      mix2.connect(flt);
      flt.connect(g);
      g.connect(this._dest());
      if (this._fxSend) g.connect(this._fxSend);

      o1.start(startTime);
      o2.start(startTime);
      vib.start(startTime);
      o1.stop(startTime + dur + 0.01);
      o2.stop(startTime + dur + 0.01);
      vib.stop(startTime + dur + 0.01);
    } catch (e) {}
  },

  // MIDI Channel 3: Plucked Acoustic Spanish Guitar Arpeggio
  _playMidiGuitar(midiNote, startTime, dur, vol = 0.028) {
    if (!this.ac || midiNote <= 0) return;
    try {
      const freq = this._midiToFreq(midiNote);
      const o1 = this.ac.createOscillator();
      const o2 = this.ac.createOscillator();
      o1.type = 'sawtooth';
      o2.type = 'triangle';
      o1.frequency.setValueAtTime(freq, startTime);
      o2.frequency.setValueAtTime(freq * 2.0, startTime); // 2nd harmonic pluck sparkle

      const flt = this.ac.createBiquadFilter();
      flt.type = 'lowpass';
      flt.frequency.setValueAtTime(freq * 6.5, startTime);
      flt.frequency.exponentialRampToValueAtTime(freq * 1.4, startTime + dur * 0.85);
      flt.Q.value = 1.4;

      const g2 = this.ac.createGain();
      g2.gain.value = 0.25;
      const g = this.ac.createGain();
      g.gain.setValueAtTime(0.0001, startTime);
      g.gain.linearRampToValueAtTime(vol, startTime + 0.006);
      g.gain.exponentialRampToValueAtTime(0.0001, startTime + dur);

      o1.connect(flt);
      o2.connect(g2);
      g2.connect(flt);
      flt.connect(g);
      g.connect(this._dest());

      o1.start(startTime);
      o2.start(startTime);
      o1.stop(startTime + dur + 0.01);
      o2.stop(startTime + dur + 0.01);
    } catch (e) {}
  },

  // MIDI Channel 4: Warm Pizzicato Contrabass / Tuba
  _playMidiBass(midiNote, startTime, dur, vol = 0.048) {
    if (!this.ac || midiNote <= 0) return;
    try {
      const freq = this._midiToFreq(midiNote);
      const o1 = this.ac.createOscillator();
      const o2 = this.ac.createOscillator();
      o1.type = 'triangle';
      o2.type = 'sawtooth';
      o1.frequency.setValueAtTime(freq, startTime);
      o2.frequency.setValueAtTime(freq, startTime);

      const flt = this.ac.createBiquadFilter();
      flt.type = 'lowpass';
      flt.frequency.setValueAtTime(420, startTime);
      flt.frequency.exponentialRampToValueAtTime(135, startTime + dur);

      const g = this.ac.createGain();
      g.gain.setValueAtTime(0.0001, startTime);
      g.gain.linearRampToValueAtTime(vol, startTime + 0.01);
      g.gain.exponentialRampToValueAtTime(0.0001, startTime + dur);

      o1.connect(flt);
      o2.connect(flt);
      flt.connect(g);
      g.connect(this._dest());
      o1.start(startTime);
      o2.start(startTime);
      o1.stop(startTime + dur + 0.01);
      o2.stop(startTime + dur + 0.01);
    } catch (e) {}
  },

  // MIDI Channel 10: Catalan Timbal Kick, Martial Snare & Tambourine
  _playMidiPerc(stepInBar, startTime) {
    if (!this.ac || !this._noiseBuf) return;
    try {
      // Beats 0 & 2: Warm Pitched Timbal Kick
      if (stepInBar === 0 || stepInBar === 2) {
        const o = this.ac.createOscillator();
        const g = this.ac.createGain();
        o.type = 'sine';
        o.frequency.setValueAtTime(stepInBar === 0 ? 115 : 98, startTime);
        o.frequency.exponentialRampToValueAtTime(38, startTime + 0.13);
        g.gain.setValueAtTime(0.001, startTime);
        g.gain.linearRampToValueAtTime(stepInBar === 0 ? 0.042 : 0.028, startTime + 0.005);
        g.gain.exponentialRampToValueAtTime(0.0001, startTime + 0.14);
        o.connect(g);
        g.connect(this._dest());
        o.start(startTime);
        o.stop(startTime + 0.15);
      }
      // Beats 1 & 3: Crisp Tambourine / Snare tap
      const src = this.ac.createBufferSource();
      src.buffer = this._noiseBuf;
      const flt = this.ac.createBiquadFilter();
      const isSnare = (stepInBar === 1 || stepInBar === 3);
      flt.type = isSnare ? 'bandpass' : 'highpass';
      flt.frequency.value = isSnare ? 1850 : 5200;
      flt.Q.value = isSnare ? 1.5 : 0.8;
      const dur = isSnare ? 0.075 : 0.035;
      const vol = isSnare ? 0.018 : 0.008;
      const g = this.ac.createGain();
      g.gain.setValueAtTime(0.0001, startTime);
      g.gain.linearRampToValueAtTime(vol, startTime + 0.003);
      g.gain.exponentialRampToValueAtTime(0.0001, startTime + dur);
      src.connect(flt);
      flt.connect(g);
      g.connect(this._dest());
      src.start(startTime, 0.1, dur);
      src.stop(startTime + dur + 0.01);
    } catch (e) {}
  },

  _scheduleMidiMusic() {
    if (!this.ac || !this.musicEnabled || this.ac.state !== 'running') return;
    const now = this.ac.currentTime;
    // If scheduler fell behind (e.g. tab was backgrounded), resync cleanly
    if (this._nextNoteTime < now - 0.25 || this._nextNoteTime > now + 1.0) {
      this._nextNoteTime = now + 0.04;
    }
    const stepDur = 0.225; // ~133 BPM lively Catalan Sardana / Tactical March!
    while (this._nextNoteTime < now + 0.14) {
      const s = this._musicStep % 64;
      const barIdx = Math.floor(s / 4) % 16;
      const stepInBar = s % 4;
      const t = this._nextNoteTime;

      // 1. Lead Tenora / Brass Melody
      const leadNote = this._MIDI_LEAD[s];
      if (leadNote > 0) {
        // Hold note longer if next step is a rest (0)
        const nextIsRest = this._MIDI_LEAD[(s + 1) % 64] === 0;
        this._playMidiLead(leadNote, t, stepDur * (nextIsRest ? 1.85 : 0.92), 0.032, false);
      }

      // 2. Woodwind Harmony Counter-Voice
      const harmNote = this._MIDI_HARMONY[s];
      if (harmNote > 0) {
        this._playMidiLead(harmNote, t, stepDur * 0.88, 0.018, true);
      }

      // 3. Spanish Guitar Arpeggio
      const chord = this._MIDI_CHORDS[barIdx];
      if (chord) {
        const arpNote = chord[stepInBar % chord.length];
        this._playMidiGuitar(arpNote, t, stepDur * 0.90, 0.024);
      }

      // 4. Pizzicato Contrabass
      const bassNote = this._MIDI_BASS[s];
      if (bassNote > 0) {
        this._playMidiBass(bassNote, t, stepDur * 1.45, 0.044);
      }

      // 5. Timbal & Snare/Tambourine Percussion
      this._playMidiPerc(stepInBar, t);

      this._nextNoteTime += stepDur;
      this._musicStep = (this._musicStep + 1) % 64;
    }
  },

  _ensureAmbientWind() {
    if (!this.ac || !this._noiseBuf || this._windNode) return;
    try {
      const src = this.ac.createBufferSource();
      src.buffer = this._noiseBuf;
      src.loop = true;
      const flt = this.ac.createBiquadFilter();
      flt.type = 'bandpass';
      flt.frequency.value = 260;
      flt.Q.value = 3.2;
      const g = this.ac.createGain();
      g.gain.value = 0.0001;
      src.connect(flt);
      flt.connect(g);
      g.connect(this._dest());
      src.start();
      this._windNode = src;
      this._windFilter = flt;
      this._windGain = g;
    } catch (e) {}
  },

  updateAmbient(windVal, isPlaying) {
    if (!this.ac) return;
    this._scheduleMidiMusic();
    if (!this._windFilter || !this._windGain) return;
    try {
      const t = this.ac.currentTime;
      const mag = Math.abs(windVal);
      const targetFreq = 180 + mag * 4.8 + Math.sin(tNow * 1.7) * 35;
      const targetGain = isPlaying ? clamp(0.004 + (mag / 100) * 0.022, 0.003, 0.028) : 0.002;
      this._windFilter.frequency.setTargetAtTime(targetFreq, t, 0.12);
      this._windGain.gain.setTargetAtTime(targetGain, t, 0.15);
    } catch (e) {}
  },

  _noiseBurst(dur, vol, freq = 600, q = 1.2, filterType = 'lowpass', delay = 0) {
    if (!this.ac || !this._noiseBuf) return;
    try {
      const t = this.ac.currentTime + delay;
      const src = this.ac.createBufferSource();
      src.buffer = this._noiseBuf;
      const flt = this.ac.createBiquadFilter();
      flt.type = filterType;
      flt.frequency.setValueAtTime(freq, t);
      flt.frequency.exponentialRampToValueAtTime(Math.max(60, freq * 0.28), t + dur);
      flt.Q.value = q;
      const g = this.ac.createGain();
      g.gain.setValueAtTime(0.001, t);
      g.gain.linearRampToValueAtTime(vol, t + 0.006);
      g.gain.exponentialRampToValueAtTime(0.0001, t + dur);
      src.connect(flt);
      flt.connect(g);
      g.connect(this._dest());
      src.start(t, Math.random() * 0.4, dur);
      src.stop(t + dur);
    } catch (e) {}
  },

  _osc(type, f1, dur, vol, f2, delay = 0) {
    if (!this.ac) return;
    try {
      const t = this.ac.currentTime + delay;
      const o = this.ac.createOscillator();
      const g = this.ac.createGain();
      o.type = type;
      o.frequency.setValueAtTime(f1, t);
      if (f2) o.frequency.exponentialRampToValueAtTime(Math.max(16, f2), t + dur);
      g.gain.setValueAtTime(0.001, t);
      g.gain.linearRampToValueAtTime(vol, t + 0.008);
      g.gain.exponentialRampToValueAtTime(0.0001, t + dur);
      o.connect(g);
      g.connect(this._dest());
      o.start(t);
      o.stop(t + dur);
    } catch (e) {}
  },

  // ─────────────────────────────────────────────────────────────────────────
  //  FORMANT-SYNTHESIZED CARTOON WORMS VOICE ENGINE (`_speakSyllable`):
  //  Routes a high-pitched glottal pulse/sawtooth with pitch contour & vibrato
  //  through two swept resonant vowel formant filters (F1 & F2) so the worms
  //  sound genuinely expressive, funny, and vocal when jumping or getting hurt!
  // ─────────────────────────────────────────────────────────────────────────
  _speakSyllable(fStart, fEnd, dur, v1 = 'A', v2 = 'I', delay = 0, vol = 0.22, vibHz = 8.5, vibDepth = 18) {
    if (!this.ac) return;
    try {
      const t = this.ac.currentTime + delay;
      const glottal = this.ac.createOscillator();
      const subHarm = this.ac.createOscillator();
      glottal.type = 'sawtooth';
      subHarm.type = 'triangle';

      glottal.frequency.setValueAtTime(fStart, t);
      glottal.frequency.exponentialRampToValueAtTime(Math.max(80, fEnd), t + dur);
      subHarm.frequency.setValueAtTime(fStart * 0.5, t);
      subHarm.frequency.exponentialRampToValueAtTime(Math.max(40, fEnd * 0.5), t + dur);

      if (vibDepth > 0) {
        const lfo = this.ac.createOscillator();
        const lfoG = this.ac.createGain();
        lfo.frequency.value = vibHz;
        lfoG.gain.value = vibDepth;
        lfo.connect(lfoG);
        lfoG.connect(glottal.frequency);
        lfo.start(t);
        lfo.stop(t + dur + 0.01);
      }

      const fmtStart = this._VOWELS[v1] || this._VOWELS.A;
      const fmtEnd   = this._VOWELS[v2] || fmtStart;

      // Formant 1 (throat resonance)
      const flt1 = this.ac.createBiquadFilter();
      flt1.type = 'bandpass';
      flt1.Q.value = 4.2;
      flt1.frequency.setValueAtTime(fmtStart[0], t);
      flt1.frequency.exponentialRampToValueAtTime(fmtEnd[0], t + dur);

      // Formant 2 (mouth/tongue resonance)
      const flt2 = this.ac.createBiquadFilter();
      flt2.type = 'bandpass';
      flt2.Q.value = 5.5;
      flt2.frequency.setValueAtTime(fmtStart[1], t);
      flt2.frequency.exponentialRampToValueAtTime(fmtEnd[1], t + dur);

      const g = this.ac.createGain();
      g.gain.setValueAtTime(0.0001, t);
      g.gain.linearRampToValueAtTime(vol, t + Math.min(0.018, dur * 0.25));
      g.gain.setValueAtTime(vol * 0.85, t + dur * 0.72);
      g.gain.exponentialRampToValueAtTime(0.0001, t + dur);

      glottal.connect(flt1);
      glottal.connect(flt2);
      subHarm.connect(flt1);
      flt1.connect(g);
      flt2.connect(g);
      g.connect(this._dest());

      glottal.start(t);
      subHarm.start(t);
      glottal.stop(t + dur + 0.01);
      subHarm.stop(t + dur + 0.01);
    } catch (e) {}
  },

  wormVoice(mood) {
    if (!this.ac) return;
    const pick = Math.floor(Math.random() * 4);
    if (mood === 'JUMP') {
      // Cute high-pitched Worms jump cries: "Hup-aa!", "Iep!", "Uup-la!", "Boing-i!"
      if (pick === 0) {
        this._speakSyllable(420, 760, 0.13, 'U', 'A', 0.0, 0.24, 6, 8);
      } else if (pick === 1) {
        this._speakSyllable(480, 820, 0.11, 'I', 'E', 0.0, 0.23, 7, 10);
        this._speakSyllable(680, 790, 0.09, 'E', 'A', 0.09, 0.18, 6, 8);
      } else if (pick === 2) {
        this._speakSyllable(390, 710, 0.14, 'O', 'I', 0.0, 0.24, 8, 12);
      } else {
        this._speakSyllable(450, 620, 0.08, 'O', 'U', 0.0, 0.22, 5, 6);
        this._speakSyllable(580, 860, 0.11, 'A', 'I', 0.07, 0.23, 8, 12);
      }
    } else if (mood === 'BACKFLIP') {
      // Excited 3-syllable backflip somersault cries: "Yaa-hoo-oo!", "Alee-hop!", "Uoo-pa-la!"
      if (pick % 2 === 0) {
        this._speakSyllable(460, 680, 0.10, 'I', 'A', 0.0, 0.24, 7, 10);
        this._speakSyllable(680, 960, 0.22, 'U', 'O', 0.09, 0.26, 11, 24);
      } else {
        this._speakSyllable(440, 640, 0.09, 'U', 'O', 0.0, 0.22, 6, 8);
        this._speakSyllable(620, 780, 0.09, 'O', 'A', 0.08, 0.23, 8, 10);
        this._speakSyllable(760, 940, 0.16, 'A', 'I', 0.16, 0.25, 10, 20);
      }
    } else if (mood === 'ATTACK') {
      // Fierce little cartoon battle shout: "Foc-a!", "Toma-ja!"
      this._speakSyllable(520, 740, 0.09, 'O', 'A', 0.0, 0.22, 9, 14);
      this._speakSyllable(680, 560, 0.11, 'A', 'E', 0.08, 0.20, 8, 12);
    } else if (mood === 'OW') {
      // Expressive Worms hurt reactions: "Aii-yii-yii!", "Ouu-ch!", "Ui-ui-ui!", "Aaa-rg!"
      if (pick === 0) {
        // "Aii-yii-yii!"
        this._speakSyllable(780, 520, 0.12, 'A', 'I', 0.0, 0.28, 14, 28);
        this._speakSyllable(690, 440, 0.12, 'I', 'E', 0.11, 0.25, 14, 26);
        this._speakSyllable(590, 340, 0.15, 'I', 'U', 0.22, 0.22, 12, 22);
      } else if (pick === 1) {
        // "Ouu-aaah!"
        this._speakSyllable(660, 840, 0.09, 'O', 'A', 0.0, 0.28, 10, 18);
        this._speakSyllable(820, 310, 0.24, 'A', 'U', 0.08, 0.27, 15, 32);
      } else if (pick === 2) {
        // Fast squeaky "Ui-ui-ui!"
        this._speakSyllable(540, 860, 0.08, 'U', 'I', 0.0, 0.26, 9, 14);
        this._speakSyllable(580, 910, 0.08, 'U', 'I', 0.085, 0.26, 9, 14);
        this._speakSyllable(520, 760, 0.11, 'U', 'E', 0.17, 0.24, 11, 18);
      } else {
        // Sharp "Aii-ouch!"
        this._speakSyllable(840, 480, 0.13, 'A', 'I', 0.0, 0.28, 13, 25);
        this._speakSyllable(560, 270, 0.17, 'O', 'U', 0.12, 0.26, 11, 20);
      }
    } else if (mood === 'DEATH') {
      // Dramatic cartoon farewell wail: "Aaa-déu móóón..." + ascending angel chime!
      this._speakSyllable(760, 580, 0.14, 'A', 'E', 0.0, 0.28, 12, 22);
      this._speakSyllable(640, 420, 0.16, 'E', 'U', 0.13, 0.27, 11, 20);
      this._speakSyllable(520, 210, 0.34, 'O', 'U', 0.28, 0.26, 9, 25);
      [523.25, 659.25, 783.99, 1046.5].forEach((f, i) => {
        this._osc('sine', f, 0.22, 0.07, f * 1.01, 0.45 + i * 0.055);
      });
    } else if (mood === 'ITCH') {
      // Scratchy allergic "At-xim! Ui-ui!"
      this._speakSyllable(620, 880, 0.07, 'A', 'I', 0.0, 0.22, 16, 30);
      this._noiseBurst(0.08, 0.14, 2600, 2.2, 'bandpass', 0.06);
      this._speakSyllable(740, 490, 0.12, 'I', 'U', 0.11, 0.22, 15, 28);
    }
  },

  wormHurt(dmg = 15, isFatal = false) {
    this.init();
    if (!this.ac) return;
    // Meaty cartoon impact thwack + crunch
    const punch = clamp(dmg / 40, 0.45, 1.25);
    this._noiseBurst(0.08, 0.18 * punch, 950, 1.4, 'bandpass');
    this._osc('triangle', 175, 0.12, 0.24 * punch, 42);
    this._osc('sawtooth', 260, 0.08, 0.16 * punch, 68);

    // Rate-limit voice slightly so multi-worm explosions stagger cleanly instead of clipping
    const now = this.ac.currentTime;
    const delay = now < this._lastHurtVoice + 0.12 ? 0.11 : 0;
    this._lastHurtVoice = now + delay;
    setTimeout(() => {
      this.wormVoice(isFatal ? 'DEATH' : 'OW');
    }, delay * 1000);
  },

  crawlStep() {
    if (!this.ac || tNow - this._lastStep < 0.12) return;
    this._lastStep = tNow;
    // Cute squishy caterpillar proleg plip-plop step!
    const pitch = 240 + Math.random() * 90;
    this._osc('sine', pitch, 0.045, 0.045, pitch * 1.45);
    this._noiseBurst(0.035, 0.025, 1200 + Math.random() * 350, 2.4, 'bandpass');
  },

  shellWhistle() {
    this._osc('sine', 1120, 0.42, 0.055, 290);
    this._osc('triangle', 560, 0.42, 0.025, 145);
  },

  titleFanfare() {
    this.init();
    const notes = [440, 523.25, 659.25, 880, 783.99, 880];
    const durs  = [0.14, 0.14,   0.14,   0.26, 0.14,   0.48];
    let tOff = 0.02;
    notes.forEach((f, i) => {
      if (this.ac) {
        const m = Math.round(69 + 12 * Math.log2(f / 440));
        this._playMidiLead(m, this.ac.currentTime + tOff, durs[i], 0.065, false);
        this._playMidiBass(m - 12, this.ac.currentTime + tOff, durs[i] * 1.1, 0.055);
      }
      tOff += durs[i] * 0.85;
    });
  },

  urticatingBurst() {
    this._noiseBurst(0.28, 0.18, 1650, 1.8, 'bandpass');
    this._osc('sawtooth', 680, 0.28, 0.15, 160);
    this._osc('triangle', 980, 0.22, 0.11, 290, 0.03);
    this.wormVoice('ITCH');
  },

  jump() {
    // Tactile rubbery cartoon spring boing + turf kick + expressive Worms jump voice!
    this._noiseBurst(0.045, 0.07, 1100, 1.8, 'bandpass');
    this._osc('sine', 165, 0.19, 0.18, 540);
    this._osc('triangle', 240, 0.15, 0.11, 760, 0.02);
    this.wormVoice('JUMP');
  },

  backflip() {
    // Double-coiled acrobatic spring launch + whoosh + excited Worms backflip voice!
    this._noiseBurst(0.09, 0.11, 1600, 1.6, 'bandpass');
    this._osc('sine', 190, 0.12, 0.18, 520);
    this._osc('triangle', 310, 0.22, 0.18, 920, 0.07);
    this._osc('sine', 460, 0.16, 0.10, 1180, 0.12);
    this.wormVoice('BACKFLIP');
  },

  charge(pct) {
    // Crisp mechanical slingshot / blunderbuss power ratchet + rising harmonic tension!
    const f = 190 + pct * 480;
    this._osc('triangle', f, 0.055, 0.065, f * 1.12);
    this._osc('sawtooth', f * 0.5, 0.045, 0.035, f * 0.56);
    this._noiseBurst(0.02, 0.035, 1800 + pct * 1400, 3.0, 'bandpass');
  },

  fireBazooka() {
    // Heavy Trabuc blunderbuss cannon thump + propellant whoosh + battle cry!
    this._noiseBurst(0.28, 0.28, 820, 0.85, 'lowpass');
    this._noiseBurst(0.14, 0.18, 2200, 1.4, 'bandpass', 0.02);
    this._osc('sine', 155, 0.28, 0.30, 34);
    this._osc('sawtooth', 210, 0.22, 0.20, 48);
    this.wormVoice('ATTACK');
  },

  shotgun() {
    // Crisp 17th-century Pedrenyal flintlock spark-click + thunderous black-powder crack!
    this._noiseBurst(0.025, 0.16, 3800, 2.5, 'bandpass');
    this._noiseBurst(0.24, 0.32, 1450, 0.75, 'lowpass', 0.015);
    this._osc('sawtooth', 280, 0.19, 0.28, 36, 0.015);
    this._osc('square', 135, 0.16, 0.20, 28, 0.015);
    this.wormVoice('ATTACK');
  },

  homeRun() {
    this._osc('square', 960, 0.06, 0.26, 220);
    this._osc('triangle', 420, 0.14, 0.26, 95);
    this.wormVoice('ATTACK');
    [523.25, 659.25, 783.99, 1046.5].forEach((f, i) => {
      this._osc('triangle', f, 0.28, 0.11, f * 1.01, 0.07 + i * 0.04);
    });
  },

  hallelujah() {
    const chord = [523.25, 659.25, 783.99, 1046.5];
    chord.forEach(f => {
      this._osc('sine', f, 0.55, 0.11, f * 1.001, 0);
      this._osc('triangle', f * 0.5, 0.55, 0.07, f * 0.5, 0);
      this._osc('sine', f * 1.122, 0.78, 0.12, f * 1.122, 0.56);
    });
  },

  mineBeep() {
    this._osc('sine', 1320, 0.065, 0.12, 1320);
    this._osc('triangle', 2640, 0.045, 0.05, 2640);
  },

  cratePickup() {
    [587.33, 783.99, 987.77, 1174.66].forEach((f, i) => {
      this._osc('triangle', f, 0.18, 0.12, f * 1.01, i * 0.045);
      this._osc('sine', f * 2, 0.12, 0.05, f * 2, i * 0.045);
    });
  },

  jetThrust() {
    if (!this.ac || tNow - this._lastJet < 0.05) return;
    this._lastJet = tNow;
    this._noiseBurst(0.065, 0.08, 720, 1.2, 'bandpass');
    this._osc('sawtooth', 110 + Math.random() * 40, 0.065, 0.09, 58);
  },

  bounce() {
    // Tactile rubbery / rocky grenade & pinecone bounce!
    this._noiseBurst(0.045, 0.09, 760, 1.8, 'bandpass');
    this._osc('triangle', 185, 0.085, 0.14, 68);
    this._osc('sine', 290, 0.05, 0.08, 120);
  },

  tick() {
    this._osc('triangle', 920, 0.038, 0.075, 640);
    this._noiseBurst(0.015, 0.04, 2800, 3.0, 'bandpass');
  },

  boom(scale = 1) {
    // Multi-Stage Cinema Artillery Explosion:
    // 1) Sharp initial detonation snap, 2) Deep sub-bass chest thump, 3) Mid-range crunch & debris tail!
    const dur = clamp(0.62 * scale, 0.38, 1.15);
    this._noiseBurst(0.045, Math.min(0.38, 0.28 * scale), 2400, 1.2, 'bandpass');
    this._noiseBurst(dur, Math.min(0.42, 0.32 * scale), 640, 0.68, 'lowpass', 0.01);
    this._noiseBurst(dur * 0.75, Math.min(0.24, 0.18 * scale), 1450, 1.5, 'bandpass', 0.03);
    this._osc('sine', 115, dur * 0.85, Math.min(0.45, 0.36 * scale), 18);
    this._osc('sawtooth', 135, dur * 0.55, Math.min(0.32, 0.24 * scale), 22);
    this._osc('triangle', 72, dur * 0.92, Math.min(0.38, 0.30 * scale), 15);
  },

  hardSlam(speed) {
    const intensity = clamp(speed / 450, 0.45, 1.3);
    this._noiseBurst(0.14, 0.20 * intensity, 520, 1.1, 'lowpass');
    this._osc('triangle', 140, 0.18, 0.26 * intensity, 32);
    this._osc('sawtooth', 95, 0.14, 0.18 * intensity, 24);
    this.wormVoice('OW');
    if (speed > 360) {
      // Cartoon dizzy birds/stars tweeting!
      [740, 980, 820, 1120].forEach((f, i) => {
        this._osc('sine', f, 0.09, 0.07, f * 1.18, 0.14 + i * 0.065);
      });
    }
  },

  skid(speed) {
    if (!this.ac || tNow - this._lastSkid < 0.055) return;
    this._lastSkid = tNow;
    this._noiseBurst(0.05, Math.min(0.08, speed * 0.00025), 980, 2.0, 'bandpass');
    const f = 110 + Math.min(200, speed * 0.45) + Math.random() * 45;
    this._osc('triangle', f, 0.05, Math.min(0.09, speed * 0.0003), f * 0.7);
  },

  plunge() {
    // Lush Mediterranean water splash + bubbly cartoon "Glu-glu-glu!" drowning voice!
    this._noiseBurst(0.42, 0.28, 1150, 1.2, 'bandpass');
    this._noiseBurst(0.22, 0.18, 2800, 1.6, 'bandpass', 0.04);
    this._osc('sawtooth', 290, 0.28, 0.18, 48);
    this._osc('sine', 460, 0.22, 0.16, 90);
    // Bubbly underwater formant "Glu-glu-glu!"
    [0.14, 0.26, 0.38, 0.50].forEach((d, i) => {
      this._speakSyllable(340 + i * 55, 580 + i * 65, 0.10, 'U', 'O', d, 0.22, 18, 35);
    });
  },

  jet() {
    this._osc('sawtooth', 120, 0.32, 0.14, 290);
  },

  fuetWhip() {
    // Supersonic Fuet de Vic whip-crack + meaty slap + battle cry!
    this._noiseBurst(0.075, 0.26, 2600, 1.6, 'bandpass', 0.035);
    this._osc('sawtooth', 210, 0.09, 0.20, 1120);
    this._osc('square', 980, 0.065, 0.22, 130, 0.045);
    this._osc('triangle', 180, 0.15, 0.24, 44, 0.055);
    this.wormVoice('ATTACK');
  },

  carquinyoliCrunch() {
    // Rock-hard Catalan almond biscotti tooth-shattering ricochet!
    this._noiseBurst(0.05, 0.16, 1850, 2.0, 'bandpass');
    this._osc('square', 840, 0.05, 0.16, 310);
    this._osc('triangle', 1240, 0.045, 0.14, 480, 0.02);
  },

  rovelloBoing() {
    // Bouncy Catalan Rovelló mushroom spring launch!
    this._osc('sine', 180, 0.28, 0.24, 680);
    this._osc('triangle', 270, 0.24, 0.18, 920, 0.025);
    this.wormVoice('JUMP');
  },

  windGust() {
    // Soft Tramuntana wind gust shimmer
    this._noiseBurst(0.45, 0.08, 520, 2.6, 'bandpass');
    this._osc('sine', 240, 0.36, 0.055, 360);
    this._osc('triangle', 175, 0.38, 0.045, 115, 0.04);
  },

  caganerBlessing() {
    // Festive Catalan Gralla fanfare arpeggio!
    [523.25, 659.25, 783.99, 1046.5].forEach((f, i) => {
      if (this.ac) {
        const m = Math.round(69 + 12 * Math.log2(f / 440));
        this._playMidiLead(m, this.ac.currentTime + i * 0.06, 0.22, 0.06, false);
      }
    });
  },

  spoonScoop() {
    // Earthy wooden boxwood spoon scooping through soil & rock!
    this._noiseBurst(0.095, 0.16, 580, 1.6, 'bandpass');
    this._osc('triangle', 155, 0.095, 0.16, 260);
  },

  drillBore() {
    // Pneumatic Catalan quarry jackhammer percussive rock-drill pulse!
    this._noiseBurst(0.06, 0.18, 1120, 2.2, 'bandpass');
    this._osc('sawtooth', 98, 0.065, 0.18, 54);
    this._osc('square', 260, 0.045, 0.12, 115);
  },

  stoneBuild() {
    // Heavy dry-stone masonry ("Pedra Seca") thud & chime!
    this._noiseBurst(0.12, 0.20, 460, 1.5, 'lowpass');
    this._osc('triangle', 140, 0.18, 0.22, 62);
    this._osc('sine', 392, 0.16, 0.12, 523.25, 0.05);
  },

  grappleWhip() {
    // Pyrenean shepherd's crook rope zip & latch!
    this._noiseBurst(0.13, 0.16, 1950, 2.0, 'bandpass');
    this._osc('sine', 280, 0.19, 0.18, 760);
    this.wormVoice('JUMP');
  },

  victory() {
    [440, 554.37, 659.25, 880].forEach((f, i) => {
      if (this.ac) {
        const m = Math.round(69 + 12 * Math.log2(f / 440));
        this._playMidiLead(m, this.ac.currentTime + i * 0.08, 0.42, 0.065, false);
      }
    });
  }
};

