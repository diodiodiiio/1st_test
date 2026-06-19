import React, { useState } from 'react';
import { ScrollView, StyleSheet, Text, TouchableOpacity, View } from 'react-native';
import { ConversationScene } from '../data/types';
import { colors, radius, spacing, typography } from '../theme';

interface Props {
  scene: ConversationScene;
  unitColor: string;
}

export default function ConversationCard({ scene, unitColor }: Props) {
  const [showTranslation, setShowTranslation] = useState(true);

  return (
    <View style={styles.container}>
      <View style={[styles.situationBadge, { backgroundColor: unitColor }]}>
        <Text style={styles.situationText}>🎬 {scene.situation}</Text>
      </View>

      <TouchableOpacity
        style={styles.toggleButton}
        onPress={() => setShowTranslation(!showTranslation)}
      >
        <Text style={styles.toggleText}>
          {showTranslation ? '🙈 日本語を隠す' : '👁 日本語を表示'}
        </Text>
      </TouchableOpacity>

      <ScrollView style={styles.dialogueScroll} showsVerticalScrollIndicator={false}>
        {scene.lines.map((line, index) => (
          <View
            key={index}
            style={[
              styles.lineContainer,
              line.speaker === 'B' ? styles.lineRight : styles.lineLeft,
            ]}
          >
            <Text style={styles.speakerName}>{line.speakerName}</Text>
            <View
              style={[
                styles.bubble,
                line.speaker === 'B'
                  ? [styles.bubbleUser, { backgroundColor: unitColor }]
                  : styles.bubbleOther,
              ]}
            >
              <Text
                style={[
                  styles.germanLine,
                  line.speaker === 'B' ? styles.germanLineUser : null,
                ]}
              >
                {line.german}
              </Text>
              {showTranslation && (
                <Text
                  style={[
                    styles.japaneseLine,
                    line.speaker === 'B' ? styles.japaneseLineUser : null,
                  ]}
                >
                  {line.japanese}
                </Text>
              )}
            </View>
          </View>
        ))}
        <View style={styles.tipBox}>
          <Text style={styles.tipLabel}>💡 ポイント</Text>
          <Text style={styles.tipText}>{scene.tip}</Text>
        </View>
      </ScrollView>
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
  },
  situationBadge: {
    alignSelf: 'center',
    paddingHorizontal: spacing.lg,
    paddingVertical: spacing.sm,
    borderRadius: radius.full,
    marginBottom: spacing.md,
  },
  situationText: {
    color: colors.text.inverse,
    ...typography.smallBold,
  },
  toggleButton: {
    alignSelf: 'flex-end',
    marginBottom: spacing.md,
    backgroundColor: colors.background,
    paddingHorizontal: spacing.md,
    paddingVertical: spacing.xs,
    borderRadius: radius.full,
    borderWidth: 1,
    borderColor: colors.border,
  },
  toggleText: {
    ...typography.small,
    color: colors.text.secondary,
  },
  dialogueScroll: {
    flex: 1,
  },
  lineContainer: {
    marginBottom: spacing.md,
    maxWidth: '80%',
  },
  lineLeft: {
    alignSelf: 'flex-start',
  },
  lineRight: {
    alignSelf: 'flex-end',
  },
  speakerName: {
    ...typography.caption,
    color: colors.text.secondary,
    marginBottom: spacing.xs,
    paddingHorizontal: spacing.xs,
  },
  bubble: {
    borderRadius: radius.lg,
    padding: spacing.md,
    shadowColor: '#000',
    shadowOffset: { width: 0, height: 1 },
    shadowOpacity: 0.06,
    shadowRadius: 4,
    elevation: 2,
  },
  bubbleOther: {
    backgroundColor: colors.card,
  },
  bubbleUser: {
    borderBottomRightRadius: 4,
  },
  germanLine: {
    ...typography.bodyBold,
    color: colors.text.primary,
    marginBottom: 2,
  },
  germanLineUser: {
    color: colors.text.inverse,
  },
  japaneseLine: {
    ...typography.small,
    color: colors.text.secondary,
  },
  japaneseLineUser: {
    color: 'rgba(255,255,255,0.8)',
  },
  tipBox: {
    backgroundColor: '#FFFBEB',
    borderRadius: radius.lg,
    padding: spacing.md,
    marginTop: spacing.md,
    borderWidth: 1,
    borderColor: '#FDE68A',
    marginBottom: spacing.lg,
  },
  tipLabel: {
    ...typography.smallBold,
    color: '#92400E',
    marginBottom: spacing.xs,
  },
  tipText: {
    ...typography.small,
    color: '#78350F',
    lineHeight: 18,
  },
});
