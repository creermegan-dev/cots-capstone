# YOLOv8 ONNX model

Place your exported model here:

`assets/models/yolov8_best.onnx`

Export from your `.pt` file:

```bash
yolo export model="C:\path\to\yolov8_best.pt" format=onnx imgsz=640
```

Then copy the generated `.onnx` file into this folder and rebuild the app.

Expected model I/O (single-class detector):

- Input: `images` — shape `[1, 3, 640, 640]`
- Output: shape `[1, 5, 8400]` (`x, y, w, h, confidence`)
