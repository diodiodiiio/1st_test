import React, { useEffect, useMemo, useState } from 'react';
import { StyleSheet, Text, TouchableOpacity, View } from 'react-native';
import * as Haptics from 'expo-haptics';
import { QuizQuestion } from '../data/types';
import { colors, radius, spacing, typography } from '../theme';
import { useSpeech } from '../hooks/useSpeech';

interface Props {
  question: QuizQuestion;
  onAnswer: (correct: boolean) => void;
  questionNumber: number;
  total: number;
}

function shuffle<T>(arr: T[]): T[] {
  const a = [...arr];
  for (let i = a.length - 1; i > 0; i--) {
    const j = Math.floor(Math.random() * (i + 1));
    [a[i], a[j]] = [a[j], a[i]];
  }
  return a;
}

export default function QuizCard({ question, onAnswer, questionNumber, total }: Props) {
  const [selected, setSelected] = useState<string | null>(null);
  const shuffledOptions = useMemo(() => shuffle(question.options), [question.id]);
  const { speak, isSpeaking } = useSpeech();

  useEffect(() => {
    setSelected(null);
    const timer = setTimeout(() => speak(question.german), 300);
    return () => clearTimeout(timer);
  }, [question.id]);

  const handleSelect = (option: string) => {
    if (selected) return;
    setSelected(option);
    const correct = option === question.correct;
    if (correct) {
      Haptics.notificationAsync(Haptics.NotificationFeedbackType.Success);
    } else {
      Haptics.notificationAsync(Haptics.NotificationFeedbackType.Error);
    }
    setTimeout(() => onAnswer(correct), 900);
  };

  const getOptionStyle = (option: string) => {
    if (!selected) return styles.option;
    if (option === question.correct) return [styles.option, styles.optionCorrect];
    if (option === selected) return [styles.option, styles.optionWrong];
    return [styles.option, styles.optionDimmed];
  };

  const getOptionTextStyle = (option: string) => {
    if (!selected) return styles.optionText;
    if (option === question.correct) return [styles.optionText, styles.optionTextCorrect];
    if (option === selected) return [styles.optionText, styles.optionTextWrong];
    return [styles.optionText, styles.optionTextDimmed];
  };

  return (
    <View style={styles.container}>
      <Text style={styles.counter}>{questionNumber} / {total}</Text>
      <View style={styles.questionBox}>
        <Text style={styles.questionLabel}>次のドイツ語の意味は？</Text>
        <Text style={styles.questionText}>{question.german}</Text>
        <TouchableOpacity
          style={[styles.speakBtn, isSpeaking && styles.speakBtnActive]}
          onPress={() => speak(question.german)}
          hitSlop={{ top: 10, bottom: 10, left: 10, right: 10 }}
        >
          <Text style={styles.speakIcon}>{isSpeaking ? '🔊' : '🔈'}</Text>
          <Text style={styles.speakLabel}>読み上げ</Text>
        </TouchableOpacity>
      </View>
      <View style={styles.options}>
        {shuffledOptions.map((option) => (
          <TouchableOpacity
            key={option}
            style={getOptionStyle(option)}
            onPress={() => handleSelect(option)}
            activeOpacity={0.8}
          >
            <Text style={getOptionTextStyle(option)}>{option}</Text>
            {selected && option === question.correct && (
              <Text style={styles.checkMark}>✓</Text>
            )}
            {selected && option === selected && option !== question.correct && (
              <Text style={styles.crossMark}>✗</Text>
            )}
          </TouchableOpacity>
        ))}
      </View>
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
  },
  counter: {
    ...typography.small,
    color: colors.text.secondary,
    textAlign: 'center',
    marginBottom: spacing.md,
  },
  questionBox: {
    backgroundColor: colors.card,
    borderRadius: radius.xl,
    padding: spacing.xl,
    alignItems: 'center',
    marginBottom: spacing.lg,
    shadowColor: '#000',
    shadowOffset: { width: 0, height: 2 },
    shadowOpacity: 0.08,
    shadowRadius: 8,
    elevation: 3,
    gap: spacing.sm,
  },
  questionLabel: {
    ...typography.small,
    color: colors.text.secondary,
  },
  questionText: {
    fontSize: 30,
    fontWeight: '700',
    color: colors.text.primary,
    textAlign: 'center',
  },
  speakBtn: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: spacing.xs,
    paddingHorizontal: spacing.md,
    paddingVertical: spacing.sm,
    backgroundColor: '#EFF6FF',
    borderRadius: radius.full,
  },
  speakBtnActive: {
    backgroundColor: '#BFDBFE',
  },
  speakIcon: {
    fontSize: 16,
  },
  speakLabel: {
    ...typography.smallBold,
    color: colors.primary,
  },
  options: {
    gap: spacing.sm,
  },
  option: {
    backgroundColor: colors.card,
    borderRadius: radius.lg,
    padding: spacing.md,
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
    borderWidth: 2,
    borderColor: colors.border,
    shadowColor: '#000',
    shadowOffset: { width: 0, height: 1 },
    shadowOpacity: 0.05,
    shadowRadius: 4,
    elevation: 2,
  },
  optionCorrect: {
    backgroundColor: colors.successLight,
    borderColor: colors.success,
  },
  optionWrong: {
    backgroundColor: '#FEE2E2',
    borderColor: colors.danger,
  },
  optionDimmed: {
    opacity: 0.4,
  },
  optionText: {
    ...typography.bodyBold,
    color: colors.text.primary,
    flex: 1,
  },
  optionTextCorrect: {
    color: '#15803D',
  },
  optionTextWrong: {
    color: colors.danger,
  },
  optionTextDimmed: {
    color: colors.text.muted,
  },
  checkMark: {
    fontSize: 20,
    color: colors.success,
    fontWeight: '700',
  },
  crossMark: {
    fontSize: 20,
    color: colors.danger,
    fontWeight: '700',
  },
});
