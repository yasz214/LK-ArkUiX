export const parseArticleJson: (rawContent: string, fullJsonString: string) => string;

export const parseCommentJson: (content: string) => string;

export const adaptColor: (hexColor: string, isDark: boolean) => string;

export const parseBBCodeJson: (text: string) => string;

export const benchmark: (rawContent: string, fullJsonString: string, iterations: number) => string;
