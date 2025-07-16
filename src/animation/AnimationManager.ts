import {CLoader} from "./AnimationFileLoader";
import {GUI} from "../pathtracer/Gui";
import BVH from "./objects/BVH";

export default class AnimationManager {
  private scene: CLoader;
  private loadedScene: string | null = null;
  private BVH!: BVH;
  private childIndices!: Uint32Array;
  private meshIndices!: Uint32Array;
  private boundingBoxes!: Float32Array;
  private nodeCount: number = 0;
  private gui: GUI;

  constructor(gui: GUI) {
    this.gui = gui;
    this.scene = new CLoader("");
    this.setBVHData();
  }

  private setBVHData(): void {
    this.BVH = new BVH(this.scene);
    const flattenedBVH = this.BVH.getFlattenedBVH();
    this.childIndices = flattenedBVH.childIndices;
    this.meshIndices = flattenedBVH.meshIndices;
    this.boundingBoxes = flattenedBVH.boundingBoxes;
    this.nodeCount = flattenedBVH.count;
  }

  /**
   * Loads and sets the scene from a Collada file
   * @param fileLocation URI for the Collada file
   */
  public setScene(fileLocation: string): void {
    this.loadedScene = fileLocation;
    this.scene = new CLoader(fileLocation);
    this.scene.load(() => this.initScene());
  }

  public initScene(): void {
    if (this.scene.meshes.length === 0) { return; }
    console.log(this.scene.meshes[0].geometry.position.count);
    this.setBVHData();
    this.gui.reset();
  }

  public getScene(): CLoader {
    return this.scene;
  }

  public getChildIndices(): Uint32Array {
    return this.childIndices;
  }

  public getMeshIndices(): Uint32Array {
    return this.meshIndices;
  }

  public getBoundingBoxes(): Float32Array {
    return this.boundingBoxes;
  }

  /**
   * Sets up the mesh and mesh drawing
   */
  // public initModel(): void {
  //   this.sceneRenderPass = new RenderPass(this.ctx, sceneVSText, sceneFSText);
  //
  //   let faceCount = this.scene.meshes[0].geometry.position.count / 3;
  //   let fIndices = new Uint32Array(faceCount * 3);
  //   for (let i = 0; i < faceCount * 3; i += 3) {
  //     fIndices[i] = i;
  //     fIndices[i + 1] = i + 1;
  //     fIndices[i + 2] = i + 2;
  //   }
  //   this.sceneRenderPass.setIndexBufferData(fIndices);
  //
  //   //vertPosition is a placeholder value until skinning is in place
  //   this.sceneRenderPass.addAttribute("vertPosition", 3, this.ctx.FLOAT, false,
  //     3 * Float32Array.BYTES_PER_ELEMENT, 0, undefined, this.scene.meshes[0].geometry.position.values);
  //   this.sceneRenderPass.addAttribute("aNorm", 3, this.ctx.FLOAT, false,
  //     3 * Float32Array.BYTES_PER_ELEMENT, 0, undefined, this.scene.meshes[0].geometry.normal.values);
  //   this.sceneRenderPass.addUniform("jTrans",
  //     (gl: WebGLRenderingContext, loc: WebGLUniformLocation) => {
  //       gl.uniform3fv(loc, this.scene.meshes[0].getBoneTranslations());
  //     });
  //   this.sceneRenderPass.addUniform("jRots",
  //     (gl: WebGLRenderingContext, loc: WebGLUniformLocation) => {
  //       gl.uniform4fv(loc, this.scene.meshes[0].getBoneRotations());
  //     });
  //
  //   this.sceneRenderPass.setDrawData(this.ctx.TRIANGLES, this.scene.meshes[0].geometry.position.count, this.ctx.UNSIGNED_INT, 0);
  //   this.sceneRenderPass.setup();
  // }
}