import React from 'react';
import {
  ScrollView,
  StyleSheet,
  Text,
  TouchableOpacity,
  View,
} from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';
import { useNavigation } from '@react-navigation/native';
import type { NativeStackNavigationProp } from '@react-navigation/native-stack';
import { useProgress } from '../context/ProgressContext';
import { CURRICULUM, isUnitUnlocked } from '../data/curriculum';
import { colors, radius, spacing, typography } from '../theme';
import type { RootStackParamList } from '../navigation/AppNavigator';

type Nav = NativeStackNavigationProp<RootStackParamList>;

export default function HomeScreen() {
  const navigation = useNavigation<Nav>();
  const { totalXP, streak, completedLessons, getLevel } = useProgress();
  const { level, title, nextXP } = getLevel();
  const xpProgress = Math.min(totalXP / nextXP, 1);

  const nextLesson = CURRICULUM.flatMap((u) =>
    u.lessons.map((l) => ({ ...l, unit: u }))
  ).find(
    (l) =>
      !completedLessons.includes(l.id) &&
      isUnitUnlocked(l.unit.id, completedLessons)
  );

  const totalLessons = CURRICULUM.flatMap((u) => u.lessons).length;
  const completionPercent = Math.round((completedLessons.length / totalLessons) * 100);

  return (
    <SafeAreaView style={styles.safe}>
      <ScrollView style={styles.scroll} contentContainerStyle={styles.content} showsVerticalScrollIndicator={false}>
        <View style={styles.header}>
          <View>
            <Text style={styles.greeting}>Guten Tag! 👋</Text>
            <Text style={styles.subGreeting}>今日もドイツ語を練習しよう</Text>
          </View>
          <View style={styles.streakBadge}>
            <Text style={styles.streakFlame}>🔥</Text>
            <Text style={styles.streakCount}>{streak}</Text>
          </View>
        </View>

        <View style={styles.levelCard}>
          <View style={styles.levelRow}>
            <View style={styles.levelLeft}>
              <Text style={styles.levelLabel}>レベル {level}</Text>
              <Text style={styles.levelTitle}>{title}</Text>
            </View>
            <View style={styles.xpBadge}>
              <Text style={styles.xpText}>{totalXP} XP</Text>
            </View>
          </View>
          <View style={styles.progressBarBg}>
            <View style={[styles.progressBarFill, { width: `${xpProgress * 100}%` }]} />
          </View>
          <Text style={styles.progressLabel}>
            次のレベルまで: {Math.max(nextXP - totalXP, 0)} XP
          </Text>
        </View>

        <View style={styles.statsRow}>
          <View style={styles.statCard}>
            <Text style={styles.statEmoji}>📚</Text>
            <Text style={styles.statValue}>{completedLessons.length}</Text>
            <Text style={styles.statLabel}>完了レッスン</Text>
          </View>
          <View style={styles.statCard}>
            <Text style={styles.statEmoji}>🎯</Text>
            <Text style={styles.statValue}>{completionPercent}%</Text>
            <Text style={styles.statLabel}>全体進捗</Text>
          </View>
          <View style={styles.statCard}>
            <Text style={styles.statEmoji}>🔥</Text>
            <Text style={styles.statValue}>{streak}</Text>
            <Text style={styles.statLabel}>連続日数</Text>
          </View>
        </View>

        {nextLesson ? (
          <View style={styles.section}>
            <Text style={styles.sectionTitle}>次のレッスン</Text>
            <TouchableOpacity
              style={[styles.nextLessonCard, { borderLeftColor: nextLesson.unit.color }]}
              onPress={() =>
                navigation.navigate('Lesson', {
                  lessonId: nextLesson.id,
                  unitId: nextLesson.unit.id,
                })
              }
              activeOpacity={0.85}
            >
              <View style={styles.nextLessonLeft}>
                <Text style={styles.nextLessonIcon}>{nextLesson.unit.icon}</Text>
                <View>
                  <Text style={styles.nextLessonUnit}>{nextLesson.unit.titleJapanese}</Text>
                  <Text style={styles.nextLessonTitle}>{nextLesson.title}</Text>
                  <Text style={styles.nextLessonMeta}>
                    単語 {nextLesson.vocab.length}個 • クイズ {nextLesson.quiz.length}問 • +{nextLesson.xpReward}XP
                  </Text>
                </View>
              </View>
              <Text style={styles.startButton}>▶</Text>
            </TouchableOpacity>
          </View>
        ) : (
          <View style={styles.completedBanner}>
            <Text style={styles.completedEmoji}>🏆</Text>
            <Text style={styles.completedText}>全レッスン完了！Herzlichen Glückwunsch!</Text>
          </View>
        )}

        <View style={styles.section}>
          <Text style={styles.sectionTitle}>カリキュラム概要</Text>
          {CURRICULUM.map((unit) => {
            const unitLessons = unit.lessons;
            const completedCount = unitLessons.filter((l) =>
              completedLessons.includes(l.id)
            ).length;
            const unlocked = isUnitUnlocked(unit.id, completedLessons);
            const pct = unitLessons.length > 0 ? completedCount / unitLessons.length : 0;

            return (
              <View key={unit.id} style={[styles.unitRow, !unlocked && styles.unitRowLocked]}>
                <Text style={styles.unitRowIcon}>{unlocked ? unit.icon : '🔒'}</Text>
                <View style={styles.unitRowInfo}>
                  <Text style={[styles.unitRowTitle, !unlocked && styles.unitRowTitleLocked]}>
                    {unit.number}. {unit.titleJapanese}
                  </Text>
                  <View style={styles.miniProgressBg}>
                    <View
                      style={[
                        styles.miniProgressFill,
                        { width: `${pct * 100}%`, backgroundColor: unit.color },
                      ]}
                    />
                  </View>
                </View>
                <Text style={[styles.unitRowCount, !unlocked && styles.unitRowTitleLocked]}>
                  {completedCount}/{unitLessons.length}
                </Text>
              </View>
            );
          })}
        </View>
      </ScrollView>
    </SafeAreaView>
  );
}

const styles = StyleSheet.create({
  safe: { flex: 1, backgroundColor: colors.background },
  scroll: { flex: 1 },
  content: { padding: spacing.lg, paddingBottom: spacing.xxl },
  header: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    marginBottom: spacing.lg,
  },
  greeting: { ...typography.h2, color: colors.text.primary },
  subGreeting: { ...typography.small, color: colors.text.secondary, marginTop: 2 },
  streakBadge: {
    backgroundColor: '#FFF7ED',
    borderRadius: radius.full,
    paddingHorizontal: spacing.md,
    paddingVertical: spacing.sm,
    flexDirection: 'row',
    alignItems: 'center',
    gap: 4,
    borderWidth: 1,
    borderColor: '#FED7AA',
  },
  streakFlame: { fontSize: 18 },
  streakCount: { fontSize: 20, fontWeight: '700', color: '#EA580C' },
  levelCard: {
    backgroundColor: colors.primary,
    borderRadius: radius.xl,
    padding: spacing.lg,
    marginBottom: spacing.lg,
  },
  levelRow: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'flex-start',
    marginBottom: spacing.md,
  },
  levelLeft: {},
  levelLabel: { ...typography.small, color: 'rgba(255,255,255,0.7)', marginBottom: 2 },
  levelTitle: { ...typography.h3, color: colors.text.inverse },
  xpBadge: {
    backgroundColor: colors.accent,
    paddingHorizontal: spacing.md,
    paddingVertical: spacing.xs,
    borderRadius: radius.full,
  },
  xpText: { ...typography.smallBold, color: colors.primary },
  progressBarBg: {
    height: 8,
    backgroundColor: 'rgba(255,255,255,0.25)',
    borderRadius: radius.full,
    marginBottom: spacing.xs,
    overflow: 'hidden',
  },
  progressBarFill: {
    height: '100%',
    backgroundColor: colors.accent,
    borderRadius: radius.full,
  },
  progressLabel: { ...typography.caption, color: 'rgba(255,255,255,0.6)' },
  statsRow: {
    flexDirection: 'row',
    gap: spacing.sm,
    marginBottom: spacing.lg,
  },
  statCard: {
    flex: 1,
    backgroundColor: colors.card,
    borderRadius: radius.lg,
    padding: spacing.md,
    alignItems: 'center',
    shadowColor: '#000',
    shadowOffset: { width: 0, height: 2 },
    shadowOpacity: 0.06,
    shadowRadius: 6,
    elevation: 2,
  },
  statEmoji: { fontSize: 22, marginBottom: spacing.xs },
  statValue: { ...typography.h3, color: colors.text.primary },
  statLabel: { ...typography.caption, color: colors.text.secondary, textAlign: 'center' },
  section: { marginBottom: spacing.lg },
  sectionTitle: { ...typography.h3, color: colors.text.primary, marginBottom: spacing.md },
  nextLessonCard: {
    backgroundColor: colors.card,
    borderRadius: radius.xl,
    padding: spacing.lg,
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
    borderLeftWidth: 5,
    shadowColor: '#000',
    shadowOffset: { width: 0, height: 3 },
    shadowOpacity: 0.1,
    shadowRadius: 10,
    elevation: 4,
  },
  nextLessonLeft: { flexDirection: 'row', alignItems: 'center', gap: spacing.md, flex: 1 },
  nextLessonIcon: { fontSize: 36 },
  nextLessonUnit: { ...typography.caption, color: colors.text.secondary, marginBottom: 2 },
  nextLessonTitle: { ...typography.bodyBold, color: colors.text.primary, marginBottom: 2 },
  nextLessonMeta: { ...typography.caption, color: colors.text.muted },
  startButton: { fontSize: 20, color: colors.primary, fontWeight: '700' },
  completedBanner: {
    backgroundColor: '#F0FDF4',
    borderRadius: radius.xl,
    padding: spacing.xl,
    alignItems: 'center',
    marginBottom: spacing.lg,
    borderWidth: 1,
    borderColor: '#BBF7D0',
  },
  completedEmoji: { fontSize: 40, marginBottom: spacing.sm },
  completedText: { ...typography.bodyBold, color: '#15803D', textAlign: 'center' },
  unitRow: {
    flexDirection: 'row',
    alignItems: 'center',
    backgroundColor: colors.card,
    borderRadius: radius.lg,
    padding: spacing.md,
    marginBottom: spacing.sm,
    gap: spacing.md,
    shadowColor: '#000',
    shadowOffset: { width: 0, height: 1 },
    shadowOpacity: 0.04,
    shadowRadius: 4,
    elevation: 1,
  },
  unitRowLocked: { opacity: 0.5 },
  unitRowIcon: { fontSize: 24, width: 36, textAlign: 'center' },
  unitRowInfo: { flex: 1 },
  unitRowTitle: { ...typography.smallBold, color: colors.text.primary, marginBottom: 6 },
  unitRowTitleLocked: { color: colors.text.muted },
  miniProgressBg: {
    height: 4,
    backgroundColor: colors.border,
    borderRadius: radius.full,
    overflow: 'hidden',
  },
  miniProgressFill: {
    height: '100%',
    borderRadius: radius.full,
  },
  unitRowCount: { ...typography.caption, color: colors.text.secondary, minWidth: 28, textAlign: 'right' },
});
