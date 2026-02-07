extends PanelContainer

# --- REFERENCIAS PANELES ---
# Como el script está EN InfoPanel, buscamos directamente en sus hijos
@onready var panels = {
	0: $Margin/HBox/Panel_Team0 if has_node("Margin/HBox/Panel_Team0") else $Margin/HBox.get_child(0).get_child(0),
	1: $Margin/HBox/Panel_Team1 if has_node("Margin/HBox/Panel_Team1") else $Margin/HBox.get_child(2).get_child(0),
	2: $Margin/HBox/Panel_Team2 if has_node("Margin/HBox/Panel_Team2") else $Margin/HBox.get_child(4).get_child(0)
}

# --- REFERENCIAS TEXTOS (NOMBRES) ---
func _get_label(root_node, label_name):
	if root_node: return root_node.find_child(label_name, true, false)
	return null

@onready var vs_separator_2 = $Margin/HBox/VS_2

# Nombres genéricos de EQUIPOS (Para cuando no es su turno)
const TEAM_DEFAULT_NAMES = {
	0: "AZULES",
	1: "ROJOS",
	2: "VERDES"
}

func setup_hud_inicial():
	var total_equipos = GameManager.total_teams_in_play
	
	# Controlamos la visibilidad desde el wrapper (el abuelo del contenido)
	_set_wrapper_visible(0, true)
	_set_wrapper_visible(1, true)
	_set_wrapper_visible(2, (total_equipos == 3))
	vs_separator_2.visible = (total_equipos == 3)

	actualizar_marcadores({0: 0, 1: 0, 2: 0})

func _set_wrapper_visible(id: int, state: bool):
	if panels.has(id) and panels[id]:
		# Ocultamos el MarginContainer padre para que no ocupe espacio
		panels[id].get_parent().visible = state

func actualizar_marcadores(scores: Dictionary):
	for team_id in scores.keys():
		if not panels.has(team_id): continue
		var lbl = _get_label(panels[team_id], "Lbl_Score")
		if lbl:
			var meta = 2 if GameManager.total_teams_in_play == 2 else 1
			lbl.text = str(scores[team_id]) + " / " + str(meta)

func actualizar_turno_visual(team_activo_id: int, nombre_jugador: String):
	for id in panels.keys():
		var panel = panels[id]
		if not panel or not panel.is_visible_in_tree(): continue
		
		# --- CORRECCIÓN PIVOTE ---
		# Calculamos el centro exacto antes de animar para que crezca desde el medio
		panel.pivot_offset = panel.size / 2
		
		var color_base = GameManager.get_team_color(id)
		var style = panel.get_theme_stylebox("panel")
		if not style: style = StyleBoxFlat.new()
		if not style.resource_local_to_scene: style = style.duplicate()
		
		var lbl_name = _get_label(panel, "Lbl_Name")
		
		if id == team_activo_id:
			# --- ACTIVO (Pop!) ---
			style.bg_color = color_base.darkened(0.2)
			style.border_width_bottom = 6
			style.border_color = color_base.lightened(0.4)
			
			if lbl_name:
				lbl_name.text = "▶ " + nombre_jugador.to_upper() + " ◀"
				lbl_name.modulate = Color.WHITE
			
			var tween = create_tween()
			tween.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
			# Crece al 110% (Gracias al margen, no se saldrá ni cortará)
			tween.tween_property(panel, "scale", Vector2(1.1, 1.1), 0.3)
			
		else:
			# --- INACTIVO ---
			style.bg_color = Color(0.1, 0.1, 0.1, 0.9) 
			style.border_width_bottom = 0
			
			if lbl_name:
				lbl_name.text = TEAM_DEFAULT_NAMES[id]
				lbl_name.modulate = Color(0.7, 0.7, 0.7)
			
			var tween = create_tween()
			tween.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
			# Vuelve a tamaño normal
			tween.tween_property(panel, "scale", Vector2.ONE, 0.3)
			
		panel.add_theme_stylebox_override("panel", style)
