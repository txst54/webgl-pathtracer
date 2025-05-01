uniform vec2 uRes;
uniform sampler2D uReservoirSampleTex;
uniform sampler2D uReservoirMeta1Tex;
uniform sampler2D uReservoirMeta2Tex;
uniform float uTime;
uniform mat4 mWorld;
uniform mat4 mView;
uniform mat4 mProj;
layout(location = 0) out vec4 outReservoirSample; // stores X_i^t
layout(location = 1) out vec4 outReservoirMeta1;   // stores W, W_sum, M
layout(location = 2) out vec4 outReservoirMeta2;   // stores W, W_sum, M

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



    // Emit final radiance estimate
    gl_FragColor = vec4(selectedSample.rgb * selectedWSum, 1.0);
    outReservoirSample =  selectedSample; // e.g., light direction or position
    outReservoirMeta   = vec4(selectedWeight, totalWeightSum, M, 0.0);
}