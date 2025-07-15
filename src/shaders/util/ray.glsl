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
    return normalize(r*cos(angle)*sdir + r*sin(angle)*tdir + sqrt(1.-u)*normal);
}

vec3 uniformSpherePos(vec3 origin, float seed, vec3 center, float radius) {
    float u = random(vec3(12.9898, 78.233, 151.7182), seed);
    float v = random(vec3(63.7264, 10.873, 623.6736), seed);
    float theta = 2.0 * PI * u;
    float phi = acos(2.0 * v - 1.0);
    vec3 lightPoint = center + radius * vec3(cos(theta) * sin(phi), sin(theta) * sin(phi), cos(phi));
    return lightPoint;
}

vec3 uniformSphereDirection(vec3 origin, float seed, vec3 center, float radius) {
    vec3 lightPoint = uniformSpherePos(origin, seed, center, radius);
    return normalize(lightPoint - origin);
}

float pdfCosineWeighted(vec3 direction, vec3 normal) {
    float cosTheta = dot(direction, normal);
    if (cosTheta <= 0.0) return epsilon;
    return cosTheta / PI;
}

float pdfUniformSphere(vec3 direction, vec3 origin) {
    Isect isect = intersect(direction, origin);
    if (isect.isLight) {
        vec3 fromLightDir = -direction;
        float dist2 = dot(fromLightDir, fromLightDir);
        fromLightDir = normalize(fromLightDir);
        vec3 lightNormal = normalize(isect.position - light);
        float cosAtLight = clamp(dot(lightNormal, fromLightDir), 0., 1.);
        if (cosAtLight < epsilon || dist2 < epsilon) return epsilon;
        float surfaceArea = 4.0 * PI * lightSize * lightSize;
        float pdfArea = 1.0 / surfaceArea;
        // Conversion factor from area to solid angle pdf is cos(theta)/dist2 and you divide by conversion factor
        float pArea =  pdfArea * dist2 / cosAtLight;
        return pArea;
    }
    return epsilon;
}

float shadow(vec3 origin, vec3 ray, vec3 sphereCenter, float sphereRadius) {
    float t = intersectSphere(origin, ray, sphereCenter, sphereRadius);
    if (t < 1.0) return 0.0;
    return 1.0;
}

float balanceHeuristic(float pdf_a, float nb_pdf_a, float pdf_b, float nb_pdf_b) {
    return pdf_a / (nb_pdf_a * pdf_a + nb_pdf_b * pdf_b + epsilon);
}

// end_macro