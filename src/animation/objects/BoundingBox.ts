import {Vec3} from "../../lib/tsm/Vec3";

export default class BoundingBox {
  minVertex: Vec3;
  maxVertex: Vec3;

  constructor(pMinVertex: Vec3, pMaxVertex: Vec3) {
    this.minVertex = pMinVertex.copy().subtract(new Vec3([0.001, 0.001, 0.001]));
    this.maxVertex = pMaxVertex.copy().add(new Vec3([0.001, 0.001, 0.001]));
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

    let minX = Infinity, minY = Infinity, minZ = Infinity;
    let maxX = -Infinity, maxY = -Infinity, maxZ = -Infinity;

    for (const vertex of vertices) {
      minX = Math.min(minX, vertex.x);
      minY = Math.min(minY, vertex.y);
      minZ = Math.min(minZ, vertex.z);
      maxX = Math.max(maxX, vertex.x);
      maxY = Math.max(maxY, vertex.y);
      maxZ = Math.max(maxZ, vertex.z);
    }
    return new BoundingBox(
      new Vec3([minX, minY, minZ]),
      new Vec3([maxX, maxY, maxZ])
    );
  }
}