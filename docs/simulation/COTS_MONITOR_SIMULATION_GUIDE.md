# COTS Monitor — Classification Simulation (Based on Your System)

This guide matches your Flutter app: Firestore `scan_records`, YOLO detection (`ai_detected_count`, `confidence`), zones (`Zone A`–`Zone D`), and `CotsConfidencePolicy` (74% / 20% thresholds).

---

## How your system maps to the simulation

| CSV column | Source in COTS Monitor |
|------------|-------------------------|
| `record_id` | Firestore document ID (`scan_records/{id}`) |
| `date` | `submitted_at` or `date_taken` |
| `zone` | `zone` (from `ZoneAssignmentService` + GPS) |
| `ai_detected_count` | `ai_detected_count` (YOLOv8 ONNX) |
| `confidence` | `confidence` (0.0–1.0, record average) |
| `confidence_percent` | `confidence × 100` (same as `CotsConfidencePolicy.percentFromConfidence`) |
| `activity_type` | `activity_type` (detection / removal, etc.) |
| `admin_confirmed` | `admin_confirmed` |
| `admin_rejected` | `admin_rejected` |
| `predicted_label` | **1** if `ai_detected_count > 0`, else **0** (AI classification) |
| `actual_label` | **1** if admin confirmed OR (no review yet & count > 0 for demo); **0** if admin rejected OR count = 0 |

### Risk levels (same idea as `UserDashboardAnalytics`)

Per **scan record** (by `ai_detected_count`):

- **High** — count ≥ 15  
- **Medium** — count 5–14  
- **Low** — count 1–4 or 0  

Per **zone** (for Graph 5): share of scans with `predicted_label = 1` (present rate).

### Confidence bands (your app policy)

- **High (≥ 74%)** — AI auto-approve  
- **Medium (20–73%)** — Admin review  
- **Low (< 20%)** — Retake photo  

---

## Step 1 — Get data from Firebase (real records)

1. Open [Firebase Console](https://console.firebase.google.com) → your project → **Firestore**.
2. Open collection **`scan_records`**.
3. For each document, copy (or export) fields:
   - `ai_detected_count`, `confidence`, `zone`, `submitted_at`
   - `admin_confirmed`, `admin_rejected`, `activity_type`
4. Build a spreadsheet with the columns in `cots_classification_simulation_export_template.csv`.
5. Add formulas:
   - `predicted_label` = IF(`ai_detected_count`>0, 1, 0)
   - `actual_label` = IF(`admin_confirmed`, 1, IF(`admin_rejected`, 0, IF(`ai_detected_count`>0,1,0)))
   - `confidence_percent` = ROUND(`confidence`*100)
6. **File → Download → CSV** and upload to Colab.

**No Firestore data yet?** Use `cots_classification_simulation_sample.csv` in this folder (demo zones Zone A–D).

---

## Step 2 — Google Colab

1. Go to https://colab.research.google.com → **New notebook**.
2. Open `cots_monitor_colab_simulation.py` in this repo and copy all cells into Colab (split at `# %%` markers), **or** upload the file and run it.
3. Upload your CSV when prompted.
4. Download the generated PNG graphs.

---

## Step 3 — Video demo (what to show)

| Order | On screen | What to say |
|-------|-----------|-------------|
| 1 | App: **Scan Detection** (YOLO) | “Input: GoPro underwater image.” |
| 2 | App: submit → **Records** / **Dashboard** | “Processing: YOLO counts COTS, assigns zone from GPS, saves to Firestore.” |
| 3 | Colab: CSV columns | “Simulation dataset from `scan_records`.” |
| 4 | Colab: metrics + 5 graphs | Explain each graph (see script below). |
| 5 | App: **Admin map** or **User analytics** | “Same insights support patrol priority and outbreak response.” |

**Length:** 2–4 minutes.

---

## Step 4 — Files to submit

- [ ] CSV used (export or sample)  
- [ ] 5–6 graph PNGs from Colab  
- [ ] Video MP4  
- [ ] Written Section 4 (already in your assignment doc)

---

## Video script (system-specific)

**Intro**  
“This simulation is for COTS Monitor. We use YOLOv8 detection on underwater images, store results in Firestore `scan_records`, and apply **classification** to label each scan as COTS Present or Absent and to assess zone risk.”

**Inputs**  
“Each row is one scan submission: `ai_detected_count`, `confidence`, `zone` from GPS assignment, and date. When available, `admin_confirmed` or `admin_rejected` is our ground truth for evaluation.”

**Processing**  
“We classify Present if the AI detected at least one COTS. We compare predictions to actual labels for accuracy. Zone risk uses present rate per zone, aligned with our dashboard severity rules.”

**Graphs**  
- Graph 1: predicted Present vs Absent across all scans.  
- Graph 2: confidence distribution (74% auto-approve policy in our app).  
- Graph 3: confusion matrix — AI vs admin/ground truth.  
- Graph 4: daily total `ai_detected_count` trend (like user dashboard).  
- Graph 5: Zone A–D present rate for patrol priority.  
- Graph 6 (optional): confidence bands High / Medium / Low per `CotsConfidencePolicy`.

**Insights**  
“High present rate in Zone A or D matches our map high-outbreak zones. Spikes in the trend chart suggest periods needing more dives. Confusion matrix errors show where admin review is still required. These support decisions in our admin map monitoring and user analytics screens.”

---

## Optional: show graphs from the app

Record your **User Analytics** or **Admin Analytics** screen alongside Colab graphs to prove the simulation matches the live system.
