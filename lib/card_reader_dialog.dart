import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_smart_pin_pad_cards/flutter_smart_pin_pad_cards.dart';
import 'package:flutter_smart_pin_pad_cards/pinpad_model.dart';
import 'package:lottie/lottie.dart';

import 'network_service.dart';

enum CardOperationType { createPin, changePin, otorisation }

enum CardOperationStep {
  insertCard,
  loading,
  cardInfo,
  enterCurrentPin, // Untuk PIN Change - masukkan PIN lama
  createPin,       // Untuk PIN Create dan PIN Change (PIN baru)
  confirmPin,      // Konfirmasi PIN
  connecting,
  success,
  failed
}

class CardReaderDialog extends StatefulWidget {
  final CardOperationType operationType;

  const CardReaderDialog({
    Key? key,
    required this.operationType,
  }) : super(key: key);

  @override
  State<CardReaderDialog> createState() => _CardReaderDialogState();
}

class _CardReaderDialogState extends State<CardReaderDialog> {
  CardOperationStep _currentStep = CardOperationStep.insertCard;
  CardData? _cardData;
  String _errorMessage = '';
  bool _isLoading = false;

  // PIN entry controllers
  final TextEditingController _currentPinController = TextEditingController();
  final TextEditingController _pinController = TextEditingController();
  final TextEditingController _confirmPinController = TextEditingController();

  final FocusNode _currentPinFocusNode = FocusNode();
  final FocusNode _pinFocusNode = FocusNode();
  final FocusNode _confirmPinFocusNode = FocusNode();

  // Timers
  Timer? _pinEntryTimer;
  Timer? _successTimer;
  int _remainingPinTime = 30;
  int _remainingSuccessTime = 10;

  // Server communication
  static const String serverHost = '192.168.88.177'; // localhost
  static const int serverPort = 8082;

  // Transaction data
  String _systemsTraceNo = '';
  String _terminalId = 'T3000001';
  String _merchantId = 'BANKJATENG00001';

  @override
  void initState() {
    super.initState();
    _generateSystemsTraceNo();
    _startCardReading();
  }

  @override
  void dispose() {
    _pinEntryTimer?.cancel();
    _successTimer?.cancel();
    _currentPinController.dispose();
    _pinController.dispose();
    _confirmPinController.dispose();
    _currentPinFocusNode.dispose();
    _pinFocusNode.dispose();
    _confirmPinFocusNode.dispose();
    FlutterSmartPinPadCards.stopInsertCardReading();
    super.dispose();
  }

  void _generateSystemsTraceNo() {
    final now = DateTime.now();
    _systemsTraceNo = now.millisecondsSinceEpoch.toString().substring(7); // Last 6 digits
  }

  // Start reading the card (INSERT method)
  Future<void> _startCardReading() async {
    setState(() {
      _currentStep = CardOperationStep.insertCard;
      _isLoading = true;
    });

    try {
      print('Starting card reading with INSERT method...');

      // Start INSERT card reading (not swipe) - Updated to use new method
      final cardData = await FlutterSmartPinPadCards.startInsertCardReading(
        enableMag: true,  // Enable magnetic stripe
        enableIcc: true,  // Enable IC chip (main method)
        enableRf: false,  // Disable contactless for now
        timeout: 60000,   // 60 seconds timeout
      );

      if (cardData != null) {
        // print('Card reading successful: ${cardData.}');

        setState(() {
          _isLoading = false;
          _cardData = cardData;
          _currentStep = CardOperationStep.cardInfo;
        });
      } else {
        throw Exception('No card data received');
      }
    } catch (e) {
      print('Card reading error: $e');
      setState(() {
        _isLoading = false;
        _errorMessage = 'Card reading failed: $e';
        _currentStep = CardOperationStep.failed;
      });

      await FlutterSmartPinPadCards.stopInsertCardReading();
    }
  }

  // Proceed after card info confirmation
  void _onCardInfoConfirmed() {
    switch (widget.operationType) {
      case CardOperationType.createPin:
        _startPinCreation();
        break;
      case CardOperationType.changePin:
        _startEnterCurrentPin();
        break;
      case CardOperationType.otorisation:
        _startPinAuthorization();
        break;
    }
  }

  // Start PIN authorization (for Otorisasi)
  void _startPinAuthorization() {
    setState(() {
      _currentStep = CardOperationStep.enterCurrentPin;
      _remainingPinTime = 30;
    });

    _startPinTimer();
    _currentPinFocusNode.requestFocus();
  }

  // Start entering current PIN (for PIN Change)
  void _startEnterCurrentPin() {
    setState(() {
      _currentStep = CardOperationStep.enterCurrentPin;
      _remainingPinTime = 30;
    });

    _startPinTimer();
    _currentPinFocusNode.requestFocus();
  }

  // Start PIN creation
  void _startPinCreation() {
    setState(() {
      _currentStep = CardOperationStep.createPin;
      _remainingPinTime = 30;
    });

    _startPinTimer();
    _pinFocusNode.requestFocus();
  }

  // Start PIN timer
  void _startPinTimer() {
    _pinEntryTimer?.cancel();
    _pinEntryTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        if (_remainingPinTime > 0) {
          _remainingPinTime--;
        } else {
          timer.cancel();
          if (mounted) {
            _showTimeoutErrorAndClose('PIN entry timed out.');
          }
        }
      });
    });
  }

  // Move to PIN confirmation
  void _confirmPin() {
    _pinEntryTimer?.cancel();

    setState(() {
      _currentStep = CardOperationStep.confirmPin;
      _remainingPinTime = 30;
    });

    _startPinTimer();
    _confirmPinFocusNode.requestFocus();
  }

  // Updated PIN block generation method using the new dynamic PIN block system
  Future<String?> _generatePinBlock(String pin) async {
    if (pin.isEmpty || _cardData == null || _cardData!.cardNumber.isEmpty) {
      print('❌ Cannot generate PIN block: Missing PIN or card number');
      return null;
    }

    try {
      print('🔐 Creating PIN block for PIN: ${pin.replaceAll(RegExp(r'.'), '*')}');
      print('🔢 Card number: ${_cardData!.cardNumber.substring(0, 6)}...${_cardData!.cardNumber.substring(_cardData!.cardNumber.length - 4)}');

      // Try the new dynamic PIN block system first
      try {
        final result = await FlutterSmartPinPadCards.createDynamicPinBlock(
          pin: pin,
          cardNumber: _cardData!.cardNumber,
          format: FlutterSmartPinPadCards.PIN_BLOCK_FORMAT_0,
          encryptionType: FlutterSmartPinPadCards.ENCRYPT_3DES,
          useHardwareEncryption: true,
        );

        if (result.success && result.pinBlock != null) {
          print('✅ Dynamic PIN block generated successfully: ${result.pinBlock}');
          return result.pinBlock;
        } else {
          print('⚠️ Dynamic PIN block failed: ${result.error}');
          // Fall back to legacy method
        }
      } catch (e) {
        print('⚠️ Dynamic PIN block exception: $e');
        // Fall back to legacy method
      }

      // Fallback to legacy PIN block method
      print('🔄 Falling back to legacy PIN block method...');
      final legacyResult = await FlutterSmartPinPadCards.createPinBlock(
        pin: pin,
        cardNumber: _cardData!.cardNumber,
        format: FlutterSmartPinPadCards.PIN_BLOCK_FORMAT_0,
        keyIndex: 0,
        encryptionType: FlutterSmartPinPadCards.ENCRYPT_3DES,
      );

      if (legacyResult.success && legacyResult.pinBlock != null) {
        print('✅ Legacy PIN block generated successfully: ${legacyResult.pinBlock}');
        return legacyResult.pinBlock;
      } else {
        print('❌ Legacy PIN block generation failed: ${legacyResult.error}');

        // Last resort: Generate a simple PIN block for testing
        // NOTE: This should only be used for testing/development
        print('🚨 Using fallback PIN block generation (TESTING ONLY)');
        return _generateFallbackPinBlock(pin, _cardData!.cardNumber);
      }
    } catch (e) {
      print('❌ Error generating PIN block: $e');

      // Last resort fallback
      return _generateFallbackPinBlock(pin, _cardData!.cardNumber);
    }
  }

  // Fallback PIN block generation for testing (NOT SECURE!)
  String _generateFallbackPinBlock(String pin, String cardNumber) {
    print('⚠️ WARNING: Using fallback PIN block generation - NOT SECURE!');

    // Simple PIN block format (ISO 9564-1 Format 0 simulation)
    String pinPart = '0${pin.length}$pin';
    while (pinPart.length < 16) {
      pinPart += 'F';
    }

    // Simple PAN part
    String panDigits = cardNumber.replaceAll(RegExp(r'[^0-9]'), '');
    String panPart = '0000' + panDigits.substring(panDigits.length - 13, panDigits.length - 1);
    while (panPart.length < 16) {
      panPart = '0$panPart';
    }

    // Simple XOR (for testing only)
    List<int> pinBytes = [];
    List<int> panBytes = [];

    for (int i = 0; i < 16; i += 2) {
      pinBytes.add(int.parse(pinPart.substring(i, i + 2), radix: 16));
      panBytes.add(int.parse(panPart.substring(i, i + 2), radix: 16));
    }

    String result = '';
    for (int i = 0; i < 8; i++) {
      int xor = pinBytes[i] ^ panBytes[i];
      result += xor.toRadixString(16).padLeft(2, '0').toUpperCase();
    }

    return result;
  }

  // Process the PIN operation - Updated to work with enhanced PIN block system
  Future<void> _processPin() async {
    _pinEntryTimer?.cancel();

    // Validate PIN match for confirmation step
    if (_currentStep == CardOperationStep.confirmPin &&
        _pinController.text != _confirmPinController.text) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('PINs do not match. Please try again.')),
      );
      _confirmPinController.clear();
      _confirmPinFocusNode.requestFocus();
      setState(() {
        _remainingPinTime = 30;
      });
      _startPinTimer();
      return;
    }

    setState(() {
      _currentStep = CardOperationStep.connecting;
    });

    try {
      // Generate PIN blocks based on operation type using the enhanced system
      String? currentPinBlock;
      String? newPinBlock;

      switch (widget.operationType) {
        case CardOperationType.createPin:
        // For Create PIN, use the new dynamic createPinDynamic method
          try {
            final result = await FlutterSmartPinPadCards.createPinDynamic(
              newPin: _pinController.text,
              cardNumber: _cardData!.cardNumber,
              format: FlutterSmartPinPadCards.PIN_BLOCK_FORMAT_0,
              encryptionType: FlutterSmartPinPadCards.ENCRYPT_3DES,
              useHardwareEncryption: true,
            );

            if (result.success && result.pinBlock != null) {
              newPinBlock = result.pinBlock;
              print('✅ Create PIN Block dynamic successful: $newPinBlock');
            } else {
              // Fallback to regular PIN block generation
              newPinBlock = await _generatePinBlock(_pinController.text);
            }
          } catch (e) {
            print('⚠️ CreatePinDynamic failed, using fallback: $e');
            newPinBlock = await _generatePinBlock(_pinController.text);
          }
          break;

        case CardOperationType.changePin:
        // For Change PIN, use the new dynamic changePinDynamic method
          try {
            final result = await FlutterSmartPinPadCards.changePinDynamic(
              currentPin: _currentPinController.text,
              newPin: _pinController.text,
              cardNumber: _cardData!.cardNumber,
              format: FlutterSmartPinPadCards.PIN_BLOCK_FORMAT_0,
              encryptionType: FlutterSmartPinPadCards.ENCRYPT_3DES,
              useHardwareEncryption: true,
            );

            if (result.success && result.oldPinBlock != null && result.newPinBlock != null) {
              currentPinBlock = result.oldPinBlock;
              newPinBlock = result.newPinBlock;
              print('✅ Change PIN dynamic successful');
            } else {
              // Fallback to regular PIN block generation
              currentPinBlock = await _generatePinBlock(_currentPinController.text);
              newPinBlock = await _generatePinBlock(_pinController.text);
            }
          } catch (e) {
            print('⚠️ ChangePinDynamic failed, using fallback: $e');
            currentPinBlock = await _generatePinBlock(_currentPinController.text);
            newPinBlock = await _generatePinBlock(_pinController.text);
          }
          break;

        case CardOperationType.otorisation:
        // For PIN Authorization, use the new dynamic authorizePinDynamic method
          try {
            final result = await FlutterSmartPinPadCards.authorizePinDynamic(
              pin: _currentPinController.text,
              cardNumber: _cardData!.cardNumber,
              transactionAmount: 100000, // Example amount
              format: FlutterSmartPinPadCards.PIN_BLOCK_FORMAT_0,
              encryptionType: FlutterSmartPinPadCards.ENCRYPT_3DES,
              useHardwareEncryption: true,
            );

            if (result.success && result.pinBlock != null) {
              currentPinBlock = result.pinBlock;
              print('✅ Authorize PIN dynamic successful: ${result.isAuthorized}');
            } else {
              // Fallback to regular PIN block generation
              currentPinBlock = await _generatePinBlock(_currentPinController.text);
            }
          } catch (e) {
            print('⚠️ AuthorizePinDynamic failed, using fallback: $e');
            currentPinBlock = await _generatePinBlock(_currentPinController.text);
          }
          break;
      }

      // Check if PIN block generation was successful
      if ((widget.operationType == CardOperationType.createPin && newPinBlock == null) ||
          (widget.operationType == CardOperationType.changePin && (currentPinBlock == null || newPinBlock == null)) ||
          (widget.operationType == CardOperationType.otorisation && currentPinBlock == null)) {
        throw Exception('Failed to generate required PIN blocks');
      }

      // Convert CardOperationType to PinOperationType
      PinOperationType operationType;
      switch (widget.operationType) {
        case CardOperationType.createPin:
          operationType = PinOperationType.createPin;
          break;
        case CardOperationType.changePin:
          operationType = PinOperationType.changePin;
          break;
        case CardOperationType.otorisation:
          operationType = PinOperationType.authorization;
          break;
      }

      // Send operation to NetworkService
      final response = await NetworkService.sendPinOperation(
        operationType: operationType,
        systemsTraceNo: _systemsTraceNo,
        terminalId: _terminalId,
        merchantId: _merchantId,
        track2Data: _cardData?.track2 ?? '',
        currentPinBlock: currentPinBlock,
        newPinBlock: newPinBlock,
        newPin: widget.operationType == CardOperationType.createPin ? _pinController.text : null,
      );

      if (response.success) {
        setState(() {
          _currentStep = CardOperationStep.success;
          _remainingSuccessTime = 10;
        });

        _successTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
          setState(() {
            if (_remainingSuccessTime > 0) {
              _remainingSuccessTime--;
            } else {
              timer.cancel();
              if (mounted) {
                Navigator.of(context).pop(true);
              }
            }
          });
        });
      } else {
        setState(() {
          _currentStep = CardOperationStep.failed;
          _errorMessage = response.errorMessage ?? 'Operation failed';
        });
      }
    } catch (e) {
      print('❌ Error processing PIN: $e');
      setState(() {
        _currentStep = CardOperationStep.failed;
        _errorMessage = 'Error: $e';
      });
    }
  }

  // Send request to server
  Future<bool> _sendRequestToServer() async {
    try {
      print('Connecting to server $serverHost:$serverPort...');

      final socket = await Socket.connect(serverHost, serverPort);
      print('Connected to server successfully');

      // Build ISO 8583 message
      final isoMessage = _buildISOMessage();
      print('ISO Message built: $isoMessage');

      // Convert to bytes and send
      final messageBytes = utf8.encode(isoMessage);
      final messageLength = messageBytes.length;

      // Send length header (2 bytes) + message
      final lengthBytes = Uint8List(2);
      lengthBytes[0] = (messageLength >> 8) & 0xFF;
      lengthBytes[1] = messageLength & 0xFF;

      socket.add(lengthBytes);
      socket.add(messageBytes);

      print('Request sent to server');
      print('Message length: $messageLength');
      print('Message: $isoMessage');

      // Read response
      final responseData = await socket.first;
      socket.close();

      // Parse response (skip length header)
      final responseMessage = utf8.decode(responseData.skip(2).toList());
      print('Response received: $responseMessage');

      // Check response code (field 39)
      return _parseResponse(responseMessage);

    } catch (e) {
      print('Server communication error: $e');
      return false;
    }
  }

  // Replace the _buildISOMessage method in _CardReaderDialogState class
  String _buildISOMessage() {
    final StringBuffer message = StringBuffer();

    // MTI
    message.write('0100');

    // Build bitmap and fields
    final fields = <int, String>{};

    // Set processing code based on operation type
    switch (widget.operationType) {
      case CardOperationType.createPin:
        fields[3] = '920000'; // Create PIN
        break;
      case CardOperationType.changePin:
        fields[3] = '930000'; // Change PIN
        break;
      case CardOperationType.otorisation:
        fields[3] = '940000'; // PIN Authorization
        break;
    }

    fields[11] = _systemsTraceNo.padLeft(6, '0'); // Systems Trace No
    fields[35] = _cardData?.track2 ?? ''; // Track 2 Data
    fields[41] = _terminalId.padRight(8, ' '); // Terminal ID
    fields[42] = _merchantId.padRight(15, ' '); // Merchant ID

    // Add PIN blocks based on operation type
    switch (widget.operationType) {
      case CardOperationType.createPin:
      // For Create PIN (920000): Send new PIN block in field 52
        fields[52] = _formatPinBlock('', _pinController.text);

        // Optional: Add the PIN in field 48 (private use)
        // fields[48] = 'NEWPIN=${_pinController.text.padLeft(6, '0')}';
        fields[48] = _pinController.text.padLeft(6, '0');

        break;

      case CardOperationType.changePin:
      // For Change PIN (930000): Send both old and new PIN blocks
      // Primary PIN block (new) in field 52
        fields[52] = _formatPinBlock('', _pinController.text);

        // Both PIN blocks in field 48
        fields[48] = _formatPinBlock('', _currentPinController.text) +
            _formatPinBlock('', _pinController.text);


        // fields[48] = 'OLDPINBLOCK=${_formatPinBlock('', _currentPinController.text)};' +
        //     'NEWPINBLOCK=${_formatPinBlock('', _pinController.text)}';
        break;

      case CardOperationType.otorisation:
      // For PIN Authorization (940000): Send current PIN block in field 52
        fields[52] = _formatPinBlock('', _currentPinController.text);
        break;
    }

    // Build bitmap
    final bitmap = _buildBitmap(fields.keys.toList());
    message.write(bitmap);

    // Add fields in order
    for (int i = 1; i <= 64; i++) {
      if (fields.containsKey(i)) {
        final fieldData = _formatField(i, fields[i]!);
        message.write(fieldData);
      }
    }

    return message.toString();
  }

  // Build bitmap in hex format
  String _buildBitmap(List<int> fieldNumbers) {
    final bitmap = List<int>.filled(8, 0);

    for (final fieldNum in fieldNumbers) {
      if (fieldNum >= 1 && fieldNum <= 64) {
        final byteIndex = (fieldNum - 1) ~/ 8;
        final bitIndex = 7 - ((fieldNum - 1) % 8);
        bitmap[byteIndex] |= (1 << bitIndex);
      }
    }

    return bitmap.map((b) => b.toRadixString(16).padLeft(2, '0')).join().toUpperCase();
  }

  // Format field based on field number
  String _formatField(int fieldNum, String value) {
    switch (fieldNum) {
      case 3:
      case 11:
      case 41:
      case 42:
        return value;
      case 35: // Track 2 with length prefix
        return '${value.length.toString().padLeft(2, '0')}$value';
      case 48: // Private use with length prefix
        return '${value.length.toString().padLeft(4, '0')}$value';
      case 52: // PIN block
        return value;
      default:
        return value;
    }
  }

  // Format private use field (field 48)
  String _formatPrivateUse(String currentPin, String newPin) {
    if (widget.operationType == CardOperationType.changePin) {
      return '${currentPin.padLeft(6, '0')};${newPin.padLeft(6, '0')}';
    }

    // if (widget.operationType == CardOperationType.changePin) {
    //   return 'OLDPIN=${currentPin.padLeft(6, '0')};NEWPIN=${newPin.padLeft(6, '0')}';
    // }
    return newPin.padLeft(6, '0');
  }

  // Format PIN block (simplified)
  String _formatPinBlock(String currentPin, String pin) {
    final pinToUse = pin.isNotEmpty ? pin : currentPin;
    final pinBlock = pinToUse.padLeft(6, '0').padRight(32, '0');
    return pinBlock;
  }

  // Parse server response
  bool _parseResponse(String response) {
    try {
      print('🔍 Parsing response: $response');

      if (response.length < 20) {
        print('❌ Response too short: ${response.length}');
        return false;
      }

      // Extract MTI
      final mti = response.substring(0, 4);
      print('📋 Response MTI: $mti');

      if (mti != '0110') {
        print('❌ Invalid MTI: $mti (expected 0110)');
        return false;
      }

      // Extract bitmap
      final bitmapHex = response.substring(4, 20);
      print('🗺️ Response bitmap: $bitmapHex');
      final bitmap = _hexToBytes(bitmapHex);

      // Find response code (field 39)
      int offset = 20;
      for (int i = 1; i <= 64; i++) {
        if (_isBitSet(bitmap, i - 1)) {
          print('🔍 Processing field $i at offset $offset');

          if (i == 39) {
            // Response code field
            final responseCode = response.substring(offset, offset + 2);
            print('✅ Response code: $responseCode');
            return responseCode == '00'; // Success
          }
          // Skip other fields (simplified parsing)
          offset += _getFieldLength(i, response, offset);
        }
      }

      print('❌ Response code field (39) not found');
      return false;
    } catch (e) {
      print('❌ Error parsing response: $e');
      return false;
    }
  }

  // Helper methods
  List<int> _hexToBytes(String hex) {
    final bytes = <int>[];
    for (int i = 0; i < hex.length; i += 2) {
      bytes.add(int.parse(hex.substring(i, i + 2), radix: 16));
    }
    return bytes;
  }

  bool _isBitSet(List<int> bitmap, int position) {
    final byteIndex = position ~/ 8;
    final bitIndex = 7 - (position % 8);
    return (bitmap[byteIndex] & (1 << bitIndex)) != 0;
  }

  int _getFieldLength(int fieldNum, String response, int offset) {
    switch (fieldNum) {
      case 3: return 6;
      case 11: return 6;
      case 37: return 12;
      case 38: return 6;
      case 39: return 2;
      case 41: return 8;
      case 42: return 15;
      default: return 0;
    }
  }

  // Handle current PIN submission
  void _onCurrentPinSubmitted() {
    if (_currentPinController.text.length != 6) {
      return;
    }

    if (widget.operationType == CardOperationType.otorisation) {
      // For authorization, process directly
      _processPin();
    } else {
      // For change PIN, go to new PIN creation
      _pinEntryTimer?.cancel();
      _startPinCreation();
    }
  }

  // Show timeout error and close
  void _showTimeoutErrorAndClose(String message) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Timeout'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _cancelOperation();
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  // Cancel operation
  void _cancelOperation() async {
    _pinEntryTimer?.cancel();
    _successTimer?.cancel();
    await FlutterSmartPinPadCards.stopInsertCardReading();
    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    String dialogTitle = _getDialogTitle();

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 400, maxHeight: 600),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                dialogTitle,
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: SingleChildScrollView(
                  child: _buildCurrentStepContent(),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: _buildDialogActions(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _getDialogTitle() {
    switch (widget.operationType) {
      case CardOperationType.createPin:
        return 'Create PIN';
      case CardOperationType.changePin:
        return 'Change PIN';
      case CardOperationType.otorisation:
        return 'PIN Authorization';
    }
  }

  Widget _buildCurrentStepContent() {
    switch (_currentStep) {
      case CardOperationStep.insertCard:
        return _buildInsertCardScreen();
      case CardOperationStep.loading:
        return _buildLoadingScreen('Reading card...');
      case CardOperationStep.cardInfo:
        return _buildCardInfoScreen();
      case CardOperationStep.enterCurrentPin:
        return _buildCurrentPinEntryScreen();
      case CardOperationStep.createPin:
        return _buildPinEntryScreen(isConfirmation: false);
      case CardOperationStep.confirmPin:
        return _buildPinEntryScreen(isConfirmation: true);
      case CardOperationStep.connecting:
        return _buildLoadingScreen('Connecting to server...');
      case CardOperationStep.success:
        return _buildSuccessScreen();
      case CardOperationStep.failed:
        return _buildFailedScreen();
    }
  }

  List<Widget> _buildDialogActions() {
    switch (_currentStep) {
      case CardOperationStep.insertCard:
        return [
          ElevatedButton(
            onPressed: _cancelOperation,
            child: const Text('Cancel'),
          ),
        ];
      case CardOperationStep.cardInfo:
        return [
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('No'),
          ),
          ElevatedButton(
            onPressed: _onCardInfoConfirmed,
            child: const Text('Yes'),
          ),
        ];
      case CardOperationStep.success:
        return [
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Done'),
          ),
        ];
      case CardOperationStep.failed:
        return [
          ElevatedButton(
            onPressed: _cancelOperation,
            child: const Text('Close'),
          ),
        ];
      default:
        return [
          ElevatedButton(
            onPressed: _cancelOperation,
            child: const Text('Cancel'),
          ),
        ];
    }
  }

  // Widget implementations for different screens...
  Widget _buildInsertCardScreen() {
    return SizedBox(
      width: 300,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.credit_card, size: 80, color: Colors.blue),
          const SizedBox(height: 16),
          Text(
            _getInsertCardMessage(),
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 16),
          ),
          const SizedBox(height: 8),
          if (_isLoading)  Lottie.asset('assets/Animation - 1747811274780.json',
          repeat: true,
          animate: true,
        ),
          // CircularProgressIndicator(),
        ],
      ),
    );
  }

  String _getInsertCardMessage() {
    switch (widget.operationType) {
      case CardOperationType.createPin:
        return 'Please insert your card to create a PIN';
      case CardOperationType.changePin:
        return 'Please insert your card to change your PIN';
      case CardOperationType.otorisation:
        return 'Please insert your card for PIN authorization';
    }
  }

  Widget _buildLoadingScreen(String message) {
    return SizedBox(
      width: 300,
      height: 200,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 24),
          Text(message, textAlign: TextAlign.center, style: const TextStyle(fontSize: 16)),
        ],
      ),
    );
  }

  Widget _buildCardInfoScreen() {
    return SizedBox(
      width: 300,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('Card Information', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.blue.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.blue.withOpacity(0.3)),
            ),
            child: Column(
              children: [
                _buildCardInfoRow('Card Number', _cardData?.getFormattedCardNumber() ?? 'Not available'),
                const SizedBox(height: 8),
                _buildCardInfoRow('Expiry Date', _cardData?.getFormattedExpiryDate() ?? 'Not available'),
                const SizedBox(height: 8),
                _buildCardInfoRow('Card Type', _cardData?.cardType ?? 'Not available'),
              ],
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'Do you want to continue with this card?',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildCardInfoRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text('$label:', style: const TextStyle(fontWeight: FontWeight.bold)),
        Text(value),
      ],
    );
  }

  Widget _buildCurrentPinEntryScreen() {
    return SizedBox(
      width: 300,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            widget.operationType == CardOperationType.otorisation
                ? 'Enter PIN for Authorization'
                : 'Enter Current PIN',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _currentPinController,
            focusNode: _currentPinFocusNode,
            decoration: const InputDecoration(
              labelText: 'PIN',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.lock_outline),
              hintText: '• • • • • •',
            ),
            keyboardType: TextInputType.number,
            obscureText: true,
            maxLength: 6,
            textAlign: TextAlign.center,
            onChanged: (value) {
              if (value.length == 6) {
                _onCurrentPinSubmitted();
              }
              setState(() {});
            },
          ),
          const SizedBox(height: 16),
          Text(
            'Time remaining: $_remainingPinTime seconds',
            style: TextStyle(
              color: _remainingPinTime <= 10 ? Colors.red : Colors.grey,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _currentPinController.text.length == 6 ? _onCurrentPinSubmitted : null,
            style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 48)),
            child: const Text('Continue'),
          ),
        ],
      ),
    );
  }

  Widget _buildPinEntryScreen({bool isConfirmation = false}) {
    final screenTitle = isConfirmation
        ? 'Confirm your PIN'
        : widget.operationType == CardOperationType.createPin
        ? 'Create your PIN'
        : 'Enter new PIN';

    return SizedBox(
      width: 300,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(screenTitle, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 20),
          TextField(
            controller: isConfirmation ? _confirmPinController : _pinController,
            focusNode: isConfirmation ? _confirmPinFocusNode : _pinFocusNode,
            decoration: InputDecoration(
              labelText: isConfirmation ? 'Confirm PIN' : 'PIN',
              border: const OutlineInputBorder(),
              prefixIcon: const Icon(Icons.lock_outline),
              hintText: '• • • • • •',
            ),
            keyboardType: TextInputType.number,
            obscureText: true,
            maxLength: 6,
            textAlign: TextAlign.center,
            onChanged: (value) {
              if (value.length == 6) {
                if (isConfirmation) {
                  _processPin();
                } else {
                  _confirmPin();
                }
              }
              setState(() {});
            },
          ),
          const SizedBox(height: 16),
          Text(
            'Time remaining: $_remainingPinTime seconds',
            style: TextStyle(
              color: _remainingPinTime <= 10 ? Colors.red : Colors.grey,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: (isConfirmation ? _confirmPinController.text.length == 6 : _pinController.text.length == 6)
                ? () {
              if (isConfirmation) {
                _processPin();
              } else {
                _confirmPin();
              }
            }
                : null,
            style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 48)),
            child: Text(isConfirmation ? 'Confirm PIN' : 'Continue'),
          ),
        ],
      ),
    );
  }

  Widget _buildSuccessScreen() {
    final successMessage = _getSuccessMessage();

    return SizedBox(
      width: 300,
      height: 200,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.check_circle, color: Colors.green, size: 60),
          const SizedBox(height: 24),
          Text(
            successMessage,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          Text(
            'Dialog will close in $_remainingSuccessTime seconds',
            style: const TextStyle(color: Colors.grey, fontSize: 14),
          ),
        ],
      ),
    );
  }

  String _getSuccessMessage() {
    switch (widget.operationType) {
      case CardOperationType.createPin:
        return 'PIN created successfully!';
      case CardOperationType.changePin:
        return 'PIN changed successfully!';
      case CardOperationType.otorisation:
        return 'PIN authorization successful!';
    }
  }

  Widget _buildFailedScreen() {
    return SizedBox(
      width: 300,
      height: 200,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error, color: Colors.red, size: 60),
          const SizedBox(height: 16),
          const Text(
            'Operation Failed',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          Text(
            _errorMessage,
            style: const TextStyle(color: Colors.red),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}