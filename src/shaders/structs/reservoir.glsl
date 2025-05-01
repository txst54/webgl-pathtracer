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

// end_macro