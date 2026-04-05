export const parseArticle: (rawContent: string, fullJsonString: string) => string;

export const parseComment: (content: string) => string;

export const adaptColor: (hexColor: string, isDark: boolean) => string;

export const parseBBCode: (text: string) => string;
