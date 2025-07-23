import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_smart_pin_pad_cards/flutter_smart_pin_pad_cards.dart';
import 'package:flutter_smart_pin_pad_cards/pinpad_model.dart';
// import 'package:flutter_smart_pin_pad_cards/flutter_smart_pin_pad_cards.dart';

// Import files
import 'card_reader_dialog.dart';
import 'network_service.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  // Set preferred orientations
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown
  ]);

  // Initialize network service
  NetworkService.initialize();

  runApp(const BankJatengApp());
}

class BankJatengApp extends StatelessWidget {
  const BankJatengApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Bank Jateng PIN System',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: const MaterialColor(
          0xFF0D4575,
          <int, Color>{
            50: Color(0xFFE3EAF0),
            100: Color(0xFFB9CADB),
            200: Color(0xFF8BA6C3),
            300: Color(0xFF5D82AB),
            400: Color(0xFF3B6799),
            500: Color(0xFF0D4575),
            600: Color(0xFF0B3E6A),
            700: Color(0xFF08355C),
            800: Color(0xFF062D4F),
            900: Color(0xFF031E39),
          },
        ),
        useMaterial3: true,
        fontFamily: 'Roboto',
      ),
      supportedLocales: const [
        Locale('en'), // English
        Locale('id'), // Indonesian
      ],
      home: const SplashScreen(),
      routes: {
        '/splash': (context) => const SplashScreen(),
        '/login': (context) => const LoginPage(),
        '/home': (context) => const HomeScreen(),
      },
    );
  }
}

// Splash Screen
class SplashScreen extends StatefulWidget {
  const SplashScreen({Key? key}) : super(key: key);

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();

    _animationController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));

    _animationController.forward();

    // Initialize PinPad during splash
    _initializePinPad();

    // Navigate to login after splash
    Timer(const Duration(seconds: 3), () {
      if (mounted) {
        Navigator.pushReplacementNamed(context, '/login');
      }
    });
  }

  Future<void> _initializePinPad() async {
    try {
      print('🔧 Initializing PIN Pad during splash...');
      await FlutterSmartPinPadCards.initPinpad();
      print('✅ PIN Pad initialized successfully');
    } catch (e) {
      print('❌ Failed to initialize PIN Pad: $e');
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF0D4575),
              Color(0xFF1a5490),
            ],
          ),
        ),
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Icon(
                  Icons.account_balance,
                  size: 120,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 40),
              const Text(
                'BANK JATENG',
                style: TextStyle(
                  fontSize: 36,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  letterSpacing: 2,
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                'PIN Management System',
                style: TextStyle(
                  fontSize: 18,
                  color: Colors.white70,
                  fontWeight: FontWeight.w300,
                ),
              ),
              const SizedBox(height: 60),
              Container(
                width: 200,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(2),
                  ),
                  width: 50,
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Initializing...',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Login Page
class LoginPage extends StatefulWidget {
  const LoginPage({Key? key}) : super(key: key);

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final TextEditingController _passwordController = TextEditingController();
  final FocusNode _passwordFocus = FocusNode();
  bool _isLoading = false;
  bool _isObscured = true;
  String _connectionStatus = '';
  bool _pinpadStatus = false;

  @override
  void initState() {
    super.initState();
    _checkSystemStatus();
  }

  @override
  void dispose() {
    _passwordController.dispose();
    _passwordFocus.dispose();
    super.dispose();
  }

  Future<void> _checkSystemStatus() async {
    setState(() {
      _connectionStatus = 'Checking system status...';
    });

    // Check server connection
    final isServerConnected = await NetworkService.testConnection();

    // Check PIN pad status
    // bool isPinpadReady = false;
    try {
      final pinpadStatus = await FlutterSmartPinPadCards.getPinpadStatus();
       pinpadStatus['available'];
    } catch (e) {
      print('Failed to check PIN pad status: $e');
    }

    setState(() {
      // _pinpadStatus;
      _connectionStatus = '''${isServerConnected ? '✅' : '❌'} Server: ${NetworkService.serverHost}:${NetworkService.serverPort}''';
    });
  }
// ${_pinpadStatus ? '✅' : '❌'} PIN Pad: ${_pinpadStatus ? 'Ready' : 'Not Available'}''';

  void _handleLogin() async {
    if (_passwordController.text.isEmpty) {
      _showSnackBar('Please enter password', Colors.orange);
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // Send logon request to server
      final logonResponse = await NetworkService.sendLogon(
        terminalId: 'T3000001',
        password: _passwordController.text,
      );

      setState(() {
        _isLoading = false;
      });

      if (logonResponse.success) {
        _showSnackBar('Logon successful!', Colors.green);

        if (mounted) {
          Navigator.pushReplacementNamed(context, '/home');
        }
      } else {
        String errorMsg = 'Logon failed';
        if (logonResponse.errorMessage != null) {
          errorMsg += ': ${logonResponse.errorMessage}';
        }
        _showSnackBar(errorMsg, Colors.red);
        _passwordController.clear();
        _passwordFocus.requestFocus();
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      _showSnackBar('Network error: $e', Colors.red);
    }
  }

  void _showSnackBar(String message, Color color) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: color,
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Card(
                  elevation: 8,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          'LOGON',
                          style: TextStyle(
                            color: Color(0xFF0D4575),
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 20),

                        if (_isLoading) ...[
                          const Text(
                            'CONNECTING\nPROCESSING',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 16),
                          const CircularProgressIndicator(
                            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF0D4575)),
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'Terminal sedang melakukan koneksi dengan server',
                            style: TextStyle(fontSize: 14, color: Colors.grey),
                            textAlign: TextAlign.center,
                          ),
                        ] else ...[
                          const Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              'INPUT PASSWORD',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: Colors.grey,
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          TextField(
                            controller: _passwordController,
                            focusNode: _passwordFocus,
                            obscureText: _isObscured,
                            keyboardType: TextInputType.number,
                            decoration: InputDecoration(
                              hintText: '****',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: const BorderSide(
                                    width: 2,
                                    color: Color(0xFF0D4575)
                                ),
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 12,
                              ),
                              prefixIcon: const Icon(Icons.lock_outline),
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _isObscured ? Icons.visibility : Icons.visibility_off,
                                ),
                                onPressed: () {
                                  setState(() {
                                    _isObscured = !_isObscured;
                                  });
                                },
                              ),
                            ),
                            onSubmitted: (_) => _handleLogin(),
                          ),
                          const SizedBox(height: 8),
                          const Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              'Input password untuk logon',
                              style: TextStyle(fontSize: 12, color: Colors.grey),
                            ),
                          ),
                          const SizedBox(height: 20),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: _handleLogin,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF0D4575),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                elevation: 2,
                              ),
                              child: const Text(
                                'LOGON',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.grey.shade300),
                            ),
                            child: Column(
                              children: [
                                const Text(
                                  'Default password: 1234',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey,
                                    fontStyle: FontStyle.italic,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  _connectionStatus,
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w500,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 8),
                                ElevatedButton.icon(
                                  onPressed: _checkSystemStatus,
                                  icon: const Icon(Icons.refresh, size: 16),
                                  label: const Text('Test System'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.grey.shade600,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 8
                                    ),
                                    minimumSize: const Size(0, 0),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// Home Screen with Enhanced Menu Logic
class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  bool _pinCreated = false;

  // Statistics
  int _totalTransactions = 0;
  int _successfulTransactions = 0;
  String _lastTransactionTime = '';
  bool _serverStatus = false;

  // Server capability tracking
  Set<String> _serverSupportedOperations = {};
  bool _isCheckingCapabilities = false;
  String _capabilityStatus = 'Checking server capabilities...';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkServerCapabilities();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed) {
      _checkServerCapabilities();
    }
  }

  // Check server capabilities using actual card data from dialog
  Future<void> _checkServerCapabilities() async {
    setState(() {
      _isCheckingCapabilities = true;
      _capabilityStatus = 'Checking server capabilities...';
      _serverSupportedOperations.clear();
    });

    // Test server connection first
    final isConnected = await NetworkService.testConnection();
    setState(() {
      _serverStatus = isConnected;
    });

    if (!isConnected) {
      setState(() {
        _isCheckingCapabilities = false;
        _capabilityStatus = 'Server not available - all operations disabled';
      });
      return;
    }

    // Test each operation type with minimal test data
    final operationsToTest = [
      {'type': PinOperationType.createPin, 'code': '920000', 'name': 'Create PIN'},
      {'type': PinOperationType.changePin, 'code': '930000', 'name': 'Change PIN'},
      {'type': PinOperationType.authorization, 'code': '940000', 'name': 'PIN Authorization'},
    ];

    for (final operation in operationsToTest) {
      try {
        setState(() {
          _capabilityStatus = 'Testing ${operation['name']}...';
        });

        // Use minimal test data just to check if processing code is supported
        final response = await NetworkService.sendPinOperation(
          operationType: operation['type'] as PinOperationType,
          systemsTraceNo: DateTime.now().millisecondsSinceEpoch.toString().substring(7),
          terminalId: 'T3000001',
          merchantId: 'BANKJATENG00001',
          track2Data: '4000000000000000D99991234567890', // Minimal test track2
          newPin: '000000', // Test PIN block
        );

        // Response codes that indicate the operation is supported
        // Format Error (30) means processing code is not supported
        // Other errors mean the operation exists but failed for other reasons
        final supportedResponseCodes = ['00', '12', '55', '96', '91', '51', '14'];

        if (supportedResponseCodes.contains(response.responseCode)) {
          _serverSupportedOperations.add(operation['code'] as String);
          debugPrint('✅ Server supports ${operation['name']} (${operation['code']}) - Response: ${response.responseCode}');
        } else {
          debugPrint('❌ Server does not support ${operation['name']} (${operation['code']}) - Response: ${response.responseCode}');
        }

        // Small delay between tests
        await Future.delayed(const Duration(milliseconds: 500));

      } catch (e) {
        debugPrint('❌ Error testing ${operation['name']}: $e');
      }
    }

    setState(() {
      _isCheckingCapabilities = false;
      _capabilityStatus = _serverSupportedOperations.isEmpty
          ? 'No operations supported by server'
          : '${_serverSupportedOperations.length}/3 operations available';
    });

    debugPrint('🔧 Server supported operations: $_serverSupportedOperations');
  }

  // Check if specific operation is supported
  bool _isOperationSupported(String processingCode) {
    return _serverSupportedOperations.contains(processingCode);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Bank JATENG'),
        backgroundColor: const Color(0xFF0D4575),
        foregroundColor: Colors.white,
        elevation: 2,
        actions: [
          IconButton(
            icon: Icon(_serverStatus ? Icons.cloud_done : Icons.cloud_off),
            onPressed: () {
              _showServerStatusDialog();
            },
            tooltip: _serverStatus ? 'Server Connected' : 'Server Disconnected',
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _checkServerCapabilities,
            tooltip: 'Refresh Capabilities',
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _showLogoutDialog,
          ),
        ],
      ),
      body: SafeArea(
        child: _buildMainContent(),
      ),
    );
  }

  Widget _buildMainContent() {
    return RefreshIndicator(
      onRefresh: _checkServerCapabilities,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            // Server Status Card
            if (_isCheckingCapabilities) _buildCapabilityCheckCard(),

            // PIN Operations Card
            _buildPinOperationsCard(),
            const SizedBox(height: 24),

            // Statistics Card
            // _buildStatisticsCard(),
          ],
        ),
      ),
    );
  }

  // Capability check status card
  Widget _buildCapabilityCheckCard() {
    return Card(
      color: Colors.blue.shade50,
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Row(
              children: [
                const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _capabilityStatus,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      overflow: TextOverflow.ellipsis,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              'Checking which PIN operations are supported by the server...',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPinOperationsCard() {
    return Card(
      color: Colors.grey.shade50,
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'PIN OPERATIONS',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0D4575),
                  ),
                ),
                if (!_isCheckingCapabilities)
                  Text(
                    _capabilityStatus,
                    style: TextStyle(
                      fontSize: 11,
                      color: _serverSupportedOperations.isEmpty ? Colors.red : Colors.green,
                      fontWeight: FontWeight.w500,
                      overflow: TextOverflow.ellipsis,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildOperationButton(
                  icon: Icons.add_circle_outline,
                  color: Colors.blue,
                  label: 'Create PIN',
                  subtitle: 'Buat PIN baru',
                  processingCode: '920000',
                  onPressed: () {
                    _showCreatePinDialog();
                  },
                ),
                _buildOperationButton(
                  icon: Icons.loop,
                  color: Colors.green,
                  label: 'Change PIN',
                  subtitle: 'Ubah PIN lama',
                  processingCode: '930000',
                  onPressed: () {
                    _showChangePinDialog();
                  },
                ),
                _buildOperationButton(
                  icon: Icons.security,
                  color: Colors.orange,
                  label: 'Otorisasi PIN',
                  subtitle: 'Verifikasi PIN',
                  processingCode: '940000',
                  onPressed: () {
                    _showOtorisasiDialog();
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // Operation button with server capability check
  Widget _buildOperationButton({
    required IconData icon,
    required String label,
    required String subtitle,
    required Color color,
    required String processingCode,
    required VoidCallback onPressed,
  }) {
    final isSupported = _isOperationSupported(processingCode);
    final isEnabled = isSupported && !_isCheckingCapabilities;

    return Expanded(
      child: Stack(
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: isEnabled ? onPressed : () {
              _showUnsupportedOperationDialog(label, processingCode);
            },
            child: Container(
              padding: const EdgeInsets.all(12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    height: 70,
                    width: 70,
                    decoration: BoxDecoration(
                      color: isEnabled ? color : Colors.grey,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: (isEnabled ? color : Colors.grey).withOpacity(0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Icon(
                      icon,
                      size: 32,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    label,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: isEnabled ? Colors.black : Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 10,
                      color: isEnabled ? Colors.grey.shade600 : Colors.grey.shade400,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (!isSupported && !_isCheckingCapabilities)
            Positioned(
              top: 8,
              right: 8,
              child: Container(
                padding: const EdgeInsets.all(2),
                decoration: const BoxDecoration(
                  color: Colors.red,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.block,
                  size: 16,
                  color: Colors.white,
                ),
              ),
            ),
          if (_isCheckingCapabilities)
            Positioned(
              top: 8,
              right: 8,
              child: Container(
                padding: const EdgeInsets.all(2),
                decoration: const BoxDecoration(
                  color: Colors.orange,
                  shape: BoxShape.circle,
                ),
                child: const SizedBox(
                  width: 12,
                  height: 12,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildStatisticsCard() {
    return Card(
      color: Colors.white,
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'STATISTICS',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF0D4575),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildStatItem(
                  'Total\nTransactions',
                  _totalTransactions.toString(),
                  Colors.blue,
                ),
                _buildStatItem(
                  'Successful\nTransactions',
                  _successfulTransactions.toString(),
                  Colors.green,
                ),
                _buildStatItem(
                  'Success\nRate',
                  _totalTransactions > 0
                      ? '${((_successfulTransactions / _totalTransactions) * 100).toStringAsFixed(1)}%'
                      : '0%',
                  Colors.orange,
                ),
              ],
            ),
            if (_lastTransactionTime.isNotEmpty) ...[
              const SizedBox(height: 16),
              Text(
                'Last transaction: $_lastTransactionTime',
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(String label, String value, Color color) {
    return Column(
      children: [
        Container(
          width: 60,
          height: 60,
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withOpacity(0.3)),
          ),
          child: Center(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w500,
            color: Colors.grey,
          ),
        ),
      ],
    );
  }

  // Show dialog for unsupported operations
  void _showUnsupportedOperationDialog(String operationName, String processingCode) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.block, color: Colors.red),
            const SizedBox(width: 8),
            const Text('Operation Not Supported'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('The server does not support "$operationName" operation.'),
            const SizedBox(height: 8),
            Text('Processing Code: $processingCode'),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.1),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: Colors.red.withOpacity(0.3)),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Possible reasons:',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                  SizedBox(height: 4),
                  Text(
                    '• Server configuration disabled this operation',
                    style: TextStyle(fontSize: 12),
                  ),
                  Text(
                    '• Processing code not configured in server',
                    style: TextStyle(fontSize: 12),
                  ),
                  Text(
                    '• Server returned Format Error (30) for this request',
                    style: TextStyle(fontSize: 12),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _checkServerCapabilities();
            },
            child: const Text('Retry Check'),
          ),
        ],
      ),
    );
  }

  // PIN Dialog Methods - These will use actual card data from CardReaderDialog
  void _showCreatePinDialog() async {
    if (!_isOperationSupported('920000')) {
      _showUnsupportedOperationDialog('Create PIN', '920000');
      return;
    }

    // CardReaderDialog will handle reading the card and getting PIN input
    // The dialog will pass the actual card data to the network service
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => const CardReaderDialog(
        operationType: CardOperationType.createPin,
      ),
    );

    setState(() {
      _totalTransactions++;
      if (result == true) {
        _pinCreated = true;
        _successfulTransactions++;
        _lastTransactionTime = _formatCurrentTime();
      }
    });

    if (result == true && mounted) {
      _showSnackBar('PIN created successfully!', Colors.green);
    } else if (result == false && mounted) {
      _showSnackBar('PIN creation failed', Colors.red);
    }
  }

  void _showChangePinDialog() async {
    if (!_isOperationSupported('930000')) {
      _showUnsupportedOperationDialog('Change PIN', '930000');
      return;
    }

    // CardReaderDialog will handle reading the card and getting both old and new PIN
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => const CardReaderDialog(
        operationType: CardOperationType.changePin,
      ),
    );

    setState(() {
      _totalTransactions++;
      if (result == true) {
        _successfulTransactions++;
        _lastTransactionTime = _formatCurrentTime();
        _pinCreated = true;
      }
    });

    if (result == true && mounted) {
      _showSnackBar('PIN changed successfully!', Colors.green);
    } else if (result == false && mounted) {
      _showSnackBar('PIN change failed', Colors.red);
    }
  }

  void _showOtorisasiDialog() async {
    if (!_isOperationSupported('940000')) {
      _showUnsupportedOperationDialog('PIN Authorization', '940000');
      return;
    }

    // CardReaderDialog will handle reading the card and getting PIN for authorization
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => const CardReaderDialog(
        operationType: CardOperationType.otorisation,
      ),
    );

    setState(() {
      _totalTransactions++;
      if (result == true) {
        _successfulTransactions++;
        _lastTransactionTime = _formatCurrentTime();
      }
    });

    if (result == true && mounted) {
      _showSnackBar('PIN authorization successful!', Colors.green);
    } else if (result == false && mounted) {
      _showSnackBar('PIN authorization failed', Colors.red);
    }
  }

  String _formatCurrentTime() {
    final now = DateTime.now();
    return '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
  }

  void _showServerStatusDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(
              _serverStatus ? Icons.cloud_done : Icons.cloud_off,
              color: _serverStatus ? Colors.green : Colors.red,
            ),
            const SizedBox(width: 8),
            Text(
              'Server Status',
              style: TextStyle(
                color: _serverStatus ? Colors.green : Colors.red,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Host: ${NetworkService.serverHost}'),
            Text('Port: ${NetworkService.serverPort}'),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: (_serverStatus ? Colors.green : Colors.red).withOpacity(0.1),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                _serverStatus ? 'Connected' : 'Disconnected',
                style: TextStyle(
                  color: _serverStatus ? Colors.green : Colors.red,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 12),
            const Text('Supported Operations:', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            ..._serverSupportedOperations.map((code) {
              String operationName;
              switch (code) {
                case '920000': operationName = 'Create PIN'; break;
                case '930000': operationName = 'Change PIN'; break;
                case '940000': operationName = 'PIN Authorization'; break;
                default: operationName = 'Unknown';
              }
              return Row(
                children: [
                  const Icon(Icons.check, color: Colors.green, size: 16),
                  const SizedBox(width: 4),
                  Text('$operationName ($code)'),
                ],
              );
            }).toList(),
            if (_serverSupportedOperations.isEmpty)
              const Row(
                children: [
                  Icon(Icons.error, color: Colors.red, size: 16),
                  SizedBox(width: 4),
                  Text('No operations supported'),
                ],
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await _checkServerCapabilities();
            },
            child: const Text('Refresh'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showSnackBar(String message, Color color) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: color,
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          action: SnackBarAction(
            label: 'OK',
            textColor: Colors.white,
            onPressed: () {
              ScaffoldMessenger.of(context).hideCurrentSnackBar();
            },
          ),
        ),
      );
    }
  }

  void _showLogoutDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text(
          'LOGOFF',
          style: TextStyle(
            color: Color(0xFF0D4575),
            fontWeight: FontWeight.bold,
          ),
        ),
        content: const Text('Are you sure you want to LOGOFF?'),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _handleLogout();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0D4575),
              foregroundColor: Colors.white,
            ),
            child: const Text('LOGOFF'),
          ),
        ],
      ),
    );
  }

  void _handleLogout() async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFF0D4575),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                'LOGOFF',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'CONNECTING\nPROCESSING',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            const CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF0D4575)),
            ),
            const SizedBox(height: 16),
            const Text(
              'Terminal sedang melakukan logoff dari server',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );

    // Send logoff request to server
    try {
      await NetworkService.sendLogon(
        terminalId: 'T3000001',
        password: '1234', // For logoff, this is not used but required by method signature
      );
    } catch (e) {
      print('Logoff error: $e');
    }

    await Future.delayed(const Duration(seconds: 2));

    if (mounted) {
      Navigator.pop(context); // Close loading dialog
      Navigator.pushReplacementNamed(context, '/login');
    }
  }
}