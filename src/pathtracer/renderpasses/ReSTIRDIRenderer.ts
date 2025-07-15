// ReSTIR Temporal Renderer
import {BaseRenderer, TextureConfig} from "./BaseRenderer";
import {RenderPass} from "../../lib/webglutils/RenderPass";
import {pathTracerVSText, ReSTIR_spatialPassFSText, ReSTIR_temporalPassFSText} from "../Shaders";
import {PathTracer} from "../App";

export default class ReSTIRDIRenderer extends BaseRenderer {
    private spatialTemporalConfig: TextureConfig;
    private pingpong: number = 0;
    private static readonly RESERVOIR_TEXTURES = 2;
    private static readonly PING_PONG_OFFSET = ReSTIRDIRenderer.RESERVOIR_TEXTURES + 2; // 2 for reservoirs + 1 for depthmap
    private pathTracer: PathTracer;

    protected initialize(pathTracer: PathTracer): void {
        const type = this.gl.getExtension('OES_texture_float') ? this.gl.FLOAT : this.gl.UNSIGNED_BYTE;
        this.frameBuffer = this.gl.createFramebuffer();
        this.spatialTemporalConfig = this.createTextureConfig(ReSTIRDIRenderer.PING_PONG_OFFSET * 2, type);

        this.renderPasses.restirTemporal = new RenderPass(this.gl, pathTracerVSText, ReSTIR_temporalPassFSText);
        this.renderPasses.restirTemporal1 = new RenderPass(this.gl, pathTracerVSText, ReSTIR_temporalPassFSText);
        this.renderPasses.restirSpatial = new RenderPass(this.gl, pathTracerVSText, ReSTIR_spatialPassFSText);
        this.renderPasses.restirSpatial1 = new RenderPass(this.gl, pathTracerVSText, ReSTIR_spatialPassFSText);

        this.pathTracer = pathTracer;

        this.setupPasses(pathTracer);
    }

    public render(): void {
        const gl = this.gl as WebGL2RenderingContext;
        const writeStartIndex = this.pingpong === 0 ? ReSTIRDIRenderer.PING_PONG_OFFSET : 0;

        gl.bindFramebuffer(gl.FRAMEBUFFER, this.frameBuffer);
        let buffers = [];
        for (let i = 0; i < ReSTIRDIRenderer.PING_PONG_OFFSET; i++) {
            gl.framebufferTexture2D(gl.FRAMEBUFFER, gl.COLOR_ATTACHMENT0 + i, gl.TEXTURE_2D, this.spatialTemporalConfig.textures[writeStartIndex + i], 0);
            buffers.push(gl.COLOR_ATTACHMENT0 + i);
        }

        gl.drawBuffers(buffers);

        const temporalPass = this.pingpong === 0 ? this.renderPasses.restirTemporal : this.renderPasses.restirTemporal1;
        temporalPass.draw();

        gl.bindFramebuffer(gl.FRAMEBUFFER, null);
        const spatialPass = this.pingpong == 0 ? this.renderPasses.restirSpatial1 : this.renderPasses.restirSpatial;
        spatialPass.draw();
        this.pingpong = 1 - this.pingpong;
        this.pathTracer.getGUI().getCamera().updateViewMatrixNext();
    }

    private setupPasses(pathTracer: PathTracer): void {
        this.setupTemporalPass(this.renderPasses.restirTemporal, pathTracer, 0);
        this.setupTemporalPass(this.renderPasses.restirTemporal1, pathTracer, ReSTIRDIRenderer.PING_PONG_OFFSET);
        this.setupSpatialPass(this.renderPasses.restirSpatial, pathTracer, 0);
        this.setupSpatialPass(this.renderPasses.restirSpatial1, pathTracer, ReSTIRDIRenderer.PING_PONG_OFFSET);
    }

    private setupTemporalPass(renderPass: RenderPass, pathTracer: PathTracer, offset: number): void {
        const numIndices = this.setupRayRenderPass(renderPass, pathTracer);

        for (let i = 0; i < ReSTIRDIRenderer.RESERVOIR_TEXTURES; i++) {
            renderPass.addUniform(`uReservoirData${i + 1}`, (gl, loc) => {
                gl.activeTexture(gl.TEXTURE0 + i);
                gl.bindTexture(gl.TEXTURE_2D, this.spatialTemporalConfig.textures[i + offset]);
                gl.uniform1i(loc, i);
            });
        }
        renderPass.addUniform(`uDepthMap`, (gl, loc) => {
            gl.activeTexture(gl.TEXTURE0 + 2);
            gl.bindTexture(gl.TEXTURE_2D, this.spatialTemporalConfig.textures[2 + offset]);
            gl.uniform1i(loc, 2);
        });

        renderPass.addUniform(`uNormalMap`, (gl, loc) => {
            gl.activeTexture(gl.TEXTURE0 + 3);
            gl.bindTexture(gl.TEXTURE_2D, this.spatialTemporalConfig.textures[3 + offset]);
            gl.uniform1i(loc, 3);
        });

        renderPass.setDrawData(this.gl.TRIANGLES, numIndices, this.gl.UNSIGNED_SHORT, 0);
        renderPass.setup();
    }

    private setupSpatialPass(renderPass: RenderPass, pathTracer: PathTracer, offset: number): void {
        const numIndices = this.setupRayRenderPass(renderPass, pathTracer);

        for (let i = 0; i < ReSTIRDIRenderer.RESERVOIR_TEXTURES; i++) {
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