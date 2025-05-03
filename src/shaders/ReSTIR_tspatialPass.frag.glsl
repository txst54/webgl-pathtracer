#version 300 es
precision highp float;

uniform vec3 uEye;
uniform vec2 uRes;
uniform float uTime;
in vec3 initialRay;
layout(location = 2) out vec4 fragColor;
uniform sampler2D uReservoirData1;
uniform sampler2D uReservoirData2;

layout(location = 0) out vec4 out_ReservoirData1;
layout(location = 1) out vec4 out_ReservoirData2;

#define M 10

// use_macro{RAND_LIB}
// use_macro{CONSTANTS}
// use_macro{SPHERE_LIB}
// use_macro{CUBE_LIB}
// use_macro{SCENE_LIB}
// use_macro{RESTIR_RESERVOIR_LIB}
// use_macro{RIS_UTIL}

void main() {
    vec2 coord = (gl_FragCoord.xy + 0.5) / uRes;
    vec3 ray = normalize(initialRay);
    vec3 origin = uEye;

    vec2 randUV = gl_FragCoord.xy / uRes;
    float jitterSeed = uTime * 1234.5678;
    randUV += vec2(rand(randUV, jitterSeed), rand(randUV, jitterSeed + 1.0)) * 0.001;

    vec4 uReservoirData1Vec = texture(uReservoirData1, coord);
    vec4 uReservoirData2Vec = texture(uReservoirData2, coord);
    ReSTIR_Reservoir r = unpackReservoir(uReservoirData1Vec, uReservoirData2Vec);
    Isect isect = intersect(ray, origin);
    if (isect.isLight) {
        fragColor = vec4(ReSTIR_lightEmission, 1.0);
        return;
    }
    vec3[M] samples;
    float[M] contrib_weights;
    float sum_p_hat = 0.0;
    int count;
    float rout_c;

    float randNum = random(vec3(1.0), gl_FragCoord.x * 29.57 + gl_FragCoord.y * 65.69 + uTime * 82.21);
    for (int dx = -1; dx <= 1; ++dx) {
        for (int dy = -1; dy <= 1; ++dy) {
            vec2 neighbor = gl_FragCoord.xy + vec2(dx, dy);
            if (neighbor.x < 0.0 || neighbor.y < 0.0 ||
            neighbor.x >= uRes.x || neighbor.y >= uRes.y) continue;

            vec2 uv = (neighbor + 0.5) / uRes;

            vec4 uCandidate1 = texture(uReservoirData1, uv);
            vec4 uCandidate2 = texture(uReservoirData2, uv);

            ReSTIR_Reservoir candidate = unpackReservoir(uCandidate1, uCandidate2);
            // if (abs(r.t - candidate.t) > 0.1) continue;
            // generate X_i
            if (count < M) {
                samples[count] = candidate.Y;
                contrib_weights[count] = candidate.W_Y;
                sum_p_hat += candidate.p_hat;
                rout_c += candidate.c;
                count++;
            }
        }
    }
    ReSTIR_Reservoir r_out = resample(samples, contrib_weights, count, isect, randUV, 1, vec3(sum_p_hat));
    r_out.c = min(512.0, rout_c);
    vec3 finalColor = shade_reservoir(r_out, isect);
    fragColor = vec4(finalColor, 1.0);
    out_ReservoirData1 = packReservoir1(r_out);
    out_ReservoirData2 = packReservoir2(r_out);
}