export class FPSCounter {
    private static readonly UPDATE_INTERVAL = 500; // ms

    private frameCount = 0;
    private lastTime = performance.now();
    private fps = 0;
    private frameTime = 0;
    private sampleCount = 0;
    private currentMode = 0;
    private modeNames: string[] = [];

    constructor(modeNames: string[] = []) {
        this.modeNames = modeNames;
    }

    /**
     * Call this method once per frame to update FPS calculations
     */
    public update(): void {
        this.frameCount++;
        const currentTime = performance.now();
        const deltaTime = currentTime - this.lastTime;
        this.frameTime = deltaTime;

        if (deltaTime >= FPSCounter.UPDATE_INTERVAL) {
            this.fps = (this.frameCount * 1000) / deltaTime;
            this.frameCount = 0;
            this.lastTime = currentTime;
            this.updateDisplay();
        }
    }

    /**
     * Set the current sample count for display
     */
    public setSampleCount(count: number): void {
        this.sampleCount = count;
    }

    /**
     * Increment the sample count by 1
     */
    public incrementSampleCount(): void {
        this.sampleCount++;
    }

    /**
     * Reset the sample count to 0
     */
    public resetSampleCount(): void {
        this.sampleCount = 0;
    }

    /**
     * Set the current rendering mode
     */
    public setMode(mode: number): void {
        this.currentMode = mode;
    }

    /**
     * Update the mode names array
     */
    public setModeNames(modeNames: string[]): void {
        this.modeNames = modeNames;
    }

    /**
     * Get current FPS value
     */
    public getFPS(): number {
        return this.fps;
    }

    /**
     * Get current frame time in milliseconds
     */
    public getFrameTime(): number {
        return this.frameTime;
    }

    /**
     * Get current sample count
     */
    public getSampleCount(): number {
        return this.sampleCount;
    }

    /**
     * Get current mode name
     */
    public getCurrentModeName(): string {
        return this.modeNames[this.currentMode] || `Mode ${this.currentMode}`;
    }

    /**
     * Update the DOM elements with current values
     */
    private updateDisplay(): void {
        const updates = [
            { id: 'fpsValue', value: this.fps.toFixed(1) },
            { id: 'frameTimeValue', value: this.frameTime.toFixed(2) },
            { id: 'sampleValue', value: this.sampleCount.toString() },
            { id: 'mode', value: this.getCurrentModeName() }
        ];

        updates.forEach(({ id, value }) => {
            const element = document.getElementById(id);
            if (element) {
                element.textContent = value;
            }
        });
    }

    /**
     * Force an immediate display update (useful for mode changes)
     */
    public forceDisplayUpdate(): void {
        this.updateDisplay();
    }
}