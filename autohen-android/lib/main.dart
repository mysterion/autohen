import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

const PORT = 8888;
void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'VR Player',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const MyHomePage(title: 'Autohen'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  final logLimit = 50;
  final ScrollController _logController = ScrollController();
  String assetsDir = "";
  List<String> logs = [];
  List<String> ips = [];
  List<String> devices = [];

  HttpServer? server;

  Future<String> _copyAssetsToSystemTemp(List<String> assetPaths) async {
    final dir = Directory.systemTemp.createTempSync('web_assets_');

    for (final asset in assetPaths) {
      final data = await rootBundle.load(asset);
      final filename = asset.split('/').last;
      final file = File('${dir.path}/$filename');
      await file.writeAsBytes(data.buffer.asUint8List());
    }

    return dir.path;
  }

  Future<void> sendPayload(String ip) async {
    const connectTimeout = Duration(seconds: 3);
    const writeTimeout = Duration(seconds: 10);
    try {
      addToLogs('Sending payload to $ip');
      final socket = await Socket.connect(ip, 9020).timeout(
        connectTimeout,
        onTimeout: () {
          throw Exception('Connection timed out');
        },
      );
      socket.setOption(SocketOption.tcpNoDelay, true);
      final timer = Timer(writeTimeout, () {
        socket.destroy(); // Force close on write timeout
      });
      try {
        final payload = await File(
          '$assetsDir/goldhen_2.3_900.bin',
        ).readAsBytes();
        socket.add(payload);
        await socket.flush();
        addToLogs('Payload sent to $ip:9020');
      } catch (e) {
        addToLogs("Failed to send payload: $e");
      } finally {
        timer.cancel();
        await socket.close();
      }
    } catch (e) {
      addToLogs("Failed to connect: $e");
    }
  }

  Future<List<String>> getWifiIps() async {
    List<String> ips = [];
    for (var ni in await NetworkInterface.list()) {
      if (ni.name.toLowerCase().startsWith("wlan")) {
        for (var ad in ni.addresses) {
          if (ad.type != InternetAddressType.IPv4) {
            continue;
          }
          ips.add(ad.address);
        }
      }
    }
    return ips;
  }

  Future<HttpServer?> serv(int port) async {
    final assets = [
      'assets/index.html',
      'assets/int64.js',
      'assets/kexploit.js',
      'assets/logging.js',
      'assets/rop.js',
      'assets/webkit.js',
      'assets/goldhen_2.3_900.bin',
    ];

    assetsDir = await _copyAssetsToSystemTemp(assets);

    try {
      final server = await HttpServer.bind(InternetAddress.anyIPv4, port);
      for (var ip in await getWifiIps()) {
        addToLogs('http://$ip:$port/');
      }
      server.listen(
        (HttpRequest req) async {
          try {
            final path = req.uri.path == '/' ? '/index.html' : req.uri.path;
            final file = File('$assetsDir$path');
            final remoteIp = req.connectionInfo?.remoteAddress.host;
            if (remoteIp != null) {
              if (!devices.contains(remoteIp)) {
                addToLogs('NEW DEVICE: $remoteIp');
                setState(() {
                  devices = [...devices, remoteIp];
                });
              }
            }
            if (await file.exists()) {
              final mimeType = _getMimeType(path);
              req.response.headers.contentType = ContentType.parse(mimeType);
              await file.openRead().pipe(req.response);
            } else {
              req.response.statusCode = HttpStatus.notFound;
              req.response.write('File not found');
              addToLogs('_OK_${req.method} - ${req.uri}');
            }
          } catch (e) {
            req.response.statusCode = HttpStatus.internalServerError;
            req.response.write('Internal server error: $e');
            addToLogs('_ER_${req.method} - ${req.uri}');
          } finally {
            await req.response.close();
          }
        },
        onError: (e) => {addToLogs('_ER_$e')},
        onDone: () {
          addToLogs('STOPPED: ${InternetAddress.loopbackIPv4}:$port');
        },
      );
      return server;
    } catch (e) {
      addToLogs('_ER_$e');
      return null;
    }
  }

  String _getMimeType(String filePath) {
    if (filePath.endsWith('.html')) return 'text/html';
    if (filePath.endsWith('.css')) return 'text/css';
    if (filePath.endsWith('.js')) return 'application/javascript';
    if (filePath.endsWith('.jpg') || filePath.endsWith('.jpeg')) {
      return 'image/jpeg';
    }
    if (filePath.endsWith('.png')) return 'image/png';
    if (filePath.endsWith('.gif')) return 'image/gif';
    if (filePath.endsWith('.ico')) return 'image/x-icon';
    return 'application/octet-stream';
  }

  void addToLogs(String log) {
    if (logs.length + 1 > logLimit) {
      logs.removeAt(0);
    }
    setState(() {
      logs.add(log);
    });
    _logController.jumpTo(_logController.position.maxScrollExtent);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text(widget.title),
      ),
      body: Container(
        padding: const EdgeInsets.symmetric(horizontal: 5),
        margin: const EdgeInsets.symmetric(horizontal: 5),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              ElevatedButton(
                onPressed: () async {
                  if (server == null) {
                    HttpServer? s = await serv(PORT);
                    final i = await getWifiIps();
                    setState(() {
                      server = s;
                      ips = i;
                    });
                    addToLogs('STARTED SERVER');
                  } else {
                    (server)?.close(force: true);
                    setState(() {
                      server = null;
                      ips = [];
                    });
                  }
                },
                child: Text(server == null ? 'start server' : 'stop server'),
              ),
              Text(
                (() {
                  var res = "";
                  for (var ip in ips) {
                    res += "http://$ip:$PORT\n";
                  }
                  return res;
                })(),
              ),
              Text("devices detected: ${devices.length}"),
              Column(
                children: devices
                    .map(
                      (e) => ElevatedButton(
                        onPressed: () async => {await sendPayload(e)},
                        child: Text("Send payload to $e"),
                      ),
                    )
                    .toList(),
              ),
              Container(
                alignment: Alignment.centerLeft,
                child: const Text('logs:'),
              ),
              Expanded(child: buildLog(logs, _logController)),
            ],
          ),
        ),
      ),
    );
  }
}

Container buildLog(List<String> logs, ScrollController ct) {
  return Container(
    color: Colors.deepPurple[100],
    child: ListView.builder(
      controller: ct,
      reverse: true,
      itemCount: logs.length,
      itemBuilder: (context, index) {
        return ListTile(title: Text(logs[index]));
      },
    ),
  );
}
