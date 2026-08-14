import React, { useState } from 'react';
import {
  ActivityIndicator,
  Alert,
  Platform,
  ScrollView,
  StyleSheet,
  Text,
  TouchableOpacity,
  View,
} from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';
import { useNavigation } from '@react-navigation/native';
import type { NativeStackNavigationProp } from '@react-navigation/native-stack';
import { useDecks } from '../context/DeckContext';
import { pickAndParseExcel } from '../utils/excelImport';
import { RowIssue } from '../data/deckTypes';
import { colors, radius, spacing, typography } from '../theme';
import type { RootStackParamList } from '../navigation/AppNavigator';

type Nav = NativeStackNavigationProp<RootStackParamList>;

/** Web には Alert.alert が無いので、確認ダイアログをプラットフォームごとに出し分ける */
function confirmDelete(deckName: string, onConfirm: () => void) {
  const message = `単語帳「${deckName}」を削除しますか？`;
  if (Platform.OS === 'web') {
    // eslint-disable-next-line no-alert
    if (window.confirm(message)) onConfirm();
    return;
  }
  Alert.alert('単語帳の削除', message, [
    { text: 'キャンセル', style: 'cancel' },
    { text: '削除', style: 'destructive', onPress: onConfirm },
  ]);
}

export default function MyVocabScreen() {
  const navigation = useNavigation<Nav>();
  const { decks, loading, addDeck, removeDeck } = useDecks();
  const [importing, setImporting] = useState(false);
  const [issues, setIssues] = useState<RowIssue[] | null>(null);
  const [notice, setNotice] = useState<{ type: 'ok' | 'error'; text: string } | null>(null);

  const handleImport = async () => {
    setImporting(true);
    setNotice(null);
    setIssues(null);

    const outcome = await pickAndParseExcel();
    setImporting(false);

    if (outcome.status === 'cancelled') return;

    if (outcome.status === 'error') {
      setNotice({ type: 'error', text: outcome.message });
      return;
    }

    const { result, fileName, sheetName } = outcome;

    if (result.cards.length === 0) {
      setNotice({
        type: 'error',
        text: result.issues[0]?.reason ?? '読み込める単語が1つもありませんでした',
      });
      setIssues(result.issues.slice(0, 10));
      return;
    }

    const deckName = fileName.replace(/\.(xlsx|xls|csv)$/i, '');
    await addDeck({
      name: deckName,
      sourceFile: fileName,
      cards: result.cards,
      categories: result.categories,
    });

    setNotice({
      type: 'ok',
      text: `「${sheetName}」から ${result.cards.length}語を取り込みました`,
    });
    if (result.issues.length > 0) setIssues(result.issues.slice(0, 10));
  };

  return (
    <SafeAreaView style={styles.safe}>
      <View style={styles.header}>
        <Text style={styles.title}>My単語帳</Text>
        <Text style={styles.subtitle}>Excelで作った単語リストを取り込んで学習</Text>
      </View>

      <ScrollView contentContainerStyle={styles.content} showsVerticalScrollIndicator={false}>
        <TouchableOpacity
          style={[styles.importBtn, importing && styles.importBtnDisabled]}
          onPress={handleImport}
          disabled={importing}
          activeOpacity={0.85}
        >
          {importing ? (
            <ActivityIndicator color={colors.text.inverse} />
          ) : (
            <>
              <Text style={styles.importIcon}>📥</Text>
              <View style={styles.importTextWrap}>
                <Text style={styles.importTitle}>Excelファイルを取り込む</Text>
                <Text style={styles.importSub}>.xlsx / .xls / .csv に対応</Text>
              </View>
            </>
          )}
        </TouchableOpacity>

        {notice && (
          <View style={[styles.notice, notice.type === 'ok' ? styles.noticeOk : styles.noticeError]}>
            <Text style={[styles.noticeText, notice.type === 'ok' ? styles.noticeTextOk : styles.noticeTextError]}>
              {notice.type === 'ok' ? '✅ ' : '⚠️ '}
              {notice.text}
            </Text>
          </View>
        )}

        {issues && issues.length > 0 && (
          <View style={styles.issueBox}>
            <Text style={styles.issueTitle}>読み飛ばした行</Text>
            {issues.map((issue, i) => (
              <Text key={`${issue.row}-${i}`} style={styles.issueLine}>
                {issue.row}行目: {issue.reason}
              </Text>
            ))}
          </View>
        )}

        <View style={styles.formatCard}>
          <Text style={styles.formatTitle}>📋 Excelの書き方</Text>
          <Text style={styles.formatDesc}>
            1行目を見出し行にして、次の列名を使ってください。列の順番は自由です。
          </Text>
          <View style={styles.formatTable}>
            <View style={[styles.formatRow, styles.formatRowHead]}>
              <Text style={[styles.formatCell, styles.formatCellHead, styles.formatColName]}>列名</Text>
              <Text style={[styles.formatCell, styles.formatCellHead]}>内容</Text>
            </View>
            {[
              { name: 'ドイツ語', desc: '必須。覚えたい単語やフレーズ', required: true },
              { name: '日本語', desc: '必須。その意味', required: true },
              { name: '発音', desc: '任意。カタカナ読み', required: false },
              { name: '例文', desc: '任意。ドイツ語の例文', required: false },
              { name: '例文の意味', desc: '任意。例文の日本語訳', required: false },
              { name: 'カテゴリ', desc: '任意。分類ラベル', required: false },
            ].map((row) => (
              <View key={row.name} style={styles.formatRow}>
                <View style={styles.formatColName}>
                  <Text style={styles.formatCellName}>{row.name}</Text>
                  {row.required && <Text style={styles.requiredTag}>必須</Text>}
                </View>
                <Text style={styles.formatCell}>{row.desc}</Text>
              </View>
            ))}
          </View>
          <Text style={styles.formatNote}>
            ※「ドイツ語」と「日本語」が空欄の行は自動的に読み飛ばされます。{'\n'}
            ※ German / Japanese など英語の列名でも認識します。
          </Text>
        </View>

        <Text style={styles.sectionTitle}>取り込んだ単語帳</Text>

        {loading ? (
          <ActivityIndicator style={styles.loader} color={colors.primary} />
        ) : decks.length === 0 ? (
          <View style={styles.emptyBox}>
            <Text style={styles.emptyEmoji}>📚</Text>
            <Text style={styles.emptyText}>まだ単語帳がありません</Text>
            <Text style={styles.emptySub}>上のボタンからExcelを取り込んでみましょう</Text>
          </View>
        ) : (
          decks.map((deck) => (
            <TouchableOpacity
              key={deck.id}
              style={styles.deckCard}
              onPress={() => navigation.navigate('DeckStudy', { deckId: deck.id })}
              activeOpacity={0.85}
            >
              <View style={styles.deckIconWrap}>
                <Text style={styles.deckIcon}>📗</Text>
              </View>
              <View style={styles.deckInfo}>
                <Text style={styles.deckName} numberOfLines={1}>
                  {deck.name}
                </Text>
                <Text style={styles.deckMeta}>
                  {deck.cards.length}語
                  {deck.categories.length > 0 && ` • ${deck.categories.length}カテゴリ`}
                  {' • '}
                  {new Date(deck.importedAt).toLocaleDateString('ja-JP')}
                </Text>
              </View>
              <TouchableOpacity
                style={styles.deleteBtn}
                onPress={() => confirmDelete(deck.name, () => removeDeck(deck.id))}
                hitSlop={{ top: 10, bottom: 10, left: 10, right: 10 }}
              >
                <Text style={styles.deleteBtnText}>削除</Text>
              </TouchableOpacity>
            </TouchableOpacity>
          ))
        )}
      </ScrollView>
    </SafeAreaView>
  );
}

const styles = StyleSheet.create({
  safe: { flex: 1, backgroundColor: colors.background },
  header: { paddingHorizontal: spacing.lg, paddingTop: spacing.md, paddingBottom: spacing.sm },
  title: { ...typography.h1, color: colors.text.primary },
  subtitle: { ...typography.small, color: colors.text.secondary, marginTop: 2 },
  content: { padding: spacing.lg, paddingBottom: spacing.xxl },

  importBtn: {
    backgroundColor: colors.primary,
    borderRadius: radius.xl,
    padding: spacing.lg,
    flexDirection: 'row',
    alignItems: 'center',
    gap: spacing.md,
    minHeight: 76,
    justifyContent: 'center',
    shadowColor: '#000',
    shadowOffset: { width: 0, height: 3 },
    shadowOpacity: 0.12,
    shadowRadius: 10,
    elevation: 4,
  },
  importBtnDisabled: { opacity: 0.7 },
  importIcon: { fontSize: 28 },
  importTextWrap: { flex: 1 },
  importTitle: { ...typography.bodyBold, color: colors.text.inverse },
  importSub: { ...typography.caption, color: 'rgba(255,255,255,0.7)', marginTop: 2 },

  notice: { borderRadius: radius.lg, padding: spacing.md, marginTop: spacing.md, borderWidth: 1 },
  noticeOk: { backgroundColor: '#F0FDF4', borderColor: '#BBF7D0' },
  noticeError: { backgroundColor: '#FEF2F2', borderColor: '#FECACA' },
  noticeText: { ...typography.small, lineHeight: 20 },
  noticeTextOk: { color: '#15803D' },
  noticeTextError: { color: '#B91C1C' },

  issueBox: {
    backgroundColor: '#FFFBEB',
    borderRadius: radius.lg,
    padding: spacing.md,
    marginTop: spacing.sm,
    borderWidth: 1,
    borderColor: '#FDE68A',
  },
  issueTitle: { ...typography.smallBold, color: '#92400E', marginBottom: spacing.xs },
  issueLine: { ...typography.caption, color: '#78350F', lineHeight: 18 },

  formatCard: {
    backgroundColor: colors.card,
    borderRadius: radius.xl,
    padding: spacing.lg,
    marginTop: spacing.lg,
    shadowColor: '#000',
    shadowOffset: { width: 0, height: 2 },
    shadowOpacity: 0.06,
    shadowRadius: 8,
    elevation: 2,
  },
  formatTitle: { ...typography.h3, color: colors.text.primary, marginBottom: spacing.xs },
  formatDesc: { ...typography.small, color: colors.text.secondary, marginBottom: spacing.md },
  formatTable: { borderRadius: radius.md, overflow: 'hidden', borderWidth: 1, borderColor: colors.border },
  formatRow: { flexDirection: 'row', borderBottomWidth: 1, borderBottomColor: colors.border },
  formatRowHead: { backgroundColor: colors.background },
  formatColName: { width: 108, paddingRight: spacing.sm, flexDirection: 'row', alignItems: 'center', gap: 4 },
  formatCell: { ...typography.caption, color: colors.text.secondary, flex: 1, padding: spacing.sm, lineHeight: 17 },
  formatCellHead: { ...typography.smallBold, color: colors.text.primary },
  formatCellName: { ...typography.caption, color: colors.text.primary, fontWeight: '700', paddingLeft: spacing.sm },
  requiredTag: {
    ...typography.caption,
    fontSize: 9,
    color: colors.danger,
    backgroundColor: '#FEE2E2',
    paddingHorizontal: 4,
    paddingVertical: 1,
    borderRadius: radius.sm,
  },
  formatNote: { ...typography.caption, color: colors.text.muted, marginTop: spacing.md, lineHeight: 17 },

  sectionTitle: { ...typography.h3, color: colors.text.primary, marginTop: spacing.xl, marginBottom: spacing.md },
  loader: { marginTop: spacing.lg },

  emptyBox: {
    backgroundColor: colors.card,
    borderRadius: radius.xl,
    padding: spacing.xl,
    alignItems: 'center',
    borderWidth: 1,
    borderColor: colors.border,
    borderStyle: 'dashed',
  },
  emptyEmoji: { fontSize: 36, marginBottom: spacing.sm },
  emptyText: { ...typography.bodyBold, color: colors.text.secondary },
  emptySub: { ...typography.caption, color: colors.text.muted, marginTop: 2 },

  deckCard: {
    backgroundColor: colors.card,
    borderRadius: radius.lg,
    padding: spacing.md,
    flexDirection: 'row',
    alignItems: 'center',
    gap: spacing.md,
    marginBottom: spacing.sm,
    shadowColor: '#000',
    shadowOffset: { width: 0, height: 2 },
    shadowOpacity: 0.07,
    shadowRadius: 6,
    elevation: 2,
  },
  deckIconWrap: {
    width: 44,
    height: 44,
    borderRadius: radius.md,
    backgroundColor: colors.background,
    alignItems: 'center',
    justifyContent: 'center',
  },
  deckIcon: { fontSize: 22 },
  deckInfo: { flex: 1 },
  deckName: { ...typography.bodyBold, color: colors.text.primary },
  deckMeta: { ...typography.caption, color: colors.text.secondary, marginTop: 2 },
  deleteBtn: {
    paddingHorizontal: spacing.md,
    paddingVertical: spacing.xs,
    borderRadius: radius.full,
    borderWidth: 1,
    borderColor: colors.border,
  },
  deleteBtnText: { ...typography.caption, color: colors.text.secondary },
});
