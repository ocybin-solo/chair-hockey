extends Node2D


# --- GAME CONFIGURATION STATE (Modified by Options) ---
var puck_bounciness: float = 1.0
var puck_max_speed: float = 1800.0  # px/sec. Hard speed cap AND scales how hard hits are (see apply_mallet_impact_force)
var score_limit: int = 7
var mallet_radius: float = 43.0
var puck_radius: float = 34.0
var goal_frac_p1: float = 1.0 / 3.0   # Player 1's goal opening (bottom net) as a fraction of screen width
var goal_frac_p2: float = 1.0 / 3.0   # Player 2's goal opening (top net)
var tracer_interval: float = 0.03   # Seconds between echoes (echoes x this = trail length)
var tracer_hue_shift: float = 0.08  # Hue change per echo. 0 = plain fading echoes
var tracer_echoes: int = 8          # 0 = tracers off

var color_table: Color = Color("000000ff")
var color_puck: Color = Color("f94900ff")
var color_p1: Color = Color("ff00ffff")
var color_p2: Color = Color("00ffffff")
var color_lines: Color = Color("ffffffff") # Rink lines color configuration

var serve_mode_loser_gets_it: bool = true # Toggle: true = Loser gets it, false = Make it take it

# --- TUNING CONSTANTS ---
const MAX_MALLET_SPEED: float = 2500.0   # px/sec cap on mallet movement, so a far-away finger can't ram a pinned puck

const SLIDE_DAMP: float = .5          # Higher = a released mallet stops sooner
const SLIDE_BOUNCE: float = 1000.1        # Speed kept when a sliding mallet hits a wall or line
const SLIDE_REST_SPEED: float = 5.0   # Below this a sliding mallet stops dead and goes solid again
const FLICK_SMOOTHING: float = 95.0    # Higher = throw speed reflects only the very end of the swipe
const MAX_SLIDE_SPEED: float = 1500.0  # Cap on throw speed

const COUNTDOWN_STEP: float = 0.6             # Seconds per countdown number
const WALL_THICKNESS: float = 200.0           # Walls are thick so the puck can never be squeezed or tunnel through
const FLIP_TOP_PLAYER_TEXT: bool = true       # Top player's score and Win/Lose text are rotated 180 so they face that player
const UI_ROW_HEIGHT: float = 44.0             # Minimum height of menu buttons and option rows (finger friendly)
const SCORE_LABEL_SIZE: Vector2 = Vector2(120, 60)
const SCORE_MARGIN_X: float = 35.0            # Distance of the score from the screen edge
const SCORE_GAP_FROM_CENTER: float = 40.0     # Distance of the score from the center line

const PUCK_FRICTION: float = 0.1              # Surface grip. Spin only transfers on contact if this is above ~0 (it was 0.01 while spin was off)
const PUCK_ANGULAR_DAMP: float = 0.3          # How quickly spin dies out (higher = stops spinning sooner)

const MAX_PUCK_SPIN: float = 50.0             # Spin cap in radians/sec (about 4 turns per second)
const CORNER_ARC_SEGMENTS: int = 20   # More = smoother curve (and smoother bounces)

var corner_radius: float = 160.0       # Rounded table corners. 0 = square
var corner_colliders: Array[CollisionPolygon2D] = []
var corner_fills: Array[Polygon2D] = []
var corner_lines: Array[Line2D] = []


# --- SAVED OPTIONS ---
const CONFIG_PATH: String = "user://options.cfg"
const CONFIG_VERSION: int = 1             # Only bump if a future change can't be handled by the rules in load_options()
const GOAL_FRAC_MIN: float = 1.0 / 8.0    # Narrowest goal opening, as a fraction of screen width
const GOAL_FRAC_MAX: float = 2.0 / 3.0    # Widest goal opening
const GOAL_FRAC_STEP: float = 1.0 / 24.0  # Slider step (the default of 1/3 lands exactly on a notch)

# -- MALLET RIGIDBODY TWEAKS for SPINNIES
@export_category("Mallet & Handle Dimensions")


@export_category("Controls & Sensitivity")
@export var swipe_sensitivity: float = 1.00   # Mallet movement per pixel of finger movement (2 = finger moves half as far)


@export_category("Physics & Spin Stabilization")

const MALLET_MASS: float = 10.0   # Heavy, so the puck can't slow the mallet much when hit (puck is 0.5)



# Every option that is saved to the config file. TO ADD A NEW OPTION LATER:
#   1. add its variable above (its starting value is its default)
#   2. add a line here (min/max sanity-check values read from the file; leave them out for colors and bools)
#   3. add its control in setup_options_panel
# Saving, loading, validating and "Reset to Defaults" then pick it up automatically.
# Old config files keep working: an option missing from the file simply uses its default.
# If you ever RENAME an option, add "renamed_from": ["old_name"] to its line so saved values carry over.
const SAVED_OPTIONS: Array = [
	{"name": "puck_bounciness", "min": 0.1, "max": 1.0},
	{"name": "puck_max_speed", "min": 600.0, "max": 3500.0},
	{"name": "tracer_echoes", "min": 0, "max": 8},
	{"name": "tracer_interval", "min": 0.01, "max": 0.2},
	{"name": "tracer_hue_shift", "min": 0.0, "max": 0.3},
	{"name": "sfx_volume", "min": 0.0, "max": 1.0},
	{"name": "swipe_sensitivity", "min": 0.5, "max": 3.0},
	{"name": "score_limit", "min": 1, "max": 9},
	{"name": "mallet_radius", "min": 20.0, "max": 80.0},
	{"name": "puck_radius", "min": 10.0, "max": 50.0},
	{"name": "goal_frac_p1", "min": GOAL_FRAC_MIN, "max": GOAL_FRAC_MAX},
	{"name": "goal_frac_p2", "min": GOAL_FRAC_MIN, "max": GOAL_FRAC_MAX},
	{"name": "corner_radius", "min": 0.0, "max": 200.0},
	{"name": "color_table"},
	{"name": "color_lines"},
	{"name": "color_puck"},
	{"name": "color_p1"},
	{"name": "color_p2"},
	{"name": "serve_mode_loser_gets_it"},
	{"name": "fx_strength", "min": 0.0, "max": 1.0},
]

const MALLET_FX_IDLE: float = 0.3   # Ripple strength on a resting mallet during play (0 = only when moving)
const FX_FULL_SPEED: float = 2000.0   # Mallet speed (px/sec) that gives the strongest ripples
var fx_strength: float = 0.2        # Ripple effect brightness. 0 = off
var fx_rect: ColorRect
var fx_mat: ShaderMaterial
var fx_prev: Array = [Vector2.ZERO, Vector2.ZERO]   # last mallet positions, for measuring speed
var fx_vel: Array = [Vector2.ZERO, Vector2.ZERO]    # smoothed mallet velocities
var fx_energy: Array = [0.0, 0.0]                   # 0..1 fade in/out per mallet
const TOUCH_FX_LEVEL: float = 0.7   # ripple strength at a held finger (mallets run 0.3 to 1.0)
var fx_touch_pos: Array = [Vector2.ZERO, Vector2.ZERO]   # last finger positions, kept so the ripple fades out in place
var fx_touch_energy: Array = [0.0, 0.0]                  # 0..1 fade in/out per finger

const PUCK_FX_IDLE: float = 0.8   # Ripple strength on a slow puck during play (0 = only when it moves)
var fx_puck_prev: Vector2 = Vector2.ZERO
var fx_puck_pos: Vector2 = Vector2.ZERO   # last in-play position, so the ripple fades out in place
var fx_puck_vel: Vector2 = Vector2.ZERO
var fx_puck_energy: float = 0.0

var option_defaults: Dictionary = {}            # filled at startup from the variables' initial values
var option_refreshers: Array[Callable] = []     # one per option control; lets Reset move the controls back
var goal_walls: Array[CollisionShape2D] = []    # the 6 walls around the goals (4 end segments, 2 back walls)

var serve_distance_from_center: float = 160.0 # How far from the center line the puck is placed on a serve

# --- SOUND ---
const SFX_DIR: String = "res://sounds/"  # Put mallet_hit, wall_hit and goal (.wav, .ogg or .mp3) in this folder
const SFX_VOICES: int = 8                # How many sounds can play at the same time
const SFX_MIN_GAP_MSEC: int = 35         # The same sound can't retrigger faster than this (stops machine-gunning)

var sfx_volume: float = 1.0              # 0..1, set from the Options menu (controls the Master bus)
var sfx_mallet_hit: AudioStream
var sfx_wall_hit: AudioStream
var sfx_goal: AudioStream
var sfx_players: Array[AudioStreamPlayer] = []
var sfx_last_msec: Dictionary = {}       # per-sound timestamp of the last play, for the retrigger gap
const MALLET_WALL_MIN_SPEED: float = 150.0     # Slower than this makes no sound
const MALLET_WALL_FULL_SPEED: float = 1500.0   # Speed that gives full volume
var sfx_mallet_wall: AudioStream
var puck_prev_velocity: Vector2 = Vector2.ZERO   # puck velocity before the latest physics step, to measure how hard a hit was

# --- RUNTIME GAME STATE ---
var last_serve_to_p1: bool = true   # Which side the last serve went to, so Respawn Puck can repeat it
var btn_respawn: Button
var p1_score: int = 0
var p2_score: int = 0
var game_active: bool = false      # false while paused / in menus / game over
var game_in_progress: bool = false # true from "New Game" until game over or app close (drives the Return to Game button)
var puck_live: bool = false        # goals only count while true
var serve_token: int = 0           # bumps every serve/new game so stale countdowns cancel themselves

# Touch Handling States (-1 means no active finger tracking)
var p1_touch_index: int = -1
var p2_touch_index: int = -1



# References to dynamically created nodes
var ui_layer: CanvasLayer
var menu_container: CenterContainer
var btn_return: Button
var options_container: Control
var game_over_container: Control
var lbl_result_p1: Label # bottom player's WIN/LOSE text
var lbl_result_p2: Label # top player's WIN/LOSE text

var game_elements_container: Node2D
var top_net: ColorRect
var bot_net: ColorRect
var bg_rect: ColorRect
var court_lines: ReferenceRect
var center_line: ColorRect
var puck: RigidBody2D
var mallet1: RigidBody2D
var mallet2: RigidBody2D
var rig1: MalletRig
var rig2: MalletRig
var lbl_score1: Label
var lbl_score2: Label

var screen_height_half: float = 0.0
var goal_depth: float = 40.0

# Help screen
const README_PATH: String = "res://docs/readme.txt"   # BBCode text file (see example below)
var readme_container: Control
var readme_scroll: ScrollContainer
var readme_label: RichTextLabel
const LICENSE_PATH: String = "res://docs/license.txt"
var btn_readme_toggle: Button
var showing_license: bool = false

func _ready() -> void:
	get_window().content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	# EXPAND = the table stretches to fill tall/narrow phone screens instead of leaving black bars
	get_window().content_scale_aspect = Window.CONTENT_SCALE_ASPECT_EXPAND
	# The Android Back button pauses instead of instantly quitting the app (see _notification)
	get_tree().quit_on_go_back = false
	capture_option_defaults()
	load_options()
	RenderingServer.set_default_clear_color(Color.BLACK)
	setup_audio()
	screen_height_half = get_viewport_rect().size.y / 2.0
	
	setup_ui_layer()
	# Build the table right away so it shows behind the menus and option changes are visible
	build_board()
	get_viewport().size_changed.connect(_on_viewport_resized)
	show_main_menu()

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		handle_back_request()
	elif what == NOTIFICATION_APPLICATION_PAUSED:
		# App sent to background (incoming call, home button...) -> pause the match
		if game_active: pause_and_open_menu()
		if is_instance_valid(options_container) and options_container.visible: save_options()
	elif what == NOTIFICATION_WM_CLOSE_REQUEST:
		if is_instance_valid(options_container) and options_container.visible: save_options()

func handle_back_request() -> void:
	if game_active:
		pause_and_open_menu()
	elif game_over_container.visible:
		game_over_container.visible = false
		show_main_menu()
	elif readme_container.visible:
		hide_readme()
	elif options_container.visible:
		hide_options_menu()
	elif menu_container.visible and game_in_progress:
		resume_game()
	else:
		get_tree().quit()

# ==========================================
# 📱 MULTI-TOUCH & PC MOUSE SIMULATION SYSTEM
# ==========================================

func _input(event: InputEvent) -> void:
	# Ignore mouse events Godot fakes from touches - real touches are handled below
	if event is InputEventMouse and event.device == InputEvent.DEVICE_ID_EMULATION:
		return
	# On the phone, any mouse event is touch emulation: only real touches count
	if event is InputEventMouse and OS.has_feature("mobile"):
		return


	# MOUSE TESTING: left = Player 1, right = Player 2, middle = pause
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_MIDDLE and event.pressed and game_active:
			pause_and_open_menu()
			return
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed: try_grab(true, 999, event.position)
			elif p1_touch_index == 999: release_touch(true)
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			if event.pressed: try_grab(false, 888, event.position)
			elif p2_touch_index == 888: release_touch(false)

	elif event is InputEventMouseMotion:
		if p1_touch_index == 999: drag_rig(rig1, event.position, event.relative, true)
		if p2_touch_index == 888: drag_rig(rig2, event.position, event.relative, false)

	# MOBILE MULTI-TOUCH
	if event is InputEventScreenTouch:
		if event.pressed:
			if not game_active: return
			if event.index >= 2:
				pause_and_open_menu()
				return
			try_grab(event.position.y > screen_height_half, event.index, event.position)
		else:
			if event.index == p1_touch_index: release_touch(true)
			elif event.index == p2_touch_index: release_touch(false)

	elif event is InputEventScreenDrag:
		if event.index == p1_touch_index: drag_rig(rig1, event.position, event.relative, true)
		elif event.index == p2_touch_index: drag_rig(rig2, event.position, event.relative, false)

# A touch anywhere on a player's half grabs that player's mallet
func try_grab(is_p1: bool, index: int, pos: Vector2) -> void:
	if not game_active: return
	var rig: MalletRig = rig1 if is_p1 else rig2
	if rig == null or not is_instance_valid(rig.mallet): return
	if (p1_touch_index if is_p1 else p2_touch_index) != -1: return
	if is_p1: p1_touch_index = index
	else: p2_touch_index = index
	rig.gripped = true
	rig.touch_pos = pos
	rig.target = rig.mallet.global_position   # starts where the mallet already is: no jump
	rig.mallet.freeze = false
	rig.mallet.linear_damp = 0.0
	rig.last_pos = rig.mallet.global_position
	rig.flick_vel = Vector2.ZERO

# The mallet's goal moves by the finger's movement times the sensitivity.
# Clamping the goal itself (not the finger) means there's no "lost travel" after hitting a wall.
func drag_rig(rig: MalletRig, pos: Vector2, relative: Vector2, is_p1: bool) -> void:
	if rig == null or not rig.gripped: return
	rig.touch_pos = pos
	rig.target = bound_mallet_position(rig.target + relative * swipe_sensitivity, is_p1)

func release_touch(is_p1: bool) -> void:
	if is_p1:
		p1_touch_index = -1
		release_handle(rig1)
	else:
		p2_touch_index = -1
		release_handle(rig2)

# Finger lifted: the mallet keeps sliding at the speed of the swipe
func release_handle(rig: MalletRig) -> void:
	if rig == null: return
	rig.gripped = false
	if not is_instance_valid(rig.mallet): return
	var v: Vector2 = rig.flick_vel.limit_length(MAX_SLIDE_SPEED)
	if v.length() < SLIDE_REST_SPEED * 2.0:
		stop_rig(rig)
		return
	rig.mallet.linear_damp = SLIDE_DAMP
	rig.mallet.linear_velocity = v

# Hard stop and go solid (pause, game over, new board)
func stop_rig(rig: MalletRig) -> void:
	if rig == null: return
	rig.gripped = false
	if is_instance_valid(rig.mallet):
		rig.mallet.linear_velocity = Vector2.ZERO
		rig.mallet.angular_velocity = 0.0
		rig.mallet.freeze = true

# Strict Court Constraining Rule: keeps mallets on their half and completely out of the goal boxes
func bound_mallet_position(pos: Vector2, is_p1: bool) -> Vector2:
	var screen_size = get_viewport_rect().size
	pos.x = clamp(pos.x, mallet_radius, screen_size.x - mallet_radius)
	if is_p1:
		pos.y = clamp(pos.y, screen_height_half + mallet_radius + 5, screen_size.y - goal_depth - mallet_radius)
	else:
		pos.y = clamp(pos.y, goal_depth + mallet_radius, screen_height_half - mallet_radius - 5)
	return bound_to_corners(pos, is_p1)


func _physics_process(delta: float) -> void:
	if not game_active: return
	drive_rig(rig1, true, delta)
	drive_rig(rig2, false, delta)
	limit_puck_speed()
	contain_puck()
	check_goal_scoring_conditions()
	if is_instance_valid(puck): puck_prev_velocity = puck.linear_velocity

func drive_rig(rig: MalletRig, is_p1: bool, delta: float) -> void:
	if rig == null or not is_instance_valid(rig.mallet): return
	var m: RigidBody2D = rig.mallet

	# Velocity is recomputed every physics frame from the distance to the goal, so the mallet
	# stops the moment it arrives instead of sliding on the last velocity it was given.
	if rig.gripped:
		m.linear_velocity = ((rig.target - m.global_position) / delta).limit_length(MAX_MALLET_SPEED)
		var instant: Vector2 = (m.global_position - rig.last_pos) / delta
		rig.flick_vel = rig.flick_vel.lerp(instant, 1.0 - exp(-delta * FLICK_SMOOTHING))
		rig.last_pos = m.global_position
	elif not m.freeze and m.linear_velocity.length() < SLIDE_REST_SPEED:
		stop_rig(rig)   # slide has run out: solid obstacle again

# Last-resort safety net (the barriers should make this almost never fire)
	var inside: Vector2 = bound_mallet_position(m.global_position, is_p1)
	var off: Vector2 = inside - m.global_position   # points back toward the court
	if off.length() > 4.0:
		m.global_position = inside
		if rig.gripped:
			m.linear_velocity = Vector2.ZERO
		else:
			# Sliding: bounce the part of the velocity that was heading out through the wall
			var n: Vector2 = off.normalized()
			var into: float = m.linear_velocity.dot(n)
			if into < 0.0:
				m.linear_velocity -= (1.0 + minf(SLIDE_BOUNCE, 1.0)) * into * n
	rig.prev_speed = m.linear_velocity.length()



func limit_puck_speed() -> void:
	if not is_instance_valid(puck) or not puck_live: return
	if puck.linear_velocity.length() > puck_max_speed:
		puck.linear_velocity = puck.linear_velocity.limit_length(puck_max_speed)
	puck.angular_velocity = clampf(puck.angular_velocity, -MAX_PUCK_SPIN, MAX_PUCK_SPIN)


# ==========================================
# 🥅 VISUAL RECESSED GOALS & SCORE DETECTION
# ==========================================
func check_goal_scoring_conditions() -> void:
	if not puck_live or not is_instance_valid(puck) or not game_active: return
	var screen_size = get_viewport_rect().size
	var p_pos = puck.global_position
	
	# Distance from the table's center line; each goal has its own opening width
	var dx: float = absf(p_pos.x - screen_size.x / 2.0)
	
	if dx < maxf(goal_width_of(true), goal_width_of(false)) / 2.0:
		# TOP NET: Player 1 (bottom) scored, so Player 2 (top) is the loser
		if p_pos.y <= goal_depth and dx < goal_width_of(false) / 2.0:
			p1_score += 1
			update_score_labels()
			flash_goal(top_net, color_p1)
			play_sfx("goal", sfx_goal)
			if p1_score >= score_limit:
				end_game(true)
			else:
				reset_puck_serve(not serve_mode_loser_gets_it)
			return
		# BOTTOM NET: Player 2 (top) scored, so Player 1 is the loser
		elif p_pos.y >= (screen_size.y - goal_depth) and dx < goal_width_of(true) / 2.0:
			p2_score += 1
			update_score_labels()
			flash_goal(bot_net, color_p2)
			play_sfx("goal", sfx_goal)
			if p2_score >= score_limit:
				end_game(false)
			else:
				reset_puck_serve(serve_mode_loser_gets_it)
			return

	# Safety net: puck somehow left the table
	var edge: float = puck_radius * 0.01
	if p_pos.y < edge or p_pos.y > screen_size.y - edge or p_pos.x < edge or p_pos.x > screen_size.x - edge:
		reset_puck_serve(randf() > 0.5, "Puck escaped!! -- Replacing..")

# Each player sees "their score / opponent's score", e.g. 0/4 when losing by 4, 4/0 when winning by 4
func update_score_labels() -> void:
	if is_instance_valid(lbl_score1): lbl_score1.text = "%d/%d" % [p1_score, p2_score]
	if is_instance_valid(lbl_score2): lbl_score2.text = "%d/%d" % [p2_score, p1_score]



# Goals and corners now blend into the table; the rink lines show where things are
func get_goal_color() -> Color:
	return Color(color_table.r, color_table.g, color_table.b, 1.0)

# Pulses the net that was scored on in the scoring mallet's color
func flash_goal(net: ColorRect, flash_color: Color) -> void:
	if not is_instance_valid(net): return
	var tw := net.create_tween() # bound to the net, so it dies safely if a new game replaces it
	for i in range(3):
		tw.tween_property(net, "color", flash_color, 0.08)
		tw.tween_property(net, "color", get_goal_color(), 0.22)

# Shows (or clears, with "") the notice text for both players
func show_notice(text: String) -> void:
	for node_name in ["NoticeTop", "NoticeBottom"]:
		var lbl := game_elements_container.get_node_or_null(node_name) as Label
		if lbl:
			lbl.text = text
			lbl.visible = text != ""

func reset_puck_serve(serve_to_p1: bool, notice: String = "") -> void:
	last_serve_to_p1 = serve_to_p1
	if not is_instance_valid(puck): return
	
	# Block further goal checks immediately and cancel any older countdown
	puck_live = false
	serve_token += 1
	var my_token := serve_token
	show_notice(notice)
	
	var screen_size = get_viewport_rect().size
	var offset := serve_distance_from_center
	var spawn_pos = Vector2(screen_size.x / 2.0, screen_height_half + (offset if serve_to_p1 else -offset))
	
	# Freeze, move (via the node, so its position really updates), hide, and disable collisions
	puck.freeze = true
	puck.linear_velocity = Vector2.ZERO
	puck.angular_velocity = 0.0
	puck.global_position = spawn_pos
	puck.rotation = 0.0 # triangle starts pointing up
	puck.visible = false
	puck.collision_layer = 0
	puck.collision_mask = 0
	
	var cd_label = game_elements_container.get_node_or_null("CountdownLabel") as Label
	if cd_label:
		cd_label.position = spawn_pos - cd_label.pivot_offset
		cd_label.visible = true
		for count in range(3, 0, -1):
			cd_label.text = ["", "I", "II", "III"][count]
			await get_tree().create_timer(COUNTDOWN_STEP).timeout
			if my_token != serve_token: return  # a newer serve, game over, or new game took over
		cd_label.visible = false
	
	show_notice("")
	
	if not is_instance_valid(puck): return
	
	# If a mallet is sitting on the spawn spot, place the puck right beside it instead
	puck.global_position = find_clear_spawn(spawn_pos)
	puck.visible = true
	puck.collision_layer = 1
	puck.collision_mask = 1
	puck.sleeping = false
	puck_live = true
	if game_active:
		puck.freeze = false  # if paused, resume_game releases it

# Pushes the spawn point out of any mallet it overlaps (along the line from the mallet's center)
func find_clear_spawn(spawn_pos: Vector2) -> Vector2:
	var screen_size = get_viewport_rect().size
	var min_dist: float = mallet_radius + puck_radius + 6.0
	
	for _pass in range(3):
		var moved := false
		for m in [mallet1, mallet2]:
			if not is_instance_valid(m): continue
			var offset: Vector2 = spawn_pos - m.global_position
			if offset.length() < min_dist:
				var dir: Vector2 = offset.normalized() if offset.length() > 0.01 else Vector2.RIGHT
				spawn_pos = m.global_position + dir * min_dist
				moved = true
		# Keep the puck inside the court
		spawn_pos.x = clampf(spawn_pos.x, puck_radius, screen_size.x - puck_radius)
		spawn_pos.y = clampf(spawn_pos.y, goal_depth + puck_radius, screen_size.y - goal_depth - puck_radius)
		if not moved: break
	return spawn_pos

# ==========================================
# 🏆 GAME OVER
# ==========================================
func end_game(p1_won: bool) -> void:
	puck_live = false
	serve_token += 1 # cancels any countdown still running
	show_notice("")
	game_active = false
	game_in_progress = false # nothing to return to once the match is over
	p1_touch_index = -1
	p2_touch_index = -1
	stop_rig(rig1)
	stop_rig(rig2)

	if is_instance_valid(puck):
		puck.freeze = true
		puck.visible = false
	show_game_over(p1_won)

func show_game_over(p1_won: bool) -> void:
	var loser_color := Color(0.65, 0.65, 0.65)
	# P1 is the bottom half, P2 is the top half
	place_result_label(lbl_result_p1, "YOU WIN" if p1_won else "YOU LOSE", color_p1 if p1_won else loser_color, false)
	place_result_label(lbl_result_p2, "YOU LOSE" if p1_won else "YOU WIN", loser_color if p1_won else color_p2, true)
	game_over_container.visible = true
	menu_container.visible = false
	options_container.visible = false

func place_result_label(lbl: Label, text: String, color: Color, is_top_player: bool) -> void:
	var screen_size = get_viewport_rect().size
	var half: float = screen_size.y / 2.0
	lbl.text = text
	lbl.add_theme_color_override("font_color", color)
	# The label fills that player's half of the screen and centers its text in it
	lbl.size = Vector2(screen_size.x, half)
	lbl.position = Vector2(0.0, 0.0 if is_top_player else half)
	lbl.pivot_offset = lbl.size / 2.0
	lbl.rotation_degrees = 180.0 if (is_top_player and FLIP_TOP_PLAYER_TEXT) else 0.0


# ==========================================
# 🕹️ MATCH GAME GENERATION
# ==========================================
func start_new_game() -> void:
	game_over_container.visible = false
	build_board() # fresh table, scores at 0
	game_active = true
	game_in_progress = true
	menu_container.visible = false
	# Short pause so the physics bodies are registered before the first serve
	await get_tree().physics_frame
	reset_puck_serve(randf() > 0.5)

func _on_viewport_resized() -> void:
	# Re-fit the table if the window size changes while no match is running (e.g. the first frames on a phone)
	if game_in_progress: return
	build_board()

# Builds the whole table (visuals, walls, puck, mallets) with scores reset and no puck in play.
# Called once at startup so the table shows behind the menus, and again for every New Game.
func build_board() -> void:
	puck_live = false
	serve_token += 1
	screen_height_half = get_viewport_rect().size.y / 2.0 # recalculated in case the window changed size
	stop_rig(rig1)
	stop_rig(rig2)
	if is_instance_valid(game_elements_container):
		game_elements_container.queue_free()
	
	p1_score = 0
	p2_score = 0
	p1_touch_index = -1
	p2_touch_index = -1
	
	game_elements_container = Node2D.new()
	add_child(game_elements_container)
	
	var screen_size = get_viewport_rect().size
	
	bg_rect = ColorRect.new()
	bg_rect.size = screen_size
	bg_rect.color = color_table
	game_elements_container.add_child(bg_rect)
	
	# Draw Recessed Goals BEHIND the baseline boundaries
	top_net = ColorRect.new()
	top_net.size = Vector2(goal_width_of(false), goal_depth)
	top_net.position = Vector2((screen_size.x - goal_width_of(false))/2.0, 0)
	top_net.color = get_goal_color()
	game_elements_container.add_child(top_net)
	
	bot_net = ColorRect.new()
	bot_net.size = Vector2(goal_width_of(true), goal_depth)
	bot_net.position = Vector2((screen_size.x - goal_width_of(true))/2.0, screen_size.y - goal_depth)
	bot_net.color = get_goal_color()
	game_elements_container.add_child(bot_net)
	
	# Outline each goal in the rink-line color so the opening stays visible
	for net in [top_net, bot_net]:
		var box := ReferenceRect.new()
		box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		box.border_color = color_lines
		box.border_width = 4.0
		box.editor_only = false
		net.add_child(box)
	
	# Main Playable Court Frame lines configuration
	court_lines = ReferenceRect.new()
	court_lines.size = Vector2(screen_size.x, screen_size.y - (goal_depth * 2))
	court_lines.position = Vector2(0, goal_depth)
	court_lines.border_color = color_lines
	court_lines.border_width = 4.0
	court_lines.editor_only = false
	game_elements_container.add_child(court_lines)

	# Center divider line
	center_line = ColorRect.new()
	center_line.size = Vector2(screen_size.x, 4)
	center_line.position = Vector2(0, screen_height_half - 2)
	center_line.color = color_lines
	game_elements_container.add_child(center_line)
	
	build_fx_layer(screen_size)

	# Scores: one per player, in the same spot relative to each player (point-mirrored through the table center)
	lbl_score1 = make_score_label(screen_size, false)
	game_elements_container.add_child(lbl_score1)
	lbl_score2 = make_score_label(screen_size, true)
	game_elements_container.add_child(lbl_score2)
	update_score_labels()
	
	# Dynamic Sideways Countdown Text Label Layer
	var lbl_countdown = Label.new()
	lbl_countdown.name = "CountdownLabel"
	lbl_countdown.text = ""
	lbl_countdown.add_theme_font_size_override("font_size", 72)
	lbl_countdown.add_theme_color_override("font_color", color_lines)
	lbl_countdown.custom_minimum_size = Vector2(100, 100)
	lbl_countdown.size = Vector2(100, 100)
	lbl_countdown.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_countdown.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl_countdown.pivot_offset = Vector2(50, 50)
	lbl_countdown.rotation_degrees = 0.0 # Din't Rotate sideways for optimal dual thumb players layout
	lbl_countdown.visible = false
	game_elements_container.add_child(lbl_countdown)
		# Notice text (e.g. "Puck flew off the table"), one facing each player, hidden until needed
	for is_top in [false, true]:
		var lbl_notice := Label.new()
		lbl_notice.name = "NoticeTop" if is_top else "NoticeBottom"
		lbl_notice.add_theme_font_size_override("font_size", 26)
		lbl_notice.add_theme_color_override("font_color", color_lines)
		lbl_notice.size = Vector2(screen_size.x, 50)
		lbl_notice.pivot_offset = lbl_notice.size / 2.0
		lbl_notice.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl_notice.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		if is_top:
			lbl_notice.position = Vector2(0, screen_height_half - 240.0 - 50.0)
			lbl_notice.rotation_degrees = 180.0 if FLIP_TOP_PLAYER_TEXT else 0.0
		else:
			lbl_notice.position = Vector2(0, screen_height_half + 240.0)
		lbl_notice.visible = false
		game_elements_container.add_child(lbl_notice)

	
	instantiate_physics_world(screen_size)
	
	fx_vel = [Vector2.ZERO, Vector2.ZERO]
	fx_energy = [0.0, 0.0]
	fx_touch_energy = [0.0, 0.0]
	fx_prev = [mallet1.global_position, mallet2.global_position]
	fx_puck_vel = Vector2.ZERO
	fx_puck_energy = 0.0
	fx_puck_prev = puck.global_position
	fx_puck_pos = puck.global_position
	# Resting table until a match starts: no puck in play
	puck.visible = false
	puck.freeze = true
	puck.collision_layer = 0
	puck.collision_mask = 0

func make_score_label(screen_size: Vector2, is_top_player: bool) -> Label:
	var lbl = Label.new()
	lbl.text = "0/0"
	lbl.add_theme_font_size_override("font_size", 42)
	lbl.size = SCORE_LABEL_SIZE
	lbl.pivot_offset = SCORE_LABEL_SIZE / 2.0
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	if is_top_player:
		# Exact 180 degree mirror of the bottom player's spot, text rotated to face them
		lbl.position = Vector2(
			screen_size.x - SCORE_MARGIN_X - SCORE_LABEL_SIZE.x,
			screen_height_half - SCORE_GAP_FROM_CENTER - SCORE_LABEL_SIZE.y)
		lbl.rotation_degrees = 180.0 if FLIP_TOP_PLAYER_TEXT else 0.0
	else:
		lbl.position = Vector2(SCORE_MARGIN_X, screen_height_half + SCORE_GAP_FROM_CENTER)
	return lbl

func add_wall(body: StaticBody2D, center: Vector2, wall_size: Vector2) -> CollisionShape2D:
	var shape_node = CollisionShape2D.new()
	var rect = RectangleShape2D.new()
	rect.size = wall_size
	shape_node.shape = rect
	shape_node.position = center
	body.add_child(shape_node)
	return shape_node

# Width in pixels of a player's goal opening. Player 1 defends the bottom net, Player 2 the top net.
func goal_width_of(is_p1: bool) -> float:
	return get_viewport_rect().size.x * (goal_frac_p1 if is_p1 else goal_frac_p2)

# Sizes and positions both nets and the walls around them from the current goal widths.
# Used when the table is built AND whenever a goal width option changes.
func layout_goals() -> void:
	if not is_instance_valid(top_net) or not is_instance_valid(bot_net): return
	var screen_size := get_viewport_rect().size
	var w_top: float = goal_width_of(false) # Player 2's goal
	var w_bot: float = goal_width_of(true)  # Player 1's goal
	
	top_net.size = Vector2(w_top, goal_depth)
	top_net.position = Vector2((screen_size.x - w_top) / 2.0, 0)
	bot_net.size = Vector2(w_bot, goal_depth)
	bot_net.position = Vector2((screen_size.x - w_bot) / 2.0, screen_size.y - goal_depth)
	
	if goal_walls.size() < 6: return
	var t := WALL_THICKNESS
	var side_top: float = (screen_size.x - w_top) / 2.0 # end-wall segment width beside the top goal
	var side_bot: float = (screen_size.x - w_bot) / 2.0 # end-wall segment width beside the bottom goal
	place_wall(goal_walls[0], Vector2(side_top / 2.0, goal_depth - t / 2.0), Vector2(side_top, t))
	place_wall(goal_walls[1], Vector2(screen_size.x - side_top / 2.0, goal_depth - t / 2.0), Vector2(side_top, t))
	place_wall(goal_walls[2], Vector2(side_bot / 2.0, screen_size.y - goal_depth + t / 2.0), Vector2(side_bot, t))
	place_wall(goal_walls[3], Vector2(screen_size.x - side_bot / 2.0, screen_size.y - goal_depth + t / 2.0), Vector2(side_bot, t))
	place_wall(goal_walls[4], Vector2(screen_size.x / 2.0, -t / 2.0), Vector2(w_top, t))
	place_wall(goal_walls[5], Vector2(screen_size.x / 2.0, screen_size.y + t / 2.0), Vector2(w_bot, t))
	layout_corners()
# Creates the four corner pieces: a collision shape, a black fill and a rink line each.
# The fills and lines are added here, before the puck and mallets, so those draw on top.
func create_corners(borders: StaticBody2D) -> void:
	corner_colliders.clear()
	corner_fills.clear()
	corner_lines.clear()
	for i in range(4):
		var col := CollisionPolygon2D.new()
		borders.add_child(col)
		corner_colliders.append(col)
		
		var fill := Polygon2D.new()
		fill.color = get_goal_color()
		game_elements_container.add_child(fill)
		# Draw under the ripple layer, like the rest of the board
		game_elements_container.move_child(fill, fx_rect.get_index())
		corner_fills.append(fill)
		
		var line := Line2D.new()
		line.width = 4.0
		line.antialiased = true
		line.joint_mode = Line2D.LINE_JOINT_ROUND
		game_elements_container.add_child(line)
		game_elements_container.move_child(line, fx_rect.get_index())
		corner_lines.append(line)

# Sizes the corner pieces. Called from layout_goals(), so it also runs whenever an option changes.
func layout_corners() -> void:
	if corner_colliders.size() < 4: return
	var s := get_viewport_rect().size
	# A curve can't be wider than the flat wall beside a goal, or it would cut into the goal opening
	var r_top: float = minf(corner_radius, (s.x - goal_width_of(false)) / 2.0)
	var r_bot: float = minf(corner_radius, (s.x - goal_width_of(true)) / 2.0)
	# Each corner: where the square corner is, which way is "into the table" in x and y, and its radius
	var specs := [
		[Vector2(0.0, goal_depth), 1.0, 1.0, r_top],
		[Vector2(s.x, goal_depth), -1.0, 1.0, r_top],
		[Vector2(0.0, s.y - goal_depth), 1.0, -1.0, r_bot],
		[Vector2(s.x, s.y - goal_depth), -1.0, -1.0, r_bot]]
	
	for i in range(4):
		var o: Vector2 = specs[i][0]
		var sx: float = specs[i][1]
		var sy: float = specs[i][2]
		var r: float = specs[i][3]
		var on: bool = r >= 6.0
		corner_colliders[i].disabled = not on
		corner_fills[i].visible = on
		corner_lines[i].visible = on
		if not on: continue
		
		# The filler is the square corner minus a quarter circle: the corner point, then the arc
		var fill_pts := PackedVector2Array([o])
		var line_pts := PackedVector2Array()
		var c: Vector2 = o + Vector2(sx * r, sy * r)   # the arc's center
		for k in range(CORNER_ARC_SEGMENTS + 1):
			var a: float = deg_to_rad(90.0 - 90.0 * float(k) / float(CORNER_ARC_SEGMENTS))
			fill_pts.append(c + Vector2(-sx * r * cos(a), -sy * r * sin(a)))
			# The rink line runs 2px inside the edge, like the straight border does
			line_pts.append(c + Vector2(-sx * (r - 2.0) * cos(a), -sy * (r - 2.0) * sin(a)))
		corner_colliders[i].polygon = fill_pts
		corner_fills[i].polygon = fill_pts
		corner_lines[i].points = line_pts
		corner_fills[i].color = get_goal_color()


func place_wall(wall: CollisionShape2D, center: Vector2, wall_size: Vector2) -> void:
	if not is_instance_valid(wall): return
	var rect := wall.shape as RectangleShape2D
	if not rect.size.is_equal_approx(wall_size): rect.size = wall_size
	if not wall.position.is_equal_approx(center): wall.position = center

# Tracer is added to the scene BEFORE its target, so the echoes draw behind it
func add_tracer(target: Node2D, radius: float, color: Color) -> Node2D:
	var tracer = TracerDrawer.new(target, radius, color, tracer_echoes, tracer_interval, tracer_hue_shift)
	game_elements_container.add_child(tracer)
	return tracer

func instantiate_physics_world(screen_size: Vector2) -> void:
	var borders = StaticBody2D.new()
	game_elements_container.add_child(borders)
	
	# All walls keep their INNER face exactly where it always was, but are now very thick
	# and extend outward. A thin wall could be squeezed through or tunneled by a fast puck.
	var t := WALL_THICKNESS
	# The six walls around the two goals (4 end segments + 2 back walls). They're created here and
	# sized/positioned by layout_goals(), so the goal width options can resize them live.
	goal_walls.clear()
	for i in range(6):
		goal_walls.append(add_wall(borders, Vector2.ZERO, Vector2(10, 10)))

	# Full height side bumper walls (taller than the screen so corners are sealed)
	var side_h: float = screen_size.y + t * 2.0
	add_wall(borders, Vector2(-t / 2.0, screen_size.y / 2.0), Vector2(t, side_h))
	add_wall(borders, Vector2(screen_size.x + t / 2.0, screen_size.y / 2.0), Vector2(t, side_h))
	create_corners(borders)
	layout_goals()


	# PUCK RIGIDBODY OBJECT CONFIGURATION
	puck = RigidBody2D.new()
	puck.mass = 0.5
	puck.lock_rotation = false  # spin is ON (the triangle marker makes it visible)
	puck.angular_damp_mode = RigidBody2D.DAMP_MODE_REPLACE
	puck.angular_damp = PUCK_ANGULAR_DAMP
	puck.linear_damp = 0.2  # Adds a touch of natural air resistance slowdown

	puck.gravity_scale = 0.0
	puck.continuous_cd = RigidBody2D.CCD_MODE_CAST_SHAPE
	# Needed so the puck reports what it touches (drives the click sounds)
	puck.contact_monitor = true
	puck.max_contacts_reported = 4
	puck.body_entered.connect(_on_puck_body_entered)
	
	var mat = PhysicsMaterial.new()
	mat.friction = PUCK_FRICTION 
	mat.bounce = puck_bounciness
	puck.physics_material_override = mat
	
	var puck_shape = CollisionShape2D.new()
	var circle = CircleShape2D.new()
	circle.radius = puck_radius
	puck_shape.shape = circle
	puck.add_child(puck_shape)
	
	var puck_mesh = PuckDrawer.new(puck_radius, color_puck)
	puck.add_child(puck_mesh)
	puck.set_meta("shape", circle)
	puck.set_meta("mesh", puck_mesh)

	puck.set_meta("tracer", add_tracer(puck, puck_radius, color_puck))
	game_elements_container.add_child(puck)
	
	# MALLETS CONFIGURATION
	create_keepouts(screen_size)
	rig1 = create_mallet(color_p1, Vector2(screen_size.x / 2, screen_size.y - 200), true)
	rig2 = create_mallet(color_p2, Vector2(screen_size.x / 2, 200), false)
	mallet1 = rig1.mallet
	mallet2 = rig2.mallet
	

func create_mallet(element_color: Color, start_pos: Vector2, is_p1: bool) -> MalletRig:
	var rig := MalletRig.new()

	var body := RigidBody2D.new()
	body.position = start_pos
	body.mass = MALLET_MASS
	body.gravity_scale = 0.0
	body.can_sleep = false
	body.lock_rotation = true      # slides only, never spins
	body.freeze = true             # solid obstacle until a finger grabs it
	body.linear_damp_mode = RigidBody2D.DAMP_MODE_REPLACE
	body.linear_damp = 0.0
	var mallet_mat := PhysicsMaterial.new()
	mallet_mat.friction = 0.0
	mallet_mat.bounce = SLIDE_BOUNCE
	body.physics_material_override = mallet_mat
	body.continuous_cd = RigidBody2D.CCD_MODE_CAST_SHAPE
	# Needed so the mallet reports what it touches (drives the wall thud)
	body.contact_monitor = true
	body.max_contacts_reported = 4
	body.body_entered.connect(_on_mallet_body_entered.bind(rig))
	# Layer 1 = puck, walls, mallets. Layers 2 / 4 = keep-out barriers for Player 1 / Player 2 only.
	body.collision_layer = 1
	body.collision_mask = 1 | (2 if is_p1 else 4)

	var col_shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = mallet_radius
	col_shape.shape = circle
	body.add_child(col_shape)

	var mallet_mesh := MalletDrawer.new(mallet_radius, element_color)
	body.add_child(mallet_mesh)
	body.set_meta("shape", circle)
	body.set_meta("mesh", mallet_mesh)
	game_elements_container.add_child(body)

	rig.mallet = body
	return rig

# Mallet touched something: only walls and barriers (StaticBody2D) make this sound.
# The puck and the other mallet are RigidBody2Ds, so they're ignored here.
func _on_mallet_body_entered(body: Node, rig: MalletRig) -> void:
	if not game_active: return
	if not (body is StaticBody2D): return
	var speed: float = rig.prev_speed   # speed going INTO the step, before the bounce changed it
	if speed < MALLET_WALL_MIN_SPEED: return
	var loudness: float = lerpf(0.25, 1.0, clampf(speed / MALLET_WALL_FULL_SPEED, 0.0, 1.0))
	# One retrigger timer per mallet, so both players can hit at the same moment
	play_sfx("mallet_wall_%d" % rig.get_instance_id(), sfx_mallet_wall, loudness, randf_range(0.95, 1.05))

func create_keepouts(s: Vector2) -> void:
	var t := WALL_THICKNESS
	var half: float = s.y / 2.0
	var w: float = s.x + t * 2.0
	var cx: float = s.x / 2.0

	# Player 1 (bottom): can't cross the center line (5px gap) or enter the bottom goal
	var keep_p1 := StaticBody2D.new()
	keep_p1.collision_layer = 2
	keep_p1.collision_mask = 0
	game_elements_container.add_child(keep_p1)
	add_wall(keep_p1, Vector2(cx, half + 5.0 - t / 2.0), Vector2(w, t))
	add_wall(keep_p1, Vector2(cx, s.y - goal_depth + t / 2.0), Vector2(w, t))

	# Player 2 (top): mirrored
	var keep_p2 := StaticBody2D.new()
	keep_p2.collision_layer = 4
	keep_p2.collision_mask = 0
	game_elements_container.add_child(keep_p2)
	add_wall(keep_p2, Vector2(cx, half - 5.0 + t / 2.0), Vector2(w, t))
	add_wall(keep_p2, Vector2(cx, goal_depth - t / 2.0), Vector2(w, t))

# ==========================================
# 🖥️ CORE MENU GUI MANAGEMENT LAYOUTS
# ==========================================
func setup_ui_layer() -> void:
	ui_layer = CanvasLayer.new()
	add_child(ui_layer)
	
	menu_container = CenterContainer.new()
	menu_container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui_layer.add_child(menu_container)

	var panel = PanelContainer.new()
	panel.custom_minimum_size = Vector2(400, 450)
	menu_container.add_child(panel)
	
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 20)
	panel.add_child(vbox)
	
	var title = Label.new()
	title.text = "CHAIR HOCKEY"
	title.add_theme_font_size_override("font_size", 38)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)
	
	btn_return = Button.new()
	btn_return.text = "Return to Game"
	btn_return.custom_minimum_size.y = UI_ROW_HEIGHT
	btn_return.visible = false
	btn_return.pressed.connect(self.resume_game)
	vbox.add_child(btn_return)
	
	btn_respawn = Button.new()
	btn_respawn.text = "Respawn Puck"
	btn_respawn.custom_minimum_size.y = UI_ROW_HEIGHT
	btn_respawn.visible = false
	btn_respawn.pressed.connect(self.respawn_puck)
	vbox.add_child(btn_respawn)
	
	var btn_new = Button.new()
	btn_new.text = "New Game"
	btn_new.custom_minimum_size.y = UI_ROW_HEIGHT
	btn_new.pressed.connect(self.start_new_game)
	vbox.add_child(btn_new)
	
	var btn_opt = Button.new()
	btn_opt.text = "Options"
	btn_opt.custom_minimum_size.y = UI_ROW_HEIGHT
	btn_opt.pressed.connect(self.show_options_menu)
	vbox.add_child(btn_opt)
	
	var btn_help = Button.new()
	btn_help.text = "Read Me"
	btn_help.custom_minimum_size.y = UI_ROW_HEIGHT
	btn_help.pressed.connect(self.show_readme)
	vbox.add_child(btn_help)
	
	var btn_exit = Button.new()
	btn_exit.text = "Exit Game"
	btn_exit.custom_minimum_size.y = UI_ROW_HEIGHT
	btn_exit.pressed.connect(func(): get_tree().quit())
	vbox.add_child(btn_exit)
	
	setup_options_panel()
	setup_readme_panel()
	setup_game_over_panel()

func setup_options_panel() -> void:
	var vw: float = get_viewport_rect().size.x
	
	# Full-screen holder (with a dark backdrop) -> margin -> column:
	# title + back button stay pinned at the top, the options scroll underneath.
	options_container = Control.new()
	options_container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	options_container.visible = false
	ui_layer.add_child(options_container)
	
	var backdrop = ColorRect.new()
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.color = Color(0.05, 0.06, 0.08, 0.55) # see-through, so option changes are visible on the table
	options_container.add_child(backdrop)
	
	var margin = MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		margin.add_theme_constant_override(side, 30)
	options_container.add_child(margin)
	
	var column = VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	margin.add_child(column)
	
	var title = Label.new()
	title.text = "OPTIONS"
	title.add_theme_font_size_override("font_size", 28)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(title)
	
	var btn_back = Button.new()
	btn_back.text = "< Save & Back"
	btn_back.custom_minimum_size = Vector2(280, UI_ROW_HEIGHT)
	btn_back.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	btn_back.pressed.connect(self.hide_options_menu)
	column.add_child(btn_back)
	
	# Scrolls vertically if there are more options than fit on screen
	var scroll = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(scroll)
	
	# CenterContainer keeps the option column horizontally centered (and vertically too when it's short)
	var center = CenterContainer.new()
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.add_child(center)
	
	var vbox = VBoxContainer.new()
	vbox.custom_minimum_size.x = minf(560.0, vw - 80.0)
	vbox.add_theme_constant_override("separation", 12)
	center.add_child(vbox)
	
	# Every option here applies instantly (even to a game in progress) and is saved when you leave this menu.
	# The second argument must match a variable listed in SAVED_OPTIONS.

	create_slider_option(vbox, "Sound Volume", "sfx_volume", 0.0, 1.0, 0.05, set_sfx_volume)
	create_slider_option(vbox, "Score Limit", "score_limit", 1, 9, 1)
	create_slider_option(vbox, "Mallet Radius", "mallet_radius", 20, 80, 5)
	create_slider_option(vbox, "Puck Radius", "puck_radius", 10, 50, 2)
	create_slider_option(vbox, "Swipe Sensitivity", "swipe_sensitivity", 0.5, 3.0, 0.05)
	# Goal widths are fractions of the screen width (shown as %). P1 defends the bottom net, P2 the top.
	create_slider_option(vbox, "P1 Goal Width", "goal_frac_p1", GOAL_FRAC_MIN, GOAL_FRAC_MAX, GOAL_FRAC_STEP, Callable(), true)
	create_slider_option(vbox, "P2 Goal Width", "goal_frac_p2", GOAL_FRAC_MIN, GOAL_FRAC_MAX, GOAL_FRAC_STEP, Callable(), true)
	create_slider_option(vbox, "Corner Radius", "corner_radius", 0, 200, 10)
	create_color_option(vbox, "Table Color", "color_table")
	create_color_option(vbox, "Rink Line Color", "color_lines")
	create_color_option(vbox, "Puck Color", "color_puck")
	create_color_option(vbox, "Player 1 Color", "color_p1")
	create_color_option(vbox, "Player 2 Color", "color_p2")
	create_slider_option(vbox, "Puck Bounciness", "puck_bounciness", 0.1, 1.0, 0.05, set_puck_bounciness)
	create_slider_option(vbox, "Puck Max Speed", "puck_max_speed", 600, 3500, 100)
	create_slider_option(vbox, "Tracer Echoes", "tracer_echoes", 0, 8, 1, set_tracer_echoes)
	create_slider_option(vbox, "Tracer Interval", "tracer_interval", 0.01, 0.2, 0.01, set_tracer_interval)
	create_slider_option(vbox, "Tracer Hue Shift", "tracer_hue_shift", 0.0, 0.3, 0.01, set_tracer_hue_shift)
	create_slider_option(vbox, "Ripple Effect", "fx_strength", 0.0, 1.0, 0.05)
	
	var hbox_rule = HBoxContainer.new()
	hbox_rule.custom_minimum_size.y = UI_ROW_HEIGHT
	hbox_rule.add_theme_constant_override("separation", 10)
	var lbl_rule = Label.new()
	lbl_rule.text = "After Goal Serve:"
	lbl_rule.custom_minimum_size.x = 170
	lbl_rule.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	var btn_rule = Button.new()
	btn_rule.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var refresh_rule_text = func():
		btn_rule.text = "Loser Gets It" if serve_mode_loser_gets_it else "Make It Take It"
	refresh_rule_text.call()
	btn_rule.pressed.connect(func():
		serve_mode_loser_gets_it = not serve_mode_loser_gets_it
		refresh_rule_text.call()
	)
	option_refreshers.append(refresh_rule_text)
	hbox_rule.add_child(lbl_rule)
	hbox_rule.add_child(btn_rule)
	vbox.add_child(hbox_rule)
	
	# Reset button: always the LAST row. Needs two taps so it can't be hit by accident.
	var btn_reset = Button.new()
	btn_reset.text = "Reset to Defaults"
	btn_reset.custom_minimum_size.y = UI_ROW_HEIGHT
	btn_reset.pressed.connect(func():
		if btn_reset.get_meta("armed", false):
			btn_reset.set_meta("armed", false)
			btn_reset.text = "Reset to Defaults"
			reset_options_to_defaults()
		else:
			btn_reset.set_meta("armed", true)
			btn_reset.text = "Tap again to confirm"
			await get_tree().create_timer(3.0).timeout
			if is_instance_valid(btn_reset) and btn_reset.get_meta("armed", false):
				btn_reset.set_meta("armed", false)
				btn_reset.text = "Reset to Defaults"
	)
	vbox.add_child(btn_reset)

func setup_game_over_panel() -> void:
	game_over_container = Control.new()
	game_over_container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	game_over_container.mouse_filter = Control.MOUSE_FILTER_STOP
	game_over_container.visible = false
	ui_layer.add_child(game_over_container)
	
	var dim = ColorRect.new()
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0, 0, 0, 0.6)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	game_over_container.add_child(dim)
	
	lbl_result_p1 = make_result_label()
	lbl_result_p2 = make_result_label()
	game_over_container.add_child(lbl_result_p1)
	game_over_container.add_child(lbl_result_p2)
	
	# Buttons sit on the center line, between the two players' results
	var center = CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	game_over_container.add_child(center)
	
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 20)
	center.add_child(vbox)
	
	var btn_again = Button.new()
	btn_again.text = "Play Again"
	btn_again.custom_minimum_size = Vector2(280, 80)
	btn_again.add_theme_font_size_override("font_size", 28)
	btn_again.pressed.connect(self.start_new_game)
	vbox.add_child(btn_again)
	
	var btn_menu = Button.new()
	btn_menu.text = "Main Menu"
	btn_menu.custom_minimum_size = Vector2(280, 80)
	btn_menu.add_theme_font_size_override("font_size", 28)
	btn_menu.pressed.connect(func():
		game_over_container.visible = false
		show_main_menu())
	vbox.add_child(btn_menu)

func make_result_label() -> Label:
	var lbl = Label.new()
	lbl.add_theme_font_size_override("font_size", 64)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	return lbl

# ==========================================
# 🔊 SOUND EFFECTS
# ==========================================
func setup_audio() -> void:
	sfx_mallet_hit = load_sfx("mallet_hit")
	sfx_wall_hit = load_sfx("wall_hit")
	sfx_goal = load_sfx("goal")
	sfx_mallet_wall = load_sfx("mallet_wall")
	
	# A small pool of players so sounds can overlap (e.g. the goal sound still ringing while clicks happen)
	for i in range(SFX_VOICES):
		var voice = AudioStreamPlayer.new()
		add_child(voice)
		sfx_players.append(voice)
	apply_sfx_volume()

# Looks for res://sounds/<name>.wav, .ogg or .mp3. A missing file just means no sound (no crash).
func load_sfx(base_name: String) -> AudioStream:
	for ext in ["wav", "ogg", "mp3"]:
		var path: String = "%s%s.%s" % [SFX_DIR, base_name, ext]
		if ResourceLoader.exists(path):
			return load(path) as AudioStream
	push_warning("Sound not found: " + base_name)
	return null

func play_sfx(key: String, stream: AudioStream, volume: float = 1.0, pitch: float = 1.0) -> void:
	if stream == null: return
	
	# Retrigger gap: the puck can touch a wall and a mallet in the same instant, or jitter on contact
	var now: int = Time.get_ticks_msec()
	if now - int(sfx_last_msec.get(key, -10000)) < SFX_MIN_GAP_MSEC: return
	sfx_last_msec[key] = now
	
	# Use a free voice, or reuse the first one if all are busy
	var chosen: AudioStreamPlayer = sfx_players[0]
	for p in sfx_players:
		if not p.playing:
			chosen = p
			break
	chosen.stream = stream
	chosen.volume_db = linear_to_db(clampf(volume, 0.001, 1.0))
	chosen.pitch_scale = pitch
	chosen.play()

# Puck touched something: a mallet (CharacterBody2D) or a wall (StaticBody2D)
const MALLET_SFX_MIN_IMPACT: float = 0.03   # Hits changing the puck's speed by less than this fraction of max speed make no sound
const MALLET_SFX_MIN_VOLUME: float = 0.1    # Volume of the softest audible mallet hit

func _on_puck_body_entered(body: Node) -> void:
	if not puck_live or not is_instance_valid(puck): return
	var pitch: float = randf_range(0.95, 1.05)
	
	if body is RigidBody2D:
		# Mallet: volume follows how hard the hit really was (how much it changed the puck's velocity)
		var impact: float = (puck.linear_velocity - puck_prev_velocity).length() / puck_max_speed
		if impact < MALLET_SFX_MIN_IMPACT: return   # a graze: no sound
		var loudness: float = lerpf(MALLET_SFX_MIN_VOLUME, 1.0, sqrt(clampf(impact, 0.0, 1.0)))
		play_sfx("mallet", sfx_mallet_hit, loudness, pitch)
	else:
		# Wall: unchanged, loudness follows the puck's speed
		var loudness: float = lerpf(0.35, 1.0, clampf(puck.linear_velocity.length() / puck_max_speed, 0.0, 1.0))
		play_sfx("wall", sfx_wall_hit, loudness, pitch)

func set_sfx_volume(val: float) -> void:
	sfx_volume = val
	apply_sfx_volume()

func apply_sfx_volume() -> void:
	# Master bus, so 0 is silent
	AudioServer.set_bus_volume_db(0, linear_to_db(maxf(sfx_volume, 0.0001)))
	AudioServer.set_bus_mute(0, sfx_volume <= 0.0)

func set_puck_bounciness(val: float) -> void:
	puck_bounciness = val
	# Update the live puck too, so it takes effect without starting a new game
	if is_instance_valid(puck) and puck.physics_material_override:
		puck.physics_material_override.bounce = val

# Pushes the current option values onto the table that's already on screen, so changes show immediately
func apply_options_to_board() -> void:
	if not is_instance_valid(game_elements_container): return
	layout_goals()
	if is_instance_valid(bg_rect): bg_rect.color = color_table
	if is_instance_valid(top_net): top_net.color = get_goal_color()
	if is_instance_valid(bot_net): bot_net.color = get_goal_color()
	if is_instance_valid(court_lines): court_lines.border_color = color_lines
	if is_instance_valid(center_line): center_line.color = color_lines
	for net in [top_net, bot_net]:
		if is_instance_valid(net) and net.get_child_count() > 0:
			(net.get_child(0) as ReferenceRect).border_color = color_lines
	var cd = game_elements_container.get_node_or_null("CountdownLabel") as Label
	if cd: cd.add_theme_color_override("font_color", color_lines)
	
	if is_instance_valid(puck): apply_look(puck, puck_radius, color_puck)
	if is_instance_valid(mallet1): apply_look(mallet1, mallet_radius, color_p1)
	if is_instance_valid(mallet2): apply_look(mallet2, mallet_radius, color_p2)
	
	# A bigger mallet could poke past a wall or the center line, so re-clamp both
	if is_instance_valid(mallet1): mallet1.global_position = bound_mallet_position(mallet1.global_position, true)
	if is_instance_valid(mallet2): mallet2.global_position = bound_mallet_position(mallet2.global_position, false)
	apply_fx_look()
	
# Updates size and color of the puck or a mallet: its drawing, its collision circle and its tracer
func apply_look(body: Node2D, radius: float, color: Color) -> void:
	if not body.has_meta("mesh"): return
	body.get_meta("mesh").set_look(radius, color)
	var shape := body.get_meta("shape") as CircleShape2D
	if shape and not is_equal_approx(shape.radius, radius):
		shape.radius = radius
	if body.has_meta("tracer"):
		body.get_meta("tracer").set_look(radius, color)

func set_tracer_interval(val: float) -> void:
	tracer_interval = val
	get_tree().call_group("tracers", "set_echo_interval", val)

func set_tracer_hue_shift(val: float) -> void:
	tracer_hue_shift = val
	get_tree().call_group("tracers", "set_hue_shift", val)

func set_tracer_echoes(val: float) -> void:
	tracer_echoes = int(val)
	# Update tracers already in the scene, so it takes effect immediately
	get_tree().call_group("tracers", "set_echo_count", tracer_echoes)

# One slider row. option_name is the variable it controls (it must be listed in SAVED_OPTIONS).
# extra = optional function to call with the new value (for effects beyond storing it).
# as_percent = show 0.35 as "35%".
func create_slider_option(parent: Node, label_text: String, option_name: String, min_v: float, max_v: float, step: float, extra: Callable = Callable(), as_percent: bool = false) -> void:
	var hbox = HBoxContainer.new()
	hbox.custom_minimum_size.y = UI_ROW_HEIGHT
	hbox.add_theme_constant_override("separation", 10)
	
	var lbl = Label.new()
	lbl.text = label_text
	lbl.custom_minimum_size.x = 170
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	
	var fmt = func(v: float) -> String:
		return ("%d%%" % roundi(v * 100.0)) if as_percent else str(snappedf(v, 0.01))
	
	var current_v: float = float(self.get(option_name))
	var slider = HSlider.new()
	slider.min_value = min_v
	slider.max_value = max_v
	slider.step = step
	slider.value = current_v
	# The whole 44px-tall strip is the touch target; tapping anywhere on it moves the slider
	slider.custom_minimum_size = Vector2(120, UI_ROW_HEIGHT)
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	
	var val_lbl = Label.new()
	val_lbl.text = fmt.call(current_v)
	val_lbl.custom_minimum_size.x = 60
	val_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	val_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	
	slider.value_changed.connect(func(v):
		val_lbl.text = fmt.call(v)
		# Store the value in the option variable (whole-number options stay whole), then run any extra effect
		self.set(option_name, int(v) if typeof(self.get(option_name)) == TYPE_INT else v)
		if extra.is_valid(): extra.call(v)
		apply_options_to_board()
	)
	# Lets "Reset to Defaults" move this slider back
	option_refreshers.append(func(): slider.value = float(self.get(option_name)))
	
	hbox.add_child(lbl)
	hbox.add_child(slider)
	hbox.add_child(val_lbl)
	parent.add_child(hbox)

# One color picker row. option_name is the Color variable it controls (listed in SAVED_OPTIONS).
func create_color_option(parent: Node, label_text: String, option_name: String) -> void:
	var hbox = HBoxContainer.new()
	hbox.custom_minimum_size.y = UI_ROW_HEIGHT
	hbox.add_theme_constant_override("separation", 10)
	
	var lbl = Label.new()
	lbl.text = label_text
	lbl.custom_minimum_size.x = 170
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	
	var cp_btn = ColorPickerButton.new()
	cp_btn.color = self.get(option_name)
	cp_btn.custom_minimum_size = Vector2(100, UI_ROW_HEIGHT)
	cp_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cp_btn.color_changed.connect(func(col):
		self.set(option_name, col)
		apply_options_to_board()
	)
	option_refreshers.append(func(): cp_btn.color = self.get(option_name))
	
	hbox.add_child(lbl)
	hbox.add_child(cp_btn)
	parent.add_child(hbox)

# ==========================================
# 💾 SAVED OPTIONS (config file)
# ==========================================
# Remembers the default of every saved option (taken from the variables' starting values)
func capture_option_defaults() -> void:
	for def in SAVED_OPTIONS:
		option_defaults[def["name"]] = self.get(def["name"])

func save_options() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("meta", "version", CONFIG_VERSION)
	for def in SAVED_OPTIONS:
		cfg.set_value("options", def["name"], self.get(def["name"]))
	var err: int = cfg.save(CONFIG_PATH)
	if err != OK:
		push_warning("Could not save options (error %d)" % err)

func load_options() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(CONFIG_PATH) != OK:
		return # no file yet (first launch) or unreadable: keep the defaults
	
	for def in SAVED_OPTIONS:
		var opt: String = def["name"]
		
		# Find the saved value under its current name, or under an old name if the option was renamed
		var key := ""
		if cfg.has_section_key("options", opt):
			key = opt
		else:
			for old_name in def.get("renamed_from", []):
				if cfg.has_section_key("options", old_name):
					key = old_name
					break
		if key == "":
			continue # option added after this file was saved: it keeps its default
		
		var value = cfg.get_value("options", key)
		var want: int = typeof(option_defaults[opt])
		
		if want == TYPE_FLOAT or want == TYPE_INT:
			if typeof(value) != TYPE_FLOAT and typeof(value) != TYPE_INT:
				continue # wrong type (hand-edited or corrupted): keep the default
			if want == TYPE_INT:
				value = clampi(int(value), int(def.get("min", -2147483648)), int(def.get("max", 2147483647)))
			else:
				value = clampf(float(value), float(def.get("min", -INF)), float(def.get("max", INF)))
		elif typeof(value) != want:
			continue # wrong type: keep the default
		
		self.set(opt, value)

func reset_options_to_defaults() -> void:
	for def in SAVED_OPTIONS:
		self.set(def["name"], option_defaults[def["name"]])
	for refresh in option_refreshers:
		refresh.call() # move every slider / color button / toggle to match
	apply_all_live_options()
	save_options()

# Pushes every option onto whatever is currently running (puck, tracers, volume, table)
func apply_all_live_options() -> void:
	set_puck_bounciness(puck_bounciness)
	get_tree().call_group("tracers", "set_echo_count", tracer_echoes)
	get_tree().call_group("tracers", "set_echo_interval", tracer_interval)
	get_tree().call_group("tracers", "set_hue_shift", tracer_hue_shift)
	apply_sfx_volume()
	apply_options_to_board()

func show_main_menu() -> void:
	menu_container.visible = true
	options_container.visible = false
	# Uses game_in_progress, NOT game_active: game_active is already false while paused,
	# which is why the button never showed up before. Not saved anywhere, so a fresh launch has no game.
	btn_return.visible = game_in_progress
	btn_respawn.visible = game_in_progress
	
func show_options_menu() -> void:
	menu_container.visible = false
	options_container.visible = true
func hide_options_menu() -> void:
	save_options() # remember the choices
	show_main_menu()
func pause_and_open_menu() -> void:
	game_active = false
	# Let go of any held mallets so nothing is stuck "grabbed" while the menu is up
	p1_touch_index = -1
	p2_touch_index = -1
	stop_rig(rig1)
	stop_rig(rig2)

	if is_instance_valid(puck): puck.freeze = true
	show_main_menu()
	
# Do-over for a stuck or escaped puck: back into the match, puck re-served where the last serve was
func respawn_puck() -> void:
	resume_game()
	reset_puck_serve(last_serve_to_p1)
		
func resume_game() -> void:
	game_active = true
	# Only release the puck if it's actually in play (not mid-countdown)
	if is_instance_valid(puck) and puck_live: puck.freeze = false
	menu_container.visible = false
# ==========================================
# 🎨 DYNAMIC VECTOR DRAWING HELPERS
# ==========================================


# Leaves fading "echoes" of where its target was a moment ago, each one shifted in hue
class TracerDrawer extends Node2D:
	var target: Node2D
	var radius: float
	var base_color: Color
	var echo_count: int
	var echo_interval: float
	var hue_shift: float
	var history: Array[Vector2] = []
	var _elapsed: float = 0.0
	
	func _init(t: Node2D, r: float, c: Color, count: int, interval: float, shift: float) -> void:
		target = t
		radius = r
		base_color = c
		echo_count = count
		echo_interval = interval
		hue_shift = shift
	
	func _ready() -> void:
		add_to_group("tracers")
	
	func set_look(r: float, c: Color) -> void:
		radius = r
		base_color = c
		queue_redraw()
	
	func set_echo_interval(v: float) -> void:
		echo_interval = v
	
	func set_hue_shift(v: float) -> void:
		hue_shift = v
		queue_redraw()
	
	func set_echo_count(n: int) -> void:
		echo_count = n
		while history.size() > echo_count:
			history.pop_back()
		queue_redraw()
	
	func _process(delta: float) -> void:
		# Hidden target (puck during a countdown) or tracers off: clear so no stale ghosts linger
		if echo_count <= 0 or not is_instance_valid(target) or not target.is_visible_in_tree():
			if not history.is_empty():
				history.clear()
				queue_redraw()
			return
		
		_elapsed += delta
		if _elapsed >= echo_interval:
			_elapsed = 0.0
			history.push_front(target.global_position)
			while history.size() > echo_count:
				history.pop_back()
			queue_redraw()
	
	func _draw() -> void:
		for i in range(history.size()):
			var fade: float = 1.0 - float(i) / float(echo_count) # newest echo is the strongest
			var hue: float = fposmod(base_color.h + hue_shift * float(i + 1), 1.0)
			var c := Color.from_hsv(hue, base_color.s, base_color.v, 0.5 * fade)
			draw_circle(history[i], radius * (1.0 - 0.05 * float(i)), c)

# The puck: a filled circle with an inverse-colored triangle inside, so spin is visible
# The puck: a filled circle with a brighter square inside, so spin is visible
class PuckDrawer extends Node2D:
	const MARKER_HALF: float = 0.17     # Half the square's side, as a fraction of the puck radius
	const MARKER_OFFSET: float = 0.0    # Shifts the square toward the top of the puck (0 = centered)
	const MARKER_LIGHTEN: float = 0.7   # How much brighter than the puck color (0 = same, 1 = white)
	
	var radius: float
	var color: Color
	var marker_color: Color
	
	func _init(r: float, c: Color) -> void:
		set_look(r, c)
	
	func set_look(r: float, c: Color) -> void:
		radius = r
		color = c
		marker_color = c.lightened(MARKER_LIGHTEN)
		# A white or very light puck can't get brighter, so go darker there instead
		if absf(marker_color.get_luminance() - c.get_luminance()) < 0.12:
			marker_color = c.darkened(0.5)
		queue_redraw()
	
	func _draw() -> void:
		draw_circle(Vector2.ZERO, radius, color)
		# The square spins with the puck because this node is a child of the puck's body
		var h: float = radius * MARKER_HALF
		var center := Vector2(0.0, -radius * MARKER_OFFSET)
		draw_rect(Rect2(center - Vector2(h, h), Vector2(h * 2.0, h * 2.0)), marker_color)

# A mallet: a filled circle with an inverse-colored dot in the center
# A mallet: raised inner knob and outer rim in the player's color, with a darker recessed
# ring between them. The inverse-colored dot marks where the finger is hooked on.

class MalletDrawer extends Node2D:
	const INNER_FRACTION: float = 0.5    # Inner knob size as a fraction of the mallet radius
	const RECESS_DARKEN: float = 0.65    # How much darker the recessed area is (0 = same, 1 = black)
	
	var radius: float
	var color: Color
	var recess_color: Color
	
	func _init(r: float, c: Color) -> void:
		set_look(r, c)
	
	func set_look(r: float, c: Color) -> void:
		radius = r
		color = c
		recess_color = c.darkened(RECESS_DARKEN) if c.get_luminance() > 0.08 else c.lightened(0.2)
		queue_redraw()
	
	func _draw() -> void:
		var rim: float = clampf(radius * 0.08, 2.5, 5.0)
		draw_circle(Vector2.ZERO, radius, recess_color)
		draw_arc(Vector2.ZERO, radius - rim / 2.0, 0.0, TAU, 48, color, rim, true)
		draw_circle(Vector2.ZERO, radius * INNER_FRACTION, color)
		

class MalletRig extends RefCounted:
	var mallet: RigidBody2D
	var gripped: bool = false
	var touch_pos: Vector2 = Vector2.ZERO   # where the finger actually is (drives the touch ripple)
	var target: Vector2 = Vector2.ZERO      # where the mallet is trying to go
	var last_pos: Vector2 = Vector2.ZERO
	var flick_vel: Vector2 = Vector2.ZERO
	var prev_speed: float = 0.0

	# ==========================================
# 🌊 RIPPLE EFFECT (shader)
# ==========================================
func build_fx_layer(screen_size: Vector2) -> void:
	fx_mat = ShaderMaterial.new()
	fx_mat.shader = load("res://ripple.gdshader") as Shader
	fx_rect = ColorRect.new()
	fx_rect.size = screen_size
	fx_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fx_rect.material = fx_mat
	fx_rect.visible = false
	game_elements_container.add_child(fx_rect)
	fx_mat.set_shader_parameter("screen_size", screen_size)
	apply_fx_look()

func apply_fx_look() -> void:
	if not is_instance_valid(fx_mat): return
	fx_mat.set_shader_parameter("color1", color_p1)
	fx_mat.set_shader_parameter("color2", color_p2)
	fx_mat.set_shader_parameter("color3", color_puck)
	fx_mat.set_shader_parameter("strength", fx_strength)

func _process(delta: float) -> void:
	update_fx(delta)

func update_fx(delta: float) -> void:
	if not is_instance_valid(fx_mat) or delta <= 0.0: return
	if not is_instance_valid(mallet1) or not is_instance_valid(mallet2): return
	var mallets := [mallet1, mallet2]
	var held := [p1_touch_index != -1 and game_active, p2_touch_index != -1 and game_active]
	
	for i in range(2):
		var pos: Vector2 = mallets[i].global_position
		var raw_vel: Vector2 = (pos - fx_prev[i]) / delta
		fx_prev[i] = pos
		fx_vel[i] = fx_vel[i].lerp(raw_vel, 1.0 - exp(-delta * 15.0))
		
		# During play every mallet has ripples: gentle at rest, stronger the faster it moves (held or sliding)
		var target: float = 0.0
		if game_active:
			target = MALLET_FX_IDLE + (1.0 - MALLET_FX_IDLE) * clampf(fx_vel[i].length() / FX_FULL_SPEED, 0.0, 1.0)
		var rate: float = 10.0 if target > fx_energy[i] else 3.0
		fx_energy[i] = lerpf(fx_energy[i], target, 1.0 - exp(-delta * rate))
		
		fx_mat.set_shader_parameter("pos%d" % (i + 1), pos)
		fx_mat.set_shader_parameter("vel%d" % (i + 1), fx_vel[i])
		fx_mat.set_shader_parameter("energy%d" % (i + 1), fx_energy[i])
				# Finger ripple: follows the actual touch point (not the mallet), fades in fast and out slowly
		var rig: MalletRig = rig1 if i == 0 else rig2
		if held[i] and rig != null:
			fx_touch_pos[i] = rig.touch_pos
		var touch_target: float = TOUCH_FX_LEVEL if held[i] else 0.0
		var touch_rate: float = 10.0 if touch_target > fx_touch_energy[i] else 3.0
		fx_touch_energy[i] = lerpf(fx_touch_energy[i], touch_target, 1.0 - exp(-delta * touch_rate))
		fx_mat.set_shader_parameter("pos%d" % (i + 3), fx_touch_pos[i])
		fx_mat.set_shader_parameter("energy%d" % (i + 3), fx_touch_energy[i])
		
		# Puck: ripples while it's in play, stronger the faster it moves. When it vanishes (goal,
	# countdown) the ripple fades out where it was instead of jumping to the new serve spot.
	if is_instance_valid(puck):
		var ppos: Vector2 = puck.global_position
		var praw: Vector2 = (ppos - fx_puck_prev) / delta
		fx_puck_prev = ppos
		fx_puck_vel = fx_puck_vel.lerp(praw, 1.0 - exp(-delta * 15.0))
		var in_play: bool = game_active and puck_live and puck.visible
		if in_play: fx_puck_pos = ppos
		var ptarget: float = 0.0
		if in_play:
			ptarget = PUCK_FX_IDLE + (1.0 - PUCK_FX_IDLE) * clampf(fx_puck_vel.length() / FX_FULL_SPEED, 0.0, 1.0)
		var prate: float = 10.0 if ptarget > fx_puck_energy else 3.0
		fx_puck_energy = lerpf(fx_puck_energy, ptarget, 1.0 - exp(-delta * prate))
		fx_mat.set_shader_parameter("pos5", fx_puck_pos)
		fx_mat.set_shader_parameter("vel5", fx_puck_vel)
		fx_mat.set_shader_parameter("energy5", fx_puck_energy)
	# Hidden entirely when nothing is happening, so it costs nothing while idle
	var any_fx: bool = fx_energy[0] > 0.01 or fx_energy[1] > 0.01 \
		or fx_touch_energy[0] > 0.01 or fx_touch_energy[1] > 0.01 \
		or fx_puck_energy > 0.01
	fx_rect.visible = fx_strength > 0.0 and any_fx

func setup_readme_panel() -> void:
	readme_container = Control.new()
	readme_container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	readme_container.visible = false
	ui_layer.add_child(readme_container)
	
	var backdrop = ColorRect.new()
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.color = Color(0.05, 0.06, 0.08, 0.95)
	readme_container.add_child(backdrop)
	
	var margin = MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		margin.add_theme_constant_override(side, 30)
	readme_container.add_child(margin)
	
	var column = VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	margin.add_child(column)
	
	var top_row = HBoxContainer.new()
	top_row.alignment = BoxContainer.ALIGNMENT_CENTER
	top_row.add_theme_constant_override("separation", 12)
	column.add_child(top_row)
	
	var btn_close = Button.new()
	btn_close.text = "< Back"
	btn_close.custom_minimum_size = Vector2(180, UI_ROW_HEIGHT)
	btn_close.pressed.connect(self.hide_readme)
	top_row.add_child(btn_close)
	
	btn_readme_toggle = Button.new()
	btn_readme_toggle.custom_minimum_size = Vector2(180, UI_ROW_HEIGHT)
	btn_readme_toggle.pressed.connect(self.toggle_license)
	top_row.add_child(btn_readme_toggle)
	
	# A ScrollContainer (same as the options menu) so finger-drag scrolling works on the phone
	readme_scroll = ScrollContainer.new()
	readme_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	readme_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(readme_scroll)
	
	readme_label = RichTextLabel.new()
	readme_label.bbcode_enabled = true
	readme_label.fit_content = true   # grows to its text; the ScrollContainer does the scrolling
	readme_label.scroll_active = false
	readme_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	readme_label.add_theme_font_size_override("normal_font_size", 22)
	readme_label.add_theme_font_size_override("bold_font_size", 22)
	readme_scroll.add_child(readme_label)

func show_readme() -> void:
	showing_license = false
	refresh_readme_text()
	menu_container.visible = false
	readme_container.visible = true

func toggle_license() -> void:
	showing_license = not showing_license
	refresh_readme_text()

func refresh_readme_text() -> void:
	var path: String = LICENSE_PATH if showing_license else README_PATH
	btn_readme_toggle.text = "Read Me" if showing_license else "License"
	# The license is plain text, so BBCode is switched off for it (any square brackets in it show as typed)
	readme_label.bbcode_enabled = not showing_license
	readme_label.add_theme_font_size_override("normal_font_size", 16 if showing_license else 22)
	if FileAccess.file_exists(path):
		readme_label.text = FileAccess.get_file_as_string(path)
	else:
		readme_label.text = "File not found: " + path
	readme_scroll.scroll_vertical = 0

func hide_readme() -> void:
	readme_container.visible = false
	show_main_menu()

# Last line of defense: the puck can never be outside the table's side walls,
# no matter what the physics engine did this step
func contain_puck() -> void:
	if not is_instance_valid(puck) or not puck_live: return
	var s := get_viewport_rect().size
	var p: Vector2 = puck.global_position
	var v: Vector2 = puck.linear_velocity
	var fixed := false
	if p.x < puck_radius - 2.0:   # 2px slack so normal wall contact is left to the engine
		p.x = puck_radius
		v.x = absf(v.x) * puck_bounciness
		fixed = true
	elif p.x > s.x - puck_radius + 2.0:
		p.x = s.x - puck_radius
		v.x = -absf(v.x) * puck_bounciness
		fixed = true
	if fixed:
		puck.global_position = p
		puck.linear_velocity = v
		
# Corner radius actually in use for a player's end (same rule layout_corners uses)
func corner_r_of(is_p1: bool) -> float:
	return minf(corner_radius, (get_viewport_rect().size.x - goal_width_of(is_p1)) / 2.0)

# The rectangle clamp alone leaves a mallet's center inside the curved corners.
# The center may only go as far as the curve pulled in by the mallet's own radius.
func bound_to_corners(pos: Vector2, is_p1: bool) -> Vector2:
	var s := get_viewport_rect().size
	var r: float = corner_r_of(is_p1)
	var reach: float = r - mallet_radius
	if r < 6.0 or reach <= 0.0: return pos   # no curve, or a curve too tight to touch the mallet
	var sy: float = -1.0 if is_p1 else 1.0   # bottom player's corners are at the bottom
	var cy: float = (s.y - goal_depth - r) if is_p1 else (goal_depth + r)
	for sx in [1.0, -1.0]:
		var c := Vector2(r if sx > 0.0 else s.x - r, cy)   # the arc's center
		var d: Vector2 = pos - c
		# Only in the corner's own quadrant (past the arc center, toward the corner)
		if d.x * sx < 0.0 and d.y * sy < 0.0 and d.length() > reach:
			pos = c + d.normalized() * reach
	return pos
