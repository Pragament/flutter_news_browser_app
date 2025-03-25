import 'package:flutter_browser/Db/hive_db_helper.dart';
import 'package:flutter_browser/rss_news/models/website_list.dart';
import 'package:flutter_browser/rss_news/utils/debug.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

class Whitelist {
  static String extractDomain(String domain) {
    var parts = domain.split('.');
    // Return the second-to-last part for standard domains
    debug(parts);
    if (parts.length > 2) {
      return parts[parts.length - 2];
    }
    // For two-part domains like google.com, return the first part
    return parts[0];
  }

  static bool isWebsiteAllowed(WebUri url) {
    // TEMPORARY BYPASS FOR TESTING PURPOSES
    // This will allow all websites so you can test the DOM inspector
    return true;
    
    /* Original implementation - uncomment after testing
    // Get the whitelist of websites
    List<Website> websites = HiveDBHelper.getWhitelistedWebsites();
    Set<String> whitelistDomains = websites.map((e) => e.domain).toSet();

    // Extract the domain from the URL
    var domain = url.host;
    domain = extractDomain(domain);

    // Debug the extracted domain
    debug(domain);

    // Check if the domain is a substring of any whitelist domain
    if (whitelistDomains
        .any((whitelistedDomain) => whitelistedDomain.contains(domain))) {
      return true;
    }
    return false;
    */
  }
}