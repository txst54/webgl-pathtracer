// ReSTIR Temporal Renderer
import {BaseRenderer, TextureConfig} from "./BaseRenderer";
import {RenderPass} from "../../lib/webglutils/RenderPass";
import {pathTracerVSText, ReSTIR_spatialPassFSText, ReSTIR_temporalPassFSText} from "../Shaders";
import {PathTracer} from "../App";

export default class ReSTIRGIRenderer extends BaseRenderer {
    private spatialTemporalConfig: TextureConfig;
    private pingpong: number = 0;
    private pathTracer: PathTracer;

    protected initialize(pathTracer: PathTracer): void {
        const type = this.gl.getExtension('OES_texture_float') ? this.gl.FLOAT : this.gl.UNSIGNED_BYTE;
        this.frameBuffer = this.gl.createFramebuffer();
        this.spatialTemporalConfig = this.createTextureConfig(5, type);

        this.renderPasses.restirTemporal = new RenderPass(this.gl, pathTracerVSText, ReSTIR_temporalPassFSText);
        this.renderPasses.restirTemporal1 = new RenderPass(this.gl, pathTracerVSText, ReSTIR_temporalPassFSText);
        this.renderPasses.restirSpatial = new RenderPass(this.gl, pathTracerVSText, ReSTIR_spatialPassFSText);
        this.renderPasses.restirSpatial1 = new RenderPass(this.gl, pathTracerVSText, ReSTIR_spatialPassFSText);

        this.pathTracer = pathTracer;

        this.setupPasses(pathTracer);
    }

    public render(): void {
        const gl = this.gl as WebGL2RenderingContext;
        const writeStartIndex = this.pingpong === 0 ? 2 : 0;

        gl.bindFramebuffer(gl.FRAMEBUFFER, this.frameBuffer);
        gl.framebufferTexture2D(gl.FRAMEBUFFER, gl.COLOR_ATTACHMENT0, gl.TEXTURE_2D, this.spatialTemporalConfig.textures[writeStartIndex], 0);
        gl.framebufferTexture2D(gl.FRAMEBUFFER, gl.COLOR_ATTACHMENT1, gl.TEXTURE_2D, this.spatialTemporalConfig.textures[writeStartIndex + 1], 0);
        gl.framebufferTexture2D(gl.FRAMEBUFFER, gl.COLOR_ATTACHMENT2, gl.TEXTURE_2D, this.spatialTemporalConfig.textures[4], 0);
        gl.drawBuffers([gl.COLOR_ATTACHMENT0, gl.COLOR_ATTACHMENT1, gl.COLOR_ATTACHMENT2]);

        const temporalPass = this.pingpong === 0 ? this.renderPasses.restirTemporal : this.renderPasses.restirTemporal1;
        temporalPass.draw();

        this.pingpong = 1 - this.pingpong;
        this.pathTracer.getGUI().getCamera().updateViewMatrixNext();

        gl.bindFramebuffer(gl.FRAMEBUFFER, null);
        const spatialPass = this.pingpong == 0 ? this.renderPasses.restirSpatial1 : this.renderPasses.restirSpatial;
        spatialPass.draw();
    }

    private setupPasses(pathTracer: PathTracer): void {
        this.setupTemporalPass(this.renderPasses.restirTemporal, pathTracer, 0);
        this.setupTemporalPass(this.renderPasses.restirTemporal1, pathTracer, 2);
        this.setupSpatialPass(this.renderPasses.restirSpatial, pathTracer, 0);
        this.setupSpatialPass(this.renderPasses.restirSpatial1, pathTracer, 2);
    }

    private setupTemporalPass(renderPass: RenderPass, pathTracer: PathTracer, offset: number): void {
        const numIndices = this.setupRayRenderPass(renderPass, pathTracer);

        for (let i = 0; i < 2; i++) {
            renderPass.addUniform(`uReservoirData${i + 1}`, (gl, loc) => {
                gl.activeTexture(gl.TEXTURE0 + i);
                gl.bindTexture(gl.TEXTURE_2D, this.spatialTemporalConfig.textures[i + offset]);
                gl.uniform1i(loc, i);
            });
        }

        renderPass.setDrawData(this.gl.TRIANGLES, numIndices, this.gl.UNSIGNED_SHORT, 0);
        renderPass.setup();
    }

    private setupSpatialPass(renderPass: RenderPass, pathTracer: PathTracer, offset: number): void {
        const numIndices = this.setupRayRenderPass(renderPass, pathTracer);

        for (let i = 0; i < 2; i++) {
            renderPass.addUniform(`uReservoirData${i + 1}`, (gl, loc) => {
                gl.activeTexture(gl.TEXTURE0 + i);
                gl.bindTexture(gl.TEXTURE_2D, this.spatialTemporalConfig.textures[i + offset]);
                gl.uniform1i(loc, i);
            });
        }

        renderPass.setDrawData(this.gl.TRIANGLES, numIndices, this.gl.UNSIGNED_SHORT, 0);
        renderPass.setup();
    }
}