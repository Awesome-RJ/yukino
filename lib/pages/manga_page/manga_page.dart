import 'package:flutter/material.dart';
import '../../core/utils.dart' as utils;
import '../../core/extractor/extractors.dart' as extractor;
import '../../core/extractor/manga/model.dart' as manga_model;
import '../../core/models/manga_page.dart' as manga_page;
import '../../plugins/router.dart';
import '../../plugins/translator/translator.dart';
import '../../components/full_screen.dart';
import './reader_page.dart';

enum Pages { home, reader }

class Page extends StatefulWidget {
  const Page({final Key? key}) : super(key: key);

  @override
  State<Page> createState() => PageState();
}

class PageState extends State<Page> {
  manga_model.MangaInfo? info;

  manga_model.ChapterInfo? chapter;
  int? currentChapterIndex;
  Map<manga_model.ChapterInfo, List<manga_model.PageInfo>> pages = {};

  late PageController controller;

  Widget loader = const Center(
    child: CircularProgressIndicator(),
  );

  late manga_page.PageArguments args;

  @override
  void initState() {
    super.initState();

    controller = PageController(
      initialPage: Pages.home.index,
    );

    Future.delayed(Duration.zero, () async {
      args = manga_page.PageArguments.fromJson(
        RouteManager.parseRoute(ModalRoute.of(context)!.settings.name!).params,
      );

      getInfo();
    });
  }

  @override
  void dispose() {
    controller.dispose();

    super.dispose();
  }

  Future<void> goToPage(Pages page) async {
    await controller.animateToPage(
      page.index,
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeInOut,
    );
  }

  void getInfo() async => extractor.Extractors.manga[args.plugin]!
      .getInfo(
        args.src,
        locale: Translator.t.code,
      )
      .then((x) => setState(() {
            info = x;
          }));

  void setChapter(
    int? index,
  ) {
    setState(() {
      currentChapterIndex = index;
      chapter = index != null ? info!.chapters[index] : null;
    });

    if (chapter != null && pages[chapter] == null) {
      extractor.Extractors.manga[args.plugin]!.getChapter(chapter!).then((x) {
        setState(() {
          pages[chapter!] = x;
        });
      });
    }
  }

  Widget getHero() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final image = info!.thumbnail != null
            ? Image.network(
                info!.thumbnail!,
                width: utils.remToPx(7),
              )
            : Image.asset(
                utils.Assets.placeholderImage(
                  utils.Fns.isDarkContext(context),
                ),
                width: utils.remToPx(7),
              );

        final left = ClipRRect(
          borderRadius: BorderRadius.circular(utils.remToPx(0.5)),
          child: image,
        );

        final right = Column(
          children: [
            Text(
              info!.title,
              style: TextStyle(
                fontSize: Theme.of(context).textTheme.headline4?.fontSize,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            Text(
              args.plugin,
              style: TextStyle(
                color: Theme.of(context).primaryColor,
                fontSize: Theme.of(context).textTheme.headline6?.fontSize,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        );

        if (constraints.maxWidth > utils.ResponsiveSizes.md) {
          return Row(
            children: [
              left,
              right,
            ],
          );
        } else {
          return Column(
            children: [
              left,
              SizedBox(
                height: utils.remToPx(1),
              ),
              right,
            ],
          );
        }
      },
    );
  }

  List<Widget> getChapterCard(manga_model.ChapterInfo chapter) {
    List<String> first = [];
    List<String> second = [];

    if (chapter.volume != null) {
      first.add('${Translator.t.volume()} ${chapter.volume}');
    }

    if (chapter.title != null) {
      first.add('${Translator.t.chapter()} ${chapter.chapter}');
      second.add(chapter.title!);
    } else {
      second.add('${Translator.t.chapter()} ${chapter.chapter}');
    }

    return [
      Text(
        first.join(' & '),
        style: TextStyle(
          color: Theme.of(context).primaryColor,
          fontWeight: FontWeight.bold,
        ),
      ),
      Text(
        second.join(' '),
        style: TextStyle(
          fontSize: Theme.of(context).textTheme.headline6?.fontSize,
          fontWeight: FontWeight.bold,
        ),
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final appBar = AppBar(
      backgroundColor:
          Theme.of(context).scaffoldBackgroundColor.withOpacity(0.3),
      elevation: 0,
    );

    return WillPopScope(
        child: SafeArea(
          child: info != null
              ? PageView(
                  controller: controller,
                  physics: const NeverScrollableScrollPhysics(),
                  children: [
                    Scaffold(
                      extendBodyBehindAppBar: true,
                      appBar: appBar,
                      body: SingleChildScrollView(
                        child: Container(
                          padding: EdgeInsets.only(
                            left: utils.remToPx(1.25),
                            right: utils.remToPx(1.25),
                            bottom: utils.remToPx(1),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              SizedBox(
                                height: appBar.preferredSize.height,
                              ),
                              getHero(),
                              SizedBox(
                                height: utils.remToPx(1.5),
                              ),
                              Text(
                                Translator.t.chapters(),
                                style: TextStyle(
                                  fontSize: Theme.of(context)
                                      .textTheme
                                      .bodyText2
                                      ?.fontSize,
                                  color: Theme.of(context)
                                      .textTheme
                                      .bodyText2
                                      ?.color
                                      ?.withOpacity(0.7),
                                ),
                              ),
                              ...info!.chapters
                                  .asMap()
                                  .map(
                                    (k, x) => MapEntry(
                                      k,
                                      Card(
                                        child: InkWell(
                                          borderRadius:
                                              BorderRadius.circular(4),
                                          child: Padding(
                                            padding: EdgeInsets.symmetric(
                                              horizontal: utils.remToPx(0.4),
                                              vertical: utils.remToPx(0.2),
                                            ),
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: getChapterCard(x),
                                            ),
                                          ),
                                          onTap: () {
                                            setChapter(k);
                                            goToPage(Pages.reader);
                                          },
                                        ),
                                      ),
                                    ),
                                  )
                                  .values
                                  .toList(),
                            ],
                          ),
                        ),
                      ),
                    ),
                    chapter != null
                        ? pages[chapter] != null && pages[chapter]!.isNotEmpty
                            ? FullScreenWidget(
                                child: MangaReader(
                                  key: ValueKey(
                                    '${chapter!.volume ?? '?'}-${chapter!.chapter}',
                                  ),
                                  info: info!,
                                  chapter: chapter!,
                                  pages: pages[chapter]!,
                                  previousChapter: () {
                                    if (currentChapterIndex != null &&
                                        currentChapterIndex! - 1 >= 0) {
                                      setChapter(currentChapterIndex! - 1);
                                    } else {
                                      setChapter(null);
                                      goToPage(Pages.home);
                                    }
                                  },
                                  nextChapter: () {
                                    if (currentChapterIndex != null &&
                                        currentChapterIndex! + 1 <
                                            info!.chapters.length) {
                                      setChapter(currentChapterIndex! + 1);
                                    } else {
                                      setChapter(null);
                                      goToPage(Pages.home);
                                    }
                                  },
                                  onPop: () {
                                    setChapter(null);
                                    goToPage(Pages.home);
                                  },
                                ),
                              )
                            : loader
                        : const SizedBox.shrink(),
                  ],
                )
              : loader,
        ),
        onWillPop: () async {
          if (controller.page!.toInt() != Pages.home.index) {
            setState(() {
              setChapter(null);
            });

            goToPage(Pages.home);
            return false;
          }

          Navigator.of(context).pop();
          return true;
        });
  }
}
