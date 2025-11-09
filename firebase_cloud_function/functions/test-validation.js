// 測試 Zod 驗證功能
const { TaskSchema, validateData } = require('./lib/utils/validation');

console.log('🧪 開始測試 Zod 驗證功能...\n');

// 測試 1: 有效的任務資料
console.log('測試 1: 有效的任務資料');
const validTask = {
  title: "讀書",
  description: "複習數學",
  category: "學習",
  isCompleted: false,
  startDate: new Date(),
};

const result1 = validateData(TaskSchema, validTask);
console.log('結果:', result1.success ? '✅ 通過' : '❌ 失敗');
if (!result1.success) {
  console.log('錯誤:', result1.errors);
}
console.log('');

// 測試 2: 空標題（應該失敗）
console.log('測試 2: 空標題（應該失敗）');
const invalidTask1 = {
  title: "",
  isCompleted: false,
  startDate: new Date(),
};

const result2 = validateData(TaskSchema, invalidTask1);
console.log('結果:', result2.success ? '❌ 不應該通過' : '✅ 正確失敗');
if (!result2.success) {
  console.log('錯誤訊息:', result2.errors);
}
console.log('');

// 測試 3: 標題過長（應該失敗）
console.log('測試 3: 標題過長（應該失敗）');
const invalidTask2 = {
  title: "A".repeat(201),
  isCompleted: false,
  startDate: new Date(),
};

const result3 = validateData(TaskSchema, invalidTask2);
console.log('結果:', result3.success ? '❌ 不應該通過' : '✅ 正確失敗');
if (!result3.success) {
  console.log('錯誤訊息:', result3.errors);
}
console.log('');

// 測試 4: 缺少必要欄位（應該失敗）
console.log('測試 4: 缺少必要欄位（應該失敗）');
const invalidTask3 = {
  title: "測試",
  // 缺少 isCompleted 和 startDate
};

const result4 = validateData(TaskSchema, invalidTask3);
console.log('結果:', result4.success ? '❌ 不應該通過' : '✅ 正確失敗');
if (!result4.success) {
  console.log('錯誤訊息:', result4.errors);
}
console.log('');

// 總結
console.log('='.repeat(50));
console.log('測試總結:');
console.log('✅ 測試 1 (有效資料):', result1.success ? '通過' : '失敗');
console.log('✅ 測試 2 (空標題):', !result2.success ? '通過' : '失敗');
console.log('✅ 測試 3 (標題過長):', !result3.success ? '通過' : '失敗');
console.log('✅ 測試 4 (缺少欄位):', !result4.success ? '通過' : '失敗');

const allPassed = result1.success && !result2.success && !result3.success && !result4.success;
console.log('\n' + '='.repeat(50));
console.log(allPassed ? '🎉 所有測試通過！Zod 驗證正常運作！' : '⚠️ 部分測試失敗');
console.log('='.repeat(50));
