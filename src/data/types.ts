export interface VocabCard {
  id: string;
  german: string;
  pronunciation: string;
  japanese: string;
  example?: {
    german: string;
    japanese: string;
  };
}

export interface QuizQuestion {
  id: string;
  german: string;
  correct: string;
  options: string[];
}

export interface ConversationLine {
  speaker: 'A' | 'B';
  speakerName: string;
  german: string;
  japanese: string;
}

export interface ConversationScene {
  situation: string;
  lines: ConversationLine[];
  tip: string;
}

export interface Lesson {
  id: string;
  title: string;
  subtitle: string;
  vocab: VocabCard[];
  quiz: QuizQuestion[];
  conversation: ConversationScene;
  xpReward: number;
}

export interface Unit {
  id: string;
  number: number;
  title: string;
  titleJapanese: string;
  icon: string;
  color: string;
  lessons: Lesson[];
}

export interface ProgressData {
  completedLessons: string[];
  totalXP: number;
  streak: number;
  lastStudyDate: string | null;
}
