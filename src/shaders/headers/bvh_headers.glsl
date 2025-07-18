// begin_macro{SCENE_HEADERS}
// float
uniform sampler2D uSceneAllVertices;
uniform sampler2D uSceneAllNormals;
uniform sampler2D uSceneBoundingBoxes;
// int
uniform sampler2D uSceneChildIndices;
uniform sampler2D uSceneMeshIndices;
uniform int uSceneRootIdx;

#define USING_BVH true
#define BVH_TEXTURE_SIZE 1024
// end_macro