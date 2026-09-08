# Charm-Modelle — Prompts für Text-zu-3D

Konvention: Modell-Dateiname = Charm-id (`assets/models/<id>.glb`). Eine Datei mit dem
richtigen Namen wird automatisch verdrahtet (`Charm._make` prüft `ResourceLoader.exists`);
fehlt sie, zeigt der Tisch den Platzhalter. Mit ✔ markierte Einträge haben schon ein Modell —
mit neuen Prompts neu generieren überschreibt einfach dieselbe Datei.

Tripo-Vorlagen für alle Charms OHNE Modell liegen seit dem 2026-09-08 fertig gewählt in
`E:/Generated Images/Fumble/charm_batch_2026-09-08/winners/<id>.png` (Kandidaten und
`picks.json` daneben); das `.glb` ist der nächste Schritt. Meshy-Exporte (Smart Topology) kommen mit 4096er-Karten in
fast unkomprimiertem JPEG (15-30 MB) und um den Ursprung zentriert - vor dem Kopieren durch
`tools/shrink_glb.py <quelle> assets/models/<id>.glb --ground` (1024er-Karten, Fuß auf Y = 0 wie
bei Tripo; der Tisch stellt Modelle ungefittet mit ihrem Ursprung auf den Filz).

**Stil-Präfix** (vor jeden Prompt setzen):

> A small collectible charm trinket in Borderlands 2 art style: hand-painted cel-shaded
> comic look, thick dark outlines, painterly hatched shading, bold saturated colors,
> chunky slightly exaggerated proportions — the object itself pristine and factory-new:
> polished spotless surfaces, crisp edges, one glowing neon accent, no dirt, rust,
> damage or clutter. Single object, strong readable silhouette, game-ready 3D asset.

Die Charms stehen klein auf dunklem Filz und werden schräg von oben gesehen — eine fette
Silhouette und EIN Leuchtakzent zählen mehr als Detail. Kein Text im Modell (Schrift
kommt aus den Generatoren meist kaputt heraus).

## Glücksbringer-Klassiker (Augen & Werte)

- ✔ `rabbits_foot.glb` **Hasenpfote** — A plush lucky rabbit's foot on a polished brass keychain cap, soft silver-grey fur, subtle cyan neon sheen.
- ✔ `lucky_cigarettes.glb` **Glückszigaretten** — A crisp open cigarette pack with three cigarettes, one flipped upside down as the lucky one, bold cream-and-gold packaging with a shiny holo-sticker.
- ✔ `four_leaf_clover.glb` **Vierblättriges Kleeblatt** — A four-leaf clover sealed in a flawless clear resin dome on a polished brass base, the leaf glowing fresh green.
- ✔ `fox_tail.glb` **Fuchsschwanz** — A big bushy fox tail on a gleaming golden clasp ring, vivid orange fur with a snow-white tip.
- ✔ `pencil_stub.glb` **Croupier-Bleistift** — A short stubby casino pencil in glossy dark-green lacquer with a bright gold band, freshly sharpened.
- `top_hat.glb` **Zylinderhut** — A pristine black silk top hat with a satin band and a crisp neon-cyan trim line around the brim.
- ✔ `silver_dollar.glb` **Silberdollar** — An oversized mirror-polished silver dollar standing upright in a chrome display clip, its rim glowing softly.
- ✔ `eight_knot.glb` **Achterknoten** — A thick pearly-white rope tied into a perfect figure-eight knot, mounted like a trophy on a lacquered plinth, rope ends capped in polished brass.
- ✔ `horseshoe.glb` **Hufeisen** — A gleaming steel horseshoe with seven neat nail holes, one arm wrapped in glowing amber wire.
- ✔ `ladybug.glb` **Marienkäfer** — A chunky enamel ladybug with a glossy candy-red shell and crisp black dots, polished chrome legs, antenna tips glowing.
- ✔ `pearl_necklace.glb` **Perlenkette** — A pearl necklace coiled in a neat spiral on a velvet pad, luminous iridescent pearls with a polished gold clasp.
- ✔ `magic_card.glb` **Zauberkarte** — A crisp playing card standing in a polished brass holder, its back a bold glowing sigil design.
- ✔ `rainbow_trout.glb` **Regenbogenforelle** — A leaping trophy trout with smooth painted panels, scales in loud clean neon gradients, on a lacquered base.
- ✔ `old_penny.glb` **Glücksgroschen** — An antique copper coin polished to a warm shine, its face a plain embossed four-leaf clover with a smooth blank rim, resting on a plump red velvet cushion.
- ✔ `piggy_bank.glb` **Sparschwein** — A chubby ceramic piggy bank in glossy pastel pink with a gold coin half inserted in its slot, cheeks blushing.
- ✔ `crystal_ball.glb` **Kristallkugel** — A flawless crystal ball on a polished brass claw stand, a graceful violet mist swirling inside.
- ✔ `chimney_sweep.glb` **Schornsteinfeger** — A tidy chimney sweep figurine in a crisp black suit and top hat, carrying a golden ladder and brush, cheeks rosy.
- ✔ `con_artist_cuff.glb` **Trickdieb-Manschette** — A snow-white shirt cuff with a gleaming golden cufflink, a crisp playing card sliding out on a tiny polished rail.
- ✔ `collectors_amulet.glb` **Sammler-Amulett** — A polished gold amulet with an empty gem socket ringed by six sparkling gems, on a gleaming chain.

## Wurf & Neuwurf

- ✔ `pendulum.glb` **Pendel** — A dowsing pendulum: a faceted crystal bob on a fine chain hanging from a polished brass arch stand, its tip glowing cyan.
- ✔ `all_or_nothing.glb` **Roter Knopf** — A big glossy red launch button under a crystal-clear flip-up safety cover, mounted on brushed steel with crisp yellow-black warning stripes.
- ✔ `anchor.glb` **Anker** — A neat ship anchor in glossy black enamel with a coiled golden rope, leaning against its polished wooden stand.

## Augen & Werte (Katalog)

- ✔ `echo_chamber.glb` **Echo-Kammer** — A gleaming retro-futuristic tape echo unit: chrome box, two spinning tape reels, a bright green VU meter, one tidy coiled patch cable.
- ✔ `twin_ring.glb` **Zwillingsring** — Two identical interlocked polished gold rings standing upright on a plump velvet cushion, a warm glow at their joint.
- ✔ `cult_of_one.glb` **Einserkult** — A tiny immaculate shrine: a polished obsidian monolith bearing one glowing white die pip, flanked by two neat golden candles.
- ✔ `street_sweeper.glb` **Straßenbesen** — A brand-new push broom leaning at an angle, varnished wooden handle, dense sharp bristles with neon glitter sparkling at the tips.
- ✔ `equalizer.glb` **Equalizer** — A sleek audio equalizer unit with a spotless faceplate, a row of glowing sliders aligned at exactly the same height, chrome knobs.
- ✔ `equal_grind.glb` **Gleichschliff** — A jeweler's grinding wheel mid-work, six identical polished die faces fanned out beside it, all showing the same pip count, fine metal dust catching the light.
- ✔ `small_fry.glb` **Kleinvieh** — A polished brass hen with two little brass chicks, standing on a shiny oversized coin, folk-art style.
- ✔ `beherit.glb` **Beherit** — A smooth egg-shaped idol with scrambled human facial features embossed across its flawless dark-red shell, thin crimson glow lines tracing the seams.
- ✔ `high_stacker.glb` **Hochstapler** — A wildly leaning tower of glossy casino chips in crisp alternating colors, spotless and gleaming, tilted but never falling.
- ✔ `prime_time.glb` **Prime Time** — A polished broadcast warning lamp: a glowing red glass box on a chrome pole stand, a neat little antenna on top.
- ✔ `front_runner.glb` **Vorreiter** — A gleaming golden jockey-on-horseback trophy mid-gallop on a polished oval base, enamel racing silks in bold colors.
- ✔ `quadrature.glb` **Quadratur** — A polished brass drafting compass standing on a spotless glass tile, scribing a glowing circle inside a crisply etched square.
- ✔ `six_pack.glb` **Sechserpack** — A neat cardboard six-pack carrier holding six glowing bottles, each cap a different bright color, the cardboard crisp and new.
- ✔ `protection_money.glb` **Schutzgeld** — A fat stack of crisp banknotes banded in black, inside an elegant black envelope sealed with a glossy black handprint seal.
- ✔ `waterfall.glb` **Wasserfall** — A sleek desktop fountain of three polished stone tiers, glowing cyan water cascading into a clear pool.

## Kombinationen & Wertung

- ✔ `house_joker.glb` **Hausjoker** — A pristine jester cap in rich purple-and-gold silk with tiny polished golden bells, resting on a lacquered stand.
- ✔ `free_drink.glb` **Freigetränk** — A sparkling cocktail glass with a bright paper umbrella and glowing green liquid, on a clean round coaster.
- ✔ `spotlight.glb` **Rampenlicht** — A miniature golden stage followspot on a polished tripod, its lens throwing a crisp cone of warm light.
- ✔ `full_counter.glb` **Vollzähler** — A gleaming chrome tally counter with a big thumb button, rolling digits glowing amber behind spotless glass.
- ✔ `momentum.glb` **Schwungrad** — A polished brass flywheel in a clean steel frame with a lacquered hand crank, spokes trailing a faint motion glow.
- ✔ `after_work_beer.glb` **Feierabendbier** — A frosty beer bottle with the cap popping off mid-air, sparkling condensation drops, a crisp label with a neon sunset.
- ✔ `broadband.glb` **Mehrfachstecker** — A gleaming chrome power strip with six sockets, each ring glowing cyan, one glossy plug inserted, cable neatly coiled.
- ✔ `even_company.glb` **Wasserwaage** — A brand-new aluminum spirit level with crisp machined edges, its glowing green bubble vial perfectly centered.
- ✔ `odd_path.glb` **Schiefer Turm** — A leaning tower miniature in gleaming white marble on a tilted polished base, a crisp neon line tracing the lean.
- ✔ `snake_eyes.glb` **Snake Eyes** — A coiled cobra with glossy black scales and polished chrome hood panels, guarding two spotless white dice showing single pips, its eyes glowing red.
- ✔ `double_bottom.glb` **Dreifacher Boden** — An elegant polished briefcase with a lifted false-bottom panel revealing neatly stacked gold bars.

## Farkle

- ✔ `broken_mirror.glb` **Zerbrochener Spiegel** — An ornate polished hand mirror, its glass bearing one clean spiderweb crack with the lines glowing violet — the frame itself flawless.
- ✔ `grandfather_clock.glb` **Standuhr** — A miniature grandfather clock in glossy dark wood with gleaming brass fittings, its golden pendulum frozen mid-swing, the face glowing warm.
- ✔ `shard_court.glb` **Scherbengericht** — A fine ceramic plate broken into clean shards and rejoined kintsugi-style with glowing gold seams, a few shards arranged neatly beside it.
- ✔ `gallows_humor.glb` **Galgenhumor** — A polished ivory skull wearing a neat jester cap with golden bells, grinning with one gold tooth, lit warmly from below.
- ✔ `phoenix_feather.glb` **Phönixfeder** — A magnificent phoenix feather standing in a polished inkwell, barbs fading ember-orange to gold, tiny clean embers drifting upward.
- ✔ `patchwork_rug.glb` **Flickenteppich** — A neatly rolled patchwork rug of vividly colored glowing fabric squares joined by tidy golden stitching.

## Geld

- ✔ `gold_rush.glb` **Goldrausch** — A polished prospector's pan with clear water and three glowing gold nuggets, a gleaming pickaxe leaning against it.
- ✔ `rag_collector.glb` **Lumpensammler** — A tidy canvas sack spilling neatly folded colorful cloth squares and one shiny coin, tied with a crisp rope bow.
- ✔ `interest_penny.glb` **Zinsgroschen** — A neat staircase of stacked polished coins rising step by step, the top coin glowing gold.
- `street_musician.glb` **Straßenmusiker** — An open violin case lined with spotless red velvet, bright coins arranged inside, a crisp glowing music note hovering above.
- ✔ `emergency_fund.glb` **Notgroschen** — A glossy red wall box with a crystal-clear break-glass front, one smooth blank golden coin inside, a polished little hammer on a neat chain.
- ✔ `cash_discount.glb` **Rabattmarke** — A crisp booklet of vintage rebate stamps, the top stamp glowing neon green with a sharp embossed percent sign.
- ✔ `high_flyer.glb` **Überflieger** — A paper plane crisply folded from a mint banknote, climbing off a slim chrome stand with a clean neon contrail.

## Materialien

- ✔ `midas_glove.glb` **Midashandschuh** — An elegant white glove standing upright, its fingertips transitioning into flawless polished gold.
- ✔ `gold_vein.glb` **Goldader** — A split geode-like rock with clean-cut faces, veins of glowing molten gold running through the crystal-lined fracture.
- ✔ `goldsmith.glb` **Goldschmied** — A spotless miniature jeweler's anvil with a gleaming gold ingot and a polished chasing hammer, tidy gold flakes on the base.
- ✔ `amber_room.glb` **Bernsteinzimmer** — A jewel-box diorama of a baroque room corner with glowing honey-amber wall panels and a sparkling tiny chandelier.
- ✔ `blood_diamond.glb` **Blutdiamant** — A huge flawless blood-red diamond on a plump black velvet pad, its facets glowing like embers.
- ✔ `bone_glue.glb` **Knochenleim** — A neat copper glue pot of smooth ivory glue with a clean wooden brush resting across the rim, one elegant glossy drip down the side.
- ✔ `bone_marrow.glb` **Knochenmark** — A smooth bone split cleanly lengthwise, revealing warm glowing marrow, presented on a polished dark stone slab.
- ✔ `glassblower_lung.glb` **Glasbläserpfeife** — A gleaming glassblower's blowpipe with a perfect molten glass bubble at its tip, glowing orange fading to cool teal.
- ✔ `mercury_vapor.glb` **Quecksilberlampe** — A pristine mercury arc lamp: a gracefully curved glass tube glowing blue-green above a mirror-liquid reservoir in a polished brass fixture.
- ✔ `display_case.glb` **Vitrine** — A small standing glass display cabinet (a vitrine) with a slim polished gold frame, two lit glass shelves each holding an empty red velvet pedestal, the cabinet itself being the whole object.
- ✔ `jewelry_box.glb` **Schmuckkästchen** — An open velvet jewelry box with a flawless mirror in the lid, holding three sparkling gem-set dice.
- ✔ `rectifier.glb` **Gleichrichter** — A pristine glass vacuum tube on a polished brass socket, twin filaments glowing bright, a faint cyan corona.

## Coupons & Packs

- ✔ `bargain_hunter.glb` **Schnäppchenjäger** — A glossy red price-tag gun with a crisp glowing percent tag hanging out, clean ergonomic grip.
- ✔ `stamp_machine.glb` **Frankiermaschine** — A gleaming retro postage meter in cream enamel with polished brass rollers, a crisp envelope sliding out.
- ✔ `fine_print.glb` **Kleingedrucktes** — A polished brass magnifying glass resting on a neatly rolled contract scroll dense with micro print, one clause circled in glowing marker.

## Pool & Trays

- ✔ `recycling.glb` **Bumerang** — A polished wooden boomerang with crisp neon-cyan edge stripes, mounted mid-spin on a sleek display stand.
- ✔ `fresh_goods.glb` **Frische Ware** — A tidy wooden market crate holding six shrink-wrapped glowing dice like fresh produce, the wrap glossy and taut.
- ✔ `sediment.glb` **Bodensatz** — An elegant glass carafe with a luminous sediment layer settled at the bottom, polished cork stopper.

## Shop & Angebote

- ✔ `seal_of_quality.glb` **Gütesiegel** — A golden wax seal stamp standing beside a flawless pressed wax medallion with a crisp star emblem.
- ✔ `bulk_discount.glb` **Mengenrabatt** — A neat miniature shipping pallet with three identical crates wrapped in glossy translucent film, one glowing tag.

## Verträge mit dem Haus

- ✔ `ad_drum.glb` **Werbetrommel** — A pristine marching drum with a bold glowing megaphone emblem on its skin, a polished mallet, bright confetti scattered on the base.
- ✔ `shyster.glb` **Winkeladvokat** — A sleek leather briefcase packed so full that crisp contracts fan out of its seams, latched with a glowing brass paragraph-symbol clasp.

## Meta & Totem-Reihe

- ✔ `parrot_totem.glb` **Papagei-Totem** — A cleanly carved totem topped with a vivid cyber-parrot head, one eye a glowing camera lens, feathers painted in bold saturated colors.
- ✔ `echo_totem.glb` **Echo-Totem** — A smooth stone totem of three identical open-mouthed faces stacked, each mouth glowing dimmer than the one above.
- ✔ `hermit_crab.glb` **Einsiedlerkrebs** — A cute hermit crab wearing a neat spiral stack of glossy casino chips with plain striped edges as its shell, polished chrome legs, antenna tips glowing.

## Essenz-Charms

- ✔ `amalgam.glb` **Amalgam** — A polished stone mortar and pestle holding a perfect blob of mirror-liquid metal, beads of it floating gently above the rim.
- ✔ `lead_apron.glb` **Bleischürze** — A neatly folded grey-blue lead apron on a polished hanger stand, a crisp glowing radiation trefoil badge.
- ✔ `storm_glass.glb` **Sturmglas** — A flawless storm glass vial with delicate feathery crystals inside, held in a polished brass cradle, faint lightning flickering within.
- ✔ `lightning_rod.glb` **Blitzableiter** — A gleaming copper lightning rod on a tidy roof-peak mount, a crisp blue spark arcing from its tip.
- ✔ `darkroom.glb` **Dunkelkammer** — A spotless darkroom safelight glowing deep red, two perfectly developed photos hanging from a neat little line.
- ✔ `pressure_vessel.glb` **Druckkessel** — A polished riveted boiler tank with a gleaming pressure gauge and valve, its seams glowing a controlled warm orange.
- ✔ `aqua_fortis.glb` **Scheidewasser** — An elegant apothecary bottle of clear green acid with gold flakes dissolving inside, polished ground-glass stopper.
- ✔ `contrast_agent.glb` **Kontrastmittel** — A gleaming medical vial of luminous white-blue liquid beside a spotless glass syringe on a polished steel tray.
- ✔ `censer.glb` **Weihrauchfass** — A polished brass thurible on gleaming chains with an elegant pierced lid, a graceful ribbon of luminous smoke curling out.
- ✔ `solar_sail.glb` **Sonnensegel** — A flawless golden foil solar sail stretched taut on slim struts around a polished probe hub, catching brilliant light.
- ✔ `storm_front.glb` **Gewitterfront** — A crystal-clear glass dome containing a dramatic rolling storm cloud with crisp lightning flashes, on a polished walnut base.
- ✔ `ignition_coil.glb` **Zündspule** — A factory-new ignition coil with a glossy red high-tension lead, a crisp blue spark jumping from its polished terminal.
- `bell_jar.glb` **Glasglocke** — A spotless laboratory bell jar on a lacquered wooden base, a bright wisp of light hovering inside, polished brass valve on top.
- ✔ `glaze_brush.glb` **Lasurpinsel** — A fine varnish brush resting across an open polished tin of crystal-clear glowing glaze, one elegant glossy drip on the rim.
- ✔ `fluorescent_tube.glb` **Leuchtstoffröhre** — A gracefully bent fluorescent tube on polished chrome mounts, glowing an even cool white-green.
- ✔ `polarizer.glb` **Polarfilter** — A camera polarizing filter ring standing upright in a sleek holder, its glass shifting in clean iridescent teal-to-violet.
- ✔ `alkahest.glb` **Alkahest** — A flawless crystal alembic flask of swirling opalescent solvent, a tiny die dissolving inside in a clean glow.
- ✔ `magnetic_trap.glb` **Magnetfalle** — A sleek containment device: two polished chrome rings suspending a brilliant violet mote, cables routed neatly into a compact base.
- ✔ `camouflage.glb` **Tarnkappe** — A pristine hooded cloak on a polished stand, half its fabric fading to glassy transparency with a clean shimmering edge.
- ✔ `fuse.glb` **Zündschnur** — A neatly coiled fuse rope on a lacquered spool, its lit end throwing crisp orange sparks.
- ✔ `cutting_torch.glb` **Schneidbrenner** — A factory-new cutting torch with tidy twin hoses and a perfect blue flame cone, spotless goggles hooked over the valve.
- ✔ `moderator.glb` **Steuerstab** — A gleaming control rod half lowered into a polished socket block, its tip glowing serene Cherenkov blue, crisp caution chevrons.
- ✔ `meteorite.glb` **Meteorit** — A sculptural iron meteorite with smooth pitted dimples on a polished museum mount, thin veins glowing like embers.
- ✔ `mycelium.glb` **Pilzgeflecht** — A clean-cut log slice threaded with delicate glowing turquoise mycelium and a tidy cluster of luminous mushrooms.
- ✔ `highlighter.glb` **Neonmarker** — A chunky brand-new neon-yellow highlighter with the cap off, tip blazing under blacklight, glossy spotless barrel.
- `ash_cloud.glb` **Aschewolke** — A crystal-clear glass dome over a perfectly sculpted miniature volcano mid-eruption, its ash plume laced with crisp tiny lightning.
- ✔ `feedback.glb` **Rückkopplung** — A polished vintage microphone facing a pristine little amplifier, a clean glowing feedback arc bridging them.
- ✔ `ice_mirror.glb` **Eisspiegel** — A hand mirror carved from flawless clear ice with elegant frost patterns on the frame, a crisp beam of light rising from the glass.
- ✔ `polar_day.glb` **Polartag** — A spotless glass globe of a serene arctic horizon, a low golden midnight sun resting on the ice, warm light across the snow.
- ✔ `magnetar.glb` **Magnetar** — A brilliant white orb held in a sleek polished armature, elegant curved magnetic field arcs radiating outward.
- ✔ `radio_telescope.glb` **Radioteleskop** — A pristine white radio telescope dish on a slim lattice mount, tilted skyward, its receiver glowing soft green.

## Energie & Pointer

- ✔ `superconductor.glb` **Supraleiter** — A flawless black ceramic puck levitating above a polished chrome magnet block, a gentle frost mist and a clean cyan underglow.
- ✔ `dynamo.glb` **Dynamo** — A polished brass hand-crank dynamo with gleaming gears and a small bright bulb, its crank handle lacquered.
- ✔ `standby_light.glb` **Standby-Licht** — A sleek spotless matte-black device slab with one glowing amber power symbol and a tiny red LED beside it.
- ✔ `soldering_iron.glb` **Lötkolben** — A brand-new soldering iron resting on a gleaming coiled-spring stand, tip glowing, a neat curl of silver solder beside it.
- ✔ `ground_wire.glb` **Erdungskabel** — A neatly coiled yellow-green grounding cable with a polished copper clamp gripping a clean steel spike.

## Runen & Werkbank

- ✔ `burin.glb` **Stichel** — A fine engraver's burin with a polished mushroom grip and glowing steel V-tip, resting on a spotless leather pad with a few elegant metal curls.
- ✔ `luminous_paint.glb` **Leuchtfarbe** — A pristine paint tin of luminous cyan-green paint, a clean brush laid across it with one glowing drop about to fall.
- ✔ `kiln.glb` **Härteofen** — A compact hardening kiln with gleaming panels, its door slit glowing white-orange, crisp warning stripes and a polished temperature dial.
- ✔ `clamp.glb` **Zwinge** — A precision screw clamp in polished steel and pale beechwood, gently holding a glowing die blank.
- `encore.glb` **Füllhorn** — A magnificent polished golden cornucopia spilling neat wax-sealed scrolls and sparkling gems, a warm glow from inside.

## Automat, Nebenwette & Hinterzimmer

- ✔ `odds_sheet.glb` **Quotenblatt** — A tidy clipboard holding a crisp odds sheet with dense printed columns, a sharpened pencil under the polished clip.
- ✔ `free_spin.glb` **Freispiel** — A gleaming brass arcade token embossed with a star, standing upright in a polished coin-slot pedestal.
- ✔ `fenced_goods.glb` **Hehlerware** — A neat wooden crate with the lid levered open, glossy luxury goods nestled in clean straw (a pearl necklace, a blue gem, a smooth unmarked gold bar), a polished crowbar resting against it.
- ✔ `jackpot_bell.glb` **Jackpotglocke** — A polished golden service bell mid-ring on a glossy red base, crisp motion echoes, two bright coins bouncing beside it.
- ✔ `deposit_shelf.glb` **Pfandregal** — A tidy wooden shelf holding four glowing deposit bottles in a neat row, a polished coin box mounted on its side.
- `tip_jar.glb` **Trinkgeldglas** — A sparkling glass jar half full of bright coins with one banknote folded like a flower, a crisp label around its neck.
- ✔ `consolation_prize.glb` **Trostpreis** — A cute little plush teddy with a satin sash ribbon, neat stitching and button eyes, sitting with a slight hopeful slump.

## Auslösungen & Zählreihenfolge

- ✔ `factory_finish.glb` **Schutzfolie** — A flawless glossy white die with a half-peeled translucent glowing blue protective film lifting from its top face, the film edge catching the light.
- ✔ `bottle_rack.glb` **Flaschenregal** — A polished wooden rack holding six corked vials of glowing essences in vivid clean colors.
- ✔ `pressure_gauge.glb` **Manometer** — A gleaming brass pressure gauge with a spotless white dial bearing only tick marks (no numbers, no letters), its red needle poised near the top of the scale.
- ✔ `empty_plinth.glb` **Leerer Sockel** — An immaculate white marble plinth ringed by a red velvet rope on four brass posts, nothing on top but a faint dust outline where the exhibit stood, the plinth with its ropes being the whole object.
- ✔ `odometer.glb` **Kilometerzähler** — A polished chrome mechanical odometer with rolling digits glowing warm white, mounted on a sleek bracket.
- `tail_light.glb` **Rücklicht** — A pristine bicycle tail light with a crisp faceted red lens glowing bright, gleaming chrome housing.
- `strobe.glb` **Stroboskop** — A spotless club strobe head on a sleek stand, caught mid-flash with a clean hard white burst.
- ✔ `metronome.glb` **Metronom** — A pyramid metronome in flawless dark lacquer with gleaming brass fittings, its arm mid-tick trailing a thin neon streak.

## Erkennung, Hand-Spanne & Vorrat

- ✔ `gap_tooth.glb` **Zahnlücke** — A cheerful set of pristine porcelain teeth on a polished brass display stand, one front tooth missing, a soft cyan glow filling the gap.
- ✔ `drop_height.glb` **Fallhöhe** — A sleek chrome high-dive tower miniature with a tall ladder and top platform, a glossy die caught mid-drop trailing a crisp neon streak down to a small crystal-clear pool.
- ✔ `inventory.glb` **Inventur** — A glossy white handheld barcode scanner sweeping a crisp red scan beam across a tidy stack of polished dice on a spotless tray.

## Ladung

- `voltmeter.glb` **Spannungsmesser** — A polished analog voltmeter in a glossy black case, big spotless white dial bearing only tick marks (no numbers, no letters) with the red needle swung high, two gleaming brass terminals with a tiny cyan spark between them.
- ✔ `safety_fuse.glb` **Sicherung** — A chunky ceramic cartridge fuse with polished brass end caps seated in a clean black holder, the thin wire inside glowing a steady warm orange (an ELECTRICAL fuse — the Zündschnur is `fuse.glb`).
- ✔ `heat_sink.glb` **Kühlkörper** — A gleaming finned aluminum heat sink with crisp machined ridges, a small glossy die resting on top in a cool cyan frost mist.
- ✔ `insulation_tape.glb` **Isolierband** — A fat roll of glossy black electrical tape with a neatly lifted tab, beside it a bare copper wire wrapped halfway, the fresh wrap seam glowing faint cyan.
- ✔ `arc_flash.glb` **Lichtbogen** — Two polished copper electrodes on white ceramic insulators with a brilliant white-blue arc bridging the gap, mounted on a spotless slate base.
- ✔ `grounding.glb` **Erdung** — A heavy polished copper earth spike half sunk into a neat square of dark turf, a thick braided copper strap bolted to its top, a soft green pulse flowing downward into the ground.
- ✔ `continuous_duty.glb` **Dauerbetrieb** — A glossy industrial rotary switch locked in the ON position by a gleaming chrome padlock through its lever, a steady green lamp glowing above it.
- `transformer.glb` **Transformator** — A laminated iron core carrying a small copper coil on one side and a much larger one on the other, a crisp blue spark jumping off the large coil.
- ✔ `ember_core.glb` **Glutkern** — A glossy black obsidian die split by one clean geometric fracture, revealing a bright molten-orange core, a few tidy embers drifting upward, on a polished slate slab.
- ✔ `spark_plug.glb` **Zündkerze** — A brand-new spark plug standing upright, spotless white ceramic insulator and polished hex steel body, a crisp blue spark jumping the gap at its tip.

## Verwaiste Modelle (kein Charm nutzt sie)

- `backwards_mirror.glb` — ein Zierspiegel; vermutlich der alte Stand des Zerbrochenen
  Spiegels. Wenn er zerbrochen aussieht: in `broken_mirror.glb` umbenennen, dann ist er
  sofort verdrahtet.
- `lucky_knot.glb` — laut Texturnamen eine goldene Hand ("golden hand charm"), passt zu
  keinem aktuellen Charm.
- `dowsing_rod.glb` — Wünschelrute; könnte als `pendulum.glb` dienen, ist aber eine
  Y-Rute, kein Pendel.
- `golden_scarab.glb` — Skarabäus; freier Kandidat für einen künftigen Charm.
