"use strict";
/**
 * Import function triggers from their respective submodules:
 *
 * const {onCall} = require("firebase-functions/v2/https");
 * const {onDocumentWritten} = require("firebase-functions/v2/firestore");
 *
 * See a full list of supported triggers at https://firebase.google.com/docs/functions
 */
var __createBinding = (this && this.__createBinding) || (Object.create ? (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    var desc = Object.getOwnPropertyDescriptor(m, k);
    if (!desc || ("get" in desc ? !m.__esModule : desc.writable || desc.configurable)) {
      desc = { enumerable: true, get: function() { return m[k]; } };
    }
    Object.defineProperty(o, k2, desc);
}) : (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    o[k2] = m[k];
}));
var __setModuleDefault = (this && this.__setModuleDefault) || (Object.create ? (function(o, v) {
    Object.defineProperty(o, "default", { enumerable: true, value: v });
}) : function(o, v) {
    o["default"] = v;
});
var __importStar = (this && this.__importStar) || (function () {
    var ownKeys = function(o) {
        ownKeys = Object.getOwnPropertyNames || function (o) {
            var ar = [];
            for (var k in o) if (Object.prototype.hasOwnProperty.call(o, k)) ar[ar.length] = k;
            return ar;
        };
        return ownKeys(o);
    };
    return function (mod) {
        if (mod && mod.__esModule) return mod;
        var result = {};
        if (mod != null) for (var k = ownKeys(mod), i = 0; i < k.length; i++) if (k[i] !== "default") __createBinding(result, mod, k[i]);
        __setModuleDefault(result, mod);
        return result;
    };
})();
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.deleteStatistic = exports.updateCategoryStats = exports.updateAppSettings = exports.getAppSettings = exports.getUserProfile = exports.deleteTaskInstance = exports.createTaskInstance = exports.toggleTaskCompletion = exports.updateTask = exports.getTask = exports.fetchStudySettings = exports.updateStudySettings = exports.batchUpdateStatistics = exports.updateStatistic = exports.fetchStatistics = exports.fetchTokenUsage = exports.updateTokenUsage = exports.callChatGPT = exports.updateUserProfile = exports.updateTaskInstance = exports.deleteTask = exports.fetchTasks = exports.batchCreateTasks = exports.createTask = void 0;
const https_1 = require("firebase-functions/v2/https");
const admin = __importStar(require("firebase-admin"));
const firebaseAdmin_1 = require("./utils/firebaseAdmin");
const errors_1 = require("./utils/errors");
const logger_1 = require("./utils/logger");
const node_fetch_1 = __importDefault(require("node-fetch"));
// Create and deploy your first functions
// https://firebase.google.com/docs/functions/get-started
// exports.helloWorld = onRequest((request, response) => {
//   logger.info("Hello logs!", {structuredData: true});
//   response.send("Hello from Firebase!");
// });
// ============================================================================
// 輔助函數：重複任務實例生成
// ============================================================================
/**
 * 計算重複任務的實例日期
 * @param task 任務資料
 * @param limit 最大實例數量（預設 365）
 * @return Date 陣列
 */
function calculateNextOccurrences(task, limit = 365) {
    var _a, _b, _c;
    const occurrences = [];
    // 確保 startDate 是 Date 物件
    const startDate = task.startDate instanceof Date ?
        task.startDate :
        ((_a = task.startDate) === null || _a === void 0 ? void 0 : _a.toDate) ?
            task.startDate.toDate() :
            new Date(task.startDate);
    // 確保不超過結束日期
    let endDate;
    if (task.repeatEndDate) {
        endDate = task.repeatEndDate instanceof Date ?
            task.repeatEndDate :
            ((_b = task.repeatEndDate) === null || _b === void 0 ? void 0 : _b.toDate) ?
                task.repeatEndDate.toDate() :
                new Date(task.repeatEndDate);
    }
    else {
        // 如果沒有設定結束日期，預設為一年後
        endDate = new Date(startDate);
        endDate.setFullYear(endDate.getFullYear() + 1);
    }
    // 如果不是重複任務，返回空陣列
    if (!task.repeatType || task.repeatType.type === "none") {
        return occurrences;
    }
    // 先加入開始日期（當天）
    occurrences.push(new Date(startDate));
    let currentDate = new Date(startDate);
    while (occurrences.length < limit) {
        if (currentDate > endDate) {
            break;
        }
        let nextDate = null;
        switch ((_c = task.repeatType) === null || _c === void 0 ? void 0 : _c.type) {
            case "daily":
                nextDate = new Date(currentDate);
                nextDate.setDate(nextDate.getDate() + 1);
                break;
            case "weekly":
                // 使用創建時的星期幾
                nextDate = new Date(currentDate);
                nextDate.setDate(nextDate.getDate() + 7);
                break;
            case "monthly":
                // 使用創建時的日期
                const dayOfMonth = startDate.getDate();
                nextDate = new Date(currentDate);
                nextDate.setMonth(nextDate.getMonth() + 1);
                // 處理月末日期（如 1/31 → 2/28）
                const maxDay = new Date(nextDate.getFullYear(), nextDate.getMonth() + 1, 0).getDate();
                nextDate.setDate(Math.min(dayOfMonth, maxDay));
                break;
            case "none":
            default:
                return occurrences;
        }
        if (nextDate && nextDate <= endDate) {
            occurrences.push(nextDate);
            currentDate = nextDate;
        }
        else {
            break;
        }
    }
    return occurrences;
}
/**
 * 檢查是否需要重新生成實例
 * @param taskRef 任務文檔引用
 * @param newTask 新任務資料
 * @return boolean
 */
async function needsRegenerateInstances(taskRef, newTask) {
    var _a, _b, _c, _d, _e, _f, _g, _h, _j, _k, _l, _m, _o, _p, _q, _r, _s, _t, _u, _v, _w, _x, _y, _z, _0, _1, _2, _3, _4, _5, _6, _7;
    try {
        const doc = await taskRef.get();
        if (!doc.exists) {
            return true; // 新任務，需要生成實例
        }
        const oldData = doc.data();
        if (!oldData) {
            return true;
        }
        // 檢查重複類型是否改變
        const oldRepeatType = ((_a = oldData.repeatType) === null || _a === void 0 ? void 0 : _a.type) || "none";
        const newRepeatType = ((_b = newTask.repeatType) === null || _b === void 0 ? void 0 : _b.type) || "none";
        if (oldRepeatType !== newRepeatType) {
            return true;
        }
        // 如果都不是重複任務，不需要重新生成
        if (oldRepeatType === "none" && newRepeatType === "none") {
            return false;
        }
        // 檢查開始時間是否改變
        const oldStartTime = (_f = (_e = (_d = (_c = oldData.startDate) === null || _c === void 0 ? void 0 : _c.toDate) === null || _d === void 0 ? void 0 : _d.call(_c)) === null || _e === void 0 ? void 0 : _e.getTime) === null || _f === void 0 ? void 0 : _f.call(_e);
        const newStartTime = newTask.startDate instanceof Date ?
            newTask.startDate.getTime() :
            ((_k = (_j = (_h = (_g = newTask.startDate) === null || _g === void 0 ? void 0 : _g.toDate) === null || _h === void 0 ? void 0 : _h.call(_g)) === null || _j === void 0 ? void 0 : _j.getTime) === null || _k === void 0 ? void 0 : _k.call(_j)) || ((_m = (_l = newTask.startDate) === null || _l === void 0 ? void 0 : _l.getTime) === null || _m === void 0 ? void 0 : _m.call(_l));
        if (oldStartTime && newStartTime && oldStartTime !== newStartTime) {
            return true;
        }
        // 檢查結束時間是否改變
        const oldEndTime = (_r = (_q = (_p = (_o = oldData.endDate) === null || _o === void 0 ? void 0 : _o.toDate) === null || _p === void 0 ? void 0 : _p.call(_o)) === null || _q === void 0 ? void 0 : _q.getTime) === null || _r === void 0 ? void 0 : _r.call(_q);
        const newEndTime = newTask.endDate instanceof Date ?
            newTask.endDate.getTime() :
            ((_v = (_u = (_t = (_s = newTask.endDate) === null || _s === void 0 ? void 0 : _s.toDate) === null || _t === void 0 ? void 0 : _t.call(_s)) === null || _u === void 0 ? void 0 : _u.getTime) === null || _v === void 0 ? void 0 : _v.call(_u)) || ((_x = (_w = newTask.endDate) === null || _w === void 0 ? void 0 : _w.getTime) === null || _x === void 0 ? void 0 : _x.call(_w));
        if (oldEndTime !== newEndTime) {
            return true;
        }
        // 檢查重複結束時間是否改變
        const oldRepeatEndTime = (_1 = (_0 = (_z = (_y = oldData.repeatEndDate) === null || _y === void 0 ? void 0 : _y.toDate) === null || _z === void 0 ? void 0 : _z.call(_y)) === null || _0 === void 0 ? void 0 : _0.getTime) === null || _1 === void 0 ? void 0 : _1.call(_0);
        const newRepeatEndTime = newTask.repeatEndDate instanceof Date ?
            newTask.repeatEndDate.getTime() :
            ((_5 = (_4 = (_3 = (_2 = newTask.repeatEndDate) === null || _2 === void 0 ? void 0 : _2.toDate) === null || _3 === void 0 ? void 0 : _3.call(_2)) === null || _4 === void 0 ? void 0 : _4.getTime) === null || _5 === void 0 ? void 0 : _5.call(_4)) || ((_7 = (_6 = newTask.repeatEndDate) === null || _6 === void 0 ? void 0 : _6.getTime) === null || _7 === void 0 ? void 0 : _7.call(_6));
        if (oldRepeatEndTime !== newRepeatEndTime) {
            return true;
        }
        return false;
    }
    catch (error) {
        logger_1.Logger.error("needsRegenerateInstances", error, {});
        return true; // 如果出錯，為安全起見重新生成實例
    }
}
// ============================================================================
// 任務相關功能
// ============================================================================
exports.createTask = (0, https_1.onCall)({ region: "asia-east1" }, async (request) => {
    var _a, _b, _c;
    if (!request.auth) {
        throw errors_1.Errors.Unauthenticated();
    }
    const userId = request.auth.uid;
    const taskData = request.data.task;
    if (!taskData || !taskData.title) {
        throw errors_1.Errors.InvalidArgument("無效的任務資料");
    }
    logger_1.Logger.trace("createTask", userId, "開始創建任務", {
        title: taskData.title,
        repeatType: (_a = taskData.repeatType) === null || _a === void 0 ? void 0 : _a.type,
    });
    try {
        const batch = firebaseAdmin_1.db.batch();
        // 建立任務文檔引用
        const taskRef = firebaseAdmin_1.db.collection("tasks")
            .doc(userId)
            .collection("userTasks")
            .doc(); // 使用 doc() 生成 ID
        // 準備任務資料
        const taskDataToSave = Object.assign(Object.assign({}, taskData), { userId, createdAt: admin.firestore.FieldValue.serverTimestamp(), updatedAt: admin.firestore.FieldValue.serverTimestamp() });
        // 處理重複任務的結束日期
        if (((_b = taskData.repeatType) === null || _b === void 0 ? void 0 : _b.type) && taskData.repeatType.type !== "none") {
            if (taskData.repeatEndDate) {
                taskDataToSave.repeatEndDate = taskData.repeatEndDate;
            }
            else {
                // 如果沒有設定結束日期，預設為一年後
                const startDate = taskData.startDate instanceof admin.firestore.Timestamp ?
                    taskData.startDate.toDate() :
                    new Date(taskData.startDate);
                const oneYearLater = new Date(startDate);
                oneYearLater.setFullYear(oneYearLater.getFullYear() + 1);
                taskDataToSave.repeatEndDate = admin.firestore.Timestamp.fromDate(oneYearLater);
            }
        }
        // 設置任務資料
        batch.set(taskRef, taskDataToSave);
        // 如果是重複性任務，生成實例
        if (((_c = taskData.repeatType) === null || _c === void 0 ? void 0 : _c.type) && taskData.repeatType.type !== "none") {
            // 準備用於計算的任務物件
            const taskForCalculation = {
                startDate: taskData.startDate instanceof admin.firestore.Timestamp ?
                    taskData.startDate.toDate() :
                    new Date(taskData.startDate),
                endDate: taskData.endDate instanceof admin.firestore.Timestamp ?
                    taskData.endDate.toDate() :
                    taskData.endDate ? new Date(taskData.endDate) : null,
                repeatType: taskData.repeatType,
                repeatEndDate: taskDataToSave.repeatEndDate instanceof admin.firestore.Timestamp ?
                    taskDataToSave.repeatEndDate.toDate() :
                    taskDataToSave.repeatEndDate ?
                        new Date(taskDataToSave.repeatEndDate) :
                        null,
            };
            const occurrences = calculateNextOccurrences(taskForCalculation, 365);
            logger_1.Logger.trace("createTask", userId, "生成重複任務實例", {
                taskId: taskRef.id,
                repeatType: taskData.repeatType.type,
                instanceCount: occurrences.length,
            });
            for (const date of occurrences) {
                const instanceRef = taskRef.collection("instances").doc();
                batch.set(instanceRef, {
                    date: admin.firestore.Timestamp.fromDate(date),
                    isCompleted: false,
                    parentTaskId: taskRef.id,
                    createdAt: admin.firestore.FieldValue.serverTimestamp(),
                });
            }
        }
        await batch.commit();
        logger_1.Logger.trace("createTask", userId, "任務創建成功", { taskId: taskRef.id });
        return {
            success: true,
            taskId: taskRef.id,
        };
    }
    catch (error) {
        logger_1.Logger.error("createTask", error, { userId });
        throw errors_1.Errors.Internal("創建任務失敗", error);
    }
});
exports.batchCreateTasks = (0, https_1.onCall)({ region: "asia-east1" }, async (request) => {
    if (!request.auth) {
        throw new Error("需要登入");
    }
    const userId = request.auth.uid;
    const tasks = request.data.tasks;
    if (!Array.isArray(tasks)) {
        throw new Error("無效的任務資料");
    }
    try {
        const batch = firebaseAdmin_1.db.batch();
        const results = [];
        for (const task of tasks) {
            const taskRef = firebaseAdmin_1.db.collection("tasks")
                .doc(userId)
                .collection("userTasks")
                .doc();
            batch.set(taskRef, Object.assign(Object.assign({}, task), { userId, createdAt: admin.firestore.FieldValue.serverTimestamp(), updatedAt: admin.firestore.FieldValue.serverTimestamp() }));
            results.push({
                taskId: taskRef.id,
                originalTask: task,
            });
        }
        await batch.commit();
        return {
            success: true,
            results,
        };
    }
    catch (error) {
        console.error("批次創建任務失敗:", error);
        throw new Error("批次創建任務失敗");
    }
});
exports.fetchTasks = (0, https_1.onCall)({ region: "asia-east1" }, async (request) => {
    if (!request.auth) {
        throw new Error("需要登入");
    }
    const userId = request.auth.uid;
    try {
        const snapshot = await firebaseAdmin_1.db.collection("tasks")
            .doc(userId)
            .collection("userTasks")
            .orderBy("createdAt", "desc")
            .get();
        const tasks = [];
        for (const doc of snapshot.docs) {
            // 獲取任務的實例
            const instancesSnapshot = await doc.ref.collection("instances").get();
            const instances = instancesSnapshot.docs.map((instanceDoc) => (Object.assign({ id: instanceDoc.id }, instanceDoc.data())));
            tasks.push(Object.assign(Object.assign({ id: doc.id }, doc.data()), { instances }));
        }
        return { success: true, tasks };
    }
    catch (error) {
        console.error("獲取任務失敗:", error);
        throw new Error("獲取任務失敗");
    }
});
exports.deleteTask = (0, https_1.onCall)({ region: "asia-east1" }, async (request) => {
    if (!request.auth) {
        throw new Error("需要登入");
    }
    const userId = request.auth.uid;
    const taskId = request.data.taskId;
    if (!taskId) {
        throw new Error("無效的任務ID");
    }
    try {
        const batch = firebaseAdmin_1.db.batch();
        const taskRef = firebaseAdmin_1.db.collection("tasks")
            .doc(userId)
            .collection("userTasks")
            .doc(taskId);
        // 刪除所有實例
        const instancesSnapshot = await taskRef.collection("instances").get();
        instancesSnapshot.docs.forEach((doc) => {
            batch.delete(doc.ref);
        });
        // 刪除主任務
        batch.delete(taskRef);
        await batch.commit();
        return { success: true };
    }
    catch (error) {
        console.error("刪除任務失敗:", error);
        throw new Error("刪除任務失敗");
    }
});
exports.updateTaskInstance = (0, https_1.onCall)({ region: "asia-east1" }, async (request) => {
    if (!request.auth) {
        throw new Error("需要登入");
    }
    const userId = request.auth.uid;
    const { taskId, instanceId, isCompleted } = request.data;
    if (!taskId || !instanceId) {
        throw new Error("無效的任務或實例ID");
    }
    try {
        const instanceRef = firebaseAdmin_1.db.collection("tasks")
            .doc(userId)
            .collection("userTasks")
            .doc(taskId)
            .collection("instances")
            .doc(instanceId);
        await instanceRef.update({
            isCompleted,
            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        });
        return { success: true };
    }
    catch (error) {
        console.error("更新任務實例失敗:", error);
        throw new Error("更新任務實例失敗");
    }
});
// 使用者相關功能
exports.updateUserProfile = (0, https_1.onCall)({ region: "asia-east1" }, async (request) => {
    if (!request.auth) {
        throw new Error("需要登入");
    }
    const userId = request.auth.uid;
    const profileData = request.data.profile;
    try {
        await firebaseAdmin_1.db.collection("users").doc(userId).set(profileData, { merge: true });
        return { success: true };
    }
    catch (error) {
        console.error("更新個人資料失敗:", error);
        throw new Error("更新個人資料失敗");
    }
});
// ChatGPT API 功能
exports.callChatGPT = (0, https_1.onCall)({ region: "asia-east1" }, async (request) => {
    if (!request.auth) {
        throw new Error("需要登入");
    }
    const { messages } = request.data;
    try {
        const response = await (0, node_fetch_1.default)("https://api.openai.com/v1/chat/completions", {
            method: "POST",
            headers: {
                "Content-Type": "application/json",
                "Authorization": `Bearer ${process.env.OPENAI_API_KEY}`,
            },
            body: JSON.stringify({
                model: "gpt-3.5-turbo",
                messages,
            }),
        });
        const result = await response.json();
        // 更新使用者的 token 使用量
        if (result.usage) {
            await updateTokenUsageInternal(request.auth.uid, result.usage.total_tokens, result.usage.prompt_tokens, result.usage.completion_tokens, "gpt-3.5-turbo");
        }
        return result;
    }
    catch (error) {
        console.error("ChatGPT API 呼叫失敗:", error);
        throw new Error("ChatGPT API 呼叫失敗");
    }
});
// Token 使用量相關功能
async function updateTokenUsageInternal(userId, tokenCount, promptTokens, completionTokens, model) {
    try {
        const userTokensRef = firebaseAdmin_1.db.collection("userStatistics").doc(userId);
        const modelKey = model ? model.replace(".", "-") : "default";
        const updateData = {
            totalTokens: admin.firestore.FieldValue.increment(tokenCount),
            lastUpdated: admin.firestore.FieldValue.serverTimestamp(),
            [`modelUsage.${modelKey}.total`]: admin.firestore.FieldValue.increment(tokenCount),
        };
        if (promptTokens) {
            updateData[`modelUsage.${modelKey}.prompt`] = admin.firestore.FieldValue.increment(promptTokens);
        }
        if (completionTokens) {
            updateData[`modelUsage.${modelKey}.completion`] = admin.firestore.FieldValue.increment(completionTokens);
        }
        await userTokensRef.set(updateData, { merge: true });
    }
    catch (error) {
        console.error("更新 Token 使用量失敗:", error);
    }
}
exports.updateTokenUsage = (0, https_1.onCall)({ region: "asia-east1" }, async (request) => {
    if (!request.auth) {
        throw new Error("需要登入");
    }
    const userId = request.auth.uid;
    const { tokenCount, promptTokens, completionTokens, model } = request.data;
    if (!tokenCount || !model) {
        throw new Error("無效的 Token 使用量資料");
    }
    try {
        await updateTokenUsageInternal(userId, tokenCount, promptTokens, completionTokens, model);
        return { success: true };
    }
    catch (error) {
        console.error("更新 Token 使用量失敗:", error);
        throw new Error("更新 Token 使用量失敗");
    }
});
exports.fetchTokenUsage = (0, https_1.onCall)({ region: "asia-east1" }, async (request) => {
    if (!request.auth) {
        throw new Error("需要登入");
    }
    const userId = request.auth.uid;
    try {
        const doc = await firebaseAdmin_1.db.collection("userStatistics")
            .doc(userId)
            .get();
        if (!doc.exists) {
            return {
                success: true,
                tokenUsage: {
                    totalTokens: 0,
                    modelUsage: {},
                },
            };
        }
        return {
            success: true,
            tokenUsage: doc.data(),
        };
    }
    catch (error) {
        console.error("獲取 Token 使用量失敗:", error);
        throw new Error("獲取 Token 使用量失敗");
    }
});
// 統計相關功能
// 診斷版本的 fetchStatistics
exports.fetchStatistics = (0, https_1.onCall)({
    region: "asia-east1",
    timeoutSeconds: 60,
    memory: "256MiB",
}, async (request) => {
    try {
        console.log("[fetchStatistics] 開始執行");
        // 驗證使用者身份
        if (!request.auth) {
            console.log("[fetchStatistics] 錯誤: 使用者未登入");
            throw new https_1.HttpsError("unauthenticated", "使用者未登入");
        }
        const userId = request.auth.uid;
        console.log(`[fetchStatistics] 用戶ID: ${userId}`);
        // 先嘗試最簡單的查詢（不使用 orderBy）
        console.log("[fetchStatistics] 開始查詢統計資料...");
        const statisticsSnapshot = await admin
            .firestore()
            .collection("statistics")
            .where("userId", "==", userId)
            .get();
        console.log(`[fetchStatistics] 查詢完成，找到 ${statisticsSnapshot.size} 條記錄`);
        const statistics = [];
        statisticsSnapshot.forEach((doc) => {
            try {
                const data = doc.data();
                console.log(`[fetchStatistics] 處理文檔 ${doc.id}, 字段: ${Object.keys(data).join(", ")}`);
                statistics.push(Object.assign({ id: doc.id }, data));
            }
            catch (docError) {
                console.error(`[fetchStatistics] 處理文檔 ${doc.id} 時出錯:`, docError);
            }
        });
        console.log(`[fetchStatistics] 成功處理 ${statistics.length} 條統計資料`);
        return {
            success: true,
            statistics: statistics,
        };
    }
    catch (error) {
        // 使用 console.error 而不是 logger.error
        console.error("[fetchStatistics] 捕獲錯誤:", error);
        if (error instanceof https_1.HttpsError) {
            throw error;
        }
        // 簡化錯誤處理
        const errorMessage = error instanceof Error ? error.message : String(error);
        console.error("[fetchStatistics] 錯誤消息:", errorMessage);
        throw new https_1.HttpsError("internal", `獲取統計資料失敗: ${errorMessage}`);
    }
});
exports.updateStatistic = (0, https_1.onCall)({ region: "asia-east1" }, async (request) => {
    if (!request.auth) {
        throw new Error("需要登入");
    }
    const userId = request.auth.uid;
    const statistic = request.data.statistic;
    if (!statistic) {
        throw new Error("無效的統計資料");
    }
    try {
        const statRef = firebaseAdmin_1.db.collection("userStatistics")
            .doc(userId)
            .collection("statistics")
            .doc(statistic.id || firebaseAdmin_1.db.collection("userStatistics").doc().id);
        await statRef.set(Object.assign(Object.assign({}, statistic), { userId, updatedAt: admin.firestore.FieldValue.serverTimestamp() }), { merge: true });
        return { success: true, statisticId: statRef.id };
    }
    catch (error) {
        console.error("更新統計資料失敗:", error);
        throw new Error("更新統計資料失敗");
    }
});
exports.batchUpdateStatistics = (0, https_1.onCall)({ region: "asia-east1" }, async (request) => {
    if (!request.auth) {
        throw new Error("需要登入");
    }
    const userId = request.auth.uid;
    const statistics = request.data.statistics;
    if (!Array.isArray(statistics)) {
        throw new Error("無效的統計資料");
    }
    try {
        const batch = firebaseAdmin_1.db.batch();
        const results = [];
        for (const stat of statistics) {
            const statRef = firebaseAdmin_1.db.collection("userStatistics")
                .doc(userId)
                .collection("statistics")
                .doc(stat.id || firebaseAdmin_1.db.collection("userStatistics").doc().id);
            batch.set(statRef, Object.assign(Object.assign({}, stat), { userId, updatedAt: admin.firestore.FieldValue.serverTimestamp() }), { merge: true });
            results.push({
                statisticId: statRef.id,
                originalStat: stat,
            });
        }
        await batch.commit();
        return { success: true, results };
    }
    catch (error) {
        console.error("批次更新統計資料失敗:", error);
        throw new Error("批次更新統計資料失敗");
    }
});
// 學習設定相關功能
exports.updateStudySettings = (0, https_1.onCall)({ region: "asia-east1" }, async (request) => {
    if (!request.auth) {
        throw new Error("需要登入");
    }
    const userId = request.auth.uid;
    const settings = request.data.settings;
    if (!settings) {
        throw new Error("無效的設定資料");
    }
    try {
        await firebaseAdmin_1.db.collection("studySettings")
            .doc(userId)
            .set(Object.assign(Object.assign({}, settings), { userId, updatedAt: admin.firestore.FieldValue.serverTimestamp() }), { merge: true });
        return { success: true };
    }
    catch (error) {
        console.error("更新學習設定失敗:", error);
        throw new Error("更新學習設定失敗");
    }
});
exports.fetchStudySettings = (0, https_1.onCall)({ region: "asia-east1" }, async (request) => {
    if (!request.auth) {
        throw new Error("需要登入");
    }
    const userId = request.auth.uid;
    try {
        const doc = await firebaseAdmin_1.db.collection("studySettings")
            .doc(userId)
            .get();
        if (!doc.exists) {
            return { success: true, settings: null };
        }
        return {
            success: true,
            settings: Object.assign({ id: doc.id }, doc.data()),
        };
    }
    catch (error) {
        console.error("獲取學習設定失敗:", error);
        throw new Error("獲取學習設定失敗");
    }
});
// ============================================================================
// 新增的 Tasks API 函數
// ============================================================================
// 獲取單一任務
exports.getTask = (0, https_1.onCall)({ region: "asia-east1" }, async (request) => {
    if (!request.auth) {
        throw errors_1.Errors.Unauthenticated();
    }
    const userId = request.auth.uid;
    const { taskId } = request.data;
    if (!taskId) {
        throw errors_1.Errors.InvalidArgument("缺少任務 ID");
    }
    logger_1.Logger.trace("getTask", userId, "開始獲取任務", { taskId });
    try {
        const taskDoc = await firebaseAdmin_1.db.collection("tasks")
            .doc(userId)
            .collection("userTasks")
            .doc(taskId)
            .get();
        if (!taskDoc.exists) {
            throw errors_1.Errors.NotFound("任務");
        }
        // 獲取任務實例
        const instancesSnapshot = await taskDoc.ref
            .collection("instances")
            .get();
        const instances = instancesSnapshot.docs.map((doc) => (Object.assign({ id: doc.id }, doc.data())));
        logger_1.Logger.trace("getTask", userId, "任務獲取成功", { taskId });
        return {
            success: true,
            task: Object.assign(Object.assign({ id: taskDoc.id }, taskDoc.data()), { instances }),
        };
    }
    catch (error) {
        if (error instanceof errors_1.Errors.constructor) {
            throw error;
        }
        logger_1.Logger.error("getTask", error, { userId, taskId });
        throw errors_1.Errors.Internal("獲取任務失敗", error);
    }
});
// 更新任務
exports.updateTask = (0, https_1.onCall)({ region: "asia-east1" }, async (request) => {
    var _a;
    if (!request.auth) {
        throw errors_1.Errors.Unauthenticated();
    }
    const userId = request.auth.uid;
    const { taskId, updates } = request.data;
    if (!taskId) {
        throw errors_1.Errors.InvalidArgument("缺少任務 ID");
    }
    if (!updates) {
        throw errors_1.Errors.InvalidArgument("缺少更新資料");
    }
    logger_1.Logger.trace("updateTask", userId, "開始更新任務", { taskId });
    try {
        const batch = firebaseAdmin_1.db.batch();
        const taskRef = firebaseAdmin_1.db.collection("tasks")
            .doc(userId)
            .collection("userTasks")
            .doc(taskId);
        // 檢查任務是否存在
        const taskDoc = await taskRef.get();
        if (!taskDoc.exists) {
            throw errors_1.Errors.NotFound("任務");
        }
        // 準備更新的任務資料（用於檢查）
        const taskForCheck = {
            startDate: updates.startDate instanceof admin.firestore.Timestamp ?
                updates.startDate.toDate() :
                updates.startDate ? new Date(updates.startDate) : null,
            endDate: updates.endDate instanceof admin.firestore.Timestamp ?
                updates.endDate.toDate() :
                updates.endDate ? new Date(updates.endDate) : null,
            repeatType: updates.repeatType,
            repeatEndDate: updates.repeatEndDate instanceof admin.firestore.Timestamp ?
                updates.repeatEndDate.toDate() :
                updates.repeatEndDate ? new Date(updates.repeatEndDate) : null,
        };
        // 檢查是否需要重新生成實例
        const needsRegenerate = await needsRegenerateInstances(taskRef, taskForCheck);
        if (needsRegenerate && ((_a = updates.repeatType) === null || _a === void 0 ? void 0 : _a.type) && updates.repeatType.type !== "none") {
            logger_1.Logger.trace("updateTask", userId, "需要重新生成實例", { taskId });
            // 獲取所有現有的實例
            const instancesSnapshot = await taskRef.collection("instances").get();
            const completedInstanceDates = [];
            // 保存已完成實例的日期，刪除未完成的實例
            for (const instanceDoc of instancesSnapshot.docs) {
                const data = instanceDoc.data();
                const isCompleted = data.isCompleted || false;
                if (isCompleted) {
                    if (data.date) {
                        completedInstanceDates.push(data.date.toDate());
                    }
                }
                else {
                    // 刪除未完成的實例
                    batch.delete(instanceDoc.ref);
                }
            }
            // 生成新的實例
            const occurrences = calculateNextOccurrences(taskForCheck, 365);
            logger_1.Logger.trace("updateTask", userId, "生成新實例", {
                taskId,
                instanceCount: occurrences.length,
                completedCount: completedInstanceDates.length,
            });
            for (const date of occurrences) {
                // 檢查這個日期是否已經有完成的實例
                const isDateCompleted = completedInstanceDates.some((completedDate) => {
                    return completedDate.toDateString() === date.toDateString();
                });
                // 只為未完成的日期生成新實例
                if (!isDateCompleted) {
                    const instanceRef = taskRef.collection("instances").doc();
                    batch.set(instanceRef, {
                        date: admin.firestore.Timestamp.fromDate(date),
                        isCompleted: false,
                        parentTaskId: taskId,
                        createdAt: admin.firestore.FieldValue.serverTimestamp(),
                    });
                }
            }
        }
        // 更新任務本身
        batch.update(taskRef, Object.assign(Object.assign({}, updates), { updatedAt: admin.firestore.FieldValue.serverTimestamp() }));
        await batch.commit();
        logger_1.Logger.trace("updateTask", userId, "任務更新成功", { taskId });
        return { success: true };
    }
    catch (error) {
        if (error instanceof errors_1.Errors.constructor) {
            throw error;
        }
        logger_1.Logger.error("updateTask", error, { userId, taskId });
        throw errors_1.Errors.Internal("更新任務失敗", error);
    }
});
// 切換任務完成狀態
exports.toggleTaskCompletion = (0, https_1.onCall)({ region: "asia-east1" }, async (request) => {
    if (!request.auth) {
        throw errors_1.Errors.Unauthenticated();
    }
    const userId = request.auth.uid;
    const { taskId, instanceId, isCompleted } = request.data;
    if (!taskId) {
        throw errors_1.Errors.InvalidArgument("缺少任務 ID");
    }
    logger_1.Logger.trace("toggleTaskCompletion", userId, "開始切換完成狀態", {
        taskId,
        instanceId,
        isCompleted,
    });
    try {
        if (instanceId) {
            // 更新實例
            const instanceRef = firebaseAdmin_1.db.collection("tasks")
                .doc(userId)
                .collection("userTasks")
                .doc(taskId)
                .collection("instances")
                .doc(instanceId);
            const instanceDoc = await instanceRef.get();
            if (!instanceDoc.exists) {
                throw errors_1.Errors.NotFound("任務實例");
            }
            await instanceRef.update({
                isCompleted,
                updatedAt: admin.firestore.FieldValue.serverTimestamp(),
            });
        }
        else {
            // 更新主任務
            const taskRef = firebaseAdmin_1.db.collection("tasks")
                .doc(userId)
                .collection("userTasks")
                .doc(taskId);
            const taskDoc = await taskRef.get();
            if (!taskDoc.exists) {
                throw errors_1.Errors.NotFound("任務");
            }
            await taskRef.update({
                isCompleted,
                updatedAt: admin.firestore.FieldValue.serverTimestamp(),
            });
        }
        logger_1.Logger.trace("toggleTaskCompletion", userId, "完成狀態切換成功", {
            taskId,
            instanceId,
        });
        return { success: true };
    }
    catch (error) {
        if (error instanceof errors_1.Errors.constructor) {
            throw error;
        }
        logger_1.Logger.error("toggleTaskCompletion", error, {
            userId,
            taskId,
            instanceId,
        });
        throw errors_1.Errors.Internal("切換完成狀態失敗", error);
    }
});
// 建立任務實例
exports.createTaskInstance = (0, https_1.onCall)({ region: "asia-east1" }, async (request) => {
    if (!request.auth) {
        throw errors_1.Errors.Unauthenticated();
    }
    const userId = request.auth.uid;
    const { taskId, instance } = request.data;
    if (!taskId || !instance) {
        throw errors_1.Errors.InvalidArgument("缺少必要參數");
    }
    logger_1.Logger.trace("createTaskInstance", userId, "開始建立任務實例", { taskId });
    try {
        // 檢查任務是否存在
        const taskDoc = await firebaseAdmin_1.db.collection("tasks")
            .doc(userId)
            .collection("userTasks")
            .doc(taskId)
            .get();
        if (!taskDoc.exists) {
            throw errors_1.Errors.NotFound("任務");
        }
        const instanceRef = await firebaseAdmin_1.db.collection("tasks")
            .doc(userId)
            .collection("userTasks")
            .doc(taskId)
            .collection("instances")
            .add(Object.assign(Object.assign({}, instance), { createdAt: admin.firestore.FieldValue.serverTimestamp(), updatedAt: admin.firestore.FieldValue.serverTimestamp() }));
        logger_1.Logger.trace("createTaskInstance", userId, "任務實例建立成功", {
            taskId,
            instanceId: instanceRef.id,
        });
        return {
            success: true,
            instanceId: instanceRef.id,
        };
    }
    catch (error) {
        if (error instanceof errors_1.Errors.constructor) {
            throw error;
        }
        logger_1.Logger.error("createTaskInstance", error, { userId, taskId });
        throw errors_1.Errors.Internal("建立任務實例失敗", error);
    }
});
// 刪除任務實例
exports.deleteTaskInstance = (0, https_1.onCall)({ region: "asia-east1" }, async (request) => {
    if (!request.auth) {
        throw errors_1.Errors.Unauthenticated();
    }
    const userId = request.auth.uid;
    const { taskId, instanceId } = request.data;
    if (!taskId || !instanceId) {
        throw errors_1.Errors.InvalidArgument("缺少必要參數");
    }
    logger_1.Logger.trace("deleteTaskInstance", userId, "開始刪除任務實例", {
        taskId,
        instanceId,
    });
    try {
        const instanceRef = firebaseAdmin_1.db.collection("tasks")
            .doc(userId)
            .collection("userTasks")
            .doc(taskId)
            .collection("instances")
            .doc(instanceId);
        const instanceDoc = await instanceRef.get();
        if (!instanceDoc.exists) {
            throw errors_1.Errors.NotFound("任務實例");
        }
        await instanceRef.delete();
        logger_1.Logger.trace("deleteTaskInstance", userId, "任務實例刪除成功", {
            taskId,
            instanceId,
        });
        return { success: true };
    }
    catch (error) {
        if (error instanceof errors_1.Errors.constructor) {
            throw error;
        }
        logger_1.Logger.error("deleteTaskInstance", error, {
            userId,
            taskId,
            instanceId,
        });
        throw errors_1.Errors.Internal("刪除任務實例失敗", error);
    }
});
// ============================================================================
// 新增的 User API 函數
// ============================================================================
// 獲取使用者資料
exports.getUserProfile = (0, https_1.onCall)({ region: "asia-east1" }, async (request) => {
    if (!request.auth) {
        throw errors_1.Errors.Unauthenticated();
    }
    const userId = request.auth.uid;
    logger_1.Logger.trace("getUserProfile", userId, "開始獲取使用者資料");
    try {
        const doc = await firebaseAdmin_1.db.collection("users")
            .doc(userId)
            .get();
        if (!doc.exists) {
            // 建立預設 profile
            const defaultProfile = {
                id: userId,
                email: request.auth.token.email || "",
                username: "",
                isVIP: false,
                lastLoginAt: admin.firestore.FieldValue.serverTimestamp(),
            };
            await firebaseAdmin_1.db.collection("users").doc(userId).set(defaultProfile);
            logger_1.Logger.trace("getUserProfile", userId, "建立預設 profile");
            return {
                success: true,
                profile: defaultProfile,
            };
        }
        logger_1.Logger.trace("getUserProfile", userId, "使用者資料獲取成功");
        return {
            success: true,
            profile: Object.assign({ id: doc.id }, doc.data()),
        };
    }
    catch (error) {
        logger_1.Logger.error("getUserProfile", error, { userId });
        throw errors_1.Errors.Internal("獲取使用者資料失敗", error);
    }
});
// 獲取應用設定
exports.getAppSettings = (0, https_1.onCall)({ region: "asia-east1" }, async (request) => {
    if (!request.auth) {
        throw errors_1.Errors.Unauthenticated();
    }
    const userId = request.auth.uid;
    logger_1.Logger.trace("getAppSettings", userId, "開始獲取應用設定");
    try {
        const doc = await firebaseAdmin_1.db.collection("settings")
            .doc(userId)
            .get();
        if (!doc.exists) {
            logger_1.Logger.trace("getAppSettings", userId, "返回預設設定");
            return {
                success: true,
                settings: {
                    notificationsEnabled: true,
                },
            };
        }
        logger_1.Logger.trace("getAppSettings", userId, "應用設定獲取成功");
        return {
            success: true,
            settings: Object.assign({ id: doc.id }, doc.data()),
        };
    }
    catch (error) {
        logger_1.Logger.error("getAppSettings", error, { userId });
        throw errors_1.Errors.Internal("獲取應用設定失敗", error);
    }
});
// 更新應用設定
exports.updateAppSettings = (0, https_1.onCall)({ region: "asia-east1" }, async (request) => {
    if (!request.auth) {
        throw errors_1.Errors.Unauthenticated();
    }
    const userId = request.auth.uid;
    const settings = request.data.settings;
    if (!settings) {
        throw errors_1.Errors.InvalidArgument("無效的設定資料");
    }
    logger_1.Logger.trace("updateAppSettings", userId, "開始更新應用設定");
    try {
        await firebaseAdmin_1.db.collection("settings")
            .doc(userId)
            .set(Object.assign(Object.assign({}, settings), { lastModified: admin.firestore.FieldValue.serverTimestamp() }), { merge: true });
        logger_1.Logger.trace("updateAppSettings", userId, "應用設定更新成功");
        return { success: true };
    }
    catch (error) {
        logger_1.Logger.error("updateAppSettings", error, { userId });
        throw errors_1.Errors.Internal("更新應用設定失敗", error);
    }
});
// ============================================================================
// 新增的 Statistics API 函數
// ============================================================================
// 更新類別統計
exports.updateCategoryStats = (0, https_1.onCall)({ region: "asia-east1" }, async (request) => {
    if (!request.auth) {
        throw errors_1.Errors.Unauthenticated();
    }
    const userId = request.auth.uid;
    const { category, updates } = request.data;
    if (!category || !updates) {
        throw errors_1.Errors.InvalidArgument("缺少必要參數");
    }
    logger_1.Logger.trace("updateCategoryStats", userId, "開始更新類別統計", { category });
    try {
        // 查找該類別的統計資料
        const statsSnapshot = await firebaseAdmin_1.db.collection("userStatistics")
            .doc(userId)
            .collection("statistics")
            .where("category", "==", category)
            .limit(1)
            .get();
        let statRef;
        if (statsSnapshot.empty) {
            // 建立新的統計資料
            statRef = firebaseAdmin_1.db.collection("userStatistics")
                .doc(userId)
                .collection("statistics")
                .doc();
            await statRef.set({
                userId,
                category,
                progress: updates.progress || 0,
                taskcount: updates.taskCount || 0,
                taskcompletecount: updates.taskCompleteCount || 0,
                totalFocusTime: updates.focusTime || 0,
                date: admin.firestore.FieldValue.serverTimestamp(),
                updatedAt: admin.firestore.FieldValue.serverTimestamp(),
            });
            logger_1.Logger.trace("updateCategoryStats", userId, "建立新類別統計", { category });
        }
        else {
            // 更新現有統計資料
            statRef = statsSnapshot.docs[0].ref;
            const updateData = {
                updatedAt: admin.firestore.FieldValue.serverTimestamp(),
            };
            if (updates.progress !== undefined) {
                updateData.progress = updates.progress;
            }
            if (updates.focusTime !== undefined) {
                updateData.totalFocusTime = admin.firestore.FieldValue.increment(updates.focusTime);
            }
            if (updates.taskCount !== undefined) {
                updateData.taskcount = admin.firestore.FieldValue.increment(updates.taskCount);
            }
            if (updates.taskCompleteCount !== undefined) {
                updateData.taskcompletecount = admin.firestore.FieldValue.increment(updates.taskCompleteCount);
            }
            await statRef.update(updateData);
            logger_1.Logger.trace("updateCategoryStats", userId, "類別統計更新成功", { category });
        }
        return { success: true };
    }
    catch (error) {
        logger_1.Logger.error("updateCategoryStats", error, { userId, category });
        throw errors_1.Errors.Internal("更新類別統計失敗", error);
    }
});
// 刪除統計資料
exports.deleteStatistic = (0, https_1.onCall)({ region: "asia-east1" }, async (request) => {
    if (!request.auth) {
        throw errors_1.Errors.Unauthenticated();
    }
    const userId = request.auth.uid;
    const { statisticId } = request.data;
    if (!statisticId) {
        throw errors_1.Errors.InvalidArgument("缺少統計資料 ID");
    }
    logger_1.Logger.trace("deleteStatistic", userId, "開始刪除統計資料", { statisticId });
    try {
        const statRef = firebaseAdmin_1.db.collection("userStatistics")
            .doc(userId)
            .collection("statistics")
            .doc(statisticId);
        const statDoc = await statRef.get();
        if (!statDoc.exists) {
            throw errors_1.Errors.NotFound("統計資料");
        }
        await statRef.delete();
        logger_1.Logger.trace("deleteStatistic", userId, "統計資料刪除成功", { statisticId });
        return { success: true };
    }
    catch (error) {
        if (error instanceof errors_1.Errors.constructor) {
            throw error;
        }
        logger_1.Logger.error("deleteStatistic", error, { userId, statisticId });
        throw errors_1.Errors.Internal("刪除統計資料失敗", error);
    }
});
//# sourceMappingURL=index.js.map