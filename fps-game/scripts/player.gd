extends CharacterBody3D

# Player controller script
# - Handles movement, camera control, health, stamina, and attacks.
# - Exported variables (using @export) make tuning values editable in the Godot editor.

# Movement / speed settings
# Adjust these to change how fast the player walks, runs, and jumps
# (Values are in Godot units / seconds unless noted otherwise)

#speed system
@export var jog = 3.0
@export var JUMP_VELOCITY = 4.5
@export var run = 9.0
@export var jog_fov = 75.0
@export var run_fov = 80.0
var target_fov = jog_fov
var current_speed = jog

# Health system (player HP and regen)
@export var max_health = 100
@export var health = 100
@export var health_regen = 2.0

# Stamina system (used for sprinting, jumping, attacking)
# Lower stamina => can't sprint; use `stamina_regen` and `stamina_drain` to tune.

@export var max_stamina = 100.0
@export var stamina = 100.0
@export var stamina_drain = 10.0  # How fast it drops per second
@export var stamina_regen = 14.0  # How fast it recovers per second
@export var stamina_dmg = 0.5
@export var can_sprint = true
@export var stamina_jump = 5
@export var stamina_attack = 3



var gravity = ProjectSettings.get_setting("physics/3d/default_gravity")

# Camera settings
# `sensitivity` controls mouse look responsiveness
@export var sensitivity = 0.002

# Cached node references (use @onready to fetch them once at runtime)
# This improves performance over calling `$NodePath` repeatedly.

#nodes
@onready var pvot = $camerapvot
@onready var springarm = $camerapvot/SpringArm3D
@onready var cam = $camerapvot/SpringArm3D/Camera3D
@onready var swordanim = $AnimationPlayer
@export var sword_cd = 0.7
@export var punch_cd = 0.3
@onready var stam_bar = $CanvasLayer/Stamina
@onready var health_bar = $CanvasLayer/health
@onready var death_label = $CanvasLayer/deathlabel
@onready var death_timer = $Deathtimer
@onready var warn_label = $CanvasLayer/warninglabel
@onready var sword =  $Swordpointh/Sword
@onready var hand_point = $"YBot/Skeleton3D/BoneAttachment3D/handpoint"
@onready var cam_point = $camerapvot/SpringArm3D/Camera3D/Swordpoint
@onready var charanim = $YBot/AnimationPlayer
@onready var crosshair = $CanvasLayer/crosshair


# Camera toggle variables
# Switch between first-person and third-person behavior
@export var is_first_person = false
@export var fp_length = 0.0
@export var tp_length = 2.5

# Attack / state flags
# `onCooldown` prevents spamming attacks; a timer clears it after the chosen cooldown.
# `is_sword_drawn` toggles between sword attacks and unarmed punches.
var onCooldown = false
var is_sword_drawn = true
var is_busy = false
var is_attacking = false


# Called when the node enters the scene tree
func _ready():
	# Lock the mouse for camera control
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	update_health_bar()
	death_label.visible = false
	warn_label.visible = false
	# Prevent the camera SpringArm from colliding with the player
	springarm.add_excluded_object(self)

	

#healthbar update
func update_health_bar():
	# Refresh the UI health bar to match the `health` variable
	if health_bar:
		health_bar.value = health

func take_dmg(amount):
	# Subtract damage, clamp to valid range and update UI
	health -= amount
	health = clamp(health, 0, max_health)
	update_health_bar()
	
	# Briefly flash the health bar red to give the player feedback
	var style = health_bar.get_theme_stylebox("fill").duplicate()
	style.bg_color = Color(1, 0, 0) # Red
	health_bar.add_theme_stylebox_override("fill", style)
	
	get_tree().create_timer(0.1).timeout.connect(func():
		var reset_style = health_bar.get_theme_stylebox("fill").duplicate()
		reset_style.bg_color = Color(0, 0.8, 0) # Your original green
		health_bar.add_theme_stylebox_override("fill", reset_style)
	)
	if health <= 0:
		die()

func die():
	# Handle player death: show UI, stop movement and reveal the cursor
	death_label.visible = true
	death_timer.start(2.0)
	set_physics_process(false)
	set_process(false)
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

# Camera look handling
func _unhandled_input(event):
	
	if event is InputEventMouseMotion:
		if is_first_person:
			## Rotate Player Y (Left/Right)
			rotate_y(-event.relative.x * sensitivity) 
			## UPDATE: Rotate SpringArm X (Up/Down) instead of Camera
			springarm.rotate_x(-event.relative.y * sensitivity)
			springarm.rotation.x = clamp(springarm.rotation.x, deg_to_rad(-80), deg_to_rad(80))
	
		else:
			# Orbit behavior: Mouse turns the PIVOT around the body
			pvot.rotate_y(-event.relative.x * sensitivity)
			springarm.rotate_x(-event.relative.y * sensitivity)
			springarm.rotation.x = clamp(springarm.rotation.x, deg_to_rad(-60), deg_to_rad(60))
	
		if is_first_person:
			springarm.rotation.x = clamp(springarm.rotation.x, deg_to_rad(-80), deg_to_rad(80))
		else:
			springarm.rotation.x = clamp(springarm.rotation.x, deg_to_rad(-60), deg_to_rad(60))

# Attack input handling
# Checks: player must be on the floor, not already attacking/busy, and not on cooldown
func attack():
	if Input.is_action_just_pressed("attack") and is_on_floor() and !onCooldown and !is_attacking and !is_busy:
		onCooldown = true
		is_attacking = true

		# Spend stamina when attacking
		stamina -= stamina_attack

		if is_sword_drawn:
			# Play first-person sword animation and an optional body animation in TP
			swordanim.play("swordswing")
			if !is_first_person:
				charanim.play("swordslash")
				await charanim.animation_finished
		else:
			# Unarmed punch: ensure a minimum visible animation time
			if charanim.has_animation("punch"):
				charanim.play("punch")
				var punch_length = charanim.get_animation("punch").length
				var min_punch_time = 0.6  # keep punch visible at least this long
				var wait_time = max(punch_length, min_punch_time)
				await get_tree().create_timer(wait_time).timeout

		is_attacking = false
		# Start a non-blocking cooldown timer to clear `onCooldown`.
		# `sword_cd` and `punch_cd` are exported so designers can tweak values.
		var cd = sword_cd if is_sword_drawn else punch_cd
		get_tree().create_timer(cd).timeout.connect(func(): onCooldown = false)

# Toggle between sword drawn and sheathed states
func toggle_sword():
	if is_busy or is_attacking: 
		return
	
	is_busy = true
	
	if is_sword_drawn and is_on_floor():
		charanim.play("sheathsword")
		await charanim.animation_finished
		sword.visible = false
		is_sword_drawn = false
	
	else:
		is_sword_drawn = true  # Set this BEFORE animation so sword stays visible
		if charanim.has_animation("swordvisble"):
			charanim.play("swordvisble")
			await charanim.animation_finished
	
	is_busy = false

func _process(delta):
	# Per-frame UI and camera updates
	update_health_bar()
	update_sword_parent()
	
	$YBot.position = Vector3.ZERO
	springarm.spring_length = lerp(springarm.spring_length, tp_length, delta * 5.0)
	var target_y_offset = 0.5   # Moves camera up slightly
	var target_h_offset = -0.5  # Moves camera to the side (Over-the-shoulder)
	
	springarm.position.y = lerp(springarm.position.y, target_y_offset, delta * 7.0)
	cam.h_offset = lerp(cam.h_offset, target_h_offset, delta * 7.0)
	
	# Optional: Adjust SpringArm height offset for Third Person 
	# (If you want the camera to sit higher in TP than FP)
	var target_y = -0.2 if is_first_person else 0.5
	springarm.position.y = lerp(springarm.position.y, target_y, delta * 20.0)
	
	if Input.is_action_just_pressed("quit"):
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		get_tree().change_scene_to_file("res://scenes/MainMenu.tscn")
		
	if stam_bar:
		stam_bar.value = stamina
	
	if Input.is_action_just_pressed("weaponc") and !is_busy:
		toggle_sword()
	attack()

func update_sword_parent():
	# Ensure the sword node is attached to the correct parent (hand or camera)
	# (this keeps transforms correct for FP and TP views)
	
	# Decide which node should hold the sword
	var target_node = cam_point if is_first_person else hand_point
	
	# Only move the sword if it's not already at the right parent
	if sword.get_parent() != target_node:
		if sword.get_parent():
			sword.get_parent().remove_child(sword)
		target_node.add_child(sword)

	# --- THE FIX FOR "ONLY SEEING SWORD" ---
	if is_first_person:
		$YBot.visible = false   # Hide body so you don't see inside the head
		sword.position = Vector3.ZERO
		sword.rotation_degrees = Vector3(0, 90, 150)
	else:
		$YBot.visible = true    # SHOW body so you can see your character
		sword.position = Vector3(0.55, 0.16, -0.05) # Adjust to fit the hand
		sword.rotation_degrees = Vector3(0, 10, 95)
	
	sword.visible = is_sword_drawn




func _physics_process(delta):

	# Physics step: movement, jumping, sprinting and animation selection

	# 1. Add Gravity
	if not is_on_floor():
		velocity.y -= gravity * delta

	# 2. Handle Jump
	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = JUMP_VELOCITY
		stamina -= stamina_jump
	
	

	# 3. Get Input Direction (W, A, S, D)
	# This creates a Vector2 from -1 to 1 for both axes
	var input_dir = Input.get_vector("left", "right", "forward", "backward")
	
	# 4. Calculate Movement relative to the correct basis
	var direction = (pvot.global_basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	var is_sprinting = Input.is_action_pressed("sprint") and is_on_floor() and velocity.length() > 0.5 and direction.length() > 0
	
	if is_sprinting:
		if stamina > 0 and can_sprint:
			current_speed = run
			stamina -= stamina_drain * delta
			target_fov = run_fov
			
		else:
			current_speed = jog
			take_dmg(stamina_dmg * delta)
			target_fov = jog_fov
			warn_label.visible = true
	
	else:
		current_speed = jog
		stamina += stamina_regen * delta
		health += health_regen * delta
		target_fov = jog_fov
		warn_label.visible = false
		
	
	stamina = clamp(stamina, 0, max_stamina)
	
	cam.fov = lerp(cam.fov, target_fov, delta * 8.0)
	
	#stamina checking if is low
	if stamina <= 0:
		can_sprint = false
	elif stamina >= 20:
		can_sprint = true

	if direction:
		velocity.x = direction.x * current_speed
		velocity.z = direction.z * current_speed
		
		if !is_first_person:
			var target_rotation = atan2(direction.x, direction.z)
			$YBot.rotation.y = lerp_angle($YBot.rotation.y, target_rotation, delta * 15.0)
		else:
			$YBot.rotation.y = 0 # Since the parent (self) is already rotating
	else:
		# Smoothly stop if no keys are pressed
		velocity.x = move_toward(velocity.x, 0, current_speed)
		velocity.z = move_toward(velocity.z, 0, current_speed)
		
	if is_attacking == false and not is_busy:
		if is_on_floor():
			if velocity.length() > 5:
				charanim.play("run")
			elif velocity.length() > 0.1:
				charanim.play("jog")
			else:
				charanim.play("idle")
		else:
			charanim.play("jump")
	

	# 5. Apply the movement
	move_and_slide()

func _on_attack_cd_timeout() -> void:
	onCooldown = false

func _on_deathtimer_timeout() -> void:
	get_tree().reload_current_scene()
