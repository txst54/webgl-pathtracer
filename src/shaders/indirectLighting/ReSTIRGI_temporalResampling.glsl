// begin_macro{RESTIRGI_TEMPORAL_RESAMPLING_LIB}
ReSTIR_Reservoir getTemporalNeighborGI(Isect isectCenter, ReSTIR_Reservoir r_current, sampler2D reservoirData1, sampler2D reservoirData2) {
    ReSTIR_Reservoir temporalNeighbor = getTemporalNeighbor(isectCenter, reservoirData1, reservoirData2);
    ReSTIR_Reservoir defaultReservoir = initializeReservoir();
    if (temporalNeighbor.W_Y < epsilon) {
        return defaultReservoir;
    }
    vec3 rayDir = normalize(temporalNeighbor.Y - isectCenter.position);
    float rayDist = length(temporalNeighbor.Y - isectCenter.position);
    vec3 rayOrigin = isectCenter.position + isectCenter.normal * epsilon;
    Isect visibilityCheck = intersect(rayDir, rayOrigin);

    // if we dont hit the sample spot, there is occlusion
    if (abs(length(visibilityCheck.position - temporalNeighbor.Y) - rayDist) > 0.1 * rayDist) {
        return defaultReservoir;
    }
    return temporalNeighbor;
}

ReSTIR_Reservoir sampleLightsTemporalGI(vec3 ray, float seed, Isect isectCenter, sampler2D reservoirData1, sampler2D reservoirData2) {
    ReSTIR_Reservoir r_in = initializeReservoir();
    ReSTIR_Reservoir r_current = sample_lights_ris(r_in, isectCenter, ray, NB_BSDF, NB_LIGHT, seed);
    ReSTIR_Reservoir r_prev = getTemporalNeighborDI(isectCenter, r_current, reservoirData1, reservoirData2);

    if (r_prev.W_Y < epsilon) {
        return r_current;
    }

    ReSTIR_Reservoir r_out = resample_temporal(r_current, r_prev, isectCenter, seed);
    return r_out;
}
// end_macro