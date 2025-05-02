#version 300 es
precision highp float;

uniform vec3 uEye;
uniform vec2 uRes;
uniform float uTime;
in vec3 initialRay;
out vec4 fragColor;
uniform sampler2D uReservoirData1;
uniform sampler2D uReservoirData2;

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

    vec4 uReservoirData1Vec = texture(uReservoirData1, coord);
    vec4 uReservoirData2Vec = texture(uReservoirData2, coord);

    Isect isect = intersect(ray, origin);
    if (isect.isLight) {
        fragColor = vec4(ReSTIR_lightEmission, 1.0);
        return;
    }
    ReSTIR_Reservoir r = unpackReservoir(uReservoirData1Vec, uReservoirData2Vec);
    ReSTIR_Reservoir r_out = r;
    float new_w_sum = r_out.w_sum;

    float randNum = random(vec3(1.0), gl_FragCoord.x * 29.57 + gl_FragCoord.y * 65.69 + uTime * 82.21);
    float M = 1.0;
    for (int dx = -2; dx <= 2; ++dx) {
        for (int dy = -2; dy <= 2; ++dy) {
            vec2 neighbor = gl_FragCoord.xy + vec2(dx, dy);
            if (neighbor == gl_FragCoord.xy ||
            neighbor.x < 0.0 || neighbor.y < 0.0 ||
            neighbor.x >= uRes.x || neighbor.y >= uRes.y) continue;

            vec2 uv = (neighbor + 0.5) / uRes;

            vec4 uCandidate1 = texture(uReservoirData1, uv);
            vec4 uCandidate2 = texture(uReservoirData2, uv);

            ReSTIR_Reservoir candidate = unpackReservoir(uCandidate1, uCandidate2);
            // generate X_i
            vec3 lightPos = candidate.Y;
            float p_light = compute_p(isect.position, lightPos);
            float p_hat = compute_p_hat(isect.position, lightPos, isect.normal, isect.albedo);

            float w = candidate.W_Y;

            if (w <= 0.0) continue;

            new_w_sum += candidate.w_sum;
            if (randNum < w / new_w_sum) {
                r_out = candidate;
            }
        }
    }
    r_out.w_sum = new_w_sum;

    fragColor = vec4(r_out.Y * (r_out.W_Y <= epsilon ? 1.0 : r_out.W_Y), 1.0);
}
