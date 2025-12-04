# Building AI-Powered Dynamic UIs with Flutter, GenUI & Firebase

> **Techsgiving Demo** — A comprehensive showcase of agentic AI capabilities in Flutter

[![Flutter](https://img.shields.io/badge/Flutter-3.5+-02569B?logo=flutter)](https://flutter.dev)
[![Firebase AI](https://img.shields.io/badge/Firebase%20AI-Gemini-FFCA28?logo=firebase)](https://firebase.google.com/docs/vertex-ai)
[![GenUI](https://img.shields.io/badge/GenUI-0.5.1-purple)](https://pub.dev/packages/genui)
[![Platform](https://img.shields.io/badge/Platform-iOS%20%7C%20Android%20%7C%20Web%20%7C%20Desktop-blue)]()

## Table of Contents

1. [Overview](#-overview)
2. [Key Innovations](#-key-innovations)
3. [Live Demo](#-live-demo)
4. [Architecture Deep Dive](#-architecture-deep-dive)
5. [GenUI: Dynamic UI Generation](#-genui-dynamic-ui-generation)
6. [AI Tool Calling](#-ai-tool-calling)
7. [Voice Chat with Gemini Live API](#-voice-chat-with-gemini-live-api)
8. [Custom Chatbot Implementation](#-custom-chatbot-implementation)
9. [Surface Management](#-surface-management)
10. [Performance Optimizations](#-performance-optimizations)
11. [Getting Started](#-getting-started)
12. [Key Takeaways](#-key-takeaways)

## Overview

This project demonstrates the future of AI-powered Flutter applications by combining:

| Technology | Purpose |
|------------|---------|
| **GenUI** | AI-generated dynamic UI components |
| **Firebase AI (Gemini)** | Natural language understanding & generation |
| **Gemini Live API** | Real-time voice conversations |
| **Function Calling** | Bidirectional AI-app communication |
| **Surface Management** | Declarative UI slot system |

### What We Built

An **expense tracker** where the entire UI is generated through natural conversation:

```
User: "Add coffee $5"
AI:   [Creates Food & Drink category] → [Shows confirmation dialog] → [Adds expense card]
      [Updates pie chart] → "Added $5 coffee to Food & Drink ☕"
```

**No hardcoded UI for data display** — the AI decides what widgets to show and where.

## Key Innovations

### 1. Agentic UI Generation
The AI doesn't just respond with text — it **takes actions** and **modifies the UI**:

```dart
// AI can call tools to modify app state
DynamicAiTool<JsonMap>(
  name: 'addExpense',
  description: 'Adds a new expense to a category',
  parameters: S.object(properties: {
    'title': S.string(),
    'amount': S.number(),
    'categoryId': S.string(),
  }),
  invokeFunction: (args) async {
    final expense = expenseService.addExpense(
      args['title'], args['amount'], args['categoryId']
    );
    return {'success': true, 'expenseId': expense.id};
  },
);
```

### 2. Bidirectional Communication
- **User → AI**: Natural language requests
- **AI → App**: Function calls to modify state
- **App → AI**: UI interactions sent back as context
- **AI → UI**: Generated widget definitions

### 3. Multi-Modal Interaction
Switch seamlessly between:
- ⌨️ **Text Chat** — Traditional message input
- 🎙️ **Voice Chat** — Real-time audio with Gemini Live API
- 👆 **UI Actions** — Button clicks, dialog confirmations

### 4. Lazy Service Initialization
Voice services load **only when needed**, keeping app startup fast:

```dart
// Services initialized on-demand, not at startup
LiveChatService get liveChatService {
  _liveChatService ??= LiveChatService();
  return _liveChatService!;
}
```

## Live Demo

### Quick Start Commands

```bash
# Clone and run
git clone <repo-url>
cd techsgiving_demo
flutter pub get

# Run on different platforms
flutter run -d macos     # Desktop
flutter run -d chrome    # Web  
flutter run              # Mobile
```

### Demo Flow

| Step | User Says | AI Response |
|------|-----------|-------------|
| 1 | "Add coffee $5" | Creates Food & Drink → Shows dialog → Adds expense |
| 2 | "Add lunch $15" | Adds to existing Food & Drink category |
| 3 | "Add Uber $23 under Travel" | Creates Travel category → Adds expense |
| 4 | "Change Travel to purple" | Updates category color |
| 5 | "Show me a pie chart" | Renders pie chart in chart slot |
| 6 | "Switch to bar chart" | Swaps visualization |
| 7 | "Beach vibes background" | Updates background imagery |
| 8 | 🎙️ *Voice:* "Coffee ten dollars" | Voice input → Processing → Audio response |

## Architecture Deep Dive

### Project Structure

```
lib/
├── app.dart                           # 🎯 Main orchestration
│   ├── GenUiManager                   # Widget catalog management
│   ├── GenUiConversation              # AI conversation handler
│   ├── ExpenseTools                   # Function calling definitions
│   └── SurfaceCallbacks               # UI update handlers
│
├── features/
│   ├── chat/
│   │   ├── services/
│   │   │   ├── chat_service.dart      # 💬 Text chat management
│   │   │   ├── live_chat_service.dart # 🎙️ Gemini Live API
│   │   │   └── audio_service.dart     # 🔊 Recording & playback
│   │   └── widgets/
│   │       ├── chat_view.dart         # Chat UI
│   │       ├── voice_chat_widget.dart # Voice interface
│   │       └── floating_chat_widget.dart
│   │
│   ├── expenses/
│   │   ├── models/                    # Expense & Category
│   │   ├── services/expense_service.dart
│   │   └── widgets/                   # Card & Column widgets
│   │
│   └── charts/                        # Dynamic chart rendering
│
├── genui/
│   ├── catalog/                       # 🎨 Widget definitions
│   │   ├── category_column_item.dart
│   │   ├── expense_card_item.dart
│   │   ├── chart_widget_item.dart
│   │   ├── total_widget_item.dart
│   │   ├── confirmation_dialog_item.dart
│   │   └── background_image_item.dart
│   │
│   └── surfaces/
│       └── surface_manager.dart       # 📍 Slot management
│
└── screens/
    └── home_screen.dart               # Responsive layout
```

### Data Flow

```
┌─────────────────────────────────────────────────────────────────┐
│                        USER INTERACTION                          │
│                    (Text / Voice / UI Click)                     │
└────────────────────────────┬────────────────────────────────────┘
                             │
                             ▼
┌─────────────────────────────────────────────────────────────────┐
│                      CHAT SERVICE                                │
│         ┌─────────────┐         ┌──────────────────┐            │
│         │ ChatService │◄───────►│ LiveChatService  │            │
│         │   (Text)    │         │    (Voice)       │            │
│         └──────┬──────┘         └────────┬─────────┘            │
└────────────────┼────────────────────────┼───────────────────────┘
                 │                        │
                 ▼                        ▼
┌─────────────────────────────────────────────────────────────────┐
│                    GenUiConversation                             │
│  ┌────────────────┐  ┌───────────────┐  ┌────────────────────┐  │
│  │ ContentGenerator├─►│   Gemini AI   ├─►│ Function Calling   │  │
│  │  (Firebase AI)  │  │               │  │  (Tools)           │  │
│  └────────────────┘  └───────────────┘  └─────────┬──────────┘  │
└───────────────────────────────────────────────────┼─────────────┘
                                                    │
                 ┌──────────────────────────────────┘
                 │
                 ▼
┌─────────────────────────────────────────────────────────────────┐
│                    SERVICE LAYER                                 │
│  ┌────────────────┐  ┌────────────────┐  ┌────────────────────┐ │
│  │ ExpenseService │  │ ImagenService  │  │   SurfaceManager   │ │
│  │  (CRUD ops)    │  │  (Backgrounds) │  │   (UI Slots)       │ │
│  └────────────────┘  └────────────────┘  └────────────────────┘ │
└─────────────────────────────────────────────────────────────────┘
                                                    │
                                                    ▼
┌─────────────────────────────────────────────────────────────────┐
│                      GenUI CATALOG                               │
│  ┌──────────────┐ ┌─────────────┐ ┌────────────┐ ┌───────────┐  │
│  │CategoryColumn│ │ ExpenseCard │ │ ChartWidget│ │TotalWidget│  │
│  └──────────────┘ └─────────────┘ └────────────┘ └───────────┘  │
│  ┌──────────────────┐ ┌─────────────────────┐                   │
│  │ConfirmationDialog│ │   BackgroundImage   │                   │
│  └──────────────────┘ └─────────────────────┘                   │
└─────────────────────────────────────────────────────────────────┘
                                                    │
                                                    ▼
┌─────────────────────────────────────────────────────────────────┐
│                     FLUTTER UI                                   │
│            HomeScreen → Surfaces → Rendered Widgets              │
└─────────────────────────────────────────────────────────────────┘
```

## GenUI: Dynamic UI Generation

### What is GenUI?

GenUI is a framework that allows **AI to generate Flutter widgets** through structured data:

```dart
// 1. Define a widget in the catalog
final categoryColumnItem = CatalogItem(
  name: 'CategoryColumn',
  dataSchema: S.object(
    properties: {
      'id': S.string(description: 'Category ID'),
      'name': S.string(description: 'Category name'),
      'color': S.string(description: 'Hex color code'),
      'expenses': S.array(items: S.object(...)),
    },
    required: ['id', 'name', 'color', 'expenses'],
  ),
  widgetBuilder: (context) {
    final data = context.data as Map<String, dynamic>;
    return CategoryColumnWidget(
      id: data['id'],
      name: data['name'],
      color: _parseColor(data['color']),
      expenses: _parseExpenses(data['expenses']),
    );
  },
);

// 2. AI generates JSON matching the schema
{
  "component": "CategoryColumn",
  "data": {
    "id": "cat_001",
    "name": "Food & Drink",
    "color": "#4CAF50",
    "expenses": [
      {"title": "Coffee", "amount": 5.0, "date": "2024-12-03"}
    ]
  }
}

// 3. GenUI renders the Flutter widget automatically
```

### Catalog Items

| Component | Purpose | Data Schema |
|-----------|---------|-------------|
| `CategoryColumn` | Kanban column for a category | id, name, color, expenses[] |
| `ExpenseCard` | Individual expense display | title, amount, date, categoryName |
| `ChartWidget` | Pie/Bar/Line charts | type, data[], colors[] |
| `TotalWidget` | Sum display | amount, label, icon |
| `ConfirmationDialog` | User confirmations | title, message, confirmText |
| `BackgroundImage` | Full-screen backgrounds | imageUrl, description |

---

## AI Tool Calling

### How It Works

The AI can call functions defined in Flutter to **modify app state**:

```dart
// Define a tool
DynamicAiTool<JsonMap>(
  name: 'addExpense',
  description: 'Adds a new expense. After calling, update the UI.',
  parameters: S.object(
    properties: {
      'title': S.string(),
      'amount': S.number(),
      'categoryId': S.string(),
    },
  ),
  invokeFunction: (args) async {
    // Called by AI when user says "Add coffee $5"
    final expense = expenseService.addExpense(...);
    return {'success': true, 'expenseId': expense.id};
  },
);
```

### Available Tools

| Tool | Trigger Example | Action |
|------|-----------------|--------|
| `addExpense` | "Add coffee $5" | Creates expense in category |
| `addCategory` | "Create Travel category" | Creates new category |
| `getAllExpenses` | Internal refresh | Returns all expenses |
| `findCategoryByName` | "Add to Food" | Finds matching category |
| `updateCategoryColor` | "Change Travel to purple" | Updates category color |
| `generateBackground` | "Beach vibes" | Updates background |

### Tool → UI Flow

```
User: "Add coffee $5 to Food"
         │
         ▼
AI analyzes request
         │
         ▼
AI calls: findCategoryByName("Food")
         │
         ▼
Returns: {categoryId: "cat_001", name: "Food & Drink"}
         │
         ▼
AI calls: addExpense(title: "Coffee", amount: 5, categoryId: "cat_001")
         │
         ▼
Returns: {success: true, expenseId: "exp_123"}
         │
         ▼
AI calls: getAllExpenses()
         │
         ▼
AI generates: CategoryColumn with updated expenses
         │
         ▼
Surface updated → UI re-renders
```

---

## Voice Chat with Gemini Live API

### Real-Time Audio Processing

```dart
class LiveChatService extends ChangeNotifier {
  // Connect to Gemini Live API
  Future<void> connect({String? systemInstruction}) async {
    _liveModel = FirebaseAI.googleAI().liveGenerativeModel(
      model: 'gemini-2.0-flash-exp',
      liveGenerationConfig: LiveGenerationConfig(
        responseModalities: [ResponseModalities.audio, ResponseModalities.text],
        speechConfig: SpeechConfig(voiceName: _selectedVoice.name),
      ),
      systemInstruction: Content.text(systemInstruction ?? ''),
    );
    
    _session = await _liveModel!.connect();
    _startListeningForResponses();
  }

  // Send audio to AI
  Future<void> sendAudio(Uint8List audioData) async {
    await _session?.sendMediaChunks([
      MediaChunks(data: audioData, mimeType: 'audio/pcm'),
    ]);
  }
}
```

### Voice Personas

| Voice | Description |
|-------|-------------|
| **Aoede** | Warm and clear |
| **Charon** | Deep and resonant |
| **Fenrir** | Strong and bold |
| **Kore** | Soft and gentle |
| **Puck** | Playful and energetic |

### Audio Service

Handles microphone recording and AI audio playback:

```dart
class AudioService extends ChangeNotifier {
  final AudioRecorder _recorder = AudioRecorder();
  SoLoud? _soloud;  // Low-latency audio engine
  
  // Record at 16kHz mono (Gemini requirement)
  Future<void> startRecording() async {
    final stream = await _recorder.startStream(RecordConfig(
      encoder: AudioEncoder.pcm16bits,
      sampleRate: 16000,
      numChannels: 1,
    ));
    stream.listen((data) => _audioStreamController.add(data));
  }
  
  // Play AI responses (24kHz from Gemini)
  Future<void> playAudio(Uint8List audioData) async {
    final wavData = _createWavFromPcm(audioData, 24000, 1, 16);
    final source = await _soloud!.loadMem('response.wav', wavData);
    await _soloud!.play(source);
  }
}
```

---

## Custom Chatbot Implementation

### Why Custom Instead of flutter_ai_toolkit?

We built a custom chat system for:
- **Full control** over message handling
- **GenUI integration** with surface updates  
- **Voice mode switching** with shared context
- **Tool calling visibility** in the UI

### ChatService Architecture

```dart
class ChatService extends ChangeNotifier {
  final List<ChatMessage> _messages = [];
  GenUiConversation? _conversation;
  
  void initialize(GenUiConversation conversation) {
    _conversation = conversation;
    
    // Listen for AI text responses
    conversation.contentGenerator.textResponseStream.listen((text) {
      _addAIMessage(text);
    });
    
    // Listen for errors
    conversation.contentGenerator.errorStream.listen((error) {
      _showError(error);
    });
  }
  
  // Send user message
  Future<void> sendMessage(String text) async {
    _addUserMessage(text);
    _setTyping(true);
    
    await _conversation?.sendRequest(UserMessage.text(text));
    
    _setTyping(false);
  }
}
```

### Mode Switching

```dart
enum ChatMode { text, voice }

class ChatView extends StatefulWidget {
  // ...
}

class _ChatViewState extends State<ChatView> {
  ChatMode _currentMode = ChatMode.text;
  
  void _toggleMode() async {
    if (_currentMode == ChatMode.text) {
      // Switch to voice - initialize services lazily
      _liveChatService ??= widget.getLiveChatService!();
      _audioService ??= widget.getAudioService!();
      await _audioService!.initialize();
      await _liveChatService!.connect();
      
      setState(() => _currentMode = ChatMode.voice);
    } else {
      // Switch to text
      await _liveChatService?.disconnect();
      setState(() => _currentMode = ChatMode.text);
    }
  }
}
```

## Surface Management

### Concept

Surfaces are **named slots** where GenUI places widgets:

```dart
// Define surface IDs
class AppConstants {
  static const surfaceBackground = 'background';
  static const surfaceChart = 'chart';
  static const surfaceTotal = 'total';
  static const surfaceCategories = 'categories';
  static const surfaceDialog = 'dialog';
}
```

### SurfaceManager

```dart
class SurfaceManager extends ChangeNotifier {
  Widget? _backgroundWidget;
  Widget? _chartWidget;
  Widget? _totalWidget;
  final List<Widget> _categoryWidgets = [];
  Widget? _dialogWidget;
  
  void setBackground(Widget widget) {
    _backgroundWidget = widget;
    notifyListeners();
  }
  
  void addCategory(Widget widget) {
    _categoryWidgets.add(widget);
    notifyListeners();
  }
  
  void clearCategories() {
    _categoryWidgets.clear();
    notifyListeners();
  }
  
  void showDialog(Widget dialog) {
    _dialogWidget = dialog;
    notifyListeners();
  }
  
  void clearDialog() {
    _dialogWidget = null;
    notifyListeners();
  }
}
```

### UI Integration

```dart
// In HomeScreen
Widget build(BuildContext context) {
  return ListenableBuilder(
    listenable: widget.surfaceManager,
    builder: (context, _) {
      return Stack(
        children: [
          // Background layer
          if (widget.surfaceManager.backgroundWidget != null)
            widget.surfaceManager.backgroundWidget!,
          
          // Content layer
          Column(
            children: [
              // Chart + Total row
              Row(children: [
                widget.surfaceManager.chartWidget ?? Container(),
                widget.surfaceManager.totalWidget ?? Container(),
              ]),
              
              // Categories
              Expanded(
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: widget.surfaceManager.categoryWidgets,
                ),
              ),
            ],
          ),
          
          // Dialog overlay
          if (widget.surfaceManager.dialogWidget != null)
            _buildDialogOverlay(),
        ],
      );
    },
  );
}
```

## Performance Optimizations

### 1. Lazy Service Initialization

Voice services only load when needed:

```dart
// ❌ Before: All services loaded at startup (slow)
@override
void initState() {
  _liveChatService = LiveChatService();  // Heavy!
  _audioService = AudioService();         // Heavy!
}

// ✅ After: Lazy loading (fast startup)
LiveChatService? _liveChatService;
AudioService? _audioService;

LiveChatService get liveChatService {
  _liveChatService ??= LiveChatService();
  return _liveChatService!;
}
```

**Result**: Chat window opens instantly instead of 5+ second delay.

### 2. Prevent Reconnection Loops

Handle Live API errors gracefully:

```dart
_session!.receive().listen(
  (response) => _handleResponse(response),
  onError: (error) {
    _isConnected = false;  // Prevent reconnection loop
    notifyListeners();
  },
);
```

### 3. Error Resilience

Global error handlers prevent crashes:

```dart
void main() {
  FlutterError.onError = (details) {
    debugPrint('Flutter Error: ${details.exception}');
  };
  
  PlatformDispatcher.instance.onError = (error, stack) {
    debugPrint('Platform Error: $error');
    return true;  // Error handled
  };
  
  runApp(const ExpenseTrackerApp());
}
```

## Getting Started

### Prerequisites

- Flutter 3.5+
- Firebase project with Vertex AI enabled
- macOS/iOS: Network entitlements configured

### Installation

```bash
# 1. Clone repository
git clone <repository-url>
cd techsgiving_demo

# 2. Install dependencies
flutter pub get

# 3. Configure Firebase
# Update lib/firebase_options.dart with your config

# 4. Run
flutter run -d macos  # or chrome, ios, android
```

### macOS Network Configuration

Add to `macos/Runner/DebugProfile.entitlements` and `Release.entitlements`:

```xml
<key>com.apple.security.network.client</key>
<true/>
```

## Key Takeaways

### For Your Next Project

1. **GenUI for Dynamic Content**
   - Define widgets as data schemas
   - Let AI populate based on context
   - Great for dashboards, reports, content apps

2. **Function Calling for Actions**
   - Expose app capabilities as tools
   - AI decides when to call them
   - Return structured data for UI updates

3. **Multi-Modal Input**
   - Text + Voice + Touch
   - Shared context across modes
   - Lazy load heavy services

4. **Surface Architecture**
   - Named slots for widget placement
   - Single source of truth
   - Easy to reason about

### Technical Lessons

| Challenge | Solution |
|-----------|----------|
| AI toolkit limitations | Custom chat implementation |
| Slow startup | Lazy service initialization |
| Reconnection loops | Proper error handling |
| Platform permissions | Built-in package handling |
| UI state sync | Global service references + NotifyListeners |

## Dependencies

```yaml
dependencies:
  # Firebase
  firebase_ai: ^3.6.0
  firebase_core: ^4.2.1

  # GenUI
  genui: ^0.5.1
  genui_firebase_ai: ^0.5.1
  json_schema_builder: ^0.1.3

  # Charts
  fl_chart: ^1.1.1

  # Audio
  record: ^6.0.0
  flutter_soloud: ^3.1.3

  # Utils
  image_picker: ^1.2.1
  intl: ^0.20.1
```

---

## Resources

- [GenUI Package](https://pub.dev/packages/genui)
- [Firebase AI Documentation](https://firebase.google.com/docs/vertex-ai)
- [Gemini Live API](https://ai.google.dev/gemini-api/docs/live)
- [fl_chart](https://pub.dev/packages/fl_chart)

---

## License

MIT License — Feel free to use for learning and inspiration!

---

<div align="center">

**Built with ❤️ for Techsgiving**

*Demonstrating the future of AI-powered Flutter applications*

</div>
