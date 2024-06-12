extends Node

@export var black_stone_scene : PackedScene
@export var white_stone_scene : PackedScene
@export var last_play_scene : PackedScene

var goban_dim : int
var board_size : int
var cell_size : int
var grid_pos : Vector2i
var player : int
var player_panel_pos : Vector2i
var temp_stone : Sprite2D
var pass_count : int
var grid_data : Array
var grid_obj : Array
var grid_history : Array
var captured_stones : Array


func _ready():
	goban_dim = 9
	board_size = 480
	cell_size = board_size / goban_dim
	# get coordinate of player panel
	player_panel_pos = $PlayerPanel.get_position()
	start_game()


func start_game() -> void:
	# init grid
	grid_data = []
	grid_obj = []
	var grid_data_row
	var grid_obj_row
	for i in range(goban_dim):
		grid_data_row = []
		grid_obj_row = []
		for j in range(goban_dim):
			grid_data_row.append(0)
			grid_obj_row.append(null)
		grid_data.append(grid_data_row)
		grid_obj.append(grid_obj_row)
	grid_history = grid_data
		
	# black is first to play
	player = -1
	
	# reset the consecutive number of pass
	pass_count = 0
	captured_stones = [0, 0]
	
	# remove all stones
	get_tree().call_group("blacks", "queue_free")
	get_tree().call_group("whites", "queue_free")
	get_tree().call_group("markers", "queue_free")
	
	# show only board ready to play
	$HUD.hide()
	get_tree().paused = false
	
	# add first player stone in side panel
	add_stone(player_panel_pos + Vector2i(cell_size / 2, cell_size / 2), true)


func _input(event) -> void:
	# react only if left click with mouse
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		# exit function if click is outside the board
		if event.position.x > board_size:
			return
		
		# convert mouse position to grid position
		grid_pos = Vector2i(event.position / cell_size)
		
		if can_add_stone():
			# ACTION = add stone
			var stone = add_stone(grid_pos * cell_size + Vector2i(cell_size / 2, cell_size / 2))
			grid_data[grid_pos.y][grid_pos.x] = player
			grid_obj[grid_pos.y][grid_pos.x] = stone
			update_marker(grid_pos * cell_size + Vector2i(cell_size / 2, cell_size / 2))
			
			# RECONCILIATION = need to remove the enemies groups
			kill_enemies()
			print(captured_stones)
			
			# next player
			player *= -1
			pass_count = 0
		
		# update temp stone for next player
		temp_stone.queue_free()
		add_stone(player_panel_pos + Vector2i(cell_size / 2, cell_size / 2), true)


func can_add_stone() -> bool:
	# rule 0 = position should be free
	if grid_data[grid_pos.y][grid_pos.x] != 0:
		return false

	# create a temporary grid, to verify rule 1 and 2
	var tmp_grid = grid_data.duplicate(true)
	tmp_grid[grid_pos.y][grid_pos.x] = player
	# identified all liberties of the group created by this stone
	var group_of_stones = get_stones_pos_of_group(tmp_grid, grid_pos, [])
	var liberties = get_liberties_for_group(tmp_grid, group_of_stones)

	# Rule 1 after checking if we kill enemy stones
	var enemies := get_nearby_items(tmp_grid, grid_pos, player * -1)
	for enemy in enemies:
		# identified all stones the group of enemies
		var enemy_group = get_stones_pos_of_group(tmp_grid, enemy, [])
		# count liberty of this group
		var enemy_liberties = get_liberties_for_group(tmp_grid, enemy_group)
		# group can be killed therefore we have at least one additional liberty
		if len(enemy_liberties) == 0:
			liberties.append(enemy)
	if len(liberties) == 0:
		return false
	
	# Rule 2 ckeck that action is not returning to previous grid
	if tmp_grid == grid_history:
		return false
	grid_history = tmp_grid
	
	return true


func add_stone(pos : Vector2i, temp=false) -> Sprite2D:
	var stone
	if player == 1:
		stone = white_stone_scene.instantiate()
	else:
		stone = black_stone_scene.instantiate()
	stone.position = pos
	add_child(stone)
	
	if temp: temp_stone = stone
	
	return stone


func update_marker(pos) -> void:
	# remove marker of last stone played
	get_tree().call_group("markers", "queue_free")
	
	var last_play = last_play_scene.instantiate()
	last_play.position = pos
	add_child(last_play)


func get_stones_pos_of_group(grid : Array, pos : Vector2i, visited := []) -> Array:
	var groups := []
	var stone : int = grid[pos.y][pos.x]
	# this first stone is part of the group
	groups.append(pos)
	
	# flag this position as visited to avoid infinite loop
	visited.append(pos)
	
	# list allies 
	var allies := get_nearby_items(grid, pos, stone)
	for ally in allies:
		# pass the position already verified
		if ally in visited:
			continue
		
		var other_stones := []
		# recursive search
		other_stones = get_stones_pos_of_group(grid, ally, visited)
		# destructure the recieved Array to append stone not already identified
		for other_stone in other_stones:
			if groups.find(other_stone) == -1:
				groups.append(other_stone)
	return groups


func get_liberties_for_group(grid, group) -> Array:
	# return the list of liberties for this "group" on this "grid"
	var liberties := []
	for stone in group:
		var nearby_liberties = get_nearby_items(grid, stone, 0)
		var nearby_intersections := get_nearby_intersections(stone)
		for nearby_liberty in nearby_liberties:
			if liberties.find(nearby_liberty) == -1:
				liberties.append(nearby_liberty)
	return liberties


func get_nearby_items(grid : Array, pos : Vector2i, item = null) -> Array:
	# return a list of all orthogonal intersections of this "pos" 
	# in this "grid" with the desired "item" value
	var nearby_intersections := get_nearby_intersections(pos)
	if item not in [0, -1, 1]:
		return nearby_intersections
	var intersections := []
	for nearby_intersection in nearby_intersections:
		if grid[nearby_intersection.y][nearby_intersection.x] == item:
			intersections.append(nearby_intersection)
	return intersections


func get_nearby_intersections(pos : Vector2i) -> Array:
	# return a list of all orthogonal intersections of this position in the board
	var intersections := []
	if pos.x > 0:  # left intersection
		intersections.append(Vector2i(pos.x - 1, pos.y))
	if pos.x < goban_dim - 1:  # right intersection
		intersections.append(Vector2i(pos.x + 1, pos.y))
	if pos.y > 0:  # up intersection
		intersections.append(Vector2i(pos.x, pos.y - 1))
	if pos.y < goban_dim - 1:  # down intersection
		intersections.append(Vector2i(pos.x, pos.y + 1))
	return intersections


func kill_enemies() -> void:
	var enemies := get_nearby_items(grid_data, grid_pos, player * -1)
	
	for enemy in enemies:
		# identified all stones linked by this stone
		var enemy_group = get_stones_pos_of_group(grid_data, enemy, [])

#			# count liberty of this stone
		var enemy_liberties = get_liberties_for_group(grid_data, enemy_group)
		
		if len(enemy_liberties) == 0:
			for stone in enemy_group:
				grid_data[stone.y][stone.x] = 0
				remove_stone(stone)
				captured_stones[player] += 1


func remove_stone(pos) -> void:
	var stone = grid_obj[pos.y][pos.x]
	stone.queue_free()


func _on_pass_button_pressed():
	# remove marker of last stone played
	get_tree().call_group("markers", "queue_free")
	
	# next player
	player *= -1
	
	# if 2 passes happens, game is ended.
	pass_count += 1
	if pass_count == 2:
		get_tree().paused = true
		stop_game()
	
	# update temp stone for next player
	temp_stone.queue_free()
	add_stone(player_panel_pos + Vector2i(cell_size / 2, cell_size / 2), true)


func _on_resign_button_pressed() -> void:
	player *= -1
	get_tree().paused = true
	game_over()


func game_over() -> void:
	var player_name = "White" if player == 1 else "Black"
	var message = "{player} won the game.".format({"player": player_name})
	$HUD.show_message(message)
	$HUD.show()


func stop_game() -> void:
	var message = "points to caculate"
	$HUD.show_message(message)
	$HUD.show()


func _on_hud_start_game() -> void:
	start_game()
