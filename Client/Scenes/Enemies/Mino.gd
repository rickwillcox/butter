extends KinematicBody2D


export var ACCELERATION = 300
export var MAX_SPEED = 250
export var FRICTION = 200
export var WANDER_TARGET_RANGE = 5

enum{
	IDLE, WANDER, CHASE, ATTACK
}

enum{
	LEFT, RIGHT
}

onready var sprite = $Sprite
onready var animation_player = $AnimationPlayer
onready var animation_tree = $AnimationTree
onready var animation_state = $AnimationTree.get("parameters/playback")
onready var wander_controller = $WanderController
onready var player_detection_zone = $PlayerDetectionZone

var velocity = Vector2.ZERO
var knockback = Vector2.ZERO
var blend_position = Vector2.ZERO
var facing_blend_position = Vector2.ZERO
var rng
var state = IDLE
var facing = RIGHT
var attacking = false

func _ready():
	randomize()
	rng = RandomNumberGenerator.new()
	state = pick_random_state([IDLE, WANDER, ATTACK])
	animation_tree.active = true
	
func _physics_process(delta):
	blend_position()
	match state:
		IDLE:
			animation_state.travel("Idle")
			velocity = velocity.move_toward(Vector2.ZERO, FRICTION)
			seek_player()
			time_left_wander_controller()
			
		WANDER:
			animation_state.travel("Run")
			seek_player()
			time_left_wander_controller()
			
			var direction = global_position.direction_to(wander_controller.target_position)
			velocity = velocity.move_toward(direction * MAX_SPEED, ACCELERATION * delta)
#			target position normalised to start movement

			if global_position.distance_to(wander_controller.target_position) <= WANDER_TARGET_RANGE:
				state = pick_random_state([IDLE, WANDER, ATTACK])
				wander_controller.start_wander_timer(rand_range(1,3))
				
		CHASE:
			var player = player_detection_zone.player
			if player != null:
				if global_position.distance_to(player.global_position) <= 25 and not attacking:
					state = ATTACK
				animation_state.travel("Run")
				var direction = global_position.direction_to(player.global_position)
				velocity = velocity.move_toward(direction * MAX_SPEED, ACCELERATION * delta)
			else:
				state = IDLE
			
		ATTACK:
			attacking = true
			var attack_type = rng.randi_range(0,1)
			if attack_type == 0:
				animation_state.travel("AttackSwing")
			else:
				animation_state.travel("AttackSpin")
			yield(get_tree().create_timer(1.2),"timeout")
			attacking = false
			state = IDLE
			
			
	velocity = move_and_slide(velocity)
		
func pick_random_state(state_list):
	state_list.shuffle()
	return state_list.pop_front()
	
func seek_player():
	if player_detection_zone.can_see_player():
		state = CHASE
	
func blend_position():
	var old_blend_position = blend_position
	blend_position = wander_controller.target_position
	if facing == RIGHT:
		if blend_position.x < old_blend_position.x:
			facing = LEFT
			facing_blend_position = blend_position * -1
	elif facing == LEFT:
		if blend_position.x > old_blend_position.x:
			facing = RIGHT
			facing_blend_position = facing_blend_position * -1
	
	animation_tree.set("parameters/Idle/blend_position", facing_blend_position)
	animation_tree.set("parameters/Run/blend_position", facing_blend_position)
	animation_tree.set("parameters/AttackSwing/blend_position", facing_blend_position)
	animation_tree.set("parameters/AttackSpin/blend_position", facing_blend_position)

func time_left_wander_controller():
	if wander_controller.get_time_left() == 0:
		state = pick_random_state([IDLE, WANDER, ATTACK])
		wander_controller.start_wander_timer(rand_range(1,3))