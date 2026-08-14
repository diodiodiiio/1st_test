import React from 'react';
import { NavigationContainer } from '@react-navigation/native';
import { createBottomTabNavigator } from '@react-navigation/bottom-tabs';
import { createNativeStackNavigator } from '@react-navigation/native-stack';
import { Text } from 'react-native';
import { colors } from '../theme';
import HomeScreen from '../screens/HomeScreen';
import CurriculumScreen from '../screens/CurriculumScreen';
import LessonScreen from '../screens/LessonScreen';
import ResultScreen from '../screens/ResultScreen';
import ProfileScreen from '../screens/ProfileScreen';
import MyVocabScreen from '../screens/MyVocabScreen';
import DeckStudyScreen from '../screens/DeckStudyScreen';

export type RootStackParamList = {
  MainTabs: undefined;
  Lesson: { lessonId: string; unitId: string };
  Result: { lessonId: string; unitId: string; xpEarned: number; quizScore: number; quizTotal: number };
  DeckStudy: { deckId: string };
};

export type TabParamList = {
  Home: undefined;
  Learn: undefined;
  MyVocab: undefined;
  Profile: undefined;
};

const Stack = createNativeStackNavigator<RootStackParamList>();
const Tab = createBottomTabNavigator<TabParamList>();

function TabIcon({ name, focused }: { name: string; focused: boolean }) {
  const icons: Record<string, string> = { Home: '🏠', Learn: '📚', MyVocab: '📗', Profile: '👤' };
  return (
    <Text style={{ fontSize: focused ? 24 : 20, opacity: focused ? 1 : 0.5 }}>
      {icons[name]}
    </Text>
  );
}

function MainTabs() {
  return (
    <Tab.Navigator
      screenOptions={({ route }) => ({
        headerShown: false,
        tabBarIcon: ({ focused }) => <TabIcon name={route.name} focused={focused} />,
        tabBarActiveTintColor: colors.primary,
        tabBarInactiveTintColor: colors.text.secondary,
        tabBarStyle: {
          backgroundColor: colors.card,
          borderTopColor: colors.border,
          height: 60,
          paddingBottom: 8,
        },
        tabBarLabelStyle: { fontSize: 11 },
      })}
    >
      <Tab.Screen name="Home" component={HomeScreen} options={{ tabBarLabel: 'ホーム' }} />
      <Tab.Screen name="Learn" component={CurriculumScreen} options={{ tabBarLabel: '学習' }} />
      <Tab.Screen name="MyVocab" component={MyVocabScreen} options={{ tabBarLabel: 'My単語帳' }} />
      <Tab.Screen name="Profile" component={ProfileScreen} options={{ tabBarLabel: 'プロフィール' }} />
    </Tab.Navigator>
  );
}

export default function AppNavigator() {
  return (
    <NavigationContainer>
      <Stack.Navigator screenOptions={{ headerShown: false }}>
        <Stack.Screen name="MainTabs" component={MainTabs} />
        <Stack.Screen name="Lesson" component={LessonScreen} />
        <Stack.Screen name="Result" component={ResultScreen} />
        <Stack.Screen name="DeckStudy" component={DeckStudyScreen} />
      </Stack.Navigator>
    </NavigationContainer>
  );
}
