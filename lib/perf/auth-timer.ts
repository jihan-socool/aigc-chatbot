// Performance monitoring for authentication flow
// Tracks timing of different steps: DB connect, query, JWT sign, etc.

export class AuthTimer {
  private readonly startTime: number;
  private readonly marks: Map<string, number>;

  constructor() {
    this.startTime = performance.now();
    this.marks = new Map();
  }

  mark(label: string): void {
    const now = performance.now();
    this.marks.set(label, now);
  }

  getElapsed(label: string): number {
    const markTime = this.marks.get(label);
    if (!markTime) {
      return -1; // Mark not found
    }
    return markTime - this.startTime;
  }

  getTimeSince(label: string): number {
    const markTime = this.marks.get(label);
    if (!markTime) {
      return -1; // Mark not found
    }
    const now = performance.now();
    return now - markTime;
  }

  getTotalElapsed(): number {
    return performance.now() - this.startTime;
  }

  getMetrics(): Record<string, number> {
    const metrics: Record<string, number> = {
      total: this.getTotalElapsed(),
    };

    const sortedMarks = Array.from(this.marks.entries()).sort(
      ([, timeA], [, timeB]) => timeA - timeB
    );

    for (let i = 0; i < sortedMarks.length; i++) {
      const [label, time] = sortedMarks[i];
      const prevTime = i > 0 ? sortedMarks[i - 1][1] : this.startTime;
      metrics[`${label}_total`] = time - this.startTime;
      metrics[`${label}_delta`] = time - prevTime;
    }

    return metrics;
  }

  logMetrics(prefix = "Auth"): void {
    const metrics = this.getMetrics();
    const metricsStr = Object.entries(metrics)
      .map(([key, value]) => `${key}=${value.toFixed(2)}ms`)
      .join(", ");
    console.log(`[${prefix}] ${metricsStr}`);
  }
}
