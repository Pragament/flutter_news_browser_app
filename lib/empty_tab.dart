import 'package:flutter/material.dart';
import 'package:flutter_browser/rss_news/screens/home_screen.dart';
import 'package:flutter_browser/rss_news/screens/app_language_selection_screen.dart';
import 'package:flutter_browser/util.dart';
import 'package:flutter_browser/webview_tab.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:flutter_browser/models/most_visited_website_model.dart';
import 'package:provider/provider.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'models/browser_model.dart';
import 'models/webview_model.dart';

class EmptyTab extends StatefulWidget {
  final WebViewController? webViewController;

  const EmptyTab({Key? key, this.webViewController}) : super(key: key);

  @override
  State<EmptyTab> createState() => _EmptyTabState();
}

class _EmptyTabState extends State<EmptyTab> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.only(top: 30.0),
        child: Column(
          children: [
            // Top 10 Most Visited Websites
            ValueListenableBuilder(
              valueListenable: Hive.box<MostVisitedWebsiteModel>('mostVisitedWebsites').listenable(),
              builder: (BuildContext context, Box<MostVisitedWebsiteModel> box, Widget? child) {
                final websites = box.values.toList()
                  ..sort((a, b) => b.visitCount.compareTo(a.visitCount));
                final topWebsites = websites.take(10).toList();

                return topWebsites.isNotEmpty
                    ? _buildHorizontalWebsiteList(topWebsites)
                    : const SizedBox.shrink();
              },
            ),
            // Main content (HomeScreen or AppLanguageSelectionScreen)
            Expanded(
              child: ValueListenableBuilder(
                valueListenable: Hive.box<List<String>>('preferences').listenable(),
                builder: (BuildContext context, Box<List<String>> box, Widget? child) {
                  final sources = box.get('selectedSources') ?? [];
                  return sources.isNotEmpty
                      ? const HomeScreen()
                      : AppLanguageSelectionScreen();
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHorizontalWebsiteList(List<MostVisitedWebsiteModel> websites) {
    return SizedBox(
      height: 80,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: websites.length,
        itemBuilder: (context, index) {
          final website = websites[index];
          return GestureDetector(
            onTap: () => _openWebsite(website.domain),
            onLongPress: () => _showDeleteConfirmationDialog(website, context),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0),
              child: Column(
                children: [
                  Container(
                    width: 45,
                    padding: EdgeInsets.all(3),
                    child: Image.network(
                      website.faviconUrl,
                      fit: BoxFit.cover,
                    ),
                  ),
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

    if (widget.webViewController != null) {
      webViewModel.webViewController!.loadUrl(urlRequest: URLRequest(url: webUri));
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

    browserModel.addTab(WebViewTab(
      key: GlobalKey(),
      webViewModel: WebViewModel(url: url),
    ));
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
      print("Deleted website: ${website.domain}");
    }
  }
}
