import { HttpsError } from "firebase-functions/v2/https";

// 標準錯誤代碼
export enum ErrorCode {
  // 客戶端錯誤 (4xx)
  UNAUTHENTICATED = "unauthenticated", // 401: 未認證
  PERMISSION_DENIED = "permission-denied", // 403: 權限不足
  INVALID_ARGUMENT = "invalid-argument", // 400: 無效參數
  NOT_FOUND = "not-found", // 404: 資源不存在
  ALREADY_EXISTS = "already-exists", // 409: 資源已存在
  RESOURCE_EXHAUSTED = "resource-exhausted", // 429: 超過配額

  // 伺服器錯誤 (5xx)
  INTERNAL = "internal", // 500: 內部錯誤
  UNAVAILABLE = "unavailable", // 503: 服務不可用
  DEADLINE_EXCEEDED = "deadline-exceeded", // 504: 超時
}

// 自訂錯誤類別
export class APIError extends HttpsError {
  constructor(
    code: string,
    message: string,
    details?: any
  ) {
    super(code as any, message, details || {});
    this.name = "APIError";
  }
}

// 錯誤工廠函數
export const Errors = {
  // 認證錯誤
  Unauthenticated: (message = "需要登入") =>
    new APIError("unauthenticated", message),

  // 權限錯誤
  PermissionDenied: (message = "權限不足") =>
    new APIError("permission-denied", message),

  // 驗證錯誤
  InvalidArgument: (message: string, details?: any) =>
    new APIError("invalid-argument", message, details),

  // 資源不存在
  NotFound: (resource: string) =>
    new APIError("not-found", `${resource}不存在`),

  // 資源已存在
  AlreadyExists: (resource: string) =>
    new APIError("already-exists", `${resource}已存在`),

  // 內部錯誤
  Internal: (message = "內部伺服器錯誤", error?: Error) => {
    console.error("Internal error:", error);
    return new APIError("internal", message);
  },

  // 服務不可用
  Unavailable: (message = "服務暫時不可用") =>
    new APIError("unavailable", message),
};
