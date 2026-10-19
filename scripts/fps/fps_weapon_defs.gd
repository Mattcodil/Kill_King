## fps_weapon_defs.gd
## Per-piece FPS loadout: weapon + health + movement speed.
## Stronger chess pieces get stronger guns and more HP. Edit the numbers here
## to rebalance — nothing else in the FPS code hard-codes these values.
##
## Keys:
##   name       display name of the weapon
##   kind       model/sound family (see FpsWeaponModels / FpsSfx)
##   hp         piece health in the duel
##   speed      walk speed (m/s)
##   damage     damage per bullet (per pellet for shotguns)
##   pellets    bullets per shot
##   interval   seconds between shots
##   auto       true = hold to keep firing, false = one shot per click
##   mag        magazine size
##   reload     reload time (s)
##   spread     random cone half-angle in degrees
##   range_eff  distance (m) up to which damage is full; falls off beyond it
##   pref_range distance (m) the AI tries to keep when using this weapon
##   recoil     view-kick strength

class_name FpsWeaponDefs
extends RefCounted

const LOADOUT: Dictionary = {
	ChessEnums.PieceType.PAWN: {
		"name": "Colt M1911", "kind": "pistol", "hp": 60.0, "speed": 5.0,
		"damage": 18.0, "pellets": 1, "interval": 0.30, "auto": false,
		"mag": 7, "reload": 1.5, "spread": 0.8, "range_eff": 40.0,
		"pref_range": 12.0, "recoil": 1.0,
	},
	ChessEnums.PieceType.KNIGHT: {
		"name": "Uzi", "kind": "smg", "hp": 90.0, "speed": 6.0,
		"damage": 9.0, "pellets": 1, "interval": 0.075, "auto": true,
		"mag": 25, "reload": 1.8, "spread": 3.0, "range_eff": 22.0,
		"pref_range": 8.0, "recoil": 0.6,
	},
	ChessEnums.PieceType.BISHOP: {
		"name": "Remington 870", "kind": "shotgun", "hp": 100.0, "speed": 5.0,
		"damage": 11.0, "pellets": 8, "interval": 0.9, "auto": false,
		"mag": 6, "reload": 2.4, "spread": 4.5, "range_eff": 9.0,
		"pref_range": 6.0, "recoil": 2.2,
	},
	ChessEnums.PieceType.ROOK: {
		"name": "HK G3", "kind": "g3", "hp": 140.0, "speed": 4.6,
		"damage": 26.0, "pellets": 1, "interval": 0.14, "auto": true,
		"mag": 20, "reload": 2.2, "spread": 1.2, "range_eff": 80.0,
		"pref_range": 18.0, "recoil": 1.5,
	},
	ChessEnums.PieceType.QUEEN: {
		"name": "AK-47 Kalashnikov", "kind": "ak", "hp": 170.0, "speed": 5.6,
		"damage": 20.0, "pellets": 1, "interval": 0.10, "auto": true,
		"mag": 30, "reload": 2.0, "spread": 2.0, "range_eff": 55.0,
		"pref_range": 14.0, "recoil": 1.3,
	},
	ChessEnums.PieceType.KING: {
		"name": "Desert Eagle", "kind": "deagle", "hp": 130.0, "speed": 4.8,
		"damage": 48.0, "pellets": 1, "interval": 0.50, "auto": false,
		"mag": 8, "reload": 2.2, "spread": 0.8, "range_eff": 45.0,
		"pref_range": 14.0, "recoil": 2.0,
	},
}

const PIECE_NAMES: Dictionary = {
	ChessEnums.PieceType.PAWN:   "Pawn",
	ChessEnums.PieceType.ROOK:   "Rook",
	ChessEnums.PieceType.KNIGHT: "Knight",
	ChessEnums.PieceType.BISHOP: "Bishop",
	ChessEnums.PieceType.QUEEN:  "Queen",
	ChessEnums.PieceType.KING:   "King",
}

static func get_def(piece_type: int) -> Dictionary:
	if LOADOUT.has(piece_type):
		return LOADOUT[piece_type]
	return LOADOUT[ChessEnums.PieceType.PAWN]

static func piece_name(piece_type: int) -> String:
	return PIECE_NAMES.get(piece_type, "Piece")
