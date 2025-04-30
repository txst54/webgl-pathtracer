// Requires constants and must be inst. after sphere

// begin_macro{RAY_LIB}
vec3 cosineWeightedDirection(float seed, vec3 normal) {
    // Simple cosine-weighted random direction
    float u = random(vec3(12.9898, 78.233, 151.7182), seed);
    float v = random(vec3(63.7264, 10.873, 623.6736), seed);
    float r = sqrt(u);
    float angle = 6.28318530718 * v;
    vec3 sdir, tdir;
    if (abs(normal.x) < .5) {
        sdir = cross(normal, vec3(1,0,0));
    } else {
        sdir = cross(normal, vec3(0,1,0));
    }
    tdir = cross(normal, sdir);
    return r*cos(angle)*sdir + r*sin(angle)*tdir + sqrt(1.-u)*normal;
}

float pdfCosineWeighted(vec3 direction, vec3 normal) {
    float cosTheta = dot(direction, normal);
    if (cosTheta <= 0.0) return 0.0;
    return cosTheta / pi;
}

float shadow(vec3 origin, vec3 ray, vec3 sphereCenter, float sphereRadius) {
    float t = intersectSphere(origin, ray, sphereCenter, sphereRadius);
    if (t < 1.0) return 0.0;
    return 1.0;
}
// end_macro