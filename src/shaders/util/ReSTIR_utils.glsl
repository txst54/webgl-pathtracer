//begin_macro{RESTIR_UTIL}
ReSTIR_Reservoir getTemporalNeighbor(Isect isectCenter, sampler2D reservoirData1, sampler2D reservoirData2) {
    ReSTIR_Reservoir r = initializeReservoir();
    vec4 pWorld = vec4(isectCenter.position, 1.0);
    vec4 clip_prev = uProjMatPrev * uViewMatPrev * pWorld;
    if (clip_prev.w < epsilon) {
        return r;
    }
    vec3 ndc_prev = clip_prev.xyz / clip_prev.w;
    vec2 uv_prev = ndc_prev.xy * 0.5 + 0.5;
    if (uv_prev.x < 0.0 || uv_prev.x >= 1.0 || uv_prev.y < 0.0 || uv_prev.y >= 1.0) {
        return r;
    }

    // fetch temporal neighbor
    vec4 uReservoirData1Vec = texture(reservoirData1, uv_prev);
    vec4 uReservoirData2Vec = texture(reservoirData2, uv_prev);
    ReSTIR_Reservoir r_prev = unpackReservoir(uReservoirData1Vec, uReservoirData2Vec);

    if (r_prev.W_Y < epsilon) {
        return r;
    }

    return r_prev;
}

ReSTIR_Reservoir resample_temporal(ReSTIR_Reservoir r_current, ReSTIR_Reservoir r_prev, Isect isectCenter, float seed) {
    ReSTIR_Reservoir r_out = initializeReservoir();
    float misWeight;
    float reservoirWeight;
    float reservoirStrategy;
    vec3 centerBrdf = isectCenter.albedo / pi;
    float neighborTargetFunctionAtCenter = evaluate_target_function_at_center(r_prev.Y, isectCenter, centerBrdf);
    float centerTargetFunctionAtCenter = r_current.p_hat;

    ReSTIR_Reservoir[2] reservoirs = ReSTIR_Reservoir[2](r_prev, r_current);
    float[2] targetFunctions = float[2](neighborTargetFunctionAtCenter, centerTargetFunctionAtCenter);

    for (int i = 0; i < 2; i++) {
        if (targetFunctions[i] < epsilon) {
            continue;
        }
        // resample initial candidates
        misWeight = reservoirs[i].c * targetFunctions[i] / (r_prev.c * neighborTargetFunctionAtCenter + r_current.c * centerTargetFunctionAtCenter);
        reservoirWeight = misWeight * targetFunctions[i] * reservoirs[i].W_Y;
        r_out.w_sum += reservoirWeight;
        r_out.c += reservoirs[i].c;
        reservoirStrategy = random(vec3(67.71, 31.91, 83.17), seed + float(i));
        if (reservoirStrategy < reservoirWeight / r_out.w_sum) {
            r_out.p_hat = targetFunctions[i];
            r_out.Y = reservoirs[i].Y;
            r_out.t = reservoirs[i].t;
        }
    }

    r_out.W_Y = r_out.w_sum / r_out.p_hat;
    return r_out;
}
//end_macro