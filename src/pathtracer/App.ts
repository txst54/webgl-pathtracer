import { Debugger } from "../lib/webglutils/Debugging.js";
import { CanvasAnimation } from "../lib/webglutils/CanvasAnimation.js";
import { GUI } from "./Gui.js";
import { FPSCounter } from "./Menu.js";
import { Vec4, Vec3 } from "../lib/TSM.js";
import MISRenderer from "./renderpasses/MISRenderer";
import { BaseRenderer } from "./renderpasses/BaseRenderer";
import RISRenderer from "./renderpasses/RISRenderer";
import ReSTIRDISpatialRenderer from "./renderpasses/ReSTIRDISpatialRenderer";
import ReSTIRDIRenderer from "./renderpasses/ReSTIRDIRenderer";
import ReSTIRGIRenderer from "./renderpasses/ReSTIRGIRenderer";
import AnimationManager from "../animation/AnimationManager";

// Rendering modes
enum RenderMode {
  MIS = 0,
  RIS = 1,
  RESTIR_SPATIAL = 2,
  RESTIR_TEMPORAL = 3,
  RESTIR_GI = 4
}

interface CameraRays {
  ray00: Vec3;
  ray01: Vec3;
  ray10: Vec3;
  ray11: Vec3;
}

export class PathTracer extends CanvasAnimation {
  private static readonly MODE_NAMES = ["MIS", "RIS", "ReSTIR DI [Spatial Pass]", "ReSTIR DI", "ReSTIR GI"];
  private static readonly MOVEMENT_SPEED = 0.2;

  // Core components
  private gui!: GUI;
  private canvas2d!: HTMLCanvasElement;
  private fpsCounter!: FPSCounter;
  private animationManager!: AnimationManager;

  // Rendering state
  private currentMode = RenderMode.MIS;
  private sampleCount = 0;
  private playerPosition!: Vec3;
  private cachedCameraRays!: CameraRays;

  // Timing
  private startTime = new Date();

  // Renderers
  private renderers!: { [key in RenderMode]: BaseRenderer };

  // Scene properties
  private lightPosition = new Vec4([-1000, 1000, -1000, 1]);
  private backgroundColor = new Vec4([0.0, 0.37254903, 0.37254903, 1.0]);

  constructor(canvas: HTMLCanvasElement) {
    super(canvas);

    this.initializeCanvas(canvas);
    this.setupWebGL();
    this.initializeGUI();
    this.initializeAnimationManager();
    this.initializeFPSCounter();
    this.createRenderers();
    this.updateCameraRays();
  }

  private initializeCanvas(canvas: HTMLCanvasElement): void {
    this.canvas2d = document.getElementById("textCanvas") as HTMLCanvasElement;

    // Match drawing buffer size
    this.canvas2d.width = this.canvas2d.clientWidth;
    this.canvas2d.height = this.canvas2d.clientHeight;
    canvas.width = canvas.clientWidth;
    canvas.height = canvas.clientHeight;

    console.log("Canvas Resolution:", this.canvas2d.width, "X", this.canvas2d.height);
  }

  private initializeAnimationManager(): void {
    this.animationManager = new AnimationManager(this.gui);
    this.animationManager.setScene("assets/robot.dae");
  }

  private setupWebGL(): void {
    this.ctx = Debugger.makeDebugContext(this.ctx);
  }

  private initializeGUI(): void {
    this.gui = new GUI(this.canvas2d, this);
    this.playerPosition = this.gui.getCamera().pos();
  }

  private initializeFPSCounter(): void {
    this.fpsCounter = new FPSCounter(PathTracer.MODE_NAMES);
    this.fpsCounter.setMode(this.currentMode);
  }

  private createRenderers(): void {
    this.renderers = {
      [RenderMode.MIS]: new MISRenderer(this.ctx, this.canvas2d, this),
      [RenderMode.RIS]: new RISRenderer(this.ctx, this.canvas2d, this),
      [RenderMode.RESTIR_SPATIAL]: new ReSTIRDISpatialRenderer(this.ctx, this.canvas2d, this),
      [RenderMode.RESTIR_TEMPORAL]: new ReSTIRDIRenderer(this.ctx, this.canvas2d, this),
      [RenderMode.RESTIR_GI]: new ReSTIRGIRenderer(this.ctx, this.canvas2d, this)
    };
  }

  public updateCameraRays(): void {
    const camera = this.gui.getCamera();
    const invPV = camera.projMatrix().copy().multiply(camera.viewMatrix()).inverse();

    const getRay = (x: number, y: number): Vec3 => {
      const clip = new Vec4([x, y, -1, 1.0]);
      const world = invPV.multiplyVec4(clip);
      return new Vec3(world.scale(1.0 / world.w).xyz).subtract(camera.pos());
    };

    this.cachedCameraRays = {
      ray00: getRay(-1, -1),
      ray01: getRay(-1, 1),
      ray10: getRay(1, -1),
      ray11: getRay(1, 1)
    };
  }

  public swapMode(): void {
    this.currentMode = (this.currentMode + 1) % Object.keys(RenderMode).length / 2;
    this.fpsCounter.setMode(this.currentMode);
    this.fpsCounter.forceDisplayUpdate();
    console.log(`Switched mode to ${PathTracer.MODE_NAMES[this.currentMode]}`);
  }

  public setMode(newMode: number): void {
    this.currentMode = newMode % (Object.keys(RenderMode).length / 2);
    this.fpsCounter.setMode(this.currentMode);
    this.fpsCounter.forceDisplayUpdate();
  }

  public reset(): void {
    this.gui.reset();
    this.playerPosition = this.gui.getCamera().pos();
  }

  public resetSamples(): void {
    this.sampleCount = 0;
    this.fpsCounter.resetSampleCount();
  }

  public draw(): void {
    this.updatePlayerMovement();
    this.setupWebGLState();
    this.drawScene(0, 0, this.canvas2d.width, this.canvas2d.height);
    this.fpsCounter.update();
    this.sampleCount++;
  }

  private updatePlayerMovement(): void {
    this.playerPosition.add(this.gui.walkDir().copy().scale(PathTracer.MOVEMENT_SPEED * 60 / this.fpsCounter.getFPS()));
    this.gui.getCamera().setPos(this.playerPosition);
  }

  private setupWebGLState(): void {
    const gl = this.ctx;
    const bg = this.backgroundColor;

    gl.clearColor(bg.r, bg.g, bg.b, bg.a);
    gl.clear(gl.COLOR_BUFFER_BIT | gl.DEPTH_BUFFER_BIT);
    gl.enable(gl.CULL_FACE);
    gl.enable(gl.DEPTH_TEST);
    gl.frontFace(gl.CCW);
    gl.cullFace(gl.BACK);
  }

  private drawScene(x: number, y: number, width: number, height: number): void {
    const gl = this.ctx as WebGL2RenderingContext;
    gl.viewport(x, y, width, height);

    this.renderers[this.currentMode].render();
  }

  // Public getters for renderers to access internal state
  public getGUI(): GUI {
    return this.gui;
  }

  public getCachedCameraRays(): CameraRays {
    return this.cachedCameraRays;
  }

  public getStartTime(): Date {
    return this.startTime;
  }

  public getTextureWeight(): number {
    return this.sampleCount / (this.sampleCount + 1);
  }

  public getAnimationManager(): AnimationManager {
    return this.animationManager;
  }
}

export function initializeCanvas(): void {
  const canvas = document.getElementById("glCanvas") as HTMLCanvasElement;
  console.log('WebGL version:',
      (document.createElement('canvas').getContext('webgl2') && 'WebGL 2.0') ||
      (document.createElement('canvas').getContext('webgl') && 'WebGL 1.0') ||
      'WebGL not supported'
  );

  const canvasAnimation = new PathTracer(canvas);
  canvasAnimation.start();
}