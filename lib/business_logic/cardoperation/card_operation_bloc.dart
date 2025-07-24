import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_smart_pin_pad_cards/flutter_smart_pin_pad_cards.dart';
import 'package:flutter_smart_pin_pad_cards/pinpad_model.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

import '../../enum/pinpad.dart';
import '../../network_service.dart';

part 'card_operation_event.dart';
part 'card_operation_state.dart';
part 'card_operation_bloc.freezed.dart';

class CardOperationBloc extends Bloc<CardOperationEvent, CardOperationState> {
  CardOperationBloc() : super(const CardOperationState.initial()) {
    on<CardOperationStartReading>(_onStartReading);
    on<CardOperationConfirmCard>(_onConfirmCard);
    on<CardOperationEnterPin>(_onEnterPin);
    on<CardOperationConfirmPin>(_onConfirmPin);
    on<CardOperationProcessOperation>(_onProcessOperation);
    on<CardOperationCancel>(_onCancel);
    on<CardOperationTimeout>(_onTimeout);
    on<CardOperationReset>(_onReset);
  }

  Future<void> _onStartReading(
      CardOperationStartReading event,
      Emitter<CardOperationState> emit,
      ) async {
    emit(CardOperationState.reading(
      operationType: event.operationType,
      remainingTime: 60,
    ));

    try {
      final cardData = await FlutterSmartPinPadCards.startInsertCardReading(
        enableMag: true,
        enableIcc: true,
        enableRf: false,
        timeout: 60000,
      );

      if (cardData != null) {
        emit(CardOperationState.cardRead(
          operationType: event.operationType,
          cardData: cardData,
        ));
      } else {
        emit(const CardOperationState.error(
          message: 'No card data received',
        ));
      }
    } catch (e) {
      await FlutterSmartPinPadCards.stopInsertCardReading();
      emit(CardOperationState.error(
        message: 'Card reading failed: $e',
      ));
    }
  }

  Future<void> _onConfirmCard(
      CardOperationConfirmCard event,
      Emitter<CardOperationState> emit,
      ) async {
    state.maybeWhen(
      cardRead: (operationType, cardData) {
        switch (operationType) {
          case CardOperationType.createPin:
            emit(CardOperationState.pinEntry(
              operationType: operationType,
              cardData: cardData,
              step: PinEntryStep.createPin,
              remainingTime: 30,
            ));
            break;
          case CardOperationType.changePin:
            emit(CardOperationState.pinEntry(
              operationType: operationType,
              cardData: cardData,
              step: PinEntryStep.enterCurrentPin,
              remainingTime: 30,
            ));
            break;
          case CardOperationType.otorisation:
            emit(CardOperationState.pinEntry(
              operationType: operationType,
              cardData: cardData,
              step: PinEntryStep.enterCurrentPin,
              remainingTime: 30,
            ));
            break;
        }
      },
      orElse: () {},
    );
  }

  Future<void> _onEnterPin(
      CardOperationEnterPin event,
      Emitter<CardOperationState> emit,
      ) async {
    state.maybeWhen(
      pinEntry: (operationType, cardData, step, remainingTime, currentPin, newPin) {
        switch (step) {
          case PinEntryStep.enterCurrentPin:
            if (operationType == CardOperationType.otorisation) {
              // For authorization, process immediately
              add(CardOperationEvent.processOperation(
                currentPin: event.pin,
                newPin: null,
              ));
            } else {
              // For change PIN, move to new PIN entry
              emit(CardOperationState.pinEntry(
                operationType: operationType,
                cardData: cardData,
                step: PinEntryStep.createPin,
                remainingTime: 30,
                currentPin: event.pin,
              ));
            }
            break;
          case PinEntryStep.createPin:
            emit(CardOperationState.pinEntry(
              operationType: operationType,
              cardData: cardData,
              step: PinEntryStep.confirmPin,
              remainingTime: 30,
              currentPin: currentPin,
              newPin: event.pin,
            ));
            break;
          case PinEntryStep.confirmPin:
            if (event.pin == newPin) {
              add(CardOperationEvent.processOperation(
                currentPin: currentPin,
                newPin: newPin,
              ));
            } else {
              emit(const CardOperationState.error(
                message: 'PINs do not match. Please try again.',
              ));
            }
            break;
        }
      },
      orElse: () {},
    );
  }

  Future<void> _onConfirmPin(
      CardOperationConfirmPin event,
      Emitter<CardOperationState> emit,
      ) async {
    add(CardOperationEvent.processOperation(
      currentPin: event.currentPin,
      newPin: event.newPin,
    ));
  }

  Future<void> _onProcessOperation(
      CardOperationProcessOperation event,
      Emitter<CardOperationState> emit,
      ) async {
    await state.maybeWhen(
      pinEntry: (operationType, cardData, step, remainingTime, currentPin, newPin) async {
        emit(CardOperationState.processing(
          operationType: operationType,
          cardData: cardData,
        ));

        try {
          // Generate PIN blocks
          String? currentPinBlock;
          String? newPinBlock;

          switch (operationType) {
            case CardOperationType.createPin:
              newPinBlock = await _generatePinBlock(event.newPin!, cardData);
              break;
            case CardOperationType.changePin:
              currentPinBlock = await _generatePinBlock(event.currentPin!, cardData);
              newPinBlock = await _generatePinBlock(event.newPin!, cardData);
              break;
            case CardOperationType.otorisation:
              currentPinBlock = await _generatePinBlock(event.currentPin!, cardData);
              break;
          }

          // Convert to PinOperationType
          PinOperationType pinOperationType;
          switch (operationType) {
            case CardOperationType.createPin:
              pinOperationType = PinOperationType.createPin;
              break;
            case CardOperationType.changePin:
              pinOperationType = PinOperationType.changePin;
              break;
            case CardOperationType.otorisation:
              pinOperationType = PinOperationType.authorization;
              break;
          }

          // Send to server
          final response = await NetworkService.sendPinOperation(
            operationType: pinOperationType,
            systemsTraceNo: DateTime.now().millisecondsSinceEpoch.toString().substring(7),
            terminalId: 'T3000001',
            merchantId: 'BANKJATENG00001',
            track2Data: cardData.track2 ?? '',
            currentPinBlock: currentPinBlock,
            newPinBlock: newPinBlock,
            newPin: operationType == CardOperationType.createPin ? event.newPin : null,
          );

          if (response.success) {
            emit(CardOperationState.success(
              operationType: operationType,
              response: response,
              remainingTime: 10,
            ));
          } else {
            emit(CardOperationState.error(
              message: response.errorMessage ?? 'Operation failed',
            ));
          }
        } catch (e) {
          emit(CardOperationState.error(
            message: 'Error processing PIN: $e',
          ));
        }
      },
      orElse: () async {},
    );
  }

  Future<void> _onCancel(
      CardOperationCancel event,
      Emitter<CardOperationState> emit,
      ) async {
    await FlutterSmartPinPadCards.stopInsertCardReading();
    emit(const CardOperationState.cancelled());
  }

  Future<void> _onTimeout(
      CardOperationTimeout event,
      Emitter<CardOperationState> emit,
      ) async {
    await FlutterSmartPinPadCards.stopInsertCardReading();
    emit(const CardOperationState.error(
      message: 'Operation timed out',
    ));
  }

  Future<void> _onReset(
      CardOperationReset event,
      Emitter<CardOperationState> emit,
      ) async {
    emit(const CardOperationState.initial());
  }

  Future<String?> _generatePinBlock(String pin, CardData cardData) async {
    try {
      // Try dynamic PIN block generation first
      final result = await FlutterSmartPinPadCards.createDynamicPinBlock(
        pin: pin,
        cardNumber: cardData.cardNumber,
        format: FlutterSmartPinPadCards.PIN_BLOCK_FORMAT_0,
        encryptionType: FlutterSmartPinPadCards.ENCRYPT_3DES,
        useHardwareEncryption: true,
      );

      if (result.success && result.pinBlock != null) {
        return result.pinBlock;
      }

      // Fallback to legacy method
      final legacyResult = await FlutterSmartPinPadCards.createPinBlock(
        pin: pin,
        cardNumber: cardData.cardNumber,
        format: FlutterSmartPinPadCards.PIN_BLOCK_FORMAT_0,
        keyIndex: 0,
        encryptionType: FlutterSmartPinPadCards.ENCRYPT_3DES,
      );

      if (legacyResult.success && legacyResult.pinBlock != null) {
        return legacyResult.pinBlock;
      }

      // Last resort fallback
      return _generateFallbackPinBlock(pin, cardData.cardNumber);
    } catch (e) {
      return _generateFallbackPinBlock(pin, cardData.cardNumber);
    }
  }

  String _generateFallbackPinBlock(String pin, String cardNumber) {
    String pinPart = '0${pin.length}$pin';
    while (pinPart.length < 16) {
      pinPart += 'F';
    }

    String panDigits = cardNumber.replaceAll(RegExp(r'[^0-9]'), '');
    String panPart = '0000' + panDigits.substring(panDigits.length - 13, panDigits.length - 1);
    while (panPart.length < 16) {
      panPart = '0$panPart';
    }

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
}