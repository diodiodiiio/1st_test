import React, { createContext, useContext, useEffect, useState } from 'react';
import AsyncStorage from '@react-native-async-storage/async-storage';
import { ProgressData } from '../data/types';

interface ProgressContextValue extends ProgressData {
  completeLesson: (lessonId: string, xpEarned: number) => Promise<void>;
  /** カリキュラム外の学習（My単語帳など）でXPとストリークだけ更新する */
  addXP: (xpEarned: number) => Promise<void>;
  isLessonCompleted: (lessonId: string) => boolean;
  getLevel: () => { level: number; title: string; nextXP: number };
}

const STORAGE_KEY = '@deutsch_lernen_progress';

const defaultProgress: ProgressData = {
  completedLessons: [],
  totalXP: 0,
  streak: 0,
  lastStudyDate: null,
};

const LEVELS = [
  { level: 1, title: 'Anfänger', minXP: 0, nextXP: 150 },
  { level: 2, title: 'Lernender', minXP: 150, nextXP: 400 },
  { level: 3, title: 'Fortgeschritten', minXP: 400, nextXP: 800 },
  { level: 4, title: 'Geübt', minXP: 800, nextXP: 1500 },
  { level: 5, title: 'Meister', minXP: 1500, nextXP: 1500 },
];

const ProgressContext = createContext<ProgressContextValue | null>(null);

export function ProgressProvider({ children }: { children: React.ReactNode }) {
  const [progress, setProgress] = useState<ProgressData>(defaultProgress);

  useEffect(() => {
    loadProgress();
  }, []);

  const loadProgress = async () => {
    try {
      const stored = await AsyncStorage.getItem(STORAGE_KEY);
      if (stored) {
        setProgress(JSON.parse(stored));
      }
    } catch (_) {}
  };

  const saveProgress = async (data: ProgressData) => {
    try {
      await AsyncStorage.setItem(STORAGE_KEY, JSON.stringify(data));
    } catch (_) {}
  };

  /** 今日学習したことを反映した streak / lastStudyDate を返す */
  const withTodaysStudy = (xpEarned: number) => {
    const today = new Date().toDateString();
    const yesterday = new Date(Date.now() - 86400000).toDateString();
    const lastDate = progress.lastStudyDate;

    let newStreak: number;
    if (lastDate === today) {
      newStreak = progress.streak;
    } else if (lastDate === yesterday) {
      newStreak = progress.streak + 1;
    } else {
      newStreak = 1;
    }

    return {
      totalXP: progress.totalXP + xpEarned,
      streak: newStreak,
      lastStudyDate: today,
    };
  };

  const completeLesson = async (lessonId: string, xpEarned: number) => {
    const newProgress: ProgressData = {
      ...withTodaysStudy(xpEarned),
      completedLessons: progress.completedLessons.includes(lessonId)
        ? progress.completedLessons
        : [...progress.completedLessons, lessonId],
    };

    setProgress(newProgress);
    await saveProgress(newProgress);
  };

  const addXP = async (xpEarned: number) => {
    const newProgress: ProgressData = {
      ...withTodaysStudy(xpEarned),
      completedLessons: progress.completedLessons,
    };

    setProgress(newProgress);
    await saveProgress(newProgress);
  };

  const isLessonCompleted = (lessonId: string) =>
    progress.completedLessons.includes(lessonId);

  const getLevel = () => {
    const xp = progress.totalXP;
    const currentLevel = LEVELS.slice().reverse().find((l) => xp >= l.minXP) ?? LEVELS[0];
    return {
      level: currentLevel.level,
      title: currentLevel.title,
      nextXP: currentLevel.nextXP,
    };
  };

  return (
    <ProgressContext.Provider
      value={{ ...progress, completeLesson, addXP, isLessonCompleted, getLevel }}
    >
      {children}
    </ProgressContext.Provider>
  );
}

export function useProgress() {
  const ctx = useContext(ProgressContext);
  if (!ctx) throw new Error('useProgress must be used within ProgressProvider');
  return ctx;
}
