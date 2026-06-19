import { StatusBar } from 'expo-status-bar';
import { ProgressProvider } from './src/context/ProgressContext';
import AppNavigator from './src/navigation/AppNavigator';

export default function App() {
  return (
    <ProgressProvider>
      <AppNavigator />
      <StatusBar style="auto" />
    </ProgressProvider>
  );
}
