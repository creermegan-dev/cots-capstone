# Detection-page model selection (2026-11-10)

The Detection upload page now selects YOLOv8n, YOLO11s (default), or YOLO26s.
Each selection uses the exact supplied checkpoint exported locally with Ultralytics
8.4.55, ONNX opset 17, float32, static 640, batch 1, nms=False, simplify=False.
YOLOv8/11 output [1,5,8400] uses external NMS; YOLO26 [1,100,6] uses native
end-to-end output. Existing preprocessing and review thresholds are unchanged.
Changing the selection clears previous results; detection must run again before
continuing. The monthly visit form remains unchanged.

- `trained_yolo8.onnx`: SHA-256 `adef20fa2bd64353114c695875f08fc46679fb6de9d3e396ec7038d1e5568ce2`.
- `trained_yolo11.onnx`: SHA-256 `30075f81627f94da58289044b80fcefa8879d3d2acae3681556ccbd63f02736c`.
- `trained_yolo26.onnx`: SHA-256 `19ad713742cfbc7263df75173fe3d0e5f1153b9fcd196629e852906927877d39`.

These assets are separate from the historical CLI-selected assets below. Original
checkpoint files and historical records were not overwritten. Phone testing is
still required; desktop export checks do not establish field accuracy.

---

# Bundled COTS detectors

## Default model: YOLO11s

Normal builds use `assets/models/yolov8_best.onnx` (the existing YOLO11s
export despite its historical filename). The input pipeline, thresholds and
model weights are unchanged. See its specifications below.

The default was restored after a field-photo diagnostic: on that one supplied
JPG, YOLO11 retained one detection at 81.35%, while YOLO26's highest score was
14.86%, below the existing threshold. This is a single-image observation,
not evidence that YOLO11 is better on every image.

## Optional comparison model: YOLO26s

`assets/models/yolo26_best.onnx` is exported from the user's trained
`YOLO26_Results (1)/weights/best.pt`. It remains available for comparison.

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
  to at least 20% are retained; 20-84% require Expert review; 85-100% are
  automatically accepted. An uncertain candidate can still be a duplicate or a
  false detection, so confidence is not an accuracy measurement.

Desktop ONNX verification matched the trained checkpoint's boxes (within 0.05
source pixels) and scores (within 0.0001) on all 20 previously compared images.
This is export parity, not independent accuracy evaluation or phone verification.

Fully restart/rebuild to switch models:

```powershell
flutter run -d DEVICE_ID
```

To explicitly select YOLO26 instead:

```powershell
flutter run -d DEVICE_ID --dart-define=COTS_MODEL=yolo26
```

An unsupported `COTS_MODEL` value fails visibly. Historical records are not
reprocessed or rewritten when the model changes.

Format reference: https://docs.ultralytics.com/guides/end2end-detection/

## Default export specifications: YOLO11s

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
  separate per-COTS policy: 85-100% automatic, 20-84% Expert review.
- Normalized exports require explicit decoder configuration. The production
  detector checks the bundled shape rather than silently treating incompatibility
  as zero detections. RT-DETR decoding remains a legacy helper, not this model.

Fully rebuild after replacing an asset. Verify metadata, tensor layout,
preprocessing and results against the original training/export environment before
changing models. No accuracy claim follows from model identity or confidence.

Reference: https://docs.ultralytics.com/reference/utils/nms/
