// begin_macro{RESERVOIR_LIB}

struct Reservoir {
    vec3 x_it;       // Light sample direction or position (X_i^t)
    float weight;      // Importance weight (W_X_i^t)
    float sumWeight;   // Sum of weights over all candidates
    int count;         // Number of samples seen
};

Reservoir initializeReservoir() {
    Reservoir r;
    r.x_it = vec3(0.0);
    r.weight = 0.0;
    r.sumWeight = 0.0;
    r.count = 0;
    return r;
}

// end_macro