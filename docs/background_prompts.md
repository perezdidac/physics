# Background prompts (Gemini)

New story-mode backgrounds, made with Gemini by the authors. Each one shows a **recognisable Catalan place**, in the style of the 8 existing backgrounds in `assets/backgrounds/` (e.g. `bg_montserrat.jpg`, `bg_cadaques.jpg`).

## How to use
1. In Gemini, paste the **style block** and then **one scene block**, in the same message. Every scene ends with a style reminder line, so keep it.
2. **Reference image (recommended):** also attach `bg_montserrat.jpg` or `bg_cadaques.jpg` and say "use exactly the art style of this image". This is the surest way to get the same look.
3. **Aspect ratio:** ask for **21:9** if you can, otherwise 16:9, at the highest resolution Gemini offers.
4. **If it still looks like a photo,** reply: "make it a hand-painted gouache illustration like a vintage travel poster, flatter colours, visible brush strokes, not a photograph".
5. **If it adds people, text or animals,** reply: "remove all people, animals, text and logos".
6. **Save it** as `bg_<key>.png` (or .jpg) and drop it in `assets/backgrounds/new/`. I crop, resize and register it.
7. **Variants:** generate 2–3 per scene and keep the one where the landmark is clearest.

## Style block (paste before every scene)
```
ART STYLE (most important): a hand-painted 2D illustration, NOT a photograph and NOT photorealistic, not a 3D render.
Gouache and acrylic illustration in the style of a vintage travel poster and of Studio Ghibli background paintings:
simplified, stylised shapes; clean edges; flat areas of colour with soft painted gradients; visible brush strokes;
slightly stylised rocks, trees and buildings; foliage painted as clusters of leaf shapes, not individual photo leaves;
clear, saturated but harmonious colours; soft painted clouds; gentle atmospheric haze between layers.
Like a beautifully illustrated storybook or a hand-painted video game background.

USE: a wide panoramic background for a 2D side-scrolling video game.
Composition: the landmark clearly visible in the upper-middle of the image, horizon at about 55% of the height,
clear depth layers (painted foreground, middle ground, far background),
the bottom third simpler and slightly darker (game terrain will be drawn over it), no strong objects at the very bottom.
No people, no animals, no insects, no text, no logos, no frame, no watermark.
```

## Scenes

### Ou (egg stage), summer, tiny scale
The egg is tiny, so these are **big pine branches in the foreground** with the landmark far away.

**1. `pinar_montseny`**: levels 1–2 of the egg stage
```
Scene: a big sunny pine branch (Pinus pinaster) in the foreground, painted with stylised clusters of long green needles
and two small pine cones, slightly simplified and softer than the rest. Far in the background, the Montseny massif with
the rounded summits of Turó de l'Home and Les Agudes, beech and pine forests on the slopes, early summer morning,
light painted mist in the valleys.
Hand-painted gouache illustration, vintage travel poster style, not a photograph.
```

**2. `pinar_montserrat_tempesta`**: egg level 4 (summer storm)
```
Scene: pine needles and a twig in the foreground with a few painted raindrops. In the background, the jagged rock
towers of the Montserrat mountain, unmistakable rounded conglomerate pinnacles, dramatic stylised summer storm clouds,
a beam of sunlight breaking through, a distant painted lightning bolt, dark blue and gold palette.
Hand-painted gouache illustration, vintage travel poster style, not a photograph.
```

**3. `pinar_montserrat_capvespre`**: egg boss (the parasitoid wasp)
```
Scene: a pine branch tip glowing in backlight in the foreground, painted simply. Behind it, the Montserrat mountain with
its pinnacles and the Santa Maria de Montserrat monastery on the cliff side, warm orange and pink summer sunset sky,
long shadows, magical golden-hour atmosphere.
Hand-painted gouache illustration, vintage travel poster style, not a photograph.
```

### Pelussa (L1–L2), end of summer, pine tree tops

**4. `collserola_barcelona`**
```
Scene: view from the top of a pine forest in the Collserola hills, stylised umbrella-pine canopies in the foreground.
Below, the city of Barcelona painted as simplified blocks spreading to the Mediterranean sea, the Sagrada Família towers
and the Torre Glòries recognisable in the distance, the Tibidabo hill with its church on one side,
late summer afternoon light, soft sea haze.
Hand-painted gouache illustration, vintage travel poster style, not a photograph.
```

**5. `costa_brava_pins`**
```
Scene: Mediterranean coast of the Costa Brava: Aleppo pines leaning over turquoise coves and rocky cliffs, the white
village of Calella de Palafrugell with its arches by the beach in the middle distance, small painted fishing boats,
calm sea, end of summer, bright warm light.
Hand-painted gouache illustration, vintage travel poster style, not a photograph.
```

### Cuca (L3–L5), autumn
It also reuses the existing `castellfollit` and `montblanc` backgrounds.

**6. `siurana_tardor`**
```
Scene: the medieval village of Siurana perched on top of a sheer limestone cliff, in the Prades mountains, the Siurana
reservoir with blue-green water below, autumn colours (orange, ochre, red) on the hillsides and pine forests,
soft autumn light, light painted mist.
Hand-painted gouache illustration, vintage travel poster style, not a photograph.
```

**7. `poblet_tardor`**
```
Scene: the Royal Monastery of Poblet with its stone walls and Gothic towers, surrounded by autumn vineyards in rows and
the Prades mountains forest behind, golden and copper autumn colours, late afternoon light, a few painted clouds.
Hand-painted gouache illustration, vintage travel poster style, not a photograph.
```

### El Bolsó (winter nest)

**8. `cerdanya_neu`**
```
Scene: snowy winter landscape of the Cerdanya valley in the Pyrenees, black pine forests covered in snow in the
foreground, the Puigmal and Cadí mountain range white with snow behind, a small Romanesque church with a stone bell
tower in a village, cold clear blue sky, crisp winter morning light.
Hand-painted gouache illustration, vintage travel poster style, not a photograph.
```

**9. `cardona_glacada`**: winter boss (the forestry brigade)
```
Scene: the castle of Cardona on its hill above the town, frosty winter morning, frozen white pine forest around it,
the salt mountain (Muntanya de Sal) visible below, pale pink winter sunrise, cold painted mist, silent atmosphere.
Hand-painted gouache illustration, vintage travel poster style, not a photograph.
```

### La Processó (spring)

**10. `garrotxa_volcans`**
```
Scene: spring in the Garrotxa volcanic zone: the rounded green volcanic cones of Croscat and Santa Margarida covered in
forest, the small Romanesque hermitage inside the crater, bright green meadows with stylised wild flowers, beech and oak
trees, fresh spring light after rain.
Hand-painted gouache illustration, vintage travel poster style, not a photograph.
```

**11. `emporda_sant_pere`**: spring boss (the cuckoo)
```
Scene: the Empordà plain in spring, green wheat fields and red poppies, rows of cypress trees, the monastery of
Sant Pere de Rodes on the mountain above the Bay of Llançà in the distance, the Mediterranean sea shining,
warm spring morning.
Hand-painted gouache illustration, vintage travel poster style, not a photograph.
```

### La Crisàlide (pupa, underground)

**12. `sota_terra_pedraforca`**
```
Scene: side cross-section of the ground under a pine tree, like a cutaway illustration in a children's nature book:
the upper 25% shows the grassy surface, the pine trunk and, far away, the Pedraforca mountain with its double peak;
the lower 75% shows painted layers of soil, pine roots, small stones and earth galleries, warm brown and ochre tones,
soft light from above.
Hand-painted gouache illustration, vintage travel poster style, not a photograph.
```

### La Papallona (moth, summer night)

**13. `montserrat_nit`**
```
Scene: Montserrat mountain at night under a full moon and a sky full of painted stars and the Milky Way, the pinnacles
lit in silver-blue moonlight, the lights of the monastery glowing warmly on the cliff, pine forest silhouettes in the
foreground, deep blue and violet palette, magical summer night.
Hand-painted gouache illustration, vintage travel poster style, not a photograph.
```

**14. `tossa_nit`**: final boss (the bat)
```
Scene: the medieval walled town of Tossa de Mar (Vila Vella) with its towers and lighthouse on the rocky headland,
at night, a big moon over the Mediterranean sea, painted moonlight reflections on the water, warm lights in the old
town, pine trees on the cliffs, summer night atmosphere.
Hand-painted gouache illustration, vintage travel poster style, not a photograph.
```

## Summary
| # | Key | Place | Stage / use |
|---|---|---|---|
| 1 | pinar_montseny | Montseny | Ou 1–2 |
| 2 | pinar_montserrat_tempesta | Montserrat (storm) | Ou 3–4 |
| 3 | pinar_montserrat_capvespre | Montserrat (sunset) | Ou boss |
| 4 | collserola_barcelona | Collserola, Barcelona | Pelussa |
| 5 | costa_brava_pins | Calella de Palafrugell | Pelussa, boss |
| 6 | siurana_tardor | Siurana | Cuca |
| 7 | poblet_tardor | Poblet | Cuca, boss |
| 8 | cerdanya_neu | Cerdanya, Puigmal | El Bolsó |
| 9 | cardona_glacada | Cardona | El Bolsó boss |
| 10 | garrotxa_volcans | Garrotxa | La Processó |
| 11 | emporda_sant_pere | Sant Pere de Rodes | La Processó boss |
| 12 | sota_terra_pedraforca | Pedraforca (underground) | La Crisàlide |
| 13 | montserrat_nit | Montserrat (night) | La Papallona |
| 14 | tossa_nit | Tossa de Mar | Final boss |
