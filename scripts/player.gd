extends CharacterBody3D

# Player node

@onready var nek := $nek
@onready var head := $nek/head
@onready var eyes: Node3D = $nek/head/eyes
@onready var standing_collision_shape: CollisionShape3D = $standing_collision_shape
@onready var crouching_collision_shape: CollisionShape3D = $crouching_collision_shape
@onready var ray_cast_3d: RayCast3D= $RayCast3D
@onready var camera_3d: Camera3D = $nek/head/eyes/Camera3D

# Speed vars

var current_speed = 5.0

const walking_speed = 5.0
const sprinting_speed = 8.0
const crouch_speed = 3.0

# State

var walking = false
var sprinting = false
var crouching = false
var free_looking = false
var sliding = false

# Slide vars

var slide_timer = 0
var slide_timer_max = 1.0
var slide_vertor = Vector2.ZERO
var slide_speed = 10.0

# Head bobbings vars

const head_bobbing_sprinting_speed = 22.0
const head_bobbing_walking_speed = 14.0
const head_bobbing_crouching_speed = 10.0

const head_bobbing_sprinting_intensity = 0.2
const head_bobbing_walking_intensity = 0.1
const head_bobbing_crouching_intensity = 0.05

var head_bobbing_vector = Vector2.ZERO
var head_bobbing_index = 0.0
var head_bobbing_current_intensity = 0.0

# Movement vars

var crouching_depth = -0.5

const jump_velocity = 4.5

var lerp_speed = 10.0

var free_look_tilt_amount = 8.0

# Input vars

var direction = Vector3.ZERO
const mouse_sens = 0.25; 

# Get the gravity from the project settings to be synced with RigidBody nodes.
var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")

func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _input(event: InputEvent) -> void:

	# Mouse looking logic

	if event is InputEventMouseMotion:
		if free_looking:
			nek.rotate_y(deg_to_rad(-event.relative.x * mouse_sens))
			nek.rotation.y = clamp(nek.rotation.y, deg_to_rad(-120), deg_to_rad(120))

		else:
			rotate_y(deg_to_rad(-event.relative.x * mouse_sens))

		head.rotate_x(deg_to_rad(-event.relative.y * mouse_sens))
		head.rotation.x = clamp(head.rotation.x, deg_to_rad(-89), deg_to_rad(89))

func _physics_process(delta: float) -> void:
	# Getting movement input
	var input_dir := Input.get_vector("left", "right", "forward", "backward")

	# Handle movemant state

	# Crouching
	if Input.is_action_pressed("crouch") || sliding:
		current_speed = crouch_speed
		head.position.y = lerp(head.position.y, crouching_depth, lerp_speed * delta)
		standing_collision_shape.disabled = true
		crouching_collision_shape.disabled = false

		# Slide begin logic

		if sprinting && input_dir != Vector2.ZERO:
			sliding = true
			slide_timer = slide_timer_max
			slide_vertor = input_dir
			free_looking = true
			print("sliding")

		walking = false
		sprinting = false
		crouching = true
	
	elif !ray_cast_3d.is_colliding():

		# Standing
		standing_collision_shape.disabled = false
		crouching_collision_shape.disabled = true
		head.position.y = lerp(head.position.y, 0.0, lerp_speed * delta)

		if Input.is_action_pressed("sprint"):
			# Sprinting
			current_speed = sprinting_speed

			walking = false
			sprinting = true
			crouching = false
		else:
			# Walking
			current_speed = walking_speed

			walking = true
			sprinting = false
			crouching = false

	# Handle free looking
	if Input.is_action_pressed("free_look") || sliding:
		free_looking = true

		if sliding:
			camera_3d.rotation.z = lerp(camera_3d.rotation.z, -deg_to_rad(7.0), delta * lerp_speed)
		else:
			camera_3d.rotation.z = -deg_to_rad(nek.rotation.y * free_look_tilt_amount)
	else:
		free_looking = false
		nek.rotation.y = lerp(nek.rotation.y, 0.0, delta * lerp_speed)
		camera_3d.rotation.z = lerp(camera_3d.rotation.z, 0.0, delta * lerp_speed)

	# Handle sliding

	if sliding:
		slide_timer -= delta
		if slide_timer <= 0:
			sliding = false
			free_looking = false

	# Handle headbob
	if sprinting:
		head_bobbing_current_intensity = head_bobbing_sprinting_intensity
		head_bobbing_index += head_bobbing_sprinting_speed * delta
	elif walking:
		head_bobbing_current_intensity = head_bobbing_walking_intensity
		head_bobbing_index += head_bobbing_walking_speed * delta
	elif crouching:
		head_bobbing_current_intensity = head_bobbing_crouching_intensity
		head_bobbing_index += head_bobbing_crouching_speed * delta

	if is_on_floor() && !sliding && input_dir != Vector2.ZERO:
		head_bobbing_vector.y = sin(head_bobbing_index)
		head_bobbing_vector.x = sin(head_bobbing_index / 2) + 0.5

		eyes.position.y = lerp(eyes.position.y, head_bobbing_vector.y * (head_bobbing_current_intensity / 2.0), lerp_speed * delta)
		eyes.position.x = lerp(eyes.position.x, head_bobbing_vector.x * head_bobbing_current_intensity, lerp_speed * delta)
	else:
		eyes.position.y = lerp(eyes.position.y, 0.0, lerp_speed * delta)
		eyes.position.x = lerp(eyes.position.x, 0.0, lerp_speed * delta)

	# Add the gravity.
	if not is_on_floor():
		velocity.y -= gravity * delta

	# Handle Jump.
	if Input.is_action_just_pressed("ui_accept") and is_on_floor():
		velocity.y = jump_velocity
		sliding = false

	# Get the input direction and handle the movement/deceleration.
	# As good practice, you should replace UI actions with custom gameplay actions.
	direction = lerp(direction, (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized(), delta * lerp_speed)

	if sliding:
		direction = (transform.basis * Vector3(slide_vertor.x, 0, slide_vertor.y)).normalized()

	if direction:
		velocity.x = direction.x * current_speed
		velocity.z = direction.z * current_speed

		if sliding:
			velocity.x = direction.x * (slide_timer + 0.1) * slide_speed
			velocity.z = direction.z * (slide_timer + 0.1) * slide_speed
	else:
		velocity.x = move_toward(velocity.x, 0, current_speed)
		velocity.z = move_toward(velocity.z, 0, current_speed)

	move_and_slide()
