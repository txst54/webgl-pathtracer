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
        ivec2(texture_idx % BVH_TEXTURE_SIZE, texture_idx / BVH_TEXTURE_SIZE), LOD);
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

vec2 getTextureIndices(sampler2D sceneIndices, int i) {
    int expanded_idx = i * 2;
    vec2 indices_out;
    int texture_idx = expanded_idx / 4;
    int LOD = 0;
    vec4 vector = texelFetch(sceneIndices, ivec2(texture_idx % BVH_TEXTURE_SIZE, texture_idx / BVH_TEXTURE_SIZE), LOD);
    if (expanded_idx % 4 == 0) {
        indices_out = vector.rg;
    } else {
        indices_out = vector.ba;
    }
    return indices_out;
}

// BVH Accelerated Intersection
float intersectTrimesh(vec3 origin, vec3 ray, sampler2D sceneAllVertices, sampler2D sceneAllNormals,
sampler2D sceneBoundingBoxes, sampler2D sceneChildIndices, sampler2D sceneMeshIndices, int sceneRootIdx) {
    int queue[1024];
    int head = 0;
    int tail = 0;
    queue[tail++] = sceneRootIdx;
    while (head < tail) {
        int top_idx = queue[head];
        head++;
        BoundingBox bbox = getTextureBBox(sceneBoundingBoxes, top_idx);
        if(!intersectBoundingBox(origin, ray, bbox.min, bbox.max)) {
            continue;
        }
        vec2 child_indices = getTextureIndices(sceneChildIndices, top_idx);
        if (int(child_indices.x) == -1 && int(child_indices.y) == -1) {
            // leaf node, check for triangular intersection
            vec2 mesh_indices = getTextureIndices(sceneMeshIndices, top_idx);
            // TODO check intersection of face
            int mesh_idx = int(mesh_indices.x);
            int face_idx = int(mesh_indices.y);
            // dont do anything with mesh_idx for now
            vec3 v0 = getTextureFloatVector(sceneAllVertices, face_idx * 3);
            vec3 v1 = getTextureFloatVector(sceneAllVertices, face_idx * 3 + 1);
            vec3 v2 = getTextureFloatVector(sceneAllVertices, face_idx * 3 + 2);
            vec3 n = getTextureFloatVector(sceneAllNormals, face_idx * 3);
            float t, u, v;
            if (rayIntersectTriangle(origin, ray, v0, v1, v2, t, u, v)) {
                // intersection found
                vec3 hit_point = origin + t * ray;
                vec3 normal = normalize(n);
                return t;
            }
        }
        if (int(child_indices.x) != -1) {
            queue[tail++] = int(child_indices.x);
        }
        if (int(child_indices.y) != -1) {
            queue[tail++] = int(child_indices.y);
        }
    }
    return INFINITY;
}
// end_macro