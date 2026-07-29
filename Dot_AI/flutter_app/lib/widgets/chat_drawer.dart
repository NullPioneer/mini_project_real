import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../services/chat_storage.dart';
import '../screens/chat_screen.dart';

class ChatHistoryDrawer extends StatefulWidget {
  const ChatHistoryDrawer({super.key});

  @override
  State<ChatHistoryDrawer> createState() => _ChatHistoryDrawerState();
}

class _ChatHistoryDrawerState extends State<ChatHistoryDrawer> {
  @override
  Widget build(BuildContext context) {
    return Drawer(
      backgroundColor: AppTheme.backgroundDark,
      child: FutureBuilder<Map<String, ChatSession>>(
        future: ChatStorageService.getSessions(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator(color: AppTheme.accentNeon));
          
          final sessionsList = snapshot.data!.values.toList()
            ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
            
          return SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Padding(
                  padding: EdgeInsets.all(20.0),
                  child: Text(
                    'Chat History',
                    style: TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const Divider(color: AppTheme.surfaceLight, height: 1),
                if (sessionsList.isEmpty)
                  const Expanded(
                    child: Center(
                      child: Text(
                        'No previous chats.',
                        style: TextStyle(color: AppTheme.textSecondary),
                      ),
                    ),
                  )
                else
                  Expanded(
                    child: ListView.builder(
                      itemCount: sessionsList.length,
                      itemBuilder: (context, index) {
                        final session = sessionsList[index];
                        return ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                          leading: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: AppTheme.surfaceLight,
                              borderRadius: BorderRadius.circular(8)
                            ),
                            child: const Icon(Icons.history_rounded, color: AppTheme.accentNeon, size: 20),
                          ),
                          title: Text(
                            session.title,
                            style: const TextStyle(color: AppTheme.textPrimary, fontSize: 15, fontWeight: FontWeight.w600),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          subtitle: Text(
                            '${(session.messages.length / 2).floor()} interactions',
                            style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13),
                          ),
                          trailing: IconButton(
                            icon: const Icon(Icons.delete_outline_rounded, color: AppTheme.textSecondary, size: 20),
                            onPressed: () async {
                              await ChatStorageService.deleteSession(session.id);
                              setState(() {}); // refresh drawer
                            },
                          ),
                          onTap: () {
                            Navigator.pop(context); // close drawer
                            // check if we are already in ChatScreen. If so, replace route?
                            // For simplicity, just push a new route for now.
                            Navigator.pushReplacement(
                              context,
                              PageRouteBuilder(
                                pageBuilder: (context, animation, secondaryAnimation) => ChatScreen(extractedText: session.extractedText),
                                transitionDuration: Duration.zero,
                                reverseTransitionDuration: Duration.zero,
                              ),
                            );
                          },
                        );
                      },
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}
