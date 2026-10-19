import { Vec2 } from '../engine/Vector.js';

export const LEVEL_DATA = [
    {
        id: 1,
        title: "Level 1: First Steps",
        description: "Draw a shape above the ball or click to nudge it into the star!",
        ball: { x: 150, y: 440 },
        stars: [{ x: 680, y: 440, collected: false }],
        terrain: [
            // Left platform
            [ new Vec2(80, 470), new Vec2(320, 470), new Vec2(320, 550), new Vec2(80, 550) ],
            // Right platform
            [ new Vec2(550, 470), new Vec2(750, 470), new Vec2(750, 550), new Vec2(550, 550) ]
        ]
    },
    {
        id: 2,
        title: "Level 2: Mind The Gap",
        description: "Bridge the gap between platforms so the ball can roll across.",
        ball: { x: 120, y: 240 },
        stars: [{ x: 700, y: 440, collected: false }],
        terrain: [
            // High left hill
            [ new Vec2(50, 280), new Vec2(260, 320), new Vec2(260, 580), new Vec2(50, 580) ],
            // Lower right platform
            [ new Vec2(520, 470), new Vec2(760, 470), new Vec2(760, 580), new Vec2(520, 580) ]
        ]
    },
    {
        id: 3,
        title: "Level 3: The Seesaw",
        description: "A seesaw plank is pinned in the center. Drop a weight on the left side!",
        ball: { x: 200, y: 280 },
        stars: [{ x: 400, y: 150, collected: false }],
        terrain: [
            // Left starting ledge
            [ new Vec2(80, 320), new Vec2(260, 320), new Vec2(260, 550), new Vec2(80, 550) ],
            // Base post
            [ new Vec2(390, 380), new Vec2(410, 380), new Vec2(410, 550), new Vec2(390, 550) ]
        ],
        dynamicBodies: [
            // Seesaw plank
            {
                type: 'PLANK',
                vertices: [ new Vec2(-140, -10), new Vec2(140, -10), new Vec2(140, 10), new Vec2(-140, 10) ],
                position: { x: 400, y: 370 },
                color: '#e67e22',
                pinAt: { x: 400, y: 370 }
            }
        ]
    },
    {
        id: 4,
        title: "Level 4: High Flyer",
        description: "The star is high on a tower. Construct a catapult or heavy lever!",
        ball: { x: 200, y: 460 },
        stars: [{ x: 650, y: 180, collected: false }],
        terrain: [
            // Ground
            [ new Vec2(50, 490), new Vec2(750, 490), new Vec2(750, 560), new Vec2(50, 560) ],
            // Tower under star
            [ new Vec2(620, 220), new Vec2(680, 220), new Vec2(680, 490), new Vec2(620, 490) ]
        ]
    },
    {
        id: 5,
        title: "Level 5: Double Star",
        description: "Collect both stars! Guide the ball down the stepped ledges.",
        ball: { x: 100, y: 120 },
        stars: [
            { x: 400, y: 310, collected: false },
            { x: 700, y: 460, collected: false }
        ],
        terrain: [
            // Top step
            [ new Vec2(50, 160), new Vec2(220, 160), new Vec2(220, 200), new Vec2(50, 200) ],
            // Middle step
            [ new Vec2(320, 350), new Vec2(480, 350), new Vec2(480, 390), new Vec2(320, 390) ],
            // Bottom step
            [ new Vec2(580, 500), new Vec2(760, 500), new Vec2(760, 540), new Vec2(580, 540) ]
        ]
    },
    {
        id: 6,
        title: "Level 6: Wheel & Axle",
        description: "Use the PIN tool to create a revolving arm to push the ball upward.",
        ball: { x: 150, y: 440 },
        stars: [{ x: 680, y: 220, collected: false }],
        terrain: [
            // Left ramp
            [ new Vec2(80, 470), new Vec2(350, 420), new Vec2(350, 550), new Vec2(80, 550) ],
            // Right high platform
            [ new Vec2(550, 260), new Vec2(750, 260), new Vec2(750, 550), new Vec2(550, 550) ]
        ]
    },
    {
        id: 7,
        title: "Level 7: Rope Swing",
        description: "Use the ROPE tool to connect dynamic shapes and swing across the gap.",
        ball: { x: 120, y: 400 },
        stars: [{ x: 680, y: 220, collected: false }],
        terrain: [
            // Left floor
            [ new Vec2(50, 440), new Vec2(240, 440), new Vec2(240, 580), new Vec2(50, 580) ],
            // Right high floor
            [ new Vec2(580, 260), new Vec2(760, 260), new Vec2(760, 580), new Vec2(580, 580) ],
            // Ceiling beam
            [ new Vec2(200, 80), new Vec2(600, 80), new Vec2(600, 100), new Vec2(200, 100) ]
        ]
    },
    {
        id: 8,
        title: "Level 8: The Tower Climb",
        description: "Build ramps and wedges to climb the zig-zag tower levels.",
        ball: { x: 100, y: 490 },
        stars: [{ x: 120, y: 110, collected: false }],
        terrain: [
            // Bottom floor
            [ new Vec2(50, 530), new Vec2(750, 530), new Vec2(750, 570), new Vec2(50, 570) ],
            // Tier 1
            [ new Vec2(220, 390), new Vec2(750, 390), new Vec2(750, 410), new Vec2(220, 410) ],
            // Tier 2
            [ new Vec2(50, 250), new Vec2(600, 250), new Vec2(600, 270), new Vec2(50, 270) ],
            // Top Tier
            [ new Vec2(50, 140), new Vec2(220, 140), new Vec2(220, 160), new Vec2(50, 160) ]
        ]
    },
    {
        id: 9,
        title: "Level 9: The Pendulum",
        description: "Swing a heavy weight to smash open the blocking gate!",
        ball: { x: 150, y: 440 },
        stars: [{ x: 700, y: 440, collected: false }],
        terrain: [
            // Ground
            [ new Vec2(50, 470), new Vec2(750, 470), new Vec2(750, 550), new Vec2(50, 550) ],
            // Top anchor beam
            [ new Vec2(380, 80), new Vec2(420, 80), new Vec2(420, 120), new Vec2(380, 120) ]
        ],
        dynamicBodies: [
            // Blocking barrier board
            {
                type: 'BARRIER',
                vertices: [ new Vec2(-10, -110), new Vec2(10, -110), new Vec2(10, 110), new Vec2(-10, 110) ],
                position: { x: 500, y: 350 },
                color: '#8e44ad'
            }
        ]
    },
    {
        id: 10,
        title: "Level 10: Grand Masterpiece",
        description: "The ultimate physics challenge! Combine drawing, pins, and ropes to reach the star.",
        ball: { x: 100, y: 140 },
        stars: [{ x: 700, y: 140, collected: false }],
        terrain: [
            // Left start ledge
            [ new Vec2(50, 180), new Vec2(200, 180), new Vec2(200, 220), new Vec2(50, 220) ],
            // Deep middle pit pillar 1
            [ new Vec2(300, 300), new Vec2(330, 300), new Vec2(330, 580), new Vec2(300, 580) ],
            // Deep middle pit pillar 2
            [ new Vec2(470, 300), new Vec2(500, 300), new Vec2(500, 580), new Vec2(470, 580) ],
            // Right goal ledge
            [ new Vec2(620, 180), new Vec2(780, 180), new Vec2(780, 220), new Vec2(620, 220) ]
        ]
    }
];
