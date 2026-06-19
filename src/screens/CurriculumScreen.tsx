import React from 'react';
import { ScrollView, StyleSheet, Text, TouchableOpacity, View } from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';
import { useNavigation } from '@react-navigation/native';
import type { NativeStackNavigationProp } from '@react-navigation/native-stack';
import { useProgress } from '../context/ProgressContext';
import { CURRICULUM, isUnitUnlocked } from '../data/curriculum';
import { colors, radius, spacing, typography } from '../theme';
import type { RootStackParamList } from '../navigation/AppNavigator';

type Nav = NativeStackNavigationProp<RootStackParamList>;

export default function CurriculumScreen() {
  const navigation = useNavigation<Nav>();
  const { completedLessons } = useProgress();

  return (
    <SafeAreaView style={styles.safe}>
      <View style={styles.header}>
        <Text style={styles.title}>カリキュラム</Text>
        <Text style={styles.subtitle}>6つのユニット • 生活必需度順</Text>
      </View>
      <ScrollView contentContainerStyle={styles.content} showsVerticalScrollIndicator={false}>
        {CURRICULUM.map((unit, unitIndex) => {
          const unlocked = isUnitUnlocked(unit.id, completedLessons);
          const completedCount = unit.lessons.filter((l) => completedLessons.includes(l.id)).length;
          const allDone = completedCount === unit.lessons.length;

          return (
            <View key={unit.id} style={styles.unitSection}>
              <View style={[styles.unitHeader, { backgroundColor: unit.color + '18' }]}>
                <View style={[styles.unitNumberBadge, { backgroundColor: unit.color }]}>
                  <Text style={styles.unitNumber}>{unit.number}</Text>
                </View>
                <View style={styles.unitHeaderInfo}>
                  <Text style={styles.unitIcon}>{unlocked ? unit.icon : '🔒'}</Text>
                  <View>
                    <Text style={[styles.unitTitle, !unlocked && styles.locked]}>{unit.title}</Text>
                    <Text style={[styles.unitTitleJa, !unlocked && styles.locked]}>{unit.titleJapanese}</Text>
                  </View>
                </View>
                <View style={styles.unitProgress}>
                  {allDone ? (
                    <Text style={styles.completedCheck}>✅</Text>
                  ) : (
                    <Text style={[styles.progressText, !unlocked && styles.locked]}>
                      {completedCount}/{unit.lessons.length}
                    </Text>
                  )}
                </View>
              </View>

              {!unlocked && (
                <View style={styles.lockedBanner}>
                  <Text style={styles.lockedText}>
                    🔒 ユニット {unitIndex} をすべて完了すると解放されます
                  </Text>
                </View>
              )}

              {unit.lessons.map((lesson) => {
                const done = completedLessons.includes(lesson.id);
                const canStart = unlocked;

                return (
                  <TouchableOpacity
                    key={lesson.id}
                    style={[
                      styles.lessonCard,
                      done && styles.lessonCardDone,
                      !canStart && styles.lessonCardLocked,
                    ]}
                    onPress={() =>
                      canStart &&
                      navigation.navigate('Lesson', {
                        lessonId: lesson.id,
                        unitId: unit.id,
                      })
                    }
                    activeOpacity={canStart ? 0.8 : 1}
                  >
                    <View style={[styles.lessonDot, { backgroundColor: done ? unit.color : colors.border }]}>
                      {done && <Text style={styles.lessonDotCheck}>✓</Text>}
                    </View>
                    <View style={styles.lessonInfo}>
                      <Text style={[styles.lessonTitle, !canStart && styles.locked]}>{lesson.title}</Text>
                      <Text style={[styles.lessonSubtitle, !canStart && styles.locked]}>{lesson.subtitle}</Text>
                      <View style={styles.lessonMeta}>
                        <Text style={styles.metaChip}>📖 {lesson.vocab.length}語</Text>
                        <Text style={styles.metaChip}>❓ {lesson.quiz.length}問</Text>
                        <Text style={styles.metaChip}>💬 会話</Text>
                        <Text style={[styles.metaChip, styles.xpChip]}>+{lesson.xpReward}XP</Text>
                      </View>
                    </View>
                    {canStart && !done && (
                      <View style={[styles.startBtn, { backgroundColor: unit.color }]}>
                        <Text style={styles.startBtnText}>▶</Text>
                      </View>
                    )}
                    {done && (
                      <TouchableOpacity
                        style={styles.retryBtn}
                        onPress={() =>
                          navigation.navigate('Lesson', { lessonId: lesson.id, unitId: unit.id })
                        }
                      >
                        <Text style={styles.retryBtnText}>復習</Text>
                      </TouchableOpacity>
                    )}
                  </TouchableOpacity>
                );
              })}
            </View>
          );
        })}
      </ScrollView>
    </SafeAreaView>
  );
}

const styles = StyleSheet.create({
  safe: { flex: 1, backgroundColor: colors.background },
  header: {
    paddingHorizontal: spacing.lg,
    paddingTop: spacing.md,
    paddingBottom: spacing.sm,
  },
  title: { ...typography.h1, color: colors.text.primary },
  subtitle: { ...typography.small, color: colors.text.secondary, marginTop: 2 },
  content: { padding: spacing.lg, paddingBottom: spacing.xxl },
  unitSection: { marginBottom: spacing.xl },
  unitHeader: {
    flexDirection: 'row',
    alignItems: 'center',
    borderRadius: radius.lg,
    padding: spacing.md,
    marginBottom: spacing.sm,
    gap: spacing.sm,
  },
  unitNumberBadge: {
    width: 32,
    height: 32,
    borderRadius: radius.full,
    alignItems: 'center',
    justifyContent: 'center',
  },
  unitNumber: { color: colors.text.inverse, fontWeight: '700', fontSize: 14 },
  unitHeaderInfo: { flex: 1, flexDirection: 'row', alignItems: 'center', gap: spacing.sm },
  unitIcon: { fontSize: 22 },
  unitTitle: { ...typography.bodyBold, color: colors.text.primary },
  unitTitleJa: { ...typography.caption, color: colors.text.secondary },
  unitProgress: { minWidth: 32, alignItems: 'flex-end' },
  progressText: { ...typography.smallBold, color: colors.text.secondary },
  completedCheck: { fontSize: 20 },
  lockedBanner: {
    backgroundColor: '#F3F4F6',
    borderRadius: radius.md,
    padding: spacing.sm,
    marginBottom: spacing.sm,
  },
  lockedText: { ...typography.small, color: colors.text.muted, textAlign: 'center' },
  lessonCard: {
    backgroundColor: colors.card,
    borderRadius: radius.lg,
    padding: spacing.md,
    flexDirection: 'row',
    alignItems: 'center',
    marginBottom: spacing.sm,
    gap: spacing.md,
    shadowColor: '#000',
    shadowOffset: { width: 0, height: 2 },
    shadowOpacity: 0.07,
    shadowRadius: 6,
    elevation: 2,
  },
  lessonCardDone: { backgroundColor: '#F8FFF8' },
  lessonCardLocked: { opacity: 0.45 },
  lessonDot: {
    width: 28,
    height: 28,
    borderRadius: radius.full,
    alignItems: 'center',
    justifyContent: 'center',
  },
  lessonDotCheck: { color: colors.text.inverse, fontWeight: '700', fontSize: 12 },
  lessonInfo: { flex: 1 },
  lessonTitle: { ...typography.bodyBold, color: colors.text.primary, marginBottom: 2 },
  lessonSubtitle: { ...typography.caption, color: colors.text.secondary, marginBottom: spacing.xs },
  lessonMeta: { flexDirection: 'row', flexWrap: 'wrap', gap: 4 },
  metaChip: {
    ...typography.caption,
    backgroundColor: colors.background,
    paddingHorizontal: 6,
    paddingVertical: 2,
    borderRadius: radius.sm,
    color: colors.text.secondary,
  },
  xpChip: { backgroundColor: '#FEF9C3', color: '#A16207' },
  startBtn: {
    width: 36,
    height: 36,
    borderRadius: radius.full,
    alignItems: 'center',
    justifyContent: 'center',
  },
  startBtnText: { color: colors.text.inverse, fontSize: 14, fontWeight: '700' },
  retryBtn: {
    paddingHorizontal: spacing.md,
    paddingVertical: spacing.xs,
    backgroundColor: colors.background,
    borderRadius: radius.full,
    borderWidth: 1,
    borderColor: colors.border,
  },
  retryBtnText: { ...typography.smallBold, color: colors.text.secondary },
  locked: { color: colors.text.muted },
});
