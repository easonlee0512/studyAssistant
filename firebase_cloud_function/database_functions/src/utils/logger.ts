import * as logger from "firebase-functions/logger";

export const Logger = {
  // 一般資訊
  info: (message: string, data?: any) => {
    logger.info(message, data);
  },

  // 警告
  warn: (message: string, data?: any) => {
    logger.warn(message, data);
  },

  // 錯誤
  error: (message: string, error: Error, data?: any) => {
    logger.error(message, {
      error: {
        name: error.name,
        message: error.message,
        stack: error.stack,
      },
      ...data,
    });
  },

  // 函數執行追蹤
  trace: (functionName: string, userId: string, action: string, data?: any) => {
    logger.info(`[${functionName}] ${action}`, {
      userId,
      timestamp: new Date().toISOString(),
      ...data,
    });
  },
};
