# Firebase Providers Documentation

This directory contains Riverpod providers for Firebase services in the StopFires app.

## Overview

The Firebase providers are organized into separate files for better maintainability:

- `firebase_providers.dart` - Core Firebase service providers
- `firestore_service.dart` - Firestore service class and related providers
- `geolocation_provider.dart` - Location services with Firestore integration

## Core Providers

### Firebase Services

```dart
// Firebase Auth instance
final firebaseAuthProvider = Provider<firebase_auth.FirebaseAuth>

// Firestore instance  
final firestoreProvider = Provider<FirebaseFirestore>

// Firebase Functions instance
final functionsProvider = Provider<FirebaseFunctions>
```

### User State

```dart
// Current Firebase Auth user stream
final firebaseAuthUserProvider = StreamProvider<firebase_auth.User?>

// Current Firebase Auth user (synchronous)
final currentFirebaseUserProvider = Provider<firebase_auth.User?>
```

## Firestore Service

The `FirestoreService` class provides a clean interface for Firestore operations:

```dart
// Get the service instance
final service = ref.read(firestoreServiceProvider);

// Get user profile
final profile = await service.getUserProfile();

// Update user profile
await service.updateUserProfile({'name': 'John'});

// Add document to collection
await service.addDocument('posts', {'title': 'Hello'});

// Get collection stream
final stream = service.getCollectionStream('posts');
```

### Firestore Providers

```dart
// User profile data stream
final userProfileProvider = StreamProvider<Map<String, dynamic>?>

// Collection stream (family provider)
final collectionProvider = StreamProvider.family<QuerySnapshot, String>
```

## Usage Examples

### In a Widget

```dart
class MyWidget extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Watch user state
    final userAsync = ref.watch(firebaseAuthUserProvider);
    
    // Watch user profile
    final profileAsync = ref.watch(userProfileProvider);
    
    return userAsync.when(
      data: (user) => user != null 
        ? Text('Welcome ${user.email}')
        : Text('Please sign in'),
      loading: () => CircularProgressIndicator(),
      error: (error, stack) => Text('Error: $error'),
    );
  }
}
```

### In a Service/Repository

```dart
class UserRepository {
  final WidgetRef ref;
  
  UserRepository(this.ref);
  
  Future<void> updateUser(String name) async {
    final service = ref.read(firestoreServiceProvider);
    await service.updateUserProfile({'name': name});
  }
}
```

### Collection Operations

```dart
// Watch a collection
final postsAsync = ref.watch(collectionProvider('posts'));

// With query builder
final recentPostsAsync = ref.watch(collectionProvider('posts').select(
  (query) => query.orderBy('createdAt', descending: true).limit(10)
));
```

## Development Setup

All providers include emulator support for development:

- **Firestore**: `127.0.0.1:8080`
- **Auth**: `127.0.0.1:9099`  
- **Functions**: `127.0.0.1:5001`

The emulators are automatically used when `kDebugMode` is true.

## Best Practices

1. **Use providers instead of direct Firebase calls** - This ensures consistent emulator usage and easier testing
2. **Watch providers in widgets** - Use `ref.watch()` for reactive UI updates
3. **Read providers in callbacks** - Use `ref.read()` for one-time access in callbacks
4. **Handle loading and error states** - Always use `.when()` to handle async states
5. **Use service classes** - Encapsulate complex operations in service classes

## Example Widgets

See `../widgets/firebase_example_widget.dart` for complete usage examples.
