import React, { useMemo, useState } from 'react';
import { ScrollView, StyleSheet, Text, TouchableOpacity, View } from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';
import { RouteProp, useNavigation, useRoute } from '@react-navigation/native';
import type { NativeStackNavigationProp } from '@react-navigation/native-stack';
import FlashCard from '../components/FlashCard';
import QuizCard from '../components/QuizCard';
import { useDecks } from '../context/DeckContext';
import { useProgress } from '../context/ProgressContext';
import { buildQuizFromCards } from '../data/deckTypes';
import { colors, radius, spacing, typography } from '../theme';
import type { RootStackParamList } from '../navigation/AppNavigator';

type Nav = NativeStackNavigationProp<RootStackParamList>;
type Route = RouteProp<RootStackParamList, 'DeckStudy'>;

type Phase = 'intro' | 'flashcard' | 'quiz' | 'done';

const DECK_COLOR = '#0EA5E9';
const XP_PER_CORRECT = 8;

export default function DeckStudyScreen() {
  const navigation = useNavigation<Nav>();
  const { deckId } = useRoute<Route>().params;
  const { getDeck } = useDecks();
  const { addXP } = useProgress();

  const deck = getDeck(deckId);

  const [phase, setPhase] = useState<Phase>('intro');
  const [cardIndex, setCardIndex] = useState(0);
  const [quizIndex, setQuizIndex] = useState(0);
  const [correctCount, setCorrectCount] = useState(0);

  // クイズは開始時に1回だけ作る（毎描画で問題が入れ替わらないように）
  const quiz = useMemo(() => (deck ? buildQuizFromCards(deck.cards) : []), [deck?.id]);

  if (!deck) {
    return (
      <SafeAreaView style={styles.safe}>
        <View style={styles.missing}>
          <Text style={styles.missingText}>単語帳が見つかりませんでした</Text>
          <TouchableOpacity style={styles.primaryBtn} onPress={() => navigation.goBack()}>
            <Text style={styles.primaryBtnText}>戻る</Text>
          </TouchableOpacity>
        </View>
      </SafeAreaView>
    );
  }

  const totalSteps = deck.cards.length + quiz.length;
  const doneSteps =
    phase === 'intro' ? 0 : phase === 'flashcard' ? cardIndex : deck.cards.length + quizIndex;
  const progressPercent = totalSteps > 0 ? (doneSteps / totalSteps) * 100 : 0;

  const handleNextCard = () => {
    if (cardIndex < deck.cards.length - 1) {
      setCardIndex(cardIndex + 1);
      return;
    }
    // 単語が1語しかない等でクイズを作れない場合は、そのまま完了へ
    if (quiz.length === 0) {
      finish(0);
      return;
    }
    setPhase('quiz');
  };

  const handleQuizAnswer = (correct: boolean) => {
    const nextCorrect = correct ? correctCount + 1 : correctCount;
    setCorrectCount(nextCorrect);

    if (quizIndex < quiz.length - 1) {
      setQuizIndex(quizIndex + 1);
      return;
    }
    finish(nextCorrect);
  };

  const finish = (finalCorrect: number) => {
    setPhase('done');
    const earned = finalCorrect * XP_PER_CORRECT;
    if (earned > 0) addXP(earned);
  };

  const restart = () => {
    setCardIndex(0);
    setQuizIndex(0);
    setCorrectCount(0);
    setPhase('flashcard');
  };

  const earnedXP = correctCount * XP_PER_CORRECT;

  return (
    <SafeAreaView style={styles.safe}>
      <View style={styles.topBar}>
        <TouchableOpacity onPress={() => navigation.goBack()} style={styles.closeBtn}>
          <Text style={styles.closeBtnText}>✕</Text>
        </TouchableOpacity>
        <View style={styles.progressBarBg}>
          <View style={[styles.progressBarFill, { width: `${progressPercent}%` }]} />
        </View>
      </View>

      <View style={styles.body}>
        {phase === 'intro' && (
          <ScrollView contentContainerStyle={styles.introContent} showsVerticalScrollIndicator={false}>
            <Text style={styles.introIcon}>📗</Text>
            <Text style={styles.introDeckName}>{deck.name}</Text>
            <Text style={styles.introMeta}>{deck.cards.length}語</Text>

            <View style={styles.introSteps}>
              <View style={styles.introStep}>
                <Text style={styles.introStepIcon}>🃏</Text>
                <Text style={styles.introStepText}>
                  単語カード {deck.cards.length}枚をめくって確認
                </Text>
              </View>
              <View style={styles.introStep}>
                <Text style={styles.introStepIcon}>❓</Text>
                <Text style={styles.introStepText}>
                  {quiz.length > 0
                    ? `4択クイズ ${quiz.length}問（正解1問につき +${XP_PER_CORRECT}XP）`
                    : '単語が少ないためクイズはスキップされます'}
                </Text>
              </View>
            </View>

            <TouchableOpacity style={styles.startBtn} onPress={() => setPhase('flashcard')}>
              <Text style={styles.startBtnText}>学習開始 ▶</Text>
            </TouchableOpacity>
          </ScrollView>
        )}

        {phase === 'flashcard' && (
          <View style={styles.phase}>
            <View style={styles.phaseHeader}>
              <Text style={styles.phaseTitle}>単語カード</Text>
              <Text style={styles.phaseCounter}>
                {cardIndex + 1} / {deck.cards.length}
              </Text>
            </View>
            <FlashCard card={deck.cards[cardIndex]} unitColor={DECK_COLOR} />
            <TouchableOpacity style={styles.nextBtn} onPress={handleNextCard}>
              <Text style={styles.nextBtnText}>
                {cardIndex < deck.cards.length - 1
                  ? '次のカード →'
                  : quiz.length > 0
                    ? 'クイズへ進む →'
                    : '学習を終える →'}
              </Text>
            </TouchableOpacity>
          </View>
        )}

        {phase === 'quiz' && (
          <View style={styles.phase}>
            <View style={styles.phaseHeader}>
              <Text style={styles.phaseTitle}>クイズ</Text>
            </View>
            <QuizCard
              question={quiz[quizIndex]}
              onAnswer={handleQuizAnswer}
              questionNumber={quizIndex + 1}
              total={quiz.length}
            />
          </View>
        )}

        {phase === 'done' && (
          <ScrollView contentContainerStyle={styles.introContent} showsVerticalScrollIndicator={false}>
            <Text style={styles.introIcon}>🎉</Text>
            <Text style={styles.doneTitle}>学習おつかれさま！</Text>

            <View style={styles.resultRow}>
              <View style={styles.resultBox}>
                <Text style={styles.resultValue}>
                  {correctCount}/{quiz.length}
                </Text>
                <Text style={styles.resultLabel}>クイズ正解</Text>
              </View>
              <View style={styles.resultBox}>
                <Text style={styles.resultValue}>+{earnedXP}</Text>
                <Text style={styles.resultLabel}>獲得XP</Text>
              </View>
            </View>

            <TouchableOpacity style={styles.startBtn} onPress={restart}>
              <Text style={styles.startBtnText}>もう一度学習する</Text>
            </TouchableOpacity>
            <TouchableOpacity style={styles.secondaryBtn} onPress={() => navigation.goBack()}>
              <Text style={styles.secondaryBtnText}>単語帳一覧へ戻る</Text>
            </TouchableOpacity>
          </ScrollView>
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
  progressBarFill: { height: '100%', backgroundColor: DECK_COLOR, borderRadius: radius.full },

  body: { flex: 1, paddingHorizontal: spacing.lg, paddingBottom: spacing.md },

  introContent: { flexGrow: 1, alignItems: 'center', justifyContent: 'center', paddingVertical: spacing.lg },
  introIcon: { fontSize: 52, marginBottom: spacing.md },
  introDeckName: { ...typography.h2, color: colors.text.primary, textAlign: 'center' },
  introMeta: { ...typography.small, color: colors.text.secondary, marginBottom: spacing.xl },
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

  startBtn: {
    backgroundColor: DECK_COLOR,
    paddingHorizontal: spacing.xxl,
    paddingVertical: spacing.md,
    borderRadius: radius.full,
    alignSelf: 'stretch',
    alignItems: 'center',
  },
  startBtnText: { ...typography.bodyBold, color: colors.text.inverse },
  secondaryBtn: {
    marginTop: spacing.sm,
    paddingVertical: spacing.md,
    borderRadius: radius.full,
    alignSelf: 'stretch',
    alignItems: 'center',
    backgroundColor: colors.card,
    borderWidth: 1,
    borderColor: colors.border,
  },
  secondaryBtnText: { ...typography.bodyBold, color: colors.text.primary },

  phase: { flex: 1 },
  phaseHeader: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    marginBottom: spacing.md,
  },
  phaseTitle: { ...typography.h3, color: colors.text.primary },
  phaseCounter: { ...typography.small, color: colors.text.secondary },
  nextBtn: {
    marginTop: spacing.lg,
    paddingVertical: spacing.md,
    borderRadius: radius.full,
    alignItems: 'center',
    backgroundColor: DECK_COLOR,
  },
  nextBtnText: { ...typography.bodyBold, color: colors.text.inverse },

  doneTitle: { ...typography.h2, color: colors.text.primary, marginBottom: spacing.lg },
  resultRow: { flexDirection: 'row', gap: spacing.md, marginBottom: spacing.xl, alignSelf: 'stretch' },
  resultBox: {
    flex: 1,
    backgroundColor: colors.card,
    borderRadius: radius.lg,
    padding: spacing.md,
    alignItems: 'center',
  },
  resultValue: { ...typography.h2, color: colors.text.primary },
  resultLabel: { ...typography.caption, color: colors.text.secondary },

  missing: { flex: 1, alignItems: 'center', justifyContent: 'center', gap: spacing.lg, padding: spacing.lg },
  missingText: { ...typography.body, color: colors.text.secondary },
  primaryBtn: {
    backgroundColor: colors.primary,
    paddingHorizontal: spacing.xl,
    paddingVertical: spacing.md,
    borderRadius: radius.full,
  },
  primaryBtnText: { ...typography.bodyBold, color: colors.text.inverse },
});
