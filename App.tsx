import { StatusBar } from 'expo-status-bar';
import { ProgressProvider } from './src/context/ProgressContext';
import { DeckProvider } from './src/context/DeckContext';
import AppNavigator from './src/navigation/AppNavigator';

export default function App() {
  return (
    <ProgressProvider>
      <DeckProvider>
        <AppNavigator />
        <StatusBar style="auto" />
      </DeckProvider>
    </ProgressProvider>
  );
}
