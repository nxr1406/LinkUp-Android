# LinkUp - Modern Instagram-style Chat Application

A feature-rich real-time chat application built with Flutter and Firebase, inspired by Instagram's messaging system.

## Features

### Authentication
- Email & Password Sign Up/Login
- Google Sign In
- Profile setup with username, bio, and profile picture

### Chat Features
- One-to-One and Group Chat
- Real-time messaging with instant delivery
- Typing indicators
- Read receipts (Seen/Delivered status)
- Message reactions with emojis
- Reply to messages
- Forward messages
- Edit messages
- Delete for everyone (Unsend)
- Pin important messages
- Search messages within chats

### Instagram-Style Features
- Dark/Light theme support
- Emoji quick reactions
- Vanish mode for auto-deleting messages
- Block and restrict users
- Message requests for non-contacts

### Group Features
- Create and manage groups
- Add/Remove members
- Admin role management
- Group name and icon customization
- Group polls

### Privacy & Security
- Block/Unblock users
- Restrict users (mute, hide messages)
- Vanish mode for temporary messages
- Message requests filtering

### Profile Features
- Profile picture upload via Catbox API
- Bio and username customization
- Online/Offline status
- Last seen timestamps

### Additional Features
- Push notifications for new messages
- Voice and Video calls (WebRTC)
- Offline support
- Optimized Firebase queries

## Tech Stack

- **Frontend**: Flutter (Dart)
- **Backend**: Firebase (Auth, Firestore, Cloud Messaging)
- **Image Storage**: Catbox Public API
- **Calls**: WebRTC
- **State Management**: Provider
- **Local Storage**: Shared Preferences

## Prerequisites

- Flutter SDK (>=3.0.0)
- Android Studio / VS Code
- Firebase account
- Catbox API key (for profile pictures)

## Installation

1. **Clone the repository**
```bash
git clone https://github.com/yourusername/linkup-chat-app.git
cd linkup-chat-app