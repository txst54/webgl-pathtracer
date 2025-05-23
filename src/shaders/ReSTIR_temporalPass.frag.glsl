#version 300 es
precision highp float;

uniform vec3 uEye;
uniform vec2 uRes;
uniform float uTime;
uniform mat4 viewMat_prev;
in vec3 initialRay;

// previous state data
uniform sampler2D uReservoirData1;
uniform sampler2D uReservoirData2;

layout(location = 0) out vec4 out_ReservoirData1;
layout(location = 1) out vec4 out_ReservoirData2;

#define M 10       // Increase total number of samples for better convergence
#define M1 5       // num of bsdf sampled candidates
#define M2 5       // num of light candidates
#define PI 3.14159265359

// Assuming the macro expansions from your original shader
// use_macro{CONSTANTS}
// use_macro{SPHERE_LIB}
// use_macro{CUBE_LIB}
// use_macro{SCENE_LIB}
// use_macro{RESTIR_RESERVOIR_LIB}
// use_macro{RAND_LIB}
// use_macro{RAY_LIB}
// use_macro{RIS_UTIL}

void main() {
    vec3 ray = normalize(initialRay);
    vec3 origin = uEye;

    vec2 randUV = gl_FragCoord.xy / uRes;
    float jitterSeed = uTime * 1234.5678;
    randUV += vec2(rand(randUV, jitterSeed), rand(randUV, jitterSeed + 1.0)) * 0.001;

    Isect isect = intersect(ray, origin);

    vec3[M] samples;
    float[M] contrib_weights;
    random_samples(samples, contrib_weights, isect, randUV);
    ReSTIR_Reservoir r = resample(samples, contrib_weights, M, isect, randUV, 0, vec3(0.0));

    vec4 homoWorld = vec4(isect.position, 1.0);
    vec4 clip_prev = viewMat_prev * homoWorld;
    if (clip_prev.w < 0.001) {
        out_ReservoirData1 = packReservoir1(r);
        out_ReservoirData2 = packReservoir2(r);
        return;
    }
    vec3 ndc_prev = clip_prev.xyz / clip_prev.w;
    vec2 uv_prev = ndc_prev.xy * 0.5 + 0.5;
    if (uv_prev.x < 0.0 || uv_prev.x >= 1.0 || uv_prev.y < 0.0 || uv_prev.y >= 1.0) {
        out_ReservoirData1 = packReservoir1(r);
        out_ReservoirData2 = packReservoir2(r);
        return;
     }
    vec4 uReservoirData1Vec = texture(uReservoirData1, uv_prev);
    vec4 uReservoirData2Vec = texture(uReservoirData2, uv_prev);
    ReSTIR_Reservoir r_prev = unpackReservoir(uReservoirData1Vec, uReservoirData2Vec);
    vec3[M] r_samples;
    r_samples[0] = r.Y;
    r_samples[1] = r_prev.Y;
    float[M] r_contrib_weights;
    r_contrib_weights[0] = r.W_Y;
    r_contrib_weights[1] = r_prev.W_Y;
    float m_denom = r.p_hat + r_prev.p_hat * r_prev.c;
    randUV += vec2(rand(randUV, jitterSeed), rand(randUV, jitterSeed + 1.0)) * 0.001;
    ReSTIR_Reservoir r_out = resample(r_samples, r_contrib_weights, 2, isect, randUV, 2, vec3(r_prev.c, m_denom, 0.0));
    r_out.c = min(r_prev.c + 1.0, 512.0);
    out_ReservoirData1 = packReservoir1(r_out);
    out_ReservoirData2 = packReservoir2(r_out);

}
