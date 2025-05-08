#[compute]
#version 450

// Velocity buffer
layout(set = 0, binding = 0, std430) restrict buffer VelocityBuffer {
    vec2 velocities[];
} velocities;

// Mass buffer
layout(set = 0, binding = 1, std430) restrict buffer MassBuffer {
    float masses[];
} masses;

// Params buffer
layout(set = 0, binding = 2, std430) restrict buffer ParamsBuffer {
    float big_G;
    float number_of_bodies;
    float delta;
    float safety; // Needed to prevent divides by zero
} params;

layout(set = 0, binding = 3, std430) restrict buffer PositionsBuffer {
    vec2 positions[];
}

// Invocations in (x,y,z)
layout(local_size_x = 8, local_size_y = 8, local_size_z = 8) in;

void main() {
    uint index = gl_GlobalInvocationID.x;
    if (index >= velocities.velocities.length()) return;
    // Early return
    if (masses.masses[index] < 0.0) {
        return;
    }

    // Gravity
    if (delta > 0.0) {
        vec3 temp = vec3(0.0);

        // Go through all other bodies
        for (int other_index = 0; other_index < number_of_bodies; other_index++) {
            // Skip ourselves
            if (other_index == index) return;

            // If no mass is encountered, we just break.
            if (masses.masses[other_index] == 0.0) { break; }

            vec3 diff = positions.positions[other_index] - positions.positions[index];
            temp += normalize(diff) * masses.masses[other_index] / (dot(diff, diff));
        }

        // Update data
        velocities.velocities[index] += vec3(temp * big_g * delta);
        positions.positions[index] += velocities.velocities[index] * delta;
    }
}