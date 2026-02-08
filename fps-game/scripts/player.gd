extends CharacterBody3D

#speed system
const jog = 3.0
const JUMP_VELOCITY = 4.5
const run = 9.0
var jog_fov = 75.0
var run_fov = 80.0
var target_fov = jog_fov
var current_speed = jog

#health system
var max_health = 100
var health = 100
var health_regen = 2.0

#stamina system
var max_stamina = 100.0
var stamina = 100.0
var stamina_drain = 10.0  # How fast it drops per second
var stamina_regen = 14.0  # How fast it recovers per second
var stamina_dmg = 0.5
var can_sprint = true
var stamina_jump = 5
var stamina_attack = 3



var gravity = ProjectSettings.get_setting("physics/3d/default_gravity")

#camera settings
var sensitivity = 0.002

#nodes
@onready var pvot = $camerapvot
@onready var springarm = $camerapvot/SpringArm3D
@onready var cam = $camerapvot/SpringArm3D/Camera3D
@onready var swordanim = $AnimationPlayer
@onready var attkcd = $AttackCD
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

# camera toggle variables
var is_first_person = true
var fp_length = 0.0
var tp_length = 2.5

#cooldown
var onCooldown = false
var is_attacking = false

#capturing mouse
func _ready():
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	update_health_bar()
	death_label.visible = false
	warn_label.visible = false
	
	springarm.add_excluded_object(self)

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
	#if event is InputEventMouseMotion and is_first_person:
		#rotate_y(-event.relative.x * sensitivity) 
		#cam.rotate_x(-event.relative.y * sensitivity)
		#cam.rotation.x = clamp(cam.rotation.x, deg_to_rad(-30), deg_to_rad(60))
		#
	#elif event is InputEventMouseMotion and !is_first_person:
		#rotate_y(-event.relative.x * sensitivity) 
		#cam.rotate_x(-event.relative.y * sensitivity)
		#cam.rotation.x = clamp(cam.rotation.x, deg_to_rad(-20), deg_to_rad(20))
	if event is InputEventMouseMotion:
		if is_first_person:
			# Rotate Player Y (Left/Right)
			rotate_y(-event.relative.x * sensitivity) 
			# UPDATE: Rotate SpringArm X (Up/Down) instead of Camera
			springarm.rotate_x(-event.relative.y * sensitivity)
			springarm.rotation.x = clamp(springarm.rotation.x, deg_to_rad(-80), deg_to_rad(80))
	#
		else:
			# Orbit behavior: Mouse turns the PIVOT around the body
			pvot.rotate_y(-event.relative.x * sensitivity)
			springarm.rotate_x(-event.relative.y * sensitivity)
			springarm.rotation.x = clamp(springarm.rotation.x, deg_to_rad(-60), deg_to_rad(60))
		
		
		# Clamp rotation on SpringArm
		if is_first_person:
			springarm.rotation.x = clamp(springarm.rotation.x, deg_to_rad(-80), deg_to_rad(80))
		else:
			springarm.rotation.x = clamp(springarm.rotation.x, deg_to_rad(-60), deg_to_rad(60))

#attack animations
func attack():
	if Input.is_action_just_pressed("attack") and onCooldown == false and is_attacking == false:
		onCooldown = true
		is_attacking = true
		
		stamina -= stamina_attack
		
		swordanim.play("swordswing")
		
		if !is_first_person:
			charanim.play("swordslash")
		
		attkcd.start()

func _process(delta):
	update_health_bar()
	update_sword_parent()
	
	$YBot.position = Vector3.ZERO
	
	if Input.is_action_just_pressed("caminput"):
		is_first_person = !is_first_person
		update_sword_parent()
		
	var target_lenght = fp_length if is_first_person else tp_length
	#cam.transform.origin = cam.transform.origin.lerp(target_lenght, delta * 10.0)
	springarm.spring_length = lerp(springarm.spring_length, target_lenght, delta * 10.0)
	
	# ADJUST THE OFFSET HERE
	# 0.0 for FPS, 0.5 (slightly right) for TPS
	var target_h_offset = -0.2 if is_first_person else -0.3 
	cam.h_offset = lerp(cam.h_offset, target_h_offset, delta * 5.0)
	
	# Optional: Adjust SpringArm height offset for Third Person 
	# (If you want the camera to sit higher in TP than FP)
	var target_y = -0.2 if is_first_person else 0.5
	springarm.position.y = lerp(springarm.position.y, target_y, delta * 20.0)
	
	if Input.is_action_just_pressed("quit"):
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		get_tree().change_scene_to_file("res://scenes/MainMenu.tscn")
		#Input.MOUSE_MODE_VISIBLE
		
	attack()
	if stam_bar:
		stam_bar.value = stamina

func update_sword_parent():
	var new_parent = cam_point if is_first_person else hand_point
	sword.position = Vector3.ZERO
	
	
	if sword.get_parent():
		sword.get_parent().remove_child(sword)
		
	#if cam_point.get_parent():
		#cam_point.get_parent().remove_child(cam_point)
	
	new_parent.add_child(sword)
	
	cam_point.visible = is_first_person
	
	
	if is_first_person:
		
		sword.position = Vector3.ZERO
		sword.rotation_degrees = Vector3(0, 90, 150)
		$YBot.visible = false
	else:
		sword.position = Vector3(0.55, 0.16, -0.05)
		sword.rotation_degrees = Vector3(0, 10, 95)
		$YBot.visible = true
		
	if crosshair:
		crosshair.visible = is_first_person

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
	
	# 4. Calculate Movement relative to the correct basis
	var direction = (pvot.global_transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	
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
		
		if !is_first_person:
			# Rotate the visual mesh ($YBot) to face where we are walking
			var target_rotation = atan2(direction.x, direction.z)
			$YBot.rotation.y = lerp_angle($YBot.rotation.y, target_rotation, delta * 20.0)
	else:
		# Smoothly stop if no keys are pressed
		velocity.x = move_toward(velocity.x, 0, current_speed)
		velocity.z = move_toward(velocity.z, 0, current_speed)
		
	if is_attacking == false:
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
	is_attacking = false

func _on_deathtimer_timeout() -> void:
	get_tree().reload_current_scene()
