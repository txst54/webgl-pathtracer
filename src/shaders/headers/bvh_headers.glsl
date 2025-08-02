// begin_macro{SCENE_HEADERS}
// float
uniform sampler2D uSceneAllVertices;
uniform sampler2D uSceneBoundingBoxes;
// int
uniform usampler2D uSceneChildIndices;
uniform usampler2D uSceneMeshIndices;
uniform int uSceneTextureSize;
uniform int uSceneNumFaces;
uniform int uSceneRootIdx;

#define HAS_TRIMESH 1
#define USING_BVH 1
#define BVH_TEXTURE_SIZE 8
// end_macro