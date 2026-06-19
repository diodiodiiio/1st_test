import React, { useEffect, useRef } from 'react';
import { Animated, StyleSheet, Text, TouchableOpacity, View } from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';
import { useNavigation, useRoute, RouteProp } from '@react-navigation/native';
import type { NativeStackNavigationProp } from '@react-navigation/native-stack';
import { useProgress } from '../context/ProgressContext';
import { getLessonById, getUnitById } from '../data/curriculum';
import { colors, radius, spacing, typography } from '../theme';
import type { RootStackParamList } from '../navigation/AppNavigator';

type Nav = NativeStackNavigationProp<RootStackParamList>;
type Route = RouteProp<RootStackParamList, 'Result'>;

export default function ResultScreen() {
  const navigation = useNavigation<Nav>();
  const route = useRoute<Route>();
  const { lessonId, unitId, xpEarned, quizScore, quizTotal } = route.params;
  const { completeLesson, streak } = useProgress();

  const lesson = getLessonById(lessonId);
  const unit = getUnitById(unitId);
  const unitColor = unit?.color ?? colors.primary;

  const scaleAnim = useRef(new Animated.Value(0.5)).current;
  const fadeAnim = useRef(new Animated.Value(0)).current;

  useEffect(() => {
    completeLesson(lessonId, xpEarned);
    Animated.parallel([
      Animated.spring(scaleAnim, { toValue: 1, friction: 5, useNativeDriver: true }),
      Animated.timing(fadeAnim, { toValue: 1, duration: 400, useNativeDriver: true }),
    ]).start();
  }, []);

  const scorePercent = quizTotal > 0 ? Math.round((quizScore / quizTotal) * 100) : 100;
  const grade = scorePercent >= 80 ? '🏆 素晴らしい！' : scorePercent >= 60 ? '👍 よくできました！' : '💪 もう一度挑戦しよう！';

  return (
    <SafeAreaView style={styles.safe}>
      <Animated.View style={[styles.container, { opacity: fadeAnim }]}>
        <Animated.View style={[styles.xpCircle, { backgroundColor: unitColor, transform: [{ scale: scaleAnim }] }]}>
          <Text style={styles.xpEmoji}>⭐</Text>
          <Text style={styles.xpValue}>+{xpEarned}</Text>
          <Text style={styles.xpLabel}>XP獲得！</Text>
        </Animated.View>

        <Text style={styles.completedTitle}>レッスン完了！</Text>
        <Text style={styles.gradeText}>{grade}</Text>

        <View style={styles.statsGrid}>
          <View style={styles.statBox}>
            <Text style={styles.statEmoji}>❓</Text>
            <Text style={styles.statValue}>{quizScore}/{quizTotal}</Text>
            <Text style={styles.statLabel}>クイズ正解</Text>
          </View>
          <View style={styles.statBox}>
            <Text style={styles.statEmoji}>⭐</Text>
            <Text style={styles.statValue}>+{xpEarned}</Text>
            <Text style={styles.statLabel}>XP</Text>
          </View>
          <View style={styles.statBox}>
            <Text style={styles.statEmoji}>🔥</Text>
            <Text style={styles.statValue}>{streak}</Text>
            <Text style={styles.statLabel}>連続日数</Text>
          </View>
        </View>

        {lesson && (
          <View style={styles.tipBox}>
            <Text style={styles.tipTitle}>💡 会話のポイント</Text>
            <Text style={styles.tipText}>{lesson.conversation.tip}</Text>
          </View>
        )}

        <View style={styles.buttons}>
          <TouchableOpacity
            style={[styles.primaryBtn, { backgroundColor: unitColor }]}
            onPress={() => navigation.navigate('MainTabs')}
          >
            <Text style={styles.primaryBtnText}>ホームへ戻る</Text>
          </TouchableOpacity>
          <TouchableOpacity
            style={styles.secondaryBtn}
            onPress={() => navigation.navigate('MainTabs')}
          >
            <Text style={styles.secondaryBtnText}>次のレッスンへ →</Text>
          </TouchableOpacity>
        </View>
      </Animated.View>
    </SafeAreaView>
  );
}

const styles = StyleSheet.create({
  safe: { flex: 1, backgroundColor: colors.background },
  container: {
    flex: 1,
    padding: spacing.lg,
    alignItems: 'center',
    justifyContent: 'center',
  },
  xpCircle: {
    width: 140,
    height: 140,
    borderRadius: radius.full,
    alignItems: 'center',
    justifyContent: 'center',
    marginBottom: spacing.lg,
    shadowColor: '#000',
    shadowOffset: { width: 0, height: 8 },
    shadowOpacity: 0.2,
    shadowRadius: 16,
    elevation: 8,
  },
  xpEmoji: { fontSize: 28 },
  xpValue: { fontSize: 32, fontWeight: '800', color: colors.text.inverse },
  xpLabel: { ...typography.small, color: 'rgba(255,255,255,0.85)' },
  completedTitle: { ...typography.h1, color: colors.text.primary, marginBottom: spacing.xs },
  gradeText: { ...typography.h3, color: colors.text.secondary, marginBottom: spacing.xl },
  statsGrid: {
    flexDirection: 'row',
    gap: spacing.md,
    marginBottom: spacing.lg,
    width: '100%',
  },
  statBox: {
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
  statLabel: { ...typography.caption, color: colors.text.secondary },
  tipBox: {
    backgroundColor: '#FFFBEB',
    borderRadius: radius.lg,
    padding: spacing.md,
    borderWidth: 1,
    borderColor: '#FDE68A',
    width: '100%',
    marginBottom: spacing.xl,
  },
  tipTitle: { ...typography.smallBold, color: '#92400E', marginBottom: spacing.xs },
  tipText: { ...typography.small, color: '#78350F', lineHeight: 18 },
  buttons: { width: '100%', gap: spacing.sm },
  primaryBtn: {
    borderRadius: radius.full,
    paddingVertical: spacing.md,
    alignItems: 'center',
  },
  primaryBtnText: { ...typography.bodyBold, color: colors.text.inverse },
  secondaryBtn: {
    borderRadius: radius.full,
    paddingVertical: spacing.md,
    alignItems: 'center',
    backgroundColor: colors.card,
    borderWidth: 1,
    borderColor: colors.border,
  },
  secondaryBtnText: { ...typography.bodyBold, color: colors.text.primary },
});
