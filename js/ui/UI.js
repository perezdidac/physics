import { LEVEL_DATA } from '../game/Levels.js';
import { ToolType } from '../game/Game.js';

export class UIManager {
    constructor() {
        this.game = null;

        // UI DOM Elements
        this.splashOverlay = document.getElementById('splash-overlay');
        this.levelSelectOverlay = document.getElementById('level-select-overlay');
        this.victoryOverlay = document.getElementById('victory-overlay');
        this.editorOverlay = document.getElementById('editor-overlay');
        this.hud = document.getElementById('hud');

        this.levelTitleEl = document.getElementById('level-title');
        this.levelDescEl = document.getElementById('level-desc');
        this.levelGridEl = document.getElementById('level-grid');

        this.setupButtons();
    }

    setGame(game) {
        this.game = game;
    }

    setupButtons() {
        // Splash buttons
        document.getElementById('btn-play').addEventListener('click', () => {
            this.game.sound.startMusic();
            this.hideAllOverlays();
            this.game.loadLevel(0);
        });

        document.getElementById('btn-level-select').addEventListener('click', () => {
            this.game.sound.startMusic();
            this.showLevelSelect();
        });

        document.getElementById('btn-editor').addEventListener('click', () => {
            this.game.sound.startMusic();
            this.showEditor();
        });

        document.getElementById('btn-audio-toggle').addEventListener('click', () => {
            const isMuted = this.game.sound.toggleMute();
            document.getElementById('btn-audio-toggle').innerText = isMuted ? '🔇 Audio: OFF' : '🎵 Audio: ON';
        });

        // Level select back button
        document.getElementById('btn-level-select-back').addEventListener('click', () => {
            this.showSplash();
        });

        // HUD Tool buttons
        document.querySelectorAll('.tool-btn').forEach(btn => {
            btn.addEventListener('click', (e) => {
                document.querySelectorAll('.tool-btn').forEach(b => b.classList.remove('active'));
                const tool = e.currentTarget.getAttribute('data-tool');
                btn.classList.add('active');
                this.game.currentTool = ToolType[tool];
                this.game.sound.playButtonClick();
            });
        });

        // HUD Action buttons
        document.getElementById('btn-undo').addEventListener('click', () => {
            this.game.undoLastShape();
        });

        document.getElementById('btn-restart').addEventListener('click', () => {
            this.game.restartLevel();
        });

        document.getElementById('btn-menu').addEventListener('click', () => {
            this.showLevelSelect();
        });
    }

    hideAllOverlays() {
        this.splashOverlay.classList.add('hidden');
        this.levelSelectOverlay.classList.add('hidden');
        this.victoryOverlay.classList.add('hidden');
        this.editorOverlay.classList.add('hidden');
        this.hud.classList.remove('hidden');
    }

    showSplash() {
        this.hideAllOverlays();
        this.hud.classList.add('hidden');
        this.splashOverlay.classList.remove('hidden');
    }

    showLevelSelect() {
        this.hideAllOverlays();
        this.hud.classList.add('hidden');
        this.levelSelectOverlay.classList.remove('hidden');
        this.renderLevelGrid();
    }

    renderLevelGrid() {
        this.levelGridEl.innerHTML = '';
        const totalLevels = LEVEL_DATA.length + this.game.customLevels.length;

        for (let i = 0; i < totalLevels; i++) {
            const isUnlocked = i < this.game.unlockedLevels;
            const levelData = i < LEVEL_DATA.length ? LEVEL_DATA[i] : this.game.customLevels[i - LEVEL_DATA.length];

            const card = document.createElement('div');
            card.className = `level-card ${isUnlocked ? 'unlocked' : 'locked'}`;

            const starsCount = this.game.starsEarned[i] || 0;
            let starsHtml = '';
            for (let s = 0; s < 3; s++) {
                starsHtml += `<span class="star-icon ${s < starsCount ? 'earned' : ''}">★</span>`;
            }

            card.innerHTML = `
                <div class="level-num">Level ${i + 1}</div>
                <div class="level-card-title">${levelData.title || 'Custom Level'}</div>
                <div class="level-stars">${starsHtml}</div>
                ${!isUnlocked ? '<div class="lock-icon">🔒</div>' : ''}
            `;

            if (isUnlocked) {
                card.addEventListener('click', () => {
                    this.game.sound.playButtonClick();
                    this.hideAllOverlays();
                    this.game.loadLevel(i);
                });
            }

            this.levelGridEl.appendChild(card);
        }
    }

    updateHUD(title, description, totalStars) {
        this.levelTitleEl.innerText = title;
        this.levelDescEl.innerText = description;
    }

    showVictoryModal(levelIdx, onNext) {
        this.victoryOverlay.classList.remove('hidden');
        this.game.sound.playStarPickup();

        const btnNext = document.getElementById('btn-victory-next');
        const newBtn = btnNext.cloneNode(true);
        btnNext.parentNode.replaceChild(newBtn, btnNext);

        newBtn.addEventListener('click', () => {
            this.victoryOverlay.classList.add('hidden');
            onNext();
        });
    }

    showEditor() {
        this.hideAllOverlays();
        this.hud.classList.add('hidden');
        this.editorOverlay.classList.remove('hidden');

        document.getElementById('btn-editor-back').onclick = () => this.showSplash();
    }
}
