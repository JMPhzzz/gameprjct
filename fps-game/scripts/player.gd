extends CharacterBody3D


const SPEED = 5.0
const JUMP_VELOCITY = 4.5

var gravity = ProjectSettings.get_setting("physics/3d/default_gravity")

#camera settings
var sensitivity = 0.002
@onready var cam = $Camera3D

func _ready():
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _unhandled_input(event):
	if event is InputEventMouseMotion:
		rotate_y(-event.relative.x * sensitivity) 
		cam.rotate_x(-event.relative.y * sensitivity) #this is rotating the camer on y axis 
		cam.rotation.x = clamp(cam.rotation.x, deg_to_rad(-60), deg_to_rad(70))

func _process(delta):
	if Input.is_action_just_pressed("quit"):
		get_tree().quit()

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

	if direction:
		velocity.x = direction.x * SPEED
		velocity.z = direction.z * SPEED
	else:
		# Smoothly stop if no keys are pressed
		velocity.x = move_toward(velocity.x, 0, SPEED)
		velocity.z = move_toward(velocity.z, 0, SPEED)

	# 5. Apply the movement
	move_and_slide()
