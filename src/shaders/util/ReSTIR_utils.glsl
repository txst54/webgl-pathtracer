//begin_macro{RESTIR_UTIL}
vec2 getPrevUV(Isect isect) {
    vec4 pWorld = vec4(isect.position, 1.0);
    vec4 clip_prev = uProjMatPrev * uViewMatPrev * pWorld;
    if (clip_prev.w < epsilon) {
        return vec2(-1.0); // invalid UV
    }
    vec3 ndc_prev = clip_prev.xyz / clip_prev.w;
    return ndc_prev.xy * 0.5 + 0.5; // convert to [0, 1] range
}


ReSTIR_Reservoir getTemporalNeighborFromTexture(Isect isectCenter,
    sampler2D reservoirData1, sampler2D reservoirData2, sampler2D depthMap, sampler2D normalMap) {
    ReSTIR_Reservoir r = initializeReservoir();
    vec2 uv_prev = getPrevUV(isectCenter);
    if (uv_prev.x < 0.0 || uv_prev.x >= 1.0 || uv_prev.y < 0.0 || uv_prev.y >= 1.0) {
        return r;
    }

    // fetch temporal neighbor
    vec4 uReservoirData1Vec = texture(reservoirData1, uv_prev);
    vec4 uReservoirData2Vec = texture(reservoirData2, uv_prev);
    vec4 candidatePosition = texture(depthMap, uv_prev);
    vec4 candidateNormal = texture(uNormalMap, uv_prev);
    ReSTIR_Reservoir r_prev = unpackReservoir(uReservoirData1Vec, uReservoirData2Vec);

    if (r_prev.W_Y < epsilon ||
        length(candidatePosition.xyz - isectCenter.position) > epsilon ||
        dot(candidateNormal.xyz, isectCenter.normal) < (1.0 - epsilon)
    ) {
        return r;
    }

    return r_prev;
}

ReSTIRGI_Reservoir getTemporalNeighborFromTextureGI(Isect isectCenter,
    sampler2D reservoirData1, sampler2D reservoirData2, sampler2D depthMap) {
    ReSTIRGI_Reservoir r = initializeReservoirGI();
    vec2 uv_prev = getPrevUV(isectCenter);
    if (uv_prev.x < 0.0 || uv_prev.x >= 1.0 || uv_prev.y < 0.0 || uv_prev.y >= 1.0) {
        return r;
    }

    // fetch temporal neighbor
    vec4 uReservoirData1Vec = texture(reservoirData1, uv_prev);
    vec4 uReservoirData2Vec = texture(reservoirData2, uv_prev);
    vec4 candidatePosition = texture(depthMap, uv_prev);
    ReSTIRGI_Reservoir r_prev = unpackReservoirGI(uReservoirData1Vec, uReservoirData2Vec);

    if (r_prev.W_Y < epsilon || length(candidatePosition.xyz - isectCenter.position) > epsilon) {
        return r;
    }

    return r_prev;
}

ReSTIR_Reservoir resample_temporal_base(ReSTIR_Reservoir r_current, ReSTIR_Reservoir r_prev, Isect isectCenter, float seed, float neighborTargetFunctionAtCenter, out bool acceptCurrent) {
    ReSTIR_Reservoir r_out = initializeReservoir();
    float misWeight;
    float reservoirWeight;
    float reservoirStrategy;
    vec3 centerBrdf = isectCenter.albedo / PI;
    float centerTargetFunctionAtCenter = r_current.p_hat;

    ReSTIR_Reservoir[2] reservoirs = ReSTIR_Reservoir[2](r_prev, r_current);
    float[2] targetFunctions = float[2](neighborTargetFunctionAtCenter, centerTargetFunctionAtCenter);
    acceptCurrent = false;
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
            acceptCurrent = i == 1; // accept the current reservoir if it's the second one (center)
        }
    }

    r_out.W_Y = r_out.w_sum / r_out.p_hat;
    return r_out;
}

ReSTIR_Reservoir resample_temporal(ReSTIR_Reservoir r_current, ReSTIR_Reservoir r_prev, Isect isectCenter, float seed) {
    bool acceptCurrent;
    vec3 centerBrdf = isectCenter.albedo / PI;
    float neighborTargetFunctionAtCenter = evaluate_target_function_at_center(r_prev.Y, isectCenter, centerBrdf);
    return resample_temporal_base(r_current, r_prev, isectCenter, seed, neighborTargetFunctionAtCenter, acceptCurrent);
}

ReSTIRGI_Reservoir resample_temporalGI(ReSTIRGI_Reservoir r_current, ReSTIRGI_Reservoir r_prev, Isect isectCenter, float seed) {
    bool acceptCurrent;
    vec3 brdf = isectCenter.albedo / PI;
    float neighborTargetFunctionAtCenter = evaluateTargetFunctionAtCenterGI(r_prev, isectCenter, brdf);
    ReSTIRGI_Reservoir r_out_gi = initializeReservoirGI();
    ReSTIR_Reservoir r_out = resample_temporal_base(reservoirGIToDI(r_current), reservoirGIToDI(r_prev),
        isectCenter, seed, neighborTargetFunctionAtCenter, acceptCurrent);
    if (acceptCurrent) {
        r_out_gi = r_current;
    } else {
        r_out_gi = r_prev;
    }
    r_out_gi.W_Y = r_out.W_Y;
    return r_out_gi;
}
//end_macro
//begin_macro{RESTIR_EQ_UTIL}
vec3 evaluateRadianceAtCenterGI(ReSTIRGI_Reservoir r, Isect isect, vec3 brdf) {
    vec3 nextRay = normalize(r.Y - isect.position);
    float ndotr = dot(isect.normal, nextRay);
    float pdfCosine = pdfCosineWeighted(nextRay, isect.normal);
    vec3 throughputMultiplier = brdf * ndotr / pdfCosine;
    return r.L * throughputMultiplier;
}

float evaluateTargetFunctionAtCenterGI(ReSTIRGI_Reservoir r, Isect isect, vec3 brdf) {
    vec3 radiance = evaluateRadianceAtCenterGI(r, isect, brdf);
    return luminance(radiance);
}
//end_macro