#version 300 es
precision highp float;

uniform vec3 uEye;
uniform vec2 uRes;
uniform float uTime;
in vec3 initialRay;

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
    int count;
    random_samples(samples, contrib_weights, count, isect, randUV);
    ReSTIR_Reservoir r = resample(samples, contrib_weights, count, isect, randUV, 0, 0.0);
    out_ReservoirData1 = packReservoir1(r);
    out_ReservoirData2 = packReservoir2(r);
}
