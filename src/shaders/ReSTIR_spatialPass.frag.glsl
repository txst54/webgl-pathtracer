#version 300 es
precision highp float;

uniform vec3 uEye;
uniform vec2 uRes;
uniform float uTime;
in vec3 initialRay;
out vec4 fragColor;
uniform sampler2D uReservoirData1;
uniform sampler2D uReservoirData2;

#define M 1
#define MAX_NEIGHBORS 25

// use_macro{RAND_LIB}
// use_macro{CONSTANTS}
// use_macro{SPHERE_LIB}
// use_macro{CUBE_LIB}
// use_macro{SCENE_LIB}
// use_macro{RAY_LIB}
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
    ReSTIR_Reservoir r_out = initializeReservoir();
    r_out.w_sum = 0.0;
    ReSTIR_Reservoir[MAX_NEIGHBORS] candidates;
    float sum_p_hat = 0.0;
    int count = 0;

    float randNum = random(vec3(1.0), gl_FragCoord.x * 29.57 + gl_FragCoord.y * 65.69 + uTime * 82.21);
    float startingSeed = gl_FragCoord.x * 29.57 + gl_FragCoord.y * 65.69 + uTime * 82.21;
    for (int dx = -2; dx <= 2; ++dx) {
        for (int dy = -2; dy <= 2; ++dy) {
            vec2 neighbor = gl_FragCoord.xy + vec2(dx, dy);
            if (neighbor.x < 0.0 || neighbor.y < 0.0 ||
            neighbor.x >= uRes.x || neighbor.y >= uRes.y) continue;

            vec2 uv = (neighbor + 0.5) / uRes;

            vec4 uCandidate1 = texture(uReservoirData1, uv);
            vec4 uCandidate2 = texture(uReservoirData2, uv);

            candidates[count] = unpackReservoir(uCandidate1, uCandidate2);
            if (abs(r.t - candidates[count].t) > 0.1 * r.t) continue;
            // generate X_i
            sum_p_hat += candidates[count].p_hat;
            r_out.c += candidates[count].c;
            count++;
        }
    }
    for (int i = 0; i < MAX_NEIGHBORS; i++) {
        if (i >= count) break;
        ReSTIR_Reservoir r_i = candidates[i];
        float m_i = r_i.p_hat/sum_p_hat;
        float p_hat_at_center = compute_p_hat(isect.position, r_i.Y, isect.normal, isect.albedo);
        float w_i = m_i * p_hat_at_center * r_i.W_Y;
        float randint = rand(r_i.Y.xy, startingSeed + float(i));
        r_out.w_sum += w_i;
        if (randint < w_i / r_out.w_sum) {
            r_out.Y = r_i.Y;
            r_out.p_hat = p_hat_at_center;
        }
    }
    r_out.W_Y = 1.0 / r_out.p_hat * r_out.w_sum;
    // ReSTIR_Reservoir r_out = resample(samples, contrib_weights, count, isect, randUV, 1, vec3(sum_p_hat));
    r_out.c = min(512.0, r_out.c);
    vec3 finalColor = shade_reservoir(r_out, isect);
    fragColor = vec4(finalColor, 1.0);
}