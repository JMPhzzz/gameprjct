extends CharacterBody3D

#speed system
const jog = 3.0
const JUMP_VELOCITY = 4.5
const run = 9.0
var jog_fov = 75.0
var run_fov = 85.0
var target_fov = jog_fov
var current_speed = jog

#health system
var max_health = 100
var health = 100
var health_regen = 2.0

#stamina system
var max_stamina = 100.0
var stamina = 100.0
var stamina_drain = 15.0  # How fast it drops per second
var stamina_regen = 10.0  # How fast it recovers per second
var stamina_dmg = 10.0
var can_sprint = true
var stamina_jump = 5



var gravity = ProjectSettings.get_setting("physics/3d/default_gravity")

#camera settings
var sensitivity = 0.002

#nodes
@onready var pvot = $camerapvot
@onready var cam = $camerapvot/Camera3D
@onready var swordanim = $AnimationPlayer
@onready var attkcd = $AttackCD
@onready var stam_bar = $CanvasLayer/Stamina
@onready var health_bar = $CanvasLayer/health
@onready var death_label = $CanvasLayer/deathlabel
@onready var death_timer = $Deathtimer
@onready var warn_label = $CanvasLayer/warninglabel

# camera toggle variables
var is_first_person = true
var fp_pos = Vector3(0, 0, 0)
var tp_pos = Vector3(0, 0.5, 2.0)

#cooldown
var onCooldown = false

#capturing mouse
func _ready():
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	update_health_bar()
	death_label.visible = false
	warn_label.visible = false

#healthbar update
func update_health_bar():
	if health_bar:
		health_bar.value = health
		#health_bar.tint_progress = Color(1, 1, 1)

func take_dmg(amount):
	health -= amount
	health = clamp(health, 0, max_health)
	update_health_bar()
	
	#if health_bar:
		#health_bar.value = health
		## Turn it RED specifically when taking damage
		#health_bar.tint_progress = Color(1, 0, 0) 
		#
		# Create a quick timer to turn it back to white after 0.1 seconds
		#get_tree().create_timer(0.1).timeout.connect(func(): 
			#health_bar.tint_progress = Color(1, 1, 1)
		#)
	var style = health_bar.get_theme_stylebox("fill").duplicate()
	style.bg_color = Color(1, 0, 0) # Red
	health_bar.add_theme_stylebox_override("fill", style)
	
	#var t = get_tree().create_timer(0.1)
	#t.timeout.connect(func(): health_bar.tint_progress = Color(1, 1, 1))
	get_tree().create_timer(0.1).timeout.connect(func():
		var reset_style = health_bar.get_theme_stylebox("fill").duplicate()
		reset_style.bg_color = Color(0, 0.8, 0) # Your original green
		health_bar.add_theme_stylebox_override("fill", reset_style)
	)
	if health <= 0:
		die()

func die():
	death_label.visible = true
	death_timer.start(2.0)
	
	set_physics_process(false)
	set_process(false)
	
	Input.MOUSE_MODE_VISIBLE

#camera axis
func _unhandled_input(event):
	if event is InputEventMouseMotion and is_first_person:
		rotate_y(-event.relative.x * sensitivity) 
		cam.rotate_x(-event.relative.y * sensitivity)
		cam.rotation.x = clamp(cam.rotation.x, deg_to_rad(-30), deg_to_rad(60))
	elif event is InputEventMouseMotion and !is_first_person:
		rotate_y(-event.relative.x * sensitivity) 
		cam.rotate_x(-event.relative.y * sensitivity)
		cam.rotation.x = clamp(cam.rotation.x, deg_to_rad(-20), deg_to_rad(20))

#attack animations
func attack():
	if Input.is_action_just_pressed("attack") and onCooldown == false:
		swordanim.play("swordswing")
		onCooldown = true
		attkcd.start()

func _process(delta):
	update_health_bar()
	
	if Input.is_action_just_pressed("caminput"):
		is_first_person = !is_first_person
		
	var target_pos = fp_pos if is_first_person else tp_pos
	cam.transform.origin = cam.transform.origin.lerp(target_pos, delta * 10.0)
	
	if Input.is_action_just_pressed("quit"):
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		get_tree().change_scene_to_file("res://scenes/MainMenu.tscn")
		#Input.MOUSE_MODE_VISIBLE
		
	attack()
	if stam_bar:
		stam_bar.value = stamina

func _physics_process(delta):
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
	
	# 4. Calculate Movement relative to where the player is FACING
	# transform.basis.z is the "Forward" direction of your node
	var direction = (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	
	var is_sprinting = Input.is_action_pressed("sprint") and is_on_floor() and velocity.length() > 0.5 and direction.length() > 0
		
	#if is_sprinting > 0 and can_sprint:
		#current_speed = run
		#stamina -= stamina_drain * delta
		#target_fov = run_fov
	
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
	else:
		# Smoothly stop if no keys are pressed
		velocity.x = move_toward(velocity.x, 0, current_speed)
		velocity.z = move_toward(velocity.z, 0, current_speed)

	# 5. Apply the movement
	move_and_slide()


func _on_attack_cd_timeout() -> void:
	onCooldown = false


func _on_deathtimer_timeout() -> void:
	get_tree().reload_current_scene()
