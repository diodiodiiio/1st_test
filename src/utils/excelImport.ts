import { Platform } from 'react-native';
import * as DocumentPicker from 'expo-document-picker';
import * as FileSystem from 'expo-file-system';
import * as XLSX from 'xlsx';
import { ParseResult, parseSheetRows } from '../data/deckTypes';

const EXCEL_MIME_TYPES = [
  'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet', // .xlsx
  'application/vnd.ms-excel', // .xls
  'text/csv', // .csv
];

export interface PickedFile {
  name: string;
  /** SheetJSに渡せる形式のデータ */
  workbook: XLSX.WorkBook;
}

export type ImportOutcome =
  | { status: 'cancelled' }
  | { status: 'error'; message: string }
  | { status: 'ok'; fileName: string; sheetName: string; sheetNames: string[]; result: ParseResult };

/**
 * Webとネイティブでファイルの読み方が違うため、ここで吸収する。
 * Web: blob URLをfetchしてArrayBufferにする
 * ネイティブ: expo-file-systemでbase64として読む
 */
async function readWorkbook(uri: string, file?: File): Promise<XLSX.WorkBook> {
  if (Platform.OS === 'web') {
    // Webでは File オブジェクトが取れることが多いので、あればそれを優先する
    const buffer = file
      ? await file.arrayBuffer()
      : await (await fetch(uri)).arrayBuffer();
    return XLSX.read(buffer, { type: 'array' });
  }

  const base64 = await FileSystem.readAsStringAsync(uri, {
    encoding: FileSystem.EncodingType.Base64,
  });
  return XLSX.read(base64, { type: 'base64' });
}

/**
 * ファイル選択ダイアログを開き、選ばれたExcel/CSVを単語カードに変換する。
 * 読み込むのは最初のシート。
 */
export async function pickAndParseExcel(): Promise<ImportOutcome> {
  let picked: DocumentPicker.DocumentPickerResult;

  try {
    picked = await DocumentPicker.getDocumentAsync({
      type: EXCEL_MIME_TYPES,
      copyToCacheDirectory: true,
      multiple: false,
    });
  } catch (e) {
    return { status: 'error', message: 'ファイル選択を開けませんでした' };
  }

  if (picked.canceled || !picked.assets?.length) {
    return { status: 'cancelled' };
  }

  const asset = picked.assets[0];

  try {
    const workbook = await readWorkbook(asset.uri, (asset as { file?: File }).file);
    const sheetNames = workbook.SheetNames;

    if (!sheetNames.length) {
      return { status: 'error', message: 'このファイルにはシートがありません' };
    }

    const sheetName = sheetNames[0];
    const sheet = workbook.Sheets[sheetName];

    // header:1 で「1行 = 配列」の素の2次元配列として取り出す
    const rows = XLSX.utils.sheet_to_json<unknown[]>(sheet, {
      header: 1,
      blankrows: false,
      defval: '',
    });

    const result = parseSheetRows(rows);

    return {
      status: 'ok',
      fileName: asset.name ?? 'unknown.xlsx',
      sheetName,
      sheetNames,
      result,
    };
  } catch (e) {
    const detail = e instanceof Error ? e.message : String(e);
    return { status: 'error', message: `ファイルを読み込めませんでした（${detail}）` };
  }
}
