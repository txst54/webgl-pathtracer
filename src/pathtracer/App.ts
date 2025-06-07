import { Debugger } from "../lib/webglutils/Debugging.js";
import { CanvasAnimation, WebGLUtilities } from "../lib/webglutils/CanvasAnimation.js";
import { GUI } from "./Gui.js";
import {
  pathTracerVSText,
  pathTracerFSText,
  spatialReuseFSText,
  risFSText,
  ReSTIR_initialPassFSText,
  ReSTIR_spatialPassFSText,
  ReSTIR_tspatialPassFSText,
  ReSTIR_temporalPassFSText,
  ReSTIRDrawPassFSText
} from "./Shaders.js";
import { Mat4, Vec4, Vec3 } from "../lib/TSM.js";
import { RenderPass } from "../lib/webglutils/RenderPass.js";
import { Camera } from "../lib/webglutils/Camera.js";

// Rendering modes
enum RenderMode {
  MIS = 0,
  RIS = 1,
  RESTIR_SPATIAL = 2,
  RESTIR_TEMPORAL = 3
}

interface CameraRays {
  ray00: Vec3;
  ray01: Vec3;
  ray10: Vec3;
  ray11: Vec3;
}

interface TextureConfig {
  count: number;
  textures: WebGLTexture[];
}

export class PathTracer extends CanvasAnimation {
  private static readonly MODE_NAMES = ["MIS", "RIS", "ReSTIR Spatial Pass", "ReSTIR Temporal Pass"];
  private static readonly FPS_UPDATE_INTERVAL = 500; // ms
  private static readonly MOVEMENT_SPEED = 0.1;

  // Core components
  private gui: GUI;
  private canvas2d: HTMLCanvasElement;

  // Rendering state
  private currentMode = RenderMode.MIS;
  private sampleCount = 0;
  private pingpong = 0;
  private playerPosition: Vec3;
  private cachedCameraRays: CameraRays;

  // Timing
  private startTime = new Date();
  private frameCount = 0;
  private lastTime = performance.now();
  private fps = 0;
  private frameTime = 0;

  // WebGL resources
  private framebuffers: {
    pathTracer: WebGLFramebuffer;
    restir: WebGLFramebuffer;
    restirTemporal: WebGLFramebuffer;
    restirSpatial: WebGLFramebuffer;
  };

  private textureConfigs: {
    pathTracer: TextureConfig;
    restirReservoir: TextureConfig;
    restirSpatialTemporal: TextureConfig;
    reservoir: TextureConfig;
  };

  private renderPasses: {
    pathTracer: RenderPass;
    ris: RenderPass;
    restirInit: RenderPass;
    restirSpatial: RenderPass;
    restirTemporal: RenderPass;
    restirTemporal1: RenderPass;
    restirTspatial: RenderPass;
    restirDrawPass: RenderPass;
    initialPass: RenderPass;
    spatial: RenderPass;
  };

  // Scene properties
  private lightPosition = new Vec4([-1000, 1000, -1000, 1]);
  private backgroundColor = new Vec4([0.0, 0.37254903, 0.37254903, 1.0]);

  constructor(canvas: HTMLCanvasElement) {
    super(canvas);

    this.initializeCanvas(canvas);
    this.setupWebGL();
    this.initializeGUI();
    this.createFramebuffers();
    this.createTextures();
    this.createRenderPasses();
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

  private setupWebGL(): void {
    this.ctx = Debugger.makeDebugContext(this.ctx);
  }

  private initializeGUI(): void {
    this.gui = new GUI(this.canvas2d, this);
    this.playerPosition = this.gui.getCamera().pos();
  }

  private createFramebuffers(): void {
    const gl = this.ctx;
    this.framebuffers = {
      pathTracer: gl.createFramebuffer(),
      restir: gl.createFramebuffer(),
      restirTemporal: gl.createFramebuffer(),
      restirSpatial: gl.createFramebuffer()
    };
  }

  private createTextures(): void {
    const gl = this.ctx;
    const type = gl.getExtension('OES_texture_float') ? gl.FLOAT : gl.UNSIGNED_BYTE;

    this.textureConfigs = {
      pathTracer: this.createTextureConfig(2, type),
      restirReservoir: this.createTextureConfig(2, type),
      restirSpatialTemporal: this.createTextureConfig(5, type),
      reservoir: this.createTextureConfig(2, type)
    };
  }

  private createTextureConfig(count: number, type: number): TextureConfig {
    const gl = this.ctx;
    const textures: WebGLTexture[] = [];

    for (let i = 0; i < count; i++) {
      const texture = gl.createTexture();
      this.initializeTexture(texture, type);
      textures.push(texture);
    }

    return { count, textures };
  }

  private initializeTexture(texture: WebGLTexture, type: number): void {
    const gl = this.ctx;
    gl.bindTexture(gl.TEXTURE_2D, texture);
    gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, gl.NEAREST);
    gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.NEAREST);
    gl.getExtension('EXT_color_buffer_float');

    const zeros = new Float32Array(this.canvas2d.width * this.canvas2d.height * 4);
    gl.texImage2D(gl.TEXTURE_2D, 0, gl.RGBA32F, this.canvas2d.width, this.canvas2d.height, 0, gl.RGBA, gl.FLOAT, zeros);
  }

  private createRenderPasses(): void {
    const gl = this.ctx;

    this.renderPasses = {
      pathTracer: new RenderPass(gl, pathTracerVSText, pathTracerFSText),
      ris: new RenderPass(gl, pathTracerVSText, risFSText),
      restirInit: new RenderPass(gl, pathTracerVSText, ReSTIR_initialPassFSText),
      restirSpatial: new RenderPass(gl, pathTracerVSText, ReSTIR_spatialPassFSText),
      restirTemporal: new RenderPass(gl, pathTracerVSText, ReSTIR_temporalPassFSText),
      restirTemporal1: new RenderPass(gl, pathTracerVSText, ReSTIR_temporalPassFSText),
      restirTspatial: new RenderPass(gl, pathTracerVSText, ReSTIR_tspatialPassFSText),
      restirDrawPass: new RenderPass(gl, pathTracerVSText, ReSTIRDrawPassFSText),
      initialPass: new RenderPass(gl, pathTracerVSText, ReSTIR_initialPassFSText),
      spatial: new RenderPass(gl, pathTracerVSText, spatialReuseFSText)
    };

    this.setupRenderPasses();
  }

  private setupRenderPasses(): void {
    this.setupPathTracerPass();
    this.setupBasicRenderPass(this.renderPasses.ris);
    this.setupBasicRenderPass(this.renderPasses.restirInit);
    this.setupSpatialPass(this.renderPasses.restirSpatial, this.textureConfigs.restirReservoir);
    this.setupSpatialPass(this.renderPasses.spatial, this.textureConfigs.reservoir);
    this.setupTemporalPasses();
    this.setupDrawPass();
  }

  private setupPathTracerPass(): void {
    const numIndices = this.setupRayRenderPass(this.renderPasses.pathTracer);
    this.renderPasses.pathTracer.addUniform("uTexture", (gl, loc) => {
      gl.activeTexture(gl.TEXTURE0);
      gl.bindTexture(gl.TEXTURE_2D, this.getCurrentTexture());
      gl.uniform1i(loc, 0);
    });
    this.renderPasses.pathTracer.setDrawData(this.ctx.TRIANGLES, numIndices, this.ctx.UNSIGNED_SHORT, 0);
    this.renderPasses.pathTracer.setup();
  }

  private setupBasicRenderPass(renderPass: RenderPass): void {
    const numIndices = this.setupRayRenderPass(renderPass);
    renderPass.setDrawData(this.ctx.TRIANGLES, numIndices, this.ctx.UNSIGNED_SHORT, 0);
    renderPass.setup();
  }

  private setupSpatialPass(renderPass: RenderPass, textureConfig: TextureConfig): void {
    const numIndices = this.setupRayRenderPass(renderPass);

    for (let i = 0; i < textureConfig.count; i++) {
      renderPass.addUniform(`uReservoirData${i + 1}`, (gl, loc) => {
        gl.activeTexture(gl.TEXTURE0 + i);
        gl.bindTexture(gl.TEXTURE_2D, textureConfig.textures[i]);
        gl.uniform1i(loc, i);
      });
    }

    renderPass.setDrawData(this.ctx.TRIANGLES, numIndices, this.ctx.UNSIGNED_SHORT, 0);
    renderPass.setup();
  }

  private setupTemporalPasses(): void {
    const stConfig = this.textureConfigs.restirSpatialTemporal;

    this.setupTemporalPass(this.renderPasses.restirTemporal, stConfig, 0);
    this.setupTemporalPass(this.renderPasses.restirTemporal1, stConfig, 2);
    this.setupTemporalPass(this.renderPasses.restirTspatial, stConfig, 0);
  }

  private setupTemporalPass(renderPass: RenderPass, textureConfig: TextureConfig, offset: number): void {
    const numIndices = this.setupRayRenderPass(renderPass);

    for (let i = 0; i < 2; i++) {
      renderPass.addUniform(`uReservoirData${i + 1}`, (gl, loc) => {
        gl.activeTexture(gl.TEXTURE0 + i);
        gl.bindTexture(gl.TEXTURE_2D, textureConfig.textures[i + offset]);
        gl.uniform1i(loc, i);
      });
    }

    renderPass.setDrawData(this.ctx.TRIANGLES, numIndices, this.ctx.UNSIGNED_SHORT, 0);
    renderPass.setup();
  }

  private setupDrawPass(): void {
    const numIndices = this.setupRayRenderPass(this.renderPasses.restirDrawPass);

    this.renderPasses.restirDrawPass.addUniform("uTexture", (gl, loc) => {
      gl.activeTexture(gl.TEXTURE0);
      gl.bindTexture(gl.TEXTURE_2D, this.textureConfigs.restirSpatialTemporal.textures[4]);
      gl.uniform1i(loc, 0);
    });

    this.renderPasses.restirDrawPass.setDrawData(this.ctx.TRIANGLES, numIndices, this.ctx.UNSIGNED_SHORT, 0);
    this.renderPasses.restirDrawPass.setup();
  }

  private setupRayRenderPass(renderPass: RenderPass): number {
    const quadVertices = new Float32Array([-1, -1, -1, 1, 1, -1, 1, 1]);
    const indices = new Uint16Array([0, 2, 1, 2, 3, 1]);

    renderPass.setIndexBufferData(indices);
    renderPass.addAttribute("aVertPos", 2, this.ctx.FLOAT, false, 2 * Float32Array.BYTES_PER_ELEMENT, 0, undefined, quadVertices);

    this.addCameraUniforms(renderPass);
    this.addTimeUniforms(renderPass);
    this.addRenderingUniforms(renderPass);

    return indices.length;
  }

  private addCameraUniforms(renderPass: RenderPass): void {
    renderPass.addUniform("uEye", (gl, loc) => {
      gl.uniform3fv(loc, this.gui.getCamera().pos().xyz);
    });

    const rayUniforms = ["uRay00", "uRay01", "uRay10", "uRay11"];
    const rayKeys = ["ray00", "ray01", "ray10", "ray11"] as const;

    rayUniforms.forEach((uniform, i) => {
      renderPass.addUniform(uniform, (gl, loc) => {
        gl.uniform3fv(loc, this.cachedCameraRays[rayKeys[i]].xyz);
      });
    });
  }

  private addTimeUniforms(renderPass: RenderPass): void {
    renderPass.addUniform("uTime", (gl, loc) => {
      const timeSinceStart = (new Date().getMilliseconds() - this.startTime.getMilliseconds()) * 0.001;
      gl.uniform1f(loc, timeSinceStart);
    });
  }

  private addRenderingUniforms(renderPass: RenderPass): void {
    renderPass.addUniform("uTextureWeight", (gl, loc) => {
      gl.uniform1f(loc, this.getTextureWeight());
    });

    renderPass.addUniform("uRes", (gl, loc) => {
      gl.uniform2f(loc, this.canvas2d.width, this.canvas2d.height);
    });

    renderPass.addUniform("uViewMatPrev", (gl, loc) => {
      gl.uniformMatrix4fv(loc, false, this.gui.getCamera().getViewMatrixPrevious());
    });

    renderPass.addUniform("uProjMatPrev", (gl, loc) => {
      gl.uniformMatrix4fv(loc, false, this.gui.getCamera().getProjMatrixPrevious());
    });
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

  private getCurrentTexture(): WebGLTexture {
    return this.textureConfigs.pathTracer.textures[this.pingpong];
  }

  private getTextureWeight(): number {
    return this.sampleCount / (this.sampleCount + 1);
  }

  private updateFPS(): void {
    this.frameCount++;
    const currentTime = performance.now();
    const deltaTime = currentTime - this.lastTime;
    this.frameTime = deltaTime;

    if (deltaTime >= PathTracer.FPS_UPDATE_INTERVAL) {
      this.fps = (this.frameCount * 1000) / deltaTime;
      this.frameCount = 0;
      this.lastTime = currentTime;
      this.updateFPSDisplay();
    }
  }

  private updateFPSDisplay(): void {
    const updates = [
      { id: 'fpsValue', value: this.fps.toFixed(1) },
      { id: 'frameTimeValue', value: this.frameTime.toFixed(2) },
      { id: 'sampleValue', value: this.sampleCount.toString() },
      { id: 'mode', value: PathTracer.MODE_NAMES[this.currentMode] }
    ];

    updates.forEach(({ id, value }) => {
      const element = document.getElementById(id);
      if (element) element.textContent = value;
    });
  }

  public swapMode(): void {
    this.currentMode = (this.currentMode + 1) % Object.keys(RenderMode).length / 2;
    console.log(`Switched mode to ${PathTracer.MODE_NAMES[this.currentMode]}`);
  }

  public setMode(newMode: number): void {
    this.currentMode = newMode % (Object.keys(RenderMode).length / 2);
  }

  public reset(): void {
    this.gui.reset();
    this.playerPosition = this.gui.getCamera().pos();
  }

  public resetSamples(): void {
    this.sampleCount = 0;
  }

  public draw(): void {
    this.updatePlayerMovement();
    this.setupWebGLState();
    this.drawScene(0, 0, this.canvas2d.width, this.canvas2d.height);
    this.updateFPS();
  }

  private updatePlayerMovement(): void {
    this.playerPosition.add(this.gui.walkDir().copy().scale(PathTracer.MOVEMENT_SPEED));
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

    switch (this.currentMode) {
      case RenderMode.MIS:
        this.renderPathTracer(gl);
        break;
      case RenderMode.RIS:
        this.renderRIS();
        break;
      case RenderMode.RESTIR_SPATIAL:
        this.renderReSTIRSpatial(gl);
        break;
      case RenderMode.RESTIR_TEMPORAL:
        this.renderReSTIRTemporal(gl);
        break;
    }
  }

  private renderPathTracer(gl: WebGL2RenderingContext): void {
    const writeIndex = 1 - this.pingpong;
    const textures = this.textureConfigs.pathTracer.textures;

    gl.bindFramebuffer(gl.FRAMEBUFFER, this.framebuffers.pathTracer);
    gl.framebufferTexture2D(gl.FRAMEBUFFER, gl.COLOR_ATTACHMENT0, gl.TEXTURE_2D, textures[writeIndex], 0);
    gl.bindTexture(gl.TEXTURE_2D, textures[this.pingpong]);
    this.renderPasses.pathTracer.draw();

    this.pingpong = writeIndex;
    this.sampleCount++;

    gl.bindFramebuffer(gl.FRAMEBUFFER, null);
    this.renderPasses.pathTracer.draw();
  }

  private renderRIS(): void {
    this.renderPasses.ris.draw();
  }

  private renderReSTIRSpatial(gl: WebGL2RenderingContext): void {
    const textures = this.textureConfigs.restirReservoir.textures;

    gl.bindFramebuffer(gl.FRAMEBUFFER, this.framebuffers.restir);
    gl.framebufferTexture2D(gl.FRAMEBUFFER, gl.COLOR_ATTACHMENT0, gl.TEXTURE_2D, textures[0], 0);
    gl.framebufferTexture2D(gl.FRAMEBUFFER, gl.COLOR_ATTACHMENT1, gl.TEXTURE_2D, textures[1], 0);
    gl.drawBuffers([gl.COLOR_ATTACHMENT0, gl.COLOR_ATTACHMENT1]);
    this.renderPasses.restirInit.draw();

    gl.bindFramebuffer(gl.FRAMEBUFFER, null);
    this.renderPasses.restirSpatial.draw();
  }

  private renderReSTIRTemporal(gl: WebGL2RenderingContext): void {
    const writeStartIndex = this.pingpong === 0 ? 2 : 0;
    const stTextures = this.textureConfigs.restirSpatialTemporal.textures;

    gl.bindFramebuffer(gl.FRAMEBUFFER, this.framebuffers.restirTemporal);
    gl.framebufferTexture2D(gl.FRAMEBUFFER, gl.COLOR_ATTACHMENT0, gl.TEXTURE_2D, stTextures[writeStartIndex], 0);
    gl.framebufferTexture2D(gl.FRAMEBUFFER, gl.COLOR_ATTACHMENT1, gl.TEXTURE_2D, stTextures[writeStartIndex + 1], 0);
    gl.framebufferTexture2D(gl.FRAMEBUFFER, gl.COLOR_ATTACHMENT2, gl.TEXTURE_2D, stTextures[4], 0);
    gl.drawBuffers([gl.COLOR_ATTACHMENT0, gl.COLOR_ATTACHMENT1, gl.COLOR_ATTACHMENT2]);

    const temporalPass = this.pingpong === 0 ? this.renderPasses.restirTemporal : this.renderPasses.restirTemporal1;
    temporalPass.draw();

    this.pingpong = 1 - this.pingpong;
    this.gui.getCamera().updateViewMatrixNext();

    gl.bindFramebuffer(gl.FRAMEBUFFER, null);
    this.renderPasses.restirDrawPass.draw();
  }

  public getGUI(): GUI {
    return this.gui;
  }

  public jump(): void {
    // TODO: If the player is not already in the lair, launch them upwards at 10 units/sec.
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