import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/chat_message.dart';

class ChatState {
  final List<ChatMessage> messages;
  final bool isTyping;

  ChatState({this.messages = const [], this.isTyping = false});

  ChatState copyWith({List<ChatMessage>? messages, bool? isTyping}) {
    return ChatState(
      messages: messages ?? this.messages,
      isTyping: isTyping ?? this.isTyping,
    );
  }
}

final chatProvider = NotifierProvider<ChatNotifier, ChatState>(() {
  return ChatNotifier();
});

class ChatNotifier extends Notifier<ChatState> {
  @override
  ChatState build() {
    return ChatState(
      messages: [
        ChatMessage(
          text:
              'Hola, soy "El Sistema" de Smart Mechanic. He recibido tu S.O.S. y estoy analizando las evidencias que enviaste (fotos/audio) para darte un diagnóstico y encontrarte el mejor taller.',
          role: MessageRole.assistant,
        ),
      ],
    );
  }

  void addMessage(ChatMessage message) {
    state = state.copyWith(
      messages: [...state.messages, message],
      isTyping: false,
    );
  }

  void initializeWithContext(String contextText) {
    // Evitar duplicados si el último mensaje ya es el mismo análisis
    if (state.messages.isNotEmpty && state.messages.last.text == contextText) {
      return;
    }

    state = state.copyWith(
      messages: [
        ...state.messages,
        ChatMessage(
          text: contextText,
          role: MessageRole.assistant,
        ),
      ],
      isTyping: false,
    );
  }

  void setTyping(bool typing) {
    state = state.copyWith(isTyping: typing);
  }
}
