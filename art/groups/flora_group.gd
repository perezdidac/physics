## Wind-swaying surface plants, one art per plant type; "flora:" is the default plant of the other maps.
## Registry file of the "flora" art group: add or replace a kind by editing only this file (and the kind's own class).
extends RefCounted


static func register(reg: ArtRegistry) -> void:
	reg.add("flora:MONTSERRAT", FloraMontserratArt.new())
	reg.add("flora:CADAQUES", FloraCadaquesArt.new())
	reg.add("flora:TAULL", FloraTaullArt.new())
	reg.add("flora:DELTA_EBRE", FloraDeltaEbreArt.new())
	reg.add("flora:TARRACO", FloraTarracoArt.new())
	reg.add("flora:PEDRAFORCA", FloraPedraforcaArt.new())
	reg.add("flora:MONTBLANC", FloraMontblancArt.new())
	reg.add_prefix("flora:", FloraDefaultArt.new())
