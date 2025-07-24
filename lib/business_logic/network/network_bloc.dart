import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_smart_pin_pad_cards/pinpad_model.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

import '../../network_service.dart';

part 'network_event.dart';
part 'network_state.dart';
part 'network_bloc.freezed.dart';

class NetworkBloc extends Bloc<NetworkEvent, NetworkState> {
  NetworkBloc() : super(NetworkState.initial()) {
    on<NetworkCheckConnection>(_onCheckConnection);
    on<NetworkCheckCapabilities>(_onCheckCapabilities);
    on<NetworkSendPinOperation>(_onSendPinOperation);
  }

  Future<void> _onCheckConnection(
      NetworkCheckConnection event,
      Emitter<NetworkState> emit,
      ) async {
    emit(state.copyWith(isCheckingConnection: true));

    try {
      final isConnected = await NetworkService.testConnection();
      emit(state.copyWith(
        isConnected: isConnected,
        isCheckingConnection: false,
      ));
    } catch (e) {
      emit(state.copyWith(
        isConnected: false,
        isCheckingConnection: false,
        errorMessage: 'Connection test failed: $e',
      ));
    }
  }

  Future<void> _onCheckCapabilities(
      NetworkCheckCapabilities event,
      Emitter<NetworkState> emit,
      ) async {
    emit(state.copyWith(
      isCheckingCapabilities: true,
      capabilityStatus: 'Checking server capabilities...',
      supportedOperations: {},
    ));

    // Test server connection first
    final isConnected = await NetworkService.testConnection();
    if (!isConnected) {
      emit(state.copyWith(
        isConnected: false,
        isCheckingCapabilities: false,
        capabilityStatus: 'Server not available - all operations disabled',
      ));
      return;
    }

    final Set<String> supportedOps = {};

    // Test each operation type
    final operationsToTest = [
      {'type': PinOperationType.createPin, 'code': '920000', 'name': 'Create PIN'},
      {'type': PinOperationType.changePin, 'code': '930000', 'name': 'Change PIN'},
      {'type': PinOperationType.authorization, 'code': '940000', 'name': 'PIN Authorization'},
    ];

    for (final operation in operationsToTest) {
      try {
        emit(state.copyWith(
          capabilityStatus: 'Testing ${operation['name']}...',
        ));

        final response = await NetworkService.sendPinOperation(
          operationType: operation['type'] as PinOperationType,
          systemsTraceNo: DateTime.now().millisecondsSinceEpoch.toString().substring(7),
          terminalId: 'T3000001',
          merchantId: 'BANKJATENG00001',
          track2Data: '4000000000000000D99991234567890',
          newPin: '000000',
        );

        // Response codes that indicate the operation is supported
        final supportedResponseCodes = ['00', '12', '55', '96', '91', '51', '14'];

        if (supportedResponseCodes.contains(response.responseCode)) {
          supportedOps.add(operation['code'] as String);
        }

        // Small delay between tests
        await Future.delayed(const Duration(milliseconds: 500));
      } catch (e) {
        // Operation test failed, continue to next
      }
    }

    emit(state.copyWith(
      isConnected: true,
      isCheckingCapabilities: false,
      supportedOperations: supportedOps,
      capabilityStatus: supportedOps.isEmpty
          ? 'No operations supported by server'
          : '${supportedOps.length}/3 operations available',
    ));
  }

  Future<void> _onSendPinOperation(
      NetworkSendPinOperation event,
      Emitter<NetworkState> emit,
      ) async {
    emit(state.copyWith(isProcessingOperation: true));

    try {
      final response = await NetworkService.sendPinOperation(
        operationType: event.operationType,
        systemsTraceNo: event.systemsTraceNo,
        terminalId: event.terminalId,
        merchantId: event.merchantId,
        track2Data: event.track2Data,
        currentPinBlock: event.currentPinBlock,
        newPinBlock: event.newPinBlock,
        newPin: event.newPin,
        amount: event.amount,
      );

      emit(state.copyWith(
        isProcessingOperation: false,
        lastOperationResponse: response,
      ));
    } catch (e) {
      emit(state.copyWith(
        isProcessingOperation: false,
        errorMessage: 'PIN operation failed: $e',
      ));
    }
  }
}
