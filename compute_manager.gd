extends Node

# TODO: Add parameters buffer with things like G constant, number of bodies, and other important parameters.
# TODO: Make velocities influence the color of bodies (later)

@export var min_x_from_center = 0
@export var max_x_from_center = 500
@export var min_y_from_center = 0
@export var max_y_from_center = 500

@export var planet_scene: PackedScene


# The velocities of all bodies thus far.
var velocities: Array = []
# The actual list of instantiated scenes of the bodies created thus far
var bodies = []

# Rendering thingies
var rendering_device: RenderingDevice
var shader: RID
var pipeline: RID

# Compute shader parameters
const work_group_size : int = 8
const num_waitframes_gpusync : int = 12

# Buffers
var buffer_set: RID # The collection of buffers (needed for more than one buffer in a single shader
var velocity_buffer: RID


# Outputs from our compute shader
var output_velocity_buffer: RID

# State
var frame : int
var last_compute_dispatch_frame: int
var waiting_for_compute: bool


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	for i in range(100):
		create_body()
	print("Velocity array state: %s" % str(velocities))
	print("Body array state: %s" % str(bodies))
	
	init_compute()
	run_compute()
	fetch_and_process_compute_data()


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	if (waiting_for_compute && frame - last_compute_dispatch_frame >= num_waitframes_gpusync):
		fetch_and_process_compute_data()
	elif (!waiting_for_compute):
		run_compute()
	
	frame += 1
	
func init_compute():
	# Create local rendering device
	rendering_device = RenderingServer.create_local_rendering_device()
	# Load our GLSL shader
	var shader_file := load("res://compute_example.glsl")
	var shader_spirv: RDShaderSPIRV = shader_file.get_spirv()
	shader = rendering_device.shader_create_from_spirv(shader_spirv)
	# Setup our buffer to send to the GPU
	var packed_velocities = PackedVector2Array(velocities)
	var packed_velocities_bytes = packed_velocities.to_byte_array()
	
	# Create a storage buffer to hold everything.
	velocity_buffer = rendering_device.storage_buffer_create(packed_velocities_bytes.size(), packed_velocities_bytes)
	# And assign a uniform to it for the shader.
	var velocity_uniform := RDUniform.new()
	velocity_uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER
	velocity_uniform.binding = 0 # Should match `binding` in shader file
	velocity_uniform.add_id(velocity_buffer)
	
	# Create uniform set and pipeline
	var uniforms = [velocity_uniform]
	buffer_set = rendering_device.uniform_set_create(uniforms, shader, 0) # last parameter must match `set` in shader file
	# Create pipeline
	pipeline = rendering_device.compute_pipeline_create(shader)
	print("Pipeline created!")
	
func run_compute():
	# Update velocities packed buffer for the compute shader to execute on.
	var velocities_packed_bytes = PackedVector2Array(velocities).to_byte_array()
	rendering_device.buffer_update(velocity_buffer, 0, velocities_packed_bytes.size(), velocities_packed_bytes)
	print("Velocity array pre_compute: %s" % str(velocities))
	# Prepare compute list
	var local_size = 8
	var groups_x = int(ceil(float(velocities.size()) / float(local_size))) # figure out how many groups we need based on the number of velocities/thread
	var compute_list := rendering_device.compute_list_begin()
	rendering_device.compute_list_bind_compute_pipeline(compute_list, pipeline)
	rendering_device.compute_list_bind_uniform_set(compute_list, buffer_set, 0)
	rendering_device.compute_list_dispatch(compute_list, groups_x, 1, 1)
	rendering_device.compute_list_end()
	# Submit to GPU to execute
	rendering_device.submit()
	waiting_for_compute = true
	print("Shader has been submitted")

func fetch_and_process_compute_data():
	rendering_device.sync()
	waiting_for_compute = false
	# Get the output from the shader
	var packed_velocites = rendering_device.buffer_get_data(velocity_buffer)
	velocities = packed_velocites.to_float32_array() 
	print("Shader computation completed! Data read back from GPU: %s" % str(velocities))

func create_body():
	# Create random position for bodies upon creation.
	var screen_size = get_viewport().get_visible_rect().size
	var random_position = Vector2(randi_range((screen_size.x / 2) + min_x_from_center, (screen_size.x / 2) + max_x_from_center), randi_range((screen_size.y / 2) + min_y_from_center, (screen_size.y / 2) + max_y_from_center))
	# Instantiate scene at that position
	var new_planet = planet_scene.instantiate()
	new_planet.position = random_position
	new_planet.gravity_scale = 0.0
	new_planet.lock_rotation = true
	new_planet.linear_velocity = Vector2(1.0, 1.0)
	
	bodies.append(new_planet)
	velocities.append(new_planet.linear_velocity)
	add_child(new_planet)
	print("Body added to list at coords: (%s, %s)" % [random_position.x, random_position.y])

	
