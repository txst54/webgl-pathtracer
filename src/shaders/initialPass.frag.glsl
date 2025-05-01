#version 300 es
precision highp float;

uniform vec3 uEye;
uniform float uTime;
in vec3 initialRay;
uniform vec2 uRes;

uniform sampler2D temporalReservoirTexture;
uniform sampler2D motionVectorTexture;

layout(location = 0) out vec4 out_ReservoirData1;
layout(location = 1) out vec4 out_ReservoirData2;
layout(location = 2) out vec4 out_ReservoirData3;

// use_macro{CONSTANTS}
// use_macro{CUBE_LIB}
// use_macro{SPHERE_LIB}
// use_macro{SCENE_LIB}
// use_macro{RAND_LIB}
// use_macro{RAY_LIB}
// use_macro{RESERVOIR_LIB}

vec3 evaluateBSDF(vec3 incoming_dir, vec3 outgoing_dir, vec3 normal, vec3 albedo) {
    if (dot(incoming_dir, normal) < 0.0 || dot(outgoing_dir, normal) < 0.0) return vec3(0.0);
    return albedo / pi;
}

float luminance(vec3 L) {
    return max(dot(L, vec3(1.0)), 0.0);
}

float compute_p_hat(float solidAnglePDF, float jacobian) {
    return solidAnglePDF * jacobian;
}

Reservoir tracePath(vec3 ray, vec3 origin) {
    Reservoir localReservoir = initializeReservoir();

    vec3 throughput = vec3(1.0);
    float path_pdf = 1.0;

    vec3 last_pos = vec3(0.0);
    vec3 last_normal = vec3(0.0);
    vec3 last_dir_in = -ray;
    vec3 albedo = vec3(1.0);

    float initSeed = ray.x * 85.63 + ray.y * 53.47 + ray.z * 25.93 + uTime * 49.69;

    int bounce = 0;
    for (bounce = 0; bounce < int(maxBounces); bounce++) {
        float currentSeed = initSeed + float(bounce) * 36.23;
        Isect isect = intersect(origin, ray);
        if (isect.t == infinity) {
            last_pos = origin + ray * infinity;
            last_normal = -ray;
            last_dir_in = -ray;
            albedo = vec3(0.0);
            break;
        }

        last_pos = isect.position;
        last_normal = isect.normal;
        last_dir_in = -ray;
        albedo = isect.albedo;

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

    vec3 light_dir = normalize(light - last_pos);
    float light_dist2 = dot(light - last_pos, light - last_pos);
    float cosTheta = max(dot(last_normal, light_dir), 0.0);
    float visibility = shadow(last_pos + epsilon * last_normal, light - last_pos, sphereCenter, sphereRadius);
    float pdf = pdfCosineWeighted(light_dir, last_normal);

    vec3 Li = vec3(lightIntensity / light_dist2); // multiply by light color if light has color
    vec3 bsdf = evaluateBSDF(last_dir_in, light_dir, last_normal, albedo);
    vec3 f = bsdf * cosTheta;

    vec3 L = f * Li * visibility;
    float w = luminance(L);

    float cosThetaJ = max(dot(last_normal, light_dir), 1e-4);
    float distance2 = dot(light - last_pos, light - last_pos);
    float jacobian = cosThetaJ / distance2;

    float hat_p = compute_p_hat(pdf, jacobian);
    float W = (hat_p > 0.0) ? w / hat_p : 0.0;

    localReservoir.Y.rc_vertex.w = w;
    localReservoir.Y.rc_vertex.L = L;
    localReservoir.Y.epsilon_1 = random(vec3(1.0), initSeed + float(bounce + 1) * 36.23);
    localReservoir.Y.epsilon_2 = random(vec3(1.0), initSeed + float(bounce + 2) * 36.23);
    localReservoir.Y.k = bounce;
    localReservoir.Y.J = jacobian;
    localReservoir.W_Y = W;
    localReservoir.w_sum = W;
    localReservoir.c = 1.0;
    return localReservoir;
}

void main() {
    Reservoir r = tracePath(initialRay, uEye);
    out_ReservoirData1 = packReservoir1(r);
    out_ReservoirData2 = packReservoir2(r);
    out_ReservoirData3 = packReservoir3(r);
}
