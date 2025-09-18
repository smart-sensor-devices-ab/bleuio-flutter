import 'dart:async';
import 'dart:convert';
import 'dart:html' as html;
import 'dart:js_util' as jsu;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

void main() {
  runApp(const BleuIOApp());
}

class BleuIOApp extends StatelessWidget {
  const BleuIOApp({super.key});

  static const bleuBlue = Color(0xFF1F4F91);      
  static const bleuBlueDark = Color(0xFF163C70);  
  static const bleuYellow = Color(0xFFF7B500);    
  static const bgSoft = Color(0xFFF6F8FC);        

  @override
  Widget build(BuildContext context) {
    final theme = ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: bgSoft,
      colorScheme: ColorScheme.fromSeed(
        seedColor: bleuBlue,
        primary: bleuBlue,
        secondary: bleuYellow,
        brightness: Brightness.light,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.white,
        foregroundColor: bleuBlue,
        elevation: 0,
        centerTitle: false,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: bleuBlue,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          shape: const StadiumBorder(),
          elevation: 0,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        isDense: true,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        focusedBorder: const OutlineInputBorder(
          borderSide: BorderSide(color: bleuBlue, width: 1.4),
        ),
      ),
    );

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'BleuIO',
      theme: theme,
      home: const BleuIOSerialWebDemo(),
    );
  }
}

class BleuIOSerialWebDemo extends StatefulWidget {
  const BleuIOSerialWebDemo({super.key});
  @override
  State<BleuIOSerialWebDemo> createState() => _BleuIOSerialWebDemoState();
}

class _BleuIOSerialWebDemoState extends State<BleuIOSerialWebDemo> {
  final _svc = _WebSerialBleuIO();
  final _cmdCtrl = TextEditingController(text: 'ATI');
  final _scrollCtrl = ScrollController();

  String _status = 'Disconnected';
  final _log = StringBuffer();

  @override
  void initState() {
    super.initState();
    _svc.lines.listen((line) {
      setState(() {
        _log.writeln(line);
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollCtrl.hasClients) {
          _scrollCtrl.jumpTo(_scrollCtrl.position.maxScrollExtent);
        }
      });
    }, onError: (e) {
      setState(() {
        _log.writeln('ERROR: $e');
      });
    });
  }

  @override
  void dispose() {
    _svc.dispose();
    _cmdCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  Future<void> _connect() async {
    setState(() => _status = 'Connecting…');
    try {
      await _svc.connect(baudRate: 115200);
      setState(() => _status = 'Connected');
      await _svc.writeLine('AT');
    } catch (e) {
      setState(() => _status = 'Failed: $e');
    }
  }

  Future<void> _send(String cmd) async {
    await _svc.writeLine(cmd);
  }

  @override
  Widget build(BuildContext context) {
    const titleStyle = TextStyle(
      color: BleuIOApp.bleuBlue,
      fontWeight: FontWeight.w700,
      fontSize: 18,
      letterSpacing: .2,
    );
    final mono = const TextStyle(
      fontFamily: 'ui-monospace, SFMono-Regular, Menlo, Consolas, monospace',
    );

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 12,
        title: Row(
          children: [
            Image.asset('assets/images/bleuio_logo.png', height: 28),
            const SizedBox(width: 10)
          ],
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _StatusPill(status: _status),
            const SizedBox(height: 10),

            // Controls row
            Wrap(
              spacing: 10,
              runSpacing: 10,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                ElevatedButton(onPressed: _connect, child: const Text('Connect BleuIO')),
                ElevatedButton(onPressed: () => _send('AT+CENTRAL'), child: const Text('AT+CENTRAL')),
                ElevatedButton(onPressed: () => _send('AT+GAPSCAN=3'), child: const Text('GAPSCAN 3s')),
                // Custom command
                Row(mainAxisSize: MainAxisSize.min, children: [
                  SizedBox(
                    width: 300,
                    child: TextField(
                      controller: _cmdCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Custom AT command',
                      ),
                      style: mono,
                      textCapitalization: TextCapitalization.characters,
                      inputFormatters: [UpperCaseTextFormatter()],
                      onSubmitted: (v) => _send(v.trim()),
                    ),
                  ),
                  const SizedBox(width: 10),
                  ElevatedButton(
                    onPressed: () => _send(_cmdCtrl.text.trim()),
                    child: const Text('Send'),
                  ),
                  const SizedBox(width: 10),
                  ElevatedButton(
                    onPressed: () { _svc.sendCtrlC(); },
                    child: const Text('Stop process'),
                  ),
                ]),
              ],
            ),

            const SizedBox(height: 14),

            // Terminal
            Expanded(
              child: Container(
                width: double.infinity,
                alignment: Alignment.topLeft,
                decoration: BoxDecoration(
                  color: const Color(0xFF0B0B0B),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: const [
                    BoxShadow(
                      color: Colors.black12,
                      blurRadius: 8,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                padding: const EdgeInsets.all(10),
                child: Scrollbar(
                  controller: _scrollCtrl,
                  child: SingleChildScrollView(
                    controller: _scrollCtrl,
                    child: SizedBox(
                      width: double.infinity,
                      child: SelectableText(
                        _log.toString(),
                        style: mono.copyWith(color: const Color(0xFF99FF99)),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  final String status;
  const _StatusPill({required this.status});

  @override
  Widget build(BuildContext context) {
    final connected = status.toLowerCase().startsWith('connected');
    final failed = status.toLowerCase().startsWith('failed');

    final bg = connected
        ? const Color(0xFFE6F4EA) 
        : failed
            ? const Color(0xFFFDE8E8) 
            : const Color(0xFFE8F0FE); 

    final fg = connected
        ? const Color(0xFF137333)
        : failed
            ? const Color(0xFFB00020)
            : BleuIOApp.bleuBlue;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: fg.withOpacity(.2)),
      ),
      child: Text('Status : $status', style: TextStyle(color: fg, fontWeight: FontWeight.w600)),
    );
  }
}

/// Minimal Web Serial wrapper for BleuIO .
class _WebSerialBleuIO {
  dynamic _port;
  dynamic _writer; // JS writer
  bool _connected = false;

  final _lineCtl = StreamController<String>.broadcast();
  Stream<String> get lines => _lineCtl.stream;

  Future<void> connect({required int baudRate}) async {
    final serial = jsu.getProperty(html.window.navigator, 'serial');
    if (serial == null) {
      throw StateError('Web Serial not supported. Use Chrome/Edge desktop.');
    }

    // Request port selection
    _port = await jsu.promiseToFuture(jsu.callMethod(serial, 'requestPort', []));
    await jsu.promiseToFuture(jsu.callMethod(_port, 'open', [jsu.jsify({'baudRate': baudRate})]));
    _connected = true;

    // Start read loop
    _readLoop();

    // Prepare writer
    final writable = jsu.getProperty(_port, 'writable');
    _writer = jsu.callMethod(writable, 'getWriter', []);
  }
  Future<void> sendCtrlC() async {
    if (!_connected || _writer == null) return;
    // ETX (Ctrl+C) without CRLF
    await _writeRaw(Uint8List.fromList([0x03]));
    _lineCtl.add('>> [CTRL+C]');
    await Future.delayed(const Duration(milliseconds: 20));
  }

  Future<void> writeLine(String cmd) async {
    if (!_connected || _writer == null) return;
    final enc = utf8.encode(cmd.endsWith('\r\n') ? cmd : '$cmd\r\n');

    await _writeRaw(utf8.encode('\r\n'));
    await Future.delayed(const Duration(milliseconds: 10));

    await _writeRaw(enc);
    _lineCtl.add('>> ${cmd.trim()}');
    await Future.delayed(const Duration(milliseconds: 30));
  }

  Future<void> _writeRaw(List<int> bytes) async {
    final data = Uint8List.fromList(bytes);
    await jsu.promiseToFuture(jsu.callMethod(_writer, 'write', [data]));
  }

  void _readLoop() async {
    final readable = jsu.getProperty(_port, 'readable');
    dynamic reader = jsu.callMethod(readable, 'getReader', []);
    final decoder = const Utf8Decoder();
    var buffer = StringBuffer();

    try {
      while (_connected) {
        final res = await jsu.promiseToFuture(jsu.callMethod(reader, 'read', []));
        final done = jsu.getProperty(res, 'done') as bool? ?? false;
        final value = jsu.getProperty(res, 'value');

        if (value != null) {
          final chunk = _uint8ListFromJsValue(value);
          buffer.write(decoder.convert(chunk));
          final text = buffer.toString();
          final parts = text.split(RegExp(r'\r?\n'));
          buffer.clear();
          if (parts.isNotEmpty) buffer.write(parts.removeLast()); // keep partial
          for (final line in parts) {
            final s = line.trimRight();
            if (s.isNotEmpty) _lineCtl.add(s);
          }
        }
        if (done) break;
      }
    } catch (e) {
      _lineCtl.add('READ ERROR: $e');
    } finally {
      try { await jsu.promiseToFuture(jsu.callMethod(reader, 'cancel', [])); } catch (_) {}
      jsu.callMethod(reader, 'releaseLock', []);
      if (_connected) _readLoop(); 
    }
  }

  Uint8List _uint8ListFromJsValue(dynamic value) {
    if (value is ByteBuffer) return value.asUint8List();
    if (value is Uint8List) return value;
    final len = jsu.getProperty(value, 'length') as int? ?? 0;
    final list = List<int>.generate(len, (i) => jsu.getProperty(value, i) as int);
    return Uint8List.fromList(list);
  }

  Future<void> dispose() async {
    _connected = false;
    try { if (_writer != null) jsu.callMethod(_writer, 'releaseLock', []); } catch (_) {}
    try { if (_port != null) await jsu.promiseToFuture(jsu.callMethod(_port, 'close', [])); } catch (_) {}
    await _lineCtl.close();
  }
}
class UpperCaseTextFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    return newValue.copyWith(
      text: newValue.text.toUpperCase(),
      selection: newValue.selection,
      composing: TextRange.empty,
    );
  }
}

