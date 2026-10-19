/**
 * 2D Vector mathematics class for physics engine
 */
export class Vec2 {
    constructor(x = 0, y = 0) {
        this.x = x;
        this.y = y;
    }

    set(x, y) {
        this.x = x;
        this.y = y;
        return this;
    }

    copy() {
        return new Vec2(this.x, this.y);
    }

    add(v) {
        return new Vec2(this.x + v.x, this.y + v.y);
    }

    addSelf(v) {
        this.x += v.x;
        this.y += v.y;
        return this;
    }

    sub(v) {
        return new Vec2(this.x - v.x, this.y - v.y);
    }

    subSelf(v) {
        this.x -= v.x;
        this.y -= v.y;
        return this;
    }

    scale(s) {
        return new Vec2(this.x * s, this.y * s);
    }

    scaleSelf(s) {
        this.x *= s;
        this.y *= s;
        return this;
    }

    dot(v) {
        return this.x * v.x + this.y * v.y;
    }

    cross(v) {
        return this.x * v.y - this.y * v.x;
    }

    crossScalar(s) {
        return new Vec2(-s * this.y, s * this.x);
    }

    lengthSq() {
        return this.x * this.x + this.y * this.y;
    }

    length() {
        return Math.sqrt(this.lengthSq());
    }

    normalize() {
        const len = this.length();
        if (len > 0.00001) {
            return new Vec2(this.x / len, this.y / len);
        }
        return new Vec2(0, 0);
    }

    normalizeSelf() {
        const len = this.length();
        if (len > 0.00001) {
            this.x /= len;
            this.y /= len;
        } else {
            this.x = 0;
            this.y = 0;
        }
        return this;
    }

    perp() {
        return new Vec2(-this.y, this.x);
    }

    distSq(v) {
        const dx = this.x - v.x;
        const dy = this.y - v.y;
        return dx * dx + dy * dy;
    }

    dist(v) {
        return Math.sqrt(this.distSq(v));
    }

    rotate(angle) {
        const cos = Math.cos(angle);
        const sin = Math.sin(angle);
        return new Vec2(
            this.x * cos - this.y * sin,
            this.x * sin + this.y * cos
        );
    }

    static crossScalarVec(s, v) {
        return new Vec2(-s * v.y, s * v.x);
    }

    static crossVecVec(a, b) {
        return a.x * b.y - a.y * b.x;
    }
}
