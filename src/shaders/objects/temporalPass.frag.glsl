// Uses pathTracer VS
precision highp float;

uniform vec3 uEye;
uniform float uTime;
varying vec3 initialRay;
uniform vec2 uRes;

uniform sampler2D temporalReservoirTexture; // Stores reservoir data from the previous frame
uniform sampler2D motionVectorTexture;      // Stores motion vectors for temporal reuse

layout(location = 0) out vec4 out_ReservoirData1; // e.g., path_pos.xyz, path_dir.x
layout(location = 1) out vec4 out_ReservoirData2; // e.g., path_dir.yzw, hat_p
layout(location = 2) out vec4 out_ReservoirWeights; // e.g., W_Y, M_r, ...

// use_macro{CONSTANTS}

// use_macro{CUBE_LIB}
// use_macro{SPHERE_LIB}
// use_macro{RAND_LIB}
// use_macro{RAY_LIB}

vec4 tracePath() {
    // Simple scene: sphere at center
    vec3 sphereCenter = vec3(0.0, 0.0, 0.0);
    float sphereRadius = 1.0;

    // for (int bounce = 0; bounce < 100; bounce++) {
    vec2 tRoom = intersectCube(origin, ray, roomCubeMin, roomCubeMax);
    float isect = intersectSphere(origin, ray, sphereCenter, sphereRadius);
    float t = infinity;
    if (tRoom.x < tRoom.y) t = tRoom.y;
    if (isect < t) t = isect;

    vec3 hit = origin + ray * t;
    vec3 surfaceColor = vec3(0.75);
    float specularHighlight = 0.0;
    vec3 normal;

    if (t == tRoom.y) {
        normal = -normalForCube(hit, roomCubeMin, roomCubeMax);
        if(hit.x < -9.9999) surfaceColor = vec3(0.1, 0.5, 1.0);
        else if(hit.x > 9.9999) surfaceColor = vec3(1.0, 0.9, 0.1);
        // ray = cosineWeightedDirection(uTime + float(bounce), normal);
    } else if (t == infinity) {
        // TODO return a default reservoir [weightage 0]
    }
    else {
        normal = normalForSphere(hit, sphereCenter, sphereRadius);
        // ray = cosineWeightedDirection(uTime + float(bounce), normal);
    }
    vec3 position = ray * t + origin;

    Reservoir localReservoir = initializeReservoir();
    // fill in code here
    return vec4(localReservoir.x_it, localReservoir.sumWeight);
}

vec3 evaluateBSDF(vec3 incoming_dir, vec3 outgoing_dir, vec3 normal, vec3 albedo) {
    // Simple Lambertian model
    if (dot(incoming_dir, normal) < 0.0 || dot(outgoing_dir, normal) < 0.0) return vec3(0.0); // Should be on the same side
    return albedo / pi; // Lambertian BRDF = albedo / PI
}

float luminance(vec3 L) {
    return max(dot(L, vec3(1.0)), 0.0);
}

float compute_p_hat(float solidAnglePDF, float jacobian) {
    return solidAnglePDF * jacobian;
}

Reservoir tracePath(vec3 ray, vec3 origin) {
    Reservoir localReservoir;
    initializeReservoir(localReservoir);

    // Start of path
    vec3 origin = cameraOrigin;
    vec3 ray = generateCameraRay();
    vec3 throughput = vec3(1.0);
    float path_pdf = 1.0;

    vec3 last_pos = vec3(0.0);
    vec3 last_normal = vec3(0.0);
    vec3 last_dir_in = -ray;
    vec3 albedo = vec3(1.0);

    float initSeed = ray.x * 85.63 + ray.y * 53.47 + ray.z * 25.93 + uTime * 49.69;

    Reservoir initializeReservoir() {
        Reservoir r;
        r.Y.rc_vertex.w = 0.0;
        r.Y.rc_vertex.L = vec3(0.0);
        r.Y.epsilon_1 = 0.0;
        r.Y.epsilon_2 = 0.0;
        r.Y.k = 0;
        r.Y.J = 0.0;
        r.W_Y = 0.0;
        r.w_sum = 0.0;
        r.c = 0.0;
        return r;
    }
    int bounce = 0;
    for (bounce = 0; bounce < maxBounces; bounce++) {
        float currentSeed = initSeed + bounce * 36.23;
        Isect isect = intersect(origin, ray);
        if (isect.t == infinity) {
            last_pos = origin + ray * infinity;
            last_normal = -ray;
            last_dir_in = -ray;
            albedo = vec3(0.0); // could add sampling from an env
            break;
        }

        // Update last vertex info for terminal NEE
        last_pos = isect.position;
        last_normal = isect.normal;
        last_dir_in = -ray;
        albedo = isect.albedo;

        // Sample next direction
        vec3 new_dir = cosineWeightedDirection(currentSeed, isect.normal);
        float pdf = pdfCosineWeighted(new_dir, isect.normal);

        if (pdf < 1e-6) break;

        vec3 bsdf = evaluateBSDF(-ray, new_dir, isect.normal, albedo);
        float cosTheta = max(dot(isect.normal, new_dir), 0.0);
        throughput *= bsdf * cosTheta / pdf;
        path_pdf *= pdf;

        origin = isect.position;
        ray = new_dir;
    }

    // -- Terminal Light Sampling (NEE) --
    vec3 light_dir = normalize(light - last_pos);
    float light_dist2 = dot(light - last_pos, light - last_pos);
    float cosTheta = max(dot(last_normal, light_dir), 0.0);
    float visibility = shadow(last_pos + epsilon * last_normal, light - last_pos, sphereCenter, sphereRadius);
    float pdf = pdfCosineWeighted(light_dir, last_normal);

    vec3 Li = lightIntensity / light_dist2;
    vec3 bsdf = evaluateBSDF(last_dir_in, light_dir, last_normal, albedo);
    vec3 f = bsdf * cosTheta;

    vec3 L = f * Li * visibility;
    float w = luminance(L); // our weightage formula
    float cosTheta = max(dot(surfaceNormal, sampleDir), 1e-4);
    float distance2 = dot(lightPos - last_vertex_pos, lightPos - last_vertex_pos);
    float jacobian = cosTheta / distance2;
    float hat_p = compute_p_hat(pdf, jacobian);
    float W = (hat_p > 0.0) ? w / hat_p : 0.0;

    // -- Populate Reservoir --
    localReservoir.Y.rc_vertex.w = w;
    localReservoir.Y.rc_vertex.L = L;
    // localReservoir.Y.epsilon_1 = 0.0; since there is only one candidate no need for epsilon_1
    localReservoir.Y.epsilon_2 = random(initSeed + (bounce + 1) * 36.23);
    localReservoir.Y.k = bounce;
    localReservoir.Y.J = jacobian;
    localReservoir.W_Y = W;
    // localReservoir.w_sum = 0.0; since there is only one candidate theres no need to store this
    localReservoir.c = 1.0;
    return localReservoir;
}

void main() {

}