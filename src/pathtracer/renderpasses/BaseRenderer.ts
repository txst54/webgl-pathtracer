import {RenderPass} from "../../lib/webglutils/RenderPass";
import {PathTracer} from "../App";
import AnimationManager from "../../animation/AnimationManager";

export interface TextureConfig {
  count: number;
  textures: WebGLTexture[];
}

// Abstract base class for all renderers
export abstract class BaseRenderer {
  protected gl: WebGL2RenderingContext;
  protected canvas: HTMLCanvasElement;
  protected frameBuffer!: WebGLFramebuffer;
  protected textureConfig!: TextureConfig;
  protected sceneTextureConfig: TextureConfig | null = null;
  protected renderPasses: { [key: string]: RenderPass } = {};
  protected animationManager: AnimationManager;
  private logged: number = 2;

  constructor(gl: WebGL2RenderingContext, canvas: HTMLCanvasElement, pathTracer: PathTracer) {
    this.gl = gl;
    this.canvas = canvas;
    this.animationManager = pathTracer.getAnimationManager();
    this.animationManager.setRenderer(this);
    this.initialize(pathTracer);
  }

  protected abstract initialize(pathTracer: PathTracer): void;

  public abstract render(): void;

  protected createTextureConfig(count: number, type: number): TextureConfig {
    const textures: WebGLTexture[] = [];

    for (let i = 0; i < count; i++) {
      const texture = this.gl.createTexture();
      this.initializeTexture(texture, type);
      textures.push(texture);
    }

    return {count, textures};
  }

  protected initializeTexture(texture: WebGLTexture, type: number): void {
    this.gl.bindTexture(this.gl.TEXTURE_2D, texture);
    this.gl.texParameteri(this.gl.TEXTURE_2D, this.gl.TEXTURE_MAG_FILTER, this.gl.NEAREST);
    this.gl.texParameteri(this.gl.TEXTURE_2D, this.gl.TEXTURE_MIN_FILTER, this.gl.NEAREST);
    this.gl.getExtension('EXT_color_buffer_float');

    const zeros = new Float32Array(this.canvas.width * this.canvas.height * 4);
    this.gl.texImage2D(this.gl.TEXTURE_2D, 0, this.gl.RGBA32F, this.canvas.width, this.canvas.height, 0, this.gl.RGBA, this.gl.FLOAT, zeros);
  }

  protected setupRayRenderPass(renderPass: RenderPass, pathTracer: PathTracer): number {
    const quadVertices = new Float32Array([-1, -1, -1, 1, 1, -1, 1, 1]);
    const indices = new Uint16Array([0, 2, 1, 2, 3, 1]);

    renderPass.setIndexBufferData(indices);
    renderPass.addAttribute("aVertPos", 2, this.gl.FLOAT, false, 2 * Float32Array.BYTES_PER_ELEMENT, 0, undefined, quadVertices);

    if (!this.sceneTextureConfig) {
      let textures = [];
      for (let i = 0; i < 5; i++) {
        textures.push(this.gl.createTexture());
      }
      this.sceneTextureConfig = {count: 5, textures};
      console.log("Created Textures");
    }

    this.addAnimationUniforms(renderPass);
    this.addCameraUniforms(renderPass, pathTracer);
    this.addTimeUniforms(renderPass, pathTracer);
    this.addRenderingUniforms(renderPass, pathTracer);

    return indices.length;
  }

  protected addCameraUniforms(renderPass: RenderPass, pathTracer: PathTracer): void {
    renderPass.addUniform("uEye", (gl, loc) => {
      gl.uniform3fv(loc, pathTracer.getGUI().getCamera().pos().xyz);
    });

    const rayUniforms = ["uRay00", "uRay01", "uRay10", "uRay11"];
    const rayKeys = ["ray00", "ray01", "ray10", "ray11"] as const;

    rayUniforms.forEach((uniform, i) => {
      renderPass.addUniform(uniform, (gl, loc) => {
        gl.uniform3fv(loc, pathTracer.getCachedCameraRays()[rayKeys[i]].xyz);
      });
    });
  }

  protected addTimeUniforms(renderPass: RenderPass, pathTracer: PathTracer): void {
    renderPass.addUniform("uTime", (gl, loc) => {
      const timeSinceStart = (new Date().getMilliseconds() - pathTracer.getStartTime().getMilliseconds()) * 0.001;
      gl.uniform1f(loc, timeSinceStart);
    });
  }

  protected addRenderingUniforms(renderPass: RenderPass, pathTracer: PathTracer): void {
    renderPass.addUniform("uTextureWeight", (gl, loc) => {
      gl.uniform1f(loc, pathTracer.getTextureWeight());
    });

    renderPass.addUniform("uRes", (gl, loc) => {
      gl.uniform2f(loc, this.canvas.width, this.canvas.height);
    });

    renderPass.addUniform("uViewMatPrev", (gl, loc) => {
      gl.uniformMatrix4fv(loc, false, pathTracer.getGUI().getCamera().getViewMatrixPrevious());
    });

    renderPass.addUniform("uProjMatPrev", (gl, loc) => {
      gl.uniformMatrix4fv(loc, false, pathTracer.getGUI().getCamera().getProjMatrixPrevious());
    });
  }

  private updateTextureData<T extends Float32Array | Uint8Array | Uint16Array | Uint32Array>(
    gl: WebGL2RenderingContext,
    texture: WebGLTexture,
    width: number,
    height: number,
    data: T,
    options: { internalFormat: number; format: number; type: number; }
  ): WebGLTexture {
    const texelCount = width * height;
    const channels = 4;
    const expectedLength = texelCount * channels;

    let paddedData: T;
    if (this.logged) {
      console.log(`Updating texture data: width=${width}, height=${height}, expectedLength=${expectedLength}, actualLength=${data.length}`);
    }
    if (data.length < expectedLength) {
      const TypedArrayConstructor = (data.constructor as new (length: number) => T);
      paddedData = new TypedArrayConstructor(expectedLength);
      paddedData.set(data);
    } else {
      paddedData = data;
    }
    gl.activeTexture(gl.TEXTURE31); // Use a high texture unit to avoid conflicts
    gl.bindTexture(gl.TEXTURE_2D, texture);
    gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.NEAREST);
    gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, gl.NEAREST);
    gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_S, gl.CLAMP_TO_EDGE);
    gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_T, gl.CLAMP_TO_EDGE);
    gl.getExtension('EXT_color_buffer_float');
    gl.texImage2D(
      gl.TEXTURE_2D,
      0,
      options.internalFormat,
      width,
      height,
      0,
      options.format,
      options.type,
      paddedData
    );
    gl.bindTexture(gl.TEXTURE_2D, null);
    return texture;
  }

  protected DEBUG_PRINT_TEXTURE(gl: WebGL2RenderingContext, texture: WebGLTexture) {
    const width = 16;
    const height = 16;
    const framebuffer = gl.createFramebuffer();
    gl.bindFramebuffer(gl.FRAMEBUFFER, framebuffer);
    gl.framebufferTexture2D(
      gl.FRAMEBUFFER, gl.COLOR_ATTACHMENT0, gl.TEXTURE_2D, texture, 0
    );
    if (gl.checkFramebufferStatus(gl.FRAMEBUFFER) !== gl.FRAMEBUFFER_COMPLETE) {
      console.error("Framebuffer not complete");
    }
    const pixels = new Float32Array(width * height * 4); // RGBA float
    gl.readPixels(
      0, 0, width, height, gl.RGBA, gl.FLOAT, pixels
    );
    gl.bindFramebuffer(gl.FRAMEBUFFER, null);
    console.log("Texture data:", pixels.slice(0, 32));
  }

  protected getFloatOptions(gl: WebGL2RenderingContext): { internalFormat: number; format: number; type: number } {
    return {
      internalFormat: gl.RGBA32F,
      format: gl.RGBA,
      type: gl.FLOAT
    };
  }

  protected getSceneTextureSize(gl: WebGL2RenderingContext): number {
    const numFaces = this.animationManager.getAllVertices().length / 3 / 3; // Assuming 3 vertices per face
    const maxTreeNodes = 2 * numFaces; // Maximum number of nodes in the BVH tree

    const VEC3_SIZE = 3;
    const BOUNDING_BOX_SIZE = VEC3_SIZE * 2; // min and max for each bounding box
    const TEXEL_SIZE = 4; // RGBA
    const maxSize = Math.ceil(maxTreeNodes * BOUNDING_BOX_SIZE / TEXEL_SIZE);
    // 2n for max tree size * vec3 * 2 for each bounding box (min and max) / vec4 size per texel
    return Math.ceil(Math.sqrt(maxSize));
  }

  protected addAnimationUniforms(renderPass: RenderPass): number {
    const TEXTURE_SIZE = 8;
    renderPass.addUniform(`uSceneAllVertices`, (gl, loc) => {
      let FLOAT_OPTIONS = {internalFormat: gl.RGBA32F, format: gl.RGBA, type: gl.FLOAT};
      if (this.sceneTextureConfig === null) {
        throw new Error("Scene texture config is not initialized");
      }
      if (this.logged) {
        console.log("Adding uSceneAllVertices");
      }
      const size = this.getSceneTextureSize(gl);
      const texture = this.updateTextureData(gl, this.sceneTextureConfig.textures[0], size, size, this.animationManager.getAllVertices(), FLOAT_OPTIONS);
      gl.activeTexture(gl.TEXTURE0);
      gl.bindTexture(gl.TEXTURE_2D, texture);
      gl.uniform1i(loc, 0);
    });
    renderPass.addUniform("uSceneAllNormals", (gl, loc) => {
      let FLOAT_OPTIONS = {internalFormat: gl.RGBA32F, format: gl.RGBA, type: gl.FLOAT};
      if (this.sceneTextureConfig === null) {
        throw new Error("Scene texture config is not initialized");
      }
      if (this.logged) {
        console.log("Adding uSceneAllNormals");
      }
      const size = this.getSceneTextureSize(gl);
      const texture = this.updateTextureData(gl, this.sceneTextureConfig.textures[1], size, size, this.animationManager.getAllNormals(), FLOAT_OPTIONS);
      gl.activeTexture(gl.TEXTURE0 + 1);
      gl.bindTexture(gl.TEXTURE_2D, texture);
      gl.uniform1i(loc, 1);
    });

    renderPass.addUniform("uSceneBoundingBoxes", (gl, loc) => {
      let FLOAT_OPTIONS = {internalFormat: gl.RGBA32F, format: gl.RGBA, type: gl.FLOAT};
      if (this.sceneTextureConfig === null) {
        throw new Error("Scene texture config is not initialized");
      }
      if (this.logged) {
        console.log("Adding uSceneAllBoundingBoxes");
      }
      const size = this.getSceneTextureSize(gl);
      const texture = this.updateTextureData(gl, this.sceneTextureConfig.textures[2], size, size, this.animationManager.getBoundingBoxes(), FLOAT_OPTIONS);
      gl.activeTexture(gl.TEXTURE0 + 2);
      gl.bindTexture(gl.TEXTURE_2D, texture);
      gl.uniform1i(loc, 2);
    });

    renderPass.addUniform("uSceneChildIndices", (gl, loc) => {
      let UNSIGNED_OPTIONS = {internalFormat: gl.RGBA32UI, format: gl.RGBA_INTEGER, type: gl.UNSIGNED_INT};
      if (this.sceneTextureConfig === null) {
        throw new Error("Scene texture config is not initialized");
      }
      if (this.logged) {
        console.log("Adding uSceneAllChildIndices");
      }
      const size = this.getSceneTextureSize(gl);
      const texture = this.updateTextureData(gl, this.sceneTextureConfig.textures[3], size, size, this.animationManager.getChildIndices(), UNSIGNED_OPTIONS);
      gl.activeTexture(gl.TEXTURE0 + 3);
      gl.bindTexture(gl.TEXTURE_2D, texture);
      gl.uniform1i(loc, 3);
    });

    renderPass.addUniform("uSceneMeshIndices", (gl, loc) => {
      let UNSIGNED_OPTIONS = {internalFormat: gl.RGBA32UI, format: gl.RGBA_INTEGER, type: gl.UNSIGNED_INT};
      if (this.sceneTextureConfig === null) {
        throw new Error("Scene texture config is not initialized");
      }
      if (this.logged) {
        console.log("Adding uSceneAllMeshIndices");
      }
      const size = this.getSceneTextureSize(gl);
      const texture = this.updateTextureData(gl, this.sceneTextureConfig.textures[4], size, size, this.animationManager.getMeshIndices(), UNSIGNED_OPTIONS);
      if (this.logged) {
        this.logged = this.logged - 1;
      }
      gl.activeTexture(gl.TEXTURE0 + 4);
      gl.bindTexture(gl.TEXTURE_2D, texture);
      gl.uniform1i(loc, 4);
    });
    renderPass.addUniform("uSceneTextureSize", (gl, loc) => {
      const size = this.getSceneTextureSize(gl);
      gl.uniform1i(loc, size);
    });
    renderPass.addUniform("uSceneNumFaces", (gl, loc) => {
      const numFaces = this.animationManager.getNumFaces();
      gl.uniform1i(loc, numFaces);
    });
    renderPass.addUniform("uSceneRootIdx", (gl, loc) => {
      const rootIndex = this.animationManager.getRootIdx();
      gl.uniform1i(loc, rootIndex);
    });
    return 0;
  }
}