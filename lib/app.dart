import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:genui/genui.dart';
import 'package:genui_firebase_ai/genui_firebase_ai.dart';
import 'package:json_schema_builder/json_schema_builder.dart' as dsb;
import 'core/theme/app_theme.dart';
import 'core/constants/app_constants.dart';
import 'features/expenses/services/expense_service.dart';
import 'features/background/services/imagen_service.dart';
import 'features/chat/services/chat_service.dart';
import 'features/chat/services/live_chat_service.dart';
import 'features/chat/services/audio_service.dart';
import 'genui/catalog/catalog_items.dart';
import 'genui/surfaces/surface_manager.dart';
import 'screens/home_screen.dart';

class ExpenseTrackerApp extends StatefulWidget {
  const ExpenseTrackerApp({super.key});

  @override
  State<ExpenseTrackerApp> createState() => _ExpenseTrackerAppState();
}

// Global reference to GenUI conversation for catalog items to access
GenUiConversation? globalGenUiConversation;

// Global reference to SurfaceManager for catalog items to access
SurfaceManager? globalSurfaceManager;

// Global reference to ExpenseService for tools to access
ExpenseService? globalExpenseService;

// Global reference to ImagenService for tools to access
ImagenService? globalImagenService;

class _ExpenseTrackerAppState extends State<ExpenseTrackerApp> {
  late final SurfaceManager _surfaceManager;
  late final ExpenseService _expenseService;
  late final ImagenService _imagenService;
  late final GenUiManager _genUiManager;
  late final GenUiConversation _genUiConversation;
  late final ChatService _chatService;

  // Voice services - lazy initialized only when needed
  LiveChatService? _liveChatService;
  AudioService? _audioService;

  final _scaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();

  @override
  void initState() {
    super.initState();
    _initializeServices();
  }

  void _initializeServices() {
    // Initialize services
    _surfaceManager = SurfaceManager();
    globalSurfaceManager = _surfaceManager; // Set global reference
    _expenseService = ExpenseService();
    globalExpenseService = _expenseService; // Set global reference
    _imagenService = ImagenService();
    globalImagenService = _imagenService; // Set global reference

    // Create GenUI catalog
    final catalog = createCatalog();

    // Create GenUI manager
    _genUiManager = GenUiManager(catalog: catalog);

    // Create expense management tools for GenUI
    final expenseTools = _createExpenseTools();

    // Create background generation tools for GenUI
    final backgroundTools = _createBackgroundTools();

    // Create Firebase AI content generator using genui_firebase_ai package
    final contentGenerator = FirebaseAiContentGenerator(
      catalog: catalog,
      systemInstruction: _getSystemInstruction(),
      additionalTools: [...expenseTools, ...backgroundTools],
    );

    // Create GenUI conversation
    _genUiConversation = GenUiConversation(
      genUiManager: _genUiManager,
      contentGenerator: contentGenerator,
      onSurfaceAdded: _handleSurfaceAdded,
      onSurfaceUpdated: _handleSurfaceUpdated,
      onSurfaceDeleted: _handleSurfaceRemoved,
      onTextResponse: _handleTextResponse,
      onError: _handleError,
    );

    // Set global reference for catalog items to access
    globalGenUiConversation = _genUiConversation;

    // Create chat service and initialize with GenUI conversation
    _chatService = ChatService();
    _chatService.initialize(_genUiConversation);

    // Voice chat services are lazy-initialized only when user opens voice mode
    // This significantly improves app startup time
  }

  /// Lazy getter for LiveChatService - only created when needed
  LiveChatService get liveChatService {
    _liveChatService ??= LiveChatService();
    return _liveChatService!;
  }

  /// Lazy getter for AudioService - only created when needed
  AudioService get audioService {
    _audioService ??= AudioService();
    return _audioService!;
  }

  String _getSystemInstruction() {
    return '''
You are an expense tracking assistant. You help users manage their expenses through natural conversation.

Your capabilities:
1. Add expenses: When users say something like "Coffee \$5", create a new expense
2. Manage categories: Automatically create categories if they don't exist
3. Change category colors: When users ask to change a category color, use the updateCategoryColor tool
4. Show charts: Display pie, bar, or line charts of expense data
5. Show totals: Display total expenses with labels
6. Change backgrounds: Generate themed backgrounds

UI Surfaces:
- background: Full-screen background image
- chart: Single chart slot (pie, bar, or line)
- total: Total widget showing sum with label
- categories: Kanban columns for expense categories
- dialog: Confirmation dialogs for text mode

Rules:
- For TEXT mode: Always show a ConfirmationDialog before adding expenses or making changes
- For VOICE mode: Perform actions immediately and confirm verbally
- Only show ONE chart at a time in the chart slot
- Automatically create categories if they don't exist
- Use 10% opacity background tint for category columns
- When switching chart types, use the same data but different visualization

Category Management:
- Infer category from context (e.g., "coffee" → "Food & Drink", "uber" → "Travel")
- Default categories: Food & Drink, Travel, Work, Entertainment, Shopping, Health, Other
- Create new categories when explicitly requested

Example Interactions:
- "Add coffee \$5" → Create expense in Food & Drink category
- "Show me a pie chart" → Display CategoryColumn data as pie chart
- "Change Travel to purple" → Update Travel category color to purple
- "Show total this week" → Display TotalWidget with current sum and "this week" label
- "Beach background" → Generate beach-themed background image

Always be helpful, conversational, and efficient!

CRITICAL WORKFLOW:
1. When user confirms an action (clicks "Yes"), call the appropriate tool (addExpense, addCategory, etc.)
2. IMMEDIATELY after calling addExpense or addCategory, you MUST call getAllExpenses to get the updated data
3. Then update the UI surfaces (especially the "categories" surface) with CategoryColumn widgets showing the updated expense data from getAllExpenses
4. Each CategoryColumn must include ALL expenses for that category from the getAllExpenses result
5. ALWAYS include the 'date' field for every expense - dates are displayed on expense cards

Example: After addExpense succeeds, call getAllExpenses, then update the "categories" surface with CategoryColumn widgets containing the complete expense lists including dates.

Background Management:
- When user requests a background change, call generateBackground tool
- After generateBackground succeeds, update the "background" surface with a BackgroundImage widget
- BackgroundImage widget requires: imageUrl (string) and description (string)
''';
  }

  List<AiTool> _createExpenseTools() {
    return [
      DynamicAiTool<JsonMap>(
        name: 'addExpense',
        description:
            'Adds a new expense to a category. Use this when the user confirms adding an expense. CRITICAL: After calling this tool, you MUST immediately call getAllExpenses, then update the "categories" surface with CategoryColumn widgets containing ALL expenses from getAllExpenses result.',
        parameters: dsb.S.object(
          properties: {
            'title': dsb.S
                .string(description: 'The title/description of the expense'),
            'amount': dsb.S
                .number(description: 'The amount of the expense as a number'),
            'categoryId': dsb.S.string(
                description: 'The ID of the category to add the expense to'),
          },
          required: ['title', 'amount', 'categoryId'],
        ),
        invokeFunction: (args) async {
          final expenseService = globalExpenseService;
          if (expenseService == null) {
            return {'error': 'ExpenseService not available'};
          }

          final title = args['title'] as String;
          final amount = (args['amount'] as num).toDouble();
          final categoryId = args['categoryId'] as String;

          final expense = expenseService.addExpense(title, amount, categoryId);

          // Get updated category info
          final category = expenseService.categories.firstWhere(
            (c) => c.id == categoryId,
            orElse: () => throw Exception('Category not found'),
          );

          return {
            'success': true,
            'expenseId': expense.id,
            'categoryId': categoryId,
            'categoryName': category.name,
            'message':
                'Expense added successfully. You MUST now call getAllExpenses and update the UI surfaces.',
          };
        },
      ),
      DynamicAiTool<JsonMap>(
        name: 'addCategory',
        description:
            'Adds a new expense category. Use this when a category needs to be created.',
        parameters: dsb.S.object(
          properties: {
            'name': dsb.S.string(
                description:
                    'The name of the category (e.g., "Food & Drink", "Travel")'),
            'color': dsb.S.string(
                description:
                    'Hex color code (e.g., "#FF5733") or named color (e.g., "purple")'),
          },
          required: ['name', 'color'],
        ),
        invokeFunction: (args) async {
          final expenseService = globalExpenseService;
          if (expenseService == null) {
            return {'error': 'ExpenseService not available'};
          }

          final name = args['name'] as String;
          final color = args['color'] as String;

          final category = expenseService.addCategory(name, color);

          return {
            'success': true,
            'categoryId': category.id,
            'categoryName': category.name,
            'message':
                'Category created successfully. Call getAllExpenses and update the categories surface.',
          };
        },
      ),
      DynamicAiTool<JsonMap>(
        name: 'updateCategoryColor',
        description:
            'Updates the color of an existing category. Use this when the user wants to change a category color. After calling this, you MUST call getAllExpenses and update the categories surface.',
        parameters: dsb.S.object(
          properties: {
            'categoryId':
                dsb.S.string(description: 'The ID of the category to update'),
            'color': dsb.S.string(
                description:
                    'New hex color code (e.g., "#FF5733") or named color (e.g., "red", "purple")'),
          },
          required: ['categoryId', 'color'],
        ),
        invokeFunction: (args) async {
          final expenseService = globalExpenseService;
          if (expenseService == null) {
            return {'error': 'ExpenseService not available'};
          }

          final categoryId = args['categoryId'] as String;
          final color = args['color'] as String;

          expenseService.updateCategoryColor(categoryId, color);

          return {
            'success': true,
            'categoryId': categoryId,
            'newColor': color,
            'message':
                'Category color updated. Call getAllExpenses and update the categories surface to reflect the change.',
          };
        },
      ),
      DynamicAiTool<JsonMap>(
        name: 'getAllExpenses',
        description:
            'Gets all expenses organized by category. Use this to get current expense data for displaying in UI.',
        parameters: dsb.S.object(
          properties: {},
          required: [],
        ),
        invokeFunction: (args) async {
          final expenseService = globalExpenseService;
          if (expenseService == null) {
            return {'error': 'ExpenseService not available'};
          }

          final categories = expenseService.categories;
          final expenses = expenseService.expenses;

          final result = <String, dynamic>{
            'categories': categories
                .map((cat) => {
                      'id': cat.id,
                      'name': cat.name,
                      'color': _colorToHex(cat.color),
                      'expenses': expenses
                          .where((e) => e.categoryId == cat.id)
                          .map((e) => {
                                'id': e.id,
                                'title': e.title,
                                'amount': e.amount,
                                'date': e.date.toIso8601String(),
                              })
                          .toList(),
                    })
                .toList(),
            'total': expenseService.totalExpenses,
          };

          return result;
        },
      ),
      DynamicAiTool<JsonMap>(
        name: 'findCategoryByName',
        description:
            'Finds a category by its name (case insensitive). Returns null if not found.',
        parameters: dsb.S.object(
          properties: {
            'name':
                dsb.S.string(description: 'The name of the category to find'),
          },
          required: ['name'],
        ),
        invokeFunction: (args) async {
          final expenseService = globalExpenseService;
          if (expenseService == null) {
            return {'error': 'ExpenseService not available'};
          }

          final name = args['name'] as String;
          final category = expenseService.findCategoryByName(name);

          if (category == null) {
            return {'found': false};
          }

          return {
            'found': true,
            'categoryId': category.id,
            'categoryName': category.name,
            'color': _colorToHex(category.color),
          };
        },
      ),
    ];
  }

  List<AiTool> _createBackgroundTools() {
    return [
      DynamicAiTool<JsonMap>(
        name: 'generateBackground',
        description:
            'Generates a background image based on a description/prompt. After calling this, you MUST update the "background" surface with a BackgroundImage widget containing the imageUrl and description.',
        parameters: dsb.S.object(
          properties: {
            'prompt': dsb.S.string(
                description:
                    'Description of the desired background (e.g., "ocean flowing", "beach sunset", "minimal gradient")'),
          },
          required: ['prompt'],
        ),
        invokeFunction: (args) async {
          final imagenService = globalImagenService;
          if (imagenService == null) {
            return {'error': 'ImagenService not available'};
          }

          final prompt = args['prompt'] as String;
          await imagenService.generateBackground(prompt);

          // Note: Since actual image generation isn't implemented, we'll return null for imageUrl
          // This will make BackgroundImageWidget show a gradient based on the description
          // In a real app, you'd get the actual image URL from the Imagen API
          final description = imagenService.currentDescription ?? prompt;

          // For now, return null imageUrl so the widget shows a gradient
          // GenUI should still update the background surface with the description

          return {
            'success': true,
            'imageUrl': null, // Will show gradient fallback
            'description': description,
            'message':
                'Background generated. You MUST now update the "background" surface with a BackgroundImage widget containing imageUrl: null and description: "$description".',
          };
        },
      ),
    ];
  }

  String _colorToHex(Color color) {
    final value = color.value; // Using value for hex conversion
    final hex = value.toRadixString(16).substring(2).toUpperCase();
    return '#$hex';
  }

  void _handleSurfaceAdded(SurfaceAdded update) {
    final surfaceId = update.surfaceId;
    final definition = update.definition;

    setState(() {
      switch (surfaceId) {
        case AppConstants.surfaceBackground:
          _surfaceManager.setBackground(
            GenUiSurface(
              host: _genUiManager,
              surfaceId: surfaceId,
            ),
          );
          break;
        case AppConstants.surfaceChart:
          _surfaceManager.setChart(
            GenUiSurface(
              host: _genUiManager,
              surfaceId: surfaceId,
            ),
          );
          break;
        case AppConstants.surfaceTotal:
          _surfaceManager.setTotal(
            GenUiSurface(
              host: _genUiManager,
              surfaceId: surfaceId,
            ),
          );
          break;
        case AppConstants.surfaceCategories:
          // Clear existing categories first to prevent duplicates
          _surfaceManager.clearCategories();
          // Then add the new category
          if (definition.rootComponentId != null) {
            _surfaceManager.addCategory(
              GenUiSurface(
                host: _genUiManager,
                surfaceId: surfaceId,
              ),
            );
          }
          break;
        case AppConstants.surfaceDialog:
          _surfaceManager.setDialog(
            GenUiSurface(
              host: _genUiManager,
              surfaceId: surfaceId,
            ),
          );
          break;
      }
    });
  }

  void _handleSurfaceUpdated(SurfaceUpdated update) {
    final surfaceId = update.surfaceId;
    final definition = update.definition;

    setState(() {
      switch (surfaceId) {
        case AppConstants.surfaceBackground:
          _surfaceManager.setBackground(
            GenUiSurface(
              host: _genUiManager,
              surfaceId: surfaceId,
            ),
          );
          break;
        case AppConstants.surfaceChart:
          _surfaceManager.setChart(
            GenUiSurface(
              host: _genUiManager,
              surfaceId: surfaceId,
            ),
          );
          break;
        case AppConstants.surfaceTotal:
          _surfaceManager.setTotal(
            GenUiSurface(
              host: _genUiManager,
              surfaceId: surfaceId,
            ),
          );
          break;
        case AppConstants.surfaceCategories:
          // Update categories - rebuild all
          _surfaceManager.clearCategories();
          if (definition.rootComponentId != null) {
            _surfaceManager.addCategory(
              GenUiSurface(
                host: _genUiManager,
                surfaceId: surfaceId,
              ),
            );
          }
          break;
        case AppConstants.surfaceDialog:
          _surfaceManager.setDialog(
            GenUiSurface(
              host: _genUiManager,
              surfaceId: surfaceId,
            ),
          );
          break;
      }
    });
  }

  void _handleSurfaceRemoved(SurfaceRemoved update) {
    final surfaceId = update.surfaceId;

    setState(() {
      switch (surfaceId) {
        case AppConstants.surfaceBackground:
          _surfaceManager.setBackground(null);
          break;
        case AppConstants.surfaceChart:
          _surfaceManager.setChart(null);
          break;
        case AppConstants.surfaceTotal:
          _surfaceManager.setTotal(null);
          break;
        case AppConstants.surfaceCategories:
          _surfaceManager.clearCategories();
          break;
        case AppConstants.surfaceDialog:
          _surfaceManager.clearDialog();
          break;
      }
    });
  }

  void _handleTextResponse(String text) {
    // Text responses are handled by the chat service
    debugPrint('AI response: $text');
  }

  void _handleError(ContentGeneratorError error) {
    // Only log in debug mode to reduce console noise
    if (kDebugMode) {
      final errorStr = error.error.toString();
      // Skip logging network permission errors (already handled gracefully)
      if (!errorStr.contains('Operation not permitted') &&
          !errorStr.contains('Connection failed')) {
        debugPrint('GenUI error: ${error.error}');
      }
    }

    // Show snackbar only for non-network errors (network errors are already shown in chat)
    final errorStr = error.error.toString();
    if (!errorStr.contains('Operation not permitted') &&
        !errorStr.contains('Connection failed') &&
        !errorStr.contains('SocketException')) {
      _scaffoldMessengerKey.currentState?.showSnackBar(
        SnackBar(
          content: Text('Error: ${error.error.toString()}'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }

  @override
  void dispose() {
    _chatService.dispose();
    _liveChatService?.dispose();
    _audioService?.dispose();
    _expenseService.dispose();
    _imagenService.dispose();
    _surfaceManager.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: AppConstants.appName,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.system,
      debugShowCheckedModeBanner: false,
      scaffoldMessengerKey: _scaffoldMessengerKey,
      home: HomeScreen(
        surfaceManager: _surfaceManager,
        chatService: _chatService,
        // Pass lazy getters - services only created when accessed
        liveChatServiceGetter: () => liveChatService,
        audioServiceGetter: () => audioService,
      ),
    );
  }
}
