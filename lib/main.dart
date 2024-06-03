import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/services.dart';
import 'package:gallery_saver/gallery_saver.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:video_player/video_player.dart';
import 'firebase_options.dart';        //請各位同學自行產生
import 'package:intl/intl.dart';
import 'package:dio/dio.dart';

Future<void> main() async{
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Storage Demo',
      theme: ThemeData(primarySwatch: Colors.blue,),
      home: const MyHomePage(title: 'Flutter Storage Demo'),
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

  var storage=FirebaseStorage.instance;
  List<AssetImage> listOfImage=[];
  List<String> listOfStr=[];
  bool clicked=false;
  bool isLoading=false;
  String? images;
  late Future<ListResult> futureFiles;

  @override
  void initState() {
    super.initState();
    getImages();
    futureFiles=FirebaseStorage.instance.ref('/images').listAll();
  }

  void getImages() {
    listOfImage=[];
    for (int i=0;i<6;i++) {
      listOfImage.add(AssetImage('assets/travelimage'+i.toString()+'.jpeg'));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.title),),
      body: Container(
        child: Column(
          children: [
            GridView.builder(
                shrinkWrap: true,
                padding: EdgeInsets.all(0),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  mainAxisSpacing: 3,
                  crossAxisSpacing: 3
                ),
                itemCount: listOfImage.length,
                itemBuilder: (context, index) {
                  return GridTile(
                      child: Material(
                        child: GestureDetector(
                          child: Stack(
                            children: [
                               this.images==listOfImage[index].assetName || listOfStr.contains(listOfImage[index].assetName)?
                               Positioned.fill(child: Opacity(
                                 opacity: 0.7,
                                 child: Image.asset(listOfImage[index].assetName, fit: BoxFit.fill,),
                               ),):
                               Positioned.fill(child: Opacity(
                                 opacity: 1.0,
                                 child: Image.asset(listOfImage[index].assetName, fit: BoxFit.fill,),
                               ),),
                              this.images==listOfImage[index].assetName || listOfStr.contains(listOfImage[index].assetName)?
                                  Positioned(left: 0, bottom: 0, child: Icon(Icons.check_circle, color: Colors.green,),):
                                  Visibility(visible: false, child: Icon(Icons.check_circle_outline, color: Colors.green,),),
                            ],
                          ),
                          onTap: () {
                            setState(() {
                              if (listOfStr.contains(listOfImage[index].assetName)) {
                                this.clicked=false;
                                listOfStr.remove(listOfImage[index].assetName);
                                this.images=null;
                              }
                              else {
                                this.clicked=true;
                                this.images=listOfImage[index].assetName;
                                listOfStr.add(this.images!);
                              }
                            });
                          },
                        ),
                      ),
                  );
                },
            ),
            ElevatedButton(
                onPressed: () {
                  setState(() {
                    this.isLoading=true;
                  });
                  listOfStr.forEach((img) async {
                    String imageName=img.substring(img.lastIndexOf('/'), img.lastIndexOf('.')).replaceAll('/', '');
                    final Directory systemTempDir=Directory.systemTemp;
                    final byteData=await rootBundle.load(img);
                    final file=File('${systemTempDir.path}/$imageName.jpeg');
                    await file.writeAsBytes(byteData.buffer.asUint8List(byteData.offsetInBytes, byteData.lengthInBytes));
                    TaskSnapshot snapshot=await storage
                                                .ref()
                                                .child("image/$imageName")
                                                .putFile(file);
                    if (snapshot.state==TaskState.success) {
                      final String downloadUrl=await snapshot.ref.getDownloadURL();
                      await FirebaseFirestore.instance
                            .collection('images')
                            .add({'url':downloadUrl, 'name':imageName});
                      setState(() {
                        this.isLoading=false;
                      });
                      final snackBar=SnackBar(content: Text('Successfully loaded!'));
                      ScaffoldMessenger.of(context).showSnackBar(snackBar);
                    }
                    else
                      throw 'Failed to load...';
                  });
                },
                child: Text('Save images'),),
            ElevatedButton(
                onPressed: () {
                  Navigator.push(context, MaterialPageRoute(builder: (context)=>SecondPage()));
                },
                child: Text('Get images'),
            ),
            isLoading? CircularProgressIndicator():Visibility(visible: false, child: Text('test'),),
          ],
        ),
      ),
    );
  }
}

class SecondPage extends StatefulWidget {
  const SecondPage({Key? key}) : super(key: key);

  @override
  State<SecondPage> createState() => _SecondPageState();
}

class _SecondPageState extends State<SecondPage> {

  final FirebaseFirestore fb=FirebaseFirestore.instance;
  File? image;
  bool isLoading=false;
  bool isRetrieve=false;
  late QuerySnapshot<Map<String, dynamic>> cachedResult;

  Future<QuerySnapshot<Map<String, dynamic>>> getImages() {
    return fb.collection('images').get();
  }
  
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(title: Text('Second Page'),
                       centerTitle: true,),
        body: Container(
          padding: EdgeInsets.all(10),
          child: SingleChildScrollView(
            child: Column(
              children: [
                FutureBuilder(
                    future: getImages(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState==ConnectionState.done) {
                        isRetrieve=true;
                        cachedResult=snapshot.data!;
                        return ListView.builder(
                          shrinkWrap: true,
                          itemCount: snapshot.data!.docs.length,
                          itemBuilder: (context, index) {
                            return ListTile(
                              contentPadding: EdgeInsets.all(8),
                              title: Text(snapshot.data!.docs[index].data()['name']),
                              leading: Image.network(snapshot.data!.docs[index].data()['url'],
                                                     fit: BoxFit.fill),
                              trailing: IconButton(icon: Icon(Icons.delete),
                                                   onPressed: () {
                                                     FirebaseStorage.instance.refFromURL(snapshot.data!.docs[index].data()['url']).delete();
                                                     FirebaseFirestore.instance.collection('image').doc(snapshot.data!.docs[index].id).delete();
                                                     setState(() {});
                                                   },),
                            );
                          },
                        );
                      }
                      else if (snapshot.connectionState==ConnectionState.none) {
                        return Text('No data!');
                      }
                      return CircularProgressIndicator();
                    }),
                ElevatedButton(
                  child: Text('Pick image'), 
                  onPressed: () async {
                    final picker=ImagePicker();
                    var image1=await picker.pickImage(source: ImageSource.gallery);
                    setState(() {
                      image=File(image1!.path);
                    });
                  },),
                image==null? Text('No image selected.'):
                             Image.file(image!, fit: BoxFit.fill, height: 300),
                !isLoading? ElevatedButton(
                    child: Text('Save image'),
                    onPressed: () async {
                      if (image!=null) {
                        setState(() {
                          this.isLoading=true;
                        });
                        Reference ref=FirebaseStorage.instance.ref();
                        DateTime now=DateTime.now();
                        String formattedDate=DateFormat('yyyyMMddHHMMSS').format(now);
                        TaskSnapshot addImg=await ref.child('image/'+formattedDate).putFile(image!);
                        if (addImg.state==TaskState.success) {
                          setState(() {
                            this.isLoading=false;
                          });
                          print('Added to Firebase Storage');
                        }
                        final imageUrl=await ref.child('image/'+formattedDate).getDownloadURL();
                        print(imageUrl);
                        Navigator.push(context, MaterialPageRoute(builder: (context)=>ThirdPage()));
                      }
                    },)
                            :CircularProgressIndicator(),   
              ],
            ),
          ),
        ),
      ),
    );
  }
}

late VideoPlayerController controller;
late Future<void> _video;

class ThirdPage extends StatefulWidget {
  const ThirdPage({Key? key}) : super(key: key);

  @override
  State<ThirdPage> createState() => _ThirdPageState();
}

class _ThirdPageState extends State<ThirdPage> {

  PlatformFile? pickedFile;
  UploadTask? uploadTask;

  Future uploadFile() async {
    final path='files/${pickedFile!.name}';
    final file=File(pickedFile!.path!);
    final ref=FirebaseStorage.instance.ref().child(path);
    setState(() {
      uploadTask=ref.putFile(file);
    });

    final snapshot=await uploadTask!.whenComplete(() {
      Navigator.push(context, MaterialPageRoute(builder: (context)=>FourthPage()));
    });

    final urlDownload=await snapshot.ref.getDownloadURL();
    print('Download link: $urlDownload');

    setState(() {
      uploadTask=null;
    });
  }

  Future selectFile() async {
    final result=await FilePicker.platform.pickFiles();
    if (result==null) return;
    setState(() {
      pickedFile=result.files.first;
      buildMediaPreview();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Upload file'),),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (pickedFile!=null)
              Expanded(child: Container(
                color: Colors.blue[100],
                child: Text(""),
              ),),
            SizedBox(height: 30),
            Text(pickedFile==null? "Hello":pickedFile!.name),
            ElevatedButton(onPressed: selectFile, child: Text('Select file'),),
            SizedBox(height: 30),
            ElevatedButton(onPressed: uploadFile, child: Text('Upload file'),),
            SizedBox(height: 30),
            buildProgress(),
          ],
        ),
      ),
    );
  }

  Widget buildMediaPreview() {
    final file=File(pickedFile!.path!);
    switch (pickedFile!.extension!.toLowerCase()) {
      case 'jpg':
      case 'jpeg':
      case 'png': return Image.file(file, width: double.infinity, fit: BoxFit.cover);
      case 'mp4': return VideoPlayerWidget(file: file);
      default: return Center(child: Text(pickedFile!.name),);
    }
  }

  Widget buildProgress() {
    return StreamBuilder(
        stream:uploadTask?.snapshotEvents,
        builder: (context, snapshot) {
          if (snapshot.hasData) {
            final data=snapshot.data!;
            double progress=data.bytesTransferred/data.totalBytes;
            return SizedBox(
              height: 50,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  LinearProgressIndicator(
                    value: progress,
                    backgroundColor: Colors.grey,
                    color: Colors.green,
                  ),
                  Center(
                    child: Text('${(100*progress).roundToDouble()}%',
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                ],
              ),
            );
          }
          else
            return SizedBox(height: 50);
        });
  }
}

class VideoPlayerWidget extends StatefulWidget {
  File file;
  VideoPlayerWidget({Key? key, required this.file,}) : super(key: key);

  @override
  State<VideoPlayerWidget> createState() => _VideoPlayerWidgetState();
}

class _VideoPlayerWidgetState extends State<VideoPlayerWidget> {

  @override
  void initState() {
    super.initState();
    controller=VideoPlayerController.file(widget.file);
    _video=controller.initialize();
    setState(() {});
  }

  @override
  void dispose() {
    super.dispose();
    controller.dispose();
  }

  @override
  Widget build(BuildContext context) {

    controller=VideoPlayerController.file(widget.file)
      ..addListener(()=>setState(() {}))
      ..setLooping(true)
      ..initialize();

    return !controller.value.isInitialized?
        Container(
          height: 200,
          child: Center(child: CircularProgressIndicator()),
        )
        :Container(
          width: double.infinity,
          child: AspectRatio(
            aspectRatio: controller.value.aspectRatio,
            child: VideoPlayer(controller),
          ),
    );
  }
}

class FourthPage extends StatefulWidget {
  const FourthPage({Key? key}) : super(key: key);

  @override
  State<FourthPage> createState() => _FourthPageState();
}

class _FourthPageState extends State<FourthPage> {

  late Future<ListResult> futureFiles;
  Map<int, double> downloadProgress={};
  String? urlPreview;
  int selectedIndex=0;

  @override
  void initState() {
    super.initState();
    futureFiles=FirebaseStorage.instance.ref('/files').listAll();
    futureFiles.then((files) {
      if (files.items.isNotEmpty) {
        setPreview(0, files.items.first);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Download files'),),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            color: Colors.blue.shade100,
            height: 300,
            child: buildPreview(),
          ),
          FutureBuilder(
              future: futureFiles,
              builder: (context, snapshot) {
                if (snapshot.hasData) {
                  final files=snapshot.data!.items;
                  return Expanded(child:
                      ListView.builder(
                          itemCount: files.length,
                          itemBuilder: (context, index) {
                            final file=files[index];
                            final isSelected=index==selectedIndex;
                            final progress=downloadProgress[index];

                            return ListTile(
                              selected: isSelected,
                              selectedTileColor: Colors.blue.shade100,
                              title: Text(file.name, style: TextStyle(color: Colors.black,
                                                                      fontWeight: isSelected? FontWeight.bold:FontWeight.normal),),
                              subtitle: progress!=null? LinearProgressIndicator(
                                                           value: progress,
                                                           backgroundColor: Colors.black,
                                                        ):null,
                              trailing: IconButton(
                                icon: Icon(Icons.download, color: Colors.black,),
                                onPressed: ()=>downloadFile(index, file),
                              ),
                              onTap: ()=>setPreview(index, file),
                            );
                          }),
                  );
                }
                else if (snapshot.hasError) {
                  return Center(child: Text('Error occurred!'),);
                }
                else {
                  return Center(child: CircularProgressIndicator(),);
                }
              }),
        ],
      ),
    );
  }

  Future setPreview(int index, Reference file) async {
    final urlFile=await file.getDownloadURL();

    setState(() {
      selectedIndex=index;
      urlPreview=urlFile;
    });
  }

  Widget buildPreview() {
    if (urlPreview!=null) {
      if (urlPreview!.contains('.jpg')) {
        return Image.network(urlPreview!, fit: BoxFit.cover, gaplessPlayback: true,);
      }
      else if (urlPreview!.contains('.mp4')) {
        return VideoPlayerWidget1(key: Key(urlPreview!), url: urlPreview!);
      }
    }
    return Center(child: Text('No preview'),);
  }

  Future downloadFile(int index, Reference ref) async {
    final url=await ref.getDownloadURL();
    final tempDir=await getTemporaryDirectory();
    final path='${tempDir.path}/${ref.name}';
    await Dio().download(url, path,
                         onReceiveProgress: (received, total) {
                            double progress=received/total;
                            setState(() {
                              downloadProgress[index]=progress;
                            });
                         });
    if (url.contains('.mp4')) {
      await GallerySaver.saveVideo(path, toDcim: true);
    }
    else if (url.contains('.jpg')) {
      await GallerySaver.saveImage(path, toDcim: true);
    }
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Download ${ref.name}')));
  }
}

class VideoPlayerWidget1 extends StatefulWidget {
  final String url;
  const VideoPlayerWidget1({Key? key, required this.url}) : super(key: key);

  @override
  State<VideoPlayerWidget1> createState() => _VideoPlayerWidget1State();
}

class _VideoPlayerWidget1State extends State<VideoPlayerWidget1> {

  late VideoPlayerController controller;

  @override
  void initState() {
    super.initState();
    controller=VideoPlayerController.networkUrl(Uri.parse(widget.url))
     ..addListener(()=>setState(() {}))
     ..setLooping(true)
     ..initialize().then((_)=>controller.play());
  }

  @override
  void dispose() {
    super.dispose();
    controller.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return !controller.value.isInitialized?
      Center(
        child: SizedBox(
          width: 64,
          height: 64,
          child: CircularProgressIndicator(color: Colors.blue, strokeWidth: 5,),
        ),
      )
      :SizedBox(
            width: double.infinity,
            child: AspectRatio(
              aspectRatio: controller.value.aspectRatio,
              child: VideoPlayer(controller),
            ),
    );
  }
}

