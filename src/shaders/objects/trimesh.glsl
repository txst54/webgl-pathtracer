// begin_macro{TRIMESH_LIB}

struct BoundingBox {
    vec3 min;
    vec3 max;
};

// BVH Accelerated Intersection
float intersectTrimesh(vec3 origin, vec3 ray, sampler2D sceneAllVertices, sampler2D sceneAllNormals,
    sampler2D sceneBoundingBoxes, sampler2D sceneChildIndices, sampler2D sceneMeshIndices, int sceneRootIdx) {

}

BoundingBox getTextureBBox(sampler2D sceneBoundingBoxes, int i) {
    int expanded_idx = i * 6; // 2 vec3
    BoundingBox bbox_out;
    for (int k = 0; k < 2; k++) {
        vec3 current = vec3(0.0);
        for (int j = 0; j < 3; j++) {
            int curr_idx = int(expanded_idx + j);
            int texture_idx = int(curr_idx / 4);
            int vector_idx = int(curr_idx % 4);
            int LOD = 0;
            vec4 vector = texelFetch(sceneBoundingBoxes,
                vec2(int(texture_idx / BVH_TEXTURE_SIZE), int(texture_idx % BVH_TEXTURE_SIZE)), LOD);
            current[j] = vector[vector_idx];
        }
        if (k == 0) {
            bbox_out.min = current;
        } else {
            bbox_out.max = current;
        }
    }
    return bbox;
}

vec2 getTextureIndices(sampler2D sceneIndices, int i) {
    int expanded_idx = i * 2;
    vec2 indices_out;
    int texture_idx = expanded_idx / 4;
    int LOD = 0;
    vec4 vector = texelFetch(sceneIndices, vec2(int(texture_idx / BVH_TEXTURE_SIZE), int(texture_idx % BVH_TEXTURE_SIZE)), LOD);
    if (expanded_idx % 4 == 0) {
        indices_out = vector.rg;
    } else {
        indices_out = vector.ba;
    }
    return indices_out;
}
// end_macro