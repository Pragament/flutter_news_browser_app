import 'package:ferry/ferry.dart';
import 'package:ferry/typed_links.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_browser/Db/hive_db_helper.dart';
import 'package:flutter_browser/empty_tab.dart';
import 'package:flutter_browser/rss_news/client/client.dart';
import 'package:flutter_browser/rss_news/services/summary_provider.dart';
import 'package:flutter_downloader/flutter_downloader.dart';
import 'package:hive_flutter/adapters.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:flutter_browser/models/browser_model.dart';
import 'package:flutter_browser/models/webview_model.dart';
import 'browser.dart';
import 'models/most_visited_website_model.dart';

// ignore: non_constant_identifier_names
late final String WEB_ARCHIVE_DIR;
// ignore: non_constant_identifier_names
late final double TAB_VIEWER_BOTTOM_OFFSET_1;
// ignore: non_constant_identifier_names
late final double TAB_VIEWER_BOTTOM_OFFSET_2;
// ignore: non_constant_identifier_names
late final double TAB_VIEWER_BOTTOM_OFFSET_3;
// ignore: constant_identifier_names
const double TAB_VIEWER_TOP_OFFSET_1 = 0.0;
// ignore: constant_identifier_names
const double TAB_VIEWER_TOP_OFFSET_2 = 10.0;
// ignore: constant_identifier_names
const double TAB_VIEWER_TOP_OFFSET_3 = 20.0;
// ignore: constant_identifier_names
const double TAB_VIEWER_TOP_SCALE_TOP_OFFSET = 250.0;
// ignore: constant_identifier_names
const double TAB_VIEWER_TOP_SCALE_BOTTOM_OFFSET = 230.0;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // ignore: unused_local_variable

  await HiveDBHelper.initializeHive();

  // For most Visited Websites
  await Hive.initFlutter();
  Hive.registerAdapter(MostVisitedWebsiteModelAdapter());
  await Hive.openBox<MostVisitedWebsiteModel>('mostVisitedWebsites');
  await Hive.openBox<List<String>>('preferences');

  final Client client = await initClient(); // don't remove this line
  WEB_ARCHIVE_DIR = (await getApplicationSupportDirectory()).path;

  TAB_VIEWER_BOTTOM_OFFSET_1 = 130.0;
  TAB_VIEWER_BOTTOM_OFFSET_2 = 140.0;
  TAB_VIEWER_BOTTOM_OFFSET_3 = 150.0;

  await FlutterDownloader.initialize(debug: kDebugMode);
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (context) => WebViewModel(),
        ),
        ChangeNotifierProxyProvider<WebViewModel, BrowserModel>(
          update: (context, webViewModel, browserModel) {
            browserModel!.setCurrentWebViewModel(webViewModel);
            return browserModel;
          },
          create: (BuildContext context) => BrowserModel(),
        ),
        ChangeNotifierProvider(create: (context) => BackgroundTask()),
      ],
      child: const FlutterBrowserApp(),
    ),
  );
}

class FlutterBrowserApp extends StatelessWidget {
  const FlutterBrowserApp({Key? key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter News Browser',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      initialRoute: '/',
      routes: {
        '/': (context) => const Browser(),
      },
    );
  }
}
