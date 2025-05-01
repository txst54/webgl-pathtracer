uniform vec2 uRes;
uniform sampler2D uReservoirSampleTex;
uniform sampler2D uReservoirMetaTex;
uniform float uTime;
layout(location = 0) out vec4 outReservoirSample; // stores X_i^t
layout(location = 1) out vec4 outReservoirMeta;   // stores W, W_sum, M

// use_macro{RAND_LIB}


void main() {
    ivec2 coord = ivec2(gl_FragCoord.xy);
    vec4 sampleData = texelFetch(uReservoirSampleTex, coord, 0);
    vec4 metaData   = texelFetch(uReservoirMetaTex, coord, 0);

    vec4 selectedSample = sampleData;
    float selectedWeight = metaData.r;   // W_i (initial)
    float selectedWSum   = metaData.g;   // W_sum_i
    float totalWeightSum = selectedWeight;
    float M = 1.0; // how many neigbors we checked

    for (int dx = -1; dx <= 1; ++dx) {
        for (int dy = -1; dy <= 1; ++dy) {
            ivec2 neighbor = coord + ivec2(dx, dy);
            if (neighbor == coord) continue; // skip self
            if (neighbor.x < 0 || neighbor.y < 0 || neighbor.x >= uRes.x || neighbor.y >= uRes.y) continue;
            vec4 sampleN = texelFetch(uReservoirSampleTex, neighbor, 0);
            vec4 metaN   = texelFetch(uReservoirMetaTex, neighbor, 0);
            if ((abs(selectedSample.a - sampleN.a)) / selectedSample.a > 0.1) continue; // this neighbor isnt very neighborly
            float Wj     = metaN.r;   // candidate's weight
            float WsumJ  = metaN.g;   // for later use if selected
            M += 1.0;

            float r = random(vec3(neighbor.x * 3.1, neighbor.y * 7.3, Wj * 3.83), uTime);
            if (r < Wj / (totalWeightSum + Wj)) {
                selectedSample = sampleN;
                selectedWeight = Wj;
                selectedWSum = WsumJ;
            }
            totalWeightSum += Wj;
        }
    }

    // Emit final radiance estimate
    gl_FragColor = vec4(selectedSample.rgb * selectedWSum, 1.0);
    outReservoirSample =  selectedSample; // e.g., light direction or position
    outReservoirMeta   = vec4(selectedWeight, totalWeightSum, M, 0.0);
}