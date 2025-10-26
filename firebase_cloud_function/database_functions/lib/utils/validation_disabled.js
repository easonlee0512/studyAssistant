"use strict";
// 暫時停用 Zod 驗證，待安裝 zod 套件後啟用
// 安裝方式: sudo npm install zod
Object.defineProperty(exports, "__esModule", { value: true });
exports.validateData = validateData;
/*
import { z } from "zod";

// 任務驗證 Schema
export const TaskSchema = z.object({
  title: z.string()
    .min(1, "標題不可為空")
    .max(200, "標題不可超過 200 字"),
  description: z.string().optional(),
  category: z.string().optional(),
  isCompleted: z.boolean(),
  startDate: z.any(), // Firestore Timestamp
  endDate: z.any().optional(),
  repeatType: z.object({
    type: z.enum(["none", "daily", "weekly", "monthly"]),
    endDate: z.any().optional(),
  }).optional(),
});

// 使用者資料驗證 Schema
export const UserProfileSchema = z.object({
  username: z.string()
    .min(1, "使用者名稱不可為空")
    .max(50, "使用者名稱不可超過 50 字")
    .optional(),
  email: z.string().email("無效的電子郵件格式").optional(),
  motivationalQuote: z.string().max(200).optional(),
  userGoal: z.string().max(200).optional(),
  learningStage: z.string().max(50).optional(),
  isVIP: z.boolean().optional(),
  targetDate: z.any().optional(),
});

// 統計資料驗證 Schema
export const StatisticSchema = z.object({
  category: z.string().min(1, "類別不可為空"),
  progress: z.number().min(0).max(1),
  taskcount: z.number().int().min(0),
  taskcompletecount: z.number().int().min(0),
  totalFocusTime: z.number().min(0),
  date: z.any(),
});

// 類別統計更新驗證 Schema
export const CategoryStatsUpdateSchema = z.object({
  progress: z.number().min(0).max(1).optional(),
  taskCount: z.number().int().optional(),
  taskCompleteCount: z.number().int().optional(),
  focusTime: z.number().optional(),
});

// 應用設定驗證 Schema
export const AppSettingsSchema = z.object({
  notificationsEnabled: z.boolean().optional(),
}).passthrough(); // 允許其他欄位

// 驗證輔助函數
export function validateData<T>(
  schema: z.ZodSchema<T>,
  data: unknown
): { success: true; data: T } | { success: false; errors: string[] } {
  try {
    const validatedData = schema.parse(data);
    return { success: true, data: validatedData };
  } catch (error: unknown) {
    if (error instanceof z.ZodError) {
      return {
        success: false,
        errors: error.errors.map((e: z.ZodIssue) => e.message),
      };
    }
    return {
      success: false,
      errors: ["驗證失敗"],
    };
  }
}
*/
// 暫時的簡單驗證函數（不使用 Zod）
function validateData(schema, data) {
    // 簡單的驗證 - 只檢查是否為物件
    if (typeof data === "object" && data !== null) {
        return { success: true, data: data };
    }
    return {
        success: false,
        errors: ["無效的資料格式"],
    };
}
//# sourceMappingURL=validation_disabled.js.map