// ReSTIR Spatial Renderer
import {BaseRenderer} from "./BaseRenderer";
import {RenderPass} from "../../lib/webglutils/RenderPass";
import {pathTracerVSText, ReSTIR_initialPassFSText, ReSTIR_spatialPassFSText} from "../Shaders";
import {PathTracer} from "../App";

export default class ReSTIRDISpatialRenderer extends BaseRenderer {
    protected initialize(pathTracer: PathTracer): void {
        const type = this.gl.getExtension('OES_texture_float') ? this.gl.FLOAT : this.gl.UNSIGNED_BYTE;
        this.frameBuffer = this.gl.createFramebuffer();
        this.textureConfig = this.createTextureConfig(2, type);

        this.renderPasses.restirInit = new RenderPass(this.gl, pathTracerVSText, ReSTIR_initialPassFSText);
        this.renderPasses.restirSpatial = new RenderPass(this.gl, pathTracerVSText, ReSTIR_spatialPassFSText);

        this.setupPasses(pathTracer);
    }

    public render(): void {
        const gl = this.gl as WebGL2RenderingContext;

        gl.bindFramebuffer(gl.FRAMEBUFFER, this.frameBuffer);
        // gl.bindFramebuffer(gl.FRAMEBUFFER, null);
        gl.framebufferTexture2D(gl.FRAMEBUFFER, gl.COLOR_ATTACHMENT0, gl.TEXTURE_2D, this.textureConfig.textures[0], 0);
        gl.framebufferTexture2D(gl.FRAMEBUFFER, gl.COLOR_ATTACHMENT1, gl.TEXTURE_2D, this.textureConfig.textures[1], 0);
        gl.drawBuffers([gl.COLOR_ATTACHMENT0, gl.COLOR_ATTACHMENT1]);
        this.renderPasses.restirInit.draw();
        gl.finish();

        gl.bindFramebuffer(gl.FRAMEBUFFER, null);
        this.renderPasses.restirSpatial.draw();
    }

    private setupPasses(pathTracer: PathTracer): void {
        // Setup initial pass
        const numIndices1 = this.setupRayRenderPass(this.renderPasses.restirInit, pathTracer);
        this.renderPasses.restirInit.setDrawData(this.gl.TRIANGLES, numIndices1, this.gl.UNSIGNED_SHORT, 0);
        this.renderPasses.restirInit.setup();

        // Setup spatial pass
        const numIndices2 = this.setupRayRenderPass(this.renderPasses.restirSpatial, pathTracer);
        for (let i = 0; i < this.textureConfig.count; i++) {
            this.renderPasses.restirSpatial.addUniform(`uReservoirData${i + 1}`, (gl, loc) => {
                gl.activeTexture(gl.TEXTURE0 + i);
                gl.bindTexture(gl.TEXTURE_2D, this.textureConfig.textures[i]);
                gl.uniform1i(loc, i);
            });
        }
        this.renderPasses.restirSpatial.setDrawData(this.gl.TRIANGLES, numIndices2, this.gl.UNSIGNED_SHORT, 0);
        this.renderPasses.restirSpatial.setup();
    }
}