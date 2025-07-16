import {Vec3} from "../../lib/tsm/Vec3";

export default class BoundingBox {
  minVertex: Vec3;
  maxVertex: Vec3;

  constructor(minVertex: Vec3, maxVertex: Vec3) {
    this.minVertex = minVertex;
    this.maxVertex = maxVertex;
  }

  public merge(other: BoundingBox): BoundingBox {
    return new BoundingBox(
      new Vec3([
        Math.min(this.minVertex.x, other.minVertex.x),
        Math.min(this.minVertex.y, other.minVertex.y),
        Math.min(this.minVertex.z, other.minVertex.z)
      ]),
      new Vec3([
        Math.max(this.maxVertex.x, other.maxVertex.x),
        Math.max(this.maxVertex.y, other.maxVertex.y),
        Math.max(this.maxVertex.z, other.maxVertex.z)
      ])
    );
  }

  public static fromVertices(vertices: Vec3[]): BoundingBox {
    if (vertices.length === 0) {
      throw new Error("Cannot create BoundingBox from empty vertex array");
    }
    let minVertex = new Vec3([Infinity, Infinity, Infinity]);
    let maxVertex = new Vec3([-Infinity, -Infinity, -Infinity]);
    for (const vertex of vertices) {
      minVertex.x = Math.min(minVertex.x, vertex.x);
      minVertex.y = Math.min(minVertex.y, vertex.y);
      minVertex.z = Math.min(minVertex.z, vertex.z);
      maxVertex.x = Math.max(maxVertex.x, vertex.x);
      maxVertex.y = Math.max(maxVertex.y, vertex.y);
      maxVertex.z = Math.max(maxVertex.z, vertex.z);
    }
    return new BoundingBox(minVertex, maxVertex);
  }
}