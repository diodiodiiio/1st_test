import React from 'react';
import { ScrollView, StyleSheet, Text, View } from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';
import { useProgress } from '../context/ProgressContext';
import { CURRICULUM } from '../data/curriculum';
import { colors, radius, spacing, typography } from '../theme';

const LEVEL_THRESHOLDS = [
  { level: 1, title: 'Anfänger', titleJa: '初心者', emoji: '🌱', minXP: 0, nextXP: 150 },
  { level: 2, title: 'Lernender', titleJa: '学習中', emoji: '📖', minXP: 150, nextXP: 400 },
  { level: 3, title: 'Fortgeschritten', titleJa: '上達中', emoji: '📚', minXP: 400, nextXP: 800 },
  { level: 4, title: 'Geübt', titleJa: '熟練', emoji: '🎓', minXP: 800, nextXP: 1500 },
  { level: 5, title: 'Meister', titleJa: 'マイスター', emoji: '🏆', minXP: 1500, nextXP: 1500 },
];

export default function ProfileScreen() {
  const { totalXP, streak, completedLessons } = useProgress();

  const currentLevel = LEVEL_THRESHOLDS.slice().reverse().find((l) => totalXP >= l.minXP) ?? LEVEL_THRESHOLDS[0];
  const nextLevel = LEVEL_THRESHOLDS.find((l) => l.level === currentLevel.level + 1);
  const progressToNext = nextLevel
    ? Math.min((totalXP - currentLevel.minXP) / (nextLevel.minXP - currentLevel.minXP), 1)
    : 1;

  const totalLessons = CURRICULUM.flatMap((u) => u.lessons).length;
  const completedUnits = CURRICULUM.filter((u) =>
    u.lessons.every((l) => completedLessons.includes(l.id))
  ).length;

  const weekDays = Array.from({ length: 7 }, (_, i) => {
    const date = new Date(Date.now() - (6 - i) * 86400000);
    return date.toDateString();
  });

  return (
    <SafeAreaView style={styles.safe}>
      <ScrollView contentContainerStyle={styles.content} showsVerticalScrollIndicator={false}>
        <View style={styles.profileCard}>
          <Text style={styles.avatar}>{currentLevel.emoji}</Text>
          <Text style={styles.levelTitle}>{currentLevel.title}</Text>
          <Text style={styles.levelTitleJa}>{currentLevel.titleJa}</Text>
          <Text style={styles.levelNum}>レベル {currentLevel.level}</Text>

          <View style={styles.progressBarBg}>
            <View style={[styles.progressBarFill, { width: `${progressToNext * 100}%` }]} />
          </View>
          {nextLevel ? (
            <Text style={styles.progressLabel}>
              {totalXP} / {nextLevel.minXP} XP（次: Lv.{nextLevel.level} {nextLevel.titleJa}）
            </Text>
          ) : (
            <Text style={styles.progressLabel}>{totalXP} XP — 最高レベル達成！</Text>
          )}
        </View>

        <View style={styles.statsRow}>
          <View style={styles.statCard}>
            <Text style={styles.statValue}>{totalXP}</Text>
            <Text style={styles.statLabel}>合計XP</Text>
          </View>
          <View style={styles.statCard}>
            <Text style={styles.statValue}>{streak}</Text>
            <Text style={styles.statLabel}>連続日数 🔥</Text>
          </View>
          <View style={styles.statCard}>
            <Text style={styles.statValue}>{completedLessons.length}/{totalLessons}</Text>
            <Text style={styles.statLabel}>完了レッスン</Text>
          </View>
        </View>

        <View style={styles.section}>
          <Text style={styles.sectionTitle}>学習ストリーク（過去7日）</Text>
          <View style={styles.streakGrid}>
            {weekDays.map((day, i) => {
              const isToday = i === 6;
              return (
                <View key={day} style={styles.streakDayCol}>
                  <View
                    style={[
                      styles.streakDot,
                      isToday && streak > 0 ? styles.streakDotActive : styles.streakDotEmpty,
                    ]}
                  >
                    {isToday && streak > 0 && <Text style={styles.streakDotText}>🔥</Text>}
                  </View>
                  <Text style={styles.streakDayLabel}>
                    {['日', '月', '火', '水', '木', '金', '土'][new Date(day).getDay()]}
                  </Text>
                </View>
              );
            })}
          </View>
        </View>

        <View style={styles.section}>
          <Text style={styles.sectionTitle}>ユニット進捗</Text>
          {CURRICULUM.map((unit) => {
            const done = unit.lessons.filter((l) => completedLessons.includes(l.id)).length;
            const total = unit.lessons.length;
            const pct = total > 0 ? done / total : 0;

            return (
              <View key={unit.id} style={styles.unitRow}>
                <Text style={styles.unitIcon}>{unit.icon}</Text>
                <View style={styles.unitInfo}>
                  <View style={styles.unitLabelRow}>
                    <Text style={styles.unitName}>{unit.titleJapanese}</Text>
                    <Text style={[styles.unitCount, pct === 1 && { color: colors.success }]}>
                      {pct === 1 ? '✅ 完了' : `${done}/${total}`}
                    </Text>
                  </View>
                  <View style={styles.miniProgressBg}>
                    <View
                      style={[
                        styles.miniProgressFill,
                        { width: `${pct * 100}%`, backgroundColor: unit.color },
                      ]}
                    />
                  </View>
                </View>
              </View>
            );
          })}
        </View>

        <View style={styles.section}>
          <Text style={styles.sectionTitle}>レベルロードマップ</Text>
          {LEVEL_THRESHOLDS.map((l) => (
            <View key={l.level} style={[styles.levelRow, totalXP >= l.minXP && styles.levelRowUnlocked]}>
              <Text style={styles.levelEmoji}>{l.emoji}</Text>
              <View style={styles.levelInfo}>
                <Text style={[styles.levelName, totalXP >= l.minXP && styles.levelNameUnlocked]}>
                  Lv.{l.level} {l.title}（{l.titleJa}）
                </Text>
                <Text style={styles.levelXP}>{l.minXP} XP〜</Text>
              </View>
              {totalXP >= l.minXP && <Text style={styles.levelCheck}>✓</Text>}
            </View>
          ))}
        </View>
      </ScrollView>
    </SafeAreaView>
  );
}

const styles = StyleSheet.create({
  safe: { flex: 1, backgroundColor: colors.background },
  content: { padding: spacing.lg, paddingBottom: spacing.xxl },
  profileCard: {
    backgroundColor: colors.primary,
    borderRadius: radius.xl,
    padding: spacing.xl,
    alignItems: 'center',
    marginBottom: spacing.lg,
  },
  avatar: { fontSize: 48, marginBottom: spacing.sm },
  levelTitle: { ...typography.h2, color: colors.text.inverse },
  levelTitleJa: { ...typography.small, color: 'rgba(255,255,255,0.7)', marginBottom: spacing.xs },
  levelNum: {
    backgroundColor: colors.accent,
    paddingHorizontal: spacing.md,
    paddingVertical: spacing.xs,
    borderRadius: radius.full,
    ...typography.smallBold,
    color: colors.primary,
    marginBottom: spacing.lg,
  },
  progressBarBg: {
    width: '100%',
    height: 8,
    backgroundColor: 'rgba(255,255,255,0.25)',
    borderRadius: radius.full,
    overflow: 'hidden',
    marginBottom: spacing.xs,
  },
  progressBarFill: {
    height: '100%',
    backgroundColor: colors.accent,
    borderRadius: radius.full,
  },
  progressLabel: { ...typography.caption, color: 'rgba(255,255,255,0.65)' },
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
  statValue: { ...typography.h3, color: colors.text.primary },
  statLabel: { ...typography.caption, color: colors.text.secondary, textAlign: 'center' },
  section: { marginBottom: spacing.lg },
  sectionTitle: { ...typography.h3, color: colors.text.primary, marginBottom: spacing.md },
  streakGrid: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    backgroundColor: colors.card,
    borderRadius: radius.lg,
    padding: spacing.md,
    shadowColor: '#000',
    shadowOffset: { width: 0, height: 2 },
    shadowOpacity: 0.06,
    shadowRadius: 6,
    elevation: 2,
  },
  streakDayCol: { alignItems: 'center', gap: spacing.xs },
  streakDot: {
    width: 36,
    height: 36,
    borderRadius: radius.full,
    alignItems: 'center',
    justifyContent: 'center',
  },
  streakDotActive: { backgroundColor: '#FFF7ED', borderWidth: 2, borderColor: '#FB923C' },
  streakDotEmpty: { backgroundColor: colors.border },
  streakDotText: { fontSize: 18 },
  streakDayLabel: { ...typography.caption, color: colors.text.secondary },
  unitRow: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: spacing.md,
    backgroundColor: colors.card,
    borderRadius: radius.lg,
    padding: spacing.md,
    marginBottom: spacing.sm,
    shadowColor: '#000',
    shadowOffset: { width: 0, height: 1 },
    shadowOpacity: 0.04,
    shadowRadius: 4,
    elevation: 1,
  },
  unitIcon: { fontSize: 24, width: 32, textAlign: 'center' },
  unitInfo: { flex: 1 },
  unitLabelRow: { flexDirection: 'row', justifyContent: 'space-between', marginBottom: 6 },
  unitName: { ...typography.smallBold, color: colors.text.primary },
  unitCount: { ...typography.caption, color: colors.text.secondary },
  miniProgressBg: {
    height: 4,
    backgroundColor: colors.border,
    borderRadius: radius.full,
    overflow: 'hidden',
  },
  miniProgressFill: { height: '100%', borderRadius: radius.full },
  levelRow: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: spacing.md,
    backgroundColor: colors.card,
    borderRadius: radius.lg,
    padding: spacing.md,
    marginBottom: spacing.sm,
    opacity: 0.45,
    borderWidth: 1,
    borderColor: 'transparent',
  },
  levelRowUnlocked: {
    opacity: 1,
    borderColor: colors.success,
    backgroundColor: '#F0FDF4',
  },
  levelEmoji: { fontSize: 22 },
  levelInfo: { flex: 1 },
  levelName: { ...typography.smallBold, color: colors.text.muted },
  levelNameUnlocked: { color: colors.text.primary },
  levelXP: { ...typography.caption, color: colors.text.muted },
  levelCheck: { fontSize: 18, color: colors.success, fontWeight: '700' },
});
