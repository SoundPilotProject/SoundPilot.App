import 'package:logger/logger.dart';

/// Global logger instance for consistent logging throughout the app.
/// We use a single instance to manage log levels and formatting in one place.
final logger = Logger(
  printer: PrettyPrinter(
    methodCount: 2,       // Number of method calls to be displayed
    errorMethodCount: 8,  // Number of method calls if stacktrace is provided
    lineLength: 120,      // Width of the output
    colors: true,         // Colorful log messages
    printEmojis: true,    // Print an emoji for each log message
  ),
);