// begin_macro{RESTIR_RESERVOIR_LIB}

struct ReSTIR_Reservoir {
    vec3 Y;      // light direction or position
    float W_Y;   // selected sample weight
    float w_sum; // total weight of all candidates
};

ReSTIR_Reservoir initializeReservoir() {
    ReSTIR_Reservoir r;
    r.Y = vec3(0.0);
    r.W_Y = 0.0;
    r.w_sum = 0.0;
    return r;
}

ReSTIR_Reservoir unpackReservoir(vec4 data1, vec4 data2) {
    ReSTIR_Reservoir r;
    r.Y = data1.rgb;        // using .rgb for vec3
    r.W_Y = data2.r;
    r.w_sum = data2.g;
    return r;
}

vec4 packReservoir1(ReSTIR_Reservoir r) {
    return vec4(r.Y, 1.0); // 1.0 is a placeholder alpha
}

vec4 packReservoir2(ReSTIR_Reservoir r) {
    return vec4(r.W_Y, r.w_sum, 0.0, 0.0); // zero pad unused values
}

// end_macro
