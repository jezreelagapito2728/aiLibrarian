import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'settings.dart';

class HomePage extends StatefulWidget {
  final String? libraryCard;
  final String? patronId;

  const HomePage({super.key, this.libraryCard, this.patronId});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  // --- STATE VARIABLES ---
  final TextEditingController _controller = TextEditingController();
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  final ScrollController _scrollController = ScrollController();
  final PageController _bookPageController = PageController();

  bool _isNewChatHovered = false;
  bool _isFocused = false;

  // State for managing chat messages, loading status, and search
  final List<Map<String, dynamic>> _messages = [];
  List<Map<String, dynamic>> _filteredMessages = [];
  bool _isLoading = false;

  // Chat history
  static final List<List<Map<String, dynamic>>> _chatHistory = [];
  int? _currentChatIndex;

  // Book search result navigation
  int _currentBookIndex = 0;
  List<Map<String, String>> _currentBooks = [];

  static const String _apiUrl =
      'http://192.168.1.41:8087/api/query/query_router';
  static const String _biblioApiUrl = 'http://192.168.1.68:8080/api/v1/biblios';
  static const String _librariesApiUrl =
      'http://192.168.1.68:8080/api/v1/public/libraries';

  @override
  void initState() {
    super.initState();
    _filteredMessages = _messages;
    _searchController.addListener(_filterMessages);
    _startNewChatSession();
  }

  @override
  void dispose() {
    _controller.dispose();
    _searchController.dispose();
    _focusNode.dispose();
    _scrollController.dispose();
    _bookPageController.dispose();
    super.dispose();
  }

  // --- UI HELPER METHODS ---

  void _unfocusTextField() {
    if (_focusNode.hasFocus) {
      _focusNode.unfocus();
    }
  }

  void _onTextChanged(String value) {
    setState(() {
      _isFocused = value.isNotEmpty;
    });
  }

  void _filterMessages() {
    final query = _searchController.text.trim().toLowerCase();
    setState(() {
      if (query.isEmpty) {
        _filteredMessages = _messages;
      } else {
        _filteredMessages = _messages
            .where(
              (message) =>
                  (message['text'] as String).toLowerCase().contains(query),
            )
            .toList();
      }
    });
  }

  Widget _buildServiceItem(String emoji, String text) {
    return Align(
      alignment: Alignment.center,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(emoji, style: const TextStyle(fontSize: 20)),
          const SizedBox(width: 12),
          Text(
            text,
            style: const TextStyle(fontSize: 16, color: Colors.black87),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickMessageButton(String text) {
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.grey[200],
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      ),
      child: Text(text, style: const TextStyle(color: Colors.black87)),
      onPressed: () {
        _controller.text = text;
        _sendMessage();
      },
    );
  }

  // --- NAVIGATION & CHAT LOGIC ---

  void _navigateToSettings() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const SettingsPage()),
    );
  }

  void _startNewChatSession() {
    setState(() {
      _messages.clear();
      _filteredMessages.clear();
      _searchController.clear();
      _isLoading = false;
      _currentBooks.clear();
      _currentBookIndex = 0;
      _chatHistory.add([]);
      _currentChatIndex = _chatHistory.length - 1;
    });
  }

  void _loadChatSession(int index) {
    setState(() {
      _messages.clear();
      _messages.addAll(_chatHistory[index]);
      _filteredMessages = _messages;
      _searchController.clear();
      _isLoading = false;
      _currentBooks.clear();
      _currentBookIndex = 0;
      _currentChatIndex = index;
    });
    _scrollToBottom();
    Navigator.pop(context);
  }

  void _startNewChat() {
    _startNewChatSession();
    Navigator.pop(context);
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _previousBook() {
    if (_currentBookIndex > 0) {
      setState(() {
        _currentBookIndex--;
      });
      _bookPageController.animateToPage(
        _currentBookIndex,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void _nextBook() {
    if (_currentBookIndex < _currentBooks.length - 1) {
      setState(() {
        _currentBookIndex++;
      });
      _bookPageController.animateToPage(
        _currentBookIndex,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  Future<void> _sendMessage() async {
    final String currentInput = _controller.text.trim();
    if (currentInput.isEmpty) {
      return;
    }

    _unfocusTextField();
    _controller.clear();

    setState(() {
      _messages.add({'text': currentInput, 'isUser': true});
      _filteredMessages = _messages;
      _isLoading = true;
      if (_currentChatIndex != null) {
        _chatHistory[_currentChatIndex!].add({
          'text': currentInput,
          'isUser': true,
        });
      }
    });
    _scrollToBottom();

    try {
      final response = await http.post(
        Uri.parse(_apiUrl),
        headers: {"Content-Type": "application/json"},
        body: json.encode({"query": currentInput}),
      );

      Map<String, dynamic> aiMessage;
      if (response.statusCode == 200) {
        final responseBody = json.decode(response.body);

        if (responseBody.containsKey('response') &&
            responseBody['response'] is List) {
          final bookSearch = responseBody['response'][0];
          if (bookSearch['type'] == 'booksearch' &&
              bookSearch['books'] != null) {
            final newBooks = <Map<String, String>>[];
            for (var book in bookSearch['books']) {
              newBooks.add({
                'title': book['title'] ?? 'Unknown Title',
                'author': book['author'] ?? 'Unknown Author',
                'year': book['year']?.toString() ?? 'Unknown',
                'isbn': book['isbn'] ?? 'Unknown',
                'publisher': book['publisher'] ?? 'Unknown Publisher',
                'quantity_available':
                    book['quantity_available']?.toString() ?? '0',
                'biblio_id': book['biblio_id']?.toString() ?? 'Unknown',
              });
            }

            _currentBooks = newBooks;
            _currentBookIndex = 0;

            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (_bookPageController.hasClients) {
                _bookPageController.animateToPage(
                  0,
                  duration: const Duration(milliseconds: 1),
                  curve: Curves.linear,
                );
              }
            });

            aiMessage = {
              'text': bookSearch['answer'] ?? 'Here are the search results:',
              'isUser': false,
              'type': 'book_search',
              'books': newBooks,
            };
          } else {
            aiMessage = {
              'text': "Unexpected book search response format.",
              'isUser': false,
            };
          }
        } else if (responseBody.containsKey('answer')) {
          String text = responseBody['answer'];
          if (responseBody['reminder1'] != null) {
            text += "\n\n💡 ${responseBody['reminder1']}";
          }
          if (responseBody['reminder2'] != null) {
            text += "\n💡 ${responseBody['reminder2']}";
          }
          if (responseBody['reminder3'] != null) {
            text += "\n💡 ${responseBody['reminder3']}";
          }
          aiMessage = {'text': text, 'isUser': false};
        } else {
          aiMessage = {
            'text': "Sorry, I couldn't understand the response.",
            'isUser': false,
          };
        }
      } else {
        aiMessage = {
          'text':
              "Error: Could not connect to the server (Code: ${response.statusCode}). Please try again later.",
          'isUser': false,
        };
      }
      setState(() {
        _messages.add(aiMessage);
        _filteredMessages = _messages;
        if (_currentChatIndex != null) {
          _chatHistory[_currentChatIndex!].add(aiMessage);
        }
        _filterMessages();
      });
    } catch (e) {
      setState(() {
        _messages.add({'text': "An error occurred: $e", 'isUser': false});
        _filteredMessages = _messages;
        if (_currentChatIndex != null) {
          _chatHistory[_currentChatIndex!].add({
            'text': "An error occurred: $e",
            'isUser': false,
          });
        }
        _filterMessages();
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
      _scrollToBottom();
    }
  }

  Future<Map<String, dynamic>> _fetchBookDetails(String biblioId) async {
    try {
      final response = await http.get(
        Uri.parse('$_biblioApiUrl/$biblioId/items'),
        headers: {"Content-Type": "application/json"},
      );

      if (response.statusCode == 200) {
        final items = json.decode(response.body) as List;
        final itemCount = items.length.toString();
        final itemId = items.isNotEmpty
            ? items[0]['item_id']?.toString() ?? 'None'
            : 'None';
        return {'availableCopies': itemCount, 'itemId': itemId};
      } else {
        return {'availableCopies': '0', 'itemId': 'None'};
      }
    } catch (e) {
      return {'availableCopies': '0', 'itemId': 'None'};
    }
  }

  Future<List<Map<String, String>>> _fetchLibraries() async {
    try {
      final response = await http.get(
        Uri.parse(_librariesApiUrl),
        headers: {"Content-Type": "application/json"},
      );

      if (response.statusCode == 200) {
        final libraries = json.decode(response.body) as List<dynamic>;
        return libraries.map((lib) {
          return <String, String>{
            'library_id': lib['library_id']?.toString() ?? 'Unknown',
            'name': lib['name']?.toString() ?? 'Unknown Library',
          };
        }).toList();
      }
      print('API Error for libraries: Status ${response.statusCode}');
      return [];
    } catch (e) {
      print('Exception in _fetchLibraries: $e');
      return [];
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _unfocusTextField,
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          leading: Builder(
            builder: (context) => IconButton(
              icon: const Icon(Icons.menu, color: Colors.black),
              onPressed: () {
                _unfocusTextField();
                Scaffold.of(context).openDrawer();
              },
            ),
          ),
          title: const Text(
            'AiChatBot',
            style: TextStyle(color: Colors.black, fontSize: 16),
          ),
        ),
        drawer: _buildDrawer(),
        body: Column(
          children: [
            Expanded(
              child: _messages.isEmpty
                  ? _buildWelcomeScreen()
                  : _buildChatList(),
            ),
            if (_isLoading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8.0),
                child: LinearProgressIndicator(),
              ),
            _buildInputArea(),
          ],
        ),
      ),
    );
  }

  Drawer _buildDrawer() {
    return Drawer(
      child: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xff242832), Color(0xff242832), Color(0xff251c28)],
          ),
        ),
        child: Column(
          children: [
            DrawerHeader(
              decoration: const BoxDecoration(color: Colors.transparent),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: "Search chats...",
                      hintStyle: const TextStyle(color: Colors.grey),
                      prefixIcon: const Icon(Icons.search, color: Colors.white),
                      filled: true,
                      fillColor: Colors.white.withValues(alpha: 0.05),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    style: const TextStyle(color: Colors.white),
                  ),
                  GestureDetector(
                    onTapDown: (_) => setState(() => _isNewChatHovered = true),
                    onTapUp: (_) => setState(() => _isNewChatHovered = false),
                    onTapCancel: () =>
                        setState(() => _isNewChatHovered = false),
                    onTap: _startNewChat,
                    child: Container(
                      width: double.infinity,
                      height: 50,
                      decoration: BoxDecoration(
                        gradient: _isNewChatHovered
                            ? const LinearGradient(
                                colors: [
                                  Color(0xFF6c20fa),
                                  Color(0xFF5d18dc),
                                  Color(0xFF6c20fa),
                                ],
                              )
                            : null,
                        border: Border.all(color: Colors.white, width: 2),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      alignment: Alignment.center,
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.add, color: Colors.white),
                          SizedBox(width: 8),
                          Text(
                            'New Chat',
                            style: TextStyle(color: Colors.white),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const Padding(
              padding: EdgeInsets.only(left: 16.0, right: 16.0, bottom: 4.0),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  "Recent Chats",
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
            Expanded(
              child: _chatHistory.isEmpty
                  ? const Center(
                      child: Text(
                        "No chat history",
                        style: TextStyle(color: Colors.grey),
                      ),
                    )
                  : ListView.builder(
                      itemCount: _chatHistory.length,
                      itemBuilder: (context, index) {
                        final chat = _chatHistory[index];
                        final firstMessage = chat.isNotEmpty
                            ? (chat.firstWhere(
                                    (msg) => msg['isUser'] == true,
                                    orElse: () => {'text': 'Empty chat'},
                                  )['text']
                                  as String)
                            : 'Empty chat';
                        return ListTile(
                          title: Text(
                            firstMessage.length > 30
                                ? '${firstMessage.substring(0, 30)}...'
                                : firstMessage,
                            style: const TextStyle(color: Colors.white),
                          ),
                          onTap: () => _loadChatSession(index),
                        );
                      },
                    ),
            ),
            ListTile(
              leading: const Icon(Icons.settings, color: Colors.white),
              title: const Text(
                "Settings",
                style: TextStyle(color: Colors.white),
              ),
              onTap: _navigateToSettings,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWelcomeScreen() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24.0),
      child: Column(
        children: [
          const SizedBox(height: 40),
          Image.asset(
            'assets/icons/ChatBot.gif',
            width: 100,
            height: 100,
            color: const Color(0xFF6c20fa),
          ),
          const SizedBox(height: 30),
          const Text(
            "Welcome to AiChatBot!",
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 30),
          const Text(
            "I'm here to help answer your questions about the library.",
            style: TextStyle(fontSize: 16, color: Colors.black54),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 30),
          const Text(
            "Feel free to ask me anything - I can help you with:",
            style: TextStyle(fontSize: 16, color: Colors.black54),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 30),
          _buildServiceItem("📚", "Library hours and services"),
          const SizedBox(height: 16),
          _buildServiceItem("📖", "Book borrowing policies"),
          const SizedBox(height: 16),
          _buildServiceItem("🔍", "Finding resources"),
          const SizedBox(height: 16),
          _buildServiceItem("❓", "General inquiries"),
          const SizedBox(height: 40),
          const Text(
            "Go ahead, try asking me something!",
            style: TextStyle(fontSize: 16, color: Colors.black54),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 50),
          Wrap(
            spacing: 16,
            runSpacing: 16,
            alignment: WrapAlignment.center,
            children: [
              _buildQuickMessageButton("What are the library hours?"),
              _buildQuickMessageButton("How do I borrow a book?"),
              _buildQuickMessageButton("Where is the history section?"),
              _buildQuickMessageButton("Search books about math"),
            ],
          ),
          const SizedBox(height: 70),
        ],
      ),
    );
  }

  Widget _buildChatList() {
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.all(8.0),
      itemCount: _filteredMessages.length,
      itemBuilder: (context, index) {
        return _buildMessageBubble(_filteredMessages[index]);
      },
    );
  }

  Widget _buildMessageBubble(Map<String, dynamic> message) {
    final isUser = message['isUser'] as bool;
    final messageText = message['text'] as String;

    if (!isUser && message['type'] == 'book_search') {
      final books = message['books'] as List<Map<String, String>>;
      final messageIndex = _filteredMessages.indexOf(message);

      return Align(
        alignment: Alignment.centerLeft,
        child: Container(
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.95,
          ),
          margin: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  messageText,
                  style: const TextStyle(
                    fontSize: 14,
                    color: Colors.black87,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  vertical: 12,
                  horizontal: 16,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFF6c20fa),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.search, color: Colors.white, size: 18),
                    const SizedBox(width: 8),
                    Text(
                      'Search Results (${books.length} books found)',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              if (books.isNotEmpty) ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(
                      onPressed:
                          messageIndex == _filteredMessages.length - 1 &&
                              _currentBookIndex > 0
                          ? _previousBook
                          : null,
                      icon: const Icon(Icons.arrow_back_ios),
                      color:
                          messageIndex == _filteredMessages.length - 1 &&
                              _currentBookIndex > 0
                          ? const Color(0xFF6c20fa)
                          : Colors.grey,
                    ),
                    Text(
                      messageIndex == _filteredMessages.length - 1
                          ? '${_currentBookIndex + 1} / ${books.length}'
                          : '1 / ${books.length}',
                      style: const TextStyle(
                        fontSize: 14,
                        color: Colors.black54,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    IconButton(
                      onPressed:
                          messageIndex == _filteredMessages.length - 1 &&
                              _currentBookIndex < books.length - 1
                          ? _nextBook
                          : null,
                      icon: const Icon(Icons.arrow_forward_ios),
                      color:
                          messageIndex == _filteredMessages.length - 1 &&
                              _currentBookIndex < books.length - 1
                          ? const Color(0xFF6c20fa)
                          : Colors.grey,
                    ),
                  ],
                ),
                SizedBox(
                  height: 240,
                  child: PageView.builder(
                    controller: messageIndex == _filteredMessages.length - 1
                        ? _bookPageController
                        : PageController(initialPage: 0),
                    onPageChanged: messageIndex == _filteredMessages.length - 1
                        ? (index) {
                            setState(() {
                              _currentBookIndex = index;
                            });
                          }
                        : null,
                    itemCount: books.length,
                    itemBuilder: (context, index) {
                      final book = books[index];
                      final quantityAvailable =
                          int.tryParse(book['quantity_available'] ?? '0') ?? 0;
                      final isAvailable = quantityAvailable > 0;

                      return Container(
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey.shade300),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.1),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: Text(
                                    book['title'] ?? 'Unknown Title',
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.black87,
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 3,
                                  ),
                                  decoration: BoxDecoration(
                                    color: isAvailable
                                        ? Colors.green
                                        : Colors.red,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Text(
                                    isAvailable
                                        ? '$quantityAvailable AVAILABLE'
                                        : 'OUT OF STOCK',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'by ${book['author'] ?? 'Unknown Author'}',
                              style: const TextStyle(
                                fontSize: 12,
                                color: Colors.black54,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Year',
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: Colors.grey[600],
                                        ),
                                      ),
                                      Text(
                                        book['year'] ?? 'Unknown',
                                        style: const TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Publisher',
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: Colors.grey[600],
                                        ),
                                      ),
                                      Text(
                                        book['publisher'] ?? 'Unknown',
                                        style: const TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w500,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: ElevatedButton.icon(
                                    onPressed: isAvailable
                                        ? () async {
                                            if (!mounted) return;
                                            final libraries =
                                                await _fetchLibraries();
                                            if (!mounted) return;
                                            String? selectedLibraryId;

                                            // Ensure context is still valid
                                            if (!mounted) return;

                                            // Store dialog context separately
                                            await showDialog(
                                              context: context,
                                              builder: (dialogContext) {
                                                return StatefulBuilder(
                                                  builder: (dialogContext, setDialogState) {
                                                    return AlertDialog(
                                                      title: Text(
                                                        'Reserve "${book['title']}"',
                                                        style: const TextStyle(
                                                          fontSize: 16,
                                                          fontWeight:
                                                              FontWeight.bold,
                                                        ),
                                                      ),
                                                      content: SingleChildScrollView(
                                                        child: Row(
                                                          crossAxisAlignment:
                                                              CrossAxisAlignment
                                                                  .start,
                                                          children: [
                                                            Expanded(
                                                              child: Column(
                                                                crossAxisAlignment:
                                                                    CrossAxisAlignment
                                                                        .start,
                                                                mainAxisSize:
                                                                    MainAxisSize
                                                                        .min,
                                                                children: const [
                                                                  Text(
                                                                    'Patron ID:',
                                                                    style: TextStyle(
                                                                      fontSize:
                                                                          14,
                                                                      fontWeight:
                                                                          FontWeight
                                                                              .bold,
                                                                    ),
                                                                  ),
                                                                  SizedBox(
                                                                    height: 8,
                                                                  ),
                                                                  Text(
                                                                    'Biblio ID:',
                                                                    style: TextStyle(
                                                                      fontSize:
                                                                          14,
                                                                      fontWeight:
                                                                          FontWeight
                                                                              .bold,
                                                                    ),
                                                                  ),
                                                                  SizedBox(
                                                                    height: 8,
                                                                  ),
                                                                  Text(
                                                                    'Available Copies:',
                                                                    style: TextStyle(
                                                                      fontSize:
                                                                          14,
                                                                      fontWeight:
                                                                          FontWeight
                                                                              .bold,
                                                                    ),
                                                                  ),
                                                                  SizedBox(
                                                                    height: 8,
                                                                  ),
                                                                  Text(
                                                                    'Select Pickup Library:',
                                                                    style: TextStyle(
                                                                      fontSize:
                                                                          14,
                                                                      fontWeight:
                                                                          FontWeight
                                                                              .bold,
                                                                    ),
                                                                  ),
                                                                ],
                                                              ),
                                                            ),
                                                            Expanded(
                                                              child: Column(
                                                                crossAxisAlignment:
                                                                    CrossAxisAlignment
                                                                        .start,
                                                                mainAxisSize:
                                                                    MainAxisSize
                                                                        .min,
                                                                children: [
                                                                  Text(
                                                                    widget.patronId ??
                                                                        'Unknown',
                                                                    style: const TextStyle(
                                                                      fontSize:
                                                                          14,
                                                                    ),
                                                                  ),
                                                                  const SizedBox(
                                                                    height: 8,
                                                                  ),
                                                                  Text(
                                                                    book['biblio_id'] ??
                                                                        'Unknown',
                                                                    style: const TextStyle(
                                                                      fontSize:
                                                                          14,
                                                                    ),
                                                                  ),
                                                                  const SizedBox(
                                                                    height: 8,
                                                                  ),
                                                                  Text(
                                                                    book['quantity_available'] ??
                                                                        '0',
                                                                    style: const TextStyle(
                                                                      fontSize:
                                                                          14,
                                                                    ),
                                                                  ),
                                                                  const SizedBox(
                                                                    height: 8,
                                                                  ),
                                                                  DropdownButton<
                                                                    String
                                                                  >(
                                                                    isExpanded:
                                                                        true,
                                                                    hint: const Text(
                                                                      'Select a library',
                                                                    ),
                                                                    value:
                                                                        selectedLibraryId,
                                                                    items: libraries.map((
                                                                      library,
                                                                    ) {
                                                                      return DropdownMenuItem<
                                                                        String
                                                                      >(
                                                                        value:
                                                                            library['library_id'],
                                                                        child: Text(
                                                                          library['name'] ??
                                                                              'Unknown',
                                                                        ),
                                                                      );
                                                                    }).toList(),
                                                                    onChanged: (value) {
                                                                      setDialogState(() {
                                                                        selectedLibraryId =
                                                                            value;
                                                                      });
                                                                    },
                                                                  ),
                                                                ],
                                                              ),
                                                            ),
                                                          ],
                                                        ),
                                                      ),
                                                      actions: [
                                                        TextButton(
                                                          onPressed: () =>
                                                              Navigator.pop(
                                                                dialogContext,
                                                              ),
                                                          child: const Text(
                                                            'Cancel',
                                                            style: TextStyle(
                                                              color: Color(
                                                                0xFF6c20fa,
                                                              ),
                                                            ),
                                                          ),
                                                        ),
                                                        ElevatedButton(
                                                          onPressed:
                                                              selectedLibraryId !=
                                                                      null &&
                                                                  isAvailable
                                                              ? () {
                                                                  if (!mounted)
                                                                    return;
                                                                  ScaffoldMessenger.of(
                                                                    context,
                                                                  ).showSnackBar(
                                                                    SnackBar(
                                                                      content: Text(
                                                                        'Reserved "${book['title']}" for pickup at library $selectedLibraryId',
                                                                      ),
                                                                      backgroundColor:
                                                                          const Color(
                                                                            0xFF6c20fa,
                                                                          ),
                                                                    ),
                                                                  );
                                                                  Navigator.pop(
                                                                    dialogContext,
                                                                  );
                                                                }
                                                              : null,
                                                          style: ElevatedButton.styleFrom(
                                                            backgroundColor:
                                                                isAvailable
                                                                ? const Color(
                                                                    0xFF6c20fa,
                                                                  )
                                                                : Colors.grey,
                                                            foregroundColor:
                                                                Colors.white,
                                                          ),
                                                          child: Text(
                                                            isAvailable
                                                                ? 'Confirm'
                                                                : 'Unavailable',
                                                          ),
                                                        ),
                                                      ],
                                                    );
                                                  },
                                                );
                                              },
                                            );
                                          }
                                        : null,
                                    icon: const Icon(
                                      Icons.bookmark_add,
                                      size: 16,
                                    ),
                                    label: const Text(
                                      'Reserve',
                                      style: TextStyle(fontSize: 12),
                                    ),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: isAvailable
                                          ? const Color(0xFF6c20fa)
                                          : Colors.grey,
                                      foregroundColor: Colors.white,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 8,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: OutlinedButton.icon(
                                    onPressed: () async {
                                      final bookDetails =
                                          await _fetchBookDetails(
                                            book['biblio_id'] ?? 'Unknown',
                                          );
                                      if (!mounted) return;

                                      await showDialog(
                                        context: context,
                                        builder: (dialogContext) => AlertDialog(
                                          title: Text(
                                            book['title'] ?? 'Book Details',
                                            style: const TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          content: SingleChildScrollView(
                                            child: Row(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Expanded(
                                                  child: Column(
                                                    crossAxisAlignment:
                                                        CrossAxisAlignment
                                                            .start,
                                                    mainAxisSize:
                                                        MainAxisSize.min,
                                                    children: const [
                                                      Text(
                                                        'Biblio ID:',
                                                        style: TextStyle(
                                                          fontSize: 14,
                                                          fontWeight:
                                                              FontWeight.bold,
                                                        ),
                                                      ),
                                                      SizedBox(height: 8),
                                                      Text(
                                                        'Author:',
                                                        style: TextStyle(
                                                          fontSize: 14,
                                                          fontWeight:
                                                              FontWeight.bold,
                                                        ),
                                                      ),
                                                      SizedBox(height: 8),
                                                      Text(
                                                        'Year:',
                                                        style: TextStyle(
                                                          fontSize: 14,
                                                          fontWeight:
                                                              FontWeight.bold,
                                                        ),
                                                      ),
                                                      SizedBox(height: 8),
                                                      Text(
                                                        'ISBN:',
                                                        style: TextStyle(
                                                          fontSize: 14,
                                                          fontWeight:
                                                              FontWeight.bold,
                                                        ),
                                                      ),
                                                      SizedBox(height: 8),
                                                      Text(
                                                        'Publisher:',
                                                        style: TextStyle(
                                                          fontSize: 14,
                                                          fontWeight:
                                                              FontWeight.bold,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                                Expanded(
                                                  child: Column(
                                                    crossAxisAlignment:
                                                        CrossAxisAlignment
                                                            .start,
                                                    mainAxisSize:
                                                        MainAxisSize.min,
                                                    children: [
                                                      Text(
                                                        book['biblio_id'] ??
                                                            'Unknown',
                                                        style: const TextStyle(
                                                          fontSize: 14,
                                                        ),
                                                      ),
                                                      const SizedBox(height: 8),
                                                      Text(
                                                        book['author'] ??
                                                            'Unknown Author',
                                                        style: const TextStyle(
                                                          fontSize: 14,
                                                        ),
                                                      ),
                                                      const SizedBox(height: 8),
                                                      Text(
                                                        book['year'] ??
                                                            'Unknown',
                                                        style: const TextStyle(
                                                          fontSize: 14,
                                                        ),
                                                      ),
                                                      const SizedBox(height: 8),
                                                      Text(
                                                        book['isbn'] ??
                                                            'Unknown',
                                                        style: const TextStyle(
                                                          fontSize: 14,
                                                        ),
                                                      ),
                                                      const SizedBox(height: 8),
                                                      Text(
                                                        book['publisher'] ??
                                                            'Unknown Publisher',
                                                        style: const TextStyle(
                                                          fontSize: 14,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          actions: [
                                            TextButton(
                                              onPressed: () =>
                                                  Navigator.pop(dialogContext),
                                              child: const Text(
                                                'Close',
                                                style: TextStyle(
                                                  color: Color(0xFF6c20fa),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      );
                                    },
                                    icon: const Icon(
                                      Icons.info_outline,
                                      size: 16,
                                    ),
                                    label: const Text(
                                      'Details',
                                      style: TextStyle(fontSize: 12),
                                    ),
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: const Color(0xFF6c20fa),
                                      side: const BorderSide(
                                        color: Color(0xFF6c20fa),
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 8,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ],
            ],
          ),
        ),
      );
    }

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        margin: const EdgeInsets.symmetric(vertical: 5, horizontal: 8),
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
        decoration: BoxDecoration(
          color: isUser ? const Color(0xFF6c20fa) : Colors.grey[200],
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          messageText,
          style: TextStyle(
            color: isUser ? Colors.white : Colors.black87,
            fontSize: 14,
          ),
        ),
      ),
    );
  }

  Widget _buildInputArea() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.all(10),
      child: SafeArea(
        child: Row(
          children: [
            Expanded(
              child: TextFormField(
                focusNode: _focusNode,
                controller: _controller,
                cursorColor: const Color(0xFF6c20fa),
                onChanged: _onTextChanged,
                onFieldSubmitted: (_) => _sendMessage(),
                decoration: InputDecoration(
                  hintText: "Message...",
                  contentPadding: const EdgeInsets.symmetric(
                    vertical: 10,
                    horizontal: 20,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(30),
                    borderSide: const BorderSide(color: Color(0xFF6c20fa)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(30),
                    borderSide: const BorderSide(color: Colors.grey),
                  ),
                ),
                maxLines: _isFocused ? 5 : 1,
                minLines: 1,
                keyboardType: TextInputType.multiline,
                textInputAction: TextInputAction.send,
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              onPressed: _isLoading ? null : _sendMessage,
              icon: Icon(
                Icons.send,
                color: _isLoading ? Colors.grey : const Color(0xFF6c20fa),
              ),
              style: IconButton.styleFrom(
                backgroundColor: Colors.grey[200],
                padding: const EdgeInsets.all(12),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
