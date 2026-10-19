import { Vec2 } from '../engine/Vector.js';
import { PhysicsWorld, RigidBody, BodyType, ShapeType, PinJoint, DistanceConstraint } from '../engine/Physics.js';
import { StrokeProcessor, CrayonRenderer } from '../engine/Drawing.js';
import { SoundManager } from '../audio/Sound.js';
import { LEVEL_DATA } from './Levels.js';

export const GameState = {
    SPLASH: 'SPLASH',
    LEVEL_SELECT: 'LEVEL_SELECT',
    PLAYING: 'PLAYING',
    PAUSED: 'PAUSED',
    LEVEL_COMPLETE: 'LEVEL_COMPLETE',
    EDITOR: 'EDITOR'
};

export const ToolType = {
    DRAW: 'DRAW',
    PIN: 'PIN',
    ROPE: 'ROPE',
    ERASER: 'ERASER'
};

export class Game {
    constructor(canvas, uiManager) {
        this.canvas = canvas;
        this.ctx = canvas.getContext('2d');
        this.ui = uiManager;

        this.world = new PhysicsWorld();
        this.sound = new SoundManager();

        this.state = GameState.SPLASH;
        this.currentTool = ToolType.DRAW;
        this.currentLevelIndex = 0;
        this.customLevels = [];

        // Gameplay state
        this.ball = null;
        this.ballNudged = false; // Enforce single hit per attempt
        this.stars = [];
        this.playerShapes = [];
        this.drawnPoints = [];
        this.isDrawing = false;
        this.ropeStartPoint = null;
        this.ropeStartBody = null;
        this.currentMousePos = new Vec2(0, 0);

        this.levelTime = 0;
        this.unlockedLevels = 1;
        this.starsEarned = {};

        this.loadProgress();
        this.setupInputListeners();

        this.lastFrameTime = performance.now();
        requestAnimationFrame((t) => this.loop(t));
    }

    loadProgress() {
        try {
            const savedUnlocked = localStorage.getItem('crayon_unlocked');
            if (savedUnlocked) this.unlockedLevels = parseInt(savedUnlocked, 10);

            const savedStars = localStorage.getItem('crayon_stars');
            if (savedStars) this.starsEarned = JSON.parse(savedStars);

            const savedCustom = localStorage.getItem('crayon_custom_levels');
            if (savedCustom) this.customLevels = JSON.parse(savedCustom);
        } catch (e) {}
    }

    saveProgress() {
        try {
            localStorage.setItem('crayon_unlocked', this.unlockedLevels.toString());
            localStorage.setItem('crayon_stars', JSON.stringify(this.starsEarned));
            localStorage.setItem('crayon_custom_levels', JSON.stringify(this.customLevels));
        } catch (e) {}
    }

    loadLevel(index) {
        let level;
        if (index < LEVEL_DATA.length) {
            level = LEVEL_DATA[index];
            this.currentLevelIndex = index;
        } else {
            const customIdx = index - LEVEL_DATA.length;
            level = this.customLevels[customIdx];
            this.currentLevelIndex = index;
        }

        if (!level) return;

        this.world.clear();
        this.playerShapes = [];
        this.drawnPoints = [];
        this.isDrawing = false;
        this.ropeStartPoint = null;
        this.ropeStartBody = null;
        this.levelTime = 0;
        this.ballNudged = false;

        for (const polyVerts of level.terrain) {
            const terrainBody = new RigidBody({
                type: BodyType.STATIC,
                shapeType: ShapeType.POLYGON,
                vertices: polyVerts,
                color: '#dfd3be',
                restitution: 0.12,
                friction: 0.62
            });
            this.world.addBody(terrainBody);
        }

        this.ball = new RigidBody({
            type: BodyType.DYNAMIC,
            shapeType: ShapeType.CIRCLE,
            radius: 16,
            position: new Vec2(level.ball.x, level.ball.y),
            color: '#c84b31',
            restitution: 0.28,
            friction: 0.42,
            isBall: true
        });
        this.world.addBody(this.ball);

        this.stars = level.stars.map(s => ({
            x: s.x,
            y: s.y,
            collected: false
        }));

        if (level.dynamicBodies) {
            for (const bData of level.dynamicBodies) {
                const body = new RigidBody({
                    type: BodyType.DYNAMIC,
                    shapeType: ShapeType.POLYGON,
                    vertices: bData.vertices,
                    position: new Vec2(bData.position.x, bData.position.y),
                    color: bData.color || '#b86538',
                    restitution: 0.18,
                    friction: 0.52
                });
                this.world.addBody(body);

                if (bData.pinAt) {
                    const pin = new PinJoint(null, body, new Vec2(bData.pinAt.x, bData.pinAt.y));
                    this.world.addJoint(pin);
                }
            }
        }

        this.state = GameState.PLAYING;
        this.ui.updateHUD(level.title, level.description, this.stars.length);
    }

    restartLevel() {
        this.loadLevel(this.currentLevelIndex);
    }

    undoLastShape() {
        if (this.playerShapes.length > 0) {
            const shape = this.playerShapes.pop();
            this.world.removeBody(shape);
            this.sound.playErase();
        }
    }

    setupInputListeners() {
        const getCanvasCoords = (e) => {
            const rect = this.canvas.getBoundingClientRect();
            const scaleX = this.canvas.width / rect.width;
            const scaleY = this.canvas.height / rect.height;
            return new Vec2(
                (e.clientX - rect.left) * scaleX,
                (e.clientY - rect.top) * scaleY
            );
        };

        this.canvas.addEventListener('mousedown', (e) => {
            if (this.state !== GameState.PLAYING && this.state !== GameState.EDITOR) return;

            const pos = getCanvasCoords(e);
            this.sound.init();

            // Single-hit nudge rule on the ball
            if (this.ball && this.currentTool === ToolType.DRAW && pos.dist(this.ball.position) <= this.ball.radius * 2.2) {
                if (this.ballNudged) return;
                this.ballNudged = true;
                const nudgeDir = pos.x <= this.ball.position.x + 4 ? 1 : -1;
                this.ball.velocity.x += nudgeDir * 320;
                this.ball.velocity.y = Math.min(this.ball.velocity.y - 125, -125);
                this.ball.angularVelocity += nudgeDir * 14;
                this.sound.playNudge();
                return;
            }

            if (e.button === 2 || this.currentTool === ToolType.ERASER) {
                this.eraseAt(pos);
                return;
            }

            if (this.currentTool === ToolType.PIN) {
                this.placePinAt(pos);
                return;
            }

            if (this.currentTool === ToolType.ROPE) {
                this.ropeStartPoint = pos.copy();
                this.ropeStartBody = this.getBodyAt(pos);
                return;
            }

            this.isDrawing = true;
            this.drawnPoints = [pos];
            this.sound.playCrayonScratch();
        });

        this.canvas.addEventListener('mousemove', (e) => {
            const pos = getCanvasCoords(e);
            this.currentMousePos = pos;
            if (this.isDrawing) {
                const last = this.drawnPoints[this.drawnPoints.length - 1];
                if (last.dist(pos) > 5) {
                    this.drawnPoints.push(pos);
                    if (Math.random() < 0.3) this.sound.playCrayonScratch();
                }
            }
        });

        this.canvas.addEventListener('mouseup', (e) => {
            const pos = getCanvasCoords(e);

            if (this.ropeStartPoint && this.currentTool === ToolType.ROPE) {
                const endBody = this.getBodyAt(pos);
                if (pos.dist(this.ropeStartPoint) > 16) {
                    const distConstraint = new DistanceConstraint(
                        this.ropeStartBody,
                        endBody,
                        this.ropeStartPoint,
                        pos,
                        pos.dist(this.ropeStartPoint)
                    );
                    this.world.addConstraint(distConstraint);
                    this.sound.playButtonClick();
                }
                this.ropeStartPoint = null;
                this.ropeStartBody = null;
            }

            if (this.isDrawing) {
                this.isDrawing = false;
                this.finalizeDrawnShape();
            }
        });

        this.canvas.addEventListener('contextmenu', (e) => e.preventDefault());

        window.addEventListener('keydown', (e) => {
            if (e.key === 'r' || e.key === 'R') {
                if (this.state === GameState.PLAYING) this.restartLevel();
            } else if (e.key === 'z' || e.key === 'Z') {
                if (this.state === GameState.PLAYING) this.undoLastShape();
            } else if (e.key === 'm' || e.key === 'M') {
                this.sound.toggleMute();
            }
        });
    }

    getBodiesAt(pos) {
        const res = [];
        for (let i = this.world.bodies.length - 1; i >= 0; i--) {
            const body = this.world.bodies[i];
            if (body.shapeType === ShapeType.CIRCLE && pos.dist(body.position) <= body.radius) {
                res.push(body);
            } else if (body.shapeType === ShapeType.POLYGON) {
                for (const f of body.fixtures) {
                    if (this.pointInPolygon(pos, f.wv)) {
                        res.push(body);
                        break;
                    }
                }
            }
        }
        return res;
    }

    getBodyAt(pos) {
        const hits = this.getBodiesAt(pos);
        return hits.length ? hits[0] : null;
    }

    pointInPolygon(pt, verts) {
        let inside = false;
        for (let i = 0, j = verts.length - 1; i < verts.length; j = i++) {
            const xi = verts[i].x, yi = verts[i].y;
            const xj = verts[j].x, yj = verts[j].y;
            const intersect = ((yi > pt.y) !== (yj > pt.y)) &&
                (pt.x < (xj - xi) * (pt.y - yi) / (yj - yi) + xi);
            if (intersect) inside = !inside;
        }
        return inside;
    }

    placePinAt(pos) {
        const hits = this.getBodiesAt(pos).filter(b => !b.isBall);
        if (!hits.length) return;
        const pin = hits.length >= 2
            ? new PinJoint(hits[1], hits[0], pos)
            : new PinJoint(null, hits[0], pos);
        this.world.addJoint(pin);
        this.sound.playButtonClick();
    }

    eraseAt(pos) {
        const target = this.getBodyAt(pos);
        if (target && !target.isBall && target.type === BodyType.DYNAMIC) {
            this.world.removeBody(target);
            const pIdx = this.playerShapes.indexOf(target);
            if (pIdx !== -1) this.playerShapes.splice(pIdx, 1);
            this.sound.playErase();
        }
    }

    finalizeDrawnShape() {
        const classified = StrokeProcessor.classifyStroke(this.drawnPoints);
        if (classified) {
            const shapeColor = CrayonRenderer.getRandomColor();
            const drawnBody = new RigidBody({
                type: BodyType.DYNAMIC,
                shapeType: ShapeType.POLYGON,
                fixtures: classified.fixtures,
                vertices: classified.vertices,
                spinePts: classified.spinePts,
                isRibbon: classified.isRibbon,
                color: shapeColor,
                restitution: 0.18,
                friction: 0.5,
                isPlayerDrawn: true
            });
            this.world.addBody(drawnBody);
            this.playerShapes.push(drawnBody);
            this.sound.playButtonClick();
        }
        this.drawnPoints = [];
    }

    checkStarCollections() {
        if (!this.ball) return;
        let newlyCollected = false;
        for (const star of this.stars) {
            if (!star.collected) {
                const dist = this.ball.position.dist(new Vec2(star.x, star.y));
                if (dist < this.ball.radius + 22) {
                    star.collected = true;
                    newlyCollected = true;
                    this.sound.playStarPickup();
                }
            }
        }
        if (newlyCollected && this.stars.every(s => s.collected)) {
            this.handleLevelVictory();
        }
    }

    handleLevelVictory() {
        this.state = GameState.LEVEL_COMPLETE;
        if (this.currentLevelIndex + 1 >= this.unlockedLevels) {
            this.unlockedLevels = Math.min(LEVEL_DATA.length + this.customLevels.length, this.currentLevelIndex + 2);
        }
        this.starsEarned[this.currentLevelIndex] = this.stars.length;
        this.saveProgress();

        this.ui.showVictoryModal(this.currentLevelIndex, () => {
            if (this.currentLevelIndex + 1 < LEVEL_DATA.length + this.customLevels.length) {
                this.loadLevel(this.currentLevelIndex + 1);
            } else {
                this.state = GameState.LEVEL_SELECT;
                this.ui.showLevelSelect();
            }
        });
    }

    loop(timestamp) {
        const dt = Math.min((timestamp - this.lastFrameTime) / 1000, 0.033);
        this.lastFrameTime = timestamp;

        if (this.state === GameState.PLAYING) {
            this.levelTime += dt;
            this.world.step(dt);
            this.checkStarCollections();
        }

        this.render();
        requestAnimationFrame((t) => this.loop(t));
    }

    render() {
        const width = this.canvas.width;
        const height = this.canvas.height;

        CrayonRenderer.drawPaperBackground(this.ctx, width, height);

        if (this.state === GameState.PLAYING || this.state === GameState.LEVEL_COMPLETE || this.state === GameState.EDITOR) {
            for (const c of this.world.constraints) {
                CrayonRenderer.drawRope(this.ctx, c.getAnchorWorldA(), c.getAnchorWorldB());
            }

            for (const body of this.world.bodies) {
                if (body.isBall) {
                    CrayonRenderer.drawCrayonBall(this.ctx, body.position.x, body.position.y, body.radius, body.angle, body.color);
                } else if (body.shapeType === ShapeType.POLYGON) {
                    if (body.isRibbon && body.spineWorld.length >= 2) {
                        CrayonRenderer.drawCrayonPoly(this.ctx, body.spineWorld, body.color, false);
                    } else {
                        CrayonRenderer.drawCrayonPoly(this.ctx, body.worldVertices, body.color, true, body.type === BodyType.STATIC ? 0.85 : 0.28);
                    }
                }
            }

            for (const joint of this.world.joints) {
                const anchorB = joint.getAnchorWorldB();
                CrayonRenderer.drawPin(this.ctx, anchorB.x, anchorB.y);
            }

            for (const star of this.stars) {
                if (!star.collected) {
                    CrayonRenderer.drawCrayonStar(this.ctx, star.x, star.y, 20, this.levelTime);
                }
            }

            if (this.isDrawing && this.drawnPoints.length > 0) {
                CrayonRenderer.drawCrayonPoly(this.ctx, this.drawnPoints, '#c84b31', false);
            }

            if (this.ropeStartPoint) {
                CrayonRenderer.drawRope(this.ctx, this.ropeStartPoint, this.currentMousePos);
            }
        }
    }
}
