// Must import constants with this macro and cube/sphere

// begin_macro{SCENE_LIB}
struct Isect {
    float t; // Distance along the ray
    vec3 position;
    vec3 normal;
    vec3 albedo; // Simplified material color
    bool isLight; // Is the hit surface a light source?
    // vec3 emission; // Light emission color
    float pdf; // PDF of sampling this hit (e.g., light sampling PDF)
};

Isect intersect(vec3 ray, vec3 origin) {
    Isect isect;
    ray = normalize(ray);
    vec2 tRoom = intersectCube(origin, ray, roomCubeMin, roomCubeMax);
    // float tSphere = intersectSphere(origin, ray, sphereCenter, sphereRadius);
    float tLight = intersectSphere(origin, ray, light, lightSize);
    // vec2 tWall = intersectCube(origin, ray, wallCubeMin, wallCubeMax);
    #ifdef HAS_TRIMESH
    vec3 nObj = vec3(0.0, 0.0, 0.0);
    float tObj = intersectTrimesh(origin, ray, nObj);
    // float tObj = INFINITY;
    // float tObj = intersectBruteForce(origin, ray, uSceneAllVertices, nObj);
    #endif
    float t = infinity;
     if (tRoom.x < tRoom.y) t = tRoom.y;
//     if (tWall.x < tWall.y && tWall.x > epsilon && tWall.x < t) t = tWall.x;
//     if (tSphere < t) t = tSphere;
    if (tLight < t) t = tLight;
    #ifdef HAS_TRIMESH
    if (tObj < t) t = tObj;
    #endif

    isect.t = t;
    isect.albedo = WHITECOLOR;
    isect.position = origin + ray * t;
    // float specularHighlight = 0.0;

    if (t == infinity) {
        return isect;
    }

    if (t == tRoom.y) {
        isect.normal = -normalForCube(isect.position, roomCubeMin, roomCubeMax);
        if(isect.position.x < -2.9999) isect.albedo = GREENCOLOR;
        else if(isect.position.x > 2.9999) isect.albedo = REDCOLOR;
    } /*else if (t == tWall.x) {
        isect.normal = normalForCube(isect.position, wallCubeMin, wallCubeMax);
        isect.albedo = WHITECOLOR; // Wall color
    } else if (t == tSphere) {
        isect.normal = normalForSphere(isect.position, sphereCenter, sphereRadius);
    } */else if (t == tLight) {
        isect.normal = normalForSphere(isect.position, light, lightSize);
        isect.isLight = true;
    } else {
        #ifdef HAS_TRIMESH
        isect.normal = nObj;
        #else
        isect.normal = vec3(0.0, 0.0, 0.0); // Default normal if no intersection
        #endif
    }
    return isect;
}
// end_macro