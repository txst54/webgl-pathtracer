#version 300 es
precision highp float;

uniform vec3 uEye, uRay00, uRay01, uRay10, uRay11;
uniform vec2 uRes;
uniform float uTime;
uniform mat4 uViewMatPrev;
uniform mat4 uProjMatPrev;
in vec3 initialRay;

// previous state data
uniform sampler2D uReservoirData1;
uniform sampler2D uReservoirData2;

layout(location = 0) out vec4 out_ReservoirData1;
layout(location = 1) out vec4 out_ReservoirData2;
layout(location = 2) out vec4 fragColor;

#define M1 5       // num of bsdf sampled candidates
#define M2 5       // num of light candidates
#define PI 3.14159265359
#define NB_BSDF 10
#define NB_LIGHT 10

// Assuming the macro expansions from your original shader
// use_macro{CONSTANTS}
// use_macro{SPHERE_LIB}
// use_macro{CUBE_LIB}
// use_macro{SCENE_LIB}
// use_macro{RESTIR_RESERVOIR_LIB}
// use_macro{RAND_LIB}
// use_macro{RAY_LIB}
// use_macro{RIS_UTIL}
// use_macro{DIRECT_LIGHT_RESTIR}
// use_macro{DIRECT_LIGHT_RIS}

void main() {
    vec3 ray = normalize(initialRay);
    vec3 origin = uEye;
    fragColor = vec4(0.0);

    float timeEntropy = hashValue(uTime);
    float seed = hashCoords(gl_FragCoord.xy + timeEntropy * vec2(1.0, -1.0));
    float total_dist = 0.0;

    Isect isect = intersect(ray, origin);
    ReSTIR_Reservoir r_current = sample_lights_ris(isect, ray, NB_BSDF, NB_LIGHT, seed);
    ReSTIR_Reservoir r_out = initializeReservoir();

    vec4 pWorld = vec4(isect.position, 1.0);
    vec4 clip_prev = uProjMatPrev * uViewMatPrev * pWorld;
    if (clip_prev.w < epsilon) {
        out_ReservoirData1 = packReservoir1(r_current);
        out_ReservoirData2 = packReservoir2(r_current);
        fragColor = vec4(vec3(0.5), 1.0);
        return;
    }
    vec3 ndc_prev = clip_prev.xyz / clip_prev.w;
    vec2 uv_prev = ndc_prev.xy * 0.5 + 0.5;
    if (uv_prev.x < 0.0 || uv_prev.x >= 1.0 || uv_prev.y < 0.0 || uv_prev.y >= 1.0) {
        out_ReservoirData1 = packReservoir1(r_current);
        out_ReservoirData2 = packReservoir2(r_current);
        fragColor = vec4(1.0, 1.0, 1.0, 1.0);
        return;
     }

    // fetch temporal neighbor
    vec4 uReservoirData1Vec = texture(uReservoirData1, uv_prev);
    vec4 uReservoirData2Vec = texture(uReservoirData2, uv_prev);
    ReSTIR_Reservoir r_prev = unpackReservoir(uReservoirData1Vec, uReservoirData2Vec);

    if (r_prev.W_Y < epsilon) {
        out_ReservoirData1 = packReservoir1(r_current);
        out_ReservoirData2 = packReservoir2(r_current);
        fragColor = vec4(0.5, 0.0, 0.0, 1.0); // maroon
        return;
    }

    vec3 lightDir = normalize(r_prev.Y - isect.position);
    float lightDistance = length(r_prev.Y - isect.position);

    vec3 rayOrigin = isect.position + isect.normal * epsilon;
    Isect visibilityCheck = intersect(lightDir, rayOrigin);

    // If we dont hit the light there is occlusion
    if (!visibilityCheck.isLight || abs(r_current.t - r_prev.t) > 0.1 * r_current.t) {
        out_ReservoirData1 = packReservoir1(r_current);
        out_ReservoirData2 = packReservoir2(r_current);
        float diff = abs(r_current.t - r_prev.t) / r_current.t * 10.0;
        fragColor = vec4(0.0, 0.0, 1.0, 1.0); // blue
        return;
    }

    float misWeight;
    float reservoirWeight;
    float reservoirStrategy;
    vec3 centerBrdf = isect.albedo / pi;
    float neighborTargetFunctionAtCenter = evaluate_target_function_at_center(r_prev.Y, isect, centerBrdf);
    float centerTargetFunctionAtCenter = r_current.p_hat;

    // resample temporal neighbor
    misWeight = neighborTargetFunctionAtCenter / (neighborTargetFunctionAtCenter + centerTargetFunctionAtCenter);
    reservoirWeight = misWeight * neighborTargetFunctionAtCenter * r_prev.W_Y;
    r_out.w_sum += reservoirWeight;
    reservoirStrategy = random(vec3(67.71, 31.91, 83.17), seed);
    if (reservoirStrategy < reservoirWeight / r_out.w_sum) {
        r_out.p_hat = neighborTargetFunctionAtCenter;
        r_out.Y = r_prev.Y;
        r_out.t = r_prev.t;
        fragColor = vec4(1.0, 0.0, 0.0, 1.0); // red temporal
    }

    // resample initial candidates
    misWeight = centerTargetFunctionAtCenter / (neighborTargetFunctionAtCenter + centerTargetFunctionAtCenter);
    reservoirWeight = misWeight * centerTargetFunctionAtCenter * r_current.W_Y;
    r_out.w_sum += reservoirWeight;
    reservoirStrategy = random(vec3(67.71, 31.91, 83.17), seed + 1.0);
    if (reservoirStrategy < reservoirWeight / r_out.w_sum) {
        r_out.p_hat = centerTargetFunctionAtCenter;
        r_out.Y = r_current.Y;
        r_out.t = r_current.t;
        fragColor = vec4(0.0, 1.0, 0.0, 1.0); // current
    }

    r_out.W_Y = r_out.w_sum / r_out.p_hat;
    out_ReservoirData1 = packReservoir1(r_out);
    out_ReservoirData2 = packReservoir2(r_out);
    if (fragColor == vec4(0.0)) {
        fragColor = vec4(0.0, 1.0, 0.0, 1.0);
    }
}
