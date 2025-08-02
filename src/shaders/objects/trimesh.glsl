// begin_macro{TRIMESH_LIB}

struct BoundingBox {
    vec3 min;
    vec3 max;
};

bool rayIntersectTriangle(vec3 rayOrigin, vec3 rayDir, vec3 v0, vec3 v1, vec3 v2, out float t, out float u, out float v) {
    const float EPSILON = 1e-5;

    vec3 edge1 = v1 - v0;
    vec3 edge2 = v2 - v0;

    vec3 h = cross(rayDir, edge2);
    float a = dot(edge1, h);

    if (abs(a) < EPSILON) {
        return false; // Ray is parallel to triangle
    }

    float f = 1.0 / a;
    vec3 s = rayOrigin - v0;
    u = f * dot(s, h);
    if (u < 0.0 || u > 1.0) {
        return false;
    }

    vec3 q = cross(s, edge1);
    v = f * dot(rayDir, q);
    if (v < 0.0 || u + v > 1.0) {
        return false;
    }

    t = f * dot(edge2, q);
    return t > EPSILON; // Only return true if intersection is in front of ray origin
}

vec3 getTextureFloatVector(sampler2D sceneTexture, int i) {
    int expanded_idx = i * 3;
    vec3 vector_out;
    for (int j = 0; j < 3; j++) {
        int curr_idx = int(expanded_idx + j);
        int texture_idx = int(curr_idx / 4);
        int vector_idx = int(curr_idx % 4);
        int LOD = 0;
        vec4 vector = texelFetch(sceneTexture,
        ivec2(texture_idx % uSceneTextureSize, texture_idx / uSceneTextureSize), LOD);
        vector_out[j] = vector[vector_idx];
    }
    return vector_out;
}

BoundingBox getTextureBBox(sampler2D sceneBoundingBoxes, int i) {
    int expanded_idx = i * 2; // 2 vec3
    BoundingBox bbox_out;
    bbox_out.min = getTextureFloatVector(sceneBoundingBoxes, expanded_idx);
    bbox_out.max = getTextureFloatVector(sceneBoundingBoxes, expanded_idx+1);
    return bbox_out;
}

uvec2 getTextureIndices(usampler2D sceneIndices, int i) {
    int expanded_idx = i * 2;
    uvec2 indices_out;
    int texture_idx = expanded_idx / 4;
    int LOD = 0;
    uvec4 vector = texelFetch(sceneIndices, ivec2(texture_idx % uSceneTextureSize, texture_idx / uSceneTextureSize), LOD);
    if (expanded_idx % 4 == 0) {
        indices_out = vector.rg;
    } else {
        indices_out = vector.ba;
    }
    return indices_out;
}

float intersectBVH(vec3 origin, vec3 ray, sampler2D sceneAllVertices,
sampler2D sceneBoundingBoxes, usampler2D sceneChildIndices, usampler2D sceneMeshIndices,
int sceneRootIdx, out vec3 normal) {

    const int MAX_STACK_SIZE = 64; // Reduced for better performance
    int stack[MAX_STACK_SIZE];
    int stackPtr = 0;

    float closestT = INFINITY; // Use large finite number instead of INFINITY
    normal = vec3(0.0);

    // Push root onto stack
    stack[stackPtr++] = sceneRootIdx;

    while (stackPtr > 0 && stackPtr < MAX_STACK_SIZE) {
        // Pop from stack
        int nodeIdx = stack[--stackPtr];

        BoundingBox bbox = getTextureBBox(sceneBoundingBoxes, nodeIdx);

        // Test ray against bounding box
        if (!intersectBoundingBox(origin, ray, bbox.min, bbox.max)) {
            continue;
        }

        uvec2 childIndices = getTextureIndices(sceneChildIndices, nodeIdx);

        // Check if this is a leaf node
        if (childIndices.x == uint(4294967295) && childIndices.y == uint(4294967295)) {
            // Leaf node - test triangle intersection
            uvec2 meshIndices = getTextureIndices(sceneMeshIndices, nodeIdx);
            int meshIdx = int(meshIndices.x);
            int faceIdx = int(meshIndices.y);

            vec3 v0 = getTextureFloatVector(sceneAllVertices, faceIdx * 3);
            vec3 v1 = getTextureFloatVector(sceneAllVertices, faceIdx * 3 + 1);
            vec3 v2 = getTextureFloatVector(sceneAllVertices, faceIdx * 3 + 2);

            float t, u, v;
            if (rayIntersectTriangle(origin, ray, v0, v1, v2, t, u, v)) {
                if (t < closestT) {
                    closestT = t;
                    // vec3 n = getTextureFloatVector(sceneAllNormals, faceIdx);
                    // normal = normalize(n);
                    vec3 edge1 = v1 - v0;
                    vec3 edge2 = v2 - v0;
                    normal = normalize(cross(edge1, edge2));
                }
            }
        } else {
            if (stackPtr < MAX_STACK_SIZE - 2) {
                // Ensure we have space to push children onto the stack
                if (childIndices.x != uint(4294967295)) {
                    stack[stackPtr++] = int(childIndices.x);
                }
                if (childIndices.y != uint(4294967295)) {
                    stack[stackPtr++] = int(childIndices.y);
                }
            }
        }
    }

    return closestT; // Return -1 for no intersection
}

float intersectBruteForce(vec3 origin, vec3 ray, sampler2D sceneAllVertices, sampler2D sceneAllNormals, out vec3 normal) {
    float t = INFINITY;
    normal = vec3(0.0); // Default normal in case no intersection is found
    for (int i = 0; i < uSceneNumFaces; i++) {
        vec3 v0 = getTextureFloatVector(sceneAllVertices, i * 3);
        vec3 v1 = getTextureFloatVector(sceneAllVertices, i * 3 + 1);
        vec3 v2 = getTextureFloatVector(sceneAllVertices, i * 3 + 2);
        float u, v;
        float t_curr;
        if (rayIntersectTriangle(origin, ray, v0, v1, v2, t_curr, u, v)) {
            if (t_curr < t) {
                t = t_curr;
                // normal = normalize(abs(getTextureFloatVector(uSceneAllNormals, i)));
                normal = vec3(0, 0, 1);
            }
        }
    }
    return t;
}

// BVH Accelerated Intersection
float intersectTrimesh(vec3 origin, vec3 ray, out vec3 normal) {
    float t;
    #if USING_BVH
    return intersectBVH(origin, ray, uSceneAllVertices, uSceneBoundingBoxes,
        uSceneChildIndices, uSceneMeshIndices, uSceneRootIdx, normal);
    #else
    // return intersectBruteForce(origin, ray, sceneAllVertices, sceneAllNormals, normal);
    #endif
}
// end_macro