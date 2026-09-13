# COTS detector ONNX model

Place your exported model here as:

`assets/models/yolov8_best.onnx`

Export from Ultralytics (YOLOv8 or RT-DETR):

```bash
yolo export model="C:\path\to\best.pt" format=onnx imgsz=640
```

Then copy the `.onnx` into this folder and **fully rebuild** the app (hot reload is not enough).

Supported exports (single-class COTS):

| Model | Output shape | Box format |
|-------|--------------|------------|
| YOLOv8 | `[1, 5, 8400]` | normalized `cx, cy, w, h` + score |
| RT-DETR | `[1, 300, 6]` | normalized `x1, y1, x2, y2` + score + class |

Input (both): `images` — `[1, 3, 640, 640]` NCHW, RGB, `/255`, letterboxed.

After replacing the file:

```bash
flutter clean
flutter pub get
flutter build apk --release
```
