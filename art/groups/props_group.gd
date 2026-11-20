## Battlefield props: barrel, crate, mine, caganer, rovello, escudella, tombstone, pine nut.
## Registry file of the "props" art group: add or replace a kind by editing only this file (and the kind's own class).
extends RefCounted


static func register(reg: ArtRegistry) -> void:
	reg.add("barrel", BarrelArt.new())
	reg.add("crate", CrateArt.new())
	reg.add("parachute", ParachuteArt.new())
	reg.add("mine", MineArt.new())
	reg.add("caganer", CaganerArt.new())
	reg.add("rovello", RovelloArt.new())
	reg.add("escudella", EscudellaArt.new())
	reg.add("tombstone", TombstoneArt.new())
	reg.add("pine_nut", PineNutArt.new())
