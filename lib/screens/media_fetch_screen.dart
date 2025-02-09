import 'dart:math';

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../helpers/media_quality_manager.dart';
import '../helpers/webview_manager.dart';
import '../services/anime_service.dart';
import '../services/request_service.dart';
import '../utils/constants.dart';
import '../utils/extractor.dart';
import '../utils/routes.dart';
import '../widgets/tako_play_web_view.dart';
import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart';

class MediaFetchScreen extends StatefulWidget {
  const MediaFetchScreen({Key? key}) : super(key: key);

  @override
  State<MediaFetchScreen> createState() => _MediaFetchScreenState();
}

class _MediaFetchScreenState extends State<MediaFetchScreen> {
  final GlobalKey webViewKey = GlobalKey();
  final webViewManagerController = Get.find<WebViewManager>();
  final mediaFetchController = Get.find<MediaQualityManager>();
  final _random = Random();
  var hasError = false.obs;
  Map<String, String> resolutions = {'sd': ''};
  List<String> _qualityList = [];
  String _filteredUrl = '';
  final animeUrl = Get.arguments['animeUrl'];
  late final String mediaUrl;

  @override
  void initState() {
    super.initState();
    mediaFetchController.getVideoQuality();

    fetchVideoFile();
  }

  Future<void> fetchVideoFile() async {
    if (webViewManagerController.isWebView) {
      var mediaUrl =
          await AnimeService().fetchIframeEmbedded(animeUrl).catchError((_) {
        Get.dialog(const AlertDialog(
          backgroundColor: tkDarkBlue,
          content: Text('An Error Occurred'),
        ));
        Get.back();
      });
      if (!mounted) return;
      await Get.offNamed(Routes.webViewScreen, arguments: {
        'mediaUrl': mediaUrl,
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Opacity(
            opacity: 0,
            child: webViewManagerController.isWebView
                ? const SizedBox()
                : FutureBuilder<String>(
                    future: AnimeService().fetchIframeEmbedded(animeUrl),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.done) {
                        return SizedBox.fromSize(
                          size: Size(MediaQuery.of(context).size.width / 1.5,
                              MediaQuery.of(context).size.height / 1.5),
                          child: TakoPlayWebView(
                            initialUrl: '${snapshot.data}',
                            onLoadingFinished: (webViewController) async {
                              mediaUrl = snapshot.data!;
                              // Ads Block
                              final response = await RequestService.create()
                                  .requestAnimeDetailResponse(animeUrl);

                              dom.Document document = parse(response.body);

                              String newRawUrl = document
                                  .getElementsByClassName('vidcdn')
                                  .first
                                  .getElementsByTagName('a')
                                  .first
                                  .attributes
                                  .values
                                  .last
                                  .toString();

                              // New fetch
                              // String newRawUrl = await webViewController
                              //     .runJavaScriptReturningResult(
                              //         "document.getElementsByClassName('vidcdn')[0].attributes.data-video.value;")
                              //     .toString();

                              List<String> data =
                                  await extractor().extract(newRawUrl);

                              // Fetching VidStreaming Url
                              String rawUrl = data[0];

                              _filteredUrl = rawUrl;
                              // takoDebugPrint('Filter Url : $_filteredUrl');
                              if (_filteredUrl != '') {
                                await Get.offNamed(Routes.videoPlayerScreen,
                                    arguments: {
                                      'url': _filteredUrl,
                                      'resolutions': resolutions,
                                    });
                              } else {
                                await Get.offNamed(Routes.videoPlayerScreen,
                                    arguments: {
                                      'url': rawUrl,
                                      'resolutions': resolutions,
                                    });
                              }
                            },
                          ),
                        );
                      } else {
                        return const SizedBox();
                      }
                    }),
          ),
          Container(
            alignment: Alignment.center,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Obx(
                  () => Image.asset(
                    hasError.value
                        ? 'assets/gif/anime-cry.gif'
                        : 'assets/gif/anime${1 + _random.nextInt(25)}.gif',
                    width: 350,
                    height: 200,
                  ),
                ),
                SizedBox(
                  height: 20,
                ),
                Obx(
                  () => Visibility(
                    visible: !hasError.value,
                    child: Text(
                      'Please Wait ...',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                Obx(
                  () => Visibility(
                    visible: hasError.value,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 20),
                      child: Text(
                        'Episode can\'t be fetch',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ),
                Obx(
                  () => Visibility(
                    visible: hasError.value,
                    child: MaterialButton(
                      onPressed: hasError.value
                          ? () {
                              Get.offNamed(Routes.webViewScreen, arguments: {
                                'mediaUrl': mediaUrl,
                              });
                            }
                          : null,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 30, vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(15),
                      ),
                      color: tkGradientBlue,
                      child: Text(
                        'Continue with WebView Player',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
