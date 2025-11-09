"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.Errors = exports.APIError = exports.ErrorCode = void 0;
const https_1 = require("firebase-functions/v2/https");
// 標準錯誤代碼
var ErrorCode;
(function (ErrorCode) {
    // 客戶端錯誤 (4xx)
    ErrorCode["UNAUTHENTICATED"] = "unauthenticated";
    ErrorCode["PERMISSION_DENIED"] = "permission-denied";
    ErrorCode["INVALID_ARGUMENT"] = "invalid-argument";
    ErrorCode["NOT_FOUND"] = "not-found";
    ErrorCode["ALREADY_EXISTS"] = "already-exists";
    ErrorCode["RESOURCE_EXHAUSTED"] = "resource-exhausted";
    // 伺服器錯誤 (5xx)
    ErrorCode["INTERNAL"] = "internal";
    ErrorCode["UNAVAILABLE"] = "unavailable";
    ErrorCode["DEADLINE_EXCEEDED"] = "deadline-exceeded";
})(ErrorCode || (exports.ErrorCode = ErrorCode = {}));
// 自訂錯誤類別
class APIError extends https_1.HttpsError {
    constructor(code, message, details) {
        super(code, message, details || {});
        this.name = "APIError";
    }
}
exports.APIError = APIError;
// 錯誤工廠函數
exports.Errors = {
    // 認證錯誤
    Unauthenticated: (message = "需要登入") => new APIError("unauthenticated", message),
    // 權限錯誤
    PermissionDenied: (message = "權限不足") => new APIError("permission-denied", message),
    // 驗證錯誤
    InvalidArgument: (message, details) => new APIError("invalid-argument", message, details),
    // 資源不存在
    NotFound: (resource) => new APIError("not-found", `${resource}不存在`),
    // 資源已存在
    AlreadyExists: (resource) => new APIError("already-exists", `${resource}已存在`),
    // 內部錯誤
    Internal: (message = "內部伺服器錯誤", error) => {
        console.error("Internal error:", error);
        return new APIError("internal", message);
    },
    // 服務不可用
    Unavailable: (message = "服務暫時不可用") => new APIError("unavailable", message),
};
//# sourceMappingURL=errors.js.map