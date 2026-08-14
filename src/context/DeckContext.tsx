import React, { createContext, useContext, useEffect, useState } from 'react';
import AsyncStorage from '@react-native-async-storage/async-storage';
import { CustomDeck } from '../data/deckTypes';
import { VocabCard } from '../data/types';

const STORAGE_KEY = '@deutsch_lernen_decks';

interface DeckContextValue {
  decks: CustomDeck[];
  /** 読み込みが終わるまでは true。空の状態を誤って表示しないために使う */
  loading: boolean;
  addDeck: (input: { name: string; sourceFile: string; cards: VocabCard[]; categories: string[] }) => Promise<CustomDeck>;
  removeDeck: (deckId: string) => Promise<void>;
  renameDeck: (deckId: string, name: string) => Promise<void>;
  getDeck: (deckId: string) => CustomDeck | undefined;
}

const DeckContext = createContext<DeckContextValue | null>(null);

export function DeckProvider({ children }: { children: React.ReactNode }) {
  const [decks, setDecks] = useState<CustomDeck[]>([]);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    (async () => {
      try {
        const stored = await AsyncStorage.getItem(STORAGE_KEY);
        if (stored) setDecks(JSON.parse(stored));
      } catch (_) {
        // 読み込めなくても空の状態で続行する
      } finally {
        setLoading(false);
      }
    })();
  }, []);

  const persist = async (next: CustomDeck[]) => {
    setDecks(next);
    try {
      await AsyncStorage.setItem(STORAGE_KEY, JSON.stringify(next));
    } catch (_) {
      // 保存に失敗しても画面上の状態は保つ
    }
  };

  const addDeck: DeckContextValue['addDeck'] = async ({ name, sourceFile, cards, categories }) => {
    const deck: CustomDeck = {
      id: `deck-${Date.now()}`,
      name,
      sourceFile,
      importedAt: new Date().toISOString(),
      cards,
      categories,
    };
    await persist([deck, ...decks]);
    return deck;
  };

  const removeDeck = async (deckId: string) => {
    await persist(decks.filter((d) => d.id !== deckId));
  };

  const renameDeck = async (deckId: string, name: string) => {
    await persist(decks.map((d) => (d.id === deckId ? { ...d, name } : d)));
  };

  const getDeck = (deckId: string) => decks.find((d) => d.id === deckId);

  return (
    <DeckContext.Provider value={{ decks, loading, addDeck, removeDeck, renameDeck, getDeck }}>
      {children}
    </DeckContext.Provider>
  );
}

export function useDecks() {
  const ctx = useContext(DeckContext);
  if (!ctx) throw new Error('useDecks must be used within DeckProvider');
  return ctx;
}
