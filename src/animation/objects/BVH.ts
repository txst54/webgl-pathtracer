import {CLoader} from "../AnimationFileLoader";
import {GUI} from "../../pathtracer/Gui";
import BoundingBox from "./BoundingBox";
import {Vec3} from "../../lib/tsm/Vec3";
import {Mesh} from "../Scene";

interface BVHNode {
  left: BVHNode | null;
  right: BVHNode | null;
  boundingBox: BoundingBox;
  mortonCode: number;
  meshIndex: number; // Index of the mesh this node represents
  faceIndex: number;
}

interface IndexedBVHNode {
  left: number;
  right: number;
  boundingBox: BoundingBox;
  meshIndex: number;
  faceIndex: number;
}

function flattenBVHNode(node: IndexedBVHNode): {
  childIndices: Uint32Array,
  meshIndices: Uint32Array,
  boundingBoxes: Float32Array
} {
  const childIndices = new Uint32Array([node.left, node.right]);
  const meshIndices = new Uint32Array([node.meshIndex, node.faceIndex]);
  const boundingBoxes = new Float32Array([
    node.boundingBox.minVertex.x, node.boundingBox.minVertex.y, node.boundingBox.minVertex.z,
    node.boundingBox.maxVertex.x, node.boundingBox.maxVertex.y, node.boundingBox.maxVertex.z
  ]);
  return {childIndices, meshIndices, boundingBoxes};
}

export default class BVH {
  root: BVHNode | null = null;

  constructor(scene: CLoader) {
    this.root = this.buildBVH(scene);
  }

  private expandBits(v: number): number {
    v = v | 0;
    v = (v * 0x00010001) & 0xFF0000FF;
    v = (v * 0x00000101) & 0x0F00F00F;
    v = (v * 0x00000011) & 0xC30C30C3;
    v = (v * 0x00000005) & 0x49249249;
    return v;
  }

  private mortonCode3D(vertex: Vec3, minVertex: Vec3, maxVertex: Vec3): number {
    const normPos = (vertex.subtract(minVertex)).divide(maxVertex.subtract(minVertex)).scale(1023.0);
    const x = Math.floor(normPos.x);
    const y = Math.floor(normPos.y);
    const z = Math.floor(normPos.z);
    return (this.expandBits(x) << 2) | (this.expandBits(y) << 1) | this.expandBits(z);
  }

  private extractVec3FromMesh(mesh: Mesh, index: number): Vec3 {
    const values = mesh.geometry.position.values;
    return new Vec3([values[index * 3], values[index * 3 + 1], values[index * 3 + 2]]);
  }

  private instantiateBVHNodes(scene: CLoader): { nodes: BVHNode[], sceneBoundingBox: BoundingBox } {
    const nodes: BVHNode[] = [];
    let boundingBox;
    let sceneMinVertex = new Vec3([Infinity, Infinity, Infinity]);
    let sceneMaxVertex = new Vec3([-Infinity, -Infinity, -Infinity]);
    let sceneBoundingBox = new BoundingBox(sceneMinVertex, sceneMaxVertex);
    for (let i = 0; i < scene.meshes.length; i++) {
      const mesh = scene.meshes[i];
      for (let j = 0; j < mesh.geometry.position.count; j += 3) {
        boundingBox = BoundingBox.fromVertices([
          this.extractVec3FromMesh(mesh, j),
          this.extractVec3FromMesh(mesh, j+1),
          this.extractVec3FromMesh(mesh, j+2)]
        );
        sceneBoundingBox = sceneBoundingBox.merge(boundingBox);
        const node: BVHNode = {
          left: null,
          right: null,
          boundingBox: boundingBox,
          mortonCode: 0,
          meshIndex: i,
          faceIndex: j / 3
        };
        nodes.push(node);
      }
    }
    return { nodes, sceneBoundingBox };
  }

  private sortBVHNodes(nodes: BVHNode[], sceneMinVertex: Vec3, sceneMaxVertex: Vec3): BVHNode[] {
    nodes.forEach(node => {
      node.mortonCode = this.mortonCode3D(
        node.boundingBox.minVertex.copy(),
        sceneMinVertex,
        sceneMaxVertex
      );
    });
    nodes.sort((a, b) => a.mortonCode - b.mortonCode);
    return nodes;
  }

  private buildBVH(scene: CLoader): BVHNode | null {
    const { nodes, sceneBoundingBox } = this.instantiateBVHNodes(scene);
    if (nodes.length == 0) return null;
    let sortedNodes = this.sortBVHNodes(nodes, sceneBoundingBox.minVertex, sceneBoundingBox.maxVertex);
    while (sortedNodes.length > 1) {
      const newNodes: BVHNode[] = [];
      for (let i = 0; i < sortedNodes.length; i += 2) {
        if (i + 1 < sortedNodes.length) {
          const left = sortedNodes[i];
          const right = sortedNodes[i + 1];
          const mergedBoundingBox = left.boundingBox.merge(right.boundingBox);
          const parentNode: BVHNode = {
            left: left,
            right: right,
            boundingBox: mergedBoundingBox,
            mortonCode: 0,
            meshIndex: -1, // No mesh index for parent nodes
            faceIndex: -1
          };
          newNodes.push(parentNode);
        } else {
          newNodes.push(sortedNodes[i]); // Odd node, just push it up
        }
      }
      sortedNodes = newNodes;
    }
    return sortedNodes[0];
  }

  private indexBVH(): { rootIdx: number, allBVHNodes: IndexedBVHNode[] } {
    const allBVHNodes: IndexedBVHNode[] = [];
    const traverse = (node: BVHNode | null): number => {
      if (!node) return -1;
      const indexedNode: IndexedBVHNode = {
        left: traverse(node.left),
        right: traverse(node.right),
        boundingBox: node.boundingBox,
        meshIndex: node.meshIndex,
        faceIndex: node.faceIndex
      }
      const index = allBVHNodes.length;
      allBVHNodes.push(indexedNode);
      return index;
    };
    const rootIdx = traverse(this.root);
    return {rootIdx, allBVHNodes};
  }

  public getFlattenedBVH(): {
    childIndices: Uint32Array, meshIndices: Uint32Array, boundingBoxes: Float32Array,
    rootIdx: number
  } {
    const { rootIdx, allBVHNodes } = this.indexBVH();
    const childIndices = new Uint32Array(allBVHNodes.length * 2);
    const meshIndices = new Uint32Array(allBVHNodes.length * 2);
    const boundingBoxes = new Float32Array(allBVHNodes.length * 6);
    for (let i = 0; i < allBVHNodes.length; i++) {
      const node = allBVHNodes[i];
      const flatNode = flattenBVHNode(node);
      childIndices.set(flatNode.childIndices, i * 2);
      meshIndices.set(flatNode.meshIndices, i * 2);
      boundingBoxes.set(flatNode.boundingBoxes, i * 6);
    }
    return {childIndices, meshIndices, boundingBoxes, rootIdx};
  }
}
