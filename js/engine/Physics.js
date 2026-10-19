import { Vec2 } from './Vector.js';

export const BodyType = {
    DYNAMIC: 0,
    STATIC: 1
};

export const ShapeType = {
    CIRCLE: 0,
    POLYGON: 1
};

export function signedPolygonArea(pts) {
    let a = 0;
    for (let i = 0, n = pts.length; i < n; i++) {
        const p = pts[i], q = pts[(i + 1) % n];
        a += p.x * q.y - q.x * p.y;
    }
    return a * 0.5;
}

export function ensureCCW(pts) {
    const copy = pts.map(p => p.copy());
    if (signedPolygonArea(copy) < 0) copy.reverse();
    return copy;
}

function ptInTriangle(p, a, b, c) {
    const c1 = (b.x - a.x) * (p.y - a.y) - (b.y - a.y) * (p.x - a.x);
    const c2 = (c.x - b.x) * (p.y - b.y) - (c.y - b.y) * (p.x - b.x);
    const c3 = (a.x - c.x) * (p.y - c.y) - (a.y - c.y) * (p.x - c.x);
    return (c1 >= -1e-5 && c2 >= -1e-5 && c3 >= -1e-5);
}

export function isConvexPolygon(pts) {
    if (pts.length < 3) return false;
    if (pts.length === 3) return true;
    let pos = 0, neg = 0;
    const n = pts.length;
    for (let i = 0; i < n; i++) {
        const a = pts[i], b = pts[(i + 1) % n], c = pts[(i + 2) % n];
        const cr = (b.x - a.x) * (c.y - b.y) - (b.y - a.y) * (c.x - b.x);
        if (cr > 1e-4) pos++;
        else if (cr < -1e-4) neg++;
        if (pos && neg) return false;
    }
    return true;
}

export function triangulatePolygon(pts) {
    const poly = ensureCCW(pts);
    if (poly.length < 3) return [];
    if (poly.length === 3 || isConvexPolygon(poly)) return [poly];

    const tris = [];
    const idx = poly.map((_, i) => i);
    let guard = idx.length * 4;

    while (idx.length > 3 && guard-- > 0) {
        let earFound = false;
        const m = idx.length;
        for (let i = 0; i < m; i++) {
            const iPrev = idx[(i + m - 1) % m];
            const iCurr = idx[i];
            const iNext = idx[(i + 1) % m];
            const a = poly[iPrev], b = poly[iCurr], c = poly[iNext];

            const cross = (b.x - a.x) * (c.y - a.y) - (b.y - a.y) * (c.x - a.x);
            if (cross <= 1e-3) continue;

            let hasPointInside = false;
            for (let j = 0; j < m; j++) {
                const vi = idx[j];
                if (vi === iPrev || vi === iCurr || vi === iNext) continue;
                if (ptInTriangle(poly[vi], a, b, c)) {
                    hasPointInside = true;
                    break;
                }
            }
            if (!hasPointInside) {
                tris.push([a.copy(), b.copy(), c.copy()]);
                idx.splice(i, 1);
                earFound = true;
                break;
            }
        }
        if (!earFound) {
            let cx = 0, cy = 0;
            for (const p of poly) { cx += p.x; cy += p.y; }
            cx /= poly.length; cy /= poly.length;
            const center = new Vec2(cx, cy);
            tris.length = 0;
            for (let i = 0; i < poly.length; i++) {
                const a = poly[i], b = poly[(i + 1) % poly.length];
                const tri = ensureCCW([center.copy(), a.copy(), b.copy()]);
                if (Math.abs(signedPolygonArea(tri)) > 4) tris.push(tri);
            }
            return tris;
        }
    }
    if (idx.length === 3) {
        tris.push([poly[idx[0]].copy(), poly[idx[1]].copy(), poly[idx[2]].copy()]);
    }
    return tris;
}

function computeConvexProps(verts) {
    const n = verts.length;
    let sa = 0, cx = 0, cy = 0;
    for (let i = 0; i < n; i++) {
        const p = verts[i], q = verts[(i + 1) % n];
        const c = p.x * q.y - q.x * p.y;
        sa += c;
        cx += (p.x + q.x) * c;
        cy += (p.y + q.y) * c;
    }
    sa *= 0.5;
    const area = Math.max(Math.abs(sa), 1);
    if (Math.abs(sa) > 1e-5) {
        cx /= (6 * sa);
        cy /= (6 * sa);
    } else {
        cx = verts.reduce((s, p) => s + p.x, 0) / n;
        cy = verts.reduce((s, p) => s + p.y, 0) / n;
    }
    const centroid = new Vec2(cx, cy);
    let I = 0;
    for (let i = 0; i < n; i++) {
        const p = verts[i].sub(centroid);
        const q = verts[(i + 1) % n].sub(centroid);
        const c = Math.abs(p.cross(q));
        I += (p.lengthSq() + q.lengthSq() + p.dot(q)) * c / 12;
    }
    return { area, centroid, I };
}

export class RigidBody {
    constructor(options = {}) {
        this.id = options.id || Math.random().toString(36).substr(2, 9);
        this.seed = options.seed || Math.floor(Math.random() * 100000);
        this.type = options.type !== undefined ? options.type : BodyType.DYNAMIC;
        this.shapeType = options.shapeType !== undefined ? options.shapeType : ShapeType.POLYGON;

        this.position = options.position ? options.position.copy() : new Vec2(0, 0);
        this.velocity = options.velocity ? options.velocity.copy() : new Vec2(0, 0);
        this.force = new Vec2(0, 0);

        this.angle = options.angle || 0;
        this.angularVelocity = options.angularVelocity || 0;
        this.torque = 0;

        this.restitution = options.restitution !== undefined ? options.restitution : 0.22;
        this.friction = options.friction !== undefined ? options.friction : 0.48;

        this.color = options.color || '#c84b31';
        this.isBall = options.isBall || false;
        this.isStar = options.isStar || false;
        this.isPlayerDrawn = options.isPlayerDrawn || false;
        this.isRibbon = !!options.isRibbon;

        this.radius = options.radius || 16;
        this.vertices = [];
        this.worldVertices = [];
        this.spineLocal = [];
        this.spineWorld = [];
        this.fixtures = [];
        this.aabb = { min: new Vec2(), max: new Vec2() };

        if (this.shapeType === ShapeType.POLYGON) {
            if (options.fixtures && options.fixtures.length > 0) {
                this.setCompoundFixtures(options.fixtures, options.vertices || options.fixtures[0], options.spinePts || null, options.density);
            } else if (options.vertices && options.vertices.length >= 3) {
                const worldVerts = options.position && (options.position.x !== 0 || options.position.y !== 0)
                    ? options.vertices.map(v => v.add(options.position))
                    : options.vertices;
                if (options.position) this.position.set(0, 0);
                const tris = triangulatePolygon(worldVerts);
                this.setCompoundFixtures(tris, ensureCCW(worldVerts), null, options.density);
            }
        } else {
            const density = options.density || 0.0022;
            const area = Math.PI * this.radius * this.radius;
            const mass = this.type === BodyType.STATIC ? 0 : area * density;
            this.setMassProperties(mass, 0.5 * mass * this.radius * this.radius);
        }

        this.updateWorldVertices();
    }

    setCompoundFixtures(convexPolys, outlineVerts, spinePts = null, density = 0.0018) {
        let totalArea = 0, cx = 0, cy = 0;
        const props = convexPolys.map(poly => {
            const ccw = ensureCCW(poly);
            const pr = computeConvexProps(ccw);
            totalArea += pr.area;
            cx += pr.centroid.x * pr.area;
            cy += pr.centroid.y * pr.area;
            return { verts: ccw, ...pr };
        });

        if (totalArea < 1) totalArea = 1;
        const com = new Vec2(cx / totalArea, cy / totalArea);
        this.position.addSelf(com);
        this.vertices = outlineVerts.map(v => v.sub(com));
        if (spinePts) {
            this.spineLocal = spinePts.map(v => v.sub(com));
        }

        let totalI = 0;
        this.fixtures = props.map(pr => {
            const shifted = pr.verts.map(v => v.sub(com));
            const lc = pr.centroid.sub(com);
            totalI += pr.I + pr.area * lc.lengthSq();
            return {
                lv: shifted,
                wv: shifted.map(v => v.copy()),
                lc,
                wc: lc.copy(),
                aabb: { min: new Vec2(), max: new Vec2() }
            };
        });

        const mass = this.type === BodyType.STATIC ? 0 : Math.max(totalArea * density, 0.08);
        const inertia = this.type === BodyType.STATIC ? 0 : Math.max(totalI * density, mass * 140);
        this.setMassProperties(mass, inertia);
    }

    setMassProperties(mass, inertia) {
        if (this.type === BodyType.STATIC || mass === 0) {
            this.mass = 0;
            this.invMass = 0;
            this.inertia = 0;
            this.invInertia = 0;
        } else {
            this.mass = mass;
            this.invMass = 1 / mass;
            this.inertia = Math.max(inertia, 80);
            this.invInertia = 1 / this.inertia;
        }
    }

    updateWorldVertices() {
        if (this.shapeType === ShapeType.POLYGON) {
            const cos = Math.cos(this.angle);
            const sin = Math.sin(this.angle);

            this.worldVertices = this.vertices.map(v => new Vec2(
                this.position.x + v.x * cos - v.y * sin,
                this.position.y + v.x * sin + v.y * cos
            ));

            if (this.isRibbon && this.spineLocal.length) {
                this.spineWorld = this.spineLocal.map(v => new Vec2(
                    this.position.x + v.x * cos - v.y * sin,
                    this.position.y + v.x * sin + v.y * cos
                ));
            }

            let minX = Infinity, minY = Infinity, maxX = -Infinity, maxY = -Infinity;
            for (const f of this.fixtures) {
                let fx0 = Infinity, fy0 = Infinity, fx1 = -Infinity, fy1 = -Infinity;
                for (let i = 0; i < f.lv.length; i++) {
                    const p = f.lv[i];
                    const wx = this.position.x + p.x * cos - p.y * sin;
                    const wy = this.position.y + p.x * sin + p.y * cos;
                    f.wv[i].set(wx, wy);
                    if (wx < fx0) fx0 = wx; if (wy < fy0) fy0 = wy;
                    if (wx > fx1) fx1 = wx; if (wy > fy1) fy1 = wy;
                }
                f.wc.set(
                    this.position.x + f.lc.x * cos - f.lc.y * sin,
                    this.position.y + f.lc.x * sin + f.lc.y * cos
                );
                f.aabb.min.set(fx0, fy0);
                f.aabb.max.set(fx1, fy1);
                if (fx0 < minX) minX = fx0; if (fy0 < minY) minY = fy0;
                if (fx1 > maxX) maxX = fx1; if (fy1 > maxY) maxY = fy1;
            }
            this.aabb.min.set(minX, minY);
            this.aabb.max.set(maxX, maxY);
        } else {
            this.aabb.min.set(this.position.x - this.radius, this.position.y - this.radius);
            this.aabb.max.set(this.position.x + this.radius, this.position.y + this.radius);
        }
    }

    applyImpulse(impulse, point) {
        if (this.type === BodyType.STATIC) return;
        this.velocity.addSelf(impulse.scale(this.invMass));
        if (point) {
            const r = point.sub(this.position);
            this.angularVelocity += this.invInertia * r.cross(impulse);
        }
    }
}

export class PinJoint {
    constructor(bodyA, bodyB, anchorWorld) {
        this.bodyA = bodyA;
        this.bodyB = bodyB;
        this.anchorWorld = anchorWorld.copy();
        this.localAnchorA = bodyA ? anchorWorld.sub(bodyA.position).rotate(-bodyA.angle) : anchorWorld.copy();
        this.localAnchorB = bodyB ? anchorWorld.sub(bodyB.position).rotate(-bodyB.angle) : anchorWorld.copy();
    }

    solve(sdt = 1 / 600) {
        const aDyn = this.bodyA && this.bodyA.type === BodyType.DYNAMIC;
        const bDyn = this.bodyB && this.bodyB.type === BodyType.DYNAMIC;
        if (!aDyn && !bDyn) return;

        const pA = this.getAnchorWorldA();
        const pB = this.getAnchorWorldB();
        const rA = this.bodyA ? pA.sub(this.bodyA.position) : new Vec2(0, 0);
        const rB = this.bodyB ? pB.sub(this.bodyB.position) : new Vec2(0, 0);

        const imA = aDyn ? this.bodyA.invMass : 0;
        const iiA = aDyn ? this.bodyA.invInertia : 0;
        const imB = bDyn ? this.bodyB.invMass : 0;
        const iiB = bDyn ? this.bodyB.invInertia : 0;

        const k11 = imA + imB + iiA * rA.y * rA.y + iiB * rB.y * rB.y;
        const k12 = -iiA * rA.x * rA.y - iiB * rB.x * rB.y;
        const k22 = imA + imB + iiA * rA.x * rA.x + iiB * rB.x * rB.x;

        const det = k11 * k22 - k12 * k12;
        if (Math.abs(det) < 1e-9) return;
        const invDet = 1 / det;

        const vA = aDyn ? this.bodyA.velocity.add(Vec2.crossScalarVec(this.bodyA.angularVelocity, rA)) : new Vec2(0, 0);
        const vB = bDyn ? this.bodyB.velocity.add(Vec2.crossScalarVec(this.bodyB.angularVelocity, rB)) : new Vec2(0, 0);
        const err = pB.sub(pA);
        const bias = err.scale(0.28 / sdt);
        const Cdot = vB.sub(vA).add(bias);

        const jx = -invDet * (k22 * Cdot.x - k12 * Cdot.y);
        const jy = -invDet * (-k12 * Cdot.x + k11 * Cdot.y);
        const imp = new Vec2(jx, jy);

        if (aDyn) {
            this.bodyA.applyImpulse(imp.scale(-1), pA);
            this.bodyA.updateWorldVertices();
        }
        if (bDyn) {
            this.bodyB.applyImpulse(imp, pB);
            this.bodyB.updateWorldVertices();
        }
    }

    getAnchorWorldA() {
        if (!this.bodyA) return this.localAnchorA.copy();
        return this.bodyA.position.add(this.localAnchorA.rotate(this.bodyA.angle));
    }

    getAnchorWorldB() {
        if (!this.bodyB) return this.localAnchorB.copy();
        return this.bodyB.position.add(this.localAnchorB.rotate(this.bodyB.angle));
    }
}

export class DistanceConstraint {
    constructor(bodyA, bodyB, anchorWorldA, anchorWorldB, length) {
        this.bodyA = bodyA;
        this.bodyB = bodyB;
        this.localAnchorA = bodyA ? anchorWorldA.sub(bodyA.position).rotate(-bodyA.angle) : anchorWorldA.copy();
        this.localAnchorB = bodyB ? anchorWorldB.sub(bodyB.position).rotate(-bodyB.angle) : anchorWorldB.copy();
        this.length = Math.max(length !== undefined ? length : anchorWorldA.dist(anchorWorldB), 16);
    }

    solve(sdt = 1 / 600) {
        const aDyn = this.bodyA && this.bodyA.type === BodyType.DYNAMIC;
        const bDyn = this.bodyB && this.bodyB.type === BodyType.DYNAMIC;
        if (!aDyn && !bDyn) return;

        const pA = this.getAnchorWorldA();
        const pB = this.getAnchorWorldB();
        const d = pB.sub(pA);
        const curLen = d.length();
        if (curLen <= this.length || curLen < 1e-5) return;

        const n = d.scale(1 / curLen);
        const rA = this.bodyA ? pA.sub(this.bodyA.position) : new Vec2(0, 0);
        const rB = this.bodyB ? pB.sub(this.bodyB.position) : new Vec2(0, 0);

        const imA = aDyn ? this.bodyA.invMass : 0;
        const iiA = aDyn ? this.bodyA.invInertia : 0;
        const imB = bDyn ? this.bodyB.invMass : 0;
        const iiB = bDyn ? this.bodyB.invInertia : 0;

        const rAn = rA.cross(n), rBn = rB.cross(n);
        const kMass = imA + imB + iiA * rAn * rAn + iiB * rBn * rBn;
        if (kMass < 1e-9) return;

        const vA = aDyn ? this.bodyA.velocity.add(Vec2.crossScalarVec(this.bodyA.angularVelocity, rA)) : new Vec2(0, 0);
        const vB = bDyn ? this.bodyB.velocity.add(Vec2.crossScalarVec(this.bodyB.angularVelocity, rB)) : new Vec2(0, 0);
        const relVn = vB.sub(vA).dot(n);
        const err = curLen - this.length;
        const bias = (err * 0.25) / sdt;

        const lambda = -(relVn + bias) / kMass;
        if (lambda < 0) {
            const imp = n.scale(lambda);
            if (aDyn) { this.bodyA.applyImpulse(imp.scale(-1), pA); this.bodyA.updateWorldVertices(); }
            if (bDyn) { this.bodyB.applyImpulse(imp, pB); this.bodyB.updateWorldVertices(); }
        }
    }

    getAnchorWorldA() {
        if (!this.bodyA) return this.localAnchorA.copy();
        return this.bodyA.position.add(this.localAnchorA.rotate(this.bodyA.angle));
    }

    getAnchorWorldB() {
        if (!this.bodyB) return this.localAnchorB.copy();
        return this.bodyB.position.add(this.localAnchorB.rotate(this.bodyB.angle));
    }
}

function ptInPoly(pt, vs) {
    let inside = false;
    for (let i = 0, j = vs.length - 1; i < vs.length; j = i++) {
        const xi = vs[i].x, yi = vs[i].y, xj = vs[j].x, yj = vs[j].y;
        if (((yi > pt.y) !== (yj > pt.y)) && pt.x < (xj - xi) * (pt.y - yi) / (yj - yi) + xi)
            inside = !inside;
    }
    return inside;
}

function closestPtOnSeg(p, a, b) {
    const ab = b.sub(a);
    const lenSq = ab.lengthSq();
    if (lenSq < 1e-9) return a.copy();
    const t = Math.max(0, Math.min(1, p.sub(a).dot(ab) / lenSq));
    return a.add(ab.scale(t));
}

function closestPtOnPoly(p, vs) {
    let best = vs[0], bestDSq = Infinity;
    for (let i = 0; i < vs.length; i++) {
        const q = closestPtOnSeg(p, vs[i], vs[(i + 1) % vs.length]);
        const dSq = p.distSq(q);
        if (dSq < bestDSq) { bestDSq = dSq; best = q; }
    }
    return best;
}

export class PhysicsWorld {
    constructor() {
        this.gravity = new Vec2(0, 560);
        this.bodies = [];
        this.joints = [];
        this.constraints = [];
        this.substeps = 10;
    }

    addBody(body) {
        this.bodies.push(body);
        return body;
    }

    removeBody(body) {
        const idx = this.bodies.indexOf(body);
        if (idx !== -1) this.bodies.splice(idx, 1);
        this.joints = this.joints.filter(j => j.bodyA !== body && j.bodyB !== body);
        this.constraints = this.constraints.filter(c => c.bodyA !== body && c.bodyB !== body);
    }

    addJoint(joint) {
        this.joints.push(joint);
        return joint;
    }

    addConstraint(constraint) {
        this.constraints.push(constraint);
        return constraint;
    }

    clear() {
        this.bodies = [];
        this.joints = [];
        this.constraints = [];
    }

    step(dt) {
        const subDt = dt / this.substeps;

        for (let step = 0; step < this.substeps; step++) {
            for (const body of this.bodies) {
                if (body.type === BodyType.DYNAMIC) {
                    body.velocity.addSelf(this.gravity.scale(subDt));
                    body.velocity.scaleSelf(0.9991);
                    body.angularVelocity *= 0.996;
                    body.position.addSelf(body.velocity.scale(subDt));
                    body.angle += body.angularVelocity * subDt;
                    body.updateWorldVertices();
                }
            }

            for (let iter = 0; iter < 3; iter++) {
                for (const joint of this.joints) joint.solve(subDt);
                for (const constraint of this.constraints) constraint.solve(subDt);
            }

            for (let i = 0; i < this.bodies.length; i++) {
                for (let j = i + 1; j < this.bodies.length; j++) {
                    const a = this.bodies[i];
                    const b = this.bodies[j];
                    if (a.type === BodyType.STATIC && b.type === BodyType.STATIC) continue;
                    if (!this.checkAABBOverlap(a.aabb, b.aabb)) continue;

                    const contacts = this.detectCollisions(a, b);
                    if (contacts) {
                        for (const m of contacts) this.solveCollision(m);
                        a.updateWorldVertices();
                        b.updateWorldVertices();
                    }
                }
            }
        }
    }

    checkAABBOverlap(a, b) {
        return (a.min.x <= b.max.x && a.max.x >= b.min.x &&
                a.min.y <= b.max.y && a.max.y >= b.min.y);
    }

    detectCollisions(a, b) {
        if (a.shapeType === ShapeType.CIRCLE && b.shapeType === ShapeType.CIRCLE) {
            const m = this.collideCircleCircle(a, b);
            return m ? [m] : null;
        }
        if (a.shapeType === ShapeType.CIRCLE && b.shapeType === ShapeType.POLYGON) {
            const list = [];
            for (const f of b.fixtures) {
                if (!this.checkAABBOverlap(a.aabb, f.aabb)) continue;
                const m = this.collideCircleFixture(a, b, f);
                if (m) list.push(m);
            }
            if (!list.length) return null;
            list.sort((x, y) => y.penetration - x.penetration);
            return [list[0]];
        }
        if (a.shapeType === ShapeType.POLYGON && b.shapeType === ShapeType.CIRCLE) {
            const list = [];
            for (const f of a.fixtures) {
                if (!this.checkAABBOverlap(f.aabb, b.aabb)) continue;
                const m = this.collideCircleFixture(b, a, f);
                if (m) {
                    m.normal.scaleSelf(-1);
                    m.bodyA = a;
                    m.bodyB = b;
                    list.push(m);
                }
            }
            if (!list.length) return null;
            list.sort((x, y) => y.penetration - x.penetration);
            return [list[0]];
        }

        const list = [];
        for (const fa of a.fixtures) {
            for (const fb of b.fixtures) {
                if (!this.checkAABBOverlap(fa.aabb, fb.aabb)) continue;
                const m = this.collideFixFix(a, fa, b, fb);
                if (m) list.push(m);
            }
        }
        if (!list.length) return null;
        list.sort((x, y) => y.penetration - x.penetration);
        return list.slice(0, 2);
    }

    collideCircleCircle(a, b) {
        const delta = b.position.sub(a.position);
        const dist = delta.length();
        const radiusSum = a.radius + b.radius;
        if (dist >= radiusSum || dist === 0) return null;
        const normal = delta.scale(1 / dist);
        const penetration = radiusSum - dist;
        return {
            bodyA: a,
            bodyB: b,
            normal,
            penetration,
            contactPoint: a.position.add(normal.scale(a.radius - penetration * 0.5))
        };
    }

    collideCircleFixture(circle, bodyB, fix) {
        const vs = fix.wv;
        const inside = ptInPoly(circle.position, vs);
        if (!inside) {
            const q = closestPtOnPoly(circle.position, vs);
            const d = q.sub(circle.position);
            const dist = d.length();
            if (dist >= circle.radius) return null;
            const n = dist > 1e-6 ? d.scale(1 / dist) : circle.position.sub(fix.wc).normalize().scale(-1);
            return {
                bodyA: circle,
                bodyB,
                normal: n,
                penetration: circle.radius - dist,
                contactPoint: q
            };
        } else {
            let minPen = Infinity, bestN = new Vec2(0, -1), bestPt = circle.position.copy();
            for (let i = 0; i < vs.length; i++) {
                const p1 = vs[i], p2 = vs[(i + 1) % vs.length];
                let edgeN = p2.sub(p1).perp().normalize();
                if (edgeN.dot(p1.sub(fix.wc)) < 0) edgeN.scaleSelf(-1);
                const distToEdge = p1.sub(circle.position).dot(edgeN);
                if (distToEdge < minPen) {
                    minPen = distToEdge;
                    bestN = edgeN.scale(-1);
                    bestPt = circle.position.add(edgeN.scale(distToEdge));
                }
            }
            return {
                bodyA: circle,
                bodyB,
                normal: bestN,
                penetration: circle.radius + Math.max(0, minPen),
                contactPoint: bestPt
            };
        }
    }

    collideFixFix(bodyA, fixA, bodyB, fixB) {
        const wvA = fixA.wv, wvB = fixB.wv;
        let minPen = Infinity, bestNormal = null;

        const checkAxes = (vs1, wc1) => {
            for (let i = 0; i < vs1.length; i++) {
                const p1 = vs1[i], p2 = vs1[(i + 1) % vs1.length];
                let n = p2.sub(p1).perp().normalize();
                if (n.dot(p1.sub(wc1)) < 0) n.scaleSelf(-1);
                const projA = this.projectPolygon(wvA, n);
                const projB = this.projectPolygon(wvB, n);
                const overlap = Math.min(projA.max, projB.max) - Math.max(projA.min, projB.min);
                if (overlap <= 0) return false;
                if (overlap < minPen) {
                    minPen = overlap;
                    bestNormal = n;
                }
            }
            return true;
        };

        if (!checkAxes(wvA, fixA.wc) || !checkAxes(wvB, fixB.wc)) return null;
        if (bestNormal.dot(fixB.wc.sub(fixA.wc)) < 0) bestNormal.scaleSelf(-1);

        let maxA = -Infinity, minB = Infinity;
        for (const p of wvA) { const d = p.dot(bestNormal); if (d > maxA) maxA = d; }
        for (const p of wvB) { const d = p.dot(bestNormal); if (d < minB) minB = d; }

        const cand = [];
        const epsSq = (minPen + 2.5) * (minPen + 2.5);
        for (const p of wvA) {
            if (p.dot(bestNormal) >= maxA - 2.5 && (ptInPoly(p, wvB) || closestPtOnPoly(p, wvB).distSq(p) <= epsSq)) {
                cand.push(p);
            }
        }
        for (const p of wvB) {
            if (p.dot(bestNormal) <= minB + 2.5 && (ptInPoly(p, wvA) || closestPtOnPoly(p, wvA).distSq(p) <= epsSq)) {
                cand.push(p);
            }
        }

        let contactPoint;
        if (cand.length > 0) {
            let sx = 0, sy = 0;
            for (const p of cand) { sx += p.x; sy += p.y; }
            contactPoint = new Vec2(sx / cand.length, sy / cand.length);
        } else {
            contactPoint = fixA.wc.add(fixB.wc).scale(0.5);
        }

        return {
            bodyA,
            bodyB,
            normal: bestNormal,
            penetration: minPen,
            contactPoint
        };
    }

    projectPolygon(vertices, axis) {
        let min = vertices[0].dot(axis);
        let max = min;
        for (let i = 1; i < vertices.length; i++) {
            const proj = vertices[i].dot(axis);
            if (proj < min) min = proj;
            if (proj > max) max = proj;
        }
        return { min, max };
    }

    solveCollision(m) {
        const a = m.bodyA;
        const b = m.bodyB;
        const n = m.normal;
        const invMassSumLinear = a.invMass + b.invMass;
        if (invMassSumLinear < 1e-9) return;

        const slop = 0.015;
        const percent = 0.38;
        const correctionMagnitude = Math.max(m.penetration - slop, 0) / invMassSumLinear * percent;
        const correction = n.scale(correctionMagnitude);

        if (a.type === BodyType.DYNAMIC) a.position.subSelf(correction.scale(a.invMass));
        if (b.type === BodyType.DYNAMIC) b.position.addSelf(correction.scale(b.invMass));

        const rA = m.contactPoint.sub(a.position);
        const rB = m.contactPoint.sub(b.position);

        const vA = a.velocity.add(Vec2.crossScalarVec(a.angularVelocity, rA));
        const vB = b.velocity.add(Vec2.crossScalarVec(b.angularVelocity, rB));
        const rv = vB.sub(vA);

        const velAlongNormal = rv.dot(n);
        if (velAlongNormal > 0) return;

        const e = (-velAlongNormal < 35) ? 0 : Math.min(a.restitution, b.restitution);
        const rACrossN = rA.cross(n);
        const rBCrossN = rB.cross(n);

        const invMassSum = invMassSumLinear +
            (rACrossN * rACrossN) * a.invInertia +
            (rBCrossN * rBCrossN) * b.invInertia;
        if (invMassSum < 1e-9) return;

        const j = -(1 + e) * velAlongNormal / invMassSum;
        const impulse = n.scale(j);

        a.applyImpulse(impulse.scale(-1), m.contactPoint);
        b.applyImpulse(impulse, m.contactPoint);

        const vA2 = a.velocity.add(Vec2.crossScalarVec(a.angularVelocity, rA));
        const vB2 = b.velocity.add(Vec2.crossScalarVec(b.angularVelocity, rB));
        const rv2 = vB2.sub(vA2);

        const tangent = rv2.sub(n.scale(rv2.dot(n))).normalize();
        if (tangent.lengthSq() < 1e-6) return;

        const rAt = rA.cross(tangent), rBt = rB.cross(tangent);
        const denT = invMassSumLinear + rAt * rAt * a.invInertia + rBt * rBt * b.invInertia;
        if (denT < 1e-9) return;

        let jt = -rv2.dot(tangent) / denT;
        const mu = Math.sqrt(a.friction * b.friction);
        const maxJt = j * mu;
        if (Math.abs(jt) > maxJt) jt = Math.sign(jt) * maxJt * 0.85;

        const frictionImpulse = tangent.scale(jt);
        a.applyImpulse(frictionImpulse.scale(-1), m.contactPoint);
        b.applyImpulse(frictionImpulse, m.contactPoint);
    }
}
