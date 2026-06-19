import React, { useRef, useState } from 'react';
import {
  Animated,
  StyleSheet,
  Text,
  TouchableWithoutFeedback,
  View,
} from 'react-native';
import { VocabCard } from '../data/types';
import { colors, radius, spacing, typography } from '../theme';

interface Props {
  card: VocabCard;
  unitColor: string;
}

export default function FlashCard({ card, unitColor }: Props) {
  const [flipped, setFlipped] = useState(false);
  const flipAnim = useRef(new Animated.Value(0)).current;

  const flip = () => {
    const toValue = flipped ? 0 : 1;
    Animated.spring(flipAnim, {
      toValue,
      friction: 8,
      tension: 10,
      useNativeDriver: true,
    }).start();
    setFlipped(!flipped);
  };

  const frontRotate = flipAnim.interpolate({
    inputRange: [0, 1],
    outputRange: ['0deg', '180deg'],
  });
  const backRotate = flipAnim.interpolate({
    inputRange: [0, 1],
    outputRange: ['180deg', '360deg'],
  });
  const frontOpacity = flipAnim.interpolate({ inputRange: [0, 0.5, 1], outputRange: [1, 0, 0] });
  const backOpacity = flipAnim.interpolate({ inputRange: [0, 0.5, 1], outputRange: [0, 0, 1] });

  return (
    <TouchableWithoutFeedback onPress={flip}>
      <View style={styles.container}>
        <Animated.View
          style={[styles.card, styles.front, { transform: [{ rotateY: frontRotate }], opacity: frontOpacity }]}
        >
          <View style={[styles.badge, { backgroundColor: unitColor }]}>
            <Text style={styles.badgeText}>ドイツ語</Text>
          </View>
          <Text style={styles.germanText}>{card.german}</Text>
          <Text style={styles.pronunciation}>{card.pronunciation}</Text>
          <Text style={styles.hint}>タップして答えを見る</Text>
        </Animated.View>

        <Animated.View
          style={[styles.card, styles.back, { transform: [{ rotateY: backRotate }], opacity: backOpacity }]}
        >
          <View style={[styles.badge, { backgroundColor: '#4B5563' }]}>
            <Text style={styles.badgeText}>日本語</Text>
          </View>
          <Text style={styles.japaneseText}>{card.japanese}</Text>
          {card.example && (
            <View style={styles.exampleBox}>
              <Text style={styles.exampleGerman}>{card.example.german}</Text>
              <Text style={styles.exampleJapanese}>{card.example.japanese}</Text>
            </View>
          )}
        </Animated.View>
      </View>
    </TouchableWithoutFeedback>
  );
}

const styles = StyleSheet.create({
  container: {
    width: '100%',
    height: 260,
  },
  card: {
    position: 'absolute',
    width: '100%',
    height: '100%',
    borderRadius: radius.xl,
    padding: spacing.xl,
    alignItems: 'center',
    justifyContent: 'center',
    backfaceVisibility: 'hidden',
    shadowColor: '#000',
    shadowOffset: { width: 0, height: 4 },
    shadowOpacity: 0.12,
    shadowRadius: 12,
    elevation: 5,
  },
  front: {
    backgroundColor: colors.card,
  },
  back: {
    backgroundColor: '#F0F9FF',
  },
  badge: {
    position: 'absolute',
    top: spacing.md,
    right: spacing.md,
    paddingHorizontal: spacing.sm,
    paddingVertical: spacing.xs,
    borderRadius: radius.full,
  },
  badgeText: {
    color: colors.text.inverse,
    ...typography.caption,
    fontWeight: '600',
  },
  germanText: {
    fontSize: 32,
    fontWeight: '700',
    color: colors.text.primary,
    textAlign: 'center',
    marginBottom: spacing.sm,
  },
  pronunciation: {
    ...typography.body,
    color: colors.text.secondary,
    textAlign: 'center',
    marginBottom: spacing.lg,
  },
  hint: {
    ...typography.small,
    color: colors.text.muted,
    position: 'absolute',
    bottom: spacing.md,
  },
  japaneseText: {
    fontSize: 28,
    fontWeight: '700',
    color: colors.primary,
    textAlign: 'center',
    marginBottom: spacing.md,
  },
  exampleBox: {
    backgroundColor: 'rgba(30, 58, 95, 0.06)',
    borderRadius: radius.md,
    padding: spacing.md,
    width: '100%',
    marginTop: spacing.sm,
  },
  exampleGerman: {
    ...typography.small,
    fontWeight: '600',
    color: colors.text.primary,
    marginBottom: spacing.xs,
  },
  exampleJapanese: {
    ...typography.small,
    color: colors.text.secondary,
  },
});
