// begin_macro{RESTIRDI_TEMPORAL_RESAMPLING_LIB}

ReSTIR_Reservoir getTemporalNeighborDI(Isect isectCenter, ReSTIR_Reservoir r_current,
    sampler2D reservoirData1, sampler2D reservoirData2, sampler2D depthMap, sampler2D normalMap) {
    ReSTIR_Reservoir temporalNeighbor = getTemporalNeighborFromTexture(isectCenter,
        reservoirData1, reservoirData2, depthMap, normalMap);
    ReSTIR_Reservoir defaultReservoir = initializeReservoir();
    if (temporalNeighbor.W_Y < epsilon) {
        return defaultReservoir;
    }
    vec3 lightDir = normalize(temporalNeighbor.Y - isectCenter.position);
    vec3 rayOrigin = isectCenter.position + isectCenter.normal * epsilon;
    Isect visibilityCheck = intersect(lightDir, rayOrigin);

    // If we dont hit the light there is occlusion
    bool occlusionCheck = !visibilityCheck.isLight || abs(r_current.t - temporalNeighbor.t) > 0.1 * r_current.t;
    if (occlusionCheck) {
        return defaultReservoir;
    }
    return temporalNeighbor;
}

ReSTIR_Reservoir sampleLightsTemporalDI(vec3 ray, float seed, Isect isectCenter,
    sampler2D reservoirData1, sampler2D reservoirData2, sampler2D depthMap, sampler2D normalMap) {
    ReSTIR_Reservoir r_in = initializeReservoir();
    ReSTIR_Reservoir r_current = sample_lights_ris(r_in, isectCenter, ray, NB_BSDF, NB_LIGHT, seed);
    ReSTIR_Reservoir r_prev = getTemporalNeighborDI(isectCenter, r_current,
        reservoirData1, reservoirData2, depthMap, normalMap);

    if (r_prev.W_Y < epsilon) {
        return r_current;
    }

    ReSTIR_Reservoir r_out = resample_temporal(r_current, r_prev, isectCenter, seed);
    return r_out;
}
// end_macro