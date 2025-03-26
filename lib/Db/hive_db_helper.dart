import 'package:flutter/material.dart';
import 'package:flutter_browser/rss_news/models/most_visited_website_model.dart';
import 'package:flutter_browser/rss_news/models/device_model.dart';
import 'package:flutter_browser/rss_news/models/rules_model.dart';
import 'package:flutter_browser/rss_news/models/website_list.dart';
// import 'package:flutter_browser/rss_news/utils/debug.dart';
import 'package:path_provider/path_provider.dart';

import 'package:hive/hive.dart';

class HiveDBHelper {
  static var box = Hive.box("rules");

  static Future<void> initializeHive() async {
    final appDirectory = await getApplicationDocumentsDirectory();
    Hive.init(appDirectory.path);
    Hive.registerAdapter(RulesAdapter());
    Hive.registerAdapter(DeviceAdapter());
    Hive.registerAdapter(MostVisitedWebsiteModelAdapter());
    Hive.registerAdapter(WebsiteAdapter());
    await Hive.openBox('rules');
    await Hive.openBox('device');
    await Hive.openBox('child_devices');
    await Hive.openBox('kiosk_mode');
    await Hive.openBox<MostVisitedWebsiteModel>('mostVisitedWebsites');
    await Hive.openBox<List<String>>('preferences');
    await Hive.openBox('token');
    await Hive.openBox('highlights');
    await Hive.openBox('whiteListWebsites');
    debugPrint("Initialized Hive DB successfully");
  }

  static addRule(Rules rule) async {
    List<Rules> rules = box.get("rule")?.cast<Rules>() ?? [];
    rules.add(rule);
    await box.put("rule", rules);
  }

  static removeRule(int index) async {
    List<Rules> rules = box.get("rule")?.cast<Rules>() ?? [];
    rules.removeAt(index);
    await box.put("rule", rules);
  }

  static getRuleAtIndex(int index) {
    List<Rules> rules = box.get("rule")?.cast<Rules>() ?? [];
    return rules[index];
  }

  static List<Rules> getAllRules() {
    return box.get("rule")?.cast<Rules>() ?? [];
  }

  static createDevice(Device device) async {
    Hive.box('device').clear();
    await box.put('device', device);
  }

  static Device? getDevice() {
    Device? d = box.get('device');
    return d;
  }

  static updateDevice(String name) async {
    Device d = box.get('device');
    d.deviceName = name;
    Hive.box('device').clear();
    await box.put('device', d);
  }

  static addChildDevice(String id) async {
    List<String> childDevices = box.get("child_devices") ?? [];
    childDevices.add(id);
    await box.put("child_devices", childDevices);
  }

  static List<String> getAllChildDevices() {
    return box.get("child_devices") ?? [];
  }

  static getchildIdAtIndex(int index) {
    List<String> childDevices = box.get("child_devices") ?? [];
    return childDevices[index];
  }

  static removeChildId(int index) async {
    List<String> childDevices = box.get("child_devices") ?? [];
    childDevices.removeAt(index);
    await box.put("child_devices", childDevices);
  }

  static setKioskMode(bool x) async {
    await box.put('kiosk_mode', x);
  }

  static bool getKioskMode() {
    return box.get('kiosk_mode') ?? false;
  }

  static setToken(DateTime x) async {
    await box.put('token', x);
  }

  static DateTime? getToken() {
    return box.get('token');
  }

  static Future<void> addHighlight(String url, String highlight) async {
    // Get and cast the stored data to the correct type
    final dynamic rawData = box.get("highlights");
    Map<String, List<String>> highlights;

    if (rawData == null) {
      // If no data exists, create new map
      highlights = {};
    } else {
      // Convert the dynamic map to the correct type
      highlights = (rawData as Map<dynamic, dynamic>).map(
        (key, value) => MapEntry(
          key.toString(),
          (value as List<dynamic>).map((e) => e.toString()).toList(),
        ),
      );
    }

    // Initialize empty list for new URL
    if (!highlights.containsKey(url)) {
      highlights[url] = [];
    }

    // Add the highlight
    highlights[url]!.add(highlight);
    // debug(highlights);
    // Save back to box
    await box.put("highlights", highlights);
  }

  static List<String> getHighlights(String url) {
    final highlights = (box.get("highlights") ?? <String, List<String>>{})
        .cast<String, List<String>>();
    // debug(highlights);
    return highlights[url] ?? [];
  }

  static Future<void> setWhitelistedWebsites(List<Website>? websites) async {
    // Save back to box
    Hive.box('whiteListWebsites').clear();
    await Hive.box('whiteListWebsites').put("whiteListWebsites", websites);
  }
  
  static List<Website> getWhitelistedWebsites() {
    return Hive.box('whiteListWebsites').get("whiteListWebsites")?.cast<Website>() ?? [];
  } 
}