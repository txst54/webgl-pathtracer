// begin_macro{RESTIRGI_RESERVOIR_LIB}
struct ReSTIRGI_Reservoir {
    vec3 Y;      // sample position (x2)
    float W_Y;   // selected sample weight
    vec3 L;     // indirect light contribution
    float c;    //sample count
};

ReSTIRGI_Reservoir initializeReservoirGI() {
    ReSTIRGI_Reservoir r;
    r.Y = vec3(0.0);
    r.W_Y = 0.0;
    r.L = vec3(0.0);
    r.c = 0.0;

    return r;
}

ReSTIRGI_Reservoir unpackReservoirGI(vec4 data1, vec4 data2) {
    ReSTIRGI_Reservoir r;
    r.Y = data1.rgb;        // using .rgb for vec3
    r.W_Y = data1.a;
    r.L = data2.rgb;        // using .rgb for vec3
    r.c = data2.a;
    return r;
}

vec4 packReservoirGI1(ReSTIRGI_Reservoir r) {
    return vec4(r.Y, r.W_Y);
}

vec4 packReservoirGI2(ReSTIRGI_Reservoir r) {
    return vec4(r.L, r.c); // zero pad unused values
}

ReSTIR_Reservoir reservoirGIToDI(ReSTIRGI_Reservoir r_in) {
    ReSTIR_Reservoir r;
    r.Y = r_in.Y;
    r.W_Y = r_in.W_Y;
    r.p_hat = dot(r_in.L, vec3(0.3086, 0.6094, 0.0820));
    r.w_sum = 0.0; // w_sum is not used in GI
    r.t = 0.0; // t is not used in GI
    r.c = r.c; // c is the sample count
    return r;
}

float luminance(vec3 contrib) {
    return dot(contrib, vec3(0.3086, 0.6094, 0.0820));
}
// end_macro