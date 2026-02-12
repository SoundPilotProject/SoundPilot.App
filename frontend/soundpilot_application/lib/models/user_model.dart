/// Represents the user domain model with synchronized Firestore settings.
class UserModel {
  final String id;
  final String username;
  final String email;
  final String language;
  final String theme;

  UserModel({
    required this.id,
    required this.username,
    required this.email,
    this.language = 'en',
    this.theme = 'system',
  });

  /// Factory method to create a UserModel from a Firestore document snippet.
  factory UserModel.fromFirestore(Map<String, dynamic> data, String id) {
    // Accessing nested 'settings' map as seen in your Firestore structure
    final settings = data['settings'] as Map<String, dynamic>? ?? {};

    return UserModel(
      id: id,
      username: data['username'] ?? 'User',
      email: data['email'] ?? '',
      language: settings['language'] ?? 'en',
      theme: settings['theme'] ?? 'system',
    );
  }
}