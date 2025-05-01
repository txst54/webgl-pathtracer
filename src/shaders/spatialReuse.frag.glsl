uniform vec2 uRes;
uniform sampler2D uReservoirData1;
uniform sampler2D uReservoirData2;
uniform sampler2D uReservoirData3;
uniform float uTime;
// layout(location = 0) out vec4 outReservoirSample; // stores X_i^t
// layout(location = 1) out vec4 outReservoirMeta;   // stores W, W_sum, M

// use_macro{RAND_LIB}


void main() {
    vec2 coord = (gl_FragCoord.xy + 0.5) / uRes;
    vec4 uReservoirData1Vec = texture2D(uReservoirData1, coord);
    vec4 uReservoirData2Vec = texture2D(uReservoirData2, coord);
    vec4 uReservoirData3Vec = texture2D(uReservoirData3, coord);
    Reservoir r = unpackReservoir(uReservoirData1Vec, uReservoirData2Vec, uReservoirData3Vec);
    Reservoir r_out = r;
    float new_w_sum = r_out.w_sum;
    float randNum = random(vec3(1.0), gl_FragCoord.x * 29.57 + gl_FragCoor.y * 65.69 + uTime * 82.21);
    float M = 1.0; // how many neigbors we checked

    for (int dx = -1; dx <= 1; ++dx) {
        for (int dy = -1; dy <= 1; ++dy) {
            vec2 neighbor = vec2(gl_FragCoord.xy) + vec2(dx, dy);
            if (neighbor == vec2(gl_FragCoord.xy) ||
                neighbor.x < 0 || neighbor.y < 0 ||
                neighbor.x >= uRes.x || neighbor.y >= uRes.y) continue;
            vec2 uv = (neighbor + 0.5) / uRes;
            vec4 uCandidate1 = texture2D(uReservoirData1, uv);
            vec4 uCandidate2 = texture2D(uReservoirData2, uv);
            vec4 uCandidate3 = texture2D(uReservoirData3, uv);
            Reservoir candidate = unpackReservoir(uCandidate1, uCandidate2, uCandidate3);
            float w = candidate.W_Y;
            if (w <= 0.0) continue;

            new_w_sum += w;
            if (randNum < w / new_w_sum) {
                r_out = candidate;
                r_out.w_sum = new_w_sum;
            }
        }
    }

    // Emit final radiance estimate
    gl_FragColor = vec4(r_out.Y.rc_vertex.L * r_out.W_Y, 1.0);
}