import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:genui/genui.dart';
import 'package:genui_firebase_ai/genui_firebase_ai.dart';
import 'package:json_schema_builder/json_schema_builder.dart' as dsb;
import 'package:firebase_ai/firebase_ai.dart';
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

// #region agent log
void _debugLog(String location, String message, Map<String, dynamic> data,
    String hypothesisId) {
  debugPrint('🔍 [$hypothesisId] $location: $message | $data');
}
// #endregion

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

  /// Convert DynamicAiTool to Firebase AI Tool format
  List<Tool> _convertToolsToFirebaseAI(List<AiTool> tools) {
    return tools.map((tool) {
      if (tool is DynamicAiTool) {
        // Convert json_schema_builder schema to Firebase AI Schema
        final schema = tool.parameters;
        final properties = <String, Schema>{};

        if (schema is dsb.ObjectSchema && schema.properties != null) {
          for (final entry in schema.properties!.entries) {
            final propSchema = entry.value;
            SchemaType? type;
            if (propSchema is dsb.StringSchema) {
              type = SchemaType.string;
            } else if (propSchema is dsb.NumberSchema) {
              type = SchemaType.number;
            } else if (propSchema is dsb.IntegerSchema) {
              type = SchemaType.integer;
            } else if (propSchema is dsb.BooleanSchema) {
              type = SchemaType.boolean;
            }

            if (type != null) {
              properties[entry.key] = Schema(
                type,
                description: propSchema.description,
              );
            }
          }
        }

        return Tool.functionDeclarations([
          FunctionDeclaration(
            tool.name,
            tool.description,
            parameters: properties,
          ),
        ]);
      }
      throw UnsupportedError('Tool type not supported: ${tool.runtimeType}');
    }).toList();
  }

  /// Lazy getter for LiveChatService - only created when needed
  LiveChatService get liveChatService {
    if (_liveChatService == null) {
      _liveChatService = LiveChatService();
      // Initialize with tools - convert to Firebase AI format
      final expenseTools = _createExpenseTools();
      final backgroundTools = _createBackgroundTools();
      final allTools = [...expenseTools, ...backgroundTools];
      final firebaseTools = _convertToolsToFirebaseAI(allTools);
      _liveChatService!.setTools(allTools, firebaseTools);
    }
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

UI Surfaces (use these surface IDs with surfaceUpdate and beginRendering):
- "background": Full-screen background image
- "chart": Single chart slot (pie, bar, or line)
- "total": Total widget showing sum with label
- "categories": Kanban columns for expense categories
- "dialog": Confirmation dialogs

HOW TO UPDATE UI SURFACES:
You MUST use the surfaceUpdate tool followed by beginRendering to display widgets.

Step 1: Call surfaceUpdate with:
  - surfaceId: the surface name (e.g., "categories")
  - components: array of component objects, each with:
    - id: unique string ID for this component
    - component: object with "name" and "data" fields

Step 2: Call beginRendering with:
  - surfaceId: same surface name
  - root: the ID of the root component to display

ADDING EXPENSES - COMPLETE WORKFLOW:

When user requests to add an expense (like "coffee \$5"):

1. Check if category exists: findCategoryByName("Food & Drink")
2. If not found, create it: addCategory("Food & Drink", "#4CAF50")
3. Add the expense ONCE: addExpense("coffee", 5.0, categoryId)
   ⚠️ CRITICAL: Call addExpense ONLY ONCE per expense. Do NOT call it multiple times.

The addExpense tool returns allCategories with ALL data. Use it to update the UI:

4. Call getAllExpenses to get ALL current categories and expenses
5. Call surfaceUpdate for "categories" surface with CategoriesContainer component:
   surfaceUpdate({
     surfaceId: "categories",
     components: [
       {
         id: "categories_root",
         component: {
           name: "CategoriesContainer",
           data: {
             categories: [
               {
                 id: "123",
                 name: "Food & Drink",
                 color: "#4CAF50",
                 expenses: [{id: "e1", title: "coffee", amount: 5, date: "2024-12-11T10:00:00Z"}]
               },
               {
                 id: "456",
                 name: "Travel",
                 color: "#2196F3",
                 expenses: [{id: "e2", title: "uber", amount: 15, date: "2024-12-11T11:00:00Z"}]
               }
             ]
           }
         }
       }
     ]
   })

6. Call beginRendering:
   beginRendering({ surfaceId: "categories", root: "categories_root" })

7. Respond: "Added coffee for \$5 to Food & Drink."

CRITICAL RULES FOR CATEGORIES SURFACE:
- ALWAYS call getAllExpenses first to get ALL current categories and expenses
- ALWAYS use CategoriesContainer as the root component (not individual CategoryColumn components)
- ALWAYS include ALL categories in the categories array, not just the new one
- When showing charts or all expenses, ALWAYS update the categories surface with ALL categories

Category Management:
- When adding to existing category: Use the existing categoryId
- When category doesn't exist: Create it first with addCategory, then add expense
- Infer category from context (e.g., "coffee" → "Food & Drink", "uber" → "Travel")
- Default categories: Food & Drink, Travel, Work, Entertainment, Shopping, Health, Other

UI Update Rules:
- Only show ONE chart at a time in the chart slot
- Use 10% opacity background tint for category columns
- ALWAYS include the 'date' field for every expense
- For categories surface: ALWAYS use CategoriesContainer with ALL categories, never individual CategoryColumn components
- When updating categories surface, ALWAYS include ALL existing categories, not just new ones
- Each expense needs: id, title, amount, date (ISO 8601 string)

CHART DATA CREATION:
When creating charts (pie, bar, or line):
1. Call getAllExpenses to get ALL categories and their expenses
2. For EACH category, calculate the TOTAL amount (sum all expenses in that category)
3. Create ONE data point per category with:
   - label: category name (e.g., "Food & Drink")
   - value: total amount for that category (sum of all expenses)
   - color: category color
4. IMPORTANT: Create exactly ONE data point per category - do NOT create multiple points for the same category
5. Example: If you have "Food & Drink" with expenses [\$5, \$10, \$3], create ONE point with label: "Food & Drink", value: 18, color: "#4CAF50"

Example chart data structure (for surfaceUpdate):
- chartType: "line"
- data: array with ONE object per category
- Each data object: label (category name), value (total amount), color (category color)

Background Management:
- Call generateBackground tool first
- The generateBackground tool returns hasImage: true/false and a description
- When creating BackgroundImage widget:
  - If hasImage is true: use imageUrl: "generated" (the widget will load the image from the service)
  - If hasImage is false: use imageUrl: null (will show gradient)
- DO NOT pass full base64 image strings - use "generated" flag instead
- Then surfaceUpdate with BackgroundImage component:
  {
    imageUrl: "generated",  // Use "generated" if image was created, null otherwise
    description: "beach theme"  // The description from generateBackground
  }
- Then beginRendering with the component ID

Always be helpful, conversational, and efficient!
''';
  }

  List<AiTool> _createExpenseTools() {
    return [
      DynamicAiTool<JsonMap>(
        name: 'addExpense',
        description:
            'Adds a new expense to a category. This tool automatically returns ALL categories with ALL their expenses so you can immediately update the UI. Use the returned data to create CategoryColumn widgets on the "categories" surface.',
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
          // #region agent log
          _debugLog(
              'app.dart:addExpense',
              'addExpense TOOL CALLED',
              {
                'title': args['title'],
                'amount': args['amount'],
                'categoryId': args['categoryId'],
                'existingExpenseCount':
                    globalExpenseService?.expenses.length ?? 0,
              },
              'A,B');
          // #endregion

          final expenseService = globalExpenseService;
          if (expenseService == null) {
            return {'error': 'ExpenseService not available'};
          }

          final title = args['title'] as String;
          final amount = (args['amount'] as num).toDouble();
          final categoryId = args['categoryId'] as String;

          final expense = expenseService.addExpense(title, amount, categoryId);

          // #region agent log
          _debugLog(
              'app.dart:addExpense:after',
              'addExpense completed',
              {
                'expenseId': expense.id,
                'totalExpensesNow': expenseService.expenses.length,
              },
              'A,B');
          // #endregion

          // Automatically get ALL categories and expenses to return
          final categories = expenseService.categories;
          final expenses = expenseService.expenses;

          final allCategoriesData = categories
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
              .toList();

          return {
            'success': true,
            'expenseId': expense.id,
            'allCategories': allCategoriesData,
            'total': expenseService.totalExpenses,
            'message':
                'Expense added. Use the allCategories data to create CategoryColumn widgets for EVERY category.',
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
          // #region agent log
          _debugLog(
              'app.dart:addCategory',
              'addCategory TOOL CALLED',
              {
                'name': args['name'],
                'color': args['color'],
                'existingCategoryCount':
                    globalExpenseService?.categories.length ?? 0,
              },
              'A,B');
          // #endregion

          final expenseService = globalExpenseService;
          if (expenseService == null) {
            return {'error': 'ExpenseService not available'};
          }

          final name = args['name'] as String;
          final color = args['color'] as String;

          final category = expenseService.addCategory(name, color);

          // #region agent log
          _debugLog(
              'app.dart:addCategory:after',
              'addCategory completed',
              {
                'categoryId': category.id,
                'totalCategoriesNow': expenseService.categories.length,
              },
              'A,B');
          // #endregion

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

          // Gemini has generated an enhanced prompt for image generation
          // In production, this would call Imagen API with the Gemini-generated prompt
          // For now, we return null to show themed gradients based on the description

          final description = imagenService.currentDescription ?? prompt;
          final hasImage = imagenService.currentBackgroundUrl != null;

          return {
            'success': true,
            'hasImage': hasImage, // Boolean flag instead of full base64 string
            'description': description,
            'message': hasImage
                ? 'Background image generated successfully using Gemini AI and ImageGen! '
                    'You MUST now update the "background" surface with a BackgroundImage widget containing imageUrl: "generated" and description: "$description". '
                    'The widget will automatically load the generated image from the service.'
                : 'Background prompt generated using Gemini AI. Image generation is pending or failed. '
                    'You MUST now update the "background" surface with a BackgroundImage widget containing imageUrl: null and description: "$description".',
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

    // #region agent log
    _debugLog(
        'app.dart:_handleSurfaceAdded',
        'Surface ADDED callback triggered',
        {
          'surfaceId': surfaceId,
          'rootComponentId': definition.rootComponentId,
          'categoryWidgetsBefore': _surfaceManager.categoryWidgets.length,
        },
        'A,D');
    // #endregion

    setState(() {
      // Handle categories surface - now uses CategoriesContainer widget
      if (surfaceId == AppConstants.surfaceCategories) {
        // #region agent log
        _debugLog(
            'app.dart:_handleSurfaceAdded:categories',
            'Adding categories surface with CategoriesContainer',
            {
              'surfaceId': surfaceId,
              'hasRootComponent': definition.rootComponentId != null,
            },
            'D,E');
        // #endregion
        // Clear existing categories and set the new container
        if (definition.rootComponentId != null) {
          _surfaceManager.clearCategories();
          _surfaceManager.setCategorySurface(
            surfaceId,
            GenUiSurface(
              host: _genUiManager,
              surfaceId: surfaceId,
            ),
          );
        }
        // #region agent log
        _debugLog(
            'app.dart:_handleSurfaceAdded:categories:after',
            'After add categories',
            {
              'categoryWidgetsAfter': _surfaceManager.categoryWidgets.length,
            },
            'D,E');
        // #endregion
        return;
      }

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
        case AppConstants.surfaceDialog:
          // #region agent log
          _debugLog(
              'app.dart:_handleSurfaceAdded:dialog',
              'Dialog surface ADDED',
              {
                'surfaceId': surfaceId,
              },
              'A');
          // #endregion
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

    // #region agent log
    _debugLog(
        'app.dart:_handleSurfaceUpdated',
        'Surface UPDATED callback triggered',
        {
          'surfaceId': surfaceId,
          'rootComponentId': definition.rootComponentId,
          'categoryWidgetsBefore': _surfaceManager.categoryWidgets.length,
        },
        'A,D');
    // #endregion

    setState(() {
      // Handle categories surface - now uses CategoriesContainer widget
      if (surfaceId == AppConstants.surfaceCategories) {
        // #region agent log
        _debugLog(
            'app.dart:_handleSurfaceUpdated:categories',
            'Updating categories surface with CategoriesContainer',
            {
              'surfaceId': surfaceId,
              'hasRootComponent': definition.rootComponentId != null,
            },
            'D,E');
        // #endregion
        // Update the categories surface (CategoriesContainer includes all categories)
        if (definition.rootComponentId != null) {
          _surfaceManager.setCategorySurface(
            surfaceId,
            GenUiSurface(
              host: _genUiManager,
              surfaceId: surfaceId,
            ),
          );
        }
        // #region agent log
        _debugLog(
            'app.dart:_handleSurfaceUpdated:categories:after',
            'After update categories',
            {
              'categoryWidgetsAfter': _surfaceManager.categoryWidgets.length,
            },
            'D,E');
        // #endregion
        return;
      }

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
        case AppConstants.surfaceDialog:
          // #region agent log
          _debugLog(
              'app.dart:_handleSurfaceUpdated:dialog',
              'Dialog surface UPDATED',
              {
                'surfaceId': surfaceId,
              },
              'A');
          // #endregion
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
      // Check if this is the categories surface
      if (surfaceId == AppConstants.surfaceCategories) {
        _surfaceManager.clearCategories();
        return;
      }

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
