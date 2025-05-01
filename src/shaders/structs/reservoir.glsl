// begin_macro{RESERVOIR_LIB}

struct RCVertex {
    float w;
    vec3 L;
    // todo add triangle Id, barycentric tuple, lobe indices
};

struct Sample_Y {
    RCVertex rc_vertex;
    float epsilon_1;
    float epsilon_2;
    int k;
    float J;
};

struct Reservoir {
    Sample_Y Y;
    float W_Y;
    float w_sum;
    float c;
    float t;
};

Reservoir initializeReservoir() {
    Reservoir r;
    r.Y.rc_vertex.w = 0.0;
    r.Y.rc_vertex.L = vec3(0.0);
    r.Y.epsilon_1 = 0.0;
    r.Y.epsilon_2 = 0.0;
    r.Y.k = 0;
    r.Y.J = 0.0;
    r.W_Y = 0.0;
    r.w_sum = 0.0;
    r.c = 0.0;
    return r;
}

Reservoir unpackReservoir(vec4 uReservoirData1Vec, vec4 uReservoirData2Vec, vec4 uReservoirData3Vec) {
    Reservoir r;
    r.Y.rc_vertex.w = uReservoirData1Vec.r;
    r.Y.rc_vertex.L = uReservoirData1Vec.gba;
    r.Y.epsilon_1 = uReservoirData2Vec.r;
    r.Y.epsilon_2 = uReservoirData2Vec.g;
    r.Y.k = int(uReservoirData2Vec.b);
    r.Y.J = uReservoirData2Vec.a;
    r.W_Y = uReservoirData3Vec.r;
    r.w_sum = uReservoirData3Vec.g;
    r.c = uReservoirData3Vec.b;
    r.t = uReservoirData3Vec.a;
    return r;
}

vec4 packReservoir1(Reservoir r) {
    return vec4(
    r.Y.rc_vertex.w,
    r.Y.rc_vertex.L.r,
    r.Y.rc_vertex.L.g,
    r.Y.rc_vertex.L.b
    );
}

vec4 packReservoir2(Reservoir r) {
    return vec4(
    r.Y.epsilon_1,
    r.Y.epsilon_2,
    float(r.Y.k),
    r.Y.J
    );
}

vec4 packReservoir3(Reservoir r) {
    return vec4(
    r.W_Y,
    r.w_sum,
    r.c,
    r.t
    );
}

// end_macro