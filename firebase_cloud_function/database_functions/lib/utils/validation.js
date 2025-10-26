"use strict";
// 暫時停用 Zod 驗證，待安裝 zod 套件後啟用
// 安裝方式: sudo npm install zod
Object.defineProperty(exports, "__esModule", { value: true });
exports.AppSettingsSchema = exports.CategoryStatsUpdateSchema = exports.StatisticSchema = exports.UserProfileSchema = exports.TaskSchema = void 0;
exports.validateData = validateData;
const zod_1 = require("zod");
// 任務驗證 Schema
exports.TaskSchema = zod_1.z.object({
    title: zod_1.z.string()
        .min(1, "標題不可為空")
        .max(200, "標題不可超過 200 字"),
    description: zod_1.z.string().optional(),
    category: zod_1.z.string().optional(),
    isCompleted: zod_1.z.boolean(),
    startDate: zod_1.z.any(), // Firestore Timestamp
    endDate: zod_1.z.any().optional(),
    repeatType: zod_1.z.object({
        type: zod_1.z.enum(["none", "daily", "weekly", "monthly"]),
        endDate: zod_1.z.any().optional(),
    }).optional(),
});
// 使用者資料驗證 Schema
exports.UserProfileSchema = zod_1.z.object({
    username: zod_1.z.string()
        .min(1, "使用者名稱不可為空")
        .max(50, "使用者名稱不可超過 50 字")
        .optional(),
    email: zod_1.z.string().email("無效的電子郵件格式").optional(),
    motivationalQuote: zod_1.z.string().max(200).optional(),
    userGoal: zod_1.z.string().max(200).optional(),
    learningStage: zod_1.z.string().max(50).optional(),
    isVIP: zod_1.z.boolean().optional(),
    targetDate: zod_1.z.any().optional(),
});
// 統計資料驗證 Schema
exports.StatisticSchema = zod_1.z.object({
    category: zod_1.z.string().min(1, "類別不可為空"),
    progress: zod_1.z.number().min(0).max(1),
    taskcount: zod_1.z.number().int().min(0),
    taskcompletecount: zod_1.z.number().int().min(0),
    totalFocusTime: zod_1.z.number().min(0),
    date: zod_1.z.any(),
});
// 類別統計更新驗證 Schema
exports.CategoryStatsUpdateSchema = zod_1.z.object({
    progress: zod_1.z.number().min(0).max(1).optional(),
    taskCount: zod_1.z.number().int().optional(),
    taskCompleteCount: zod_1.z.number().int().optional(),
    focusTime: zod_1.z.number().optional(),
});
// 應用設定驗證 Schema
exports.AppSettingsSchema = zod_1.z.object({
    notificationsEnabled: zod_1.z.boolean().optional(),
}).passthrough(); // 允許其他欄位
// 驗證輔助函數
function validateData(schema, data) {
    try {
        const validatedData = schema.parse(data);
        return { success: true, data: validatedData };
    }
    catch (error) {
        if (error instanceof zod_1.z.ZodError) {
            return {
                success: false,
                errors: error.errors.map((e) => e.message),
            };
        }
        return {
            success: false,
            errors: ["驗證失敗"],
        };
    }
}
//# sourceMappingURL=validation.js.map