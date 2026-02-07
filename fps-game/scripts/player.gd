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

#stamina system
var max_stamina = 100.0
var stamina = 100.0
var stamina_drain = 30.0  # How fast it drops per second
var stamina_regen = 15.0  # How fast it recovers per second
var stamina_dmg = 50
var can_sprint = true

var gravity = ProjectSettings.get_setting("physics/3d/default_gravity")

#camera settings
var sensitivity = 0.002

#nodes
@onready var cam = $Camera3D
@onready var swordanim = $AnimationPlayer
@onready var attkcd = $AttackCD
@onready var stam_bar = $CanvasLayer/Stamina
@onready var health_bar = $CanvasLayer/health
@onready var death_label = $CanvasLayer/deathlabel
@onready var death_timer = $Deathtimer

#cooldown
var onCooldown = false

#capturing mouse
func _ready():
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	update_health_bar()

#healthbar update
func update_health_bar():
	if health_bar:
		health_bar.value = health

func take_dmg(amount):
	health -= amount
	health = clamp(health, 0, max_health)
	update_health_bar()
	
	health_bar.tint_progress = Color(1, 0, 0) # Turn red
	
	if health <= 0:
		die()

func die():
	death_label.visible = true
	death_timer.start(2.0)
	
	Input.MOUSE_MODE_VISIBLE



#camera axis
func _unhandled_input(event):
	if event is InputEventMouseMotion:
		rotate_y(-event.relative.x * sensitivity) 
		cam.rotate_x(-event.relative.y * sensitivity) #this is rotating the camer on y axis 
		cam.rotation.x = clamp(cam.rotation.x, deg_to_rad(-60), deg_to_rad(70))

#attack animations
func attack():
	if Input.is_action_just_pressed("attack") and onCooldown == false:
		swordanim.play("swordswing")
		onCooldown = true
		attkcd.start()

func _process(delta):
	update_health_bar()
	
	if Input.is_action_just_pressed("quit"):
		get_tree().quit()
		
	attack()
	if stam_bar:
		stam_bar.value = stamina

func _physics_process(delta):
	# 1. Add Gravity
	if not is_on_floor():
		velocity.y -= gravity * delta

	# 2. Handle Jump
	if Input.is_action_just_pressed("ui_accept") and is_on_floor():
		velocity.y = JUMP_VELOCITY
	
	

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
			current_speed = run
			take_dmg(stamina_dmg * delta)
	
	else:
		current_speed = jog
		stamina += stamina_regen * delta
		target_fov = jog_fov
		
	
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
