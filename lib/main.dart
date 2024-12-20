import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'dart:ui' as ui;
import 'package:http/http.dart' as http;
import 'dart:typed_data';

void main() {
  runApp(const MaterialApp(home: MatrixImagePainter()));
}

class MatrixImagePainter extends StatefulWidget {
  const MatrixImagePainter({super.key});

  @override
  MatrixImagePainterState createState() => MatrixImagePainterState();
}

class MatrixImagePainterState extends State<MatrixImagePainter> {
  late ui.Image image;
  bool isImageLoaded = false;

  Offset offset = Offset.zero;
  double scale = 1.0;
  double angle = 0.0; // 회전 각도 (라디안 단위)

  Offset? lastFocalPoint; // 마지막 마우스 포인트 위치
  Offset? pointerImagePosition;

  @override
  void initState() {
    super.initState();
    _loadNetworkImage();
  }

  Future<void> _loadNetworkImage() async {
    final response = await http.get(Uri.parse(
        'https://watermark.lovepik.com/photo/40094/6373.jpg_wh1200.jpg')); // 이미지 URL
    if (response.statusCode == 200) {
      final Uint8List data = response.bodyBytes;
      final ui.Codec codec = await ui.instantiateImageCodec(data);
      final ui.FrameInfo frameInfo = await codec.getNextFrame();
      setState(() {
        image = frameInfo.image;
        isImageLoaded = true;
      });
    } else {
      throw Exception('이미지를 불러오지 못했습니다.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("CustomPaint with Mouse Control")),
      body: Center(
        child: isImageLoaded
            ? Container(
                width: 600,
                height: 400,
                decoration: BoxDecoration(
                  border: Border.all(
                    color: Colors.blue,
                    width: 2.0,
                  ),
                ),
                child: MouseRegion(
                  onHover: (details) {
                    setState(() {
                      // 포인터의 이미지 좌표 계산
                      final Offset transformedPointer =
                          (details.localPosition - offset) / scale;

                      pointerImagePosition = Offset(
                        transformedPointer.dx,
                        transformedPointer.dy,
                      );
                    });
                  },
                  child: Listener(
                    onPointerSignal: (pointerSignal) {
                      if (pointerSignal is PointerScrollEvent) {
                        setState(() {
                          // 이전 스케일과 포인터 위치 계산
                          final double previousScale = scale;
                          final Offset focalPoint = pointerSignal.localPosition;

                          // 마우스 위치 기준으로 이미지 좌표계의 포인트 계산
                          final Offset focalPointInImage =
                              (focalPoint - offset) / previousScale;

                          // 새로운 스케일 계산
                          scale +=
                              pointerSignal.scrollDelta.dy > 0 ? 0.1 : -0.1;
                          scale = scale.clamp(0.5, 3.0);

                          // 새로운 offset 계산 (확대/축소 후에도 동일한 이미지 위치 고정)
                          offset = focalPoint - focalPointInImage * scale;
                        });
                      }
                    },
                    onPointerDown: (details) {
                      if (details.buttons == kSecondaryMouseButton) {
                        // 오른쪽 마우스 버튼을 클릭했을 때 시계방향으로 90도 회전
                        setState(() {
                          angle += 90.0 * 3.1415927 / 180; // 90도 (라디안으로 변환)
                          if (angle >= 2 * 3.1415927) {
                            angle -= 2 * 3.1415927; // 각도를 0 ~ 2π 사이로 유지
                          }
                        });
                      } else if (details.buttons == kPrimaryMouseButton) {
                        // 왼쪽 마우스 버튼 눌렀을 때 팬 시작
                        lastFocalPoint = details.position;
                      }
                    },
                    onPointerMove: (details) {
                      setState(() {
                        if (lastFocalPoint != null &&
                            details.buttons == kPrimaryMouseButton) {
                          // 왼쪽 마우스 버튼으로 팬 이동 처리
                          offset += details.position - lastFocalPoint!;
                          lastFocalPoint = details.position;
                        }
                      });
                    },
                    onPointerUp: (details) {
                      lastFocalPoint = null;
                    },
                    child: CustomPaint(
                      painter: ImagePainter(
                        image: image,
                        offset: offset,
                        scale: scale,
                        angle: angle,
                        pointerImagePosition: pointerImagePosition,
                      ),
                      child: const SizedBox(
                        width: 400,
                        height: 400,
                      ),
                    ),
                  ),
                ),
              )
            : const CircularProgressIndicator(),
      ),
    );
  }
}

class ImagePainter extends CustomPainter {
  final ui.Image image;
  final Offset offset;
  final double scale;
  final double angle;
  final Offset? pointerImagePosition;

  ImagePainter({
    required this.image,
    required this.offset,
    required this.scale,
    required this.angle,
    this.pointerImagePosition,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // 이미지 중심 구하기
    final Offset imageCenter = Offset(
      size.width / 2,
      size.height / 2,
    );

    // 매트릭스 설정
    final Matrix4 matrix = Matrix4.identity()
      ..translate(offset.dx, offset.dy) // 사용자 입력에 따른 이동
      ..scale(scale) // 확대/축소
      ..translate(imageCenter.dx, imageCenter.dy) // 이미지 중심으로 이동
      ..rotateZ(angle) // 각도 회전
      ..translate(-imageCenter.dx, -imageCenter.dy); // 원래 위치로 되돌리기

    canvas.transform(matrix.storage); // 캔버스에 매트릭스 적용

    // 이미지 그리기
    final Rect imageRect = Rect.fromLTWH(
      0,
      0,
      image.width.toDouble(),
      image.height.toDouble(),
    );

    canvas.drawImageRect(image, imageRect, Offset.zero & size, Paint());

    // 디버깅 정보 출력
    final paragraphBuilder = ui.ParagraphBuilder(
        ui.ParagraphStyle(textAlign: TextAlign.left))
      ..pushStyle(ui.TextStyle(color: Colors.red, fontSize: 14))
      ..addText(
          'Scale: $scale\nOffset: $offset\nPointer: ${pointerImagePosition?.toString() ?? "N/A"}');
    final paragraph = paragraphBuilder.build()
      ..layout(ui.ParagraphConstraints(width: size.width));
    canvas.drawParagraph(paragraph, const Offset(10, 10));
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return true;
  }
}
