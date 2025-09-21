import "dart:async";

import "package:flutter_terminal_sdk/flutter_terminal_sdk.dart";
import "package:flutter_terminal_sdk/models/card_reader_callbacks.dart";
import "package:flutter_terminal_sdk/models/data/payment_scheme.dart";
import "package:flutter_terminal_sdk/models/data/purchase_response.dart";
import "package:flutter_terminal_sdk/models/data/transaction_response.dart";
import "package:flutter_terminal_sdk/models/purchase_callbacks.dart";
import "package:flutter_terminal_sdk/models/refund_callbacks.dart";
import "package:flutter_terminal_sdk/models/terminal_response.dart";
import "package:uuid/uuid.dart"; // Add this dependency to pubspec.yaml

enum TransactionStatus {
  idle,
  initializing,
  loggedIn,
  connecting,
  connected,
  processing,
  completed,
  failed
}

enum NearPayError {
  sdkNotInitialized,
  nfcNotSupported,
  nfcDisabled,
  deviceNotReady,
  loginFailed,
  connectionFailed,
  transactionFailed,
  unknown
}

class NearPayResult {
  final bool success;
  final String message;
  final NearPayError? error;
  final dynamic response; // Can be PurchaseResponse or TransactionResponse

  NearPayResult({
    required this.success,
    required this.message,
    this.error,
    this.response,
  });

  NearPayResult.success({
    required this.message,
    this.response,
  })  : success = true,
        error = null;

  NearPayResult.failure({
    required this.message,
    required this.error,
  })  : success = false,
        response = null;
}

class DirectPaymentCallbacks {
  final Function(String)? onStatusUpdate;
  final Function(NearPayResult)? onTransactionCompleted;
  final Function(String)? onCardReaderUpdate;

  DirectPaymentCallbacks({
    this.onStatusUpdate,
    this.onTransactionCompleted,
    this.onCardReaderUpdate,
  });
}

class NearPayImpl {
  static final NearPayImpl _instance = NearPayImpl._internal();
  factory NearPayImpl() => _instance;
  NearPayImpl._internal();

  final FlutterTerminalSdk _terminalSdk = FlutterTerminalSdk();
  final Uuid _uuid = const Uuid();

  TerminalModel? _terminal;
  TerminalModel? _connectedTerminal;
  TransactionStatus _status = TransactionStatus.idle;

// For handling direct payment callbacks
  DirectPaymentCallbacks? _currentPaymentCallbacks;

// Getters
  bool get isInitialized => _terminalSdk.isInitialized;
  TransactionStatus get status => _status;
  TerminalModel? get connectedTerminal => _connectedTerminal;

  /// Initialize the Terminal SDK with comprehensive error checking
  final String googleCloudProjectNumber = "12345678";
  final String huaweiSafetyDetectApiKey = "your_api_key";
  Future<NearPayResult> initialize({
    Environment environment = Environment.sandbox,
    Country country = Country.sa,
  }) async
  {
    try {
      _status = TransactionStatus.initializing;

      await _terminalSdk.initialize(
        environment: environment,
        googleCloudProjectNumber: int.parse(googleCloudProjectNumber),
        huaweiSafetyDetectApiKey: huaweiSafetyDetectApiKey,
        country: country,
      );

      print("SDK initialized: ${_terminalSdk.isInitialized}");

      if (!_terminalSdk.isInitialized) {
        _status = TransactionStatus.failed;
        return NearPayResult.failure(
          message: "Failed to initialize SDK",
          error: NearPayError.sdkNotInitialized,
        );
      }

      return NearPayResult.success(
        message: "SDK initialized successfully",
      );
    } catch (e) {
      print("Error initializing SDK: $e");
      _status = TransactionStatus.failed;
      return NearPayResult.failure(
        message: "Error initializing SDK: $e",
        error: NearPayError.sdkNotInitialized,
      );
    }
  }

  /// Check if NFC is supported on the device
  Future<bool> isNfcSupported() async {
    try {
      return await _terminalSdk.isNfcEnabled();
    } catch (e) {
      print("Error checking NFC support: $e");
      return false;
    }
  }

  /// Check if NFC is enabled on the device
  Future<bool> isNfcEnabled() async {
    try {
      return await _terminalSdk.isNfcEnabled();
    } catch (e) {
      print("Error checking NFC status: $e");
      return false;
    }
  }

  /// Comprehensive device readiness check with detailed error reporting
  Future<NearPayResult> checkDeviceReadiness() async {
    try {
      if (!_terminalSdk.isInitialized) {
        return NearPayResult.failure(
          message: "SDK is not initialized. Please initialize first.",
          error: NearPayError.sdkNotInitialized,
        );
      }

      bool nfcEnabled;
      try {
        nfcEnabled = await _terminalSdk.isNfcEnabled();
      } catch (e) {
        return NearPayResult.failure(
          message: "NFC is not supported on this device.",
          error: NearPayError.nfcNotSupported,
        );
      }

      if (!nfcEnabled) {
        return NearPayResult.failure(
          message: "NFC is disabled. Please enable NFC in device settings.",
          error: NearPayError.nfcDisabled,
        );
      }

      return NearPayResult.success(
        message: "Device is ready for transactions.",
      );
    } catch (e) {
      return NearPayResult.failure(
        message: "Unknown error checking device readiness: $e",
        error: NearPayError.unknown,
      );
    }
  }

  /// Login with JWT token with comprehensive validation
  Future<NearPayResult> loginWithJWT(String jwtToken) async {
    try {
      final readinessCheck = await checkDeviceReadiness();
      if (!readinessCheck.success) {
        return readinessCheck;
      }

      print("Starting JWT login...");
      _terminal = await _terminalSdk.jwtLogin(jwt: jwtToken);

      if (_terminal != null) {
        _status = TransactionStatus.loggedIn;
        print("Login successful - Terminal UUID: ${_terminal!.terminalUUID}");
        return NearPayResult.success(
          message: "Login successful",
        );
      } else {
        print("Login failed - No terminal returned");
        return NearPayResult.failure(
          message: "Login failed - Invalid credentials or network error",
          error: NearPayError.loginFailed,
        );
      }
    } catch (e) {
      print("Login error: $e");
      _status = TransactionStatus.failed;
      return NearPayResult.failure(
        message: "Login error: $e",
        error: NearPayError.loginFailed,
      );
    }
  }

  /// Direct purchase after login (skips terminal connection step)
  Future<NearPayResult> purchaseDirectly({
    required double amount,
    PaymentScheme? scheme,
    String? customerReferenceNumber,
    required String transactionUuid,
    DirectPaymentCallbacks? callbacks,
  }) async
  {
    try {
      if (_terminal == null) {
        print("No terminal available - please login first");
        return NearPayResult.failure(
          message: "No terminal available - please login first",
          error: NearPayError.loginFailed,
        );
      }

      _status = TransactionStatus.processing;
      _currentPaymentCallbacks = callbacks;

      callbacks?.onStatusUpdate?.call("Starting direct payment...");

      print("Starting direct payment...");
      print("Terminal ID: ${_terminal!.tid}");
      print("Terminal UUID: ${_terminal!.terminalUUID}");
      print("Terminal UUID (uuid): ${_terminal!.terminalUUID}");

      // Generate unique transaction UUID
      final amountInCents = (amount * 100).round();

      callbacks?.onStatusUpdate?.call("Preparing payment terminal...");

      // Create completer for async callback handling
      final completer = Completer<NearPayResult>();

      // Start direct payment on terminal (your approach)
      await _terminal!.purchase(
        transactionUuid: transactionUuid,
        amount: amountInCents,
        scheme: scheme,
        customerReferenceNumber: customerReferenceNumber ?? "",
        callbacks: PurchaseCallbacks(
          cardReaderCallbacks: CardReaderCallbacks(
            onReadingStarted: () {
              print("Reading started...");
              callbacks?.onStatusUpdate?.call("Reading started...");
              callbacks?.onCardReaderUpdate?.call("Reading started");
            },
            onReaderDisplayed: () {
              print("Reader displayed");
              callbacks?.onStatusUpdate?.call("Reader displayed");
              callbacks?.onCardReaderUpdate?.call("Reader displayed");
            },
            onReaderClosed: () {
              print("Reader closed");
              callbacks?.onStatusUpdate?.call("Reader closed");
              callbacks?.onCardReaderUpdate?.call("Reader closed");
            },
            onReaderWaiting: () {
              print("Reader waiting...");
              callbacks?.onStatusUpdate?.call("Please present your card");
              callbacks?.onCardReaderUpdate?.call("Waiting for card");
            },
            onReaderReading: () {
              print("Reader reading...");
              callbacks?.onStatusUpdate?.call("Reading card...");
              callbacks?.onCardReaderUpdate?.call("Reading card");
            },
            onReaderRetry: () {
              print("Reader retrying...");
              callbacks?.onStatusUpdate?.call("Please try again");
              callbacks?.onCardReaderUpdate?.call("Retrying");
            },
            onPinEntering: () {
              print("PIN entry required...");
              callbacks?.onStatusUpdate?.call("Please enter your PIN");
              callbacks?.onCardReaderUpdate?.call("Enter PIN");
            },
            onReaderFinished: () {
              print("Reader finished");
              callbacks?.onStatusUpdate?.call("Processing transaction...");
              callbacks?.onCardReaderUpdate?.call("Processing");
            },
            onReaderError: (message) {
              print("Reader error: $message");
              callbacks?.onStatusUpdate?.call("Reader error: $message");
              callbacks?.onCardReaderUpdate?.call("Error: $message");
            },
            onCardReadSuccess: () {
              print("Card read successfully");
              callbacks?.onStatusUpdate?.call("Card read successfully");
              callbacks?.onCardReaderUpdate?.call("Card read success");
            },
            onCardReadFailure: (message) {
              print("Card read failure: $message");
              callbacks?.onStatusUpdate?.call("Card read failed: $message");
              callbacks?.onCardReaderUpdate?.call("Card read failed");
            },
          ),

          onSendTransactionFailure: (message) {
            print("Transaction failed: $message");
            _status = TransactionStatus.failed;
            final result = NearPayResult.failure(
              message: "Transaction failed: $message",
              error: NearPayError.transactionFailed,
            );

            if (!completer.isCompleted) {
              completer.complete(result);
            }

            callbacks?.onTransactionCompleted?.call(result);
          },
          onTransactionPurchaseCompleted: (PurchaseResponse transactionResponse) {
            print("Transaction completed: $transactionResponse");
            _status = TransactionStatus.completed;

            final result = NearPayResult.success(
              message: "Transaction completed successfully",
              response: transactionResponse,
            );

            if (!completer.isCompleted) {
              completer.complete(result);
            }
            callbacks?.onTransactionCompleted?.call(result);
          },
        ),
      );

      // Wait for transaction completion
      return await completer.future;
    } catch (e) {
      print("Error in direct purchase: $e");
      _status = TransactionStatus.failed;
      return NearPayResult.failure(
        message: "Error processing direct payment: $e",
        error: NearPayError.transactionFailed,
      );
    }
  }

  Future<NearPayResult> refundDirectly({
    required double amount,
    PaymentScheme? scheme,
    String? customerReferenceNumber,
    required String transactionUuid,
    required String refundUuid,
    DirectPaymentCallbacks? callbacks,
  }) async
  {
    print("Refund test - please login first");

    try {
      if (_terminal == null) {
        print("No terminal available - please login first");
        return NearPayResult.failure(
          message: "No terminal available - please login first",
          error: NearPayError.loginFailed,
        );
      }

      _status = TransactionStatus.processing;
      _currentPaymentCallbacks = callbacks;

      callbacks?.onStatusUpdate?.call("Starting direct payment...");

      // Generate unique transaction UUID
      final amountInCents = (amount * 100).round();
      callbacks?.onStatusUpdate?.call("Preparing payment terminal...");
      // Create completer for async callback handling
      final completer = Completer<NearPayResult>();
      // Start direct payment on terminal (your approach)
      //          transactionUuid:"28885c93-82f4-412d-88ca-0246692a3ffd" ,
      //           customerReferenceNumber: customerReferenceNumber,
      //           callbacks: callbacks,
      //           refundUuid: "28885c93-84f4-412d-88ca-0246622a2ffd"
      print("terminal:${_terminal!.terminalUUID}");
      await _terminal!.refund(
        transactionUuid: "28885c93-82f4-412d-88ca-0246692a3ffd",
        amount: 100,
        scheme: null,
        customerReferenceNumber: customerReferenceNumber ?? "",
        refundUuid: "28885c93-84f4-412d-88ca-0246622a2ffd",
        callbacks: RefundCallbacks(
          cardReaderCallbacks: CardReaderCallbacks(
            onReadingStarted: () {
              print("Reading started...");
              callbacks?.onStatusUpdate?.call("Reading started...");
              callbacks?.onCardReaderUpdate?.call("Reading started");
            },
            onReaderDisplayed: () {
              print("Reader displayed");
              callbacks?.onStatusUpdate?.call("Reader displayed");
              callbacks?.onCardReaderUpdate?.call("Reader displayed");
            },
            onReaderClosed: () {
              print("Reader closed");
              callbacks?.onStatusUpdate?.call("Reader closed");
              callbacks?.onCardReaderUpdate?.call("Reader closed");
            },
            onReaderWaiting: () {
              print("Reader waiting...");
              callbacks?.onStatusUpdate?.call("Please present your card");
              callbacks?.onCardReaderUpdate?.call("Waiting for card");
            },
            onReaderReading: () {
              print("Reader reading...");
              callbacks?.onStatusUpdate?.call("Reading card...");
              callbacks?.onCardReaderUpdate?.call("Reading card");
            },
            onReaderRetry: () {
              print("Reader retrying...");
              callbacks?.onStatusUpdate?.call("Please try again");
              callbacks?.onCardReaderUpdate?.call("Retrying");
            },
            onPinEntering: () {
              print("PIN entry required...");
              callbacks?.onStatusUpdate?.call("Please enter your PIN");
              callbacks?.onCardReaderUpdate?.call("Enter PIN");
            },
            onReaderFinished: () {
              print("Reader finished");
              callbacks?.onStatusUpdate?.call("Processing transaction...");
              callbacks?.onCardReaderUpdate?.call("Processing");
            },
            onReaderError: (message) {
              print("Reader error: $message");
              callbacks?.onStatusUpdate?.call("Reader error: $message");
              callbacks?.onCardReaderUpdate?.call("Error: $message");
            },
            onCardReadSuccess: () {
              print("Card read successfully");
              callbacks?.onStatusUpdate?.call("Card read successfully");
              callbacks?.onCardReaderUpdate?.call("Card read success");
            },
            onCardReadFailure: (message) {
              print("Card read failure: $message");
              callbacks?.onStatusUpdate?.call("Card read failed: $message");
              callbacks?.onCardReaderUpdate?.call("Card read failed");
            },
          ),

          onSendTransactionFailure: (message) {
            print("Transaction failed: $message");
            _status = TransactionStatus.failed;
            final result = NearPayResult.failure(
              message: "Transaction failed: $message",
              error: NearPayError.transactionFailed,
            );

            if (!completer.isCompleted) {
              completer.complete(result);
            }
            callbacks?.onTransactionCompleted?.call(result);
          },
          onTransactionRefundCompleted: (PurchaseResponse transactionResponse) {
            print("Transaction completed: $transactionResponse");
            _status = TransactionStatus.completed;

            final result = NearPayResult.success(
              message: "Transaction completed successfully",
              response: transactionResponse,
            );

            if (!completer.isCompleted) {
              completer.complete(result);
            }
            callbacks?.onTransactionCompleted?.call(result);
          },
        ),
      );

      // Wait for transaction completion
      return await completer.future;
    } catch (e) {
      print("Error in direct purchase: $e");
      _status = TransactionStatus.failed;
      return NearPayResult.failure(
        message: "Error processing direct payment: $e",
        error: NearPayError.transactionFailed,
      );
    }
  }



}
