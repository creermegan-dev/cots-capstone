# Bundled COTS detectors

## Active model: YOLO26s

`assets/models/yolo26_best.onnx` is exported from the user's trained
`YOLO26_Results (1)/weights/best.pt`. It is now the default model.

SHA-256: `e0b0e5e934577706ad60b88fd75ade5992b8da1443b06eedd3cee6b08b874575`.

- Exported with Ultralytics 8.4.55, opset 17, float32, batch 1,
  static 640 input, end2end=True, nms=False, max_det=100, simplify=False.
- Input: `images`, `[1, 3, 640, 640]`, RGB /255 NCHW, orientation-corrected
  and letterboxed with 114 padding.
- Output: `output0`, `[1, 100, 6]`, input-pixel
  `[x1, y1, x2, y2, confidence, class_id]`. Class 0 is `Cots-detection`.
- Decode this native end-to-end output explicitly, remove padding and scale to
  the oriented source image. Do not run raw YOLO NMS a second time or guess that
  small pixel coordinates are normalized.
- Confidence filtering and per-COTS acceptance remain unchanged: scores rounding
  to at least 20% are retained; 20-79% require Expert review; 80-100% are
  automatically accepted. An uncertain candidate can still be a duplicate or a
  false detection, so confidence is not an accuracy measurement.

Desktop ONNX verification matched the trained checkpoint's boxes (within 0.05
source pixels) and scores (within 0.0001) on all 20 previously compared images.
This is export parity, not independent accuracy evaluation or phone verification.

Fully restart/rebuild to switch models:

```powershell
flutter run -d DEVICE_ID
```

YOLO11 remains registered and unchanged as a fallback:

```powershell
flutter run -d DEVICE_ID --dart-define=COTS_MODEL=yolo11
```

An unsupported `COTS_MODEL` value fails visibly. Historical records are not
reprocessed or rewritten when the model changes.

Format reference: https://docs.ultralytics.com/guides/end2end-detection/

## Preserved fallback: YOLO11s

The registered asset remains `assets/models/yolov8_best.onnx` for compatibility.
Its embedded metadata identifies **Ultralytics YOLO11s**, one class
(`Cots-detection`), exported on 2026-09-20 using Ultralytics 8.4.57.

SHA-256: `a2707702a7232ac4864921f52f45e00e361efda71f73cd3c1efb8599e1da8e9f`.

- Input: `images`, float32 `[1, 3, 640, 640]`, orientation-corrected,
  letterboxed with 114 padding, RGB /255, NCHW.
- Output: `output0`, `[1, 5, 8400]`: input-pixel cx/cy/width/height and
  one COTS class score. External NMS is required (export metadata nms=False,
  end2end=False).
- Decoder keeps scores rounding to at least 20% (threshold 0.195), applies
  IoU 0.45 NMS, then maps boxes to the oriented source image. Acceptance is a
  separate per-COTS policy: 80-100% automatic, 20-79% Expert review.
- Normalized exports require explicit decoder configuration. The production
  detector checks the bundled shape rather than silently treating incompatibility
  as zero detections. RT-DETR decoding remains a legacy helper, not this model.

Fully rebuild after replacing an asset. Verify metadata, tensor layout,
preprocessing and results against the original training/export environment before
changing models. No accuracy claim follows from model identity or confidence.

Reference: https://docs.ultralytics.com/reference/utils/nms/
