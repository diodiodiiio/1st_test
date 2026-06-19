import React, { useState } from 'react';
import {
  StyleSheet,
  Text,
  TouchableOpacity,
  View,
} from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';
import { useNavigation, useRoute, RouteProp } from '@react-navigation/native';
import type { NativeStackNavigationProp } from '@react-navigation/native-stack';
import FlashCard from '../components/FlashCard';
import QuizCard from '../components/QuizCard';
import ConversationCard from '../components/ConversationCard';
import { getLessonById, getUnitById } from '../data/curriculum';
import { colors, radius, spacing, typography } from '../theme';
import type { RootStackParamList } from '../navigation/AppNavigator';

type Nav = NativeStackNavigationProp<RootStackParamList>;
type Route = RouteProp<RootStackParamList, 'Lesson'>;

type Phase = 'intro' | 'flashcard' | 'quiz' | 'conversation';

export default function LessonScreen() {
  const navigation = useNavigation<Nav>();
  const route = useRoute<Route>();
  const { lessonId, unitId } = route.params;

  const lesson = getLessonById(lessonId);
  const unit = getUnitById(unitId);

  const [phase, setPhase] = useState<Phase>('intro');
  const [cardIndex, setCardIndex] = useState(0);
  const [quizIndex, setQuizIndex] = useState(0);
  const [correctCount, setCorrectCount] = useState(0);

  if (!lesson || !unit) return null;

  const handleBack = () => navigation.goBack();

  const goToPhase = (next: Phase) => {
    setPhase(next);
    setCardIndex(0);
    setQuizIndex(0);
  };

  const handleNextCard = () => {
    if (cardIndex < lesson.vocab.length - 1) {
      setCardIndex(cardIndex + 1);
    } else {
      goToPhase('quiz');
    }
  };

  const handleQuizAnswer = (correct: boolean) => {
    if (correct) setCorrectCount((c) => c + 1);
    if (quizIndex < lesson.quiz.length - 1) {
      setQuizIndex(quizIndex + 1);
    } else {
      setPhase('conversation');
    }
  };

  const handleFinish = () => {
    navigation.replace('Result', {
      lessonId,
      unitId,
      xpEarned: lesson.xpReward,
      quizScore: correctCount,
      quizTotal: lesson.quiz.length,
    });
  };

  const phaseProgress = () => {
    if (phase === 'intro') return 0;
    if (phase === 'flashcard') return ((cardIndex + 1) / (lesson.vocab.length + lesson.quiz.length + 1)) * 100;
    if (phase === 'quiz') return ((lesson.vocab.length + quizIndex + 1) / (lesson.vocab.length + lesson.quiz.length + 1)) * 100;
    return 95;
  };

  const phaseLabels: Record<Phase, string> = {
    intro: '準備',
    flashcard: '単語カード',
    quiz: 'クイズ',
    conversation: '会話',
  };

  return (
    <SafeAreaView style={styles.safe}>
      <View style={styles.topBar}>
        <TouchableOpacity onPress={handleBack} style={styles.closeBtn}>
          <Text style={styles.closeBtnText}>✕</Text>
        </TouchableOpacity>
        <View style={styles.progressBarBg}>
          <View
            style={[
              styles.progressBarFill,
              { width: `${phaseProgress()}%`, backgroundColor: unit.color },
            ]}
          />
        </View>
      </View>

      <View style={styles.phasePills}>
        {(['flashcard', 'quiz', 'conversation'] as const).map((p) => (
          <View
            key={p}
            style={[
              styles.pill,
              phase === p ? [styles.pillActive, { backgroundColor: unit.color }] : null,
              (phase === 'quiz' && p === 'flashcard') ||
              (phase === 'conversation' && (p === 'flashcard' || p === 'quiz'))
                ? [styles.pillDone, { borderColor: unit.color }]
                : null,
            ]}
          >
            <Text
              style={[
                styles.pillText,
                phase === p ? styles.pillTextActive : null,
              ]}
            >
              {phaseLabels[p]}
            </Text>
          </View>
        ))}
      </View>

      <View style={styles.body}>
        {phase === 'intro' && (
          <View style={styles.introContainer}>
            <Text style={styles.introIcon}>{unit.icon}</Text>
            <Text style={styles.introUnitName}>{unit.titleJapanese}</Text>
            <Text style={styles.introLessonName}>{lesson.title}</Text>
            <Text style={styles.introSub}>{lesson.subtitle}</Text>
            <View style={styles.introSteps}>
              <View style={styles.introStep}>
                <Text style={styles.introStepIcon}>🃏</Text>
                <Text style={styles.introStepText}>単語カード {lesson.vocab.length}枚をタップして確認</Text>
              </View>
              <View style={styles.introStep}>
                <Text style={styles.introStepIcon}>❓</Text>
                <Text style={styles.introStepText}>4択クイズ {lesson.quiz.length}問で確認</Text>
              </View>
              <View style={styles.introStep}>
                <Text style={styles.introStepIcon}>💬</Text>
                <Text style={styles.introStepText}>実践的な会話シナリオを読む</Text>
              </View>
            </View>
            <TouchableOpacity
              style={[styles.startButton, { backgroundColor: unit.color }]}
              onPress={() => goToPhase('flashcard')}
            >
              <Text style={styles.startButtonText}>レッスン開始 ▶</Text>
            </TouchableOpacity>
          </View>
        )}

        {phase === 'flashcard' && (
          <View style={styles.phaseContainer}>
            <View style={styles.phaseHeader}>
              <Text style={styles.phaseTitle}>単語カード</Text>
              <Text style={styles.phaseCounter}>{cardIndex + 1} / {lesson.vocab.length}</Text>
            </View>
            <FlashCard card={lesson.vocab[cardIndex]} unitColor={unit.color} />
            <TouchableOpacity
              style={[styles.nextButton, { backgroundColor: unit.color }]}
              onPress={handleNextCard}
            >
              <Text style={styles.nextButtonText}>
                {cardIndex < lesson.vocab.length - 1 ? '次のカード →' : 'クイズへ進む →'}
              </Text>
            </TouchableOpacity>
          </View>
        )}

        {phase === 'quiz' && (
          <View style={styles.phaseContainer}>
            <View style={styles.phaseHeader}>
              <Text style={styles.phaseTitle}>クイズ</Text>
            </View>
            <QuizCard
              question={lesson.quiz[quizIndex]}
              onAnswer={handleQuizAnswer}
              questionNumber={quizIndex + 1}
              total={lesson.quiz.length}
            />
          </View>
        )}

        {phase === 'conversation' && (
          <View style={styles.phaseContainer}>
            <View style={styles.phaseHeader}>
              <Text style={styles.phaseTitle}>会話シナリオ</Text>
            </View>
            <ConversationCard scene={lesson.conversation} unitColor={unit.color} />
            <TouchableOpacity
              style={[styles.nextButton, { backgroundColor: unit.color }]}
              onPress={handleFinish}
            >
              <Text style={styles.nextButtonText}>レッスン完了 🎉</Text>
            </TouchableOpacity>
          </View>
        )}
      </View>
    </SafeAreaView>
  );
}

const styles = StyleSheet.create({
  safe: { flex: 1, backgroundColor: colors.background },
  topBar: {
    flexDirection: 'row',
    alignItems: 'center',
    paddingHorizontal: spacing.lg,
    paddingVertical: spacing.sm,
    gap: spacing.md,
  },
  closeBtn: {
    width: 36,
    height: 36,
    borderRadius: radius.full,
    backgroundColor: colors.card,
    alignItems: 'center',
    justifyContent: 'center',
    borderWidth: 1,
    borderColor: colors.border,
  },
  closeBtnText: { fontSize: 16, color: colors.text.secondary, fontWeight: '600' },
  progressBarBg: {
    flex: 1,
    height: 8,
    backgroundColor: colors.border,
    borderRadius: radius.full,
    overflow: 'hidden',
  },
  progressBarFill: {
    height: '100%',
    borderRadius: radius.full,
  },
  phasePills: {
    flexDirection: 'row',
    gap: spacing.sm,
    paddingHorizontal: spacing.lg,
    marginBottom: spacing.md,
  },
  pill: {
    paddingHorizontal: spacing.md,
    paddingVertical: spacing.xs,
    borderRadius: radius.full,
    backgroundColor: colors.border,
    borderWidth: 1.5,
    borderColor: 'transparent',
  },
  pillActive: { borderColor: 'transparent' },
  pillDone: { backgroundColor: 'transparent' },
  pillText: { ...typography.caption, color: colors.text.secondary },
  pillTextActive: { color: colors.text.inverse, fontWeight: '600' },
  body: { flex: 1, paddingHorizontal: spacing.lg, paddingBottom: spacing.md },
  introContainer: {
    flex: 1,
    alignItems: 'center',
    justifyContent: 'center',
  },
  introIcon: { fontSize: 56, marginBottom: spacing.md },
  introUnitName: { ...typography.small, color: colors.text.secondary, marginBottom: spacing.xs },
  introLessonName: { ...typography.h2, color: colors.text.primary, marginBottom: spacing.xs, textAlign: 'center' },
  introSub: { ...typography.small, color: colors.text.secondary, marginBottom: spacing.xl, fontStyle: 'italic' },
  introSteps: { width: '100%', gap: spacing.sm, marginBottom: spacing.xl },
  introStep: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: spacing.md,
    backgroundColor: colors.card,
    borderRadius: radius.lg,
    padding: spacing.md,
  },
  introStepIcon: { fontSize: 22 },
  introStepText: { ...typography.small, color: colors.text.primary, flex: 1 },
  startButton: {
    paddingHorizontal: spacing.xxl,
    paddingVertical: spacing.md,
    borderRadius: radius.full,
  },
  startButtonText: { ...typography.bodyBold, color: colors.text.inverse },
  phaseContainer: { flex: 1 },
  phaseHeader: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    marginBottom: spacing.md,
  },
  phaseTitle: { ...typography.h3, color: colors.text.primary },
  phaseCounter: { ...typography.small, color: colors.text.secondary },
  nextButton: {
    marginTop: spacing.lg,
    paddingVertical: spacing.md,
    borderRadius: radius.full,
    alignItems: 'center',
  },
  nextButtonText: { ...typography.bodyBold, color: colors.text.inverse },
});
