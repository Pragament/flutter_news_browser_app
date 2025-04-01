// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:flutter_browser/Db/hive_db_helper.dart';
import 'package:flutter_browser/rss_news/models/device_model.dart';
import 'package:flutter_browser/rss_news/models/most_visited_website_model.dart';
import 'package:flutter_browser/rss_news/screens/home_screen.dart';
import 'package:flutter_browser/rss_news/services/whitelist.dart';
import 'package:flutter_browser/rss_news/utils/debug.dart';
import 'package:flutter_browser/util.dart';
import 'package:flutter_browser/webview_tab.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:provider/provider.dart';
import 'package:webview_flutter/webview_flutter.dart';
// import 'package:webview_flutter_platform_interface/webview_flutter_platform_interface.dart';

// import 'package:webview_flutter_web/webview_flutter_web.dart';
import 'models/browser_model.dart';
import 'models/webview_model.dart';
import 'models/window_model.dart';

class EmptyTab extends StatefulWidget {
  final WebViewController? webViewController;
  // final WebViewController? viewController;

  const EmptyTab({Key? key, this.webViewController}) : super(key: key);

  @override
  State<EmptyTab> createState() => _EmptyTabState();
}

class _EmptyTabState extends State<EmptyTab> {
  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    Device? d = HiveDBHelper.getDevice();
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.only(top: 30.0),
        child: Column(
          children: [
            // Top 10 Most Visited Websites
            ValueListenableBuilder(
              valueListenable:
                  Hive.box<MostVisitedWebsiteModel>('mostVisitedWebsites')
                      .listenable(),
              builder: (BuildContext context, Box<MostVisitedWebsiteModel> box,
                  Widget? child) {
                final websites = box.values.toList()
                  ..sort((a, b) => b.visitCount.compareTo(a.visitCount));
                final topWebsites = websites.take(10).toList();

                return topWebsites.isNotEmpty
                    ? _buildHorizontalWebsiteList(topWebsites)
                    : const SizedBox.shrink();
              },
            ),

            // Main content (HomeScreen or AppLanguageSelectionScreen)
            if (d == null)
              const Expanded(
                child: HomeScreen(),
              ),
            // if (d != null) const Expanded(child: NoNews()),
          ],
        ),
      ),
    );
  }

  Widget _buildHorizontalWebsiteList(List<MostVisitedWebsiteModel> websites) {
    return Padding(
      padding: const EdgeInsets.only(top: 100.0, bottom: 50),
      child: SizedBox(
        height: 80,
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          itemCount: websites.length,
          itemBuilder: (context, index) {
            final website = websites[index];
            return GestureDetector(
              onTap: () => _openWebsite(website.domain),
              onLongPress: () =>
                  _showDeleteConfirmationDialog(website, context),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8.0),
                child: Column(
                  children: [
                    Container(
                        width: 45,
                        padding: const EdgeInsets.all(3),
                        child: Image.network(
                          website.faviconUrl.isNotEmpty &&
                                  Uri.tryParse(website.faviconUrl)
                                          ?.isAbsolute ==
                                      true
                              ? website.faviconUrl
                              : 'assets/images/news.jpeg', // fallback image in case URL is invalid
                          fit: BoxFit.cover,
                          loadingBuilder: (BuildContext context, Widget child,
                              ImageChunkEvent? loadingProgress) {
                            if (loadingProgress == null) {
                              return child; // Image loaded successfully
                            } else {
                              return Center(
                                child: CircularProgressIndicator(
                                  value: loadingProgress.expectedTotalBytes !=
                                          null
                                      ? loadingProgress.cumulativeBytesLoaded /
                                          (loadingProgress.expectedTotalBytes ??
                                              1)
                                      : null,
                                ),
                              ); // Show loading indicator while the image is loading
                            }
                          },
                          errorBuilder: (BuildContext context, Object error,
                              StackTrace? stackTrace) {
                            return Image.asset('assets/images/news.jpeg',
                                fit: BoxFit
                                    .cover); // Show fallback image in case of error
                          },
                        )),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: 50,
                      child: Text(
                        website.name,
                        style: const TextStyle(fontSize: 12),
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  void _openWebsite(String url) async {
    var browserModel = Provider.of<BrowserModel>(context, listen: false);
    var webViewModel = Provider.of<WebViewModel>(context, listen: false);
    var settings = browserModel.getSettings();
    var webUri = WebUri(url.trim());

    if (!webUri.scheme.startsWith("http") && !Util.isLocalizedContent(webUri)) {
      webUri = WebUri('${settings.searchEngine.searchUrl}$url');
    }

    if (widget.webViewController != null &&  Whitelist.isWebsiteAllowed(WebUri(url))) {
      webViewModel.webViewController!
          .loadUrl(urlRequest: URLRequest(url: webUri));
    } else {
      addNewTab(url: webUri);
      webViewModel.url = webUri;
    }
  }

  void addNewTab({WebUri? url}) {
  var browserModel = Provider.of<BrowserModel>(context, listen: false);
  var settings = browserModel.getSettings();

  url ??= settings.homePageEnabled && settings.customUrlHomePage.isNotEmpty
      ? WebUri(settings.customUrlHomePage)
      : WebUri(settings.searchEngine.url);

  if (Util.isDesktop()) {
    // For desktop platforms
    final windowModel = Provider.of<WindowModel>(context, listen: false);
    windowModel.addTab(WebViewTab(
      key: GlobalKey(),
      webViewModel: WebViewModel(url: url),
    ));
  } else {
    // For mobile platforms
    browserModel.addTab(WebViewTab(
      key: GlobalKey(),
      webViewModel: WebViewModel(url: url),
    ));
  }
}

  void _showDeleteConfirmationDialog(
      MostVisitedWebsiteModel website, BuildContext context) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Delete Website'),
          content: Text('Are you sure you want to delete ${website.name}?'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(); // Close the dialog
              },
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () async {
                await _deleteWebsite(website);
                Navigator.of(context).pop(); // Close the dialog
              },
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _deleteWebsite(MostVisitedWebsiteModel website) async {
    final box = Hive.box<MostVisitedWebsiteModel>('mostVisitedWebsites');
    final key = website.key;
    if (key != null) {
      await box.delete(key);
      debug("Deleted website: ${website.domain}");
    }
  }
}
