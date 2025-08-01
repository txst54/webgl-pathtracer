// begin_macro{CUBE_LIB}
vec2 intersectCube(vec3 origin, vec3 ray, vec3 cubeMin, vec3 cubeMax) {
    vec3 tMin = (cubeMin - origin) / ray;
    vec3 tMax = (cubeMax - origin) / ray;
    vec3 t1 = min(tMin, tMax);
    vec3 t2 = max(tMin, tMax);
    float tNear = max(max(t1.x, t1.y), t1.z);
    float tFar = min(min(t2.x, t2.y), t2.z);
    return vec2(tNear, tFar);
}

bool intersectBoundingBox(vec3 origin, vec3 ray, vec3 cubeMin, vec3 cubeMax) {
    vec2 t = intersectCube(origin, ray, cubeMin, cubeMax);
    // near < far
    return t.x < t.y && t.y > 0.0;
}

vec3 normalForCube(vec3 hit, vec3 cubeMin, vec3 cubeMax) {
    if (hit.x < cubeMin.x + epsilon)
    return vec3(-1.0, 0.0, 0.0);
    else if (hit.x > cubeMax.x - epsilon)
    return vec3(1.0, 0.0, 0.0);
    else if (hit.y < cubeMin.y + epsilon)
    return vec3(0.0, -1.0, 0.0);
    else if (hit.y > cubeMax.y - epsilon)
    return vec3(0.0, 1.0, 0.0);
    else if (hit.z < cubeMin.z + epsilon)
    return vec3(0.0, 0.0, -1.0);
    else
    return vec3(0.0, 0.0, 1.0);
}
// end_macro