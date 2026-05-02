export const initEngine: (keys: string[], values: string[]) => boolean;

export const convertText: (text: string) => string;

export const convertBatch: (texts: string[]) => string[];

export const benchmark: (text: string, iterations: number) => string;
