extends CharacterBody3D

signal health_changed(health_value)
#signal ammo_changed(ammo_bar_value)
#signal shots_fired(shots_fired_value)

@onready var camera = $Camera3D
@onready var anim_player = $AnimationPlayer
@onready var muzzle_flash = $Camera3D/pistol/Muzzleflash
@onready var raycast = $Camera3D/RayCast3D
@onready var crosshair = $CanvasLayer/HUD/TextureRect
@onready var ammo_bar = $HUD/ammo

#variables
var health = 3
var ammo = 12

#booleans
var showscope = false
var reloading = false
var moving = false

const SPEED = 8.0
const JUMP_VELOCITY = 6
var gravity = 20.0

func _enter_tree():
	set_multiplayer_authority(str(name).to_int())

func _ready():
	if not is_multiplayer_authority(): return
	
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	camera.current = true

func _unhandled_input(event):
	if not is_multiplayer_authority(): return

	if event is InputEventMouseMotion:
		rotate_y(-event.relative.x * .005)
		camera.rotate_x(-event.relative.y * .005)
		camera.rotation.x = clamp(camera.rotation.x, -PI/2, PI/2)
	#print(anim_player.current_animation)
	if Input.is_action_just_pressed("scope") and anim_player.current_animation != "scope" and not reloading:
		showscope = !showscope
		#play_scope()
		if showscope:
			play_scope()
		
	
		
	if Input.is_action_just_pressed("shoot") and anim_player.current_animation != "shoot" and ammo >= 1:
		play_shoot_effects.rpc()
		if raycast.is_colliding():
			var hit_player = raycast.get_collider()
			hit_player.recieve_damage.rpc_id(hit_player.get_multiplayer_authority())
			
	if Input.is_action_just_pressed("reload") and ammo < 12 and anim_player.current_animation != "reload":
		reloading = !reloading
		pistol_reload()

func _physics_process(delta: float):
	if not is_multiplayer_authority(): return

	# Add the gravity.
	if not is_on_floor():
		velocity += get_gravity() * delta

	# Handle jump.
	if Input.is_action_just_pressed("ui_accept") and is_on_floor():
		velocity.y = JUMP_VELOCITY

	# Get the input direction and handle the movement/deceleration.
	# As good practice, you should replace UI actions with custom gameplay actions.
	var input_dir := Input.get_vector("left", "right", "up", "down")
	var direction := (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	if direction:
		velocity.x = direction.x * SPEED
		velocity.z = direction.z * SPEED
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED)
		velocity.z = move_toward(velocity.z, 0, SPEED)
	if anim_player.current_animation == "shot":
		pass
	elif showscope:
		pass
	elif reloading:
		pass
	#walking on floor animation
	elif input_dir != Vector2.ZERO and is_on_floor():
		#moving = true
		#if !showscope:
			#anim_player.stop()
		anim_player.play("move")
		#else: anim_player.play("scope")
			
		#print("didnt work")
	elif not showscope and not reloading and anim_player.current_animation  != "move":
		#anim_player.stop()
		anim_player.play("idle")
		#print("in idle")
	
	move_and_slide()

@rpc("call_local")

func play_shoot_effects():
	anim_player.stop()
	if showscope:
		anim_player.play("scopeshot")
	else:
		anim_player.play("shot")
		
	pistol_flash()
	ammo -= 1
	update_ammo_bar(ammo)
	
func pistol_flash():
	muzzle_flash.restart()
	muzzle_flash.emitting = true

func play_scope():
	anim_player.stop()
	anim_player.play("scope")

func pistol_reload():
	anim_player.stop()
	anim_player.play("reload")
	await get_tree().create_timer(1.5).timeout 
	ammo = 12
	update_ammo_bar(ammo)
	reloading = false
	#print(str(reloading))

func update_ammo_bar(ammo_bar_value):
	ammo_bar.value = ammo_bar_value

func update_shots_fired(shots_fired_value):
	shots_fired_value = reloading
@rpc("any_peer")
func recieve_damage():
	health -= 1
	if health <= 0:
		health = 6
		position = Vector3.ZERO
	health_changed.emit(health)

func _on_animation_player_animation_finished(anim_name):
	if anim_name == "shot":
		anim_player.play("idle")
	if anim_name == "reload":
		ammo = 12
