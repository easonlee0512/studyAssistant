import * as admin from "firebase-admin";

export interface TodoTask {
    id?: string;
    title: string;
    description?: string;
    userId: string;
    isCompleted: boolean;
    startDate: admin.firestore.Timestamp;
    endDate?: admin.firestore.Timestamp;
    createdAt?: admin.firestore.Timestamp;
    updatedAt?: admin.firestore.Timestamp;
    repeatType?: {
        type: "none" | "daily" | "weekly" | "monthly";
        endDate?: admin.firestore.Timestamp;
    };
}

export interface UserProfile {
    id: string;
    email: string;
    username: string;
    userGoal?: string;
    targetDate?: admin.firestore.Timestamp;
    learningStage?: string;
    isVIP: boolean;
    lastLoginAt: admin.firestore.Timestamp;
}

export interface LearningStatistic {
    id?: string;
    userId: string;
    category: string;
    progress: number;
    taskcount: number;
    taskcompletecount: number;
    totalFocusTime: number;
    date: admin.firestore.Timestamp;
    updatedAt: admin.firestore.Timestamp;
}

export interface StudySettings {
    id?: string;
    userId: string;
    updatedAt: admin.firestore.Timestamp;
    // 加入其他需要的設定欄位
}

export interface Statistic {
    id?: string;
    userId: string;
    date: admin.firestore.Timestamp;
    updatedAt: admin.firestore.Timestamp;
    // 加入其他需要的統計欄位
}
