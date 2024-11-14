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
      body: Listener(
        onPointerSignal: (pointerSignal) {
          // 마우스 휠로 스케일 조정
          if (pointerSignal is PointerScrollEvent) {
            setState(() {
              scale += pointerSignal.scrollDelta.dy > 0 ? 0.1 : -0.1;
              scale = scale.clamp(0.5, 3.0); // 스케일 범위 제한
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
        child: Center(
          child: isImageLoaded
              ? CustomPaint(
                  painter: ImagePainter(
                    image: image,
                    offset: offset,
                    scale: scale,
                    angle: angle,
                  ),
                  child: const SizedBox(
                    width: 300,
                    height: 300,
                  ),
                )
              : const CircularProgressIndicator(),
        ),
      ),
    );
  }
}

class ImagePainter extends CustomPainter {
  final ui.Image image;
  final Offset offset;
  final double scale;
  final double angle;

  ImagePainter({
    required this.image,
    required this.offset,
    required this.scale,
    required this.angle,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final Matrix4 matrix = Matrix4.identity()
      ..translate(size.width / 2, size.height / 2) // 캔버스 중심으로 이동
      ..rotateZ(angle) // 각도 회전
      ..translate(-size.width / 2, -size.height / 2) // 다시 원위치
      ..translate(offset.dx, offset.dy) // 사용자 입력에 따른 이동
      ..scale(scale); // 확대/축소

    canvas.transform(matrix.storage); // 캔버스에 매트릭스 적용

    // 이미지 그리기
    final Rect imageRect = Rect.fromLTWH(
      0,
      0,
      image.width.toDouble(),
      image.height.toDouble(),
    );

    canvas.drawImageRect(image, imageRect, Offset.zero & size, Paint());
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return true;
  }
}
