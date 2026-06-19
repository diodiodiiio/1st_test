import React, { useRef, useState } from 'react';
import { ScrollView, StyleSheet, Text, TouchableOpacity, View } from 'react-native';
import { ConversationScene } from '../data/types';
import { colors, radius, spacing, typography } from '../theme';
import { useSpeech } from '../hooks/useSpeech';

interface Props {
  scene: ConversationScene;
  unitColor: string;
}

export default function ConversationCard({ scene, unitColor }: Props) {
  const [showTranslation, setShowTranslation] = useState(true);
  const [autoPlayIndex, setAutoPlayIndex] = useState<number | null>(null);
  const { speak, stop, isSpeaking } = useSpeech();
  const autoPlayRef = useRef<ReturnType<typeof setTimeout> | null>(null);

  const speakLine = (text: string, index?: number) => {
    if (index !== undefined) setAutoPlayIndex(index);
    speak(text);
  };

  const playAll = () => {
    stop();
    if (autoPlayRef.current) clearTimeout(autoPlayRef.current);

    let delay = 0;
    scene.lines.forEach((line, index) => {
      const wordCount = line.german.split(' ').length;
      const duration = Math.max(wordCount * 550, 1600);

      autoPlayRef.current = setTimeout(() => {
        setAutoPlayIndex(index);
        speak(line.german);
        if (index === scene.lines.length - 1) {
          setTimeout(() => setAutoPlayIndex(null), duration);
        }
      }, delay);
      delay += duration;
    });
  };

  const stopAll = () => {
    stop();
    if (autoPlayRef.current) clearTimeout(autoPlayRef.current);
    setAutoPlayIndex(null);
  };

  return (
    <View style={styles.container}>
      <View style={[styles.situationBadge, { backgroundColor: unitColor }]}>
        <Text style={styles.situationText}>🎬 {scene.situation}</Text>
      </View>

      <View style={styles.toolbar}>
        <TouchableOpacity
          style={styles.toggleButton}
          onPress={() => setShowTranslation(!showTranslation)}
        >
          <Text style={styles.toggleText}>
            {showTranslation ? '🙈 日本語を隠す' : '👁 日本語を表示'}
          </Text>
        </TouchableOpacity>

        <TouchableOpacity
          style={[styles.playAllBtn, autoPlayIndex !== null && styles.playAllBtnActive]}
          onPress={autoPlayIndex !== null ? stopAll : playAll}
        >
          <Text style={styles.playAllText}>
            {autoPlayIndex !== null ? '⏹ 停止' : '▶ 全部聴く'}
          </Text>
        </TouchableOpacity>
      </View>

      <ScrollView style={styles.dialogueScroll} showsVerticalScrollIndicator={false}>
        {scene.lines.map((line, index) => (
          <View
            key={index}
            style={[
              styles.lineContainer,
              line.speaker === 'B' ? styles.lineRight : styles.lineLeft,
            ]}
          >
            <Text style={[styles.speakerName, line.speaker === 'B' && styles.speakerNameRight]}>
              {line.speakerName}
            </Text>
            <View
              style={[
                styles.bubbleRow,
                line.speaker === 'B' ? styles.bubbleRowRight : styles.bubbleRowLeft,
              ]}
            >
              {line.speaker === 'A' && (
                <TouchableOpacity
                  style={[
                    styles.lineSpeak,
                    autoPlayIndex === index && styles.lineSpeakActive,
                  ]}
                  onPress={() => speakLine(line.german, index)}
                  hitSlop={{ top: 8, bottom: 8, left: 8, right: 8 }}
                >
                  <Text style={styles.lineSpeakIcon}>
                    {autoPlayIndex === index && isSpeaking ? '🔊' : '🔈'}
                  </Text>
                </TouchableOpacity>
              )}
              <View
                style={[
                  styles.bubble,
                  line.speaker === 'B'
                    ? [styles.bubbleUser, { backgroundColor: unitColor }]
                    : styles.bubbleOther,
                  autoPlayIndex === index && styles.bubbleHighlighted,
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
              {line.speaker === 'B' && (
                <TouchableOpacity
                  style={[
                    styles.lineSpeak,
                    autoPlayIndex === index && styles.lineSpeakActive,
                  ]}
                  onPress={() => speakLine(line.german, index)}
                  hitSlop={{ top: 8, bottom: 8, left: 8, right: 8 }}
                >
                  <Text style={styles.lineSpeakIcon}>
                    {autoPlayIndex === index && isSpeaking ? '🔊' : '🔈'}
                  </Text>
                </TouchableOpacity>
              )}
            </View>
          </View>
        ))}
        <View style={styles.tipBox}>
          <Text style={styles.tipLabel}>💡 ポイント</Text>
          <Text style={styles.tipText}>{scene.tip}</Text>
        </View>
        <View style={{ height: spacing.xl }} />
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
  toolbar: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    marginBottom: spacing.md,
    gap: spacing.sm,
  },
  toggleButton: {
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
  playAllBtn: {
    backgroundColor: colors.primary,
    paddingHorizontal: spacing.md,
    paddingVertical: spacing.xs,
    borderRadius: radius.full,
  },
  playAllBtnActive: {
    backgroundColor: colors.danger,
  },
  playAllText: {
    ...typography.smallBold,
    color: colors.text.inverse,
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
  speakerNameRight: {
    textAlign: 'right',
  },
  bubbleRow: {
    flexDirection: 'row',
    alignItems: 'flex-end',
    gap: spacing.xs,
  },
  bubbleRowLeft: {},
  bubbleRowRight: {
    flexDirection: 'row-reverse',
  },
  lineSpeak: {
    width: 28,
    height: 28,
    borderRadius: radius.full,
    backgroundColor: colors.border,
    alignItems: 'center',
    justifyContent: 'center',
    marginBottom: 2,
  },
  lineSpeakActive: {
    backgroundColor: '#BFDBFE',
  },
  lineSpeakIcon: {
    fontSize: 14,
  },
  bubble: {
    borderRadius: radius.lg,
    padding: spacing.md,
    shadowColor: '#000',
    shadowOffset: { width: 0, height: 1 },
    shadowOpacity: 0.06,
    shadowRadius: 4,
    elevation: 2,
    flex: 1,
  },
  bubbleOther: {
    backgroundColor: colors.card,
  },
  bubbleUser: {
    borderBottomRightRadius: 4,
  },
  bubbleHighlighted: {
    shadowOpacity: 0.18,
    shadowRadius: 8,
    elevation: 5,
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
