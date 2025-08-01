import {CLoader} from "./AnimationFileLoader";
import {GUI} from "../pathtracer/Gui";
import BVH from "./objects/BVH";
import {BaseRenderer} from "../pathtracer/renderpasses/BaseRenderer";

export default class AnimationManager {
  private scene: CLoader;
  private loadedScene: string | null = null;
  private BVH!: BVH;
  private childIndices!: Uint32Array;
  private meshIndices!: Uint32Array;
  private boundingBoxes!: Float32Array;
  private rootIdx: number = 0;
  private renderer: BaseRenderer | null = null;
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
    this.rootIdx = flattenedBVH.rootIdx;
  }

  public setRenderer(renderer: BaseRenderer): void {
    this.renderer = renderer;
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
    console.log(this.scene.meshes[0].geometry.position.values);
    this.setBVHData();
    // if (this.renderer) {
    //   this.renderer.reset();
    // }
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

  public getRootIdx(): number {
    return this.rootIdx;
  }

  public getAllVertices(): Float32Array {
    if (this.scene.meshes.length === 0) {
      return new Float32Array(0);
    }
    return this.scene.meshes[0].geometry.position.values;
  }

  public getAllNormals(): Float32Array {
    if (this.scene.meshes.length === 0) {
      return new Float32Array(0);
    }
    return this.scene.meshes[0].geometry.normal.values;
  }

  public getNumFaces(): number {
    if (this.scene.meshes.length === 0) return 0;
    return this.scene.meshes[0].geometry.position.count / 3
  }


  public getLoadedScene(): string {
    return this.loadedScene || "";
  }
}