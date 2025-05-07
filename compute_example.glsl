#[compute]
#version 450

// Velocity buffer
layout(set = 0, binding = 0, std430) restrict buffer VelocityBuffer {
    vec2 velocities[];
} velocities;

// Invocations in (x,y,z)
layout(local_size_x = 8, local_size_y = 8, local_size_z = 8) in;

void main() {
    uint index = gl_GlobalInvocationID.x;
    if (index >= velocities.velocities.length()) return;
    velocities.velocities[index] *= 2.0;
}