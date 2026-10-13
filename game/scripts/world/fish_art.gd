class_name FishArt
## Builds a fish under `parent`: the Tripo model ("moonfin", "koi") when it
## exists, otherwise a primitive stand-in. Fish face +Z.


static func build(parent: Node3D, kind := "moonfin", glow := true) -> Node3D:
	var root := Node3D.new()
	parent.add_child(root)
	var model := ModelLib.scene(kind)
	if model:
		var inst := model.instantiate()
		root.add_child(inst)
		if glow:
			# A soft moonlit sheen that keeps the fish's own colours.
			ModelLib.glow(inst, 0.3 if kind == "moonfin" else 0.12, Color(0.55, 0.85, 1.0) if kind == "moonfin" else Color(1.0, 0.8, 0.6))
		# Rigged fish swim with a travelling body wave; start each at its own phase.
		var ap := Npc._find_animation_player(inst)
		if ap and ap.has_animation("swim"):
			for a in ["swim", "flop"]:
				if ap.has_animation(a):
					ap.get_animation(a).loop_mode = Animation.LOOP_LINEAR
			ap.play("swim")
			ap.seek(randf() * ap.current_animation_length, true)
			root.set_meta("anim", ap)
		return root
	if kind == "koi":
		_koi(root)
	else:
		_moonfin(root, glow)
	return root


static func _moonfin(f: Node3D, glow: bool) -> void:
	var teal := PH.mat(Color("3a9aa2"), 0.3, Color("2e8a93"), 0.15 if glow else 0.0)
	var belly := PH.mat(Color("f2eddc"), 0.4)
	var gold := PH.mat(Color("f2c46b"), 0.3, Color("f5b84c"), 1.6)
	var fin := PH.mat(Color("b2a9ec"), 0.5, Color("a39af0"), 0.3)
	var dark := PH.mat(Color("141a22"), 0.2)
	PH.sphere(f, 0.06, Vector3(0, 0.012, 0), teal, Vector3(0.85, 1.15, 2.6), 18)
	PH.sphere(f, 0.055, Vector3(0, -0.012, 0.01), belly, Vector3(0.8, 0.8, 2.4), 18)
	for side in [-1.0, 1.0]:
		var cres := PH.torus(f, 0.022, 0.03, Vector3(0.05 * side, 0.015, 0.03), gold, Vector3(0, 0, 90))
		cres.scale = Vector3(1, 1, 0.6)
		PH.sphere(f, 0.012, Vector3(0.042 * side, 0.025, 0.115), dark, Vector3.ONE, 8)
		var pec := PH.sphere(f, 0.04, Vector3(0.05 * side, -0.02, 0.05), fin, Vector3(0.2, 0.5, 1.0), 10)
		pec.rotation_degrees = Vector3(0, 30 * side, 20 * side)
	var dorsal := PH.sphere(f, 0.05, Vector3(0, 0.07, -0.01), fin, Vector3(0.15, 0.7, 1.3), 12)
	dorsal.rotation_degrees = Vector3(-15, 0, 0)
	for side in [-1.0, 1.0]:
		var tail := PH.sphere(f, 0.05, Vector3(0, 0.025 * side, -0.18), fin, Vector3(0.15, 0.6, 1.2), 12)
		tail.rotation_degrees = Vector3(35 * side, 0, 0)


static func _koi(f: Node3D) -> void:
	var cream := PH.mat(Color("f3ead8"), 0.35, Color("f3ead8"), 0.08)
	var coral := PH.mat(Color("e98a5c"), 0.35, Color("e98a5c"), 0.1)
	var fin := PH.mat(Color("f6e2d0"), 0.5)
	var dark := PH.mat(Color("141a22"), 0.2)
	PH.sphere(f, 0.08, Vector3.ZERO, cream, Vector3(0.8, 0.9, 2.7), 18)
	PH.sphere(f, 0.06, Vector3(0, 0.035, 0.06), coral, Vector3(0.75, 0.6, 1.4), 14)
	PH.sphere(f, 0.05, Vector3(0.0, 0.03, -0.11), coral, Vector3(0.7, 0.6, 1.2), 12)
	for side in [-1.0, 1.0]:
		PH.sphere(f, 0.012, Vector3(0.055 * side, 0.02, 0.17), dark, Vector3.ONE, 8)
		var pec := PH.sphere(f, 0.05, Vector3(0.06 * side, -0.03, 0.08), fin, Vector3(0.15, 0.5, 1.0), 10)
		pec.rotation_degrees = Vector3(0, 35 * side, 25 * side)
	for side in [-1.0, 1.0]:
		var tail := PH.sphere(f, 0.07, Vector3(0, 0.03 * side, -0.26), fin, Vector3(0.12, 0.7, 1.3), 12)
		tail.rotation_degrees = Vector3(30 * side, 0, 0)
