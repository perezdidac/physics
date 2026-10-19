import { Vec2 } from './Vector.js';
import { ensureCCW, signedPolygonArea, triangulatePolygon } from './Physics.js';

export class StrokeProcessor {
    static simplify(points, epsilon = 4.0) {
        if (points.length <= 2) return points;

        let maxDist = 0;
        let index = 0;
        const end = points.length - 1;

        for (let i = 1; i < end; i++) {
            const dist = StrokeProcessor.perpendicularDistance(points[i], points[0], points[end]);
            if (dist > maxDist) {
                maxDist = dist;
                index = i;
            }
        }

        if (maxDist > epsilon) {
            const rec1 = StrokeProcessor.simplify(points.slice(0, index + 1), epsilon);
            const rec2 = StrokeProcessor.simplify(points.slice(index), epsilon);
            return rec1.slice(0, rec1.length - 1).concat(rec2);
        } else {
            return [points[0], points[end]];
        }
    }

    static perpendicularDistance(pt, lineStart, lineEnd) {
        const dx = lineEnd.x - lineStart.x;
        const dy = lineEnd.y - lineStart.y;
        const mag = Math.sqrt(dx * dx + dy * dy);
        if (mag === 0) return pt.dist(lineStart);
        const u = ((pt.x - lineStart.x) * dx + (pt.y - lineStart.y) * dy) / (mag * mag);
        const clampedU = Math.max(0, Math.min(1, u));
        const proj = new Vec2(lineStart.x + clampedU * dx, lineStart.y + clampedU * dy);
        return pt.dist(proj);
    }

    static buildRibbonFixtures(pts, halfThick = 6.5) {
        const quads = [];
        for (let i = 0; i < pts.length - 1; i++) {
            const a = pts[i], b = pts[i + 1];
            const d = b.sub(a);
            const len = d.length();
            if (len < 2) continue;
            const dir = d.scale(1 / len);
            const n = dir.perp().scale(halfThick);
            const ext = dir.scale(Math.min(halfThick * 0.45, 3));
            const a0 = a.sub(ext), b0 = b.add(ext);
            quads.push(ensureCCW([
                a0.sub(n),
                b0.sub(n),
                b0.add(n),
                a0.add(n)
            ]));
        }
        return quads;
    }

    static classifyStroke(points) {
        if (!points || points.length < 2) return null;
        let pathLen = 0;
        for (let i = 1; i < points.length; i++) pathLen += points[i].dist(points[i - 1]);
        if (pathLen < 18) return null;

        const simplified = StrokeProcessor.simplify(points, 4.0);
        const filt = [];
        for (const p of simplified) {
            if (!filt.length || filt[filt.length - 1].dist(p) > 5) filt.push(p.copy());
        }
        if (filt.length < 2) return null;

        const startEndDist = points[0].dist(points[points.length - 1]);
        const isClosedLoop = filt.length >= 3 && (startEndDist < Math.max(38, pathLen * 0.22));

        if (isClosedLoop) {
            if (filt.length > 3 && filt[0].dist(filt[filt.length - 1]) < 14) filt.pop();
            const area = Math.abs(signedPolygonArea(filt));
            if (area >= 120) {
                const tris = triangulatePolygon(filt);
                if (tris.length > 0) {
                    return {
                        isRibbon: false,
                        fixtures: tris,
                        vertices: ensureCCW(filt),
                        spinePts: null
                    };
                }
            }
        }

        const quads = StrokeProcessor.buildRibbonFixtures(filt, 6.5);
        if (!quads.length) return null;
        return {
            isRibbon: true,
            fixtures: quads,
            vertices: quads[0],
            spinePts: filt
        };
    }

    static processDrawnStroke(points) {
        const res = StrokeProcessor.classifyStroke(points);
        return res ? res.vertices : null;
    }
}

export class CrayonRenderer {
    static CRAYON_COLORS = [
        '#c84b31', // Terracotta Vermilion
        '#3a647d', // Prussian Slate
        '#527853', // Sage Olive
        '#d49137', // Ochre Gold
        '#764966', // Plum Wine
        '#b86538', // Burnt Sienna
        '#3b7a75'  // Teal Patina
    ];

    static getRandomColor() {
        return CrayonRenderer.CRAYON_COLORS[Math.floor(Math.random() * CrayonRenderer.CRAYON_COLORS.length)];
    }

    static drawCrayonPoly(ctx, vertices, color, isClosed = true, fillAlpha = 0.28) {
        if (!vertices || vertices.length === 0) return;

        ctx.save();
        ctx.fillStyle = color;
        ctx.strokeStyle = color;
        ctx.lineCap = 'round';
        ctx.lineJoin = 'round';

        if (isClosed && vertices.length >= 3) {
            ctx.globalAlpha = fillAlpha;
            ctx.beginPath();
            ctx.moveTo(vertices[0].x, vertices[0].y);
            for (let i = 1; i < vertices.length; i++) ctx.lineTo(vertices[i].x, vertices[i].y);
            ctx.closePath();
            ctx.fill();
        }

        ctx.globalAlpha = 0.85;
        ctx.lineWidth = isClosed ? 3.2 : 8.5;
        ctx.beginPath();
        ctx.moveTo(vertices[0].x, vertices[0].y);
        for (let i = 1; i < vertices.length; i++) ctx.lineTo(vertices[i].x, vertices[i].y);
        if (isClosed) ctx.closePath();
        ctx.stroke();

        ctx.restore();
    }

    static drawPaperBackground(ctx, width, height) {
        ctx.save();
        ctx.fillStyle = '#f4efe4';
        ctx.fillRect(0, 0, width, height);

        ctx.strokeStyle = 'rgba(115, 145, 168, 0.14)';
        ctx.lineWidth = 1;
        for (let y = 30; y < height; y += 30) {
            ctx.beginPath();
            ctx.moveTo(0, y);
            ctx.lineTo(width, y);
            ctx.stroke();
        }

        ctx.strokeStyle = 'rgba(198, 95, 85, 0.28)';
        ctx.lineWidth = 1.4;
        ctx.beginPath();
        ctx.moveTo(62, 0);
        ctx.lineTo(62, height);
        ctx.stroke();
        ctx.restore();
    }

    static drawCrayonStar(ctx, x, y, radius, time) {
        ctx.save();
        ctx.translate(x, y);
        ctx.rotate(Math.sin(time * 1.8) * 0.14);

        ctx.fillStyle = '#e5a93c';
        ctx.strokeStyle = '#6e4511';
        ctx.lineWidth = 2;

        ctx.beginPath();
        for (let i = 0; i < 10; i++) {
            const r = (i % 2 === 0) ? radius : radius * 0.44;
            const angle = (i * Math.PI) / 5 - Math.PI / 2;
            const sx = Math.cos(angle) * r;
            const sy = Math.sin(angle) * r;
            if (i === 0) ctx.moveTo(sx, sy);
            else ctx.lineTo(sx, sy);
        }
        ctx.closePath();
        ctx.fill();
        ctx.stroke();
        ctx.restore();
    }

    static drawCrayonBall(ctx, x, y, radius, angle, color = '#c84b31') {
        ctx.save();
        ctx.translate(x, y);
        ctx.rotate(angle);

        ctx.fillStyle = color;
        ctx.beginPath();
        ctx.arc(0, 0, radius, 0, Math.PI * 2);
        ctx.fill();

        ctx.strokeStyle = '#4a1d12';
        ctx.lineWidth = 2.2;
        ctx.beginPath();
        ctx.arc(0, 0, radius, 0, Math.PI * 2);
        ctx.stroke();

        ctx.strokeStyle = 'rgba(250, 242, 225, 0.55)';
        ctx.lineWidth = 2.4;
        ctx.beginPath();
        ctx.arc(0, 0, radius * 0.56, -0.4, Math.PI * 0.95);
        ctx.stroke();

        ctx.restore();
    }

    static drawPin(ctx, x, y) {
        ctx.save();
        ctx.translate(x, y);
        ctx.fillStyle = '#c59b47';
        ctx.strokeStyle = '#4d3610';
        ctx.lineWidth = 1.6;
        ctx.beginPath();
        ctx.arc(0, 0, 6.5, 0, Math.PI * 2);
        ctx.fill();
        ctx.stroke();
        ctx.restore();
    }

    static drawRope(ctx, p1, p2) {
        ctx.save();
        ctx.strokeStyle = '#7d5c3b';
        ctx.lineWidth = 3.8;
        ctx.lineCap = 'round';
        ctx.beginPath();
        ctx.moveTo(p1.x, p1.y);
        ctx.lineTo(p2.x, p2.y);
        ctx.stroke();
        ctx.restore();
    }
}
